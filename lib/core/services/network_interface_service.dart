// lib/core/services/network_interface_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/connectivity_result_model.dart';

/// Wraps connectivity_plus behind a clean interface we control.
///
/// This isolation means:
/// 1. Tests mock this, never connectivity_plus directly.
/// 2. If connectivity_plus changes its API, only this file changes.
abstract interface class NetworkInterfaceService {
  Stream<NetworkType> get interfaceStream;
  Future<NetworkType> getCurrentType();
  void dispose();
}

class ConnectivityPlusNetworkService implements NetworkInterfaceService {
  final Connectivity _connectivity;

  ConnectivityPlusNetworkService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @override
  Stream<NetworkType> get interfaceStream =>
      _connectivity.onConnectivityChanged.map(_toNetworkType);

  @override
  Future<NetworkType> getCurrentType() async =>
      _toNetworkType(await _connectivity.checkConnectivity());

  NetworkType _toNetworkType(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.ethernet;
    }
    if (results.contains(ConnectivityResult.wifi)) return NetworkType.wifi;
    if (results.contains(ConnectivityResult.mobile)) return NetworkType.mobile;
    return NetworkType.none;
  }

  @override
  void dispose() {
    // connectivity_plus Connectivity instance has no explicit dispose.
  }
}
