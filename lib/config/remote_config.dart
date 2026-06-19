// lib/config/remote_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// Replace CONFIG_URL with your GitHub private repo raw file URL.
// Format of config.json on GitHub:
//   { "api_key": "AIzaSy-xxxx", "model": "gemini-2.0-flash" }
// ─────────────────────────────────────────────────────────────────────────────

class RemoteConfig {
  /// Replace this with your actual GitHub raw content URL.
  /// Example:
  ///   "https://raw.githubusercontent.com/your-org/private-repo/main/config.json"
  static const String configUrl =
      'https://gist.githubusercontent.com/420anshulkumar8-lab/0c2fea6e262cf353543414f68b9c9b74/raw/d7b86cb89c42d79f40b56256ab40993fd743da33/config.json';

  /// Default model to use if remote config cannot be fetched
  static const String defaultModel = 'google/gemini-2.0-flash-exp:free';

  /// Hive settings keys
  static const String hiveCachedApiKey = 'cached_api_key';
  static const String hiveCachedModel = 'cached_model';
}
