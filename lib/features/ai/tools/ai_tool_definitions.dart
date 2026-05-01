import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';

typedef SearchUsersParams = ({String query, int? limit});
typedef GetProfileParams = ({String userId});
typedef GetFriendsListParams = ({String userId});
typedef SendMessageParams = ({
  String conversationId,
  String senderId,
  String senderUsername,
  String content,
  bool isFriend,
});
typedef SendFriendRequestParams = ({
  String fromUserId,
  String fromUsername,
  String fromProfilePhoto,
  String toUserId,
  String toUsername,
});
typedef RespondFriendRequestParams = ({String requestId, String response});
typedef CancelFriendRequestParams = ({String requestId});
typedef AreFriendsParams = ({String userIdA, String userIdB});
typedef GetIndividualConversationParams = ({String userIdA, String userIdB});
typedef CreateIndividualConversationParams = ({
  String currentUserId,
  String currentUsername,
  String otherUserId,
  String otherUsername,
});

typedef IsUserBannedParams = ({String userId});
typedef IsBlockedByParams = ({String blockerId, String currentUserId});
typedef IsConversationBusyParams = ({String conversationId});
typedef GetUserPresenceParams = ({String userId});
typedef CheckUserExistsParams = ({String userId});

enum AiTool {
  searchUsers,
  getUserProfile,
  getFriendsList,
  sendMessage,
  sendFriendRequest,
  respondToFriendRequest,
  cancelFriendRequest,
  getSentFriendRequests,
  getIncomingFriendRequests,
  areFriends,
  getIndividualConversation,
  createIndividualConversation,
  deleteMessage,

  isUserBanned,
  isBlockedBy,
  isConversationBusy,
  getUserPresence,
  checkUserExists,
}

extension AiToolMeta on AiTool {
  String get toolName => switch (this) {
        AiTool.searchUsers => 'search_users',
        AiTool.getUserProfile => 'get_user_profile',
    AiTool.getFriendsList => 'get_friends_list',
        AiTool.sendMessage => 'send_message',
        AiTool.sendFriendRequest => 'send_friend_request',
        AiTool.respondToFriendRequest => 'respond_to_friend_request',
        AiTool.cancelFriendRequest => 'cancel_friend_request',
    AiTool.getSentFriendRequests => 'get_sent_friend_requests',
    AiTool.getIncomingFriendRequests => 'get_incoming_friend_requests',
        AiTool.areFriends => 'are_friends',
        AiTool.getIndividualConversation => 'get_individual_conversation',
        AiTool.createIndividualConversation => 'create_individual_conversation',
        AiTool.deleteMessage => 'delete_message',
    AiTool.isUserBanned => 'is_user_banned',
    AiTool.isBlockedBy => 'is_blocked_by',
    AiTool.isConversationBusy => 'is_conversation_busy',
    AiTool.getUserPresence => 'get_user_presence',
    AiTool.checkUserExists => 'check_user_exists',
      };

  String get description => switch (this) {
    AiTool.searchUsers =>
      'Search for users by username. Returns a list of matching profiles.',
    AiTool.getUserProfile => 'Fetch a single user profile by their userId.',
    AiTool.getFriendsList =>
      'Get all friends of a given userId with their profile info.',
    AiTool.sendMessage => 'Send a text message in an existing conversation.',
    AiTool.sendFriendRequest => 'Send a friend request to another user.',
    AiTool.respondToFriendRequest =>
      'Accept or decline an incoming friend request.',
    AiTool.cancelFriendRequest => 'Cancel a previously sent friend request.',
    AiTool.getSentFriendRequests =>
      'Get all pending friend requests the current user has sent. '
          'Always call this first to get the requestId before cancelling a request.',
    AiTool.getIncomingFriendRequests =>
      'Get all pending friend requests the current user has received. '
          'Always call this first to get the requestId before accepting or declining a request.',
    AiTool.areFriends => 'Check whether two users are already friends.',
    AiTool.getIndividualConversation =>
      'Find an existing 1-to-1 conversation between two users.',
    AiTool.createIndividualConversation =>
      'Create a new 1-to-1 conversation between two users.',
    AiTool.deleteMessage =>
      'Soft-delete a message (marks it as deleted, content replaced).',
    AiTool.isUserBanned =>
      'Check whether a user account is currently banned. '
          'Call this before sending friend requests or messages to another user '
          'to avoid unnecessary errors.',
    AiTool.isBlockedBy =>
      'Check whether a specific user (blockerId) has blocked the current user. '
          'Call this before attempting to message or friend-request someone.',
    AiTool.isConversationBusy =>
      'Check whether a conversation already has a pending send operation in '
          'flight. Returns true if the user should wait before sending another '
          'message to avoid a BusyException.',
    AiTool.getUserPresence =>
      'Get the online/offline status and last-seen time of a user. '
          'Useful before suggesting to start a chat ("they are online now!").',
    AiTool.checkUserExists =>
      'Verify that a userId actually exists in the system before '
          'performing any action that requires a valid user.',
      };

