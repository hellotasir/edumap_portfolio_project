import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';

typedef SearchUsersParams = ({String query, int? limit});
typedef GetProfileParams = ({String userId});
typedef GetFriendsListParams = ({String userId});
typedef GetGroupMembersParams = ({String conversationId});
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

enum AiTool {
  searchUsers,
  getUserProfile,
  getFriendsList,
  getGroupMembers,
  sendMessage,
  sendFriendRequest,
  respondToFriendRequest,
  cancelFriendRequest,
  areFriends,
  getIndividualConversation,
  createIndividualConversation,
  deleteMessage,
}

extension AiToolMeta on AiTool {
  String get toolName => switch (this) {
        AiTool.searchUsers => 'search_users',
        AiTool.getUserProfile => 'get_user_profile',
        AiTool.getFriendsList => 'get_friends_list',
        AiTool.getGroupMembers => 'get_group_members',
        AiTool.sendMessage => 'send_message',
        AiTool.sendFriendRequest => 'send_friend_request',
        AiTool.respondToFriendRequest => 'respond_to_friend_request',
        AiTool.cancelFriendRequest => 'cancel_friend_request',
        AiTool.areFriends => 'are_friends',
        AiTool.getIndividualConversation => 'get_individual_conversation',
        AiTool.createIndividualConversation => 'create_individual_conversation',
        AiTool.deleteMessage => 'delete_message',
      };

  String get description => switch (this) {
        AiTool.searchUsers => 'Search for users by username. Returns a list of matching profiles.',
        AiTool.getUserProfile => 'Fetch a single user profile by their userId.',
        AiTool.getFriendsList => 'Get all friends of a given userId with their profile info.',
        AiTool.getGroupMembers => 'Get all members of a group conversation.',
        AiTool.sendMessage => 'Send a text message in an existing conversation.',
        AiTool.sendFriendRequest => 'Send a friend request to another user.',
        AiTool.respondToFriendRequest => 'Accept or decline an incoming friend request.',
        AiTool.cancelFriendRequest => 'Cancel a previously sent friend request.',
        AiTool.areFriends => 'Check whether two users are already friends.',
        AiTool.getIndividualConversation => 'Find an existing 1-to-1 conversation between two users.',
        AiTool.createIndividualConversation => 'Create a new 1-to-1 conversation between two users.',
        AiTool.deleteMessage => 'Soft-delete a message (marks it as deleted, content replaced).',
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
        AiTool.getGroupMembers => {
            'type': 'object',
            'properties': {
              'conversationId': {'type': 'string'},
            },
            'required': ['conversationId'],
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
                'description': 'Whether sender and recipient are already friends. Non-friends can only send 3 messages.',
              },
            },
            'required': ['conversationId', 'senderId', 'senderUsername', 'content', 'isFriend'],
          },
        AiTool.sendFriendRequest => {
            'type': 'object',
            'properties': {
              'fromUserId': {'type': 'string'},
              'fromUsername': {'type': 'string'},
              'fromProfilePhoto': {'type': 'string'},
              'toUserId': {'type': 'string'},
              'toUsername': {'type': 'string'},
            },
            'required': ['fromUserId', 'fromUsername', 'fromProfilePhoto', 'toUserId', 'toUsername'],
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
        AiTool.areFriends => {
            'type': 'object',
            'properties': {
              'userIdA': {'type': 'string'},
              'userIdB': {'type': 'string'},
            },
            'required': ['userIdA', 'userIdB'],
          },
        AiTool.getIndividualConversation => {
            'type': 'object',
            'properties': {
              'userIdA': {'type': 'string'},
              'userIdB': {'type': 'string'},
            },
            'required': ['userIdA', 'userIdB'],
          },
        AiTool.createIndividualConversation => {
            'type': 'object',
            'properties': {
              'currentUserId': {'type': 'string'},
              'currentUsername': {'type': 'string'},
              'otherUserId': {'type': 'string'},
              'otherUsername': {'type': 'string'},
            },
            'required': ['currentUserId', 'currentUsername', 'otherUserId', 'otherUsername'],
          },
        AiTool.deleteMessage => {
            'type': 'object',
            'properties': {
              'conversationId': {'type': 'string'},
              'messageId': {'type': 'string'},
            },
            'required': ['conversationId', 'messageId'],
          },
      };
}

class AiToolExecutor {
  const AiToolExecutor(this._chat);

  final ChatRepository _chat;

