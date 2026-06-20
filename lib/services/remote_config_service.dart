// lib/services/remote_config_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Fetches API key + model from a GitHub raw file on every app start.
// Falls back to Hive cache if network is unavailable.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/remote_config.dart';
import 'hive_service.dart';

class RemoteConfigResult {
  final String apiKey;
  final String model;

  const RemoteConfigResult({required this.apiKey, required this.model});
}

class RemoteConfigService {
  /// Fetch from GitHub, cache result. Falls back to cache on failure.
  /// Returns null if no key is available anywhere.
  static Future<RemoteConfigResult?> fetch() async {
    // ── Attempt remote fetch ─────────────────────────────────────────────
    try {
      // Cache-bust: GitHub's CDN serves gist/raw URLs with caching, so a
      // fixed URL can return a stale (old) config for several minutes
      // after you update it. Adding a changing query param + no-cache
      // headers forces a fresh fetch every single time.
      final bustUrl = Uri.parse(RemoteConfig.configUrl).replace(
        queryParameters: {
          ...Uri.parse(RemoteConfig.configUrl).queryParameters,
          '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final response = await http
          .get(
            bustUrl,
            headers: {
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json =
            jsonDecode(response.body) as Map<String, dynamic>;
        final apiKey = json['api_key'] as String?;
        final model = json['model'] as String? ?? RemoteConfig.defaultModel;

        if (apiKey != null && apiKey.isNotEmpty) {
          // Cache successful result
          await HiveService.setCachedApiKey(apiKey);
          await HiveService.setCachedModel(model);
          return RemoteConfigResult(apiKey: apiKey, model: model);
        }
      }
    } catch (_) {
      // Network error — fall through to cache
    }

    // ── Fall back to cache ────────────────────────────────────────────────
    final cachedKey = HiveService.cachedApiKey;
    final cachedModel =
        HiveService.cachedModel ?? RemoteConfig.defaultModel;

    if (cachedKey != null && cachedKey.isNotEmpty) {
      return RemoteConfigResult(apiKey: cachedKey, model: cachedModel);
    }

    // ── No key anywhere ───────────────────────────────────────────────────
    return null;
  }
}