  Map<String, dynamic> get parametersSchema => switch (this) {
        AiTool.searchUsers => {
            'type': 'object',
            'properties': {
        'query': {'type': 'string', 'description': 'Username search query'},
        'limit': {'type': 'integer', 'description': 'Max results (default 20)'},
            },
            'required': ['query'],
          },
        AiTool.getUserProfile => {
            'type': 'object',
            'properties': {
              'userId': {'type': 'string'},
            },
            'required': ['userId'],
          },
        AiTool.getFriendsList => {
            'type': 'object',
            'properties': {
              'userId': {'type': 'string'},
            },
            'required': ['userId'],
    },
        AiTool.sendMessage => {
            'type': 'object',
            'properties': {
              'conversationId': {'type': 'string'},
              'senderId': {'type': 'string'},
              'senderUsername': {'type': 'string'},
              'content': {'type': 'string'},
              'isFriend': {
                'type': 'boolean',
          'description':
              'Whether sender and recipient are already friends. '
              'Non-friends can only send 3 messages.',
              },
            },
      'required': [
        'conversationId',
        'senderId',
        'senderUsername',
        'content',
        'isFriend',
      ],
          },
        AiTool.sendFriendRequest => {
            'type': 'object',
            'properties': {
              'fromUserId': {'type': 'string'},
              'fromUsername': {'type': 'string'},
        'fromProfilePhoto': {'type': 'string'},
              'toUsername': {'type': 'string'},
            },
      'required': [
        'fromUserId',
        'fromUsername',
        'fromProfilePhoto',
        'toUsername',
      ],
          },
        AiTool.respondToFriendRequest => {
            'type': 'object',
            'properties': {
              'requestId': {'type': 'string'},
              'response': {
                'type': 'string',
                'enum': ['accepted', 'declined'],
              },
            },
            'required': ['requestId', 'response'],
          },
        AiTool.cancelFriendRequest => {
            'type': 'object',
            'properties': {
              'requestId': {'type': 'string'},
            },
            'required': ['requestId'],
          },
    AiTool.getSentFriendRequests => {
      'type': 'object',
      'properties': {
        'userId': {'type': 'string'},
      },
      'required': ['userId'],
    },
    AiTool.getIncomingFriendRequests => {
      'type': 'object',
      'properties': {
        'userId': {'type': 'string'},
      },
      'required': ['userId'],
    },
        AiTool.areFriends => {
            'type': 'object',
            'properties': {
        'currentUserId': {'type': 'string'},
        'otherUsername': {'type': 'string'},
            },
      'required': ['currentUserId', 'otherUsername'],
          },
        AiTool.getIndividualConversation => {
            'type': 'object',
            'properties': {
        'currentUserId': {'type': 'string'},
        'otherUsername': {'type': 'string'},
            },
      'required': ['currentUserId', 'otherUsername'],
          },
        AiTool.createIndividualConversation => {
            'type': 'object',
            'properties': {
              'currentUserId': {'type': 'string'},
              'currentUsername': {'type': 'string'},
              'otherUserId': {'type': 'string'},
              'otherUsername': {'type': 'string'},
            },
      'required': [
        'currentUserId',
        'currentUsername',
        'otherUserId',
        'otherUsername',
      ],
          },
        AiTool.deleteMessage => {
            'type': 'object',
            'properties': {
              'conversationId': {'type': 'string'},
              'messageId': {'type': 'string'},
            },
            'required': ['conversationId', 'messageId'],
          },
    AiTool.isUserBanned => {
      'type': 'object',
      'properties': {
        'userId': {
          'type': 'string',
          'description': 'The userId to check ban status for.',
        },
      },
      'required': ['userId'],
    },
    AiTool.isBlockedBy => {
      'type': 'object',
      'properties': {
        'blockerId': {
          'type': 'string',
          'description': 'The userId of the person who may have blocked.',
        },
        'currentUserId': {
          'type': 'string',
          'description': 'The userId of the current user.',
        },
      },
      'required': ['blockerId', 'currentUserId'],
    },
    AiTool.isConversationBusy => {
      'type': 'object',
      'properties': {
        'conversationId': {
          'type': 'string',
          'description': 'The conversation to check for pending sends.',
        },
      },
      'required': ['conversationId'],
    },
    AiTool.getUserPresence => {
      'type': 'object',
      'properties': {
        'userId': {
          'type': 'string',
          'description': 'The userId whose presence to fetch.',
        },
      },
      'required': ['userId'],
    },
    AiTool.checkUserExists => {
      'type': 'object',
      'properties': {
        'userId': {
          'type': 'string',
          'description': 'The userId to verify exists.',
        },
      },
      'required': ['userId'],
    },
      };
}

