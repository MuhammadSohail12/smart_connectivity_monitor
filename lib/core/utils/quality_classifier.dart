// lib/core/utils/quality_classifier.dart

import '../models/connectivity_config.dart';
import '../models/connectivity_result_model.dart';

/// Stateless utility — classifies latency into [ConnectionQuality].
///
/// Separated from the probe service so thresholds are testable in isolation
/// and can be swapped without touching network code.
abstract final class QualityClassifier {
  static ConnectionQuality classify(int latencyMs, ConnectivityConfig config) {
    if (latencyMs < config.excellentLatencyMs) {
      return ConnectionQuality.excellent;
    }
    if (latencyMs < config.goodLatencyMs) return ConnectionQuality.good;
    if (latencyMs < config.moderateLatencyMs) return ConnectionQuality.moderate;
    return ConnectionQuality.poor;
  }
}
