import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/features/feedback/models/feedback_model.dart';
import 'package:flutter_education_app/features/app/repositories/database_repository.dart';

class FeedbackRepository implements DatabaseRepository<FeedbackModel> {
  const FeedbackRepository();

  static const _userId = 'user_id';
  static const _userName = 'userName';
  static const _category = 'category';
  static const _rating = 'rating';
  static const _message = 'message';
  static const _createdAt = 'createdAt';

  static const _defaultUserName = 'Anonymous';
  static const _defaultCategory = 'general';
  static const _defaultRating = 1;

  @override
  List<String> get collectionPath => ['feedback'];

  @override
  FeedbackModel fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (data == null) {
      throw StateError(
        'FeedbackRepository.fromSnapshot: document ${snapshot.id} has no data.',
      );
    }

    final rawRating = (data[_rating] as num?)?.toInt() ?? _defaultRating;
    final safeRating = rawRating.clamp(1, 5);

    return FeedbackModel(
      id: snapshot.id,
      user_id: (data[_userId] as String?)?.trim() ?? '',
      userName:
          (data[_userName] as String?)?.trim().isNotEmpty == true
              ? (data[_userName] as String).trim()
              : _defaultUserName,
      category:
          (data[_category] as String?)?.trim().isNotEmpty == true
              ? (data[_category] as String).trim()
              : _defaultCategory,
      rating: safeRating,
      message: (data[_message] as String?)?.trim() ?? '',
      createdAt: (data[_createdAt] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  Map<String, dynamic> toMap(FeedbackModel model) => {
        _userId: model.user_id,
        _userName: model.userName,
        _category: model.category,
        _rating: model.rating,
        _message: model.message,
        _createdAt: Timestamp.fromDate(model.createdAt),
      };
}