class AiToolExecutor {
  const AiToolExecutor(this._chat);

  final ChatRepository _chat;

  Future<Map<String, dynamic>> execute(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    final tool = AiTool.values.firstWhere(
      (t) => t.toolName == toolName,
      orElse: () => throw ArgumentError('Unknown tool: $toolName'),
    );

    return switch (tool) {
      AiTool.searchUsers => _searchUsers(args),
      AiTool.getUserProfile => _getUserProfile(args),
      AiTool.getFriendsList => _getFriendsList(args),
      AiTool.sendMessage => _sendMessage(args),
      AiTool.sendFriendRequest => _sendFriendRequest(args),
      AiTool.respondToFriendRequest => _respondToFriendRequest(args),
      AiTool.cancelFriendRequest => _cancelFriendRequest(args),
      AiTool.getSentFriendRequests => _getSentFriendRequests(args),
      AiTool.getIncomingFriendRequests => _getIncomingFriendRequests(args),
      AiTool.areFriends => _areFriends(args),
      AiTool.getIndividualConversation => _getIndividualConversation(args),
      AiTool.createIndividualConversation => _createIndividualConversation(
        args,
      ),
      AiTool.deleteMessage => _deleteMessage(args),
      AiTool.isUserBanned => _isUserBanned(args),
      AiTool.isBlockedBy => _isBlockedBy(args),
      AiTool.isConversationBusy => _isConversationBusy(args),
      AiTool.getUserPresence => _getUserPresence(args),
      AiTool.checkUserExists => _checkUserExists(args),
    };
  }

