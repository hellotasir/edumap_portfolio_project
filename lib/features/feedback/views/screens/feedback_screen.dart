// ignore_for_file: use_build_context_synchronously

import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/core/consts/messages.dart';
import 'package:edumap_portfolio_project/features/feedback/models/feedback_model.dart';
import 'package:edumap_portfolio_project/features/feedback/models/filter_state.dart';
import 'package:edumap_portfolio_project/features/feedback/repositories/feedback_repository.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/core/services/cloud/database_service.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';
import 'package:edumap_portfolio_project/features/feedback/views/widgets/empty_state.dart';
import 'package:edumap_portfolio_project/features/feedback/views/widgets/feedback_form.dart';
import 'package:edumap_portfolio_project/features/feedback/views/widgets/feedback_tile.dart';
import 'package:edumap_portfolio_project/features/feedback/views/widgets/filter_sheet.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(
      screen: FeedbackScreen(authRepository: authRepository),
    ).navigate(context);
  }

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _firestoreService = DatabaseService<FeedbackModel>(
    FeedbackRepository(),
  );
  final _searchCtrl = TextEditingController();

  List<FeedbackModel> _allFeedback = [];
  bool _fetching = true;
  FeedbackModel? _myFeedback;
  FilterState _filter = const FilterState();

  static const _categories = [
    ('all', 'All'),
    ('general', 'General'),
    ('bug', 'Bug Report'),
    ('feature', 'Feature Request'),
    ('content', 'Content Issue'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _filter = _filter.copyWith(query: _searchCtrl.text.trim()));
  }

  Future<void> _loadFeedback() async {
    if (mounted) setState(() => _fetching = true);
    try {
      final all = await _firestoreService.getAll(
        query: (col) => col.orderBy('createdAt', descending: true),
      );

      final seen = <String, FeedbackModel>{};
      for (final f in all) {
        if (!seen.containsKey(f.user_id)) seen[f.user_id] = f;
      }

      final deduped = seen.values.toList();

      final userId = _firestoreService.currentUserId;
      if (mounted) {
        setState(() {
          _allFeedback = deduped;
          _myFeedback = userId != null
              ? deduped.where((f) => f.user_id == userId).firstOrNull
              : null;
        });
      }
    } catch (_) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  List<FeedbackModel> get _filtered {
    var list = List<FeedbackModel>.from(_allFeedback);

    if (_filter.category != 'all') {
      list = list.where((f) => f.category == _filter.category).toList();
    }
    if (_filter.minRating > 0) {
      list = list.where((f) => f.rating >= _filter.minRating).toList();
    }
    if (_filter.query.isNotEmpty) {
      final q = _filter.query.toLowerCase();
      list = list
          .where(
            (f) =>
                f.userName.toLowerCase().contains(q) ||
                f.message.toLowerCase().contains(q),
          )
          .toList();
    }

    switch (_filter.sortOrder) {
      case SortOrder.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOrder.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOrder.highestRating:
        list.sort((a, b) {
          final r = b.rating.compareTo(a.rating);
          return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
        });
      case SortOrder.lowestRating:
        list.sort((a, b) {
          final r = a.rating.compareTo(b.rating);
          return r != 0 ? r : b.createdAt.compareTo(a.createdAt);
        });
    }

    return list;
  }

  void _openForm({FeedbackModel? existing}) {
    try {
      if (existing == null && _myFeedback != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have already submitted feedback. Use Edit to update it.',
            ),
          ),
        );
        return;
      }

      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) => FeedbackForm(
            service: _firestoreService,
            existing: existing,
            scrollController: scrollController,
          ),
        ),
      ).then((submitted) {
        if (submitted == true) _loadFeedback();
      });
    } catch (e) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    }
  }

  Future<void> _deleteSingle(FeedbackModel feedback) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Feedback'),
          content: const Text(
            'Are you sure you want to delete your submitted feedback?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _firestoreService.deleteByDocId(feedback.id!);
      _loadFeedback();
    } catch (e) {
      SnackbarWidget(message: actionErrorMessage).showSnackbar(context);
    }
  }

  Future<void> _deleteAll() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete ALL Feedback'),
          content: const Text(
            'This will permanently delete every feedback document. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete All'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _firestoreService.deleteCollection();
      _loadFeedback();
    } catch (e) {
      SnackbarWidget(message: actionErrorMessage).showSnackbar(context);
    }
  }

  void _showSortFilter() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => FilterSheet(
          initial: _filter,
          categories: _categories,
          onApply: (updated) => setState(() => _filter = updated),
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filter = const FilterState();
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final currentUserId = _firestoreService.currentUserId;

    final canAdd = !_fetching && _myFeedback == null;

    return NetworkWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          actions: [
            if (canAdd)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (_allFeedback.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete All Feedback',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'delete_all') _deleteAll();
                },
              ),
          ],
        ),
        body: _fetching
            ? const Center(child: CircularProgressIndicator())
            : _allFeedback.isEmpty
            ? EmptyState(onAdd: () => _openForm())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Search by name or message…',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        onPressed: _searchCtrl.clear,
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Badge(
                            isLabelVisible: _filter.isActive,
                            child: IconButton.outlined(
                              onPressed: _showSortFilter,
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              tooltip: 'Filter & Sort',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _categories.map((c) {
                            final selected = _filter.category == c.$1;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(c.$2),
                                selected: selected,
                                onSelected: (_) => setState(
                                  () => _filter = _filter.copyWith(
                                    category: c.$1,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_filter.isActive)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 16,
                              ),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 24,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No results found',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _resetFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final feedback = filtered[i];
                        final isOwner = feedback.user_id == currentUserId;
                        return FeedbackTile(
                          feedback: feedback,
                          isOwner: isOwner,
                          onEdit: isOwner
                              ? () => _openForm(existing: feedback)
                              : null,
                          onDelete: isOwner
                              ? () => _deleteSingle(feedback)
                              : null,
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}
