import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;
import 'unified_login.dart';
import 'admin_panel.dart';
import 'driver_app.dart';
import 'splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

String? _cachedUserRole;

@pragma('vm:entry-point')
Future<void> _dashboardBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final recipientId = message.data['recipientId'];
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (recipientId != null && currentUid != null && recipientId != currentUid) return;

  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('userRole') ?? 'driver';
  final notifType = message.data['type'] ?? '';
  if (role == 'owner' && _isDriverOnlyNotification(notifType)) return;
  if (role == 'driver' && _isOwnerOnlyNotification(notifType)) return;

  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;
  await flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'orders_channel',
        'إشعارات الطلبات',
        channelDescription: 'إشعارات الطلبات',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        showWhen: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

bool _isDriverOnlyNotification(String type) {
  return type == 'alternative_accepted' || type == 'alternative_rejected' || type == 'counter_offer_accepted';
}

bool _isOwnerOnlyNotification(String type) {
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_dashboardBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: androidSettings),
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showNotificationForRole(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint(' Notification tapped: ${message.data}');
  });

  final RemoteMessage? initial =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    debugPrint(' App opened from notification: ${initial.data}');
  }

  final prefs = await SharedPreferences.getInstance();
  final String? userRole = prefs.getString('userRole');
  _cachedUserRole = userRole;

  // Fetch FCM token and send to server if user is logged in
  String? fcmToken;
  try {
    fcmToken = await FirebaseMessaging.instance.getToken();
  } catch (_) {}
  debugPrint(' FCM Token: $fcmToken');
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && fcmToken != null) {
    ApiClient.setToken(null);
    try {
      final role = userRole == 'owner' ? 'owner' : 'driver';
      await ApiClient.post('/api/notify-token', {
        'uid': user.uid,
        'fcmToken': fcmToken,
        'role': role,
      });
    } catch (_) {}
  } else if (fcmToken != null && userRole == 'owner') {
    try {
      final dataRaw = prefs.getString('ownerData');
      if (dataRaw != null) {
        final data = jsonDecode(dataRaw) as Map<String, dynamic>;
        final ownerId = data['uid'] as String?;
        final token = prefs.getString('adminToken');
        if (token != null) ApiClient.setToken(token);
        if (ownerId != null) {
          await ApiClient.post('/api/notify-token', {
            'uid': ownerId,
            'fcmToken': fcmToken,
            'role': 'owner',
          });
        }
      }
    } catch (_) {}
  }

  runApp(MyApp(savedRole: userRole));
}

Future<void> _showNotificationForRole(RemoteMessage message) async {
  final recipientId = message.data['recipientId'];
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (recipientId != null && currentUid != null && recipientId != currentUid) return;

  final role = _cachedUserRole ?? 'driver';
  final notifType = message.data['type'] ?? '';
  if (role == 'owner' && _isDriverOnlyNotification(notifType)) return;
  if (role == 'driver' && _isOwnerOnlyNotification(notifType)) return;

  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;

  await flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'orders_channel',
        'إشعارات الطلبات',
        channelDescription: 'إشعارات الطلبات',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        showWhen: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

class MyApp extends StatelessWidget {
  final String? savedRole;
  const MyApp({super.key, this.savedRole});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF5B0094),
        statusBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DelivDriver',
        theme: AppTheme.theme,
        home: const DriverSplashScreen(),
        routes: {
          '/login':  (_) => const UnifiedLoginScreen(),
          '/admin':  (_) => const AdminDashboardMain(),
          '/driver': (_) => const DriverMainShell(),
        },
      ),
    );
  }

  Widget _getHome() {
    if (FirebaseAuth.instance.currentUser != null) {
      return const _AuthGate();
    }

    if (savedRole == 'admin') return const AdminGate();

    if (savedRole == 'owner') {
      return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          String? dataRaw = snapshot.data!.getString('ownerData');
          if (dataRaw != null) {
            try {
              Map<String, dynamic> data = jsonDecode(dataRaw);
              return OwnerDashboard(ownerData: data);
            } catch (e) {
              return const UnifiedLoginScreen();
            }
          }
          return const UnifiedLoginScreen();
        },
      );
    }

    return const UnifiedLoginScreen();
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndRoute());
  }

  Future<void> _checkAndRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final doc = await ApiClient.get('/api/drivers/${user.uid}');
      if (doc['isActive'] != true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      SocketClient().init();
      SocketClient().join('driver_${user.uid}');
      if (mounted) Navigator.pushReplacementNamed(context, '/driver');
    } catch (e) {
      debugPrint('AuthGate error: $e');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('adminToken');
    if (token != null) ApiClient.setToken(token);
  }

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardMain();
  }
}
