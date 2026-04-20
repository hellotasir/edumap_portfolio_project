import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/cloud/profile_location_service.dart';
import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/repositories/profile_location_repository.dart';
import 'package:flutter_education_app/features/location/views/widgets/save_address_tile.dart';
import 'package:flutter_education_app/features/subscription/views/widgets/error_banner.dart';

class ManageLocationsScreen extends StatefulWidget {
  const ManageLocationsScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.profileLocationService,
  });

  final String userId;
  final String role;
  final ProfileLocationService profileLocationService;

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  bool _addLoading = false;
  String? _error;

  final _addressController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _addCustomAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter an address.');
      return;
    }

    setState(() {
      _addLoading = true;
      _error = null;
    });

    try {
      await widget.profileLocationService.saveCustomLocation(
        userId: widget.userId,
        role: widget.role,
        rawAddress: address,
        label: _labelController.text.trim().isNotEmpty
            ? _labelController.text.trim()
            : null,
        isVisible: true,
      );
      if (mounted) {
        _addressController.clear();
        _labelController.clear();
        _snack('Address saved & profile updated');
      }
    } on GeocodingException catch (e) {
      if (mounted)
        setState(() => _error = 'Could not find address: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _addLoading = false);
    }
  }

  Future<void> _setDefault(LocationModel model) async {
    if (model.id == null) return;
    await widget.profileLocationService.setDefaultLocation(
      userId: widget.userId,
      role: widget.role,
      locationId: model.id!,
    );
    _snack('Default address updated');
  }

  Future<void> _delete(LocationModel model) async {
    if (model.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(model.label ?? model.address.formattedAddress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && model.id != null) {
      await widget.profileLocationService.deleteCustomLocation(model.id!);
      if (mounted) _snack('Address deleted');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<ProfileLocationSnapshot?>(
              stream: widget.profileLocationService.watchProfileLocation(
                widget.userId,
              ),
              builder: (context, snapshot) {
                final profileLocation = snapshot.data;
                if (profileLocation == null) return const SizedBox.shrink();
                return _ProfileSyncCard(
                  snapshot: profileLocation,
                  theme: theme,
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<LocationModel>>(
              stream: widget.profileLocationService.watchAllLocations(
                widget.userId,
                widget.role,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final locations = (snapshot.data ?? [])
                    .where((l) => l.type == LocationType.customAddress)
                    .toList();

                if (locations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No saved addresses yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return Column(
                  children: locations
                      .map(
                        (loc) => SavedAddressTile(
                          location: loc,
                          onSetDefault: () => _setDefault(loc),
                          onDelete: () => _delete(loc),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Add New Address',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Home, Studio',
                prefixIcon: Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address *',
                hintText: 'e.g. 221B Baker Street, London',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustomAddress(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addLoading ? null : _addCustomAddress,
                icon: _addLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Save Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSyncCard extends StatelessWidget {
  const _ProfileSyncCard({required this.snapshot, required this.theme});

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            color: theme.colorScheme.tertiary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile location synced',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer.withOpacity(
                        0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
