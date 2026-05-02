import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/subscription/models/subscription_model.dart';

class SubscriptionGuardService {
  SubscriptionGuardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<bool> watchSubscriptionActive(String userId) {
    return _firestore
        .collection('profiles')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) => _evaluate(snapshot));
  }

  Future<bool> _evaluate(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    if (snapshot.docs.isEmpty) return false;

    final doc = snapshot.docs.first;
    final subData = doc.data()['subscription'];

    if (subData == null) return false;

    final subscription = SubscriptionModel.fromMap(
      subData as Map<String, dynamic>,
    );

    final isExpired = subscription.expiresAt.isBefore(DateTime.now());

    if (isExpired && subscription.status == 'active') {
      await doc.reference.update({
        'subscription.status': 'inactive',
        'subscription.updated_at': DateTime.now().toIso8601String(),
        'is_verified': false,
      });
      return false;
    }

    return subscription.isActive;
  }
}
