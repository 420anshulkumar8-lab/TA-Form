// lib/models/ta_session.dart
// ─────────────────────────────────────────────────────────────────────────────
// Represents one month's complete TA session stored in Hive "ta_sessions" box.
// Key format: "session_[month]_[year]_[employeeId]"
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

enum SessionStatus { fresh, draft, submitted }

class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  final String timestamp; // ISO-8601

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp,
      };
}

class TaSession {
  final String month; // "june"
  final String year; // "2026"
  final String employeeId;
  SessionStatus status;
  bool selectTa;
  bool selectContingent;
  String aiLanguage;
  List<ChatMessage> chatHistoryTa;
  List<ChatMessage> chatHistoryContingent;
  Map<String, dynamic>? formDataTa; // parsed from AI JSON
  Map<String, dynamic>? formDataContingent; // parsed from AI JSON
  String lastUpdated; // ISO-8601
  String? pdfPath;

  TaSession({
    required this.month,
    required this.year,
    required this.employeeId,
    this.status = SessionStatus.fresh,
    this.selectTa = true,
    this.selectContingent = true,
    this.aiLanguage = 'Hinglish',
    List<ChatMessage>? chatHistoryTa,
    List<ChatMessage>? chatHistoryContingent,
    this.formDataTa,
    this.formDataContingent,
    String? lastUpdated,
    this.pdfPath,
  })  : chatHistoryTa = chatHistoryTa ?? [],
        chatHistoryContingent = chatHistoryContingent ?? [],
        lastUpdated = lastUpdated ?? DateTime.now().toIso8601String();

  // ── Hive session key ──────────────────────────────────────────────────────
  static String buildKey(String month, String year, String employeeId) =>
      'session_${month.toLowerCase()}_${year}_$employeeId';

  String get key => buildKey(month, year, employeeId);

  // ── Display label ─────────────────────────────────────────────────────────
  String get displayLabel =>
      '${_capitalize(month)} $year';

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Total amount (TA + contingent) ────────────────────────────────────────
  double get totalAmount {
    double total = 0;
    if (formDataTa != null) {
      total += (formDataTa!['grand_total'] ?? 0).toDouble();
    }
    if (formDataContingent != null) {
      total += (formDataContingent!['total_amount'] ?? 0).toDouble();
    }
    return total;
  }

  bool get isTaFinalized =>
      formDataTa != null &&
      (formDataTa!['status'] == 'submitted' ||
          formDataTa!['status'] == 'pending');

  // ── Serialization ─────────────────────────────────────────────────────────
  String toJsonString() => jsonEncode({
        'month': month,
        'year': year,
        'employee_id': employeeId,
        'status': status.name,
        'selection': {'ta': selectTa, 'contingent': selectContingent},
        'ai_language': aiLanguage,
        'chat_history_ta': chatHistoryTa.map((m) => m.toJson()).toList(),
        'chat_history_contingent':
            chatHistoryContingent.map((m) => m.toJson()).toList(),
        'form_data_ta': formDataTa,
        'form_data_contingent': formDataContingent,
        'last_updated': lastUpdated,
        'pdf_path': pdfPath,
      });

  factory TaSession.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final statusStr = json['status'] as String? ?? 'fresh';
    final selection = json['selection'] as Map<String, dynamic>? ?? {};

    return TaSession(
      month: json['month'] ?? '',
      year: json['year'] ?? '',
      employeeId: json['employee_id'] ?? '',
      status: SessionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SessionStatus.fresh,
      ),
      selectTa: selection['ta'] as bool? ?? true,
      selectContingent: selection['contingent'] as bool? ?? true,
      aiLanguage: json['ai_language'] ?? 'Hinglish',
      chatHistoryTa: (json['chat_history_ta'] as List<dynamic>? ?? [])
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      chatHistoryContingent:
          (json['chat_history_contingent'] as List<dynamic>? ?? [])
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList(),
      formDataTa: json['form_data_ta'] as Map<String, dynamic>?,
      formDataContingent:
          json['form_data_contingent'] as Map<String, dynamic>?,
      lastUpdated: json['last_updated'] ?? DateTime.now().toIso8601String(),
      pdfPath: json['pdf_path'] as String?,
    );
  }
}
