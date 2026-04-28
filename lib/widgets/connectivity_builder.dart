// lib/widgets/connectivity_builder.dart

import 'package:flutter/widgets.dart';

import '../core/models/connectivity_result_model.dart';
import '../features/connectivity/state/connectivity_state.dart';
import '../src/smart_connectivity_monitor_base.dart';

/// Rebuilds its subtree whenever [ConnectivityState] changes.
///
/// ```dart
/// ConnectivityBuilder(
///   builder: (context, state) {
///     return switch (state) {
///       ConnectivityChecking() => CircularProgressIndicator(),
///       ConnectivityLoaded s when s.isOnline => OnlineContent(),
///       ConnectivityLoaded s => OfflinePlaceholder(),
///       ConnectivityError e => Text('Error: ${e.message}'),
///     };
///   },
/// )
/// ```
class ConnectivityBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ConnectivityState state) builder;

  const ConnectivityBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityState>(
      stream: SmartConnectivityMonitor.instance.stateStream,
      initialData: SmartConnectivityMonitor.instance.currentState,
      builder: (context, snapshot) => builder(context, snapshot.data!),
    );
  }
}

/// Simpler builder — rebuilds only when online/offline flips.
///
/// ```dart
/// OnlineOfflineBuilder(
///   online: (context) => DataScreen(),
///   offline: (context) => OfflineScreen(),
/// )
/// ```
class OnlineOfflineBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) online;
  final Widget Function(BuildContext context) offline;

  const OnlineOfflineBuilder({
    super.key,
    required this.online,
    required this.offline,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SmartConnectivityMonitor.instance.isOnlineStream,
      initialData: SmartConnectivityMonitor.instance.isOnline,
      builder: (context, snapshot) {
        return snapshot.data! ? online(context) : offline(context);
      },
    );
  }
}

/// Quality-aware builder — rebuilds when [ConnectionQuality] tier changes.
///
/// ```dart
/// ConnectionQualityBuilder(
///   builder: (context, quality) {
///     return Text('Signal: ${quality.label}');
///   },
/// )
/// ```
class ConnectionQualityBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ConnectionQuality quality) builder;

  const ConnectionQualityBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionQuality>(
      stream: SmartConnectivityMonitor.instance.qualityStream,
      initialData:
          SmartConnectivityMonitor.instance.currentResult?.quality ??
              ConnectionQuality.none,
      builder: (context, snapshot) =>
          builder(context, snapshot.data!),
    );
  }
}
