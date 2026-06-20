// lib/providers/app_provider.dart
// Central state manager for the app

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/employee_profile.dart';
import '../services/hive_service.dart';
import '../services/remote_config_service.dart';
import '../config/remote_config.dart';

class AppProvider extends ChangeNotifier {
  EmployeeProfile _profile = EmployeeProfile();
  String? _apiKey;
  String _model = RemoteConfig.defaultModel;
  bool _isLoadingConfig = false;
  String? _configError;
  String _appLanguage = 'Hinglish';
  bool _isDarkMode = false;
  String _appVersion = '1.0.0';

  EmployeeProfile get profile => _profile;
  String? get apiKey => _apiKey;
  String get model => _model;
  bool get isLoadingConfig => _isLoadingConfig;
  String? get configError => _configError;
  bool get hasProfile => _profile.isComplete;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String get appLanguage => _appLanguage;
  bool get isDarkMode => _isDarkMode;
  String get appVersion => _appVersion;

  AppProvider() {
    _loadFromHive();
    _loadPackageInfo();
  }

  // Load cached values from Hive on startup
  void _loadFromHive() {
    _profile = HiveService.getProfile();
    _apiKey = HiveService.cachedApiKey;
    final cachedModel = HiveService.cachedModel;
    if (cachedModel != null && cachedModel.isNotEmpty) {
      _model = cachedModel;
    }
    _appLanguage = HiveService.appLanguage;
    _isDarkMode = HiveService.isDarkMode;
    notifyListeners();
  }

  // Called from main() to apply saved preferences before first frame
  void setInitialTheme(bool dark) {
    _isDarkMode = dark;
    // no notifyListeners needed — called before runApp
  }

  void setInitialLanguage(String lang) {
    if (lang.isNotEmpty) _appLanguage = lang;
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      notifyListeners();
    } catch (_) {}
  }

  // Fetch live config from remote URL
  Future<bool> loadRemoteConfig() async {
    _isLoadingConfig = true;
    _configError = null;
    notifyListeners();

    try {
      final config = await RemoteConfigService.fetch();
      if (config != null) {
        _apiKey = config.apiKey;
        _model = config.model;
        await HiveService.setCachedApiKey(config.apiKey);
        await HiveService.setCachedModel(config.model);
        _isLoadingConfig = false;
        notifyListeners();
        return true;
      } else {
        _configError = 'Config server se connect nahi ho saka. '
            'Internet check karein.';
      }
    } catch (e) {
      _configError = 'Config load error. Cached key use kar rahe hain.';
    }

    _isLoadingConfig = false;
    notifyListeners();
    return false;
  }

  Future<void> saveProfile(EmployeeProfile profile) async {
    _profile = profile;
    await HiveService.saveProfile(profile);
    notifyListeners();
  }

  void reloadProfile() {
    _profile = HiveService.getProfile();
    notifyListeners();
  }

  Future<void> setAppLanguage(String language) async {
    _appLanguage = language;
    await HiveService.setAppLanguage(language);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await HiveService.setDarkMode(_isDarkMode);
    notifyListeners();
  }
}
