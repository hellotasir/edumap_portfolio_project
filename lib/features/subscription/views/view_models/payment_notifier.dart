import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/subscription/models/subscription_plan.dart';
import 'package:edumap_portfolio_project/features/subscription/repositories/payment_repository.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCTransactionInfoModel.dart';
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/sslcommerz.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'payment_state.dart';

sealed class PaymentResult {}
class PaymentSucceeded extends PaymentResult {}
class PaymentCancelled extends PaymentResult {}

class PaymentFailed extends PaymentResult {
  final String message;
  PaymentFailed(this.message);
}

class PaymentUnknownStatus extends PaymentResult {
  final String status;
  PaymentUnknownStatus(this.status);
}

final paymentNotifierProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>(
      (ref) => PaymentNotifier(ref.read(subscriptionRepositoryProvider)),
    );

final subscriptionRepositoryProvider = Provider.autoDispose<PaymentRepository>(
  (_) => PaymentRepository(),
);

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this._paymentRepo) : super(const PaymentState());

  final PaymentRepository _paymentRepo;

  void Function(PaymentResult)? onResult;

  void selectMethod(String? method) {
    state = state.copyWith(selectedMethod: method, clearError: true);
  }

  Future<void> pay({
    required SubscriptionPlan plan,
    required ProfileModel profile,
  }) async {
    if (!state.canPay) return;

    state = state.copyWith(status: PaymentStatus.loading, clearError: true);

    try {
      switch (state.selectedMethod) {
        case 'stripe':
          await _handleStripePayment(plan);
          break;
        case 'sslcommerz':
          await _handleSSLCommerzPayment(plan: plan, profile: profile);
          break;
        default:
          throw Exception('Unknown payment method');
      }
    } on StripeException catch (e) {
      final msg =
          e.error.localizedMessage ?? e.error.message ?? 'Payment cancelled.';
      final isCancelled = e.error.code == FailureCode.Canceled;

      if (!isCancelled) {
        await _recordFailure(plan: plan, gateway: 'stripe', errorMessage: msg);
        state = state.copyWith(status: PaymentStatus.failed, errorMessage: msg);
        onResult?.call(PaymentFailed(msg));
      } else {
        state = state.copyWith(status: PaymentStatus.idle, clearError: true);
        onResult?.call(PaymentCancelled());
      }
    } catch (e) {
      final msg = e.toString();
      await _recordFailure(
        plan: plan,
        gateway: state.selectedMethod ?? 'unknown',
        errorMessage: msg,
      );
      state = state.copyWith(status: PaymentStatus.failed, errorMessage: msg);
      onResult?.call(PaymentFailed(msg));
    } finally {
      if (state.status == PaymentStatus.loading) {
        state = state.copyWith(status: PaymentStatus.idle);
      }
    }
  }

  Future<void> _handleStripePayment(SubscriptionPlan plan) async {
    final clientSecret = await _paymentRepo.createStripePaymentIntent(
      amount: (plan.price * 100).toInt(),
      currency: 'usd',
    );

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'EDUMAP PORTFOLIO',
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'US',
          currencyCode: 'USD',
        ),
        style: ThemeMode.system,
        billingDetailsCollectionConfiguration:
            const BillingDetailsCollectionConfiguration(
              name: CollectionMode.automatic,
              email: CollectionMode.automatic,
            ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();
    await _paymentRepo.activateSubscription(plan: plan, gateway: 'stripe');

    state = state.copyWith(status: PaymentStatus.success);
    onResult?.call(PaymentSucceeded());
  }

  Future<void> _handleSSLCommerzPayment({
    required SubscriptionPlan plan,
    required ProfileModel profile,
  }) async {
    final credentials = await _paymentRepo.getSSLCommerzCredentials();
    final tranId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

    final sslcommerz = Sslcommerz(
      initializer: SSLCommerzInitialization(
        multi_card_name: 'visa,master,bkash,nagad',
        currency: SSLCurrencyType.USD,
        language: 'en',
        product_category: 'Education',
        sdkType: SSLCSdkType.TESTBOX,
        store_id: credentials['store_id']!,
        store_passwd: credentials['store_passwd']!,
        total_amount: plan.price.toDouble(),
        tran_id: tranId,
      ),
    );

    final SSLCTransactionInfoModel result = await sslcommerz.payNow();
    final status = result.status?.toLowerCase().trim() ?? '';

    switch (status) {
      case 'valid':
      case 'validated':
        await _paymentRepo.verifyAndActivateSSLCommerzSubscription(
          plan: plan,
          transactionId: result.tranId ?? tranId,
          valId: result.valId ?? '',
        );
        state = state.copyWith(status: PaymentStatus.success);
        onResult?.call(PaymentSucceeded());

      case 'cancelled':
        state = state.copyWith(status: PaymentStatus.idle, clearError: true);
        onResult?.call(PaymentCancelled());

      case 'failed':
        await _recordFailure(
          plan: plan,
          gateway: 'sslcommerz',
          errorMessage: 'SSLCommerz payment failed',
        );
        state = state.copyWith(
          status: PaymentStatus.failed,
          errorMessage: 'Payment failed. Please try again.',
        );
        onResult?.call(PaymentFailed('Payment failed. Please try again.'));

      default:
        state = state.copyWith(status: PaymentStatus.idle);
        onResult?.call(PaymentUnknownStatus(status));
    }
  }

  Future<void> _recordFailure({
    required SubscriptionPlan plan,
    required String gateway,
    required String errorMessage,
  }) async {
    await _paymentRepo.recordFailedPayment(
      plan: plan,
      gateway: gateway,
      status: 'error',
      errorMessage: errorMessage,
    );
  }
}
