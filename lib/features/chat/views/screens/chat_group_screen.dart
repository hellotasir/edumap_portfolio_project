import 'dart:io';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
  });

  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen>
    with TickerProviderStateMixin {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _selectedIds = {};
  final Map<String, String> _selectedUsernames = {};

  File? _groupImageFile;
  bool _isUploadingImage = false;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _loadError;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadFriends();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final friends = await widget.chatRepository.getFriendsList(
        widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _friends = friends;
          _searchResults = friends;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Could not load friends. Tap to retry.';
        });
      }
    }
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = _friends);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchResults = _friends.where((f) {
        final username = (f['username'] as String? ?? '').toLowerCase();
        final fullName = (f['full_name'] as String? ?? '').toLowerCase();
        return username.contains(q) || fullName.contains(q);
      }).toList();
    });
  }

  void _toggleUser(Map<String, dynamic> user) {
    final id = _resolveId(user);
    final username = user['username'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedUsernames.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedUsernames[id] = username;
      }
    });
  }

  String _resolveId(Map<String, dynamic> user) {
    final uid = user['user_id'] as String?;
    if (uid != null && uid.isNotEmpty) return uid;
    return user['id'] as String? ?? '';
  }

  Future<void> _pickGroupImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _groupImageFile = File(picked.path));
    }
  }

  Future<String?> _uploadGroupImage() async {
    if (_groupImageFile == null) return null;
    setState(() => _isUploadingImage = true);
    try {
      return await widget.chatRepository.uploadGroupPhoto(
        adminUserId: widget.currentUserId,
        imageFile: _groupImageFile!,
        
      );
    } catch (_) {
      _showSnack('Failed to upload group image');
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) { _showSnack('Please enter a group name'); return; }
    if (_selectedIds.isEmpty) { _showSnack('Select at least one member'); return; }
    setState(() => _isCreating = true);
    try {
      final groupPhotoUrl = await _uploadGroupImage();
      final conversation =
          await widget.chatRepository.createGroupConversation(
        adminUserId: widget.currentUserId,
        adminUsername: widget.currentUsername,
        groupName: name,
        memberIds: _selectedIds.toList(),
        memberUsernames: _selectedUsernames,
        groupPhoto: groupPhotoUrl,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversation: conversation,
            currentUserId: widget.currentUserId,
            currentUsername: widget.currentUsername,
            currentProfilePhoto: widget.currentProfilePhoto,
            chatRepository: widget.chatRepository,
          ),
        ),
      );
    } catch (_) {
      _showSnack('Failed to create group. Please try again.');
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isBusy = _isCreating || _isUploadingImage;

    return NetworkWidget(
        child: Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'New Group',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            actions: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _selectedIds.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: FilledButton(
                          onPressed: isBusy ? null : _createGroup,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: isBusy
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : Text(
                                  'Create',
                                  style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onPrimary,
                                  ),
                                ),
                        ),
                      ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    _GroupAvatarPicker(
                      imageFile: _groupImageFile,
                      colorScheme: cs,
                      onTap: _pickGroupImage,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Group name',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.45),
                              letterSpacing: 0.3,
                            ),
                          ),
                          TextField(
                            controller: _groupNameController,
                            autocorrect: true,
                            textCapitalization: TextCapitalization.words,
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Study Squad',
                              hintStyle: tt.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.25),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.only(
                                top: 4,
                                bottom: 6,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: cs.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: cs.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: tt.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search friends…',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 36,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _selectedIds.isEmpty
                    ? const SizedBox.shrink()
                    : _SelectedChips(
                        selectedIds: _selectedIds,
                        selectedUsernames: _selectedUsernames,
                        onRemove: (id) => setState(() {
                          _selectedIds.remove(id);
                          _selectedUsernames.remove(id);
                        }),
                      ),
              ),
              if (!_isLoading && _friends.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                  child: Row(
                    children: [
                      Text(
                        'FRIENDS',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_searchResults.length}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildBody(cs, tt)),
            ],
          ),
        ),
      );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_loadError != null) {
      return Center(
        child: GestureDetector(
          onTap: _loadFriends,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_friends.isEmpty) {
      return _EmptyFriends(colorScheme: cs, textTheme: tt);
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 10),
            Text(
              'No results for "${_searchController.text}"',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        itemCount: _searchResults.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, i) {
          final user = _searchResults[i];
          final id = _resolveId(user);
          final username = user['username'] as String? ?? '';
          final fullName = user['full_name'] as String? ?? '';
          final photoUrl = user['profile_photo'] as String? ?? '';
          final isSelected = _selectedIds.contains(id);
          final displayName = fullName.isNotEmpty ? fullName : username;
          return _FriendTile(
            key: ValueKey(id),
            displayName: displayName,
            username: username,
            fullName: fullName,
            photoUrl: photoUrl,
            isSelected: isSelected,
            colorScheme: cs,
            textTheme: tt,
            onTap: () => _toggleUser(user),
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    super.key,
    required this.displayName,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.isSelected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  final String displayName;
  final String username;
  final String fullName;
  final String photoUrl;
  final bool isSelected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final tt = textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: tt.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        )
                      : null,
                ),
                if (isSelected)
                  Positioned.fill(
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fullName.isNotEmpty && username.isNotEmpty)
                    Text(
                      '@$username',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: isSelected
                  ? Container(
                      key: const ValueKey('checked'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: cs.onPrimary,
                      ),
                    )
                  : Container(
                      key: const ValueKey('unchecked'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupAvatarPicker extends StatelessWidget {
  const _GroupAvatarPicker({
    required this.imageFile,
    required this.colorScheme,
    required this.onTap,
  });

  final File? imageFile;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: imageFile != null ? FileImage(imageFile!) : null,
            child: imageFile == null
                ? Icon(
                    Icons.group_rounded,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  )
                : null,
          ),
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                size: 10,
                color: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({
    required this.selectedIds,
    required this.selectedUsernames,
    required this.onRemove,
  });

  final Set<String> selectedIds;
  final Map<String, String> selectedUsernames;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: selectedIds.map((id) {
          final username = selectedUsernames[id] ?? '';
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: cs.primary,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              label: Text(
                username,
                style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w500),
              ),
              onDeleted: () => onRemove(id),
              deleteIconColor: cs.onSurface.withValues(alpha: 0.4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  const _EmptyFriends({required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final tt = textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 28,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add friends first to create a group',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}