// test/widget/connectivity_banner_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';
import 'package:smart_connectivity_monitor/core/cache/connectivity_cache.dart';
import 'package:smart_connectivity_monitor/core/services/network_interface_service.dart';
import 'package:smart_connectivity_monitor/core/services/probe_service.dart';

class MockNetworkService extends Mock implements NetworkInterfaceService {}
class MockProbeService extends Mock implements ProbeService {}

void main() {
  late MockNetworkService network;
  late MockProbeService probe;
  late StreamController<NetworkType> interfaceCtrl;

  setUp(() {
    network = MockNetworkService();
    probe = MockProbeService();
    interfaceCtrl = StreamController<NetworkType>.broadcast();

    when(() => network.interfaceStream).thenAnswer((_) => interfaceCtrl.stream);
    when(() => network.dispose()).thenReturn(null);
    when(() => probe.dispose()).thenReturn(null);
  });

  tearDown(() async {
    if (SmartConnectivityMonitor.isInitialized) {
      await SmartConnectivityMonitor.dispose();
    }
    await interfaceCtrl.close();
  });

  Future<void> init({
    required WidgetTester tester,
    required NetworkType networkType,
    int? probeLatency,
    bool throwCaptivePortal = false,
  }) async {
    when(() => network.getCurrentType())
        .thenAnswer((_) async => networkType);

    if (networkType != NetworkType.none) {
      if (throwCaptivePortal) {
        when(() => probe.probe()).thenThrow(const CaptivePortalDetectedException());
      } else if (probeLatency != null) {
        when(() => probe.probe()).thenAnswer((_) async => probeLatency);
      }
    }

    await SmartConnectivityMonitor.initialize(
      config: const ConnectivityConfig(probeInterval: Duration(hours: 1)),
      overrides: SmartConnectivityOverrides(
        networkInterfaceService: network,
        probeService: probe,
        cache: const NoOpConnectivityCache(),
      ),
    );

    // Wait for initial probe.
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }

  Widget buildApp() => MaterialApp(
        builder: (context, child) => Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child ?? const SizedBox()),
          ],
        ),
        home: const Scaffold(body: Text('Content')),
      );

  group('ConnectivityBanner', () {
    testWidgets('does not show when online with good connection', (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.wifi,
        probeLatency: 80,
      ));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Banner should not be visible.
      expect(find.text('No internet connection'), findsNothing);
    });

    testWidgets('shows offline message when no internet', (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.none,
      ));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets('shows captive portal message when portal detected',
        (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.wifi,
        throwCaptivePortal: true,
      ));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('WiFi connected — login required'), findsOneWidget);
    });

    testWidgets('shows slow connection when quality is poor', (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.mobile,
        probeLatency: 800, // > 600ms → poor
      ));

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.text('Slow connection detected'), findsOneWidget);
    });

    testWidgets('ConnectivityBuilder rebuilds on state change', (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.wifi,
        probeLatency: 80,
      ));

      final widget = MaterialApp(
        home: Scaffold(
          body: ConnectivityBuilder(
            builder: (context, state) => switch (state) {
              ConnectivityLoaded s when s.isOnline =>
                const Text('ONLINE'),
              ConnectivityLoaded() => const Text('OFFLINE'),
              ConnectivityChecking() => const Text('CHECKING'),
              ConnectivityError() => const Text('ERROR'),
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('ONLINE'), findsOneWidget);
    });

    testWidgets('OnlineOfflineBuilder shows correct widget', (tester) async {
      await tester.runAsync(() => init(
        tester: tester,
        networkType: NetworkType.none,
      ));

      final widget = MaterialApp(
        home: Scaffold(
          body: OnlineOfflineBuilder(
            online: (_) => const Text('ONLINE'),
            offline: (_) => const Text('OFFLINE'),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('ONLINE'), findsNothing);
    });
  });
}
