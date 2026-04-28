// test/unit/connectivity_result_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';

void main() {
  ConnectivityResultModel makeModel({
    bool isOnline = true,
    NetworkType type = NetworkType.wifi,
    ConnectionQuality quality = ConnectionQuality.good,
    bool isCaptivePortal = false,
    int? latencyMs = 80,
  }) =>
      ConnectivityResultModel(
        isOnline: isOnline,
        networkType: type,
        quality: quality,
        isCaptivePortal: isCaptivePortal,
        latencyMs: latencyMs,
        timestamp: DateTime(2025),
      );

  group('ConnectivityResultModel', () {
    test('isSlowConnection is true for poor and moderate', () {
      expect(
        makeModel(quality: ConnectionQuality.poor).isSlowConnection,
        isTrue,
      );
      expect(
        makeModel(quality: ConnectionQuality.moderate).isSlowConnection,
        isTrue,
      );
      expect(
        makeModel(quality: ConnectionQuality.good).isSlowConnection,
        isFalse,
      );
      expect(
        makeModel(quality: ConnectionQuality.excellent).isSlowConnection,
        isFalse,
      );
    });

    test('isStableConnection is true for good and excellent', () {
      expect(makeModel(quality: ConnectionQuality.good).isStableConnection, isTrue);
      expect(
          makeModel(quality: ConnectionQuality.excellent).isStableConnection,
          isTrue);
      expect(
          makeModel(quality: ConnectionQuality.poor).isStableConnection, isFalse);
    });

    test('toJson / fromJson round-trips correctly', () {
      final model = makeModel();
      final json = model.toJson();
      final restored = ConnectivityResultModel.fromJson(json);
      expect(restored, equals(model));
    });

    test('equality ignores timestamp', () {
      final a = makeModel();
      final b = makeModel();
      expect(a, equals(b));
    });

    test('copyWith updates only specified fields', () {
      final original = makeModel();
      final updated = original.copyWith(quality: ConnectionQuality.poor);
      expect(updated.quality, ConnectionQuality.poor);
      expect(updated.isOnline, original.isOnline);
      expect(updated.networkType, original.networkType);
    });

    test('unknown sentinel is offline with none quality', () {
      final unknown = ConnectivityResultModel.unknown;
      expect(unknown.isOnline, isFalse);
      expect(unknown.quality, ConnectionQuality.none);
      expect(unknown.networkType, NetworkType.none);
    });
  });
}
