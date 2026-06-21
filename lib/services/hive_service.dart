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

  /// Sessions for the current employee only
  static List<TaSession> getSessionsForEmployee(String employeeId) {
    return getAllSessions()
        .where((s) => s.employeeId == employeeId)
        .toList();
  }
}
