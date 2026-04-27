import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/core/consts/api_keys.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_model.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_plan.dart';
import 'package:flutter_education_app/features/subscription/models/transaction_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentRepository {
  PaymentRepository({
    AuthRepository? authRepository,
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
  }) : _auth = authRepository ?? AuthRepository(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabase ?? Supabase.instance.client;

  final AuthRepository _auth;
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  String get _requireUserId {
    final uid = _auth.currentUser?.id;
    if (uid == null) throw Exception('No authenticated user found.');
    return uid;
  }

  Future<DocumentReference<Map<String, dynamic>>> _profileRef(
    String uid,
  ) async {
    final query = await _firestore
        .collection('profiles')
        .where('user_id', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Profile not found for user: $uid');
    return query.docs.first.reference;
  }

  Future<String> createStripePaymentIntent({
    required int amount,
    required String currency,
  }) async {
    try {
      final anonKey = supabaseAnonKey;
      final accessToken = _supabase.auth.currentSession?.accessToken;

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer ${accessToken ?? anonKey}',
        },
        body: jsonEncode({'amount': amount, 'currency': currency}),
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(
          'Payment intent failed: ${data['error'] ?? response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final clientSecret = data['client_secret'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Invalid client secret returned from server.');
      }

      return clientSecret;
    } catch (e) {
      debugPrint('[Stripe] Error: $e');
      rethrow;
    }
  }

  Future<TransactionHistory> verifyAndActivateSSLCommerzSubscription({
    required SubscriptionPlan plan,
    required String transactionId,
    required String valId,
  }) async {
    return activateSubscription(
      plan: plan,
      gateway: 'sslcommerz',
      gatewayRef: valId,
    );
  }

  Future<SubscriptionModel?> getCurrentSubscription() async {
    final uid = _requireUserId;
    final ref = await _profileRef(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final sub = data?['subscription'];
    if (sub == null) return null;
    return SubscriptionModel.fromMap(sub as Map<String, dynamic>);
  }

  Future<bool> isSubscriptionActive() async {
    try {
      final sub = await getCurrentSubscription();
      return sub?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<TransactionHistory> activateSubscription({
    required SubscriptionPlan plan,
    required String gateway,
    String? gatewayRef,
  }) async {
    final uid = _requireUserId;
    final transactionId = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: plan.durationDays));

    final tx = TransactionHistory(
      id: transactionId,
      userId: uid,
      planId: plan.id,
      planName: plan.name,
      amount: plan.price,
      currency: 'USD',
      gateway: gateway,
      gatewayRef: gatewayRef,
      status: 'success',
      createdAt: now,
    );

    final subscription = SubscriptionModel(
      planId: plan.id,
      planName: plan.name,
      status: 'active',
      startedAt: now,
      expiresAt: expiresAt,
      paymentGateway: gateway,
      updatedAt: now,
    );

    await _recordPaymentToSupabase(tx);
    await _writeSubscriptionToProfile(uid, subscription);

    return tx;
  }

  Future<void> recordFailedPayment({
    required SubscriptionPlan plan,
    required String gateway,
    required String status,
    String? errorMessage,
    String? gatewayRef,
  }) async {
    final uid = _requireUserId;
    final tx = TransactionHistory(
      id: _uuid.v4(),
      userId: uid,
      planId: plan.id,
      planName: plan.name,
      amount: plan.price,
      currency: 'USD',
      gateway: gateway,
      gatewayRef: gatewayRef,
      status: status,
      errorMessage: errorMessage,
      createdAt: DateTime.now(),
    );
    await _recordPaymentToSupabase(tx);
  }

  Future<void> cancelSubscription() async {
    final uid = _requireUserId;
    final ref = await _profileRef(uid);
    await ref.update({
      'subscription.status': 'cancelled',
      'subscription.updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _recordPaymentToSupabase(TransactionHistory tx) async {
    try {
      await _supabase.from('payments').insert(tx.toMap());
    } catch (e) {
      debugPrint('[PaymentRepository] Supabase payment record failed: $e');
      rethrow;
    }
  }

  Future<void> _writeSubscriptionToProfile(
    String uid,
    SubscriptionModel subscription,
  ) async {
    try {
      final ref = await _profileRef(uid);
      await ref.update({
        'subscription': subscription.toMap(),
        'is_verified': true,
      });
    } catch (e) {
      rethrow;
    }
  }
}
