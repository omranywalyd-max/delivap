import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/main_page.dart';

class UserNotificationHelper {
  static final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init(String userId) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      // طلب إذن الإشعارات من النظام لأندرويد 13+
      final androidPlugin = _localPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient.put('/api/users/$userId', {
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
        });
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        try {
          await ApiClient.put('/api/users/$userId', {
            'fcmToken': newToken,
            'lastTokenUpdate': DateTime.now().toIso8601String(),
          });
        } catch (e) {
        }
      });

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      await _localPlugin.initialize(
        settings: InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) _navigateToOrders();
        },
      );

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _navigateToOrders();
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _navigateToOrders();
      }
    } catch (e) {
    }
  }

  static void _navigateToOrders() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
      (route) => false,
    );
  }

  static void _showBanner(RemoteMessage message) {
    final data = message.data;
    final payload = data.isNotEmpty ? '${data['orderType'] ?? ''}|${data['orderId'] ?? ''}' : null;
    final soundName = data['sound'] as String?;
    final channelId = soundName != null ? 'user_channel_$soundName' : 'user_channel';
    final channelName = soundName != null ? 'تنبيهات $soundName' : 'تنبيهات الزبون';

    _localPlugin.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          vibrationPattern: Int64List.fromList([0, 2000]),
          sound: (soundName != null && soundName == 'okhrej') ? const RawResourceAndroidNotificationSound('okhrej') : null,
        ),
      ),
    );
  }
}
