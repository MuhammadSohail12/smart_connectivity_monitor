// lib/features/connectivity/state/connectivity_state.dart

import '../../../core/models/connectivity_result_model.dart';

/// Sealed state hierarchy for the connectivity feature.
///
/// Using sealed classes gives us exhaustive pattern matching at compile time.
/// No more missed cases in switch statements.
sealed class ConnectivityState {
  const ConnectivityState();
}

/// First state — emitted immediately before the first probe completes.
/// UI should show a neutral/loading indicator.
final class ConnectivityChecking extends ConnectivityState {
  const ConnectivityChecking();
}

/// First probe (or cache read) returned a result.
/// This is the steady state — all subsequent emissions are this type.
final class ConnectivityLoaded extends ConnectivityState {
  final ConnectivityResultModel result;
  const ConnectivityLoaded(this.result);

  bool get isOnline => result.isOnline;
  bool get isSlowConnection => result.isSlowConnection;
  bool get isCaptivePortal => result.isCaptivePortal;
  NetworkType get networkType => result.networkType;
  ConnectionQuality get quality => result.quality;
  int? get latencyMs => result.latencyMs;
}

/// Something went wrong at the service level (not network — service crash).
final class ConnectivityError extends ConnectivityState {
  final String message;
  const ConnectivityError(this.message);
}

extension ConnectivityStateX on ConnectivityState {
  /// Whether the current state represents an active internet connection.
  bool get isOnline {
    final self = this;
    if (self is ConnectivityLoaded) return self.isOnline;
    return false;
  }

  /// Safe accessor — returns null when not in [ConnectivityLoaded] state.
  ConnectivityResultModel? get resultOrNull {
    final self = this;
    if (self is ConnectivityLoaded) return self.result;
    return null;
  }
}
