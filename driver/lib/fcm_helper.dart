import 'package:flutter/foundation.dart';
import 'package:dashbord/services/api_client.dart';

class FCMHelper {
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await ApiClient.post('/api/notify-user', {
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('FCM Error: $e');
    }
  }

  static Future<void> sendToDriver({
    required String driverId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await ApiClient.post('/api/notify-driver', {
        'driverId': driverId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('FCM Driver Error: $e');
    }
  }

  static Future<void> sendToToken({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await ApiClient.post('/api/notify-token', {
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (e) {
      debugPrint('FCM Token Error: $e');
    }
  }
}
