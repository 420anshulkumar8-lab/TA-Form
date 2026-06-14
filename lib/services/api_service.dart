// lib/services/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Sends chat messages to Anthropic Claude API.
// Handles session context injection and JSON tag extraction.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ta_session.dart';
import '../models/employee_profile.dart';
import '../config/ta_rates.dart';
import '../prompts/ta_system_prompt.dart';
import '../prompts/contingent_system_prompt.dart';

class ApiResponse {
  final String cleanMessage; // Message shown to user (tags removed)
  final Map<String, dynamic>? taFormData; // Parsed from <ta_form_data>
  final Map<String, dynamic>? contingentFormData; // From <contingent_form_data>
  final String? error;

  const ApiResponse({
    required this.cleanMessage,
    this.taFormData,
    this.contingentFormData,
    this.error,
  });

  bool get hasError => error != null;
}

class ApiService {
  static const String _endpoint =
      'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

  final String apiKey;
  final String model;

  ApiService({required this.apiKey, required this.model});

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a message in the TA chat tab
  Future<ApiResponse> sendTaMessage({
    required TaSession session,
    required EmployeeProfile profile,
    required String newUserMessage,
  }) async {
    final systemPrompt = _buildTaSystemPrompt(session, profile);
    final messages = _buildMessages(session.chatHistoryTa, newUserMessage);
    return _callClaude(systemPrompt: systemPrompt, messages: messages);
  }

  /// Send a message in the Contingent chat tab
  Future<ApiResponse> sendContingentMessage({
    required TaSession session,
    required EmployeeProfile profile,
    required String newUserMessage,
  }) async {
    final systemPrompt =
        _buildContingentSystemPrompt(session, profile);
    final messages =
        _buildMessages(session.chatHistoryContingent, newUserMessage);
    return _callClaude(systemPrompt: systemPrompt, messages: messages);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _buildTaSystemPrompt(
      TaSession session, EmployeeProfile profile) {
    final rates = TaRatesConfig.ratesForGradeLevel(profile.gradeLevel);
    final contextJson = jsonEncode({
      'LANGUAGE': session.aiLanguage,
      'FORM_MONTH': session.month,
      'FORM_YEAR': session.year,
      'EMPLOYEE': {
        ...profile.toJson(),
        'ta_rate_per_km': rates.taPerKm,
        'da_rate_per_day': rates.daPerDay,
      },
    });
    return '${TaSystemPrompt.prompt}\n\n--- SYSTEM CONTEXT ---\n$contextJson';
  }

  String _buildContingentSystemPrompt(
      TaSession session, EmployeeProfile profile) {
    final rates = TaRatesConfig.ratesForGradeLevel(profile.gradeLevel);
    final contextJson = jsonEncode({
      'LANGUAGE': session.aiLanguage,
      'FORM_MONTH': session.month,
      'FORM_YEAR': session.year,
      'EMPLOYEE': {
        ...profile.toJson(),
        'ta_rate_per_km': rates.taPerKm,
        'da_rate_per_day': rates.daPerDay,
      },
      'TA_DATA': session.formDataTa,
    });
    return '${ContingentSystemPrompt.prompt}\n\n--- SYSTEM CONTEXT ---\n$contextJson';
  }

  List<Map<String, dynamic>> _buildMessages(
      List<ChatMessage> history, String newMessage) {
    final messages = history
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    messages.add({'role': 'user', 'content': newMessage});
    return messages;
  }

  Future<ApiResponse> _callClaude({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final body = jsonEncode({
        'model': model,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': messages,
      });

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _anthropicVersion,
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            (decoded['content'] as List<dynamic>).first as Map<String, dynamic>;
        final rawText = content['text'] as String;
        return _parseResponse(rawText);
      } else {
        final error =
            'Claude API error ${response.statusCode}: ${response.body}';
        return ApiResponse(
          cleanMessage:
              'AI se connection nahi ho pa raha. Dobara try karein.',
          error: error,
        );
      }
    } catch (e) {
      return ApiResponse(
        cleanMessage: 'AI se connection nahi ho pa raha. Dobara try karein.',
        error: e.toString(),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Extract hidden JSON tags, return clean message + parsed data
  // ─────────────────────────────────────────────────────────────────────────
  ApiResponse _parseResponse(String rawText) {
    Map<String, dynamic>? taFormData;
    Map<String, dynamic>? contingentFormData;

    String clean = rawText;

    // Extract <ta_form_data>...</ta_form_data>
    final taMatch = RegExp(
      r'<ta_form_data>([\s\S]*?)<\/ta_form_data>',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (taMatch != null) {
      try {
        taFormData =
            jsonDecode(taMatch.group(1)!.trim()) as Map<String, dynamic>;
      } catch (_) {}
      clean = clean
          .replaceAll(taMatch.group(0)!, '')
          .trim();
    }

    // Extract <contingent_form_data>...</contingent_form_data>
    final contingentMatch = RegExp(
      r'<contingent_form_data>([\s\S]*?)<\/contingent_form_data>',
      caseSensitive: false,
    ).firstMatch(clean);
    if (contingentMatch != null) {
      try {
        contingentFormData = jsonDecode(contingentMatch.group(1)!.trim())
            as Map<String, dynamic>;
      } catch (_) {}
      clean = clean
          .replaceAll(contingentMatch.group(0)!, '')
          .trim();
    }

    return ApiResponse(
      cleanMessage: clean.trim(),
      taFormData: taFormData,
      contingentFormData: contingentFormData,
    );
  }
}
