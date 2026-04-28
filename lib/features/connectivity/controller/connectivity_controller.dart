// lib/features/connectivity/controller/connectivity_controller.dart

import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../../../core/cache/connectivity_cache.dart';
import '../../../core/models/connectivity_result_model.dart';
import '../../../core/services/connectivity_monitor_service.dart';
import '../state/connectivity_state.dart';

/// The public-facing controller — the only type consumers interact with directly.
///
/// What it does:
/// - Wraps [ConnectivityMonitorService] in a typed [ConnectivityState] stream.
/// - Caches results on each emission.
/// - Fires registered callbacks (onConnectionLost, onConnectionRestored, etc.).
/// - Exposes [BehaviorSubject] so new subscribers get current state immediately.
/// - Handles the initial cache read for immediate UI on app launch.
class ConnectivityController {
  final ConnectivityMonitorService _monitorService;
  final ConnectivityCache _cache;

  late final BehaviorSubject<ConnectivityState> _subject;
  StreamSubscription<ConnectivityResultModel>? _monitorSub;

  // Registered global callbacks.
  final _onConnectionLost = <void Function(ConnectivityResultModel)>[];
  final _onConnectionRestored = <void Function(ConnectivityResultModel)>[];
  final _onQualityChanged =
      <void Function(ConnectionQuality prev, ConnectionQuality next)>[];
  final _onStateChanged = <void Function(ConnectivityState)>[];

  ConnectivityResultModel? _previousResult;

  ConnectivityController({
    required ConnectivityMonitorService monitorService,
    required ConnectivityCache cache,
  })  : _monitorService = monitorService,
        _cache = cache {
    _subject = BehaviorSubject<ConnectivityState>.seeded(
      const ConnectivityChecking(),
    );
  }

  // ── Public stream API ──────────────────────────────────────────────────────

  /// Stream of [ConnectivityState]. Replays latest value to new subscribers.
  Stream<ConnectivityState> get stateStream => _subject.stream;

  /// Convenience stream — only emits on online/offline flips.
  Stream<bool> get isOnlineStream =>
      stateStream.map((s) => s.isOnline).distinct();

  /// Convenience stream — only emits when [ConnectionQuality] tier changes.
  Stream<ConnectionQuality> get qualityStream => stateStream
      .map((s) => s.resultOrNull?.quality ?? ConnectionQuality.none)
      .distinct();

  // ── Synchronous accessors ──────────────────────────────────────────────────

  /// Current state — always available synchronously after initialization.
  ConnectivityState get currentState => _subject.value;

  /// Whether internet is currently available.
  bool get isOnline => currentState.isOnline;

  /// Current result, or null if checking.
  ConnectivityResultModel? get currentResult => currentState.resultOrNull;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Called by [SmartConnectivityMonitor.initialize].
  Future<void> start() async {
    // Emit cached state immediately for instant UI on launch.
    final cached = await _cache.read();
    if (cached != null) {
      _subject.add(ConnectivityLoaded(cached));
    }

    // Wire monitor → state.
    _monitorSub = _monitorService.stream.listen(
      _onResult,
      onError: (Object e) {
        _subject.add(ConnectivityError(e.toString()));
      },
    );

    // Start the monitor engine.
    await _monitorService.start();
  }

  void _onResult(ConnectivityResultModel result) {
    final prev = _previousResult;

    // Persist to cache.
    _cache.write(result);

    // Build new state.
    final state = ConnectivityLoaded(result);
    _subject.add(state);

    // Fire state-change callbacks.
    for (final cb in _onStateChanged) {
        cb(state);
      }

    if (prev != null) {
      // Connection lost.
      if (prev.isOnline && !result.isOnline) {
        for (final cb in _onConnectionLost) {
        cb(result);
      }
      }
      // Connection restored.
      if (!prev.isOnline && result.isOnline) {
        for (final cb in _onConnectionRestored) {
        cb(result);
      }
      }
      // Quality changed.
      if (prev.quality != result.quality) {
        for (final cb in _onQualityChanged) {
        cb(prev.quality, result.quality);
      }
      }
    }

    _previousResult = result;
  }

  // ── Callbacks ──────────────────────────────────────────────────────────────

  /// Register a callback fired when internet access is lost.
  void addConnectionLostListener(
      void Function(ConnectivityResultModel result) callback) {
    _onConnectionLost.add(callback);
  }

  void removeConnectionLostListener(
      void Function(ConnectivityResultModel result) callback) {
    _onConnectionLost.remove(callback);
  }

  /// Register a callback fired when internet access is restored.
  void addConnectionRestoredListener(
      void Function(ConnectivityResultModel result) callback) {
    _onConnectionRestored.add(callback);
  }

  void removeConnectionRestoredListener(
      void Function(ConnectivityResultModel result) callback) {
    _onConnectionRestored.remove(callback);
  }

  /// Register a callback fired when [ConnectionQuality] tier changes.
  void addQualityChangedListener(
      void Function(ConnectionQuality prev, ConnectionQuality next) callback) {
    _onQualityChanged.add(callback);
  }

  void removeQualityChangedListener(
      void Function(ConnectionQuality prev, ConnectionQuality next) callback) {
    _onQualityChanged.remove(callback);
  }

  /// Register a callback fired on every state change.
  void addStateChangedListener(void Function(ConnectivityState state) callback) {
    _onStateChanged.add(callback);
  }

  void removeStateChangedListener(
      void Function(ConnectivityState state) callback) {
    _onStateChanged.remove(callback);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Force an immediate probe outside the normal schedule.
  ///
  /// Result is emitted to [stateStream] and returned directly.
  /// Safe to call at any time (e.g., after a failed API call).
  Future<ConnectivityState> forceCheck() {
    _monitorService.triggerProbe();
    return stateStream
        .where((s) => s is! ConnectivityChecking)
        .first
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => currentState,
        );
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _monitorSub?.cancel();
    await _subject.close();
    await _monitorService.dispose();
    _onConnectionLost.clear();
    _onConnectionRestored.clear();
    _onQualityChanged.clear();
    _onStateChanged.clear();
  }
}
