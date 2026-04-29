// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/mfa_widget.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/core/widgets/app_snackbar.dart';
import 'package:edumap_portfolio_project/core/widgets/loading_widget.dart';
import 'package:edumap_portfolio_project/features/subscription/models/subscription_plan.dart';
import 'package:edumap_portfolio_project/features/subscription/views/view_models/payment_notifier.dart';
import 'package:edumap_portfolio_project/features/subscription/views/screens/subscription_screen.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/bottom_paybar.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/error_banner.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/payment_method_tile.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/plan_summary_card.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/repositories/profile_repository.dart';
import 'package:edumap_portfolio_project/core/consts/messages.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;

  const PaymentScreen({super.key, required this.plan});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _authRepository = AuthRepository();
  final _profileRepository = ProfileRepository();
  Stream<ProfileModel?>? _profileStream;

  @override
  void initState() {
    super.initState();
    _initProfileStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentNotifierProvider.notifier).onResult = _handleResult;
    });
  }

  void _initProfileStream() {
    final userId = _authRepository.currentUser!.id;
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

  void _handleResult(PaymentResult result) {
    if (!mounted) return;

    switch (result) {
      case PaymentSucceeded():
        AppSnackbar.show(
          context,
          message: 'Thank you for purchasing our service.',
          type: SnackType.success,
        );

      case PaymentCancelled():
        break;

      case PaymentFailed():
        AppSnackbar.show(
          context,
          message: 'Payment failed. Try again later.',
          type: SnackType.error,
        );

      case PaymentUnknownStatus():
        AppSnackbar.show(
          context,
          message: 'Payment closed by user.',
          type: SnackType.info,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentNotifierProvider);
    final notifier = ref.read(paymentNotifierProvider.notifier);

    return StreamBuilder<ProfileModel?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoadingProfile =
            snapshot.connectionState == ConnectionState.waiting;

        return NetworkWidget(
          child: MfaWidget(
            authRepository: AuthRepository(),
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  onPressed: () {
                    AppNavigator(
                      screen: const SubscriptionScreen(),
                    ).navigate(context);
                  },
                  icon: const Icon(Icons.chevron_left_outlined),
                ),
                title: const Text('Checkout'),
              ),
              body: isLoadingProfile
                  ? const Center(child: LoadingIndicator())
                  : profile == null
                  ? const Center(child: Text(actionErrorMessage))
                  : SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                PlanSummary(plan: widget.plan),
                                const SizedBox(height: 28),
                                const Text(
                                  'Payment Method',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                PaymentMethodTile(
                                  value: 'stripe',
                                  title: 'Credit / Debit Card',
                                  subtitle: 'Powered by Stripe',
                                  icon: Icons.credit_card_outlined,
                                  selectedValue: paymentState.selectedMethod,
                                  onChanged: notifier.selectMethod,
                                ),
                                PaymentMethodTile(
                                  value: 'sslcommerz',
                                  title: 'SSLCommerz',
                                  subtitle: 'Mobile banking & cards',
                                  icon: Icons.mobile_friendly_outlined,
                                  selectedValue: paymentState.selectedMethod,
                                  onChanged: notifier.selectMethod,
                                ),
                                if (paymentState.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  ErrorBanner(
                                    message: paymentState.errorMessage!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          BottomPayBar(
                            price: widget.plan.price,
                            canPay: paymentState.canPay,
                            isLoading: paymentState.isLoading,
                            onPay: () => notifier.pay(
                              plan: widget.plan,
                              profile: profile,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
