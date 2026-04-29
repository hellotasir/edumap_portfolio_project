import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/core/widgets/loading_widget.dart';
import 'package:edumap_portfolio_project/features/subscription/models/subscription_plan.dart';
import 'package:edumap_portfolio_project/features/subscription/views/screens/payment_screen.dart';
import 'package:edumap_portfolio_project/features/subscription/views/screens/transaction_screen.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/repositories/profile_repository.dart';
import 'package:edumap_portfolio_project/features/profile/views/screens/profile_screen.dart';
import 'package:edumap_portfolio_project/core/consts/messages.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool isYearly = true;

  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  Stream<ProfileModel?>? _profileStream;

  double get price => isYearly ? 99.99 : 9.99;
  String get duration => isYearly ? 'year' : 'month';

  @override
  void initState() {
    super.initState();
    _initProfileStream();
  }

  void _initProfileStream() {
    final userId = _authRepository.currentUser?.id ?? '';
    final collectionPath = _profileRepository.collectionPath.first;

    _profileStream = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return _profileRepository.fromSnapshot(snapshot.docs.first);
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<ProfileModel?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
            appBar: AppBar(
              title: const Text('Subscription'),
              leading: IconButton(
                onPressed: () =>
                    AppNavigator(screen: ProfileScreen()).navigate(context),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                  child: IconButton(
                    onPressed: () {
                      AppNavigator(
                        screen: const TransactionScreen(),
                      ).navigate(context);
                    },
                    icon: const Icon(Icons.history),
                  ),
                ),
              ],
            ),

            body: isLoading
                ? const Center(child: LoadingIndicator())
                : profile == null
                ? const Center(child: Text(actionErrorMessage))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upgrade Your Experience',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unlock premium features to enhance your journey.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              ToggleButtons(
                                isSelected: [!isYearly, isYearly],
                                onPressed: (index) {
                                  setState(() => isYearly = index == 1);
                                },
                                borderRadius: BorderRadius.circular(10),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Monthly'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Yearly'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              _featureItem(
                                icon: Icons.verified,
                                title: 'Verified Badge',
                                subtitle: 'Stand out with a trusted profile',
                              ),
                              _featureItem(
                                icon: Icons.call,
                                title: 'Video & Voice Call',
                                subtitle: 'Connect directly with users',
                              ),
                              _featureItem(
                                icon: Icons.location_on,
                                title: 'Distance Tracker',
                                subtitle: 'Track distance in real-time',
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '\$$price / $duration',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text('Cancel anytime'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                            onPressed: () {
                              final plan = isYearly
                                  ? SubscriptionPlan.yearly
                                  : SubscriptionPlan.monthly;
                            
                              AppNavigator(
                                screen: PaymentScreen(
                                  plan: plan,
                                ),
                              ).navigate(context);
                            },
                            child: const Text('Subscribe Now'),
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                ),
        );
      },
    );
  }

  Widget _featureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
