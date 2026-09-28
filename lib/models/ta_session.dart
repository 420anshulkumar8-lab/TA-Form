// lib/models/ta_session.dart
// ─────────────────────────────────────────────────────────────────────────────
// Represents one month's complete TA session stored in Hive "ta_sessions" box.
// Key format: "session_[month]_[year]_[employeeId]"
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

enum SessionStatus { fresh, draft, submitted }

/// Snapshot of the employee profile fields printed on the PDF, frozen at the
/// moment a TA is finalized so later profile edits never alter a finalized
/// TA. Draft sessions never carry a snapshot (they always use the live
/// profile).

class TaSession {
  /// Stable, never-changing owner id used in session keys. The app has a
  /// single profile, so sessions must NOT be tied to the editable Employee
  /// Number — otherwise editing that number orphans every saved session.
  static const String ownerId = 'owner';

  final String month; // "june"
  final String year; // "2026"
  final String employeeId;
  SessionStatus status;
  Map<String, dynamic>? formDataTa; // TaFormData.toJson()
  Map<String, dynamic>? formDataContingent; // ContingentFormData.toJson()
  String lastUpdated; // ISO-8601
  String? pdfPath;

  /// Frozen profile data (EmployeeProfile.toJson()) captured at finalize
  /// time. Null for draft/fresh sessions and for TAs finalized before this
  /// feature existed.
  Map<String, dynamic>? profileSnapshot;

  TaSession({
    required this.month,
    required this.year,
    required this.employeeId,
    this.status = SessionStatus.fresh,
    this.formDataTa,
    this.formDataContingent,
    String? lastUpdated,
    this.pdfPath,
    this.profileSnapshot,
  }) : lastUpdated = lastUpdated ?? DateTime.now().toIso8601String();

  // ── Hive session key ──────────────────────────────────────────────────────
  static String buildKey(String month, String year, String employeeId) =>
      'session_${month.toLowerCase()}_${year}_$employeeId';

  String get key => buildKey(month, year, employeeId);

  // ── Display label ─────────────────────────────────────────────────────────
  String get displayLabel => '${_capitalize(month)} $year';

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

  bool get hasAnyData => formDataTa != null || formDataContingent != null;

  // ── Serialization ─────────────────────────────────────────────────────────
  String toJsonString() => jsonEncode({
        'month': month,
        'year': year,
        'employee_id': employeeId,
        'status': status.name,
        'form_data_ta': formDataTa,
        'form_data_contingent': formDataContingent,
        'last_updated': lastUpdated,
        'pdf_path': pdfPath,
        'profile_snapshot': profileSnapshot,
      });

  factory TaSession.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final statusStr = json['status'] as String? ?? 'fresh';

    return TaSession(
      month: json['month'] ?? '',
      year: json['year'] ?? '',
      employeeId: json['employee_id'] ?? '',
      status: SessionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => SessionStatus.fresh,
      ),
      formDataTa: json['form_data_ta'] as Map<String, dynamic>?,
      formDataContingent: json['form_data_contingent'] as Map<String, dynamic>?,
      lastUpdated: json['last_updated'] ?? DateTime.now().toIso8601String(),
      pdfPath: json['pdf_path'] as String?,
      profileSnapshot: json['profile_snapshot'] as Map<String, dynamic>?,
    );
  }
}