  Future<Map<String, dynamic>> _searchUsers(Map<String, dynamic> a) async {
    final results = await _chat.searchUsersByUsername(
      a['query'] as String,
      limit: (a['limit'] as int?) ?? 20,
    );
    return {
      'users': results
          .map((u) => {'username': u['username'], 'full_name': u['full_name']})
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _getUserProfile(Map<String, dynamic> a) async {
    final profile = await _chat.getUserProfile(a['userId'] as String);
    if (profile == null) return {'profile': null};
    return {
      'profile': {
        'username': profile['username'],
        'full_name': profile['full_name'],
      },
    };
  }

  Future<Map<String, dynamic>> _getFriendsList(Map<String, dynamic> a) async {
    final friends = await _chat.getFriendsList(a['userId'] as String);
    return {
      'friends': friends
          .map((f) => {'username': f['username'], 'full_name': f['full_name']})
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> a) async {
    final msg = await _chat.sendMessage(
      conversationId: a['conversationId'] as String,
      senderId: a['senderId'] as String,
      senderUsername: a['senderUsername'] as String,
      content: a['content'] as String,
      isFriend: a['isFriend'] as bool,
    );
    return {
      'success': true,
      'messageId': msg.id,
      'sentAt': msg.sentAt.toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _sendFriendRequest(
    Map<String, dynamic> a,
  ) async {
    final toUsername = a['toUsername'] as String;
    final candidates = await _chat.searchUsersByUsername(toUsername, limit: 1);
    if (candidates.isEmpty) {
      return {'success': false, 'error': 'User not found.'};
    }
    final target = candidates.first;
    final toUserId =
        target['user_id'] as String? ?? target['id'] as String? ?? '';
    if (toUserId.isEmpty) {
      return {'success': false, 'error': 'Could not resolve user.'};
    }
    final req = await _chat.sendFriendRequest(
      fromUserId: a['fromUserId'] as String,
      fromUsername: a['fromUsername'] as String,
      fromProfilePhoto: a['fromProfilePhoto'] as String,
      toUserId: toUserId,
      toUsername: toUsername,
    );
    return {'success': true, 'requestId': req.id};
  }

  Future<Map<String, dynamic>> _respondToFriendRequest(
    Map<String, dynamic> a,
  ) async {
    final status = a['response'] == 'accepted'
        ? FriendRequestStatus.accepted
        : FriendRequestStatus.rejected;
    await _chat.respondToFriendRequest(a['requestId'] as String, status);
    return {'success': true, 'status': a['response']};
  }

  Future<Map<String, dynamic>> _cancelFriendRequest(
    Map<String, dynamic> a,
  ) async {
    await _chat.cancelFriendRequest(a['requestId'] as String);
    return {'success': true};
  }

  Future<Map<String, dynamic>> _getSentFriendRequests(
    Map<String, dynamic> a,
  ) async {
    final requests = await _chat
        .watchSentRequests(a['userId'] as String)
        .first
        .timeout(const Duration(seconds: 5));
    return {
      'requests': requests
          .map(
            (r) => {
              'requestId': r.id,
              'toUsername': r.toUsername,
              'sentAt': r.sentAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _getIncomingFriendRequests(
    Map<String, dynamic> a,
  ) async {
    final requests = await _chat
        .watchIncomingRequests(a['userId'] as String)
        .first
        .timeout(const Duration(seconds: 5));
    return {
      'requests': requests
          .map(
            (r) => {
              'requestId': r.id,
              'fromUsername': r.fromUsername,
              'sentAt': r.sentAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _areFriends(Map<String, dynamic> a) async {
    final result = await _chat.areFriends(
      a['userIdA'] as String,
      a['userIdB'] as String,
    );
    return {'areFriends': result};
  }

  Future<Map<String, dynamic>> _getIndividualConversation(
    Map<String, dynamic> a,
  ) async {
    final conv = await _chat.getIndividualConversation(
      a['userIdA'] as String,
      a['userIdB'] as String,
    );
    if (conv == null) return {'found': false};
    return {
      'found': true,
      'conversationId': conv.id,
    };
  }

  Future<Map<String, dynamic>> _createIndividualConversation(
    Map<String, dynamic> a,
  ) async {
    final conv = await _chat.createIndividualConversation(
      currentUserId: a['currentUserId'] as String,
      currentUsername: a['currentUsername'] as String,
      otherUserId: a['otherUserId'] as String,
      otherUsername: a['otherUsername'] as String,
    );
    return {'success': true, 'conversationId': conv.id};
  }

  Future<Map<String, dynamic>> _deleteMessage(Map<String, dynamic> a) async {
    await _chat.deleteMessage(
      a['conversationId'] as String,
      a['messageId'] as String,
    );
    return {'success': true};
  }

  Future<Map<String, dynamic>> _isUserBanned(Map<String, dynamic> a) async {
    final banned = await _chat.isUserBanned(a['userId'] as String);
    return {'isBanned': banned};
  }

  Future<Map<String, dynamic>> _isBlockedBy(Map<String, dynamic> a) async {
    final blocked = await _chat.isBlockedBy(
      a['blockerId'] as String,
      a['currentUserId'] as String,
    );
    return {'isBlocked': blocked};
  }

  Future<Map<String, dynamic>> _isConversationBusy(
    Map<String, dynamic> a,
  ) async {
    final busy = _chat.isConversationBusy(a['conversationId'] as String);
    return {'isBusy': busy};
  }

  Future<Map<String, dynamic>> _getUserPresence(Map<String, dynamic> a) async {
    final userId = a['userId'] as String;
    try {
      final presence = await _chat
          .watchPresence(userId)
          .first
          .timeout(const Duration(seconds: 5));
      return {
        'userId': presence.userId,
        'isOnline': presence.isOnline,
        'lastSeen': presence.lastSeen.toIso8601String(),
      };
    } catch (_) {
      return {
        'userId': userId,
        'isOnline': false,
        'lastSeen': null,
        'error': 'Could not determine presence.',
      };
    }
  }

  Future<Map<String, dynamic>> _checkUserExists(Map<String, dynamic> a) async {
    final exists = await _chat.checkUserExists(a['userId'] as String);
    return {'exists': exists};
  }
}