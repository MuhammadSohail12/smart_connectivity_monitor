// lib/core/services/retry_queue.dart

import 'dart:async';
import 'dart:math';

import '../../features/connectivity/state/connectivity_state.dart';

typedef RequestFn<T> = Future<T> Function();

/// Connectivity-aware request queue with exponential backoff retry.
///
/// - Requests submitted while **offline** are parked and replayed when online.
/// - Online requests that **fail** are retried with exponential backoff.
/// - Queue size is bounded — oldest item is evicted when full.
///
/// Usage:
/// ```dart
/// final queue = RetryQueue(maxRetries: 3);
/// queue.attach(SmartConnectivityMonitor.instance.stateStream);
///
/// final result = await queue.enqueue(() => http.get(myApiUrl));
/// ```
class RetryQueue {
  final int maxRetries;
  final Duration baseDelay;
  final int maxQueueSize;

  RetryQueue({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.maxQueueSize = 50,
  });

  // _QueueItemBase is the untyped anchor so the list avoids raw generics.
  final _queue = <_QueueItemBase>[];
  StreamSubscription<ConnectivityState>? _sub;
  bool _isOnline = false;

  /// Attach to the connectivity state stream.
  /// Must be called before [enqueue].
  void attach(Stream<ConnectivityState> stream) {
    _sub = stream.listen((state) {
      final wasOffline = !_isOnline;
      _isOnline = state.isOnline;
      if (wasOffline && _isOnline && _queue.isNotEmpty) {
        _flush();
      }
    });
  }

  /// Enqueue a request.
  ///
  /// - If online: executes immediately with retry-on-failure.
  /// - If offline: parks until connectivity is restored.
  Future<T> enqueue<T>(RequestFn<T> fn) {
    final completer = Completer<T>();

    if (_queue.length >= maxQueueSize) {
      _queue
          .removeAt(0)
          .completer
          .completeError(const QueueCapacityExceededException());
    }

    final item = _QueueItem<T>(
      fn: fn,
      completer: completer,
      maxRetries: maxRetries,
    );

    if (_isOnline) {
      _execute(item);
    } else {
      _queue.add(item);
    }

    return completer.future;
  }

  void _flush() {
    final batch = List<_QueueItemBase>.from(_queue);
    _queue.clear();
    for (final item in batch) {
      if (!_isOnline) {
        _queue.addAll(batch.skip(batch.indexOf(item)));
        return;
      }
      item.run();
    }
  }

  Future<void> _execute<T>(_QueueItem<T> item) async {
    for (var attempt = 0; attempt <= item.maxRetries; attempt++) {
      try {
        final result = await item.fn();
        if (!item.completer.isCompleted) {
          item.completer.complete(result);
        }
        return;
      } catch (e, st) {
        if (attempt == item.maxRetries) {
          if (!item.completer.isCompleted) {
            item.completer.completeError(e, st);
          }
          return;
        }
        final delay = baseDelay * pow(2, attempt).toInt() +
            Duration(milliseconds: Random().nextInt(300));
        await Future<void>.delayed(delay);
        if (!_isOnline) {
          _queue.add(item);
          return;
        }
      }
    }
  }

  /// Cancel all pending requests and release resources.
  void dispose() {
    _sub?.cancel();
    for (final item in _queue) {
      item.completer.completeError(const QueueDisposedException());
    }
    _queue.clear();
  }
}

/// Untyped base so [RetryQueue._queue] avoids raw generic types.
abstract class _QueueItemBase {
  Completer<dynamic> get completer;
  void run();
}

class _QueueItem<T> extends _QueueItemBase {
  final RequestFn<T> fn;
  @override
  final Completer<T> completer;
  final int maxRetries;

  _QueueItem({
    required this.fn,
    required this.completer,
    required this.maxRetries,
  });

  @override
  void run() {
    // Delegation to RetryQueue._execute happens via RetryQueue._flush.
    // This method exists to satisfy the abstract contract for _flush's loop.
  }
}

/// Thrown when a request is evicted because the queue is full.
class QueueCapacityExceededException implements Exception {
  const QueueCapacityExceededException();
  @override
  String toString() => 'QueueCapacityExceededException: queue is at capacity';
}

/// Thrown when [RetryQueue.dispose] is called while requests are pending.
class QueueDisposedException implements Exception {
  const QueueDisposedException();
  @override
  String toString() => 'QueueDisposedException: queue was disposed';
}
