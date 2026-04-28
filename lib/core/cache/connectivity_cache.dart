// lib/core/cache/connectivity_cache.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/connectivity_result_model.dart';

/// Persists and retrieves the last known [ConnectivityResultModel].
///
/// Used to:
/// - Show a meaningful UI state immediately on app launch (before first probe).
/// - Let the app know if it was online when last used.
///
/// Uses [SharedPreferences] — lightweight, no external DB needed.
abstract interface class ConnectivityCache {
  Future<ConnectivityResultModel?> read();
  Future<void> write(ConnectivityResultModel result);
  Future<void> clear();
}

class SharedPrefsConnectivityCache implements ConnectivityCache {
  static const _key = 'scm_last_connectivity_result';

  final SharedPreferences _prefs;

  SharedPrefsConnectivityCache(this._prefs);

  /// Factory constructor — handles SharedPreferences initialization.
  static Future<SharedPrefsConnectivityCache> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsConnectivityCache(prefs);
  }

  @override
  Future<ConnectivityResultModel?> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ConnectivityResultModel.fromJson(json);
    } catch (_) {
      // Corrupt cache — clear it and return null.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ConnectivityResultModel result) async {
    await _prefs.setString(_key, jsonEncode(result.toJson()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

/// No-op cache for tests or when caching is disabled via [ConnectivityConfig].
class NoOpConnectivityCache implements ConnectivityCache {
  const NoOpConnectivityCache();

  @override
  Future<ConnectivityResultModel?> read() async => null;

  @override
  Future<void> write(ConnectivityResultModel result) async {}

  @override
  Future<void> clear() async {}
}
