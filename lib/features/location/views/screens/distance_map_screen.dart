import 'dart:async';
import 'dart:math' as math;
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/consts/api_keys.dart';
import 'package:edumap_portfolio_project/core/services/local/user_location_service.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/category_toggle.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/distance_panel.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/map_button.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/plusing_marker.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/static_marker.dart';
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
          .listen((UserLocationDoc doc) {
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

    return NetworkWidget(
      child: Scaffold(
        body: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              _buildMap(theme),
            Positioned(
              top: topPad + 8,
              left: 16,
              child: MapButton(
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
                    CategoryToggle(
                      categories: _availableCategories,
                      selected: _selectedCategory ?? _availableCategories.first,
                      onSelected: _switchCategory,
                      theme: theme,
                    ),
                  const SizedBox(width: 8),
                  MapButton(
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
              child: DistancePanel(
                friend: widget.targetFriend,
                theirEntry: _theirEntry,
                myEntry: _myBestEntry,
                distanceKm: _distanceKm,
                theme: theme,
              ),
            ),
          ],
        ),
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
              urlTemplate,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.flutter_education_app',
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
                child: PulsingMarker(
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
                child: StaticMarker(
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

extension _FirstWhereOrNullX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
