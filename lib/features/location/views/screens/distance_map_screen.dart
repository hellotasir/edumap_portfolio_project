import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/local/user_location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/views/screens/friends_location_screen.dart';
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

class DistanceMapScreen extends StatefulWidget {
  const DistanceMapScreen({
    super.key,
    required this.currentUserId,
    required this.targetFriend,
    required this.targetEntry,
    required this.locationService,
  });

  final String currentUserId;
  final FriendLocationData targetFriend;
  final UserAddressEntry targetEntry;
  final UserLocationService locationService;

  @override
  State<DistanceMapScreen> createState() => _DistanceMapScreenState();
}

class _DistanceMapScreenState extends State<DistanceMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  UserAddressEntry? _myBestEntry;
  UserAddressEntry? _theirEntry;
  double? _distanceKm;
  bool _loading = true;
  bool _isRefreshing = false;

  AddressCategory? _selectedCategory;
  List<AddressCategory> _availableCategories = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  StreamSubscription<UserLocationDoc>? _mySub;

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

    _theirEntry = widget.targetEntry;
    _availableCategories =
        widget.targetFriend.locationDoc?.visibleEntries
            .map((e) => e.category)
            .toSet()
            .toList() ??
        [widget.targetEntry.category];
    _selectedCategory = widget.targetEntry.category;

    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mySub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _mySub = widget.locationService
          .watchMyLocations(widget.currentUserId)
          .listen((doc) {
            if (!mounted) return;
            setState(() {
              _myBestEntry = _pickMyBest(doc);
            });
            _recalculate();
            _fitBounds();
          });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fitBounds();
      }
    }
  }

  UserAddressEntry? _pickMyBest(UserLocationDoc doc) {
    final current = doc.currentLocation;
    if (current != null && current.isVisible) return current;
    final visible = doc.visibleEntries;
    if (visible.isEmpty) return null;
    return visible.first;
  }

  void _switchCategory(AddressCategory cat) {
    final entries = widget.targetFriend.locationDoc?.visibleEntries ?? [];
    final match = entries.firstWhereOrNull((e) => e.category == cat);
    setState(() {
      _selectedCategory = cat;
      _theirEntry = match;
    });
    _recalculate();
    _fitBounds();
  }

  void _recalculate() {
    if (_myBestEntry == null || _theirEntry == null) return;
    final km = widget.locationService.haversineKm(
      _myBestEntry!.coordinates,
      _theirEntry!.coordinates,
    );
    if (mounted) setState(() => _distanceKm = km);
  }

  void _fitBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_myBestEntry != null && _theirEntry != null) {
        final a = _myBestEntry!.coordinates;
        final b = _theirEntry!.coordinates;
        final latDiff = (a.latitude - b.latitude).abs();
        final lonDiff = (a.longitude - b.longitude).abs();
        const epsilon = 0.0001;
        if (latDiff < epsilon && lonDiff < epsilon) {
          _mapController.move(ll.LatLng(a.latitude, a.longitude), 15);
          return;
        }
        final bounds = LatLngBounds(
          ll.LatLng(
            math.min(a.latitude, b.latitude),
            math.min(a.longitude, b.longitude),
          ),
          ll.LatLng(
            math.max(a.latitude, b.latitude),
            math.max(a.longitude, b.longitude),
          ),
        );
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
        );
      } else {
        final loc = _myBestEntry ?? _theirEntry;
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
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.locationService.shareCurrentLocation(
        userId: widget.currentUserId,
        title: 'My Current Location',
        category: AddressCategory.student,
        isVisible: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update location: $e'),
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
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            _buildMap(theme),
          Positioned(
            top: topPad + 8,
            left: 16,
            child: _MapButton(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Positioned(
            top: topPad + 8,
            right: 16,
            child: Row(
              children: [
                if (_availableCategories.length > 1)
                  _CategoryToggle(
                    categories: _availableCategories,
                    selected: _selectedCategory ?? _availableCategories.first,
                    onSelected: _switchCategory,
                    theme: theme,
                  ),
                const SizedBox(width: 8),
                _MapButton(
                  onTap: _isRefreshing ? null : _refreshMyLocation,
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DistancePanel(
              friend: widget.targetFriend,
              theirEntry: _theirEntry,
              myEntry: _myBestEntry,
              distanceKm: _distanceKm,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    final myLL = _myBestEntry != null
        ? ll.LatLng(
            _myBestEntry!.coordinates.latitude,
            _myBestEntry!.coordinates.longitude,
          )
        : null;
    final theirLL = _theirEntry != null
        ? ll.LatLng(
            _theirEntry!.coordinates.latitude,
            _theirEntry!.coordinates.longitude,
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
                width: 72,
                height: 80,
                child: _PulsingMarker(
                  animation: _pulseAnim,
                  color: theme.colorScheme.primary,
                  label: 'You',
                  photoUrl: '',
                  fallbackIcon: Icons.person_pin_circle_rounded,
                  theme: theme,
                ),
              ),
            if (theirLL != null)
              Marker(
                point: theirLL,
                width: 72,
                height: 80,
                child: _StaticMarker(
                  color: theme.colorScheme.tertiary,
                  label: widget.targetFriend.displayName,
                  photoUrl: widget.targetFriend.profilePhoto,
                  fallbackIcon:
                      _theirEntry?.category == AddressCategory.instructor
                      ? Icons.school_rounded
                      : Icons.person_rounded,
                  theme: theme,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryToggle extends StatelessWidget {
  const _CategoryToggle({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.theme,
  });

  final List<AddressCategory> categories;
  final AddressCategory selected;
  final void Function(AddressCategory) onSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: categories.map((cat) {
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat == AddressCategory.instructor
                        ? Icons.school_rounded
                        : Icons.person_rounded,
                    size: 13,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cat.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PulsingMarker extends StatelessWidget {
  const _PulsingMarker({
    required this.animation,
    required this.color,
    required this.label,
    required this.photoUrl,
    required this.fallbackIcon,
    required this.theme,
  });

  final Animation<double> animation;
  final Color color;
  final String label;
  final String photoUrl;
  final IconData fallbackIcon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52 * animation.value,
                height: 52 * animation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2 * animation.value),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.45),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(color),
                        )
                      : _fallback(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(Color color) => Container(
    color: color.withOpacity(0.15),
    child: Icon(fallbackIcon, color: color, size: 22),
  );
}

class _StaticMarker extends StatelessWidget {
  const _StaticMarker({
    required this.color,
    required this.label,
    required this.photoUrl,
    required this.fallbackIcon,
    required this.theme,
  });

  final Color color;
  final String label;
  final String photoUrl;
  final IconData fallbackIcon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          constraints: const BoxConstraints(maxWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

  Widget _fallback() => Container(
    color: color.withOpacity(0.15),
    child: Icon(fallbackIcon, color: color, size: 22),
  );
}

class _DistancePanel extends StatelessWidget {
  const _DistancePanel({
    required this.friend,
    required this.theirEntry,
    required this.myEntry,
    required this.distanceKm,
    required this.theme,
  });

  final FriendLocationData friend;
  final UserAddressEntry? theirEntry;
  final UserAddressEntry? myEntry;
  final double? distanceKm;
  final ThemeData theme;

  String _fmt(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  backgroundImage: friend.profilePhoto.isNotEmpty
                      ? NetworkImage(friend.profilePhoto)
                      : null,
                  child: friend.profilePhoto.isEmpty
                      ? Icon(
                          friend.role == 'instructor'
                              ? Icons.school_rounded
                              : Icons.person_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (theirEntry != null)
                        Text(
                          '${theirEntry!.title}  ·  ${theirEntry!.category.label}',
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
                          _fmt(distanceKm!),
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
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 10),
            if (myEntry != null)
              _AddrRow(
                icon: Icons.my_location_rounded,
                label: 'Your location  ·  ${myEntry!.title}',
                address: myEntry!.address.formattedAddress,
                isPrimary: true,
                theme: theme,
              ),
            if (myEntry != null && theirEntry != null)
              const SizedBox(height: 8),
            if (theirEntry != null)
              _AddrRow(
                icon: theirEntry!.category == AddressCategory.instructor
                    ? Icons.school_rounded
                    : Icons.person_rounded,
                label: "${friend.username}'s ${theirEntry!.title}",
                address: theirEntry!.address.formattedAddress,
                isPrimary: false,
                theme: theme,
              ),
            if (myEntry == null)
              _WarnRow(
                message: 'Your location not found. Tap refresh above.',
                theme: theme,
              ),
            if (theirEntry == null)
              _WarnRow(
                message:
                    '${friend.username} has no visible location for this category.',
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddrRow extends StatelessWidget {
  const _AddrRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.isPrimary,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String address;
  final bool isPrimary;
  final ThemeData theme;

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

class _WarnRow extends StatelessWidget {
  const _WarnRow({required this.message, required this.theme});

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

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap, required this.child});

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

extension _FirstWhereOrNullX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
