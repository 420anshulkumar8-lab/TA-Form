// lib/providers/app_provider.dart
// Central state manager for the app

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/employee_profile.dart';
import '../services/hive_service.dart';

class AppProvider extends ChangeNotifier {
  EmployeeProfile _profile = EmployeeProfile();
  bool _isDarkMode = false;
  String _appVersion = '1.0.0';

  EmployeeProfile get profile => _profile;
  bool get hasProfile => _profile.isComplete;
  bool get isDarkMode => _isDarkMode;
  String get appVersion => _appVersion;

  AppProvider() {
    _loadFromHive();
    _loadPackageInfo();
  }

  // Load cached values from Hive on startup
  void _loadFromHive() {
    _profile = HiveService.getProfile();
    _isDarkMode = HiveService.isDarkMode;
    notifyListeners();
  }

  // Called from main() to apply saved preferences before first frame
  void setInitialTheme(bool dark) {
    _isDarkMode = dark;
    // no notifyListeners needed — called before runApp
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveProfile(EmployeeProfile profile) async {
    await HiveService.saveProfile(profile);
    // Re-read from Hive (rather than trusting the in-memory `profile` we
    // were handed) so every listener instantly sees exactly what's now
    // persisted — this is what makes the change visible immediately on
    // Home/Drawer/etc. without needing an app restart.
    _profile = HiveService.getProfile();
    notifyListeners();
  }

  void reloadProfile() {
    _profile = HiveService.getProfile();
    notifyListeners();
  }

  Future<void> setProfilePhoto(String path) async {
    final updated = HiveService.getProfile();
    updated.photoPath = path;
    await HiveService.saveProfile(updated);
    _profile = HiveService.getProfile();
    notifyListeners();
  }

  Future<void> removeProfilePhoto() async {
    final updated = HiveService.getProfile();
    updated.photoPath = '';
    await HiveService.saveProfile(updated);
    _profile = HiveService.getProfile();
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await HiveService.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}
