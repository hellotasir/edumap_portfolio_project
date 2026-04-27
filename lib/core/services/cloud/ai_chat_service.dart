import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/features/ai/prompts/ai_prompts.dart';
import 'package:flutter_education_app/features/ai/tools/ai_tool_definitions.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:http/http.dart' as http;

enum MessageRole { user, assistant }

@immutable
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
    this.toolCallsSummary,
  });

  final MessageRole role;
  final String text;
  final bool isError;
  final List<String>? toolCallsSummary;
}

@immutable
class _HistoryEntry {
  const _HistoryEntry({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory _HistoryEntry.fromJson(Map<String, dynamic> json) => _HistoryEntry(
    role: json['role'] as String,
    content: json['content'] as String,
  );
}

class AiChatService {
  AiChatService({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required ChatRepository chatRepository,
    required String userId,
    required String username,
    String assistantMode = AiPrompts.modeGeneral,
    String? customTone,
  }) : _executor = AiToolExecutor(chatRepository),
       _endpoint =
           '${supabaseUrl.replaceAll(RegExp(r'/$'), '')}/functions/v1/ai-chat',
       _anonKey = supabaseAnonKey {
    _systemPrompt = AiPrompts.buildSystemPrompt(
      userId: userId,
      username: username,
      mode: assistantMode,
      customTone: customTone,
    );
  }

  final String _endpoint;
  final String _anonKey;
  final AiToolExecutor _executor;
  late final String _systemPrompt;

  final List<_HistoryEntry> _history = [];

  Future<AiChatMessage> sendMessage(String userText) async {
    _history.add(_HistoryEntry(role: 'user', content: userText));

    try {
      final (replyText, toolsSummary) = await _runLoop();
      _history.add(_HistoryEntry(role: 'model', content: replyText));
      return AiChatMessage(
        role: MessageRole.assistant,
        text: replyText,
        toolCallsSummary: toolsSummary.isEmpty ? null : toolsSummary,
      );
    } catch (e, st) {
      debugPrint('[AiChatService] error: $e\n$st');
      if (_history.isNotEmpty) _history.removeLast();
      return AiChatMessage(
        role: MessageRole.assistant,
        text: _friendlyError(e),
        isError: true,
      );
    }
  }

  void clearHistory() => _history.clear();

  Future<(String, List<String>)> _runLoop() async {
    final toolsSummary = <String>[];
    var pendingHistory = List<_HistoryEntry>.from(_history);

    for (var round = 0; round < 5; round++) {
      final response = await _callEdgeFunction(pendingHistory);

      if (response.containsKey('text')) {
        final text = (response['text'] as String? ?? '').trim();
        return (
          text.isEmpty ? 'I could not generate a response.' : text,
          toolsSummary,
        );
      }

      final rawRequests = response['toolRequests'] as List<dynamic>?;
      if (rawRequests == null || rawRequests.isEmpty) {
        return (
          'I could not generate a response. Please try again.',
          toolsSummary,
        );
      }

      final serverHistory = response['pendingHistory'] as List<dynamic>?;
      if (serverHistory != null) {
        pendingHistory = serverHistory
            .map(
              (e) =>
                  _HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }

      final toolResults = <Map<String, dynamic>>[];
      for (final req in rawRequests) {
        final name = req['name'] as String;
        final args = Map<String, dynamic>.from(req['args'] as Map? ?? {});
        toolsSummary.add(name);
        try {
          final result = await _executor.execute(name, args);
          toolResults.add({'name': name, 'result': result});
        } catch (e) {
          toolResults.add({
            'name': name,
            'result': {'error': e.toString()},
          });
        }
      }

      pendingHistory.add(
        _HistoryEntry(role: 'tool', content: jsonEncode(toolResults)),
      );
    }

    return (
      'I reached my processing limit. Please try a simpler request.',
      toolsSummary,
    );
  }

  Future<Map<String, dynamic>> _callEdgeFunction(
    List<_HistoryEntry> history,
  ) async {
    final body = jsonEncode({
      'systemPrompt': _systemPrompt,
      'history': history.map((e) => e.toJson()).toList(),
      'tools': AiTool.values
          .map(
            (t) => {
              'name': t.toolName,
              'description': t.description,
              'parameters': t.parametersSchema,
            },
          )
          .toList(),
    });

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_anonKey',
            'apikey': _anonKey,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw _HttpException(response.statusCode, response.body);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _friendlyError(Object e) {
    if (e is _HttpException) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return 'AI service configuration error. Please try again later.';
      }
      if (e.statusCode == 429) {
        return 'Too many requests right now. Please wait a few seconds and try again.';
      }
      if (e.statusCode >= 500) {
        return 'The AI service is temporarily unavailable. Please try again later.';
      }
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'The request timed out. Please check your connection and try again.';
    }
    if (msg.contains('socketexception') || msg.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    if (msg.contains('messagelimitexception')) {
      return 'You can only send 3 messages before the other person accepts your friend request.';
    }
    if (msg.contains('toxicityexception')) {
      return 'Your message was flagged as inappropriate and was not sent.';
    }
    if (msg.contains('duplicatefriendrequestexception')) {
      return 'A friend request between these users already exists.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _HttpException implements Exception {
  const _HttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'HttpException($statusCode): $body';
}
