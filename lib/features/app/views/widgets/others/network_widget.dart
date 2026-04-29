import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:edumap_portfolio_project/core/services/local/connectivity_service.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/error_screen.dart';
import 'package:flutter/material.dart';

class NetworkWidget extends StatefulWidget {
  final Widget child;
  final bool showLoadingOnInitial;

  const NetworkWidget({
    super.key,
    required this.child,
    this.showLoadingOnInitial = true,
  });

  @override
  State<NetworkWidget> createState() => _NetworkWidgetState();
}

class _NetworkWidgetState extends State<NetworkWidget> {
  final ConnectivityService _service = ConnectivityService();

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  Future<bool>? _connectivityFuture;

  @override
  void initState() {
    super.initState();
    _triggerCheck();

    _subscription = _service.connectivityStream.listen((_) {
      _triggerCheck(); 
    });
  }

  void _triggerCheck() {
    setState(() {
      _connectivityFuture = _service.isOnline();
    });
  }

  Future<void> _handleRetry() async {
    _triggerCheck();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<bool>(
        future: _connectivityFuture,
        builder: (context, snapshot) {
          
          final isOnline = snapshot.data == true;
        
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isOnline
                ? KeyedSubtree(
                    key: const ValueKey('child_widget'),
                    child: widget.child,
                  )
                : ErrorScreen(
                    key: const ValueKey('error_screen'),
                    errorType: ErrorType.network,
                    onRetry: _handleRetry,
                  ),
          );
        },
      ),
    );
  }
}
