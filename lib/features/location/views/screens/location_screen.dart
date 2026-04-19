import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        CameraFit,
        FlutterMap,
        InteractionOptions,
        InteractiveFlag,
        LatLngBounds,
        MapController,
        MapOptions,
        Marker,
        MarkerLayer,
        PolylineLayer,
        TileLayer,
        Polyline;
import 'package:latlong2/latlong.dart' as ll;

class FriendLocationResult {
  const FriendLocationResult({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.profilePhoto,
    this.location,
  });

  final String userId;
  final String username;
  final String fullName;
  final String role;
  final String profilePhoto;
  final LocationModel? location;
}

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({
    super.key,
    required this.currentUserId,
    required this.currentRole,
    required this.locationService,
  });

  final String currentUserId;
  final String currentRole;
  final LocationService locationService;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final _chatRepository = ChatRepository();
  List<FriendLocationResult> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final friendList = await _chatRepository.getFriendsList(
        widget.currentUserId,
      );
      final results = <FriendLocationResult>[];

      for (final friend in friendList) {
        final uid = friend['user_id'] as String? ?? '';
        final role = friend['role'] as String? ?? 'student';
        if (uid.isEmpty) continue;

        LocationModel? location;
        try {
          location = await widget.locationService.getDefaultLocation(uid, role);
        } catch (_) {}

        results.add(
          FriendLocationResult(
            userId: uid,
            username: friend['username'] as String? ?? '',
            fullName: friend['full_name'] as String? ?? '',
            role: role,
            profilePhoto: friend['profile_photo'] as String? ?? '',
            location: location,
          ),
        );
      }

      if (mounted) setState(() => _friends = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDistanceMap(FriendLocationResult friend) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: DistanceMapScreen(
            currentUserId: widget.currentUserId,
            currentRole: widget.currentRole,
            targetFriend: friend,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Distance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFriends,
          ),
        ],
      ),
      body: NetworkWidget(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
          ? _EmptyFriends()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _friends.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return _FriendLocationCard(
                  friend: friend,
                  onTap: () => _openDistanceMap(friend),
                );
              },
              ),
      ),
    );
  }
}

class DistanceMapScreen extends StatefulWidget {
  const DistanceMapScreen({
    super.key,
    required this.currentUserId,
    required this.currentRole,
    required this.targetFriend,
    required this.locationService,
  });

  final String currentUserId;
  final String currentRole;
  final FriendLocationResult targetFriend;
  final LocationService locationService;

  @override
  State<DistanceMapScreen> createState() => _DistanceMapScreenState();
}

