import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edumap_portfolio_project/features/subscription/models/transaction_history.dart';

const _kGateways = {
  'all': (label: 'All Gateways', icon: Icons.all_inclusive_rounded),
  'stripe': (label: 'Stripe', icon: Icons.credit_card_outlined),
  'sslcommerz': (label: 'SSLCommerz', icon: Icons.mobile_friendly_outlined),
};

class TransactionDetailSheet extends StatelessWidget {
  final TransactionHistory tx;
  const TransactionDetailSheet({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSuccess = tx.isSuccess;
    final statusColor = isSuccess ? Colors.green.shade600 : cs.error;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      maxChildSize: 0.88,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _kGateways[tx.gateway]?.icon ??
                              Icons.payment_outlined,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.planName,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSuccess
                                    ? '✓  Payment Successful'
                                    : '✕  Payment Failed',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${tx.amount.toStringAsFixed(2)}',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            tx.currency,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  _DetailRow(
                    label: 'Gateway',
                    value: _kGateways[tx.gateway]?.label ?? tx.gateway,
                  ),
                  _DetailRow(label: 'Plan', value: tx.planName),
                  _DetailRow(label: 'Date', value: _fmtDateTime(tx.createdAt)),
                  if (tx.gatewayRef != null)
                    _DetailRow(
                      label: 'Reference',
                      value: tx.gatewayRef!,
                      copyable: true,
                    ),
                  _DetailRow(
                    label: 'Transaction ID',
                    value: tx.id,
                    copyable: true,
                  ),
                  if (tx.errorMessage != null && !isSuccess)
                    _DetailRow(
                      label: 'Error',
                      value: tx.errorMessage!,
                      isError: true,
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool isError;
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isError ? cs.error : cs.onSurface,
                      ),
                    ),
                  ),
                  if (copyable)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.copy_all_rounded,
                        size: 13,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