  Future<Map<String, dynamic>> execute(String toolName, Map<String, dynamic> args) async {
    final tool = AiTool.values.firstWhere(
      (t) => t.toolName == toolName,
      orElse: () => throw ArgumentError('Unknown tool: $toolName'),
    );

    return switch (tool) {
      AiTool.searchUsers => _searchUsers(args),
      AiTool.getUserProfile => _getUserProfile(args),
      AiTool.getFriendsList => _getFriendsList(args),
      AiTool.getGroupMembers => _getGroupMembers(args),
      AiTool.sendMessage => _sendMessage(args),
      AiTool.sendFriendRequest => _sendFriendRequest(args),
      AiTool.respondToFriendRequest => _respondToFriendRequest(args),
      AiTool.cancelFriendRequest => _cancelFriendRequest(args),
      AiTool.areFriends => _areFriends(args),
      AiTool.getIndividualConversation => _getIndividualConversation(args),
      AiTool.createIndividualConversation => _createIndividualConversation(args),
      AiTool.deleteMessage => _deleteMessage(args),
    };
  }

  Future<Map<String, dynamic>> _searchUsers(Map<String, dynamic> a) async {
    final results = await _chat.searchUsersByUsername(
      a['query'] as String,
      limit: (a['limit'] as int?) ?? 20,
    );
    return {'users': results};
  }

  Future<Map<String, dynamic>> _getUserProfile(Map<String, dynamic> a) async {
    final profile = await _chat.getUserProfile(a['userId'] as String);
    return {'profile': profile};
  }

  Future<Map<String, dynamic>> _getFriendsList(Map<String, dynamic> a) async {
    final friends = await _chat.getFriendsList(a['userId'] as String);
    return {'friends': friends};
  }

  Future<Map<String, dynamic>> _getGroupMembers(Map<String, dynamic> a) async {
    final members = await _chat.getGroupMembers(a['conversationId'] as String);
    return {'members': members};
  }

  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> a) async {
    final msg = await _chat.sendMessage(
      conversationId: a['conversationId'] as String,
      senderId: a['senderId'] as String,
      senderUsername: a['senderUsername'] as String,
      content: a['content'] as String,
      isFriend: a['isFriend'] as bool,
    );
    return {'success': true, 'messageId': msg.id, 'sentAt': msg.sentAt.toIso8601String()};
  }

  Future<Map<String, dynamic>> _sendFriendRequest(Map<String, dynamic> a) async {
    final req = await _chat.sendFriendRequest(
      fromUserId: a['fromUserId'] as String,
      fromUsername: a['fromUsername'] as String,
      fromProfilePhoto: a['fromProfilePhoto'] as String,
      toUserId: a['toUserId'] as String,
      toUsername: a['toUsername'] as String,
    );
    return {'success': true, 'requestId': req.id};
  }

  Future<Map<String, dynamic>> _respondToFriendRequest(Map<String, dynamic> a) async {
    final status = a['response'] == 'accepted'
        ? FriendRequestStatus.accepted
        : FriendRequestStatus.rejected;
    await _chat.respondToFriendRequest(a['requestId'] as String, status);
    return {'success': true, 'status': a['response']};
  }

  Future<Map<String, dynamic>> _cancelFriendRequest(Map<String, dynamic> a) async {
    await _chat.cancelFriendRequest(a['requestId'] as String);
    return {'success': true};
  }

  Future<Map<String, dynamic>> _areFriends(Map<String, dynamic> a) async {
    final result = await _chat.areFriends(a['userIdA'] as String, a['userIdB'] as String);
    return {'areFriends': result};
  }

  Future<Map<String, dynamic>> _getIndividualConversation(Map<String, dynamic> a) async {
    final conv = await _chat.getIndividualConversation(
      a['userIdA'] as String,
      a['userIdB'] as String,
    );
    if (conv == null) return {'found': false};
    return {'found': true, 'conversationId': conv.id, 'participantIds': conv.participantIds};
  }

  Future<Map<String, dynamic>> _createIndividualConversation(Map<String, dynamic> a) async {
    final conv = await _chat.createIndividualConversation(
      currentUserId: a['currentUserId'] as String,
      currentUsername: a['currentUsername'] as String,
      otherUserId: a['otherUserId'] as String,
      otherUsername: a['otherUsername'] as String,
    );
    return {'success': true, 'conversationId': conv.id};
  }

  Future<Map<String, dynamic>> _deleteMessage(Map<String, dynamic> a) async {
    await _chat.deleteMessage(a['conversationId'] as String, a['messageId'] as String);
    return {'success': true};
  }
}