import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'Services/api_client.dart';
import 'Services/delivery_screen.dart';
import 'Sign Up/Sign_Up.dart';
import 'main_page.dart';
import 'user_local.dart';
import 'theme.dart';
import 'Order/active_orders_screen.dart';
import 'driver_arrival_overlay.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // ring: MyFirebaseMessagingService ?????? ???? ?? ??????? ??? fullScreenIntent
  if (message.data['sound'] == 'ring') return;

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;
  final soundName = message.data['sound'] as String?;
  final channelId = soundName != null ? 'user_channel_$soundName' : 'user_channel';
  final channelName = soundName != null ? '??????? $soundName' : '??????? ????????';
  flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '??????? ??????? ????????',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        sound: soundName != null ? RawResourceAndroidNotificationSound(soundName) : null,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  Firebase.initializeApp().then((_) => _initDeferredServices());
}

Future<void> _initDeferredServices() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );
  flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!);
          _handleNotificationNavigation(data);
        } catch (_) { /* ignored */ }
      }
    },
  );

  // ????? ????? ??????? ????? ?? ??????? ?????
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'user_channel',
        '??????? ????????',
        description: '??????? ??????? ????????',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'user_channel_okhrej',
        '????? ???? ??????',
        description: '????? ??? ???? ??????',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('okhrej'),
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'user_channel_ring',
        '???? ??????',
        description: '???? ?????? ?? ??????',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('okhrej'),
      ),
    );
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final sound = message.data['sound'];
    if (sound == 'ring') {
      if (!DriverArrivalOverlay.isEnabled) return;
      void attempt(int retries) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          DriverArrivalOverlay.trigger(
            context: ctx,
            driverName: message.data['driverName'] as String?,
            driverPhoto: message.data['driverPhoto'] as String?,
            orderId: message.data['orderId'] as String?,
          );
        } else if (retries > 0) {
          Future.delayed(const Duration(milliseconds: 800), () => attempt(retries - 1));
        }
      }
      attempt(5);
    } else {
      _showLocalNotification(message);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);

    final sound = message.data['sound'];
    if (sound == 'ring') {
      if (!DriverArrivalOverlay.isEnabled) return;
      void attempt(int retries) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          DriverArrivalOverlay.trigger(
            context: ctx,
            driverName: message.data['driverName'] as String?,
            driverPhoto: message.data['driverPhoto'] as String?,
            orderId: message.data['orderId'] as String?,
          );
        } else if (retries > 0) {
          Future.delayed(const Duration(milliseconds: 800), () => attempt(retries - 1));
        }
      }
      attempt(5);
    }
  });

  messaging.getInitialMessage().then((initialMessage) {
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationNavigation(initialMessage.data);

        final sound = initialMessage.data['sound'];
        if (sound == 'ring') {
          if (!DriverArrivalOverlay.isEnabled) return;
          void attempt(int retries) {
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              DriverArrivalOverlay.trigger(
                context: ctx,
                driverName: initialMessage.data['driverName'] as String?,
                driverPhoto: initialMessage.data['driverPhoto'] as String?,
                orderId: initialMessage.data['orderId'] as String?,
              );
            } else if (retries > 0) {
              Future.delayed(const Duration(milliseconds: 800), () => attempt(retries - 1));
            }
          }
          attempt(5);
        }
      });
    }
  }).catchError((_) {});

  messaging.getToken().then((fcmToken) async {
    if (fcmToken == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ApiClient.put('/api/users/${user.uid}', {'fcmToken': fcmToken}).catchError((_) {});
      UserLocal.load(user.uid).catchError((_) {});
      try {
        final idToken = await user.getIdToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fb_id_token', idToken!);
      } catch (_) { /* ignored */ }
    }
  }).catchError((_) {});

  messaging.onTokenRefresh.listen((String newToken) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      ApiClient.put('/api/users/${u.uid}', {'fcmToken': newToken}).catchError((_) {});
      try {
        final idToken = await u.getIdToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fb_id_token', idToken!);
      } catch (_) { /* ignored */ }
    }
  });

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove('fb_id_token');
      } else {
        final idToken = await user.getIdToken();
        await prefs.setString('fb_id_token', idToken!);
      }
    } catch (_) { /* ignored */ }
  });
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;
  final soundName = message.data['sound'] as String?;
  final channelId = soundName != null ? 'user_channel_$soundName' : 'user_channel';
  final channelName = soundName != null ? '??????? $soundName' : '??????? ????????';

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: '??????? ??????? ????????',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    sound: soundName != null ? RawResourceAndroidNotificationSound(soundName) : null,
  );

  final details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: details,
    payload: jsonEncode(message.data),
  );
}

void _handleNotificationNavigation(Map<String, dynamic> data) {
  final String? type = data['type']?.toString();
  final String? orderId = data['orderId']?.toString();
  switch (type) {
    case 'order_update':
    case 'order_accepted':
    case 'order_rejected':
    case 'order_delivered':
    case 'accepted':
    case 'onway':
    case 'delivered':
    case 'counter_offer':
    case 'driver_rejected':
    case 'service_accepted':
    case 'service_onway':
    case 'service_delivered':
    case 'alternative_pending':
    case 'alternative_accepted':
    case 'alternative_rejected':
      navigatorKey.currentState?.pushNamed('/orders');
      break;
    case 'driver_location':
    case 'driver_arrived':
      if (orderId != null && orderId.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => DriverTrackingScreen(orderId: orderId),
          ),
        );
      } else {
        navigatorKey.currentState?.pushNamed('/orders');
      }
      break;
    default:
      navigatorKey.currentState?.pushNamed('/home');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF7D29C6),
        statusBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Deliv',
        theme: AppTheme.theme,
        home: const SplashScreen(),
        routes: {
          '/home': (_) => const MainPage(),
          '/map-picker': (_) => const MapPickerScreen(),
          '/phone_screen': (context) => const PhoneScreen(),
          '/location_screen': (context) => const LocationScreen(),
        },
      ),
    );
  }
}
