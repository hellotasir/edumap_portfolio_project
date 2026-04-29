import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/suggestion_tile.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onSend});

  final void Function(String) onSend;

  static const _suggestions = [
    (
      'Find a friend',
      'Search for users by username',
      Icons.person_search_outlined,
    ),
    (
      'Start chatting',
      'Open a conversation with a friend',
      Icons.chat_bubble_outline_rounded,
    ),
    (
      'Check connections',
      'Show me my friends list',
      Icons.people_outline_rounded,
    ),
    ('Send a message', 'Help me message someone', Icons.send_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness != Brightness.dark;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        Image.asset(
          isDark
              ? 'assets/edumap-transparent-icon.png'
              : 'assets/edumap-black-transparent-icon.png',
          height: 45,
        ),
        const SizedBox(height: 16),
        Text(
          'How can I help you today?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'I can search for users, manage friend requests,\nand send messages on your behalf.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        ..._suggestions.map(
          (s) => SuggestionTile(
            label: s.$1,
            subtitle: s.$2,
            icon: s.$3,
            onTap: () => onSend(s.$2),
          ),
        ),
      ],
    );
  }
}
