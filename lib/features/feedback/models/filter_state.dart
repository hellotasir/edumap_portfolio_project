import 'package:flutter/foundation.dart';

enum SortOrder { newest, oldest, highestRating, lowestRating }

@immutable
class FilterState {
  const FilterState({
    this.query = '',
    this.category = 'all',
    this.minRating = 0,
    this.sortOrder = SortOrder.newest,
  }) : assert(
         minRating >= 0 && minRating <= 5,
         'minRating must be between 0 and 5',
       );

  final String query;
  final String category;
  final int minRating;
  final SortOrder sortOrder;

  static const FilterState initial = FilterState();

  bool get isActive =>
      query.isNotEmpty ||
      category != 'all' ||
      minRating > 0 ||
      sortOrder != SortOrder.newest;

  FilterState copyWith({
    String? query,
    String? category,
    int? minRating,
    SortOrder? sortOrder,
  }) => FilterState(
    query: query ?? this.query,
    category: category ?? this.category,
    minRating: minRating ?? this.minRating,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  FilterState reset() => FilterState.initial;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterState &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          category == other.category &&
          minRating == other.minRating &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(query, category, minRating, sortOrder);

  @override
  String toString() =>
      'FilterState('
      'query: $query, '
      'category: $category, '
      'minRating: $minRating, '
      'sortOrder: $sortOrder'
      ')';
}
