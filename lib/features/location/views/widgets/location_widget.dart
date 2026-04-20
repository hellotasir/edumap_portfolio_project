import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_education_app/core/services/cloud/profile_location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/views/screens/location_screen.dart';
import 'package:flutter_education_app/features/location/views/screens/manage_location_screen.dart';
import 'package:flutter_education_app/features/location/views/widgets/location_tile.dart';
import 'package:flutter_education_app/features/subscription/views/widgets/error_banner.dart';
import 'package:flutter_education_app/features/location/repositories/profile_location_repository.dart';

class LocationWidget extends StatefulWidget {
  const LocationWidget({
    super.key,
    required this.userId,
    required this.role,
    required this.profileLocationService,
    required this.locationService,
    this.onSaved,
  });

  final String userId;
  final String role;
  final ProfileLocationService profileLocationService;
  final LocationService locationService;
  final void Function(LocationModel)? onSaved;

  @override
  State<LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<LocationWidget> {
  bool _isLoading = false;
  LocationModel? _current;
  ProfileLocationSnapshot? _profileSnapshot;
  String? _error;

  bool get _isInstructor => widget.role == 'instructor';

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _listenToProfileSnapshot();
  }

  Future<void> _loadCurrentLocation() async {
    final loc = await widget.profileLocationService
        .watchCurrentLocation(widget.userId, widget.role)
        .first
        .catchError((_) => null);
    if (mounted) setState(() => _current = loc);
  }

  void _listenToProfileSnapshot() {
    widget.profileLocationService.watchProfileLocation(widget.userId).listen((
      snap,
    ) {
      if (mounted) setState(() => _profileSnapshot = snap);
    });
  }

  Future<void> _shareLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final model = await widget.profileLocationService.saveCurrentLocation(
        userId: widget.userId,
        role: widget.role,
      );
      if (mounted) {
        setState(() => _current = model);
        widget.onSaved?.call(model);
        _snack('Location updated & synced to profile', isError: false);
      }
    } on LocationPermissionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on LocationServiceDisabledException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeFromProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from profile?'),
        content: const Text(
          'Your location will no longer appear on your public profile. '
          'Your location records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.profileLocationService.revokeProfileLocation(widget.userId);
      if (mounted) _snack('Location removed from profile', isError: false);
    }
  }

  void _openMap() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: LiveMapScreen(
            currentUserId: widget.userId,
            currentRole: widget.role,
            locationService: widget.locationService,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'My Location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_profileSnapshot != null)
                  _ProfileSyncBadge(theme: theme)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'GPS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Used to calculate distance between you and others.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_profileSnapshot != null) ...[
              const SizedBox(height: 8),
              _ProfileSyncDetail(snapshot: _profileSnapshot!, theme: theme),
            ],
            const Divider(height: 28),
            if (_current != null) ...[
              LocationTile(
                icon: Icons.location_on_rounded,
                label: 'Current position',
                address: _current!.address.formattedAddress,
                accuracy: _current!.accuracy,
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'No location shared yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _shareLocation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(
                  _current == null ? 'Share My Location' : 'Refresh Location',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Track Distance'),
              ),
            ),
            if (_profileSnapshot != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _revokeFromProfile,
                  icon: const Icon(Icons.person_off_rounded),
                  label: const Text('Remove from Profile'),
                ),
              ),
            ],
            if (_isInstructor) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageLocationsScreen(
                        userId: widget.userId,
                        role: widget.role,
                        profileLocationService: widget.profileLocationService,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.home_work_rounded),
                  label: const Text('Manage Saved Addresses'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSyncBadge extends StatelessWidget {
  const _ProfileSyncBadge({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_rounded,
            size: 12,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            'Synced',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSyncDetail extends StatelessWidget {
  const _ProfileSyncDetail({required this.snapshot, required this.theme,
  });

  final ProfileLocationSnapshot snapshot;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (snapshot.city.isNotEmpty) snapshot.city,
      if (snapshot.country.isNotEmpty) snapshot.country,
    ];
    final label = parts.join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_pin_rounded,
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.isNotEmpty
                  ? 'Profile shows: $label'
                  : 'Location synced to your profile',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
