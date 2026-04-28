// lib/core/utils/connectivity_exceptions.dart

/// Base for all package-specific exceptions.
sealed class ConnectivityException implements Exception {
  final String message;
  const ConnectivityException(this.message);
  @override
  String toString() => '$runtimeType: $message';
}

/// Internet probe timed out.
final class ProbeTimeoutException extends ConnectivityException {
  const ProbeTimeoutException()
      : super('Internet probe timed out — connection too slow or unreachable');
}

/// Both primary and fallback probe endpoints failed.
final class ProbeFailedException extends ConnectivityException {
  final Object? cause;
  const ProbeFailedException(super.message, {this.cause});
}

/// Probe succeeded but response indicates a captive portal redirect.
final class CaptivePortalException extends ConnectivityException {
  const CaptivePortalException()
      : super('Captive portal detected — login required to access internet');
}

/// Service was used before [SmartConnectivityMonitor.initialize] was called.
final class NotInitializedException extends ConnectivityException {
  const NotInitializedException()
      : super(
            'SmartConnectivityMonitor is not initialized. '
            'Call SmartConnectivityMonitor.initialize() in main() first.');
}
