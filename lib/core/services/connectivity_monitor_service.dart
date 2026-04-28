// lib/core/services/connectivity_monitor_service.dart

import 'dart:async';
import 'dart:collection';

import '../models/connectivity_config.dart';
import '../models/connectivity_result_model.dart';
import '../utils/connectivity_exceptions.dart';
import '../utils/quality_classifier.dart';
import 'network_interface_service.dart';
import 'probe_service.dart';

/// Core monitoring engine.
///
/// Responsibilities:
///   1. Subscribe to OS interface changes (fast, native callback).
///   2. On interface change OR periodic tick — run [ProbeService.probe].
///   3. Derive [ConnectivityResultModel] from probe result.
///   4. Detect instability via rolling drop window.
///   5. Emit deduplicated results on [stream].
///   6. Expose [triggerProbe] for on-demand checks.
///
/// This class has NO Flutter dependency — pure Dart.
class ConnectivityMonitorService {
  final NetworkInterfaceService _interfaceService;
  final ProbeService _probeService;
  final ConnectivityConfig _config;

  // Rolling window for instability detection.
  final Queue<DateTime> _dropTimestamps = Queue<DateTime>();

  final _triggerController = StreamController<void>.broadcast();
  final _resultController =
      StreamController<ConnectivityResultModel>.broadcast();

  Timer? _periodicTimer;
  StreamSubscription<NetworkType>? _interfaceSub;
  StreamSubscription<void>? _triggerSub;

  ConnectivityResultModel _last = ConnectivityResultModel.unknown;

  ConnectivityMonitorService({
    required NetworkInterfaceService interfaceService,
    required ProbeService probeService,
    required ConnectivityConfig config,
  })  : _interfaceService = interfaceService,
        _probeService = probeService,
        _config = config;

  /// Deduplicated stream of connectivity results.
  Stream<ConnectivityResultModel> get stream => _resultController.stream;

  /// Most recent result — synchronous access.
  ConnectivityResultModel get current => _last;

  /// Trigger an immediate probe outside the normal schedule.
  void triggerProbe() {
    if (!_triggerController.isClosed) _triggerController.add(null);
  }

  /// Start monitoring. Called once by the top-level initializer.
  Future<void> start() async {
    // Listen to OS interface events.
    _interfaceSub =
        _interfaceService.interfaceStream.listen((_) => _runProbe());

    // Periodic background probe catches latency drift and silent drops.
    _periodicTimer = Timer.periodic(_config.probeInterval, (_) => _runProbe());

    // Manual trigger channel.
    _triggerSub = _triggerController.stream.listen((_) => _runProbe());

    // Run first probe immediately so callers don't wait for the first interval.
    await _runProbe();
  }

  Future<void> _runProbe() async {
    final type = await _interfaceService.getCurrentType();

    // Fast-path: no interface → skip network round-trip entirely.
    if (type == NetworkType.none) {
      _emit(ConnectivityResultModel(
        isOnline: false,
        networkType: NetworkType.none,
        quality: ConnectionQuality.none,
        isCaptivePortal: false,
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final latencyMs = await _probeService.probe();
      final quality = QualityClassifier.classify(latencyMs, _config);

      _emit(ConnectivityResultModel(
        isOnline: true,
        networkType: type,
        quality: _applyInstability(quality),
        isCaptivePortal: false,
        latencyMs: latencyMs,
        timestamp: DateTime.now(),
      ));
    } on CaptivePortalException {
      _emit(ConnectivityResultModel(
        isOnline: false,
        networkType: type,
        quality: ConnectionQuality.none,
        isCaptivePortal: true,
        timestamp: DateTime.now(),
      ));
    } catch (_) {
      _emit(ConnectivityResultModel(
        isOnline: false,
        networkType: type,
        quality: ConnectionQuality.none,
        isCaptivePortal: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _emit(ConnectivityResultModel result) {
    // Track online→offline drops for instability detection.
    if (_last.isOnline && !result.isOnline) {
      _dropTimestamps.addLast(DateTime.now());
    }

    // Evict timestamps outside the detection window.
    final cutoff = DateTime.now().subtract(_config.instabilityWindow);
    while (_dropTimestamps.isNotEmpty &&
        _dropTimestamps.first.isBefore(cutoff)) {
      _dropTimestamps.removeFirst();
    }

    _last = result;

    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  /// Degrade quality to poor if connection is historically unstable.
  ConnectionQuality _applyInstability(ConnectionQuality quality) {
    if (_dropTimestamps.length >= _config.instabilityDropThreshold) {
      return ConnectionQuality.poor;
    }
    return quality;
  }

  Future<void> dispose() async {
    _periodicTimer?.cancel();
    await _interfaceSub?.cancel();
    await _triggerSub?.cancel();
    await _triggerController.close();
    await _resultController.close();
    _probeService.dispose();
    _interfaceService.dispose();
  }
}
