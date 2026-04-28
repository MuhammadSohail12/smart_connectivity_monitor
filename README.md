# smart_connectivity_monitor

[![pub package](https://img.shields.io/pub/v/smart_connectivity_monitor.svg)](https://pub.dev/packages/smart_connectivity_monitor)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade Flutter package for **real-time internet connectivity monitoring** with caching, quality detection, and built-in UI widgets.

---

## Why this package?

Most packages just check if a network interface is active. This one **verifies actual internet access** and measures quality.

| Feature | Basic packages | This package |
|---|---|---|
| Detect WiFi / Mobile | ✅ | ✅ |
| Verify real internet access | ❌ | ✅ |
| Detect captive portals | ❌ | ✅ |
| Measure connection quality | ❌ | ✅ |
| Cache last known state | ❌ | ✅ |
| Built-in UI widgets | ❌ | ✅ |
| Global callbacks | ❌ | ✅ |

---

## Installation

```yaml
dependencies:
  smart_connectivity_monitor: ^1.0.0
```

### Android permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS

No additional setup required.

---

## Quick Start

### 1. Initialize once in `main.dart`

```dart
import 'package:smart_connectivity_monitor/smart_connectivity_monitor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SmartConnectivityMonitor.initialize(
    config: const ConnectivityConfig(
      probeInterval: Duration(seconds: 30),
      enableCaching: true,
    ),
  );

  runApp(const MyApp());
}
```

### 2. Use anywhere in the app

```dart
// Synchronous access
SmartConnectivityMonitor.instance.isOnline           // bool
SmartConnectivityMonitor.instance.currentState       // ConnectivityState
SmartConnectivityMonitor.instance.currentResult      // ConnectivityResultModel?

// Reactive streams
SmartConnectivityMonitor.instance.stateStream        // Stream<ConnectivityState>
SmartConnectivityMonitor.instance.isOnlineStream     // Stream<bool>
SmartConnectivityMonitor.instance.qualityStream      // Stream<ConnectionQuality>
```

---

## Connection Quality

Quality is measured from actual probe latency — not guessed from signal bars.

| Quality | Latency |
|---|---|
| `excellent` | < 100ms |
| `good` | 100–200ms |
| `moderate` | 200–600ms |
| `poor` | > 600ms |

Thresholds are configurable via `ConnectivityConfig`.

---

## Global Callbacks

```dart
SmartConnectivityMonitor.instance.addConnectionLostListener((result) {
  // Fires when internet is lost.
  showOfflineUI();
});

SmartConnectivityMonitor.instance.addConnectionRestoredListener((result) {
  // Fires when internet is restored.
  reloadData();
});

SmartConnectivityMonitor.instance.addQualityChangedListener((prev, next) {
  // Fires when quality tier changes (e.g., good → poor).
  if (next.isSlow) showSlowWarning();
});

SmartConnectivityMonitor.instance.addStateChangedListener((state) {
  // Fires on every state change.
});
```

---

## Widgets

### ConnectivityBanner

Slide-in banner that shows automatically when offline or slow.

```dart
// Wrap your entire navigator — covers all routes.
MaterialApp(
  builder: (context, child) => Column(
    children: [
      const ConnectivityBanner(),
      Expanded(child: child!),
    ],
  ),
)

// Or place in a specific screen.
Column(children: [
  const ConnectivityBanner(
    offlineMessage: 'You are offline',
    showRetry: true,
    showForSlowConnection: true,
  ),
  Expanded(child: YourContent()),
])
```

### ConnectivitySnackbar

Auto-snackbar when connectivity changes:

```dart
@override
void initState() {
  super.initState();
  ConnectivitySnackbar.setup(
    context: context,
    offlineMessage: 'No internet connection',
    onlineMessage: 'Back online',
  );
}

@override
void dispose() {
  ConnectivitySnackbar.teardown();
  super.dispose();
}
```

One-off manual snackbar:

```dart
ConnectivitySnackbar.show(
  context: context,
  message: 'Slow connection detected',
  backgroundColor: Colors.orange,
  icon: Icons.speed,
);
```

### ConnectivityBuilder

Reactive builder — rebuilds on every state change:

```dart
ConnectivityBuilder(
  builder: (context, state) => switch (state) {
    ConnectivityChecking() => CircularProgressIndicator(),
    ConnectivityLoaded s when s.isOnline => OnlineScreen(),
    ConnectivityLoaded() => OfflineScreen(),
    ConnectivityError e => Text('Error: ${e.message}'),
  },
)
```

### OnlineOfflineBuilder

Simpler — rebuilds only on online/offline flip:

```dart
OnlineOfflineBuilder(
  online: (context) => DataScreen(),
  offline: (context) => OfflinePlaceholder(),
)
```

### ConnectionQualityBuilder

Rebuilds only when quality tier changes:

```dart
ConnectionQualityBuilder(
  builder: (context, quality) => Text('Signal: ${quality.label}'),
)
```

---

## ConnectivityMixin

Auto-managed lifecycle for StatefulWidgets. No manual subscriptions:

```dart
class _MyScreenState extends State<MyScreen> with ConnectivityMixin {
  @override
  void onConnectionLost(ConnectivityResultModel result) {
    setState(() => _isOffline = true);
  }

  @override
  void onConnectionRestored(ConnectivityResultModel result) {
    setState(() {
      _isOffline = false;
      _reloadData();
    });
  }

  @override
  void onQualityChanged(ConnectionQuality prev, ConnectionQuality next) {
    if (next.isSlow) _showSlowAlert();
  }
}
```

---

## Caching

Last known connectivity state is persisted to SharedPreferences automatically.

On the next app launch, the cached state is emitted immediately while the first probe runs in background — users see meaningful UI instantly.

To disable:

```dart
await SmartConnectivityMonitor.initialize(
  config: const ConnectivityConfig(enableCaching: false),
);
```

---

## Captive Portal Detection

Detected automatically when connected to hotel/airport WiFi requiring login.

```dart
final state = SmartConnectivityMonitor.instance.currentState;
if (state is ConnectivityLoaded && state.isCaptivePortal) {
  showDialog(/* "Open browser to login" prompt */);
}
```

---

## Force Check

Trigger an immediate probe on demand:

```dart
// After a failed API call — check before showing an error.
final state = await SmartConnectivityMonitor.instance.forceCheck();
if (!state.isOnline) {
  showOfflineError();
} else {
  retryApiCall();
}
```

---

## Configuration

```dart
await SmartConnectivityMonitor.initialize(
  config: const ConnectivityConfig(
    probeInterval: Duration(seconds: 30),  // Background check cadence.
    probeTimeout: Duration(seconds: 6),    // Per-probe timeout.
    excellentLatencyMs: 100,               // Latency thresholds.
    goodLatencyMs: 200,
    moderateLatencyMs: 600,
    enableCaching: true,
  ),
);

// Presets:
ConnectivityConfig.strict   // For fintech / high-reliability apps.
ConnectivityConfig.relaxed  // For content apps — saves battery.
```

---

## Testing

Inject mocks via `SmartConnectivityOverrides`:

```dart
await SmartConnectivityMonitor.initialize(
  overrides: SmartConnectivityOverrides(
    networkInterfaceService: MockNetworkInterfaceService(),
    probeService: MockProbeService(),
    cache: const NoOpConnectivityCache(),
  ),
);
```

All internal services are behind interfaces — fully mockable with `mocktail` or `mockito`.

---

## Package Architecture

```
lib/
├── smart_connectivity_monitor.dart      ← Single import for consumers
├── src/
│   └── smart_connectivity_monitor_base.dart  ← Global singleton
├── core/
│   ├── models/
│   │   ├── connectivity_result_model.dart    ← Data object
│   │   └── connectivity_config.dart          ← Configuration
│   ├── services/
│   │   ├── connectivity_monitor_service.dart ← Core engine
│   │   ├── network_interface_service.dart    ← OS interface wrapper
│   │   └── probe_service.dart                ← HTTP probe
│   ├── cache/
│   │   └── connectivity_cache.dart           ← SharedPreferences cache
│   └── utils/
│       ├── quality_classifier.dart           ← Latency → quality
│       └── connectivity_exceptions.dart      ← Typed errors
├── features/
│   └── connectivity/
│       ├── controller/
│       │   └── connectivity_controller.dart  ← State orchestrator
│       └── state/
│           └── connectivity_state.dart       ← Sealed states
└── widgets/
    ├── connectivity_banner.dart              ← Slide-in banner
    ├── connectivity_snackbar.dart            ← Snackbar helper
    ├── connectivity_builder.dart             ← Reactive builders
    └── connectivity_mixin.dart               ← Lifecycle mixin
```

---

## Performance Notes

- Background probes run every 30s (configurable) — one tiny HEAD request, zero body
- OS interface events (WiFi switch, etc.) trigger immediate re-probe
- `BehaviorSubject` — new widget subscribers get current state instantly
- Duplicate results are suppressed — no unnecessary widget rebuilds
- Cache read on startup — no waiting for first probe before showing UI
