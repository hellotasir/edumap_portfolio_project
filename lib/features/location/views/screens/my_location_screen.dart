import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/local/user_location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/views/screens/friends_location_screen.dart';

class MyLocationScreen extends StatefulWidget {
  const MyLocationScreen({
    super.key,
    required this.userId,
    required this.locationService,
  });

  final String userId;
  final UserLocationService locationService;

  @override
  State<MyLocationScreen> createState() => _MyLocationScreenState();
}

class _MyLocationScreenState extends State<MyLocationScreen> {
  StreamSubscription<UserLocationDoc>? _sub;
  UserLocationDoc? _doc;
  bool _loadingGps = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _sub = widget.locationService.watchMyLocations(widget.userId).listen((doc) {
      if (mounted) setState(() => _doc = doc);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _shareCurrentLocation() async {
    setState(() {
      _loadingGps = true;
      _gpsError = null;
    });
    try {
      await widget.locationService.shareCurrentLocation(
        userId: widget.userId,
        title: 'My Current Location',
        category: AddressCategory.student,
        isVisible: true,
      );
      if (mounted) _snack('Current location updated');
    } on LocationPermissionException catch (e) {
      if (mounted) setState(() => _gpsError = e.message);
    } on LocationServiceDisabledException catch (e) {
      if (mounted) setState(() => _gpsError = e.message);
    } catch (e) {
      if (mounted) setState(() => _gpsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  void _openAddAddress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAddressSheet(
        onSave: (title, category, rawAddress, isVisible) async {
          Navigator.pop(context);
          try {
            await widget.locationService.addSavedAddress(
              userId: widget.userId,
              title: title,
              category: category,
              rawAddress: rawAddress,
              isVisible: isVisible,
            );
            if (mounted) _snack('Address saved');
          } on GeocodingException catch (e) {
            if (mounted)
              _snack('Could not find address: ${e.message}', isError: true);
          } catch (e) {
            if (mounted) _snack(e.toString(), isError: true);
          }
        },
      ),
    );
  }

  Future<void> _toggleVisibility(UserAddressEntry entry) async {
    try {
      await widget.locationService.toggleVisibility(
        userId: widget.userId,
        entryId: entry.entryId,
        isVisible: !entry.isVisible,
      );
    } catch (_) {}
  }

  Future<void> _deleteEntry(UserAddressEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(entry.title),
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
    if (confirmed == true) {
      await widget.locationService.deleteEntry(
        userId: widget.userId,
        entryId: entry.entryId,
      );
      if (mounted) _snack('Deleted');
    }
  }

  void _openFriendsMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsLocationScreen(
          currentUserId: widget.userId,
          locationService: widget.locationService,
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _doc?.entries ?? [];

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _HeaderCard(
                theme: theme,
                loadingGps: _loadingGps,
                gpsError: _gpsError,
                hasCurrent: _doc?.currentLocation != null,
                onShareGps: _shareCurrentLocation,
                onTrackDistance: _openFriendsMap,
                onAddAddress: _openAddAddress,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(theme: theme),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _AddressCard(
                  entry: entries[i],
                  theme: theme,
                  onToggleVisibility: () => _toggleVisibility(entries[i]),
                  onDelete: entries[i].type == AddressType.saved
                      ? () => _deleteEntry(entries[i])
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.theme,
    required this.loadingGps,
    required this.gpsError,
    required this.hasCurrent,
    required this.onShareGps,
    required this.onTrackDistance,
    required this.onAddAddress,
  });

  final ThemeData theme;
  final bool loadingGps;
  final String? gpsError;
  final bool hasCurrent;
  final VoidCallback onShareGps;
  final VoidCallback onTrackDistance;
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Locations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Manage what others can see',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (gpsError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: gpsError!, theme: theme),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loadingGps ? null : onShareGps,
                    icon: loadingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed_rounded, size: 18),
                    label: Text(hasCurrent ? 'Refresh GPS' : 'Share GPS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddAddress,
                    icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                    label: const Text('Add Address'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTrackDistance,
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: const Text('Track Distance with Friends'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.entry,
    required this.theme,
    required this.onToggleVisibility,
    this.onDelete,
  });

  final UserAddressEntry entry;
  final ThemeData theme;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isCurrent = entry.type == AddressType.currentLocation;
    final catColor = entry.category == AddressCategory.instructor
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final catBg = entry.category == AddressCategory.instructor
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;
    final catFg = entry.category == AddressCategory.instructor
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    color: catColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GPS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          entry.category.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: catFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: entry.isVisible,
                  onChanged: (_) => onToggleVisibility(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.address.formattedAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (entry.accuracy != null && isCurrent) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 12,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '±${entry.accuracy!.toStringAsFixed(0)} m accuracy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
            Row(
              children: [
                const Spacer(),
                Text(
                  entry.isVisible ? 'Visible to friends' : 'Hidden',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: entry.isVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet({required this.onSave});

  final Future<void> Function(
    String title,
    AddressCategory category,
    String rawAddress,
    bool isVisible,
  )
  onSave;

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  AddressCategory _category = AddressCategory.student;
  bool _isVisible = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();
    if (title.isEmpty || address.isEmpty) {
      setState(() => _error = 'Title and address are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(title, _category, address, _isVisible);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

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
          Text(
            'Add New Address',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Home, Studio, University',
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Category',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              _CategoryChip(
                label: 'Student',
                icon: Icons.person_rounded,
                selected: _category == AddressCategory.student,
                onTap: () =>
                    setState(() => _category = AddressCategory.student),
                theme: theme,
              ),
              const SizedBox(width: 8),
              _CategoryChip(
                label: 'Tutor',
                icon: Icons.school_rounded,
                selected: _category == AddressCategory.instructor,
                onTap: () =>
                    setState(() => _category = AddressCategory.instructor),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: _isVisible,
                onChanged: (v) => setState(() => _isVisible = v),
              ),
              const SizedBox(width: 8),
              Text(
                _isVisible ? 'Visible to friends' : 'Hidden from friends',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _error!, theme: theme),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Address'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.theme});

  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No locations yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share your GPS or add a saved address.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
