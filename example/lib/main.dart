// example/lib/main.dart
//
// Full demo app showing every major feature of smart_connectivity_monitor.

import 'package:flutter/material.dart';
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1: Initialize once in main() before runApp().
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SmartConnectivityMonitor.initialize(
    // Optional: use ConnectivityConfig.strict for fintech apps.
    config: const ConnectivityConfig(
      probeInterval: Duration(seconds: 30),
      enableCaching: true,       // Restore last state on launch.
    ),
  );

  // Global callbacks — fire regardless of which screen is active.
  SmartConnectivityMonitor.instance.addConnectionLostListener((_) {
    debugPrint('[SCM] ⚠ Connection lost');
  });

  SmartConnectivityMonitor.instance.addConnectionRestoredListener((result) {
    debugPrint('[SCM] ✓ Connection restored — ${result.quality.label}');
  });

  SmartConnectivityMonitor.instance.addQualityChangedListener((prev, next) {
    debugPrint('[SCM] Quality: ${prev.label} → ${next.label}');
  });

  runApp(const DemoApp());
}

// ─────────────────────────────────────────────────────────────────────────────
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCM Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8),
          brightness: Brightness.dark,
        ),
      ),
      // Wrap the entire navigator with ConnectivityBanner.
      // This shows/hides automatically — you don't manage it.
      builder: (context, child) => Column(
        children: [
          const ConnectivityBanner(showForSlowConnection: true),
          Expanded(child: child!),
        ],
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2: Use ConnectivityMixin for auto-managed lifecycle in StatefulWidgets.
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ConnectivityMixin {
  String _retryQueueResult = '—';

  // ConnectivityMixin hooks — auto-subscribed, auto-cancelled on dispose.
  @override
  void onConnectionLost(ConnectivityResultModel result) {
    // No manual subscription management needed.
    debugPrint('Screen: connection lost');
  }

  @override
  void onConnectionRestored(ConnectivityResultModel result) {
    setState(() {}); // Trigger rebuild on restore.
  }

  @override
  void onQualityChanged(ConnectionQuality prev, ConnectionQuality next) {
    if (next.isSlow && mounted) {
      ConnectivitySnackbar.show(
        context: context,
        message: 'Connection slowed to ${next.label}',
        backgroundColor: Colors.orange.shade700,
        icon: Icons.speed,
      );
    }
  }

  Future<void> _runQueuedRequest() async {
    setState(() => _retryQueueResult = 'Queued…');
    // Simulate an API call via the retry queue.
    // If offline, this parks here and fires when back online.
    try {
      // NOTE: ConnectivityController.retryQueue is accessible if you need it.
      // For this example we simulate with a delayed Future.
      await Future<void>.delayed(const Duration(seconds: 1));
      final status = await SmartConnectivityMonitor.instance.forceCheck();
      setState(() => _retryQueueResult =
          status.isOnline ? 'API success ✅' : 'Offline — queued ⏸');
    } catch (e) {
      setState(() => _retryQueueResult = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Connectivity Monitor'),
        actions: const [_QualityBadge()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live status card (ConnectivityBuilder) ──────────────────────
          const _StatusCard(),
          const SizedBox(height: 16),

          // ── Analytics card (StreamBuilder on analyticsStream) ──────────
          const _AnalyticsSection(),
          const SizedBox(height: 16),

          // ── Retry queue demo ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Force Check / Retry',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Go offline, press the button — it will retry when back online.',
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Text('Result: $_retryQueueResult'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _runQueuedRequest,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Run Request'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── OnlineOfflineBuilder example ────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OnlineOfflineBuilder',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  OnlineOfflineBuilder(
                    online: (context) => const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Online — full features available'),
                      ],
                    ),
                    offline: (context) => const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Offline — limited mode active'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── ConnectionQualityBuilder example ───────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quality-Aware UI',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ConnectionQualityBuilder(
                    builder: (context, quality) => _QualityBar(quality: quality),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3: Use ConnectivityBuilder for reactive UI.
// ─────────────────────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return ConnectivityBuilder(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: switch (state) {
              ConnectivityChecking() => const Row(
                  children: [
                    SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Checking connectivity…'),
                  ],
                ),
              ConnectivityLoaded s => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Status',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _row('Online', s.isOnline ? '✅ Yes' : '❌ No'),
                    _row('Type', s.networkType.name.toUpperCase()),
                    _row('Quality', s.quality.label),
                    _row('Captive Portal', s.isCaptivePortal ? '⚠ Yes' : 'No'),
                    if (s.latencyMs != null)
                      _row('Latency', '${s.latencyMs}ms'),
                    if (s.isSlowConnection)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text('Slow connection',
                                style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                  ],
                ),
              ConnectivityError e => Text('Error: ${e.message}',
                  style: const TextStyle(color: Colors.red)),
            },
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection();

  @override
  Widget build(BuildContext context) {
    // Directly read synchronous state for one-off display.
    final result = SmartConnectivityMonitor.instance.currentResult;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last Known State',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (result != null) ...[
              Text('Network: ${result.networkType.name}'),
              Text('Quality: ${result.quality.label}'),
              if (result.latencyMs != null)
                Text('Latency: ${result.latencyMs}ms'),
              Text('Timestamp: ${result.timestamp.toLocal()}'),
            ] else
              const Text('No data yet'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QualityBadge extends StatelessWidget {
  const _QualityBadge();

  @override
  Widget build(BuildContext context) {
    return ConnectionQualityBuilder(
      builder: (context, quality) {
        if (quality == ConnectionQuality.none) return const SizedBox.shrink();

        final color = switch (quality) {
          ConnectionQuality.excellent => Colors.green,
          ConnectionQuality.good => Colors.lightGreen,
          ConnectionQuality.moderate => Colors.orange,
          ConnectionQuality.poor => Colors.red,
          ConnectionQuality.none => Colors.grey,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quality.label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QualityBar extends StatelessWidget {
  final ConnectionQuality quality;
  const _QualityBar({required this.quality});

  @override
  Widget build(BuildContext context) {
    const levels = ConnectionQuality.values;
    final qualityIndex = levels.indexOf(quality);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signal: ${quality.label}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: levels.skip(1).map((level) {
            final idx = levels.indexOf(level);
            final active = qualityIndex >= idx;
            final color = switch (level) {
              ConnectionQuality.poor => Colors.red,
              ConnectionQuality.moderate => Colors.orange,
              ConnectionQuality.good => Colors.lightGreen,
              ConnectionQuality.excellent => Colors.green,
              ConnectionQuality.none => Colors.grey,
            };

            return Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: active ? color : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
