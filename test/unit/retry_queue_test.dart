// test/unit/retry_queue_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';

void main() {
  late RetryQueue queue;
  late StreamController<ConnectivityState> stateCtrl;

  ConnectivityState onlineState() => ConnectivityLoaded(
        ConnectivityResultModel(
          isOnline: true,
          networkType: NetworkType.wifi,
          quality: ConnectionQuality.good,
          isCaptivePortal: false,
          latencyMs: 80,
          timestamp: DateTime.now(),
        ),
      );

  ConnectivityState offlineState() => ConnectivityLoaded(
        ConnectivityResultModel(
          isOnline: false,
          networkType: NetworkType.none,
          quality: ConnectionQuality.none,
          isCaptivePortal: false,
          timestamp: DateTime.now(),
        ),
      );

  setUp(() {
    stateCtrl = StreamController<ConnectivityState>.broadcast();
    queue = RetryQueue(
      maxRetries: 2,
      baseDelay: const Duration(milliseconds: 10),
    );
  });

  tearDown(() async {
    queue.dispose();
    await stateCtrl.close();
  });

  group('RetryQueue', () {
    test('executes immediately when online', () async {
      queue.attach(stateCtrl.stream);
      stateCtrl.add(onlineState());
      await Future<void>.delayed(Duration.zero);

      var called = false;
      final result = await queue.enqueue<String>(() async {
        called = true;
        return 'done';
      });

      expect(called, isTrue);
      expect(result, 'done');
    });

    test('retries on transient failure', () async {
      queue.attach(stateCtrl.stream);
      stateCtrl.add(onlineState());
      await Future<void>.delayed(Duration.zero);

      var attempts = 0;
      final result = await queue.enqueue<String>(() async {
        attempts++;
        if (attempts < 2) throw Exception('transient error');
        return 'recovered';
      });

      expect(result, 'recovered');
      expect(attempts, 2);
    });

    test('fails after max retries exceeded', () async {
      queue.attach(stateCtrl.stream);
      stateCtrl.add(onlineState());
      await Future<void>.delayed(Duration.zero);

      var attempts = 0;
      await expectLater(
        queue.enqueue<String>(() async {
          attempts++;
          throw Exception('permanent failure');
        }),
        throwsException,
      );

      // Initial attempt + 2 retries = 3.
      expect(attempts, 3);
    });

    test('parks request when offline and replays on restore', () async {
      queue.attach(stateCtrl.stream);
      stateCtrl.add(offlineState());
      await Future<void>.delayed(Duration.zero);

      var executed = false;
      final future = queue.enqueue<String>(() async {
        executed = true;
        return 'queued result';
      });

      // Not executed yet.
      expect(executed, isFalse);

      // Go online.
      stateCtrl.add(onlineState());
      final result = await future;

      expect(executed, isTrue);
      expect(result, 'queued result');
    });

    test('throws QueueDisposedException when queue is disposed with pending items',
        () async {
      queue.attach(stateCtrl.stream);
      stateCtrl.add(offlineState());
      await Future<void>.delayed(Duration.zero);

      final future = queue.enqueue<String>(() async => 'never');
      queue.dispose();

      await expectLater(future, throwsA(isA<QueueDisposedException>()));
    });
  });
}
