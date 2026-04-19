import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/subscription/models/transaction_history.dart';

const _kGateways = {
  'all': (label: 'All Gateways', icon: Icons.all_inclusive_rounded),
  'stripe': (label: 'Stripe', icon: Icons.credit_card_outlined),
  'sslcommerz': (label: 'SSLCommerz', icon: Icons.mobile_friendly_outlined),
};

class TransactionTile extends StatelessWidget {
  final TransactionHistory tx;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionTile({
    super.key,
    required this.tx,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final gatewayIcon = _kGateways[tx.gateway]?.icon ?? Icons.payment_outlined;
    final gatewayLabel = _kGateways[tx.gateway]?.label ?? tx.gateway;
    final isSuccess = tx.isSuccess;
    final statusColor = isSuccess ? Colors.green.shade600 : cs.error;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.error),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  gatewayIcon,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.planName,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          gatewayLabel,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '  ·  ${_fmtDate(tx.createdAt)}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isSuccess
                        ? '-\$${tx.amount.toStringAsFixed(2)}'
                        : '\$${tx.amount.toStringAsFixed(2)}',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSuccess ? cs.onSurface : cs.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSuccess ? 'Paid' : 'Failed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
