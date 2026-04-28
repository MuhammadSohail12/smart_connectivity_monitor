// lib/widgets/connectivity_banner.dart

import 'package:flutter/material.dart';

import '../features/connectivity/state/connectivity_state.dart';
import '../src/smart_connectivity_monitor_base.dart';

/// Animated slide-in banner shown when connectivity is lost or degraded.
///
/// Place at the top of your widget tree (inside Column, not as AppBar):
///
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       ConnectivityBanner(),           // ← add this
///       Expanded(child: YourContent()),
///     ],
///   ),
/// )
/// ```
///
/// Or wrap your entire navigator:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => Column(
///     children: [ConnectivityBanner(), Expanded(child: child!)],
///   ),
/// )
/// ```
class ConnectivityBanner extends StatefulWidget {
  /// Override the offline message.
  final String? offlineMessage;

  /// Override the slow connection message.
  final String? slowMessage;

  /// Override the captive portal message.
  final String? captivePortalMessage;

  /// Offline banner background color. Defaults to deep red.
  final Color? offlineColor;

  /// Slow connection banner background color. Defaults to orange.
  final Color? slowColor;

  /// Text/icon color. Defaults to white.
  final Color? foregroundColor;

  /// Whether to show a Retry button.
  final bool showRetry;

  /// Callback when Retry is tapped.
  final VoidCallback? onRetry;

  /// Whether to show the banner for slow connections too (not just offline).
  final bool showForSlowConnection;

  const ConnectivityBanner({
    super.key,
    this.offlineMessage,
    this.slowMessage,
    this.captivePortalMessage,
    this.offlineColor,
    this.slowColor,
    this.foregroundColor,
    this.showRetry = true,
    this.onRetry,
    this.showForSlowConnection = true,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _updateVisibility(bool shouldShow) {
    if (shouldShow == _visible) return;
    _visible = shouldShow;
    if (shouldShow) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityState>(
      stream: SmartConnectivityMonitor.instance.stateStream,
      initialData: SmartConnectivityMonitor.instance.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data!;
        final result = state.resultOrNull;

        final shouldShow = switch (state) {
          ConnectivityLoaded s =>
            !s.isOnline ||
                (widget.showForSlowConnection && s.isSlowConnection),
          ConnectivityChecking() => false,
          ConnectivityError() => false,
        };

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateVisibility(shouldShow);
        });

        if (!shouldShow && !_animCtrl.isAnimating && _animCtrl.value == 0) {
          return const SizedBox.shrink();
        }

        final isCaptive = result?.isCaptivePortal ?? false;
        final isSlow =
            (result?.isSlowConnection ?? false) && (result?.isOnline ?? false);

        final bgColor = isSlow
            ? (widget.slowColor ?? Colors.orange.shade700)
            : (widget.offlineColor ?? Colors.red.shade800);

        final message = isCaptive
            ? (widget.captivePortalMessage ??
                'WiFi connected — login required')
            : isSlow
                ? (widget.slowMessage ?? 'Slow connection detected')
                : (widget.offlineMessage ?? 'No internet connection');

        final icon = isCaptive
            ? Icons.wifi_lock
            : isSlow
                ? Icons.signal_cellular_connected_no_internet_4_bar
                : Icons.wifi_off;

        final fg = widget.foregroundColor ?? Colors.white;

        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Material(
              color: bgColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(icon, color: fg, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message,
                              style: TextStyle(
                                color: fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (result?.latencyMs != null && isSlow)
                              Text(
                                '${result!.latencyMs}ms latency',
                                style: TextStyle(
                                  color: fg.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.showRetry && !isSlow)
                        TextButton(
                          onPressed: widget.onRetry ??
                              () =>
                                  SmartConnectivityMonitor.instance.forceCheck(),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: fg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
