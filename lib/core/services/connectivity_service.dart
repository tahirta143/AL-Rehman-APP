import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  
  // ValueNotifier for UI to listen to
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  bool _manualOffline = false;
  bool get isManualOffline => _manualOffline;
  
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _init();
  }

  Future<void> _init() async {
    // Check initial status
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  void toggleManualOffline() {
    _manualOffline = !_manualOffline;
    debugPrint('🛠️ Manual Offline Override: ${_manualOffline ? "ON" : "OFF"}');
    _refreshStatus();
  }

  void _refreshStatus() async {
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool hardwareOnline = results.any((result) => result != ConnectivityResult.none);
    bool online = !_manualOffline && hardwareOnline;
    
    if (isOnline.value != online) {
      isOnline.value = online;
      debugPrint('🌐 Connectivity Status: ${online ? "ONLINE" : "OFFLINE"} (Manual: $_manualOffline, HW: $hardwareOnline)');
    }
  }

  // Helper method to check once
  Future<bool> checkOnline() async {
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
