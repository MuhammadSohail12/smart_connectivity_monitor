// lib/src/smart_connectivity_monitor_base.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../core/cache/connectivity_cache.dart';
import '../core/models/connectivity_config.dart';
import '../core/models/connectivity_result_model.dart';
import '../core/services/connectivity_monitor_service.dart';
import '../core/services/network_interface_service.dart';
import '../core/services/probe_service.dart';
import '../core/utils/connectivity_exceptions.dart';
import '../features/connectivity/controller/connectivity_controller.dart';
import '../features/connectivity/state/connectivity_state.dart';

/// App-wide singleton entry point.
///
/// ─── Setup (call once in main.dart) ───────────────────────────────────────
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await SmartConnectivityMonitor.initialize();
///   runApp(MyApp());
/// }
/// ```
///
/// ─── Usage anywhere ────────────────────────────────────────────────────────
/// ```dart
/// // Synchronous
/// SmartConnectivityMonitor.instance.isOnline
/// SmartConnectivityMonitor.instance.currentResult
///
/// // Reactive
/// SmartConnectivityMonitor.instance.stateStream
/// SmartConnectivityMonitor.instance.isOnlineStream
/// SmartConnectivityMonitor.instance.qualityStream
///
/// // Force re-check
/// await SmartConnectivityMonitor.instance.forceCheck();
/// ```
class SmartConnectivityMonitor {
  SmartConnectivityMonitor._();

  static SmartConnectivityMonitor? _instance;
  static ConnectivityController? _controller;

  /// Initialized singleton. Throws [NotInitializedException] if not initialized.
  static SmartConnectivityMonitor get instance {
    if (_instance == null) throw const NotInitializedException();
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  /// Initialize the package. Call once in `main()` before `runApp()`.
  ///
  /// - [config]: Tune probe interval, thresholds, and caching behaviour.
  /// - [overrides]: Inject custom implementations for testing.
  ///
  /// Subsequent calls are no-ops and return the existing instance.
  static Future<SmartConnectivityMonitor> initialize({
    ConnectivityConfig config = const ConnectivityConfig(),
    SmartConnectivityOverrides? overrides,
  }) async {
    if (_instance != null) return _instance!;

    final interfaceService = overrides?.networkInterfaceService ??
        ConnectivityPlusNetworkService(connectivity: Connectivity());

    final probeService = overrides?.probeService ??
        HttpProbeService(
          config: config,
          client: http.Client(),
        );

    final cache = overrides?.cache ??
        (config.enableCaching
            ? await SharedPrefsConnectivityCache.create()
            : const NoOpConnectivityCache());

    final monitorService = ConnectivityMonitorService(
      interfaceService: interfaceService,
      probeService: probeService,
      config: config,
    );

    _controller = ConnectivityController(
      monitorService: monitorService,
      cache: cache,
    );

    await _controller!.start();

    _instance = SmartConnectivityMonitor._();
    return _instance!;
  }

  // ── Stream API ─────────────────────────────────────────────────────────────

  /// Full state stream — replays latest to new subscribers immediately.
  Stream<ConnectivityState> get stateStream => _controller!.stateStream;

  /// Emits only when the online/offline boolean flips.
  Stream<bool> get isOnlineStream => _controller!.isOnlineStream;

  /// Emits only when the [ConnectionQuality] tier changes.
  Stream<ConnectionQuality> get qualityStream => _controller!.qualityStream;

  // ── Synchronous accessors ──────────────────────────────────────────────────

  ConnectivityState get currentState => _controller!.currentState;
  bool get isOnline => _controller!.isOnline;
  ConnectivityResultModel? get currentResult => _controller!.currentResult;

  // ── Callbacks ──────────────────────────────────────────────────────────────

  void addConnectionLostListener(
          void Function(ConnectivityResultModel) callback) =>
      _controller!.addConnectionLostListener(callback);

  void removeConnectionLostListener(
          void Function(ConnectivityResultModel) callback) =>
      _controller!.removeConnectionLostListener(callback);

  void addConnectionRestoredListener(
          void Function(ConnectivityResultModel) callback) =>
      _controller!.addConnectionRestoredListener(callback);

  void removeConnectionRestoredListener(
          void Function(ConnectivityResultModel) callback) =>
      _controller!.removeConnectionRestoredListener(callback);

  void addQualityChangedListener(
          void Function(ConnectionQuality prev, ConnectionQuality next)
              callback) =>
      _controller!.addQualityChangedListener(callback);

  void removeQualityChangedListener(
          void Function(ConnectionQuality prev, ConnectionQuality next)
              callback) =>
      _controller!.removeQualityChangedListener(callback);

  void addStateChangedListener(void Function(ConnectivityState) callback) =>
      _controller!.addStateChangedListener(callback);

  void removeStateChangedListener(void Function(ConnectivityState) callback) =>
      _controller!.removeStateChangedListener(callback);

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Trigger an immediate probe. Returns the resulting state.
  Future<ConnectivityState> forceCheck() => _controller!.forceCheck();

  // ── Dispose ────────────────────────────────────────────────────────────────

  /// Release all resources. Resets singleton — safe to re-initialize after.
  /// Useful in tests. Rarely needed in production.
  static Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _instance = null;
  }
}

/// Dependency injection bag for testing.
/// All fields are optional — only override what your test needs.
class SmartConnectivityOverrides {
  final NetworkInterfaceService? networkInterfaceService;
  final ProbeService? probeService;
  final ConnectivityCache? cache;

  const SmartConnectivityOverrides({
    this.networkInterfaceService,
    this.probeService,
    this.cache,
  });
}
