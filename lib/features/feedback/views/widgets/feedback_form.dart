import 'package:edumap_portfolio_project/features/feedback/models/feedback_model.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/cloud/database_service.dart';
import 'package:edumap_portfolio_project/features/feedback/views/widgets/form_sheet_scaffold.dart';

class FeedbackForm extends StatefulWidget {
  const FeedbackForm({
    super.key,
    required this.service,
    this.existing,
    this.scrollController,
  });

  final DatabaseService<FeedbackModel> service;
  final FeedbackModel? existing;
  final ScrollController? scrollController;

  @override
  State<FeedbackForm> createState() => FeedbackFormState();
}

class FeedbackFormState extends State<FeedbackForm> {
  late final TextEditingController _feedbackCtrl;
  late String _category;
  late int _rating;
  bool _loading = false;

  bool _checking = false;
  bool _alreadySubmitted = false;

  static const _categories = [
    ('general', 'General'),
    ('bug', 'Bug Report'),
    ('feature', 'Feature Request'),
    ('content', 'Content Issue'),
  ];

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = TextEditingController(text: widget.existing?.message ?? '');
    _category = widget.existing?.category ?? 'general';
    _rating = widget.existing?.rating ?? 0;

    if (widget.existing == null) _checkDuplicate();
  }

  Future<void> _checkDuplicate() async {
    final userId = widget.service.currentUserId;
    if (userId == null) return;

    setState(() => _checking = true);
    try {
      final results = await widget.service.getAll(
        query: (col) => col.where('userId', isEqualTo: userId).limit(1),
      );
      if (mounted && results.isNotEmpty) {
        setState(() => _alreadySubmitted = true);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_alreadySubmitted) return;

    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = widget.service.currentUser;
      final meta = user?.userMetadata;
      final userName =
          meta?['full_name'] as String? ??
          meta?['name'] as String? ??
          meta?['display_name'] as String? ??
          meta?['username'] as String? ??
          'Anonymous';

      final model = FeedbackModel(
        user_id: user?.id ?? 'anonymous',
        userName: userName,
        category: _category,
        rating: _rating,
        message: text,

        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.existing?.id != null) {
        await widget.service.replace(widget.existing!.id!, model);
      } else {
        final userId = user?.id;
        if (userId != null) {
          final existing = await widget.service.getAll(
            query: (col) => col.where('userId', isEqualTo: userId).limit(1),
          );
          if (existing.isNotEmpty) {
            if (mounted) {
              setState(() {
                _alreadySubmitted = true;
                _loading = false;
              });
            }
            return;
          }
        }
        await widget.service.add(model);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return FormSheetScaffold(
      title: isEditing ? 'Edit Feedback' : 'New Feedback',
      scrollController: widget.scrollController,
      child: _checking
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : _alreadySubmitted
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Feedback Already Submitted',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have already submitted feedback. To make changes, close this and use the Edit option on your existing entry.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "We'd love to hear from you. Your feedback helps us improve.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Overall Rating',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      ...List.generate(5, (i) {
                        return IconButton(
                          onPressed: () => setState(() => _rating = i + 1),
                          icon: Icon(
                            i < _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < _rating ? Colors.amber : null,
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c.$1;
                      return ChoiceChip(
                        label: Text(c.$2),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = c.$1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _feedbackCtrl,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Your feedback',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      hintText: 'Tell us what you think…',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Update Feedback' : 'Submit Feedback',
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}
