import 'package:flutter/material.dart';

class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color});
  final Color color;

  @override
  State<TypingDots> createState() => TypingDotsState();
}

class TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final bounce = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 5,
            height: 5 + (bounce * 3),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
