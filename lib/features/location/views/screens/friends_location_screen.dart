import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/core/services/local/user_location_service.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:edumap_portfolio_project/features/location/views/screens/distance_map_screen.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/empty_friends.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/friend_card.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/friend_sheet.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/repositories/profile_repository.dart';
import 'package:edumap_portfolio_project/features/profile/views/screens/profile_screen.dart';

class FriendsLocationScreen extends StatefulWidget {
  const FriendsLocationScreen({
    super.key,
    required this.currentUserId,
    required this.locationService,
  });

  final String currentUserId;
  final UserLocationService locationService;

  @override
  State<FriendsLocationScreen> createState() => _FriendsLocationScreenState();
}

class _FriendsLocationScreenState extends State<FriendsLocationScreen> {
  final _chatRepository = ChatRepository();
  final _profileRepository = ProfileRepository();
  List<FriendLocationData> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final friendList = await _chatRepository.getFriendsList(widget.currentUserId);
      final results = <FriendLocationData>[];
      for (final friend in friendList) {
        final uid = friend['user_id'] as String? ?? '';
        if (uid.isEmpty) continue;
        UserLocationDoc? doc;
        try {
          doc = await widget.locationService.getUserLocations(uid);
        } catch (_) {}
        results.add(
          FriendLocationData(
            userId: uid,
            username: friend['username'] as String? ?? '',
            fullName: friend['full_name'] as String? ?? '',
            role: friend['role'] as String? ?? 'student',
            profilePhoto: friend['profile_photo'] as String? ?? '',
            locationDoc: doc,
          ),
        );
      }
      if (mounted) setState(() => _friends = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<ProfileModel?> _fetchProfile(String userId) async {
    try {
      final collectionPath = _profileRepository.collectionPath.firstOrNull;
      if (collectionPath == null) return null;
      final snap = await FirebaseFirestore.instance
          .collection(collectionPath)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return _profileRepository.fromSnapshot(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  void _showFriendSheet(FriendLocationData friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FriendSheet(
        friend: friend,
        fetchProfile: _fetchProfile,
        onOpenMap: (entry) {
          Navigator.pop(context);
          _openDistanceMap(friend, entry);
        },
        onViewProfile: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(viewUserId: friend.userId),
            ),
          );
        },
      ),
    );
  }

  void _openDistanceMap(FriendLocationData friend, UserAddressEntry targetEntry) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: DistanceMapScreen(
            currentUserId: widget.currentUserId,
            targetFriend: friend,
            targetEntry: targetEntry,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NetworkWidget(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Track Distance'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _loadFriends,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _friends.isEmpty
            ? EmptyFriends(theme: theme)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _friends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => FriendCard(
                  friend: _friends[i],
                  theme: theme,
                  onTap: () => _showFriendSheet(_friends[i]),
                ),
              ),
      ),
    );
  }
}




