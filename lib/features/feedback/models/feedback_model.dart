import 'package:flutter/foundation.dart';

@immutable
class FeedbackModel {
  const FeedbackModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.rating,
    required this.message,
    required this.createdAt,
  }) : assert(userId != '', 'userId must not be empty'),
       assert(rating >= 1 && rating <= 5, 'rating must be between 1 and 5');

  final String? id;
  final String userId;
  final String userName;
  final String category;
  final int rating;
  final String message;
  final DateTime createdAt;

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? category,
    int? rating,
    String? message,
    DateTime? createdAt,
  }) => FeedbackModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    category: category ?? this.category,
    rating: rating ?? this.rating,
    message: message ?? this.message,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          userName == other.userName &&
          category == other.category &&
          rating == other.rating &&
          message == other.message &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, userId, userName, category, rating, message, createdAt);

  @override
  String toString() =>
      'FeedbackModel('
      'id: $id, '
      'userId: $userId, '
      'userName: $userName, '
      'category: $category, '
      'rating: $rating, '
      'message: $message, '
      'createdAt: $createdAt'
      ')';
}
