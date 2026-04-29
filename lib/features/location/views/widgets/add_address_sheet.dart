import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/category_chip.dart';

import 'error_banner.dart';

class AddAddressSheet extends StatefulWidget {
  const AddAddressSheet({super.key, required this.onSave});

  final Future<void> Function(
    String title,
    AddressCategory category,
    String rawAddress,
    bool isVisible,
  )
  onSave;

  @override
  State<AddAddressSheet> createState() => AddAddressSheetState();
}

class AddAddressSheetState extends State<AddAddressSheet> {
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
              CategoryChip(
                label: 'Student',
                icon: Icons.person_rounded,
                selected: _category == AddressCategory.student,
                onTap: () =>
                    setState(() => _category = AddressCategory.student),
                theme: theme,
              ),
              const SizedBox(width: 8),
              CategoryChip(
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
            ErrorBanner(message: _error!, theme: theme),
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
