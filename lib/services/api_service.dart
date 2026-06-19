// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ta_session.dart';
import '../models/employee_profile.dart';
import '../config/ta_rates.dart';
import '../prompts/ta_system_prompt.dart';
import '../prompts/contingent_system_prompt.dart';

class ApiResponse {
  final String cleanMessage;
  final Map<String, dynamic>? taFormData;
  final Map<String, dynamic>? contingentFormData;
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
      'https://openrouter.ai/api/v1/chat/completions';

  final String apiKey;
  final String model;

  ApiService({required this.apiKey, required this.model});

  Future<ApiResponse> sendTaMessage({
    required TaSession session,
    required EmployeeProfile profile,
    required String newUserMessage,
  }) async {
    final systemPrompt = _buildTaSystemPrompt(session, profile);
    final messages = _buildMessages(session.chatHistoryTa, newUserMessage);
    return _callApi(systemPrompt: systemPrompt, messages: messages);
  }

  Future<ApiResponse> sendContingentMessage({
    required TaSession session,
    required EmployeeProfile profile,
    required String newUserMessage,
  }) async {
    final systemPrompt = _buildContingentSystemPrompt(session, profile);
    final messages = _buildMessages(session.chatHistoryContingent, newUserMessage);
    return _callApi(systemPrompt: systemPrompt, messages: messages);
  }

  String _buildTaSystemPrompt(TaSession session, EmployeeProfile profile) {
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

  String _buildContingentSystemPrompt(TaSession session, EmployeeProfile profile) {
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
    return [
      ...history.map((m) => {
        'role': m.role == 'assistant' ? 'assistant' : 'user',
        'content': m.content,
      }),
      {
        'role': 'user',
        'content': newMessage,
      },
    ];
  }

  Future<ApiResponse> _callApi({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final allMessages = [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://els-gzb.app',
              'X-Title': 'TA Form App',
            },
            body: jsonEncode({
              'model': model,
              'messages': allMessages,
              'max_tokens': 4096,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final rawText =
            decoded['choices'][0]['message']['content'] as String;
        return _parseResponse(rawText);
      } else {
        return ApiResponse(
          cleanMessage:
              'AI se connection nahi ho pa raha. Dobara try karein.',
          error: 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return ApiResponse(
        cleanMessage: 'AI se connection nahi ho pa raha. Dobara try karein.',
        error: e.toString(),
      );
    }
  }

  ApiResponse _parseResponse(String rawText) {
    Map<String, dynamic>? taFormData;
    Map<String, dynamic>? contingentFormData;
    String clean = rawText;

    final taMatch = RegExp(
      r'<ta_form_data>([\s\S]*?)<\/ta_form_data>',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (taMatch != null) {
      try {
        taFormData =
            jsonDecode(taMatch.group(1)!.trim()) as Map<String, dynamic>;
      } catch (_) {}
      clean = clean.replaceAll(taMatch.group(0)!, '').trim();
    }

    final contingentMatch = RegExp(
      r'<contingent_form_data>([\s\S]*?)<\/contingent_form_data>',
      caseSensitive: false,
    ).firstMatch(clean);
    if (contingentMatch != null) {
      try {
        contingentFormData =
            jsonDecode(contingentMatch.group(1)!.trim()) as Map<String, dynamic>;
      } catch (_) {}
      clean = clean.replaceAll(contingentMatch.group(0)!, '').trim();
    }

    return ApiResponse(
      cleanMessage: clean.trim(),
      taFormData: taFormData,
      contingentFormData: contingentFormData,
    );
  }
}
