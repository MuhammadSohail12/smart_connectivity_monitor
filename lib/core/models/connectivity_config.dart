// lib/core/models/connectivity_config.dart

/// Configuration passed to [SmartConnectivityMonitor.initialize].
///
/// All fields have sensible production-ready defaults.
/// Only override what you need.
///
/// ```dart
/// await SmartConnectivityMonitor.initialize(
///   config: ConnectivityConfig(
///     probeInterval: Duration(seconds: 20),
///     enableCaching: true,
///   ),
/// );
/// ```
class ConnectivityConfig {
  /// How often to run a background probe when the interface hasn't changed.
  /// Lower = more responsive but more battery. Default: 30 seconds.
  final Duration probeInterval;

  /// Hard timeout per probe attempt. Default: 6 seconds.
  final Duration probeTimeout;

  /// Latency below which quality is [ConnectionQuality.excellent]. Default: 100ms.
  final int excellentLatencyMs;

  /// Latency below which quality is [ConnectionQuality.good]. Default: 200ms.
  final int goodLatencyMs;

  /// Latency below which quality is [ConnectionQuality.moderate]. Default: 600ms.
  final int moderateLatencyMs;

  /// Number of drops within [instabilityWindow] to flag as unstable. Default: 3.
  final int instabilityDropThreshold;

  /// Rolling window for instability detection. Default: 2 minutes.
  final Duration instabilityWindow;

  /// Whether to persist last known state in SharedPreferences. Default: true.
  final bool enableCaching;

  /// Primary probe URL. Defaults to Google's generate_204 endpoint.
  final String probeUrl;

  /// Fallback probe URL if primary is unreachable. Defaults to Apple success.
  final String fallbackProbeUrl;

  const ConnectivityConfig({
    this.probeInterval = const Duration(seconds: 30),
    this.probeTimeout = const Duration(seconds: 6),
    this.excellentLatencyMs = 100,
    this.goodLatencyMs = 200,
    this.moderateLatencyMs = 600,
    this.instabilityDropThreshold = 3,
    this.instabilityWindow = const Duration(minutes: 2),
    this.enableCaching = true,
    this.probeUrl = 'https://connectivitycheck.gstatic.com/generate_204',
    this.fallbackProbeUrl = 'https://www.apple.com/library/test/success.html',
  });

  /// Strict config for fintech / high-reliability apps.
  /// More frequent probes, tighter quality thresholds.
  static const strict = ConnectivityConfig(
    probeInterval: Duration(seconds: 15),
    probeTimeout: Duration(seconds: 4),
    excellentLatencyMs: 80,
    goodLatencyMs: 150,
    moderateLatencyMs: 400,
    instabilityDropThreshold: 2,
    instabilityWindow: Duration(minutes: 1),
  );

  /// Relaxed config for low-power or content apps.
  static const relaxed = ConnectivityConfig(
    probeInterval: Duration(minutes: 2),
    probeTimeout: Duration(seconds: 10),
    excellentLatencyMs: 200,
    goodLatencyMs: 400,
    moderateLatencyMs: 1000,
    instabilityDropThreshold: 5,
    instabilityWindow: Duration(minutes: 5),
  );
}
