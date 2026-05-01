import 'package:edumap_portfolio_project/core/widgets/loading_widget.dart';
import 'package:edumap_portfolio_project/features/ai/prompts/ai_prompts.dart';
import 'package:edumap_portfolio_project/features/ai/views/view_models/ai_providers.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/empty_state.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/error_banner.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/input_bar.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({
    super.key,
    required this.userId,
    required this.username,
    this.profilePhoto,

    this.role = 'student',
    this.assistantMode,
    this.customTone,
  });

  final String userId;
  final String username;
  final String? profilePhoto;

  final String role;

  final String? assistantMode;
  final String? customTone;

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  @override
  void initState() {
    super.initState();
    _applyConfig();
  }

  @override
  void didUpdateWidget(AiAssistantScreen old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId ||
        old.username != widget.username ||
        old.profilePhoto != widget.profilePhoto ||
        old.role != widget.role) {
      _applyConfig();
    }
  }

  void _applyConfig() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = AiConfig(
        userId: widget.userId,
        username: widget.username,
        profilePhoto: widget.profilePhoto,
        role: widget.role,
        assistantMode: widget.assistantMode ?? AiPrompts.modeGeneral,
        customTone: widget.customTone,
      );
      final current = ref.read(aiConfigProvider);
      if (current != next) {
        ref.read(aiConfigProvider.notifier).state = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) => const _AiBody();
}

class _AiBody extends ConsumerStatefulWidget {
  const _AiBody();

  @override
  ConsumerState<_AiBody> createState() => _AiBodyState();
}

class _AiBodyState extends ConsumerState<_AiBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();
    ref
        .read(aiChatNotifierProvider.notifier)
        .send(text)
        .then((_) => _scrollToBottom());
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatNotifierProvider);
    final configReady = ref.watch(aiConfigProvider) != null;

    return Column(
      children: [
        Expanded(
          child: !configReady
              ? const Center(child: LoadingIndicator())
              : state.isEmpty
                  ? EmptyState(
                      onSend: (text) =>
                          ref.read(aiChatNotifierProvider.notifier).send(text),
                    )
                  : MessageList(
                      messages: state.messages,
                      isLoading: state.isLoading,
                      scrollController: _scrollController,
                    ),
        ),
        if (state.errorMessage != null)
          ErrorBanner(
            message: state.errorMessage!,
            onDismiss: () =>
                ref.read(aiChatNotifierProvider.notifier).clearChat(),
          ),
        InputBar(
          controller: _controller,
          focusNode: _focusNode,
          isLoading: state.isLoading,
          onSend: _send,
          onClear: state.isEmpty
              ? null
              : () => ref.read(aiChatNotifierProvider.notifier).clearChat(),
        ),
      ],
    );
  }
}