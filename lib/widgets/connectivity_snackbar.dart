// lib/widgets/connectivity_snackbar.dart

import 'package:flutter/material.dart';

import '../core/models/connectivity_result_model.dart';
import '../src/smart_connectivity_monitor_base.dart';

/// Helper class for showing connectivity-related SnackBars.
///
/// Call [ConnectivitySnackbar.setup] once in your app (in a StatefulWidget's
/// initState or in a top-level widget that has a valid [BuildContext]).
///
/// It auto-listens to [SmartConnectivityMonitor] and shows snackbars on changes.
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   ConnectivitySnackbar.setup(context: context);
/// }
///
/// @override
/// void dispose() {
///   ConnectivitySnackbar.teardown();
///   super.dispose();
/// }
/// ```
abstract final class ConnectivitySnackbar {
  static void Function(ConnectivityResultModel)? _lostHandler;
  static void Function(ConnectivityResultModel)? _restoredHandler;

  /// Wire up automatic snackbars.
  ///
  /// - [context]: Must be valid throughout the app session.
  /// - [offlineMessage]: Shown when connection is lost.
  /// - [onlineMessage]: Shown when connection is restored.
  /// - [slowMessage]: Shown when connection is slow (optional).
  static void setup({
    required BuildContext context,
    String offlineMessage = 'No internet connection',
    String onlineMessage = 'Back online',
    String? slowMessage,
    Duration duration = const Duration(seconds: 3),
  }) {
    void showSnack(String message, Color color, IconData icon) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            duration: duration,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    }

    _lostHandler = (_) {
      showSnack(offlineMessage, Colors.red.shade700, Icons.wifi_off);
    };

    _restoredHandler = (result) {
      final msg = result.isSlowConnection
          ? (slowMessage ?? '$onlineMessage (slow)')
          : onlineMessage;
      showSnack(msg, Colors.green.shade700, Icons.wifi);
    };

    SmartConnectivityMonitor.instance
        .addConnectionLostListener(_lostHandler!);
    SmartConnectivityMonitor.instance
        .addConnectionRestoredListener(_restoredHandler!);
  }

  /// Remove listeners set up by [setup]. Call in dispose().
  static void teardown() {
    if (_lostHandler != null) {
      SmartConnectivityMonitor.instance
          .removeConnectionLostListener(_lostHandler!);
      _lostHandler = null;
    }
    if (_restoredHandler != null) {
      SmartConnectivityMonitor.instance
          .removeConnectionRestoredListener(_restoredHandler!);
      _restoredHandler = null;
    }
  }

  /// Show a one-off connectivity snackbar manually.
  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.black87,
    IconData icon = Icons.info_outline,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
  }
}
