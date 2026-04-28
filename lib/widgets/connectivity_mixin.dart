// lib/widgets/connectivity_mixin.dart

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/models/connectivity_result_model.dart';
import '../features/connectivity/state/connectivity_state.dart';
import '../src/smart_connectivity_monitor_base.dart';

/// Add this mixin to any [State] class to get auto-managed connectivity hooks.
///
/// Subscribes on [initState] and cancels on [dispose] — zero boilerplate.
/// Override only the hooks you need.
///
/// ```dart
/// class _HomeScreenState extends State<HomeScreen> with ConnectivityMixin {
///   @override
///   void onConnectionLost(ConnectivityResultModel result) {
///     setState(() => _isOffline = true);
///   }
///
///   @override
///   void onConnectionRestored(ConnectivityResultModel result) {
///     setState(() {
///       _isOffline = false;
///       _reloadData();
///     });
///   }
///
///   @override
///   void onQualityChanged(ConnectionQuality prev, ConnectionQuality next) {
///     if (next.isSlow) _showSlowWarning();
///   }
/// }
/// ```
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<ConnectivityState>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _connectivitySub = SmartConnectivityMonitor.instance.stateStream.listen(
      _handleState,
    );
  }

  ConnectivityResultModel? _prevResult;

  void _handleState(ConnectivityState state) {
    onConnectivityStateChanged(state);

    if (state is ConnectivityLoaded) {
      final prev = _prevResult;

      if (prev != null) {
        if (prev.isOnline && !state.result.isOnline) {
          onConnectionLost(state.result);
        }
        if (!prev.isOnline && state.result.isOnline) {
          onConnectionRestored(state.result);
        }
        if (prev.quality != state.result.quality) {
          onQualityChanged(prev.quality, state.result.quality);
        }
      }

      _prevResult = state.result;
    }
  }

  /// Called on every connectivity state change.
  void onConnectivityStateChanged(ConnectivityState state) {}

  /// Called when internet access is lost.
  void onConnectionLost(ConnectivityResultModel result) {}

  /// Called when internet access is restored.
  void onConnectionRestored(ConnectivityResultModel result) {}

  /// Called when [ConnectionQuality] tier changes.
  void onQualityChanged(ConnectionQuality prev, ConnectionQuality next) {}

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
