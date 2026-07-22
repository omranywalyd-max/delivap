import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_local.dart';

class DriverArrivalOverlay {
  static Timer? _showTimer;
  static const _channel = MethodChannel('com.deliv.customer/ringtone');

  static void trigger({
    required BuildContext context,
    String? driverName,
    String? driverPhoto,
    String? orderId,
  }) {
    cancelPending();

    _showTimer = Timer(const Duration(seconds: 10), () async {
      try {
        await _channel.invokeMethod('launchArrivalScreen', {
          'driverName': driverName ?? 'السائق',
          'driverPhoto': driverPhoto ?? '',
        });
      } catch (_) { /* ignored */ }
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

  static Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod('checkOverlayPermission');
      return result == true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) { /* ignored */ }
  }

  static void cancelPending() {
    _showTimer?.cancel();
    _showTimer = null;
  }
}
