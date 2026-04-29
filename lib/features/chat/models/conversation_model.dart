import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';

class ConversationModel {
  const ConversationModel({
    this.id,
    required this.type,
    required this.participantIds,
    required this.participantUsernames,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.groupName,
    this.groupPhoto,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
    this.isActive = true,
  });

  final String? id;
  final ConversationType type;
  final List<String> participantIds;
  final Map<String, String> participantUsernames;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupName;
  final String? groupPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final bool isActive;

  static ConversationModel fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data()!;
    return ConversationModel(
      id: snap.id,
      type: ConversationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'individual'),
        orElse: () => ConversationType.individual,
      ),
      participantIds: List<String>.from(data['participant_ids'] ?? []),
      participantUsernames: Map<String, String>.from(
        data['participant_usernames'] ?? {},
      ),
      createdBy: data['created_by'] as String? ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      groupName: data['group_name'] as String?,
      groupPhoto: data['group_photo'] as String?,
      lastMessage: data['last_message'] as String?,
      lastMessageAt: (data['last_message_at'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['last_message_sender_id'] as String?,
      unreadCounts: Map<String, int>.from(data['unread_counts'] ?? {}),
      isActive: data['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'participant_ids': participantIds,
    'participant_usernames': participantUsernames,
    'created_by': createdBy,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    'group_name': groupName,
    'group_photo': groupPhoto,
    'last_message': lastMessage,
    'last_message_at':
        lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
    'last_message_sender_id': lastMessageSenderId,
    'unread_counts': unreadCounts,
    'is_active': isActive,
  };

  ConversationModel copyWith({
    String? id,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    Map<String, int>? unreadCounts,
    DateTime? updatedAt,
    List<String>? participantIds,
    Map<String, String>? participantUsernames,
  }) =>
      ConversationModel(
        id: id ?? this.id,
        type: type,
        participantIds: participantIds ?? this.participantIds,
        participantUsernames: participantUsernames ?? this.participantUsernames,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        groupName: groupName,
        groupPhoto: groupPhoto,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        isActive: isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt &&
          lastMessage == other.lastMessage &&
          unreadCounts == other.unreadCounts;

  @override
  int get hashCode => Object.hash(id, updatedAt, lastMessage);
}