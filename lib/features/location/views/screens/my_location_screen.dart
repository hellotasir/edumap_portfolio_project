import 'dart:async';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/local/user_location_service.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:edumap_portfolio_project/features/location/views/screens/friends_location_screen.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/address_card.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/empty_state.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/header_card.dart';

import '../widgets/add_address_sheet.dart';

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
    _sub = widget.locationService.watchMyLocations(widget.userId).listen((
      UserLocationDoc doc,
    ) {
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
      builder: (_) => AddAddressSheet(
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
            if (mounted) {
              _snack('Could not find address: ${e.message}', isError: true);
            }
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

    return NetworkWidget(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: HeaderCard(
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
                child: EmptyState(theme: theme),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => AddressCard(
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
      ),
    );
  }
}




