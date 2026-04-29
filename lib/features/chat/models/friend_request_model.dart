import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';

class FriendRequestModel {
  const FriendRequestModel({
    this.id,
    required this.fromUserId,
    required this.fromUsername,
    this.fromFullName = '',
    required this.fromProfilePhoto,
    required this.toUserId,
    required this.toUsername,
    required this.status,
    required this.sentAt,
    this.respondedAt,
  });

  final String? id;
  final String fromUserId;
  final String fromUsername;
  final String fromFullName;
  final String fromProfilePhoto;
  final String toUserId;
  final String toUsername;
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;

  static FriendRequestModel fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data()!;
    return FriendRequestModel(
      id: snap.id,
      fromUserId: data['from_user_id'] as String? ?? '',
      fromUsername: data['from_username'] as String? ?? '',
      fromFullName: data['from_full_name'] as String? ?? '',
      fromProfilePhoto: data['from_profile_photo'] as String? ?? '',
      toUserId: data['to_user_id'] as String? ?? '',
      toUsername: data['to_username'] as String? ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['responded_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'from_user_id': fromUserId,
    'from_username': fromUsername,
    'from_full_name': fromFullName,
    'from_profile_photo': fromProfilePhoto,
    'to_user_id': toUserId,
    'to_username': toUsername,
    'status': status.name,
    'sent_at': Timestamp.fromDate(sentAt),
    'responded_at':
        respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
  };
}