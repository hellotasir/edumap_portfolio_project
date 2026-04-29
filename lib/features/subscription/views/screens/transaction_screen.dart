import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/widgets/loading_widget.dart';
import 'package:edumap_portfolio_project/features/subscription/models/transaction_history.dart';
import 'package:edumap_portfolio_project/features/subscription/repositories/transaction_repository.dart';
import 'package:edumap_portfolio_project/features/subscription/views/screens/subscription_screen.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/empty_state.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/filter_bar.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/summary_banner.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/transaction_detail_sheet.dart';
import 'package:edumap_portfolio_project/features/subscription/views/widgets/transaction_tile.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';



class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TransactionRepository _repo = TransactionRepository();

  late Future<List<TransactionHistory>> _future;

  String _gatewayFilter = 'all';
  String _statusFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _repo.getTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _repo.getTransactions();
    });
  }


  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Transactions'),
        content: const Text(
          'This will permanently delete all your payment history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repo.deleteAllTransactions();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All transactions deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }


  Future<void> _deleteSingle(TransactionHistory tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete the "${tx.planName}" transaction? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repo.deleteTransaction(tx.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }


  List<TransactionHistory> _applyFilters(List<TransactionHistory> all,
  ) {
    return all.where((tx) {
      final matchGateway =
          _gatewayFilter == 'all' || tx.gateway == _gatewayFilter;
      final matchStatus = _statusFilter == 'all' || tx.status == _statusFilter;
      final query = _searchQuery.toLowerCase();
      final matchSearch =
          query.isEmpty ||
          tx.planName.toLowerCase().contains(query) ||
          tx.gateway.toLowerCase().contains(query) ||
          (tx.gatewayRef?.toLowerCase().contains(query) ?? false);
      return matchGateway && matchStatus && matchSearch;
    }).toList();
  }

  ({double totalSpent, int successCount, int failedCount}) _stats(
    List<TransactionHistory> all,
  ) {
    double total = 0;
    int success = 0;
    int failed = 0;
    for (final tx in all) {
      if (tx.isSuccess) {
        total += tx.amount;
        success++;
      } else {
        failed++;
      }
    }
    return (totalSpent: total, successCount: success, failedCount: failed);
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return NetworkWidget(
        child: Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: () =>
                  AppNavigator(screen: SubscriptionScreen()).navigate(context),
              icon: const Icon(Icons.chevron_left_outlined),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            title: Text(
              'Payment History',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: _confirmDeleteAll,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                tooltip: 'Delete all transactions',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          body: FutureBuilder<List<TransactionHistory>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: const LoadingIndicator());
              }

              if (snapshot.hasError) {
                return _ErrorView(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }

              final all = snapshot.data ?? [];
              final filtered = _applyFilters(all);
              final stats = _stats(all);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SummaryBanner(stats: stats)),
                  SliverToBoxAdapter(
                    child: FilterBar(
                      searchController: _searchController,
                      onSearchChanged: (q) => setState(() => _searchQuery = q),
                      gatewayFilter: _gatewayFilter,
                      onGatewayChanged: (v) =>
                          setState(() => _gatewayFilter = v),
                      statusFilter: _statusFilter,
                      onStatusChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        '${filtered.length} transaction${filtered.length == 1 ? '' : 's'}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(child: EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 68,
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                        ),
                        itemBuilder: (context, i) => TransactionTile(
                          tx: filtered[i],
                          onTap: () => _showDetail(context, filtered[i]),
                          onDelete: () => _deleteSingle(filtered[i]),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
  }

  void _showDetail(BuildContext context, TransactionHistory tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(tx: tx),
    );
  }
}






class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 32, color: cs.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

