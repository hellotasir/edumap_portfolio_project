// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaSession {
  MfaSession._();
  static final instance = MfaSession._();

  DateTime? _verifiedAt;
  Duration _sessionDuration = const Duration(minutes: 15);

  bool get isVerified =>
      _verifiedAt != null &&
      DateTime.now().difference(_verifiedAt!) < _sessionDuration;

  void markVerified({int sessionDurationMinutes = 15}) {
    _sessionDuration = Duration(minutes: sessionDurationMinutes);
    _verifiedAt = DateTime.now();
  }

  void invalidate() => _verifiedAt = null;
}

class MfaWidget extends StatefulWidget {
  const MfaWidget({
    super.key,
    required this.child,
    required this.authRepository,
    this.sessionDurationMinutes = 15,
    this.maxAttempts = 5,
    this.lockoutMinutes = 2,
    this.onVerified,
    this.onFailed,
    this.lockedOutBuilder,
  });

  final Widget child;
  final AuthRepository authRepository;
  final int sessionDurationMinutes;
  final int maxAttempts;
  final int lockoutMinutes;
  final VoidCallback? onVerified;
  final VoidCallback? onFailed;
  final Widget Function(BuildContext context, Duration remaining)?
  lockedOutBuilder;

  @override
  State<MfaWidget> createState() => _MfaWidgetState();
}

class _MfaWidgetState extends State<MfaWidget> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  _GateState _gate = _GateState.checking;
  bool _loading = false;
  int _attempts = 0;
  DateTime? _lockedUntil;
  Duration _lockRemaining = Duration.zero;
  String? _factorId;
  String? _challengeId;

  AuthRepository get _repo => widget.authRepository;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final hasMfa = await _repo.mfaIsEnabled();
    if (!hasMfa) {
      _set(_GateState.notEnrolled);
      return;
    }
    if (MfaSession.instance.isVerified) {
      _set(_GateState.verified);
      return;
    }
    await _newChallenge();
    _set(_GateState.challenge);
  }

  Future<void> _newChallenge() async {
    try {
      final factors = await _repo.mfaListVerifiedFactors();
      if (factors.isEmpty) return;
      _factorId = factors.first.id;
      _challengeId = await _repo.mfaCreateChallenge(_factorId!);
    } catch (_) {}
  }

  Future<void> _verify() async {
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) return;

    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      _err('Enter the complete 6-digit code.');
      return;
    }

    if (_factorId == null || _challengeId == null) await _newChallenge();

    _set(_GateState.challenge, loading: true);

    try {
      await _repo.mfaVerifyChallenge(
        factorId: _factorId!,
        challengeId: _challengeId!,
        code: code,
      );
      MfaSession.instance.markVerified(
        sessionDurationMinutes: widget.sessionDurationMinutes,
      );
      _attempts = 0;
      _set(_GateState.verified);
      widget.onVerified?.call();
    } catch (_) {
      _attempts++;
      _clearOtp();
      if (_attempts >= widget.maxAttempts) {
        _lockOut();
      } else {
        final left = widget.maxAttempts - _attempts;
        _err('Incorrect code. $left attempt${left == 1 ? '' : 's'} remaining.');
        await _newChallenge();
        _set(_GateState.challenge);
      }
    } finally {
      if (mounted && _gate != _GateState.lockedOut) {
        setState(() => _loading = false);
      }
    }
  }

  void _lockOut() {
    _lockedUntil = DateTime.now().add(Duration(minutes: widget.lockoutMinutes));
    _set(_GateState.lockedOut);
    _tickLockout();
    if (widget.onFailed != null) {
      widget.onFailed!();
    } else {
      _repo.logout(scope: SignOutScope.global);
    }
  }

  void _tickLockout() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final now = DateTime.now();
      if (_lockedUntil == null || now.isAfter(_lockedUntil!)) {
        _attempts = 0;
        _lockedUntil = null;
        await _newChallenge();
        _set(_GateState.challenge);
        return false;
      }
      setState(() => _lockRemaining = _lockedUntil!.difference(now));
      return true;
    });
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _focusNodes.first.requestFocus();
  }

  void _set(_GateState s, {bool loading = false}) {
    if (mounted) {
      setState(() {
        _gate = s;
        _loading = loading;
      });
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_gate) {
    _GateState.checking => _Checking(),
    _GateState.notEnrolled => widget.child,
    _GateState.verified => widget.child,
    _GateState.challenge => _Challenge(
      loading: _loading,
      attempts: _attempts,
      maxAttempts: widget.maxAttempts,
      controllers: _controllers,
      focusNodes: _focusNodes,
      onVerify: _verify,
    ),
    _GateState.lockedOut =>
      widget.lockedOutBuilder != null
          ? widget.lockedOutBuilder!(context, _lockRemaining)
          : _LockedOut(remaining: _lockRemaining),
  };
}

class _Checking extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Challenge extends StatelessWidget {
  const _Challenge({
    required this.loading,
    required this.attempts,
    required this.maxAttempts,
    required this.controllers,
    required this.focusNodes,
    required this.onVerify,
  });

  final bool loading;
  final int attempts;
  final int maxAttempts;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 600;

    return PopScope(
      canPop: false,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width > 600 ? size.width * 0.2 : 28,
            vertical: compact ? 16 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 68,
                height: compact ? 56 : 68,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security_rounded,
                  size: compact ? 26 : 32,
                  color: cs.onPrimaryContainer,
                ),
              ),
              SizedBox(height: compact ? 16 : 20),
              Text(
                'Verification Required',
                style:
                    (compact
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                'Enter the 6-digit code from your authenticator app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 24 : 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _OtpBox(
                      controller: controllers[i],
                      focusNode: focusNodes[i],
                      compact: compact,
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          focusNodes[i + 1].requestFocus();
                        }
                        if (v.isEmpty && i > 0) {
                          focusNodes[i - 1].requestFocus();
                        }
                        if (controllers.every((c) => c.text.isNotEmpty)) {
                          onVerify();
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (attempts > 0) ...[
                SizedBox(height: compact ? 8 : 10),
                Text(
                  '${maxAttempts - attempts} attempt${maxAttempts - attempts == 1 ? '' : 's'} remaining',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
              SizedBox(height: compact ? 20 : 28),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: loading ? null : onVerify,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(
                    loading ? 'Verifying…' : 'Verify',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedOut extends StatelessWidget {
  const _LockedOut({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).height < 600;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 68,
              height: compact ? 56 : 68,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                size: compact ? 26 : 32,
                color: Colors.red.shade600,
              ),
            ),
            SizedBox(height: compact ? 16 : 20),
            Text(
              'Too Many Attempts',
              style:
                  (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              'Access temporarily blocked. Try again in:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 16 : 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '$mm:$ss',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final boxSize = compact ? 38.0 : 44.0;

    return SizedBox(
      width: boxSize,
      height: boxSize + 6,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

enum _GateState { checking, notEnrolled, verified, challenge, lockedOut }
