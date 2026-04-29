import 'package:edumap_portfolio_project/features/subscription/models/transaction_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class TransactionRepository {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  String get _requireUserId {
    final uid = _userId;
    if (uid == null) throw Exception('No authenticated user found.');
    return uid;
  }

  Future<List<TransactionHistory>> getTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                TransactionHistory.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<TransactionHistory?> getTransaction(String id) async {
    try {
      final uid = _userId;
      if (uid == null) return null;

      final response = await _supabase
          .from('payments')
          .select()
          .eq('id', id)
          .eq('user_id', uid)
          .maybeSingle();

      if (response == null) return null;
      return TransactionHistory.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  Future<List<TransactionHistory>> getSuccessfulTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .eq('status', 'success')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                TransactionHistory.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch successful transactions: $e');
    }
  }

  Future<List<TransactionHistory>> getFailedTransactions() async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', uid)
          .eq('status', 'failed')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (row) =>
                TransactionHistory.fromMap(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch failed transactions: $e');
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final uid = _requireUserId;
      await _supabase.from('payments').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  Future<void> deleteAllTransactions() async {
    try {
      final uid = _requireUserId;
      await _supabase.from('payments').delete().eq('user_id', uid);
    } catch (e) {
      throw Exception('Failed to delete all transactions: $e');
    }
  }

  Future<void> deleteFailedTransactions() async {
    try {
      final uid = _requireUserId;
      await _supabase
          .from('payments')
          .delete()
          .eq('user_id', uid)
          .eq('status', 'failed');
    } catch (e) {
      throw Exception('Failed to delete failed transactions: $e');
    }
  }

  Future<void> deleteTransactions(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      final uid = _requireUserId;
      await _supabase
          .from('payments')
          .delete()
          .eq('user_id', uid)
          .inFilter('id', ids);
    } catch (e) {
      throw Exception('Failed to delete transactions: $e');
    }
  }
}