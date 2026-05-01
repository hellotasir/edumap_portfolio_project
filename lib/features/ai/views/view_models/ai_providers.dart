import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:edumap_portfolio_project/core/services/cloud/ai_chat_service.dart';
import 'package:edumap_portfolio_project/features/ai/prompts/ai_prompts.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
String get _supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

@immutable
class AiConfig {
  const AiConfig({
    required this.userId,
    required this.username,
    this.profilePhoto,
    this.role = 'student',
    this.assistantMode = AiPrompts.modeGeneral,
    this.customTone,
  });

  final String userId;
  final String username;

  final String? profilePhoto;

  final String role;

  final String assistantMode;
  final String? customTone;

  @override
  bool operator ==(Object other) =>
      other is AiConfig &&
      other.userId == userId &&
      other.username == username &&
      other.profilePhoto == profilePhoto &&
      other.role == role &&
      other.assistantMode == assistantMode &&
      other.customTone == customTone;

  @override
  int get hashCode => Object.hash(
    userId,
    username,
    profilePhoto,
    role,
    assistantMode,
    customTone,
  );
}

final aiConfigProvider = StateProvider<AiConfig?>((ref) => null);

final aiChatServiceProvider = Provider<AiChatService?>((ref) {
  final config = ref.watch(aiConfigProvider);
  if (config == null) return null;

  return AiChatService(
    supabaseUrl: _supabaseUrl,
    supabaseAnonKey: _supabaseAnonKey,
    chatRepository: ref.watch(chatRepositoryProvider),
    userId: config.userId,
    username: config.username,
    profilePhoto: config.profilePhoto,
    role: config.role,
    assistantMode: config.assistantMode,
    customTone: config.customTone,
  );
});

@immutable
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  bool get isEmpty => messages.isEmpty;

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => AiChatState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    ref.watch(aiChatServiceProvider);
    return const AiChatState();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final service = ref.read(aiChatServiceProvider);
    if (service == null) return;

    state = state.copyWith(
      messages: List.unmodifiable([
        ...state.messages,
        AiChatMessage(role: MessageRole.user, text: trimmed),
      ]),
      isLoading: true,
      clearError: true,
    );

    final reply = await service.sendMessage(trimmed);

    state = state.copyWith(
      messages: List.unmodifiable([...state.messages, reply]),
      isLoading: false,
      errorMessage: reply.isError ? reply.text : null,
    );
  }

  void clearChat() {
    ref.read(aiChatServiceProvider)?.clearHistory();
    state = const AiChatState();
  }
}

final aiChatNotifierProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
