// test/unit/connectivity_monitor_service_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';
import 'package:smart_connectivity_monitor/core/services/connectivity_monitor_service.dart';
import 'package:smart_connectivity_monitor/core/services/network_interface_service.dart';
import 'package:smart_connectivity_monitor/core/services/probe_service.dart';
import 'package:smart_connectivity_monitor/core/utils/connectivity_exceptions.dart';

class MockNetworkService extends Mock implements NetworkInterfaceService {}
class MockProbeService extends Mock implements ProbeService {}

void main() {
  late MockNetworkService network;
  late MockProbeService probe;
  late StreamController<NetworkType> interfaceCtrl;
  late ConnectivityMonitorService service;

  const config = ConnectivityConfig(
    probeInterval: Duration(hours: 1), // Disable periodic probes in tests.
  );

  setUp(() {
    network = MockNetworkService();
    probe = MockProbeService();
    interfaceCtrl = StreamController<NetworkType>.broadcast();

    when(() => network.interfaceStream).thenAnswer((_) => interfaceCtrl.stream);
    when(() => network.dispose()).thenReturn(null);
    when(() => probe.dispose()).thenReturn(null);

    service = ConnectivityMonitorService(
      interfaceService: network,
      probeService: probe,
      config: config,
    );
  });

  tearDown(() async {
    await service.dispose();
    await interfaceCtrl.close();
  });

  group('ConnectivityMonitorService', () {
    test('emits offline immediately when no interface', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.none);

      await service.start();
      await Future<void>.delayed(Duration.zero);

      expect(service.current.isOnline, isFalse);
      expect(service.current.networkType, NetworkType.none);
      verifyNever(() => probe.probe());
    });

    test('emits excellent quality when latency < 100ms', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async => 60);

      final results = <ConnectivityResultModel>[];
      final sub = service.stream.listen(results.add);

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();

      expect(results.last.isOnline, isTrue);
      expect(results.last.quality, ConnectionQuality.excellent);
    });

    test('emits captive portal when probe throws CaptivePortalException', () async {
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenThrow(const CaptivePortalException());

      final results = <ConnectivityResultModel>[];
      final sub = service.stream.listen(results.add);

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();

      expect(results.last.isCaptivePortal, isTrue);
      expect(results.last.isOnline, isFalse);
    });

    test('re-probes when interface stream emits', () async {
      var callCount = 0;
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.wifi);
      when(() => probe.probe()).thenAnswer((_) async {
        callCount++;
        return 80;
      });

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      interfaceCtrl.add(NetworkType.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // One from start() + one from interface event.
      expect(callCount, greaterThanOrEqualTo(2));
    });

    test('triggerProbe causes immediate re-probe', () async {
      var callCount = 0;
      when(() => network.getCurrentType())
          .thenAnswer((_) async => NetworkType.mobile);
      when(() => probe.probe()).thenAnswer((_) async {
        callCount++;
        return 150;
      });

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      service.triggerProbe();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(callCount, greaterThanOrEqualTo(2));
    });
  });
}
