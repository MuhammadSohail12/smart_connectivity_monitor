// test/unit/quality_classifier_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';
import 'package:smart_connectivity_monitor/core/utils/quality_classifier.dart';

void main() {
  const config = ConnectivityConfig(
    excellentLatencyMs: 100,
    goodLatencyMs: 200,
    moderateLatencyMs: 600,
  );

  group('QualityClassifier', () {
    test('returns excellent for latency < 100ms', () {
      expect(QualityClassifier.classify(50, config), ConnectionQuality.excellent);
      expect(QualityClassifier.classify(99, config), ConnectionQuality.excellent);
    });

    test('returns good for latency 100–199ms', () {
      expect(QualityClassifier.classify(100, config), ConnectionQuality.good);
      expect(QualityClassifier.classify(199, config), ConnectionQuality.good);
    });

    test('returns moderate for latency 200–599ms', () {
      expect(
          QualityClassifier.classify(200, config), ConnectionQuality.moderate);
      expect(
          QualityClassifier.classify(599, config), ConnectionQuality.moderate);
    });

    test('returns poor for latency >= 600ms', () {
      expect(QualityClassifier.classify(600, config), ConnectionQuality.poor);
      expect(QualityClassifier.classify(1200, config), ConnectionQuality.poor);
    });
  });
}
