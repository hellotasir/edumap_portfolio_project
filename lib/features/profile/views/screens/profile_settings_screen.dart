import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/mfa_widget.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/repositories/profile_repository.dart';
import 'package:edumap_portfolio_project/core/services/cloud/database_service.dart';
import 'dart:async';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, this.profile});

  final ProfileModel? profile;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _service = DatabaseService<ProfileModel>(ProfileRepository());
  final _formKey = GlobalKey<FormState>();

  late ProfileMode _selectedMode;
  late StudentLevel _selectedLevel;
  bool _saving = false;
  bool _dirty = false;
  bool _checkingUsername = false;
  bool _usernameAvailable = true;
  String? _usernameError;
  Gender _gender = Gender.preferNotToSay;
  Timer? _debounceTimer;

  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();

  static const _genderOptions = [Gender.male, Gender.female];

  List<TextEditingController> get _controllers => [
        _fullNameCtrl,
        _usernameCtrl,
        _bioCtrl,
        _phoneCtrl,
        _countryCtrl,
        _cityCtrl,
        _timezoneCtrl,
        _languagesCtrl,
        _linkedinCtrl,
        _githubCtrl,
        _websiteCtrl,
        _headlineCtrl,
        _yearsCtrl,
        _expertiseCtrl,
        _interestsCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.profile?.currentMode ?? ProfileMode.student;
    _selectedLevel = widget.profile?.studentProfile.currentLevel ??
        StudentLevel.beginner;
    if (widget.profile != null) _populate(widget.profile!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in _controllers) {
        if (c != _usernameCtrl) c.addListener(_onChanged);
      }
      _usernameCtrl.addListener(_onUsernameChanged);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(ProfileModel p) {
    _fullNameCtrl.text = p.profile.fullName;
    _usernameCtrl.text = p.username;
    _bioCtrl.text = p.profile.bio;
    _phoneCtrl.text = p.phone;
    _countryCtrl.text = p.profile.location.country;
    _cityCtrl.text = p.profile.location.city;
    _timezoneCtrl.text = p.profile.location.timezone;
    _languagesCtrl.text = p.profile.languages.join(', ');
    _linkedinCtrl.text = p.profile.socialLinks.linkedin?.toString() ?? '';
    _githubCtrl.text = p.profile.socialLinks.github?.toString() ?? '';
    _websiteCtrl.text = p.profile.socialLinks.website?.toString() ?? '';
    _headlineCtrl.text = p.instructorProfile.headline;
    _yearsCtrl.text = p.instructorProfile.yearsOfExperience == 0
        ? ''
        : p.instructorProfile.yearsOfExperience.toString();
    _expertiseCtrl.text = p.instructorProfile.expertise.join(', ');
    _interestsCtrl.text = p.studentProfile.interests.join(', ');
    _selectedLevel = p.studentProfile.currentLevel;
    _gender = p.profile.gender;
  }

  void _onChanged() {
    if (mounted && !_dirty) setState(() => _dirty = true);
  }

  void _onUsernameChanged() {
    _onChanged();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability();
    });
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameCtrl.text.trim();

    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = true;
        _usernameError = null;
        _checkingUsername = false;
      });
      return;
    }

    if (widget.profile?.username == username) {
      setState(() {
        _usernameAvailable = true;
        _usernameError = null;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (!mounted) return;

      final exists = querySnapshot.docs.isNotEmpty;
      setState(() {
        _usernameAvailable = !exists;
        _usernameError = exists ? 'Username already taken' : null;
        _checkingUsername = false;
      });
    } catch (e) {
      debugPrint('[ProfileSettingsScreen] Username check error: $e');
      if (!mounted) return;
      setState(() {
        _usernameAvailable = true;
        _usernameError = null;
        _checkingUsername = false;
      });
    }
  }

  List<String> _splitComma(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Uri? _parseUri(String raw) {
    final trimmed = raw.trim();
    return trimmed.isNotEmpty ? Uri.tryParse(trimmed) : null;
  }

  final _repo = ProfileRepository();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_usernameAvailable) {
      _showSnack('Please choose a different username', error: true);
      return;
    }

    if (_checkingUsername) {
      _showSnack('Checking username availability...', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final isUpdate = widget.profile?.id != null;
      final newMode = _selectedMode;
      final updatedModes = isUpdate
          ? {...widget.profile!.availableModes, newMode}.toList()
          : [newMode];

      if (isUpdate) {
        final updated = ProfileModel(
          id: widget.profile!.id,
          userId: widget.profile!.userId,
          username: _usernameCtrl.text.trim(),
          email: widget.profile!.email,
          phone: _phoneCtrl.text.trim(),
          passwordHash: widget.profile!.passwordHash,
          currentMode: newMode,
          availableModes: updatedModes,
          isVerified: widget.profile!.isVerified,
          status: widget.profile!.status,
          createdAt: widget.profile!.createdAt,
          updatedAt: DateTime.now(),
          lastLogin: widget.profile!.lastLogin,
          profile: ProfileInfo(
            fullName: _fullNameCtrl.text.trim(),
            profilePhoto: widget.profile!.profile.profilePhoto,
            coverPhoto: widget.profile!.profile.coverPhoto,
            bio: _bioCtrl.text.trim(),
            dateOfBirth: null,
            gender: _gender,
            languages: _splitComma(_languagesCtrl.text),
            location: Location(
              country: _countryCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              timezone: _timezoneCtrl.text.trim(),
            ),
            socialLinks: SocialLinks(
              linkedin: _parseUri(_linkedinCtrl.text),
              github: _parseUri(_githubCtrl.text),
              website: _parseUri(_websiteCtrl.text),
            ),
          ),
          studentProfile: StudentProfile(
            isActive: newMode == ProfileMode.student,
            interests: _splitComma(_interestsCtrl.text),
            currentLevel: _selectedLevel,
          ),
          instructorProfile: InstructorProfile(
            isActive: newMode == ProfileMode.instructor,
            headline: _headlineCtrl.text.trim(),
            expertise: _splitComma(_expertiseCtrl.text),
            yearsOfExperience: int.tryParse(_yearsCtrl.text.trim()) ?? 0,
          ),
          system: widget.profile!.system,
        );

        await _repo.update(widget.profile!.id!, updated);
      } else {
        final userId = AuthRepository().currentUser?.id ?? '';
        final now = DateTime.now();

        final newProfile = ProfileModel(
          id: null,
          userId: userId,
          username: _usernameCtrl.text.trim(),
          email: '',
          phone: _phoneCtrl.text.trim(),
          passwordHash: '',
          currentMode: newMode,
          availableModes: updatedModes,
          isVerified: false,
          status: ProfileStatus.active,
          createdAt: now,
          updatedAt: now,
          lastLogin: now,
          profile: ProfileInfo(
            fullName: _fullNameCtrl.text.trim(),
            profilePhoto: null,
            coverPhoto: null,
            bio: _bioCtrl.text.trim(),
            dateOfBirth: null,
            gender: _gender,
            languages: _splitComma(_languagesCtrl.text),
            location: Location(
              country: _countryCtrl.text.trim(),
              city: _cityCtrl.text.trim(),
              timezone: _timezoneCtrl.text.trim(),
            ),
            socialLinks: SocialLinks(
              linkedin: _parseUri(_linkedinCtrl.text),
              github: _parseUri(_githubCtrl.text),
              website: _parseUri(_websiteCtrl.text),
            ),
          ),
          studentProfile: StudentProfile(
            isActive: newMode == ProfileMode.student,
            interests: _splitComma(_interestsCtrl.text),
            currentLevel: _selectedLevel,
          ),
          instructorProfile: InstructorProfile(
            isActive: newMode == ProfileMode.instructor,
            headline: _headlineCtrl.text.trim(),
            expertise: _splitComma(_expertiseCtrl.text),
            yearsOfExperience: int.tryParse(_yearsCtrl.text.trim()) ?? 0,
          ),
          system: const SystemInfo(isBanned: false, isFeaturedInstructor: false),
        );

        await _service.add(newProfile);
      }

      if (!mounted) return;
      setState(() => _dirty = false);
      _showSnack(isUpdate ? 'Profile updated!' : 'Profile created!');
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[ProfileSettingsScreen] $e\n$st');
      _showSnack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. They will be lost if you leave.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error ? cs.error : cs.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handlePop() async {
    final ok = await _confirmDiscard();
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && mounted) Navigator.pop(context);
      },
      child: NetworkWidget(
        child: MfaWidget(
          authRepository: AuthRepository(),
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _handlePop,
              ),
              title: const Text('Edit Profile'),
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : AnimatedOpacity(
                          opacity: _dirty ? 1.0 : 0.4,
                          duration: const Duration(milliseconds: 200),
                          child: FilledButton(
                            onPressed: _dirty ? _save : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                              shape: const StadiumBorder(),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 60),
                children: [
                  const SizedBox(height: 8),
                  _buildModeSection(cs, tt),
                  _SectionHeader(label: 'Personal Info'),
                  _Field(
                    label: 'Full Name',
                    controller: _fullNameCtrl,
                    hint: 'Your display name',
                    required: true,
                  ),
                  _Field(
                    label: 'Username',
                    controller: _usernameCtrl,
                    hint: 'john_doe',
                    required: true,
                    prefixText: '@',
                    suffixIcon: _checkingUsername
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (_usernameCtrl.text.trim().isNotEmpty &&
                                  _usernameAvailable &&
                                  _usernameCtrl.text.trim() !=
                                      widget.profile?.username)
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                )
                              : null,
                    errorText: _usernameError,
                  ),
                  _Field(
                    label: 'Bio',
                    controller: _bioCtrl,
                    hint: 'A short bio about yourself…',
                    maxLines: 3,
                  ),
                  _Field(
                    label: 'Phone',
                    controller: _phoneCtrl,
                    hint: '+1 234 567 890',
                    keyboard: TextInputType.phone,
                  ),
                  _GenderSelector(
                    value: _gender,
                    options: _genderOptions,
                    onChanged: (v) => setState(() {
                      _gender = v;
                      _dirty = true;
                    }),
                  ),
                  _SectionHeader(label: 'Location'),
                  _Field(
                    label: 'Country',
                    controller: _countryCtrl,
                    hint: 'United States',
                  ),
                  _Field(
                    label: 'City',
                    controller: _cityCtrl,
                    hint: 'New York',
                  ),
                  _Field(
                    label: 'Timezone',
                    controller: _timezoneCtrl,
                    hint: 'America/New_York',
                  ),
                  _Field(
                    label: 'Languages',
                    controller: _languagesCtrl,
                    hint: 'English, Spanish…',
                    helperText: 'Comma-separated',
                  ),
                  _SectionHeader(label: 'Social Links'),
                  _Field(
                    label: 'LinkedIn',
                    controller: _linkedinCtrl,
                    hint: 'linkedin.com/in/…',
                    keyboard: TextInputType.url,
                    prefixIcon: Icons.work_outline_rounded,
                  ),
                  _Field(
                    label: 'GitHub',
                    controller: _githubCtrl,
                    hint: 'github.com/…',
                    keyboard: TextInputType.url,
                    prefixIcon: Icons.code_rounded,
                  ),
                  _Field(
                    label: 'Website',
                    controller: _websiteCtrl,
                    hint: 'https://…',
                    keyboard: TextInputType.url,
                    prefixIcon: Icons.language_rounded,
                  ),
                  if (_selectedMode == ProfileMode.instructor) ...[
                    _SectionHeader(label: 'Instructor Details'),
                    _Field(
                      label: 'Headline',
                      controller: _headlineCtrl,
                      hint: 'Senior Flutter Engineer',
                      required: true,
                    ),
                    _Field(
                      label: 'Years of Experience',
                      controller: _yearsCtrl,
                      hint: '5',
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                    _Field(
                      label: 'Expertise',
                      controller: _expertiseCtrl,
                      hint: 'Flutter, Dart, Firebase…',
                      helperText: 'Comma-separated',
                      maxLines: 2,
                    ),
                  ] else ...[
                    _SectionHeader(label: 'Student Details'),
                    _LevelSelector(
                      value: _selectedLevel,
                      options: StudentLevel.values,
                      onChanged: (v) => setState(() {
                        _selectedLevel = v;
                        _dirty = true;
                      }),
                    ),
                    _Field(
                      label: 'Interests',
                      controller: _interestsCtrl,
                      hint: 'Flutter, Design, AI…',
                      helperText: 'Comma-separated',
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSection(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCOUNT TYPE',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ProfileMode>(
            segments: ProfileMode.values.map((mode) {
              final icon = mode == ProfileMode.instructor
                  ? Icons.school_outlined
                  : Icons.person_outline_rounded;
              return ButtonSegment<ProfileMode>(
                value: mode,
                label: Text(mode.label),
                icon: Icon(icon, size: 16),
              );
            }).toList(),
            selected: {_selectedMode},
            onSelectionChanged: (s) {
              final picked = s.first;
              if (_selectedMode != picked)
                setState(() {
                  _selectedMode = picked;
                  _dirty = true;
                });
            },
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child:
                _selectedMode != (widget.profile?.currentMode ?? ProfileMode.student)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Switching to ${_selectedMode.name} mode will update your active role on save.',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Divider(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withOpacity(0.5),
            height: 1,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    this.required = false,
    this.prefixText,
    this.helperText,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType keyboard;
  final bool required;
  final String? prefixText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        style: tt.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
          helperText: helperText,
          errorText: errorText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 16, color: cs.onSurfaceVariant)
              : null,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          hintStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant.withOpacity(0.4),
          ),
          labelStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          floatingLabelStyle: tt.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.error),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.error, width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 12, bottom: 10),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Gender value;
  final List<Gender> options;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gender',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option;
              return ChoiceChip(
                label: Text(option.label),
                selected: selected,
                onSelected: (_) => onChanged(option),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: cs.outlineVariant),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant, height: 1),
        ],
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final StudentLevel value;
  final List<StudentLevel> options;
  final ValueChanged<StudentLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    const icons = {
      StudentLevel.beginner: Icons.star_outline_rounded,
      StudentLevel.intermediate: Icons.star_half_rounded,
      StudentLevel.advanced: Icons.star_rounded,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option;
              return ChoiceChip(
                avatar: Icon(
                  icons[option] ?? Icons.star_outline_rounded,
                  size: 14,
                  color: selected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                label: Text(option.label),
                selected: selected,
                onSelected: (_) => onChanged(option),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: cs.outlineVariant),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant, height: 1),
        ],
      ),
    );
  }
}