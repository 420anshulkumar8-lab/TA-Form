// lib/services/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Sends chat messages to Google Gemini API.
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
  // Gemini endpoint — model name injected at runtime
  static const String _baseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

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
    return _callGemini(systemPrompt: systemPrompt, messages: messages);
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
    return _callGemini(systemPrompt: systemPrompt, messages: messages);
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

  /// Convert internal chat history to Gemini format
  /// Gemini uses "user" and "model" roles (not "assistant")
  List<Map<String, dynamic>> _buildMessages(
      List<ChatMessage> history, String newMessage) {
    final messages = history.map((m) {
      return {
        'role': m.role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m.content}
        ],
      };
    }).toList();

    messages.add({
      'role': 'user',
      'parts': [
        {'text': newMessage}
      ],
    });
    return messages;
  }

  Future<ApiResponse> _callGemini({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      // Gemini endpoint: /v1beta/models/{model}:generateContent?key={apiKey}
      final uri = Uri.parse(
          '$_baseEndpoint/$model:generateContent?key=$apiKey');

      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': messages,
        'generationConfig': {
          'maxOutputTokens': 4096,
          'temperature': 0.7,
        },
      });

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        // Gemini response path: candidates[0].content.parts[0].text
        final candidates =
            decoded['candidates'] as List<dynamic>;
        final content =
            candidates.first['content'] as Map<String, dynamic>;
        final parts = content['parts'] as List<dynamic>;
        final rawText = parts.first['text'] as String;
        return _parseResponse(rawText);
      } else {
        final error =
            'Gemini API error ${response.statusCode}: ${response.body}';
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
