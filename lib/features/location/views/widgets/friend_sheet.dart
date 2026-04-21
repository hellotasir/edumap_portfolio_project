import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/location/models/location_model.dart';
import 'package:flutter_education_app/features/location/views/widgets/avatar.dart';
import 'package:flutter_education_app/features/location/views/widgets/shared_entry_tile.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';

class FriendSheet extends StatefulWidget {
  const FriendSheet({
    super.key,
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
  State<FriendSheet> createState() => FriendSheetState();
}

class FriendSheetState extends State<FriendSheet> {
  ProfileModel? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.fetchProfile(widget.friend.userId);
    if (mounted)
      setState(() {
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
                child: Avatar(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                  return SharedEntryTile(
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
