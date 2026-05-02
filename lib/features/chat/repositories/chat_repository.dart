import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/notification/friend_request_notification_service.dart'
    show FriendRequestNotificationService;
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';
import 'package:edumap_portfolio_project/features/chat/models/friend_request_model.dart';
import 'package:edumap_portfolio_project/features/chat/models/user_preference_model.dart';
import 'package:edumap_portfolio_project/features/app/repositories/storage_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';

Map<String, dynamic>? _decodeJsonSync(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

Future<List<Map<String, dynamic>>> _parseJsonListInIsolate(
  List<String> raws,
) async {
  final out = <Map<String, dynamic>>[];
  for (final raw in raws) {
    final decoded = _decodeJsonSync(raw);
    if (decoded != null) out.add(decoded);
  }
  return out;
}

class _LocalCache {
  _LocalCache._();
  static final _LocalCache instance = _LocalCache._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'chat_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sent_at INTEGER NOT NULL DEFAULT 0,
            data TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id, sent_at)',
        );
        await db.execute('''
          CREATE TABLE presence (
            user_id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertConversation(ConversationModel conv) async {
    final database = await db;
    await database.insert('conversations', {
      'id': conv.id ?? '',
      'data': _encodeConversation(conv),
      'updated_at': conv.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertConversations(List<ConversationModel> list) async {
    final database = await db;
    final batch = database.batch();
    for (final conv in list) {
      batch.insert('conversations', {
        'id': conv.id ?? '',
        'data': _encodeConversation(conv),
        'updated_at': conv.updatedAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> loadConversations() async {
    final database = await db;
    final rows = await database.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    if (rows.isEmpty) return [];
    final raws = rows.map((r) => r['data'] as String).toList();
    return _parseJsonListInIsolate(raws);
  }

  Future<void> deleteConversation(String conversationId) async {
    final database = await db;
    await database.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    await database.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> upsertMessages(List<ChatMessageModel> msgs) async {
    if (msgs.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final msg in msgs) {
      batch.insert('messages', {
        'id': msg.id ?? '',
        'conversation_id': msg.conversationId,
        'sent_at': msg.sentAt.millisecondsSinceEpoch,
        'data': _encodeMessage(msg),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> loadMessages(String conversationId) async {
    final database = await db;
    final rows = await database.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sent_at ASC',
    );
    if (rows.isEmpty) return [];
    final raws = rows.map((r) => r['data'] as String).toList();
    return _parseJsonListInIsolate(raws);
  }

  Future<void> softDeleteMessage(String messageId) async {
    final database = await db;
    await database.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> upsertPresence(UserPresenceModel model) async {
    final database = await db;
    await database.insert('presence', {
      'user_id': model.userId,
      'data': _encodePresence(model),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserPresenceModel?> loadPresence(String userId) async {
    final database = await db;
    final rows = await database.query(
      'presence',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final json = _decodeJsonSync(rows.first['data'] as String);
    if (json == null) return null;
    return _decodePresence(userId, json);
  }

  String _encodeConversation(ConversationModel c) => jsonEncode({
    'id': c.id,
    'type': c.type.name,
    'participant_ids': c.participantIds,
    'participant_usernames': c.participantUsernames,
    'created_by': c.createdBy,
    'created_at': c.createdAt.toIso8601String(),
    'updated_at': c.updatedAt.toIso8601String(),
    'last_message': c.lastMessage,
    'last_message_at': c.lastMessageAt?.toIso8601String(),
    'last_message_sender_id': c.lastMessageSenderId,
    'group_name': c.groupName,
    'group_photo': c.groupPhoto,
    'unread_counts': c.unreadCounts,
    'is_active': c.isActive,
  });

  String _encodeMessage(ChatMessageModel m) => jsonEncode({
    'id': m.id,
    'conversation_id': m.conversationId,
    'sender_id': m.senderId,
    'sender_username': m.senderUsername,
    'content': m.content,
    'type': m.type.name,
    'status': m.status.name,
    'sent_at': m.sentAt.toIso8601String(),
    'read_by': m.readBy,
    'delivered_to': m.deliveredTo,
    'media_url': m.mediaUrl,
    'media_thumbnail_url': m.mediaThumbnailUrl,
    'media_duration_seconds': m.mediaDurationSeconds,
    'media_file_name': m.mediaFileName,
    'media_file_size': m.mediaFileSize,
    'is_deleted': m.isDeleted,
  });

  String _encodePresence(UserPresenceModel p) => jsonEncode({
    'user_id': p.userId,
    'is_online': p.isOnline,
    'last_seen': p.lastSeen.toIso8601String(),
  });

  UserPresenceModel _decodePresence(String userId, Map<String, dynamic> json) =>
      UserPresenceModel(
        userId: userId,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen:
            DateTime.tryParse(json['last_seen'] as String? ?? '') ??
            DateTime.now(),
      );
}

class _SerialQueue {
  final _queues = <String, Future<void>>{};
  final _inflight = <String, int>{};
  static const int _maxConcurrent = 1;

  bool isBusy(String conversationId) =>
      (_inflight[conversationId] ?? 0) >= _maxConcurrent;

  Future<T> enqueue<T>(String conversationId, Future<T> Function() task) {
    if (isBusy(conversationId)) {
      return Future.error(
        BusyException('Please wait for the previous action to complete.'),
      );
    }
    _inflight[conversationId] = (_inflight[conversationId] ?? 0) + 1;
    final prev = _queues[conversationId] ?? Future<void>.value();
    final next = prev.then((_) => task());
    _queues[conversationId] = next
        .then((_) {})
        .catchError((_) {})
        .whenComplete(
          () => _inflight[conversationId] =
              ((_inflight[conversationId] ?? 1) - 1).clamp(0, 999),
        );
    return next;
  }
}

class _LruCache<K, V> {
  _LruCache(this.capacity);

  final int capacity;
  final _map = <K, V>{};

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    if (_map.length >= capacity) _map.remove(_map.keys.first);
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);
}

class ToxicityFilter {
  static const List<String> _toxicPatterns = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'cunt',
    'nigger',
    'nigga',
    'faggot',
    'retard',
    'whore',
    'slut',
    'kill yourself',
    'kys',
    'go die',
    'i will kill',
    'i\'ll kill',
    'murder you',
    'hate you',
    'piece of shit',
    'motherfucker',
    'son of a bitch',
    'idiot',
    'moron',
    'stupid',
    'dumbass',
    'loser',
    'ugly',
    'fat',
  ];

  static bool isToxic(String text) {
    final lower = text.toLowerCase();
    for (final pattern in _toxicPatterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }
}

class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    StorageRepository? storageRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageRepository = storageRepository ?? StorageRepository();

  final FirebaseFirestore _firestore;
  final StorageRepository _storageRepository;

  final _LocalCache _cache = _LocalCache.instance;
  final _SerialQueue _sendQueue = _SerialQueue();
  final _LruCache<String, Map<String, dynamic>> _profileCache = _LruCache(128);

  DateTime? _lastUsernameSyncAt;
  static const _usernameSyncCooldown = Duration(minutes: 2);

  SupabaseClient get _supabase => Supabase.instance.client;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _conversations.doc(conversationId).collection('messages');

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _firestore.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> get _friends =>
      _firestore.collection('friends');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('profiles');

  CollectionReference<Map<String, dynamic>> get _presence =>
      _firestore.collection('presence');

  RealtimeChannel? _typingChannel;

  bool isConversationBusy(String conversationId) =>
      _sendQueue.isBusy(conversationId);

  Future<void> syncParticipantUsernames(
    List<ConversationModel> conversations,
  ) async {
    final now = DateTime.now();
    if (_lastUsernameSyncAt != null &&
        now.difference(_lastUsernameSyncAt!) < _usernameSyncCooldown) {
      return;
    }
    _lastUsernameSyncAt = now;

    try {
      final allIds = <String>{};
      for (final conv in conversations) {
        allIds.addAll(conv.participantIds);
      }
      if (allIds.isEmpty) return;

      final idList = allIds.toList();
      final liveUsernames = <String, String>{}; // userId -> username

      Future<void> fetchChunk(List<String> chunk) async {
        final snap = await _profiles
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        final foundIds = <String>{};
        for (final doc in snap.docs) {
          final username = doc.data()['username'] as String? ?? '';
          if (username.isNotEmpty) {
            liveUsernames[doc.id] = username;
            foundIds.add(doc.id);

            final uid = doc.data()['user_id'] as String?;
            if (uid != null && uid.isNotEmpty && uid != doc.id) {
              liveUsernames[uid] = username;
              foundIds.add(uid);
            }
          }
        }

        final missing = chunk.where((id) => !foundIds.contains(id)).toList();
        if (missing.isEmpty) return;

        final fallbackChunks = <List<String>>[];
        for (var i = 0; i < missing.length; i += 10) {
          fallbackChunks.add(
            missing.sublist(i, (i + 10).clamp(0, missing.length)),
          );
        }
        await Future.wait(
          fallbackChunks.map((fc) async {
            final fSnap = await _profiles.where('user_id', whereIn: fc).get();
            for (final doc in fSnap.docs) {
              final username = doc.data()['username'] as String? ?? '';
              final uid = doc.data()['user_id'] as String? ?? doc.id;
              if (username.isNotEmpty) {
                liveUsernames[uid] = username;
                liveUsernames[doc.id] = username;
              }
            }
          }),
        );
      }

      final chunks = <List<String>>[];
      for (var i = 0; i < idList.length; i += 30) {
        chunks.add(idList.sublist(i, (i + 30).clamp(0, idList.length)));
      }
      await Future.wait(chunks.map(fetchChunk));

      if (liveUsernames.isEmpty) return;

      for (final entry in liveUsernames.entries) {
        final cached = _profileCache.get(entry.key);
        if (cached != null) {
          _profileCache.put(entry.key, {...cached, 'username': entry.value});
        }
      }

      final writeBatch = _firestore.batch();
      var dirtyCount = 0;

      for (final conv in conversations) {
        if (conv.id == null) continue;

        final storedUsernames = Map<String, String>.from(
          conv.participantUsernames,
        );
        final updatedUsernames = Map<String, String>.from(storedUsernames);
        var changed = false;

        for (final participantId in conv.participantIds) {
          final liveUsername = liveUsernames[participantId];
          if (liveUsername == null || liveUsername.isEmpty) continue;

          final storedUsername = storedUsernames[participantId] ?? '';
          if (storedUsername != liveUsername) {
            updatedUsernames[participantId] = liveUsername;
            changed = true;
          }
        }

        if (!changed) continue;

        writeBatch.update(_conversations.doc(conv.id), {
          'participant_usernames': updatedUsernames,
        });

        final corrected = ConversationModel(
          id: conv.id,
          type: conv.type,
          participantIds: conv.participantIds,
          participantUsernames: updatedUsernames,
          createdBy: conv.createdBy,
          createdAt: conv.createdAt,
          updatedAt: conv.updatedAt,
          lastMessage: conv.lastMessage,
          lastMessageAt: conv.lastMessageAt,
          lastMessageSenderId: conv.lastMessageSenderId,
          groupName: conv.groupName,
          groupPhoto: conv.groupPhoto,
          unreadCounts: conv.unreadCounts,
          isActive: conv.isActive,
        );
        unawaited(_cache.upsertConversation(corrected));

        dirtyCount++;
      }

      if (dirtyCount == 0) return;

      await writeBatch.commit();
    } catch (_) {}
  }

  Future<bool> checkUserExists(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final byDocId = await _profiles.doc(userId).get();
      if (byDocId.exists) return true;
      final byField = await _profiles
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      return byField.docs.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> recordToxicityStrike(String userId) async {
    try {
      final snap = await _profiles
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;

      final doc = snap.docs.first;
      final data = doc.data();
      final system = data['system'] as Map<String, dynamic>?;
      final flags = system?['flags'] as Map<String, dynamic>?;
      final currentStrikes = (flags?['toxicity_strikes'] as int?) ?? 0;
      final newStrikes = currentStrikes + 1;

      if (newStrikes >= 3) {
        await doc.reference.update({
          'system.flags.is_banned': true,
          'system.flags.ban_reason': 'toxic_behavior',
          'system.flags.toxicity_strikes': newStrikes,
          'system.flags.banned_at': FieldValue.serverTimestamp(),
        });
        return true;
      }

      await doc.reference.update({'system.flags.toxicity_strikes': newStrikes});
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> banUserForToxicity(
    String userId, {
    String? conversationId,
    String? toxicMessageId,
  }) async {
    final snap = await _profiles
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;

    final futures = <Future<void>>[
      snap.docs.first.reference.update({
        'system.flags.is_banned': true,
        'system.flags.ban_reason': 'toxic_behavior',
        'system.flags.banned_at': FieldValue.serverTimestamp(),
      }),
    ];

    if (conversationId != null && toxicMessageId != null) {
      futures.add(
        _messages(conversationId).doc(toxicMessageId).update({
          'is_deleted': true,
          'content':
              'This message was removed for violating community guidelines.',
        }),
      );
      futures.add(_cache.softDeleteMessage(toxicMessageId));
    }

    await Future.wait(futures);
  }

  Future<bool> isUserBanned(String userId) async {
    try {
      final snap = await _profiles
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;
      final data = snap.docs.first.data();
      final system = data['system'] as Map<String, dynamic>?;
      final flags = system?['flags'] as Map<String, dynamic>?;
      return flags?['is_banned'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<int> getToxicityStrikes(String userId) async {
    try {
      final snap = await _profiles
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return 0;
      final data = snap.docs.first.data();
      final system = data['system'] as Map<String, dynamic>?;
      final flags = system?['flags'] as Map<String, dynamic>?;
      return (flags?['toxicity_strikes'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    if (_profileCache.containsKey(userId)) return _profileCache.get(userId);
    try {
      final snap = await _profiles.doc(userId).get();
      if (snap.exists) {
        final flat = _flattenProfile(snap.id, snap.data()!);
        _profileCache.put(userId, flat);
        return flat;
      }
      final query = await _profiles
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final d = query.docs.first;
      final flat = _flattenProfile(d.id, d.data());
      _profileCache.put(userId, flat);
      return flat;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _flattenProfile(
    String docId,
    Map<String, dynamic> data,
  ) {
    final profileMap = data['profile'] as Map<String, dynamic>? ?? {};
    final resolvedUid = (data['user_id'] as String?)?.isNotEmpty == true
        ? data['user_id'] as String
        : docId;
    return {
      'id': docId,
      'user_id': resolvedUid,
      'username': data['username'] as String? ?? '',
      'full_name': profileMap['full_name'] as String? ?? '',
      'profile_photo': profileMap['profile_photo'] as String? ?? '',
    };
  }

  Stream<List<ConversationModel>> watchConversations(String userId) {
    late StreamController<List<ConversationModel>> controller;
    StreamSubscription<List<ConversationModel>>? firestoreSub;

    controller = StreamController<List<ConversationModel>>.broadcast(
      onListen: () async {
        try {
          final cached = await _cache.loadConversations();
          if (cached.isNotEmpty && !controller.isClosed) {
            controller.add(
              cached
                  .map(_conversationFromJson)
                  .whereType<ConversationModel>()
                  .toList(),
            );
          }
        } catch (_) {}

        final convStream = _conversations
            .where('participant_ids', arrayContains: userId)
            .where('is_active', isEqualTo: true)
            .snapshots();

        final presenceStream = _presence
            .where('is_online', isEqualTo: true)
            .snapshots()
            .map((snap) => snap.docs.map((d) => d.id).toSet());

        firestoreSub =
            Rx.combineLatest2<
                  QuerySnapshot<Map<String, dynamic>>,
                  Set<String>,
                  List<ConversationModel>
                >(convStream, presenceStream, (convSnap, onlineIds) {
                  final list = convSnap.docs
                      .map(ConversationModel.fromSnapshot)
                      .toList();

                  list.sort((a, b) {
                    final aOnline = a.participantIds.any(
                      (id) => id != userId && onlineIds.contains(id),
                    );
                    final bOnline = b.participantIds.any(
                      (id) => id != userId && onlineIds.contains(id),
                    );
                    if (aOnline != bOnline) return aOnline ? -1 : 1;
                    final aTime = a.lastMessageAt ?? a.createdAt;
                    final bTime = b.lastMessageAt ?? b.createdAt;
                    return bTime.compareTo(aTime);
                  });

                  _cache.upsertConversations(list);

                  unawaited(syncParticipantUsernames(list));

                  final buffer = StringBuffer();
                  buffer.writeln('Conversations Update: ${DateTime.now()}');
                  buffer.writeln('Total: ${list.length}');
                  for (final c in list) {
                    buffer.writeln(
                      'ID: ${c.id}, LastMsg: ${c.lastMessageAt}, Participants: ${c.participantIds}',
                    );
                  }
                  debugPrint(buffer.toString());

                  return list;
                })
                .listen(controller.add, onError: controller.addError);
      },
      onCancel: () => firestoreSub?.cancel(),
    );

    return controller.stream;
  }

  Future<ConversationModel?> getIndividualConversation(
    String userIdA,
    String userIdB,
  ) async {
    final snap = await _conversations
        .where('type', isEqualTo: 'individual')
        .where('participant_ids', arrayContains: userIdA)
        .where('is_active', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      final ids = List<String>.from(doc.data()['participant_ids'] ?? []);
      if (ids.contains(userIdB)) return ConversationModel.fromSnapshot(doc);
    }
    return null;
  }

  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String currentUsername,
    required String otherUserId,
    required String otherUsername,
  }) async {
    final existing = await getIndividualConversation(
      currentUserId,
      otherUserId,
    );
    if (existing != null) return existing;

    final now = DateTime.now();
    final model = ConversationModel(
      type: ConversationType.individual,
      participantIds: [currentUserId, otherUserId],
      participantUsernames: {
        currentUserId: currentUsername,
        otherUserId: otherUsername,
      },
      createdBy: currentUserId,
      createdAt: now,
      updatedAt: now,
      unreadCounts: {currentUserId: 0, otherUserId: 0},
      isActive: true,
    );
    final ref = await _conversations.add(model.toMap());
    final created = model.copyWith(id: ref.id);
    await _cache.upsertConversation(created);
    return created;
  }

  Future<ConversationModel> createGroupConversation({
    required String adminUserId,
    required String adminUsername,
    required String groupName,
    required List<String> memberIds,
    required Map<String, String> memberUsernames,
    String? groupPhoto,
  }) async {
    final now = DateTime.now();
    final allIds = [adminUserId, ...memberIds];
    final allUsernames = {adminUserId: adminUsername, ...memberUsernames};
    final model = ConversationModel(
      type: ConversationType.group,
      participantIds: allIds,
      participantUsernames: allUsernames,
      createdBy: adminUserId,
      createdAt: now,
      updatedAt: now,
      groupName: groupName,
      groupPhoto: groupPhoto,
      unreadCounts: {for (final id in allIds) id: 0},
      isActive: true,
    );
    final ref = await _conversations.add(model.toMap());
    final created = model.copyWith(id: ref.id);
    await _cache.upsertConversation(created);
    return created;
  }

  Future<void> addMembersToGroup({
    required String conversationId,
    required Map<String, String> newMembers,
  }) async {
    final snap = await _conversations.doc(conversationId).get();
    if (!snap.exists) return;
    final conv = ConversationModel.fromSnapshot(snap);
    await _conversations.doc(conversationId).update({
      'participant_ids': [...conv.participantIds, ...newMembers.keys],
      'participant_usernames': {...conv.participantUsernames, ...newMembers},
      'unread_counts': {
        ...conv.unreadCounts,
        for (final id in newMembers.keys) id: 0,
      },
    });
    final updated = await _conversations.doc(conversationId).get();
    if (updated.exists) {
      await _cache.upsertConversation(ConversationModel.fromSnapshot(updated));
    }
  }

  Future<void> removeMemberFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    final snap = await _conversations.doc(conversationId).get();
    if (!snap.exists) return;
    final conv = ConversationModel.fromSnapshot(snap);
    final updatedIds = conv.participantIds.where((id) => id != userId).toList();
    if (updatedIds.isEmpty) {
      await deleteConversation(conversationId);
      return;
    }
    final updatedUsernames = Map<String, String>.from(conv.participantUsernames)
      ..remove(userId);
    final updatedUnread = Map<String, int>.from(conv.unreadCounts)
      ..remove(userId);
    await _conversations.doc(conversationId).update({
      'participant_ids': updatedIds,
      'participant_usernames': updatedUsernames,
      'unread_counts': updatedUnread,
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    const batchSize = 400;
    while (true) {
      final snap = await _messages(conversationId).limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
    await _conversations.doc(conversationId).delete();
    await _cache.deleteConversation(conversationId);
  }

  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderUsername,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? mediaThumbnailUrl,
    int? mediaDurationSeconds,
    String? mediaFileName,
    int? mediaFileSize,
    required bool isFriend,
  }) {
    return _sendQueue.enqueue<ChatMessageModel>(conversationId, () async {
      if (!isFriend) {
        final sentCount = await _countMessagesBySender(
          conversationId,
          senderId,
        );
        if (sentCount >= 3) {
          throw const MessageLimitException(
            'You can only send 3 messages before the other person '
            'accepts your friend request.',
          );
        }
      }

      final preview = _lastMessagePreview(type, content, mediaFileName);

      final ref = await _messages(conversationId).add({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_username': senderUsername,
        'content': content,
        'type': type.name,
        'status': MessageStatus.sent.name,
        'sent_at': FieldValue.serverTimestamp(),
        'read_by': <String>[],
        'delivered_to': <String>[],
        'media_url': mediaUrl,
        'media_thumbnail_url': mediaThumbnailUrl,
        'media_duration_seconds': mediaDurationSeconds,
        'media_file_name': mediaFileName,
        'media_file_size': mediaFileSize,
        'is_deleted': false,
      });

      final savedSnap = await ref.get();
      final saved = ChatMessageModel.fromMap(savedSnap.data()!, id: ref.id);

      if (type == MessageType.text && ToxicityFilter.isToxic(content)) {
        await _messages(conversationId).doc(ref.id).update({
          'is_deleted': true,
          'content':
              'This message was removed for violating community guidelines.',
        });
        await _cache.softDeleteMessage(ref.id);

        final banned = await recordToxicityStrike(senderId);
        throw ToxicityException(
          banned
              ? 'Your account has been banned due to repeated toxic behavior.'
              : 'Your message was flagged as toxic.',
          banned: banned,
        );
      }

      await Future.wait([
        _updateConversationOnNewMessage(
          conversationId: conversationId,
          senderId: senderId,
          content: preview,
          sentAt: saved.sentAt,
        ),
        _cache.upsertMessages([saved]),
      ]);

      _broadcastNewMessage(conversationId, saved);
      return saved;
    });
  }

  String _lastMessagePreview(
    MessageType type,
    String content,
    String? fileName,
  ) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.audio:
        return '🎵 Voice message';
      case MessageType.video:
        return '🎬 Video';
      case MessageType.file:
        return '📎 ${fileName ?? 'File'}';
      case MessageType.call:
        return '📞 Call';
      default:
        return content;
    }
  }

  Future<int> _countMessagesBySender(
    String conversationId,
    String senderId,
  ) async {
    final snap = await _messages(conversationId)
        .where('sender_id', isEqualTo: senderId)
        .where('is_deleted', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  Future<void> _updateConversationOnNewMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required DateTime sentAt,
  }) async {
    final convSnap = await _conversations.doc(conversationId).get();
    if (!convSnap.exists) return;
    final conv = ConversationModel.fromSnapshot(convSnap);

    final updatedUnread = Map<String, int>.from(conv.unreadCounts);
    for (final pid in conv.participantIds) {
      if (pid != senderId) {
        updatedUnread[pid] = (updatedUnread[pid] ?? 0) + 1;
      }
    }

    await _conversations.doc(conversationId).update({
      'last_message': content,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_sender_id': senderId,
      'updated_at': FieldValue.serverTimestamp(),
      'unread_counts': updatedUnread,
    });
  }

  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    late StreamController<List<ChatMessageModel>> controller;
    StreamSubscription<List<ChatMessageModel>>? firestoreSub;

    controller = StreamController<List<ChatMessageModel>>.broadcast(
      onListen: () async {
        try {
          final cachedRaw = await _cache.loadMessages(conversationId);
          if (cachedRaw.isNotEmpty && !controller.isClosed) {
            final models = cachedRaw
                .map(_messageFromJson)
                .whereType<ChatMessageModel>()
                .toList();
            controller.add(models);
          }
        } catch (_) {}

        firestoreSub = _messages(conversationId)
            .orderBy('sent_at', descending: false)
            .snapshots()
            .map((snap) {
              final list = snap.docs
                  .map((d) => ChatMessageModel.fromMap(d.data(), id: d.id))
                  .toList();
              list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
              _cache.upsertMessages(list);
              return list;
            })
            .listen(controller.add, onError: controller.addError);
      },
      onCancel: () => firestoreSub?.cancel(),
    );

    return controller.stream;
  }

  Future<void> markAsRead(String conversationId, String userId) async {
    final snap = await _messages(
      conversationId,
    ).where('is_deleted', isEqualTo: false).get();

    final writeBatch = _firestore.batch();

    writeBatch.update(_conversations.doc(conversationId), {
      'unread_counts.$userId': 0,
    });

    for (final doc in snap.docs) {
      final readBy = List<String>.from(doc.data()['read_by'] ?? []);
      if (!readBy.contains(userId)) {
        readBy.add(userId);
        writeBatch.update(doc.reference, {'read_by': readBy, 'status': 'read'});
      }
    }

    await writeBatch.commit();
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _messages(conversationId).doc(messageId).update({
      'is_deleted': true,
      'content': 'This message was deleted.',
    });
    await _cache.softDeleteMessage(messageId);
  }

  Future<String> uploadChatMedia({
    required File file,
    required String senderId,
    required String folder,
  }) async {
    final result = await _storageRepository.uploadChatMedia(
      file: file,
      senderId: senderId,
      folder: folder,
    );
    if (result.isFailure) throw Exception(result.error);
    return result.data!;
  }

  Future<String> uploadThumbnail({
    required File thumbnailFile,
    required String senderId,
  }) async {
    final result = await _storageRepository.uploadThumbnail(
      thumbnailFile: thumbnailFile,
      senderId: senderId,
    );
    if (result.isFailure) throw Exception(result.error);
    return result.data!;
  }

  Future<String> uploadGroupPhoto({
    required File imageFile,
    required String adminUserId,
  }) async {
    try {
      final result = await _storageRepository.uploadGroupPhoto(
        imageFile: imageFile,
        adminUserId: adminUserId,
      );

      if (result.isFailure) {
        throw Exception(result.error);
      }

      final url = result.data!;

      if (url.isEmpty) {
        throw Exception('Empty URL returned from storage');
      }

      if (!url.contains('supabase.co/storage/v1/object/public/')) {}

      return url;
    } catch (e) {
      rethrow;
    }
  }

  Stream<String?> watchTypingUser(String conversationId) {
    final typingController = StreamController<String?>.broadcast();
    _typingChannel = _supabase
        .channel('typing:$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) =>
              typingController.add(payload['username'] as String?),
        )
        .subscribe();
    return typingController.stream;
  }

  Future<void> broadcastTyping(String conversationId, String username) =>
      _supabase
          .channel('typing:$conversationId')
          .sendBroadcastMessage(
            event: 'typing',
            payload: {'username': username},
          );

  void disposeTypingChannel() {
    _typingChannel?.unsubscribe();
    _typingChannel = null;
  }

  void _broadcastNewMessage(String conversationId, ChatMessageModel msg) {
    _supabase
        .channel('messages:$conversationId')
        .sendBroadcastMessage(
          event: 'new_message',
          payload: {
            'message_id': msg.id,
            'sender_id': msg.senderId,
            'sender_username': msg.senderUsername,
            'content': msg.content,
            'sent_at': msg.sentAt.toIso8601String(),
          },
        );
  }

  Future<({String docId, FriendRequestModel model})?> _getExistingRequestPair(
    String userIdA,
    String userIdB,
  ) async {
    final results = await Future.wait([
      _friendRequests
          .where('from_user_id', isEqualTo: userIdA)
          .where('to_user_id', isEqualTo: userIdB)
          .limit(1)
          .get(),
      _friendRequests
          .where('from_user_id', isEqualTo: userIdB)
          .where('to_user_id', isEqualTo: userIdA)
          .limit(1)
          .get(),
    ]);

    if (results[0].docs.isNotEmpty) {
      final doc = results[0].docs.first;
      return (docId: doc.id, model: FriendRequestModel.fromSnapshot(doc));
    }

    if (results[1].docs.isNotEmpty) {
      final doc = results[1].docs.first;
      return (docId: doc.id, model: FriendRequestModel.fromSnapshot(doc));
    }

    return null;
  }

  Future<bool> isBlockedBy(String blockerId, String currentUserId) async {
    final snap = await _friendRequests
        .where('from_user_id', isEqualTo: blockerId)
        .where('to_user_id', isEqualTo: currentUserId)
        .where('status', isEqualTo: FriendRequestStatus.blocked.name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<FriendRequestModel> sendFriendRequest({
    required String fromUserId,
    required String fromUsername,
    required String fromProfilePhoto,
    required String toUserId,
    required String toUsername,
  }) async {
    final alreadyFriends = await areFriends(fromUserId, toUserId);
    if (alreadyFriends) {
      throw const DuplicateFriendRequestException(
        'You are already friends with this user.',
      );
    }

    final existing = await _getExistingRequestPair(fromUserId, toUserId);
    if (existing != null &&
        existing.model.status == FriendRequestStatus.pending) {
      if (existing.model.fromUserId == fromUserId) {
        throw const DuplicateFriendRequestException(
          'You have already sent a friend request to this user.',
        );
      } else {
        throw const DuplicateFriendRequestException(
          'This user has already sent you a friend request. Accept it instead.',
        );
      }
    }

    final fromProfile = await getUserProfile(fromUserId);
    final fromFullName = fromProfile?['full_name'] as String? ?? '';

    final model = FriendRequestModel(
      fromUserId: fromUserId,
      fromUsername: fromUsername,
      fromFullName: fromFullName,
      fromProfilePhoto: fromProfilePhoto,
      toUserId: toUserId,
      toUsername: toUsername,
      status: FriendRequestStatus.pending,
      sentAt: DateTime.now(),
    );

    final ref = await _friendRequests.add(model.toMap());
    final created = FriendRequestModel.fromSnapshot(await ref.get());
    await FriendRequestNotificationService.instance.notify(created);
    return created;
  }

  Stream<List<FriendRequestModel>> watchIncomingRequests(String userId) =>
      _friendRequests
          .where('to_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map(
            (snap) => snap.docs.map(FriendRequestModel.fromSnapshot).toList(),
          );

  Stream<List<FriendRequestModel>> watchSentRequests(String userId) =>
      _friendRequests
          .where('from_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map(
            (snap) => snap.docs.map(FriendRequestModel.fromSnapshot).toList(),
          );

  Future<FriendRequestModel?> getRequestBetween(
    String userIdA,
    String userIdB,
  ) async {
    final existing = await _getExistingRequestPair(userIdA, userIdB);
    return existing?.model;
  }

  Future<bool> areFriends(String userIdA, String userIdB) async {
    final sortedIds = [userIdA, userIdB]..sort();
    final uid1 = sortedIds[0];
    final uid2 = sortedIds[1];

    final snap = await _friends
        .where('user_id_1', isEqualTo: uid1)
        .where('user_id_2', isEqualTo: uid2)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<void> respondToFriendRequest(
    String requestId,
    FriendRequestStatus newStatus,
  ) async {
    if (newStatus == FriendRequestStatus.accepted) {
      final reqSnap = await _friendRequests.doc(requestId).get();
      if (!reqSnap.exists) return;

      final req = FriendRequestModel.fromSnapshot(reqSnap);
      final sortedIds = [req.fromUserId, req.toUserId]..sort();
      final uid1 = sortedIds[0];
      final uid2 = sortedIds[1];

      final existingFriend = await _friends
          .where('user_id_1', isEqualTo: uid1)
          .where('user_id_2', isEqualTo: uid2)
          .limit(1)
          .get();

      final batch = _firestore.batch();
      batch.delete(_friendRequests.doc(requestId));

      if (existingFriend.docs.isEmpty) {
        final friendRef = _friends.doc();
        batch.set(friendRef, {
          'user_id_1': uid1,
          'user_id_2': uid2,
          'user_ids': [uid1, uid2],
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } else if (newStatus == FriendRequestStatus.rejected) {
      await _friendRequests.doc(requestId).delete();
    }
  }

  Future<void> removeFriend(String friendDocId) =>
      _friends.doc(friendDocId).delete();

  Future<String?> getFriendDocId(String userIdA, String userIdB) async {
    final sortedIds = [userIdA, userIdB]..sort();
    final uid1 = sortedIds[0];
    final uid2 = sortedIds[1];

    final snap = await _friends
        .where('user_id_1', isEqualTo: uid1)
        .where('user_id_2', isEqualTo: uid2)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> cancelFriendRequest(String requestId) =>
      _friendRequests.doc(requestId).delete();

  Future<void> unblockUser(String requestId) =>
      _friendRequests.doc(requestId).delete();

  Future<FriendRequestModel?> getBlockedRequest(
    String blockerId,
    String blockedId,
  ) async {
    final snap = await _friendRequests
        .where('from_user_id', isEqualTo: blockerId)
        .where('to_user_id', isEqualTo: blockedId)
        .where('status', isEqualTo: FriendRequestStatus.blocked.name)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FriendRequestModel.fromSnapshot(snap.docs.first);
  }

  Future<FriendRequestModel> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    final friendDocId = await getFriendDocId(blockerId, blockedId);
    if (friendDocId != null) {
      await _friends.doc(friendDocId).delete();
    }

    final existing = await _getExistingRequestPair(blockerId, blockedId);
    if (existing != null) {
      await _friendRequests.doc(existing.docId).delete();
    }

    final ref = await _friendRequests.add({
      'from_user_id': blockerId,
      'to_user_id': blockedId,
      'from_username': '',
      'from_full_name': '',
      'from_profile_photo': '',
      'to_username': '',
      'status': FriendRequestStatus.blocked.name,
      'sent_at': FieldValue.serverTimestamp(),
      'responded_at': null,
    });

    return FriendRequestModel.fromSnapshot(await ref.get());
  }

  Future<List<Map<String, dynamic>>> getFriendsList(String userId) async {
    final results = await Future.wait([
      _friends.where('user_id_1', isEqualTo: userId).get(),
      _friends.where('user_id_2', isEqualTo: userId).get(),
    ]);

    final friendEntries = <String, String>{};

    for (final doc in results[0].docs) {
      final otherId = doc.data()['user_id_2'] as String? ?? '';
      if (otherId.isNotEmpty) friendEntries[otherId] = doc.id;
    }

    for (final doc in results[1].docs) {
      final otherId = doc.data()['user_id_1'] as String? ?? '';
      if (otherId.isNotEmpty) friendEntries[otherId] = doc.id;
    }

    if (friendEntries.isEmpty) return [];

    final allFriendIds = friendEntries.keys.toList();
    final out = <Map<String, dynamic>>[];
    final foundIds = <String>{};

    Future<void> fetchChunk(List<String> chunk) async {
      final snap = await _profiles
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        final flat = _flattenProfile(d.id, d.data());
        final resolvedUid = flat['user_id'] as String;
        if (foundIds.add(d.id)) {
          foundIds.add(resolvedUid);
          out.add({
            ...flat,
            'friend_doc_id':
                friendEntries[d.id] ?? friendEntries[resolvedUid] ?? '',
          });
        }
      }
    }

    final chunks = <List<String>>[];
    for (var i = 0; i < allFriendIds.length; i += 30) {
      chunks.add(
        allFriendIds.sublist(i, (i + 30).clamp(0, allFriendIds.length)),
      );
    }
    await Future.wait(chunks.map(fetchChunk));

    final missing = allFriendIds.where((id) => !foundIds.contains(id)).toList();
    final missingChunks = <List<String>>[];
    for (var i = 0; i < missing.length; i += 10) {
      missingChunks.add(missing.sublist(i, (i + 10).clamp(0, missing.length)));
    }
    await Future.wait(
      missingChunks.map((chunk) async {
        final snap = await _profiles.where('user_id', whereIn: chunk).get();
        for (final d in snap.docs) {
          final flat = _flattenProfile(d.id, d.data());
          final resolvedUid = flat['user_id'] as String;
          if (foundIds.add(resolvedUid)) {
            foundIds.add(d.id);
            out.add({
              ...flat,
              'friend_doc_id':
                  friendEntries[resolvedUid] ?? friendEntries[d.id] ?? '',
            });
          }
        }
      }),
    );

    return out;
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(
    String conversationId,
  ) async {
    final snap = await _conversations.doc(conversationId).get();
    if (!snap.exists) return [];
    final conv = ConversationModel.fromSnapshot(snap);
    final memberIds = conv.participantIds;
    if (memberIds.isEmpty) return [];

    final out = <Map<String, dynamic>>[];
    final foundIds = <String>{};

    final chunks = <List<String>>[];
    for (var i = 0; i < memberIds.length; i += 30) {
      chunks.add(memberIds.sublist(i, (i + 30).clamp(0, memberIds.length)));
    }

    await Future.wait(
      chunks.map((chunk) async {
        final profileSnap = await _profiles
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in profileSnap.docs) {
          final flat = _flattenProfile(d.id, d.data());
          final resolvedUid = flat['user_id'] as String;
          if (foundIds.add(d.id)) {
            foundIds.add(resolvedUid);
            out.add({
              ...flat,
              'is_admin':
                  conv.createdBy == resolvedUid || conv.createdBy == d.id,
            });
          }
        }
      }),
    );

    final missing = memberIds.where((id) => !foundIds.contains(id)).toList();
    final missingChunks = <List<String>>[];
    for (var i = 0; i < missing.length; i += 10) {
      missingChunks.add(missing.sublist(i, (i + 10).clamp(0, missing.length)));
    }

    await Future.wait(
      missingChunks.map((chunk) async {
        final profileSnap = await _profiles
            .where('user_id', whereIn: chunk)
            .get();
        for (final d in profileSnap.docs) {
          final flat = _flattenProfile(d.id, d.data());
          final resolvedUid = flat['user_id'] as String;
          if (foundIds.add(resolvedUid)) {
            foundIds.add(d.id);
            out.add({
              ...flat,
              'is_admin':
                  conv.createdBy == resolvedUid || conv.createdBy == d.id,
            });
          }
        }
      }),
    );

    return out;
  }

  Future<List<Map<String, dynamic>>> searchUsersByUsername(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final snap = await _profiles
        .where('username', isEqualTo: q)
        .limit(limit)
        .get();
    return snap.docs.map((d) => _flattenProfile(d.id, d.data())).toList();
  }

  Future<void> setOnline(String userId) => _presence.doc(userId).set({
    'is_online': true,
    'last_seen': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> setOffline(String userId) => _presence.doc(userId).set({
    'is_online': false,
    'last_seen': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Stream<UserPresenceModel> watchPresence(String userId) {
    late StreamController<UserPresenceModel> controller;
    StreamSubscription<UserPresenceModel>? sub;

    controller = StreamController<UserPresenceModel>.broadcast(
      onListen: () async {
        try {
          final cached = await _cache.loadPresence(userId);
          if (cached != null && !controller.isClosed) controller.add(cached);
        } catch (_) {}

        sub = _presence
            .doc(userId)
            .snapshots()
            .map(
              (snap) => snap.exists
                  ? UserPresenceModel.fromSnapshot(snap)
                  : UserPresenceModel(
                      userId: userId,
                      isOnline: false,
                      lastSeen: DateTime.now(),
                    ),
            )
            .distinct()
            .listen((model) {
              _cache.upsertPresence(model);
              controller.add(model);
            }, onError: controller.addError);
      },
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }

  Stream<Map<String, UserPresenceModel>> watchPresenceForUsers(
    List<String> userIds,
  ) {
    if (userIds.isEmpty) return Stream.value({});
    return _presence
        .where(FieldPath.documentId, whereIn: userIds)
        .snapshots()
        .map((snap) {
          final result = <String, UserPresenceModel>{};
          for (final doc in snap.docs) {
            final model = UserPresenceModel.fromSnapshot(doc);
            result[doc.id] = model;
            _cache.upsertPresence(model);
          }
          for (final id in userIds) {
            result.putIfAbsent(
              id,
              () => UserPresenceModel(
                userId: id,
                isOnline: false,
                lastSeen: DateTime.now(),
              ),
            );
          }
          return result;
        });
  }

  Stream<int> watchTotalUnreadCount(String userId) => _conversations
      .where('participant_ids', arrayContains: userId)
      .where('is_active', isEqualTo: true)
      .snapshots()
      .map((snap) {
        var total = 0;
        for (final doc in snap.docs) {
          final counts = Map<String, dynamic>.from(
            doc.data()['unread_counts'] ?? {},
          );
          total += (counts[userId] as int?) ?? 0;
        }
        return total;
      });

  ConversationModel? _conversationFromJson(Map<String, dynamic> j) {
    try {
      return ConversationModel(
        id: j['id'] as String?,
        type: ConversationType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => ConversationType.individual,
        ),
        participantIds: List<String>.from(j['participant_ids'] ?? []),
        participantUsernames: Map<String, String>.from(
          j['participant_usernames'] ?? {},
        ),
        createdBy: j['created_by'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(j['updated_at'] as String? ?? '') ??
            DateTime.now(),
        lastMessage: j['last_message'] as String?,
        lastMessageAt: DateTime.tryParse(j['last_message_at'] as String? ?? ''),
        lastMessageSenderId: j['last_message_sender_id'] as String?,
        groupName: j['group_name'] as String?,
        groupPhoto: j['group_photo'] as String?,
        unreadCounts: Map<String, int>.from(j['unread_counts'] ?? {}),
        isActive: j['is_active'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  ChatMessageModel? _messageFromJson(Map<String, dynamic> j) {
    try {
      return ChatMessageModel.fromMap(j, id: j['id'] as String?);
    } catch (_) {
      return null;
    }
  }
}

class Rx {
  static Stream<R> combineLatest2<A, B, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    R Function(A, B) combiner,
  ) {
    late StreamController<R> controller;
    A? latestA;
    B? latestB;
    var hasA = false;
    var hasB = false;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;

    void emit() {
      if (hasA && hasB) controller.add(combiner(latestA as A, latestB as B));
    }

    controller = StreamController<R>.broadcast(
      onListen: () {
        subA = streamA.listen((a) {
          latestA = a;
          hasA = true;
          emit();
        }, onError: controller.addError);
        subB = streamB.listen((b) {
          latestB = b;
          hasB = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
      },
    );

    return controller.stream;
  }
}

class MessageLimitException implements Exception {
  const MessageLimitException(this.message);
  final String message;

  @override
  String toString() => 'MessageLimitException: $message';
}

class ToxicityException implements Exception {
  const ToxicityException(this.message, {this.banned = false});
  final String message;
  final bool banned;

  @override
  String toString() => 'ToxicityException: $message';
}

class DuplicateFriendRequestException implements Exception {
  const DuplicateFriendRequestException(this.message);
  final String message;

  @override
  String toString() => 'DuplicateFriendRequestException: $message';
}

class BusyException implements Exception {
  const BusyException(this.message);
  final String message;

  @override
  String toString() => 'BusyException: $message';
}

void unawaited(Future<void> future) {
  future.catchError((Object e, StackTrace st) {
    debugPrint('[unawaited] $e\n$st');
  });
}
