// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';

@immutable
class FeedbackModel {
  const FeedbackModel({
    this.id,
    required this.user_id,
    required this.userName,
    required this.category,
    required this.rating,
    required this.message,
    required this.createdAt,
  }) : assert(user_id != '', 'userId must not be empty'),
       assert(rating >= 1 && rating <= 5, 'rating must be between 1 and 5');

  final String? id;
  final String user_id;
  final String userName;
  final String category;
  final int rating;
  final String message;
  final DateTime createdAt;

  FeedbackModel copyWith({
    String? id,
    String? user_id,
    String? userName,
    String? category,
    int? rating,
    String? message,
    DateTime? createdAt,
  }) => FeedbackModel(
    id: id ?? this.id,
    user_id: user_id ?? this.user_id,
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
          user_id == other.user_id &&
          userName == other.userName &&
          category == other.category &&
          rating == other.rating &&
          message == other.message &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, user_id, userName, category, rating, message, createdAt);

  @override
  String toString() =>
      'FeedbackModel('
      'id: $id, '
      'user_id: $user_id, '
      'userName: $userName, '
      'category: $category, '
      'rating: $rating, '
      'message: $message, '
      'createdAt: $createdAt'
      ')';
}
