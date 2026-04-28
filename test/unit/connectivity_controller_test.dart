// test/unit/connectivity_controller_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';
import 'package:smart_connectivity_monitor/core/cache/connectivity_cache.dart';
import 'package:smart_connectivity_monitor/core/services/connectivity_monitor_service.dart';
import 'package:smart_connectivity_monitor/core/services/network_interface_service.dart';
import 'package:smart_connectivity_monitor/core/services/probe_service.dart';
import 'package:smart_connectivity_monitor/features/connectivity/controller/connectivity_controller.dart';

class MockNetworkService extends Mock implements NetworkInterfaceService {}
class MockProbeService extends Mock implements ProbeService {}
class MockCache extends Mock implements ConnectivityCache {}

void main() {
  late MockNetworkService network;
  late MockProbeService probe;
  late MockCache cache;
  late StreamController<NetworkType> interfaceCtrl;
  late ConnectivityMonitorService monitorService;
  late ConnectivityController controller;

  const config = ConnectivityConfig(
    probeInterval: Duration(hours: 1),
  );

  setUp(() {
    network = MockNetworkService();
    probe = MockProbeService();
    cache = MockCache();
    interfaceCtrl = StreamController<NetworkType>.broadcast();

    when(() => network.interfaceStream).thenAnswer((_) => interfaceCtrl.stream);
    when(() => network.dispose()).thenReturn(null);
    when(() => probe.dispose()).thenReturn(null);
    when(() => cache.read()).thenAnswer((_) async => null);
    when(() => cache.write(any())).thenAnswer((_) async {});

    monitorService = ConnectivityMonitorService(
      interfaceService: network,
      probeService: probe,
      config: config,
    );

    controller = ConnectivityController(
      monitorService: monitorService,
      cache: cache,
    );
  });

  tearDown(() async {
    await controller.dispose();
    await interfaceCtrl.close();
  });

  group('ConnectivityController', () {
    test('initial state is ConnectivityChecking', () {
      expect(controller.currentState, isA<ConnectivityChecking>());
    });

    test('transitions to ConnectivityLoaded after successful probe', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async => 80);

      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.currentState, isA<ConnectivityLoaded>());
      expect(controller.isOnline, isTrue);
    });

    test('fires onConnectionLost callback when dropping from online', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async => 80);

      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var lostFired = false;
      controller.addConnectionLostListener((_) => lostFired = true);

      // Simulate drop.
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.none);
      interfaceCtrl.add(NetworkType.none);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(lostFired, isTrue);
    });

    test('fires onConnectionRestored callback', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.none);
      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var restoredFired = false;
      controller.addConnectionRestoredListener((_) => restoredFired = true);

      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async => 60);
      interfaceCtrl.add(NetworkType.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(restoredFired, isTrue);
    });

    test('emits cached result immediately on start', () async {
      final cached = ConnectivityResultModel(
        isOnline: true,
        networkType: NetworkType.wifi,
        quality: ConnectionQuality.good,
        isCaptivePortal: false,
        latencyMs: 90,
        timestamp: DateTime(2025),
      );
      when(() => cache.read()).thenAnswer((_) async => cached);
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async => 90);

      final states = <ConnectivityState>[];
      final sub = controller.stateStream.listen(states.add);

      await controller.start();

      // The first emission after checking should be from cache.
      final loaded = states.whereType<ConnectivityLoaded>().first;
      expect(loaded.isOnline, isTrue);

      await sub.cancel();
    });

    test('writes result to cache on each probe', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.mobile);
      when(() => probe.probe()).thenAnswer((_) async => 200);

      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => cache.write(any())).called(greaterThanOrEqualTo(1));
    });
  });
}
