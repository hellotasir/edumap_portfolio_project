import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';

class StatusIcon extends StatelessWidget {
  const StatusIcon({required this.status, required this.cs});

  final MessageStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = cs.onPrimary.withOpacity(0.55);
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
        );
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 12, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 12, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 12, color: cs.onPrimary);
      case MessageStatus.failed:
        return Icon(Icons.error_outline_rounded, size: 12, color: cs.error);
    }
  }
}
