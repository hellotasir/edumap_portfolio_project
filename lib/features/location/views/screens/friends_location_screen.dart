import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/local/user_location_service.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/views/screens/distance_map_screen.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_education_app/features/profile/views/screens/profile_screen.dart';

class FriendLocationData {
  const FriendLocationData({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.profilePhoto,
    required this.locationDoc,
  });

  final String userId;
  final String username;
  final String fullName;
  final String role;
  final String profilePhoto;
  final UserLocationDoc? locationDoc;

  List<UserAddressEntry> get visibleEntries =>
      locationDoc?.visibleEntries ?? [];

  bool get hasVisibleLocations => visibleEntries.isNotEmpty;

  String get displayName => fullName.isNotEmpty ? fullName : '@$username';
}

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
      builder: (_) => _FriendSheet(
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
    return Scaffold(
      appBar: AppBar(
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
          ? _EmptyFriends(theme: theme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _FriendCard(
                friend: _friends[i],
                theme: theme,
                onTap: () => _showFriendSheet(_friends[i]),
              ),
            ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.theme,
    required this.onTap,
  });

  final FriendLocationData friend;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visible = friend.visibleEntries;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Avatar(
                photoUrl: friend.profilePhoto,
                role: friend.role,
                theme: theme,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@${friend.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (visible.isEmpty)
                      Text(
                        'No locations shared',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: visible.take(2).map((e) => _EntryChip(
                          entry: e,
                          theme: theme,
                        )).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  friend.role == 'instructor' ? 'TUTOR' : 'STUDENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.entry, required this.theme});

  final UserAddressEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isInstructor = entry.category == AddressCategory.instructor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isInstructor
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry.type == AddressType.currentLocation
                ? Icons.my_location_rounded
                : Icons.location_on_rounded,
            size: 10,
            color: isInstructor
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            entry.title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: isInstructor
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendSheet extends StatefulWidget {
  const _FriendSheet({
    required this.friend,
    required this.fetchProfile,
    required this.onOpenMap,
    required this.onViewProfile,
  });

  final FriendLocationData friend;
  final Future<ProfileModel?> Function(String) fetchProfile;
  final void Function(UserAddressEntry entry) onOpenMap;
  final VoidCallback onViewProfile;

  @override
  State<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<_FriendSheet> {
  ProfileModel? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.fetchProfile(widget.friend.userId);
    if (mounted) setState(() {
      _profile = p;
      _loadingProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friend = widget.friend;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onViewProfile,
                child: _Avatar(
                  photoUrl: friend.profilePhoto,
                  role: friend.role,
                  theme: theme,
                  radius: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@${friend.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        friend.role == 'instructor' ? 'TUTOR' : 'STUDENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loadingProfile)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_profile != null) ...[
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            if (_profile!.profile.bio.isNotEmpty) ...[
              Text(
                'About',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _profile!.profile.bio,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 8),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          if (friend.visibleEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No visible locations shared by ${friend.username}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Text(
              'Shared Locations  ·  tap to view on map',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: friend.visibleEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final entry = friend.visibleEntries[i];
                  return _SharedEntryTile(
                    entry: entry,
                    theme: theme,
                    onTap: () => widget.onOpenMap(entry),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onViewProfile,
            icon: const Icon(Icons.person_rounded, size: 18),
            label: const Text('View Profile'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedEntryTile extends StatelessWidget {
  const _SharedEntryTile({
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final UserAddressEntry entry;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInstructor = entry.category == AddressCategory.instructor;
    final color = isInstructor
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final bgColor = isInstructor
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;
    final fgColor = isInstructor
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                entry.type == AddressType.currentLocation
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.address.city.isNotEmpty
                        ? entry.address.city
                        : entry.address.formattedAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                entry.category.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.map_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.role,
    required this.theme,
    this.radius = 22,
  });

  final String photoUrl;
  final String role;
  final ThemeData theme;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.secondaryContainer,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(
              role == 'instructor' ? Icons.school_rounded : Icons.person_rounded,
              color: theme.colorScheme.onSecondaryContainer,
              size: radius * 0.9,
            )
          : null,
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to track distance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}