class _DistanceMapScreenState extends State<DistanceMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  LocationModel? _myLocation;
  LocationModel? _theirLocation;
  double? _distanceKm;
  bool _loading = true;
  bool _isRefreshing = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  StreamSubscription? _mySub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mySub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _mySub = widget.locationService
          .watchCurrentLocation(widget.currentUserId, widget.currentRole)
          .listen((loc) {
            if (mounted) {
              setState(() => _myLocation = loc);
              _recalculate();
              if (loc != null && _theirLocation != null) _fitBounds();
            }
          });

      _theirLocation =
          widget.targetFriend.location ??
          await widget.locationService.getDefaultLocation(
            widget.targetFriend.userId,
            widget.targetFriend.role,
          );

      _recalculate();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
      _fitBounds();
    }
  }

  void _recalculate() {
    if (_myLocation == null || _theirLocation == null) return;
    final km = _haversineKm(
      _myLocation!.coordinates,
      _theirLocation!.coordinates,
    );
    setState(() => _distanceKm = km);
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;

  void _fitBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_myLocation != null && _theirLocation != null) {
        final bounds = LatLngBounds(
          ll.LatLng(
            math.min(
              _myLocation!.coordinates.latitude,
              _theirLocation!.coordinates.latitude,
            ),
            math.min(
              _myLocation!.coordinates.longitude,
              _theirLocation!.coordinates.longitude,
            ),
          ),
          ll.LatLng(
            math.max(
              _myLocation!.coordinates.latitude,
              _theirLocation!.coordinates.latitude,
            ),
            math.max(
              _myLocation!.coordinates.longitude,
              _theirLocation!.coordinates.longitude,
            ),
          ),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
        );
      } else {
        final loc = _myLocation ?? _theirLocation;
        if (loc != null) {
          _mapController.move(
            ll.LatLng(loc.coordinates.latitude, loc.coordinates.longitude),
            13,
          );
        }
      }
    });
  }

  Future<void> _refreshMyLocation() async {
    setState(() => _isRefreshing = true);
    try {
      final model = await widget.locationService.saveCurrentLocation(
        userId: widget.currentUserId,
        role: widget.currentRole,
      );
      if (mounted) {
        setState(() => _myLocation = model);
        _recalculate();
        _fitBounds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            _buildMap(theme),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _MapIconButton(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _MapIconButton(
              onTap: _isRefreshing ? null : _refreshMyLocation,
              child: _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DistancePanel(
              friend: widget.targetFriend,
              myLocation: _myLocation,
              theirLocation: _theirLocation,
              distanceKm: _distanceKm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    final myLL = _myLocation != null
        ? ll.LatLng(
            _myLocation!.coordinates.latitude,
            _myLocation!.coordinates.longitude,
          )
        : null;
    final theirLL = _theirLocation != null
        ? ll.LatLng(
            _theirLocation!.coordinates.latitude,
            _theirLocation!.coordinates.longitude,
          )
        : null;

    final center = myLL ?? theirLL ?? const ll.LatLng(23.8103, 90.4125);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.edumap.app',
        ),
        if (myLL != null && theirLL != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [myLL, theirLL],
                color: theme.colorScheme.primary,
                strokeWidth: 2.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (myLL != null)
              Marker(
                point: myLL,
                width: 60,
                height: 60,
                child: _PulsingMarker(
                  animation: _pulseAnim,
                  color: theme.colorScheme.primary,
                  icon: Icons.person_pin_circle_rounded,
                  label: 'You',
                  theme: theme,
                ),
              ),
            if (theirLL != null)
              Marker(
                point: theirLL,
                width: 60,
                height: 60,
                child: _StaticMarker(
                  color: theme.colorScheme.tertiary,
                  icon: widget.targetFriend.role == 'instructor'
                      ? Icons.school_rounded
                      : Icons.person_rounded,
                  label: widget.targetFriend.username,
                  theme: theme,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({
    required this.animation,
    required this.color,
    required this.icon,
    required this.label,
    required this.theme,
  });

  final Animation<double> animation;
  final Color color;
  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 42 * animation.value,
                height: 42 * animation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2 * animation.value),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticMarker extends StatelessWidget {
  const _StaticMarker({
    required this.color,
    required this.icon,
    required this.label,
    required this.theme,
  });

  final Color color;
  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: theme.colorScheme.onTertiary, size: 18),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiary,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DistancePanel extends StatelessWidget {
  const _DistancePanel({
    required this.friend,
    required this.myLocation,
    required this.theirLocation,
    required this.distanceKm,
  });

  final FriendLocationResult friend;
  final LocationModel? myLocation;
  final LocationModel? theirLocation;
  final double? distanceKm;

  String _formatDistance(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FriendAvatar(
                  photoUrl: friend.profilePhoto,
                  role: friend.role,
                  theme: theme,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.fullName.isNotEmpty
                            ? friend.fullName
                            : '@${friend.username}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${friend.username}  ·  ${friend.role.toUpperCase()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatDistance(distanceKm!),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'away',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            if (myLocation != null)
              _AddressRow(
                icon: Icons.my_location_rounded,
                label: 'Your location',
                address: myLocation!.address.formattedAddress,
                theme: theme,
                isPrimary: true,
              ),
            if (myLocation != null && theirLocation != null)
              const SizedBox(height: 8),
            if (theirLocation != null)
              _AddressRow(
                icon: friend.role == 'instructor'
                    ? Icons.school_rounded
                    : Icons.person_rounded,
                label: '${friend.username}\'s location',
                address: theirLocation!.address.formattedAddress,
                theme: theme,
                isPrimary: false,
              ),
            if (myLocation == null)
              _WarningRow(
                message: 'Your location not found. Tap refresh above.',
                theme: theme,
              ),
            if (theirLocation == null)
              _WarningRow(
                message: '${friend.username} has not shared their location.',
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.theme,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final String address;
  final ThemeData theme;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.message, required this.theme});
  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendLocationCard extends StatelessWidget {
  const _FriendLocationCard({required this.friend, required this.onTap});

  final FriendLocationResult friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FriendAvatar(
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
                      friend.fullName.isNotEmpty
                          ? friend.fullName
                          : '@${friend.username}',
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
                    if (friend.location != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              friend.location!.address.city.isNotEmpty
                                  ? friend.location!.address.city
                                  : friend.location!.address.formattedAddress,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No location shared',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({
    required this.photoUrl,
    required this.role,
    required this.theme,
  });

  final String photoUrl;
  final String role;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.secondaryContainer,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(
              role == 'instructor'
                  ? Icons.school_rounded
                  : Icons.person_rounded,
              color: theme.colorScheme.onSecondaryContainer,
              size: 22,
            )
          : null,
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconTheme(
          data: IconThemeData(color: theme.colorScheme.onSurface, size: 18),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
