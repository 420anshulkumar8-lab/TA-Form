// lib/services/hive_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Central Hive database service. All boxes opened here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:hive_flutter/hive_flutter.dart';
import '../models/employee_profile.dart';
import '../models/ta_session.dart';

class HiveService {
  static const String _settingsBox = 'settings';
  static const String _profileBox = 'employee_profile';
  static const String _sessionsBox = 'ta_sessions';

  // ── Initialise all boxes ──────────────────────────────────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EmployeeProfileAdapter());
    }

    // Open boxes
    await Hive.openBox(_settingsBox);
    await Hive.openBox<EmployeeProfile>(_profileBox);
    await Hive.openBox<String>(_sessionsBox); // JSON strings

    await _migrateSessionsToStableOwner();
  }

  /// One-time (idempotent) migration: earlier versions keyed sessions by the
  /// editable Employee Number, so changing it made every saved session
  /// unreachable. Re-key any such session under the stable owner id so the
  /// data reappears and can never be orphaned again.
  static Future<void> _migrateSessionsToStableOwner() async {
    final box = Hive.box<String>(_sessionsBox);
    for (final oldKey in box.keys.toList()) {
      final raw = box.get(oldKey);
      if (raw == null) continue;
      TaSession s;
      try {
        s = TaSession.fromJsonString(raw);
      } catch (_) {
        continue;
      }
      if (s.employeeId == TaSession.ownerId && oldKey == s.key) continue;
      final migrated = TaSession(
        month: s.month,
        year: s.year,
        employeeId: TaSession.ownerId,
        status: s.status,
        formDataTa: s.formDataTa,
        formDataContingent: s.formDataContingent,
        lastUpdated: s.lastUpdated,
        pdfPath: s.pdfPath,
        profileSnapshot: s.profileSnapshot,
      );
      final existing = box.get(migrated.key);
      // If two old sessions collapse onto one key, keep the newer one.
      if (existing != null) {
        final e = TaSession.fromJsonString(existing);
        if (e.lastUpdated.compareTo(s.lastUpdated) >= 0) {
          await box.delete(oldKey);
          continue;
        }
      }
      await box.put(migrated.key, migrated.toJsonString());
      if (oldKey != migrated.key) await box.delete(oldKey);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  static Box get _settings => Hive.box(_settingsBox);

  static bool get isDarkMode =>
      _settings.get('theme_mode', defaultValue: false) as bool;

  static Future<void> setDarkMode(bool value) =>
      _settings.put('theme_mode', value);

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPLOYEE PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  static Box<EmployeeProfile> get _profileBoxRef =>
      Hive.box<EmployeeProfile>(_profileBox);

  static EmployeeProfile getProfile() {
    return _profileBoxRef.get('profile') ?? EmployeeProfile();
  }

  static Future<void> saveProfile(EmployeeProfile profile) async {
    // Delete-then-put avoids any stale HiveObject binding from a previously
    // read instance, so every read after this always reflects the latest
    // save immediately (no app-restart needed to see the new value).
    await _profileBoxRef.delete('profile');
    await _profileBoxRef.put('profile', profile);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TA SESSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Box<String> get _sessions => Hive.box<String>(_sessionsBox);

  static TaSession? getSession(String key) {
    final raw = _sessions.get(key);
    if (raw == null) return null;
    return TaSession.fromJsonString(raw);
  }

  static Future<void> saveSession(TaSession session) async {
    await _sessions.put(session.key, session.toJsonString());
  }

  static Future<void> deleteSession(String key) async {
    await _sessions.delete(key);
  }

  /// Returns all sessions sorted by last updated, newest first.
  static List<TaSession> getAllSessions() {
    return _sessions.values
        .map((raw) {
          try {
            return TaSession.fromJsonString(raw);
          } catch (_) {
            return null;
          }
        })
        .whereType<TaSession>()
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
  }

  /// Sessions for the (single) profile owner. The argument is ignored on
  /// purpose: sessions are tied to the stable owner id, never to the
  /// editable Employee Number.
  static List<TaSession> getSessionsForEmployee([String? _]) {
    return getAllSessions()
        .where((s) => s.employeeId == TaSession.ownerId)
        .toList();
  }
}
