## 1.0.0

Initial production release.

### Features
- Real-time internet connectivity monitoring (WiFi, mobile, ethernet)
- Actual internet reachability verification — not just interface detection
- Captive portal detection (hotel/airport WiFi login walls)
- Connection quality classification: excellent / good / moderate / poor
- Slow connection detection based on measured latency
- Persistent caching of last known connectivity state via SharedPreferences
- App-wide singleton initialization — initialize once, use everywhere
- `ConnectivityController` with reactive stream and synchronous access
- `ConnectivityMixin` for lifecycle-safe StatefulWidget integration
- Global callbacks: `onConnectionLost`, `onConnectionRestored`, `onQualityChanged`
- Built-in `ConnectivityBanner` widget — animated slide-in/out
- Built-in `ConnectivitySnackbar` helper — one-line snackbar
- Built-in `ConnectivityBuilder` — reactive widget rebuilder
- Connectivity-aware retry queue with exponential backoff
- Session analytics: uptime ratio, drop count, average latency
- Full dependency injection support for testing
