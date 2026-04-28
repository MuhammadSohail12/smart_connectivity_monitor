// test/unit/connectivity_cache_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';
import 'package:smart_connectivity_monitor/core/cache/connectivity_cache.dart';

void main() {
  group('SharedPrefsConnectivityCache', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns null when cache is empty', () async {
      final cache = await SharedPrefsConnectivityCache.create();
      expect(await cache.read(), isNull);
    });

    test('write then read returns same result', () async {
      final cache = await SharedPrefsConnectivityCache.create();

      final model = ConnectivityResultModel(
        isOnline: true,
        networkType: NetworkType.wifi,
        quality: ConnectionQuality.excellent,
        isCaptivePortal: false,
        latencyMs: 55,
        timestamp: DateTime(2025, 1, 1),
      );

      await cache.write(model);
      final restored = await cache.read();

      expect(restored, isNotNull);
      expect(restored!.isOnline, isTrue);
      expect(restored.quality, ConnectionQuality.excellent);
      expect(restored.latencyMs, 55);
    });

    test('clear removes cached value', () async {
      final cache = await SharedPrefsConnectivityCache.create();

      final model = ConnectivityResultModel(
        isOnline: true,
        networkType: NetworkType.mobile,
        quality: ConnectionQuality.good,
        isCaptivePortal: false,
        timestamp: DateTime(2025),
      );

      await cache.write(model);
      await cache.clear();

      expect(await cache.read(), isNull);
    });
  });

  group('NoOpConnectivityCache', () {
    test('read always returns null', () async {
      const cache = NoOpConnectivityCache();
      expect(await cache.read(), isNull);
    });

    test('write and clear complete without error', () async {
      const cache = NoOpConnectivityCache();
      final model = ConnectivityResultModel(
        isOnline: false,
        networkType: NetworkType.none,
        quality: ConnectionQuality.none,
        isCaptivePortal: false,
        timestamp: DateTime(2025),
      );
      await expectLater(cache.write(model), completes);
      await expectLater(cache.clear(), completes);
    });
  });
}
