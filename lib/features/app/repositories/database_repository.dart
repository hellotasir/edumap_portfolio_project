import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/cloud/database_service.dart';

abstract class DatabaseRepository<T> {
  List<String> get collectionPath;
  T fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot);
  Map<String, dynamic> toMap(T model);
}

class DatabaseProvider<T> extends InheritedWidget {
  DatabaseProvider({
    super.key,
    required DatabaseRepository<T> repository,
    required super.child,
  }) : service = DatabaseService<T>(repository);

  final DatabaseService<T> service;

  static DatabaseService<T> of<T>(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<DatabaseProvider<T>>();
    assert(
      provider != null,
      'No DatabaseProvider<$T> found. Wrap a parent widget with DatabaseProvider<$T>.',
    );
    return provider!.service;
  }

  @override
  bool updateShouldNotify(DatabaseProvider<T> oldWidget) =>
      service != oldWidget.service;
}
