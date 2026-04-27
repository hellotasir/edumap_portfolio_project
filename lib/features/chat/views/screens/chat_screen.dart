// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/views/screens/call_screen.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/conversation_model.dart';
import 'package:flutter_education_app/features/chat/models/user_preference_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart'
    hide MessageLimitException;
import 'package:flutter_education_app/features/chat/views/screens/chat_settings_screen.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/audio_message_bubble.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/image_message_bubble.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/video_message_bubble.dart';
import 'package:flutter_education_app/features/profile/views/screens/profile_screen.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
  });

  final ConversationModel conversation;
  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  String? _otherUserPhoto;
  bool? _otherUserExists;
  bool _isFriend = false;
  bool _isFriendLoaded = false;
  final bool _friendRequestSent = false;
  int _myMessageCount = 0;
  String? _typingUser;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isAttachMenuOpen = false;
  bool _hasText = false;
  bool _isBanned = false;
  bool _isDeletingConversation = false;

  final Set<String> _downloadingFiles = {};

  late ConversationModel _conversation;

  late final String _otherUserId;
  late final bool _isGroup;

  String get _otherUsername =>
      _conversation.participantUsernames[_otherUserId] ?? 'User';

  String get _displayTitle =>
      _isGroup
      ? (_conversation.groupName ?? 'Group')
      : _otherUsername;

  bool get _limitReached =>
      !_isFriend && _isFriendLoaded && !_isGroup && _myMessageCount >= 3;

  int get _remaining => (3 - _myMessageCount).clamp(0, 3);

  bool get _inputDisabled =>
      _isBanned || _limitReached || _otherUserExists == false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _isGroup = _conversation.type == ConversationType.group;
    _otherUserId = _isGroup
        ? ''
        : _conversation.participantIds.firstWhere(
            (id) => id != widget.currentUserId,
            orElse: () => '',
          );
    _loadFriendStatus();
    _markRead();
    _listenTyping();
    _checkBanStatus();
    if (!_isGroup) _loadOtherUserProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    widget.chatRepository.disposeTypingChannel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _checkBanStatus() async {
    final banned = await widget.chatRepository.isUserBanned(
      widget.currentUserId,
    );
    if (mounted) setState(() => _isBanned = banned);
  }

  Future<void> _loadFriendStatus() async {
    if (_isGroup) {
      if (mounted) {
        setState(() {
          _isFriend = true;
          _isFriendLoaded = true;
        });
      }
      return;
    }
    final result = await widget.chatRepository.areFriends(
      widget.currentUserId,
      _otherUserId,
    );
    if (mounted) {
      setState(() {
        _isFriend = result;
        _isFriendLoaded = true;
      });
    }
  }

  Future<void> _markRead() async {
    await widget.chatRepository.markAsRead(
      _conversation.id!,
      widget.currentUserId,
    );
  }

  Future<void> _loadOtherUserProfile() async {
    try {
      final exists = await widget.chatRepository.checkUserExists(_otherUserId);
      final profile = exists
          ? await widget.chatRepository.getUserProfile(_otherUserId)
          : null;
      if (mounted) {
        setState(() {
          _otherUserExists = exists;
          _otherUserPhoto = profile?['profile_photo'] as String?;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _otherUserExists = true);
    }
  }

  void _listenTyping() {
    widget.chatRepository.watchTypingUser(_conversation.id!).listen((username) {
      if (username != widget.currentUsername) {
        if (mounted) setState(() => _typingUser = username);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUser = null);
        });
      }
    });
  }

  void _onTextChanged(String value) {
    final hasText = value.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);

    if (hasText) {
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(milliseconds: 300), () {
        widget.chatRepository.broadcastTyping(
          _conversation.id!,
          widget.currentUsername,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_isBanned) {
      _showBanDialog();
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (ToxicityFilter.isToxic(text)) {
      final banned = await widget.chatRepository.recordToxicityStrike(
        widget.currentUserId,
      );
      if (banned) {
        if (mounted) setState(() => _isBanned = true);
        _showBanDialog();
      } else {
        _showToxicityWarning();
      }
      return;
    }

    if (widget.chatRepository.isConversationBusy(_conversation.id!)) {
      _showSnack('Please wait for the previous message to send.');
      return;
    }

    setState(() => _isSending = true);
    _controller.clear();
    _hasText = false;

    try {
      await widget.chatRepository.sendMessage(
        conversationId: _conversation.id!,
        senderId: widget.currentUserId,
        senderUsername: widget.currentUsername,
        content: text,
        isFriend: _isFriend,
      );
      _scrollToBottom();
    } on ToxicityException catch (e) {
      if (e.banned && mounted) {
        setState(() => _isBanned = true);
        _showBanDialog();
      }
    } on MessageLimitException catch (e) {
      _showSnack(e.message);
    } on BusyException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Failed to send message');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showToxicityWarning() {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 22),
            const SizedBox(width: 8),
            const Text('Inappropriate Message'),
          ],
        ),
        content: const Text(
          'Your message contains inappropriate or toxic content. Please keep conversations respectful. '
          'Your account will be permanently banned after 3 violations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: cs.error, size: 22),
            const SizedBox(width: 8),
            const Text('Account Banned'),
          ],
        ),
        content: const Text(
          'Your account has been banned due to toxic behavior. '
          'You can no longer send messages. Please contact support if you believe this is a mistake.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  Future<void> _pickAndSendImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile == null) return;
    await _uploadAndSend(
      file: File(xfile.path),
      type: MessageType.image,
      folder: 'images',
      content: '📷 Photo',
    );
  }

  Future<void> _pickAndSendVideo() async {
    final xfile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    await _uploadAndSend(
      file: File(xfile.path),
      type: MessageType.video,
      folder: 'videos',
      content: '🎬 Video',
    );
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('Microphone permission required');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopAndSendRecording() async {
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (path == null) return;
    await _uploadAndSend(
      file: File(path),
      type: MessageType.audio,
      folder: 'audio',
      content: '🎵 Voice message',
    );
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancel();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;
    final pf = result.files.single;
    await _uploadAndSend(
      file: File(pf.path!),
      type: MessageType.file,
      folder: 'files',
      content: '📎 ${pf.name}',
      fileName: pf.name,
      fileSize: pf.size,
    );
  }

  Future<void> _uploadAndSend({
    required File file,
    required MessageType type,
    required String folder,
    required String content,
    String? fileName,
    int? fileSize,
  }) async {
    if (_isBanned) {
      _showBanDialog();
      return;
    }
    if (_limitReached) {
      _showSnack('Message limit reached');
      return;
    }
    if (_otherUserExists == false) {
      _showSnack('This user no longer exists');
      return;
    }
    if (widget.chatRepository.isConversationBusy(_conversation.id!)) {
      _showSnack('Please wait for the previous action to complete.');
      return;
    }
    setState(() => _isSending = true);
    try {
      final url = await widget.chatRepository.uploadChatMedia(
        file: file,
        senderId: widget.currentUserId,
        folder: folder,
      );
      await widget.chatRepository.sendMessage(
        conversationId: _conversation.id!,
        senderId: widget.currentUserId,
        senderUsername: widget.currentUsername,
        content: content,
        type: type,
        mediaUrl: url,
        mediaFileName: fileName,
        mediaFileSize: fileSize,
        isFriend: _isFriend,
      );
      _scrollToBottom();
    } on BusyException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _downloadFile(ChatMessageModel msg) async {
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty) {
      _showSnack('No download URL available');
      return;
    }

    final messageId = msg.id ?? url;
    if (_downloadingFiles.contains(messageId)) return;

    setState(() => _downloadingFiles.add(messageId));

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          _showSnack('Storage permission denied — enable it in Settings');
          return;
        }
      }

      final Directory saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) saveDir.createSync(recursive: true);
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final rawName =
          msg.mediaFileName ??
          Uri.parse(url).pathSegments.last.split('?').first;
      final safeName = rawName.isNotEmpty ? rawName : 'download';
      final savePath =
          '${saveDir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      await File(savePath).writeAsBytes(response.bodyBytes, flush: true);

      if (mounted) {
        _showSnack(
          Platform.isAndroid
              ? 'Saved to Downloads: $safeName'
              : 'Saved to Files: $safeName',
        );
      }
    } catch (e) {
      debugPrint('[Download] Error: $e');
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _showSnack('Download failed: $e');
      }
    } finally {
      if (mounted) setState(() => _downloadingFiles.remove(messageId));
    }
  }

  Future<void> _openUserProfile(String userId) async {
    if (userId == widget.currentUserId) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(viewUserId: userId)),
    );
  }

  Future<void> _confirmDelete(ChatMessageModel msg) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete message?'),
        content: const Text('This message will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.chatRepository.deleteMessage(_conversation.id!, msg.id!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return StreamBuilder<List<ConversationModel>>(
      stream: widget.chatRepository.watchConversations(widget.currentUserId),
      builder: (context, convSnap) {
        if (convSnap.hasData) {
          final updated = convSnap.data!
              .where((c) => c.id == _conversation.id)
              .firstOrNull;
          if (updated != null && updated != _conversation) {
            _conversation = updated;
          }
        }

        return GestureDetector(
          onTap: () {
            _focusNode.unfocus();
            if (_isAttachMenuOpen) setState(() => _isAttachMenuOpen = false);
          },
          child: Scaffold(
            backgroundColor: cs.surface,
            appBar: _buildAppBar(context, cs, tt),
            body: Column(
              children: [
                if (_isBanned) RepaintBoundary(child: _buildBanBanner(cs, tt)),
                if (!_isBanned && !_isGroup && _otherUserExists == false)
                  RepaintBoundary(child: _buildDeletedUserBanner(cs, tt)),
                if (!_isBanned &&
                    _otherUserExists != false &&
                    !_isFriend &&
                    _isFriendLoaded &&
                    !_isGroup)
                  RepaintBoundary(child: _buildNonFriendBanner(cs, tt)),
                Expanded(
                  child: StreamBuilder<List<ChatMessageModel>>(
                    stream: widget.chatRepository.watchMessages(
                      _conversation.id!,
                    ),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return Center(
                          child: CircularProgressIndicator.adaptive(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.primary,
                            ),
                          ),
                        );
                      }

                      final messages = snap.data ?? [];

                      _myMessageCount = messages
                          .where(
                            (m) =>
                                m.senderId == widget.currentUserId &&
                                !m.isDeleted,
                          )
                          .length;

                      if (messages.isEmpty) {
                        return _buildEmptyState(cs, tt);
                      }

                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: messages.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, i) {
                          final msg = messages[i];
                          final isMe = msg.senderId == widget.currentUserId;
                          final showSenderLabel =
                              !isMe &&
                              _isGroup &&
                              (i == 0 ||
                                  messages[i - 1].senderId != msg.senderId);
                          final isFirst =
                              i == 0 ||
                              messages[i - 1].senderId != msg.senderId;
                          final isLast =
                              i == messages.length - 1 ||
                              messages[i + 1].senderId != msg.senderId;

                          return _ChatBubble(
                            key: ValueKey(msg.id),
                            msg: msg,
                            isMe: isMe,
                            isFirst: isFirst,
                            isLast: isLast,
                            showSenderLabel: showSenderLabel,
                            isGroup: _isGroup,
                            cs: cs,
                            tt: tt,
                            downloadingFiles: _downloadingFiles,
                            onDelete: () => _confirmDelete(msg),
                            onDownload: () => _downloadFile(msg),
                            onTapSender: () => _openUserProfile(msg.senderId),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_typingUser != null)
                  RepaintBoundary(child: _buildTypingIndicator(cs, tt)),
                if (!_isBanned &&
                    _otherUserExists != false &&
                    !_isFriend &&
                    _isFriendLoaded &&
                    !_isGroup)
                  RepaintBoundary(child: _buildLimitBar(cs, tt)),
                if (_isAttachMenuOpen && !_inputDisabled)
                  RepaintBoundary(child: _buildAttachMenu(cs, tt)),
                RepaintBoundary(child: _buildInputBar(context, cs, tt)),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, ColorScheme cs, TextTheme tt) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleSpacing: 0,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: cs.onSurface,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: _isGroup ? null : () => _openUserProfile(_otherUserId),
        child: _isGroup
            ? _buildGroupTitle(cs, tt)
            : _buildIndividualTitle(cs, tt),
      ),
      actions: [
        if (!_isGroup && _otherUserExists != false) ...[
          IconButton(
            onPressed: () {
              AppNavigator(
                screen: CallScreen(
                  userID: _otherUserId,
                  userName: _otherUsername,
                  callID: _otherUserId,
                  isVideoCall: false,
                ),
              ).navigate(context);
            },
            icon: Icon(Icons.call_rounded, size: 20, color: cs.onSurface),
          ),
          IconButton(
            onPressed: () {
              AppNavigator(
                screen: CallScreen(
                  userID: _otherUserId,
                  userName: _otherUsername,
                  callID: _otherUserId,
                  isVideoCall: true,
                ),
              ).navigate(context);
            },
            icon: Icon(Icons.video_call_rounded, size: 20, color: cs.onSurface),
          ),
        ],
        _AppBarIconButton(
          icon: Icons.tune_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatSettingsScreen(
                conversation: _conversation,
                currentUserId: widget.currentUserId,
                currentUsername: widget.currentUsername,
                currentProfilePhoto: widget.currentProfilePhoto,
                chatRepository: widget.chatRepository,
              ),
            ),
          ),
          cs: cs,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIndividualTitle(ColorScheme cs, TextTheme tt) {
    if (_otherUserExists == false) {
      return Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cs.errorContainer,
            child: Icon(
              Icons.person_off_rounded,
              size: 18,
              color: cs.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _otherUsername,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              Text(
                'Account deleted',
                style: tt.labelSmall?.copyWith(
                  color: cs.error.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return StreamBuilder<UserPresenceModel>(
      stream: widget.chatRepository.watchPresence(_otherUserId),
      builder: (context, snap) {
        final presence = snap.data;
        final isOnline = presence?.isOnline ?? false;
        return Row(
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(_otherUserId),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage:
                        (_otherUserPhoto?.isNotEmpty ?? false)
                        ? NetworkImage(_otherUserPhoto!)
                        : null,
                    onBackgroundImageError:
                        (_otherUserPhoto?.isNotEmpty ?? false)
                        ? (_, _) => setState(() => _otherUserPhoto = null)
                        : null,
                    child: (_otherUserPhoto?.isEmpty ?? true)
                        ? Text(
                            _otherUsername.isNotEmpty
                                ? _otherUsername[0].toUpperCase()
                                : '?',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF4CAF50)
                            : cs.outline.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherUsername,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  isOnline
                      ? 'Online'
                      : presence != null
                      ? 'Last seen ${timeago.format(presence.lastSeen)}'
                      : 'Offline',
                  style: tt.labelSmall?.copyWith(
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : cs.onSurface.withOpacity(0.4),
                    fontWeight: isOnline ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupTitle(ColorScheme cs, TextTheme tt) {
    return StreamBuilder<Map<String, UserPresenceModel>>(
      stream: widget.chatRepository.watchPresenceForUsers(
        _conversation.participantIds,
      ),
      builder: (context, snap) {
        final presence = snap.data ?? {};
        final onlineCount = presence.values.where((p) => p.isOnline).length;
        final total = _conversation.participantIds.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayTitle,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '$onlineCount of $total online',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBanBanner(ColorScheme cs, TextTheme tt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.errorContainer,
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account has been banned for toxic behavior. Messaging is disabled.',
              style: tt.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedUserBanner(ColorScheme cs, TextTheme tt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.errorContainer.withOpacity(0.7),
      child: Row(
        children: [
          Icon(Icons.person_off_rounded, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_otherUsername}\'s account no longer exists on this platform.',
              style: tt.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isDeletingConversation
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onErrorContainer,
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    AppNavigator(
                      screen: ChatSettingsScreen(
                        conversation: _conversation,
                        currentUserId: widget.currentUserId,
                        currentUsername: widget.currentUsername,
                        currentProfilePhoto: widget.currentProfilePhoto,
                        chatRepository: widget.chatRepository,
                      ),
                    ).navigate(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Delete Chat',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAttachMenu(ColorScheme cs, TextTheme tt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.grey.shade100,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _AttachItem(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            color: Colors.purple,
            onTap: () {
              setState(() => _isAttachMenuOpen = false);
              _pickAndSendImage();
            },
          ),
          _AttachItem(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            color: Colors.blue,
            onTap: () {
              setState(() => _isAttachMenuOpen = false);
              _pickAndSendImage(source: ImageSource.camera);
            },
          ),
          _AttachItem(
            icon: Icons.videocam_rounded,
            label: 'Video',
            color: Colors.red,
            onTap: () {
              setState(() => _isAttachMenuOpen = false);
              _pickAndSendVideo();
            },
          ),
          _AttachItem(
            icon: Icons.insert_drive_file_rounded,
            label: 'File',
            color: Colors.orange,
            onTap: () {
              setState(() => _isAttachMenuOpen = false);
              _pickAndSendFile();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ColorScheme cs, TextTheme tt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark
        ? cs.surfaceContainerHighest
        : Colors.grey.shade200;

    String hintText;
    if (_isBanned) {
      hintText = 'Account banned — messaging disabled';
    } else if (_otherUserExists == false) {
      hintText = 'This user no longer exists';
    } else if (_limitReached) {
      hintText = 'Limit reached — waiting for acceptance';
    } else {
      hintText = 'Message';
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withOpacity(0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _CircleIconButton(
              icon: _isAttachMenuOpen ? Icons.close_rounded : Icons.add_rounded,
              onTap: _inputDisabled
                  ? (_isBanned ? _showBanDialog : () {})
                  : () =>
                        setState(() => _isAttachMenuOpen = !_isAttachMenuOpen),
              backgroundColor: fieldColor,
              iconColor: cs.onSurface.withOpacity(_inputDisabled ? 0.3 : 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: fieldColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: _isRecording
                    ? _buildRecordingIndicator(cs, tt)
                    : TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !_inputDisabled,
                        onChanged: _onTextChanged,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: tt.bodyMedium,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: tt.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(0.35),
                          ),
                          enabledBorder: InputBorder.none,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSendOrMicButton(cs, fieldColor),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recording…',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _cancelRecording,
            child: Icon(
              Icons.delete_outline_rounded,
              color: cs.error,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOrMicButton(ColorScheme cs, Color fieldColor) {
    if (_hasText || _isSending) {
      return GestureDetector(
        onTap: (_inputDisabled || _isSending) ? null : _sendMessage,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _inputDisabled ? cs.outline : cs.primary,
            shape: BoxShape.circle,
          ),
          child: _isSending
              ? Padding(
                  padding: const EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Icon(Icons.send_rounded, size: 20, color: cs.onPrimary),
        ),
      );
    }

    if (_isRecording) {
      return GestureDetector(
        onTap: _stopAndSendRecording,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stop_rounded, size: 22, color: Colors.white),
        ),
      );
    }

    return _CircleIconButton(
      icon: Icons.mic_rounded,
      onTap: _inputDisabled
          ? (_isBanned ? _showBanDialog : () {})
          : _startRecording,
      backgroundColor: fieldColor,
      iconColor: cs.onSurface.withOpacity(_inputDisabled ? 0.3 : 0.55),
      size: 46,
    );
  }

  Widget _buildNonFriendBanner(ColorScheme cs, TextTheme tt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLow : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 14,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _friendRequestSent
                  ? 'Friend request sent to $_otherUsername'
                  : '$_otherUsername is not your friend yet',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitBar(ColorScheme cs, TextTheme tt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: isDark ? cs.surfaceContainerLow : Colors.grey.shade100,
      child: Row(
        children: [
          Icon(
            Icons.lock_rounded,
            size: 13,
            color: cs.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _remaining > 0
                  ? '$_remaining message${_remaining != 1 ? 's' : ''} remaining before they accept your request'
                  : 'Message limit reached — waiting for acceptance',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDots(color: cs.onSurface.withOpacity(0.4)),
              const SizedBox(width: 8),
              Text(
                '$_typingUser is typing',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isGroup ? Icons.group_rounded : Icons.chat_bubble_rounded,
              size: 32,
              color: cs.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isGroup ? 'No messages yet' : 'Say hi to $_otherUsername! 👋',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.isFirst,
    required this.isLast,
    required this.showSenderLabel,
    required this.isGroup,
    required this.cs,
    required this.tt,
    required this.downloadingFiles,
    required this.onDelete,
    required this.onDownload,
    required this.onTapSender,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final bool isFirst;
  final bool isLast;
  final bool showSenderLabel;
  final bool isGroup;
  final ColorScheme cs;
  final TextTheme tt;
  final Set<String> downloadingFiles;
  final VoidCallback onDelete;
  final VoidCallback onDownload;
  final VoidCallback onTapSender;

  static const _r = Radius.circular(22);
  static const _rSmall = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final isDeleted = msg.isDeleted;
    final isMedia =
        msg.type == MessageType.image ||
        msg.type == MessageType.video ||
        msg.type == MessageType.audio;

    final bubbleColor = isDeleted
        ? cs.surfaceContainerLowest
        : isMe
        ? cs.primary
        : cs.surfaceContainerHigh;

    final textColor = isDeleted
        ? cs.onSurface.withOpacity(0.3)
        : isMe
        ? cs.onPrimary
        : cs.onSurface;

    final borderRadius = BorderRadius.only(
      topLeft: (!isMe && !isFirst) ? _rSmall : _r,
      topRight: (isMe && !isFirst) ? _rSmall : _r,
      bottomLeft: isMe ? _r : (isLast ? _r : _rSmall),
      bottomRight: isMe ? (isLast ? _r : _rSmall) : _r,
    );

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 4 : 1),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isGroup) ...[
            if (isLast)
              GestureDetector(
                onTap: onTapSender,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    msg.senderUsername.isNotEmpty
                        ? msg.senderUsername[0].toUpperCase()
                        : '?',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !isDeleted ? onDelete : null,
              child: Container(
                margin: EdgeInsets.only(
                  left: isMe ? 72 : 0,
                  right: isMe ? 0 : 72,
                ),
                padding: isMedia
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: isMedia
                    ? null
                    : BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                      ),
                child: ClipRRect(
                  borderRadius: isMedia ? borderRadius : BorderRadius.zero,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSenderLabel && !isMedia)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GestureDetector(
                            onTap: onTapSender,
                            child: Text(
                              msg.senderUsername,
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      _buildContent(
                        isDeleted,
                        isMedia,
                        isMe,
                        bubbleColor,
                        borderRadius,
                        textColor,
                      ),
                      if (!isMedia)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(msg.sentAt),
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: isMe
                                      ? cs.onPrimary.withOpacity(0.55)
                                      : cs.onSurface.withOpacity(0.35),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                _StatusIcon(status: msg.status, cs: cs),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    bool isDeleted,
    bool isMedia,
    bool isMe,
    Color bubbleColor,
    BorderRadius borderRadius,
    Color textColor,
  ) {
    if (isDeleted) {
      return Text(
        msg.content,
        style: tt.bodyMedium?.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (msg.type) {
      case MessageType.image:
        return ImageMessageBubble(message: msg, isMe: isMe);

      case MessageType.audio:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
          ),
          child: AudioMessageBubble(message: msg, isMe: isMe),
        );

      case MessageType.video:
        return VideoMessageBubble(message: msg, isMe: isMe);

      case MessageType.file:
        return _FileMessageContent(
          msg: msg,
          isMe: isMe,
          cs: cs,
          tt: tt,
          bubbleColor: bubbleColor,
          borderRadius: borderRadius,
          isDownloading: downloadingFiles.contains(
            msg.id ?? msg.mediaUrl ?? '',
          ),
          onDownload: onDownload,
        );

      default:
        return Text(
          msg.content,
          style: tt.bodyMedium?.copyWith(color: textColor),
        );
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _FileMessageContent extends StatelessWidget {
  const _FileMessageContent({
    required this.msg,
    required this.isMe,
    required this.cs,
    required this.tt,
    required this.bubbleColor,
    required this.borderRadius,
    required this.isDownloading,
    required this.onDownload,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;
  final Color bubbleColor;
  final BorderRadius borderRadius;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final name = msg.mediaFileName ?? 'File';
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'FILE';
    final size = msg.mediaFileSize != null
        ? _formatFileSize(msg.mediaFileSize!)
        : '';
    final hasUrl = msg.mediaUrl?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: hasUrl && !isDownloading ? onDownload : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.18)
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isMe ? Colors.white : cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (size.isNotEmpty)
                    Text(
                      size,
                      style: tt.labelSmall?.copyWith(
                        color: isMe
                            ? cs.onPrimary.withOpacity(0.6)
                            : cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (hasUrl)
              SizedBox(
                width: 28,
                height: 28,
                child: isDownloading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isMe ? cs.onPrimary : cs.primary,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        size: 22,
                        color: isMe
                            ? cs.onPrimary.withOpacity(0.8)
                            : cs.primary,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.cs});

  final MessageStatus status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = cs.onPrimary.withOpacity(0.55);
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
        );
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 12, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 12, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 12, color: cs.onPrimary);
      case MessageStatus.failed:
        return Icon(Icons.error_outline_rounded, size: 12, color: cs.error);
    }
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: cs.onSurface),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final bounce = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 5,
            height: 5 + (bounce * 3),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _AttachItem extends StatelessWidget {
  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
