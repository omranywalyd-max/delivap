import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_local.dart';

class DriverArrivalOverlay {
  static Timer? _showTimer;
  static const _channel = MethodChannel('com.deliv.customer/ringtone');

  static Future<bool> checkPermission() async {
    try {
      return await _channel.invokeMethod('checkOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static void trigger({
    required BuildContext context,
    String? driverName,
    String? driverPhoto,
    String? orderId,
  }) {
    cancelPending();
    log('DriverArrivalOverlay: trigger called, isEnabled=$isEnabled, will launch in 10s');

    _showTimer = Timer(const Duration(seconds: 10), () async {
      try {
        log('DriverArrivalOverlay: launching arrival screen...');
        await _channel.invokeMethod('launchArrivalScreen', {
          'driverName': driverName ?? 'السائق',
          'driverPhoto': driverPhoto ?? '',
        });
        log('DriverArrivalOverlay: success');
      } catch (_) {}
    });
  }

  static bool get isEnabled {
    final data = UserLocal.data;
    if (data != null && data['settings'] is Map) {
      final s = data['settings'] as Map;
      return s['enableDriverArrivalRing'] == true;
    }
    return false;
  }

  static void cancelPending() {
    _showTimer?.cancel();
    _showTimer = null;
  }
}
