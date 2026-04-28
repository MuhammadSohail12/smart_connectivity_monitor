// lib/core/models/connectivity_result_model.dart

/// The complete connectivity snapshot at a point in time.
///
/// This is the single data object passed through the entire package.
/// Every stream emission, cache read, and widget callback uses this type.
class ConnectivityResultModel {
  /// Whether internet is reachable and verified.
  final bool isOnline;

  /// The active network interface type.
  final NetworkType networkType;

  /// Quality of the current connection based on measured latency.
  final ConnectionQuality quality;

  /// True when connected to WiFi/mobile but a captive portal intercepts traffic.
  final bool isCaptivePortal;

  /// Measured round-trip latency in milliseconds. Null when offline.
  final int? latencyMs;

  /// When this snapshot was taken.
  final DateTime timestamp;

  const ConnectivityResultModel({
    required this.isOnline,
    required this.networkType,
    required this.quality,
    required this.isCaptivePortal,
    this.latencyMs,
    required this.timestamp,
  });

  /// True when online but connection is slow (poor or moderate quality).
  bool get isSlowConnection =>
      isOnline &&
      (quality == ConnectionQuality.poor ||
          quality == ConnectionQuality.moderate);

  /// True when connection is good enough for normal app operation.
  bool get isStableConnection =>
      isOnline &&
      (quality == ConnectionQuality.good ||
          quality == ConnectionQuality.excellent);

  /// Sentinel value — safe fallback before first probe completes.
  static ConnectivityResultModel get unknown => ConnectivityResultModel(
        isOnline: false,
        networkType: NetworkType.none,
        quality: ConnectionQuality.none,
        isCaptivePortal: false,
        timestamp: DateTime.now(),
      );

  ConnectivityResultModel copyWith({
    bool? isOnline,
    NetworkType? networkType,
    ConnectionQuality? quality,
    bool? isCaptivePortal,
    int? latencyMs,
    DateTime? timestamp,
  }) =>
      ConnectivityResultModel(
        isOnline: isOnline ?? this.isOnline,
        networkType: networkType ?? this.networkType,
        quality: quality ?? this.quality,
        isCaptivePortal: isCaptivePortal ?? this.isCaptivePortal,
        latencyMs: latencyMs ?? this.latencyMs,
        timestamp: timestamp ?? this.timestamp,
      );

  /// Serialise to JSON for caching in SharedPreferences.
  Map<String, dynamic> toJson() => {
        'isOnline': isOnline,
        'networkType': networkType.name,
        'quality': quality.name,
        'isCaptivePortal': isCaptivePortal,
        'latencyMs': latencyMs,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Deserialise from cached JSON.
  factory ConnectivityResultModel.fromJson(Map<String, dynamic> json) =>
      ConnectivityResultModel(
        isOnline: json['isOnline'] as bool,
        networkType: NetworkType.values.firstWhere(
          (e) => e.name == json['networkType'],
          orElse: () => NetworkType.none,
        ),
        quality: ConnectionQuality.values.firstWhere(
          (e) => e.name == json['quality'],
          orElse: () => ConnectionQuality.none,
        ),
        isCaptivePortal: json['isCaptivePortal'] as bool,
        latencyMs: json['latencyMs'] as int?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectivityResultModel &&
          isOnline == other.isOnline &&
          networkType == other.networkType &&
          quality == other.quality &&
          isCaptivePortal == other.isCaptivePortal &&
          latencyMs == other.latencyMs;

  @override
  int get hashCode =>
      Object.hash(isOnline, networkType, quality, isCaptivePortal, latencyMs);

  @override
  String toString() =>
      'ConnectivityResultModel('
      'isOnline: $isOnline, '
      'type: $networkType, '
      'quality: $quality, '
      'captive: $isCaptivePortal, '
      'latency: ${latencyMs}ms)';
}

/// Active network interface type.
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  none,
}

/// Connection quality derived from measured latency.
///
/// Thresholds (configurable via [ConnectivityConfig]):
/// - excellent : < 100ms
/// - good      : 100–200ms
/// - moderate  : 200–600ms
/// - poor      : > 600ms
/// - none      : offline
enum ConnectionQuality {
  none,
  poor,
  moderate,
  good,
  excellent,
}

extension ConnectionQualityX on ConnectionQuality {
  /// Human-readable label for display in UI.
  String get label => switch (this) {
        ConnectionQuality.excellent => 'Excellent',
        ConnectionQuality.good => 'Good',
        ConnectionQuality.moderate => 'Moderate',
        ConnectionQuality.poor => 'Poor',
        ConnectionQuality.none => 'No Connection',
      };

  bool get isSlow =>
      this == ConnectionQuality.poor || this == ConnectionQuality.moderate;
}
