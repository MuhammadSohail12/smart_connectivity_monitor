// lib/core/services/probe_service.dart

import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/connectivity_config.dart';
import '../utils/connectivity_exceptions.dart';

/// Performs the actual HTTP probe that verifies internet access.
///
/// Design:
/// - HEAD request to generate_204 — zero bytes body downloaded.
/// - If primary CDN is unreachable, falls back to Apple success page.
/// - Detects captive portals via unexpected status code or redirect.
/// - Measures only round-trip time — not download speed (too heavy).
abstract interface class ProbeService {
  /// Returns round-trip latency in milliseconds.
  /// Throws [CaptivePortalException], [ProbeTimeoutException],
  /// or [ProbeFailedException] on failure.
  Future<int> probe();

  void dispose();
}

class HttpProbeService implements ProbeService {
  final http.Client _client;
  final ConnectivityConfig _config;

  HttpProbeService({
    required ConnectivityConfig config,
    http.Client? client,
  })  : _config = config,
        _client = client ?? http.Client();

  @override
  Future<int> probe() async {
    try {
      return await _hit(_config.probeUrl, 204);
    } on CaptivePortalException {
      rethrow;
    } catch (_) {
      // Primary failed for a non-portal reason — try fallback.
      try {
        return await _hit(_config.fallbackProbeUrl, 200);
      } on CaptivePortalException {
        rethrow;
      } catch (e) {
        throw ProbeFailedException(
          'Both probe endpoints failed',
          cause: e,
        );
      }
    }
  }

  Future<int> _hit(String url, int expectedStatus) async {
    final sw = Stopwatch()..start();

    final http.Response response;
    try {
      response = await _client
          .head(
            Uri.parse(url),
            headers: {
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_config.probeTimeout);
    } on TimeoutException {
      throw const ProbeTimeoutException();
    }

    sw.stop();

    // Captive portals return a redirect or body with login page.
    if (response.statusCode != expectedStatus) {
      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 307 ||
          (response.contentLength ?? 0) > 100) {
        throw const CaptivePortalException();
      }
      throw ProbeFailedException(
        'Unexpected probe response: ${response.statusCode}',
      );
    }

    return sw.elapsedMilliseconds;
  }

  @override
  void dispose() => _client.close();
}
