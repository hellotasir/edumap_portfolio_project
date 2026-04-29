import 'package:flutter/material.dart';

enum ErrorType { network, server, notFound, unknown }

class ErrorScreen extends StatefulWidget {
  final ErrorType errorType;
  final String? message;
  final VoidCallback? onRetry;

  const ErrorScreen({
    super.key,
    this.errorType = ErrorType.unknown,
    this.message,
    this.onRetry,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ErrorMeta get _meta {
    switch (widget.errorType) {
      case ErrorType.network:
        return _ErrorMeta(
          icon: Icons.wifi_off_rounded,
          title: 'No Connection',
          subtitle:
              widget.message ??
              'Please check your internet connection and try again.',
        );
      case ErrorType.server:
        return _ErrorMeta(
          icon: Icons.cloud_off_rounded,
          title: 'Server Error',
          subtitle:
              widget.message ??
              'Something went wrong on our end. We\'re working on it.',
        );
      case ErrorType.notFound:
        return _ErrorMeta(
          icon: Icons.search_off_rounded,
          title: 'Not Found',
          subtitle:
              widget.message ?? 'The page you\'re looking for doesn\'t exist.',
        );
      case ErrorType.unknown:
        return _ErrorMeta(
          icon: Icons.error_outline_rounded,
          title: 'Unexpected Error',
          subtitle:
              widget.message ??
              'An unexpected error occurred. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final theme = Theme.of(context);

    return Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          meta.icon,
                          size: 48,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        meta.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        meta.subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 36),
                      if (widget.onRetry != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }
}

class _ErrorMeta {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ErrorMeta({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
