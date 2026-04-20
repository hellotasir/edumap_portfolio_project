import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_education_app/core/services/cloud/profile_location_service.dart';
import 'package:flutter_education_app/core/widgets/loading_widget.dart';
import 'package:flutter_education_app/features/app/views/widgets/home_empty_profile_state.dart';
import 'package:flutter_education_app/features/app/views/widgets/home_empty_state.dart';
import 'package:flutter_education_app/features/app/views/widgets/home_profile_avatar.dart';
import 'package:flutter_education_app/features/app/views/widgets/others/mfa_widget.dart';
import 'package:flutter_education_app/features/location/repositories/profile_location_repository.dart';
import 'package:flutter_education_app/features/location/views/view_models/profile_location_adapter.dart';
import 'package:flutter_education_app/features/location/views/widgets/location_widget.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/core/consts/app_details.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_education_app/features/chat/views/widgets/inbox_widget.dart';
import 'package:flutter_education_app/features/profile/views/screens/profile_screen.dart';

enum _HomeTab {
  inbox(
    label: 'Inbox',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
  ),
  location(
    label: 'Location',
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on_rounded,
  );

  const _HomeTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  _HomeTab _currentTab = _HomeTab.inbox;

  final _profileRepository = ProfileRepository();
  final _authRepository = AuthRepository();
  final _chatRepository = ChatRepository();
  late final _locationService = LocationService();
  late final _profileLocationRepository = ProfileLocationRepository();
  late final _profileLocationService = ProfileLocationService(
    locationService: _locationService,
    profileLocationRepository: _profileLocationRepository,
  );

  Stream<ProfileModel?>? _profileStream;
  StreamSubscription<ProfileModel?>? _profileSub;
  ProfileModel? _cachedProfile;
  Object? _profileError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProfileStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileSub?.cancel();
    super.dispose();
  }

  void _initProfileStream() {
    final userId = _authRepository.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      setState(() => _profileError = 'User is not authenticated.');
      return;
    }

    final collectionPath = _profileRepository.collectionPath.firstOrNull;
    if (collectionPath == null || collectionPath.isEmpty) {
      setState(() => _profileError = 'Invalid collection path.');
      return;
    }

    _profileStream = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return _profileRepository.fromSnapshot(snapshot.docs.first);
        });

    _profileSub = _profileStream!.listen(
      (profile) {
        if (!mounted) return;
        setState(() {
          if (profile != null) _cachedProfile = profile;
          _profileError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _profileError = error);
      },
    );
  }

  Widget _buildPage(_HomeTab tab, ProfileModel profile) {
    return switch (tab) {
      _HomeTab.inbox => InboxWidget(
        currentUserId: profile.userId,
        currentUsername: profile.username,
        currentProfilePhoto: profile.profile.profilePhoto,
        chatRepository: _chatRepository,
      ),
      _HomeTab.location => LocationWidget(
        userId: profile.userId,
        role: profile.currentMode,
        profileLocationService: _profileLocationService,
        locationService: ProfileLocationAdapter(
          profileLocationService: _profileLocationService,
          locationService: _locationService,
        ),
      ),
    };
  }

  void _onTabTapped(int index) {
    final tab = _HomeTab.values[index];
    if (tab == _currentTab) return;
    HapticFeedback.selectionClick();
    setState(() => _currentTab = tab);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return StreamBuilder<ProfileModel?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? _cachedProfile;
        final isFirstLoad =
            snapshot.connectionState == ConnectionState.waiting &&
            profile == null;
        final hasError = _profileError != null || snapshot.hasError;

        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 2,
            elevation: 0,
            leadingWidth: 56,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              child: Image.asset(
                isDark
                    ? 'assets/edumap-black-transparent-icon.png'
                    : 'assets/edumap-transparent-icon.png',
                fit: BoxFit.contain,
              ),
            ),
            title: Text(
              appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Profile',
                  onPressed: _openProfile,
                  icon: HomeProfileAvatar(
                    isLoading: isFirstLoad,
                    profile: profile,
                  ),
                ),
              ),
            ],
          ),
          body: MfaWidget(
            authRepository: AuthRepository(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildBody(
                context,
                isFirstLoad: isFirstLoad,
                hasError: hasError,
                profile: profile,
                colorScheme: colorScheme,
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTab.index,
            onDestinationSelected: _onTabTapped,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: _HomeTab.values
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isFirstLoad,
    required bool hasError,
    required ProfileModel? profile,
    required ColorScheme colorScheme,
  }) {
    if (isFirstLoad) return const Center(child: LoadingIndicator());

    if (hasError) {
      return HomeErrorState(
        key: const ValueKey('error'),
        message: _friendlyError(_profileError ?? 'Unknown error'),
        onRetry: () {
          setState(() {
            _profileError = null;
            _cachedProfile = null;
          });
          _profileSub?.cancel();
          _initProfileStream();
        },
      );
    }

    if (profile == null) {
      return const HomeEmptyProfileState(key: ValueKey('empty'));
    }

    return KeyedSubtree(
      key: ValueKey(_currentTab),
      child: _buildPage(_currentTab, profile),
    );
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'You don\'t have permission to access this data.',
        'unavailable' =>
          'Service is temporarily unavailable. Please try again.',
        'not-found' => 'Your profile data could not be found.',
        _ => 'A network error occurred (${error.code}).',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}
