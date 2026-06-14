// lib/config/remote_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// Replace CONFIG_URL with your GitHub private repo raw file URL.
// Format of config.json on GitHub:
//   { "api_key": "sk-ant-xxxx", "model": "claude-sonnet-4-6" }
// ─────────────────────────────────────────────────────────────────────────────

class RemoteConfig {
  /// Replace this with your actual GitHub raw content URL.
  /// Example:
  ///   "https://raw.githubusercontent.com/your-org/private-repo/main/config.json"
  static const String configUrl =
      'YOUR_GITHUB_RAW_URL';

  /// Default model to use if remote config cannot be fetched
  static const String defaultModel = 'claude-sonnet-4-6';

  /// Hive settings keys
  static const String hiveCachedApiKey = 'cached_api_key';
  static const String hiveCachedModel = 'cached_model';
}
