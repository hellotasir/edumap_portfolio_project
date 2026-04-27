import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/widgets/loading_widget.dart';
import 'package:flutter_education_app/features/ai/prompts/ai_prompts.dart';
import 'package:flutter_education_app/features/ai/views/view_models/ai_providers.dart';
import 'package:flutter_education_app/features/ai/views/widgets/empty_state.dart';
import 'package:flutter_education_app/features/ai/views/widgets/error_banner.dart';
import 'package:flutter_education_app/features/ai/views/widgets/input_bar.dart';
import 'package:flutter_education_app/features/ai/views/widgets/message_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({
    super.key,
    required this.userId,
    required this.username,
    this.profilePhoto,
    this.assistantMode,
    this.customTone,
  });

  final String userId;
  final String username;
  final String? profilePhoto;
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
    if (old.userId != widget.userId || old.username != widget.username) {
      _applyConfig();
    }
  }

  void _applyConfig() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = GeminiConfig(
        userId: widget.userId,
        username: widget.username,
        assistantMode: widget.assistantMode ?? AiPrompts.modeGeneral,
        customTone: widget.customTone,
      );
      final current = ref.read(geminiConfigProvider);
      if (current != next) {
        ref.read(geminiConfigProvider.notifier).state = next;
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
        .read(geminiNotifierProvider.notifier)
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
    final state = ref.watch(geminiNotifierProvider);
    final configReady = ref.watch(geminiConfigProvider) != null;

    return Column(
      children: [
        Expanded(
          child: !configReady
              ? Center(child: const LoadingIndicator())
              : state.isEmpty
              ? EmptyState(
                  onSend: (text) =>
                      ref.read(geminiNotifierProvider.notifier).send(text),
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
                ref.read(geminiNotifierProvider.notifier).clearChat(),
          ),
        InputBar(
          controller: _controller,
          focusNode: _focusNode,
          isLoading: state.isLoading,
          onSend: _send,
          onClear: state.isEmpty
              ? null
              : () => ref.read(geminiNotifierProvider.notifier).clearChat(),
        ),
      ],
    );
  }
}
