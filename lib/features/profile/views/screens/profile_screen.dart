// lib/features/profile/views/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_notifier.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_provider.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_stream_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/features/app/views/screens/home_screen.dart';
import 'package:flutter_education_app/core/widgets/loading_widget.dart';
import 'package:flutter_education_app/core/widgets/material_widget.dart';
import 'package:flutter_education_app/features/profile/views/screens/profile_settings_screen.dart';
import 'package:flutter_education_app/features/profile/views/widgets/error_view.dart';
import 'package:flutter_education_app/features/profile/views/widgets/profile_body.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.viewUserId});

  final String? viewUserId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(profileStreamProvider(widget.viewUserId));
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    if (!_hasAnimated) {
      _hasAnimated = true;
      _animCtrl.forward();
    }
  }

  void _resetAnimation() {
    _hasAnimated = false;
    _animCtrl.reset();
  }

  ProfileNotifier get _notifier =>
      ref.read(profileProvider(widget.viewUserId).notifier);

  Future<void> _handleAvatarChange() async {
    try {
      await _notifier.changeAvatar(context);
      _showSnack('Profile photo updated');
      ref.invalidate(profileStreamProvider(widget.viewUserId));
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    }
  }

  Future<void> _handleCoverChange() async {
    try {
      await _notifier.changeCover(context);
      _showSnack('Cover photo updated');
      ref.invalidate(profileStreamProvider(widget.viewUserId));
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    }
  }

  void _openSettings(profile) {
    if (!_notifier.isOwnProfile || profile == null) return;
    AppNavigator(
      screen: ProfileSettingsScreen(profile: profile),
    ).navigate(context);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileStreamProvider(widget.viewUserId));

    return MaterialWidget(
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: profileAsync.when(
            loading: () => const Center(
              key: ValueKey('loading'),
              child: LoadingIndicator(),
            ),

            error: (error, stackTrace) => ErrorView(
              key: const ValueKey('error'),
              message: error.toString(),
              onRetry: () {
                _resetAnimation();
                ref.invalidate(profileStreamProvider(widget.viewUserId));
              },
            ),

            data: (profileState) {
              if (profileState.loading) {
                return const Center(
                  key: ValueKey('loading'),
                  child: LoadingIndicator(),
                );
              }

              if (profileState.errorMessage != null) {
                return ErrorView(
                  key: const ValueKey('error'),
                  message: profileState.errorMessage!,
                  onRetry: () {
                    _resetAnimation();
                    ref.invalidate(profileStreamProvider(widget.viewUserId));
                  },
                );
              }

              _triggerAnimation();

              return FadeTransition(
                key: const ValueKey('content'),
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ProfileBody(
                    profile: profileState.profile!,
                    isOwnProfile: _notifier.isOwnProfile,
                    uploadingAvatar: profileState.uploadingAvatar,
                    uploadingCover: profileState.uploadingCover,
                    onChangeAvatar: _handleAvatarChange,
                    onChangeCover: _handleCoverChange,
                    onOpenSettings: () => _openSettings(profileState.profile),
                    initials: _initials,
                    capitalize: _capitalize,
                    onBack: () =>
                        AppNavigator(screen: HomeScreen()).navigate(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
