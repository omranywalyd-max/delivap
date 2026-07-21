# خاصية رنّة وصول السائق (Driver Arrival Ringtone)

## ملخص المشروع

- **تطبيق الزبون:** `com.deliv.customer` — مسار: `C:\flutter_application_1`
- **تطبيق الدركاج/المحل:** `com.deliv.driver` — مسار: `C:\D\dashbord`
- **السيرفر:** Node.js — مسار محلي: `C:\server` | مسار VPS: `/root/delivery-server`
- **VPS:** `89.167.84.221` | مستخدم: `root` | كلمة السر: `ddeelliivv`
- **النطاق:** `api.delivap.com` | PM2 process: `delivery-api`
- **الجهاز:** RMX3491 (Realme) | Android API 35
- **ملاحظة مهمة:** المستخدم كيختبر الدور كامل (زبون + دركاج + صاحب محل + أدمين) على **نفس الجهاز**. كيبدل بين الأبليكيشنات.

---

## وصف الخاصية

لما الدركاج كيصل لعنوان التوصيل وكيدوس على "اخرج اخرج"، الزبون كيسمع رنة قوية + كتظهرلو شاشة كاملة (DriverArrivalActivity) فيها:
- صورة الدركاج + سميتو
- عداد تنازلي 60 ثانية
- زر إغلاق

**الرنا خاصها تشتغل حتى كان الأبليكيشن مطفّي أو في الخلفية.**

---

## قنوات الإشعارات (Notification Channels)

| Channel ID | الاسم | الصوت | ملاحظات |
|---|---|---|---|
| `user_channel` | إشعارات المستخدم | default | الافتراضية، مسجلة في Manifest |
| `driver_arrival` | إشعار وصول السائق | `okhrej.mp3` | **يجب إنشاؤها يدوياً في Kotlin** (MainActivity.kt) |
| `driver_arrival_channel` | إشعارات وصول السائق | default | مسجلة في Dart فقط، **لا تُستخدم حالياً** |
| `user_channel_okhrej` | إشعارات okhrej | `okhrej.mp3` | تُنشأ ديناميكياً في Dart |

---

## الملفات المستخدمة

### 1. السيرفر — `C:\server\fcm.js`

```javascript
const { getMessaging } = require('firebase-admin/messaging');

async function sendToDriver({ driverId, title, body, data = {} }) {
  try {
    const mongoose = require('mongoose');
    const Driver = require('./models/Driver');
    let driver = await Driver.findOne({ uid: driverId });
    if (!driver && mongoose.Types.ObjectId.isValid(driverId)) {
      driver = await Driver.findById(driverId);
    }
    if (!driver || !driver.fcmToken) {
      console.log(`FCM: no fcmToken for driver ${driverId}`);
      return;
    }
    await getMessaging().send({
      token: driver.fcmToken,
      data: Object.fromEntries(Object.entries({ title, body, recipientId: driverId, ...data }).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high' },
    });
    console.log(`FCM sent to driver ${driverId}: ${title}`);
  } catch (e) {
    console.error(`FCM Error for driver ${driverId}:`, e.message);
  }
}

async function sendToUser({ userId, title, body, data = {} }) {
  try {
    const mongoose = require('mongoose');
    const User = require('./models/User');
    let user = await User.findOne({ uid: userId });
    if (!user && mongoose.Types.ObjectId.isValid(userId)) {
      user = await User.findById(userId);
    }
    if (!user || !user.fcmToken) {
      console.log(`FCM: no fcmToken for user ${userId}`);
      return;
    }
    if (user.settings?.disablePurchaseNotif && data?.type?.includes('purchased')) {
      console.log(`FCM: skipped purchase notif for ${userId}`);
      return;
    }

    const dataFields = Object.fromEntries(
      Object.entries({ title, body, recipientId: userId, ...data }).map(([k, v]) => [k, String(v)])
    );

    const isOkhrej = data.sound === 'okhrej';
    await getMessaging().send({
      token: user.fcmToken,
      notification: { title, body },
      data: dataFields,
      android: {
        priority: 'high',
        ...(isOkhrej ? { notification: { sound: 'okhrej', channelId: 'driver_arrival' } } : {}),
      },
    });

    const dataKeys = Object.keys(data);
    console.log(`FCM sent to ${userId}: ${title} | sound=${data['sound'] || 'default'} | dataKeys=${dataKeys.join(',')}`);
  } catch (e) {
    console.error(`FCM Error for user ${userId}:`, e.message);
  }
}

module.exports = { sendToUser, sendToDriver };
```

**ملاحظة السيرفر:** الـ `sendToDriver` كيبعث **data-only** (بدون `notification`). الـ `sendToUser` كيبعث `notification` + `data`. لـ `okhrej` كيضيف `android.notification.sound: 'okhrej'` و `channelId: 'driver_arrival'`.

---

### 2. Dart — `C:\flutter_application_1\lib\main.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  final bool isOkhrej = soundName == 'okhrej';
  final channelId = isOkhrej ? 'driver_arrival' : (soundName != null ? 'user_channel_$soundName' : 'user_channel');
  final channelName = isOkhrej ? 'إشعار وصول السائق' : (soundName != null ? 'إشعارات $soundName' : 'إشعارات المستخدم');
  flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'إشعارات الطلبات والتوصيل',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        sound: isOkhrej ? const RawResourceAndroidNotificationSound('okhrej') : null,
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

void _initDeferredServices() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const MethodChannel('com.deliv.customer/ringtone')
      .invokeMethod('requestFullScreenIntent')
      .catchError((_) {});

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
        } catch (_) {}
      }
    },
  );

  const driverArrivalChannel = AndroidNotificationChannel(
    'driver_arrival_channel',
    'إشعارات وصول السائق',
    description: 'إشعارات وصول السائق مع صوت الرنة',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(driverArrivalChannel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('🔔 [NOTIFICATION RECEIVED] Data: ${message.data}');
    
    _showLocalNotification(message);

    final sound = message.data['sound'];
    if (sound == 'okhrej') {
      final isEnabled = DriverArrivalOverlay.isEnabled;
      final hasCtx = navigatorKey.currentContext != null;
      debugPrint('🔔 [ARRIVAL] sound=$sound isEnabled=$isEnabled hasContext=$hasCtx');
      
      ApiClient.post('/api/debug/arrival-log', {
        'userId': UserLocal.uid,
        'sound': sound,
        'isEnabled': isEnabled,
        'hasCtx': hasCtx,
        'timestamp': DateTime.now().toIso8601String(),
      }).catchError((_) {});

      if (hasCtx && isEnabled) {
        DriverArrivalOverlay.trigger(
          context: navigatorKey.currentContext!,
          driverName: message.data['driverName'] as String?,
          driverPhoto: message.data['driverPhoto'] as String?,
          orderId: message.data['orderId'] as String?,
        );
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);

    final sound = message.data['sound'];
    if (sound == 'okhrej') {
      final isEnabled = DriverArrivalOverlay.isEnabled;
      final hasCtx = navigatorKey.currentContext != null;
      debugPrint('🔔 [ARRIVAL-OPENED] sound=$sound isEnabled=$isEnabled hasContext=$hasCtx');
      ApiClient.post('/api/debug/arrival-log', {
        'userId': UserLocal.uid,
        'sound': sound,
        'isEnabled': isEnabled,
        'hasCtx': hasCtx,
        'source': 'onMessageOpenedApp',
        'timestamp': DateTime.now().toIso8601String(),
      }).catchError((_) {});

      if (hasCtx && isEnabled) {
        DriverArrivalOverlay.trigger(
          context: navigatorKey.currentContext!,
          driverName: message.data['driverName'] as String?,
          driverPhoto: message.data['driverPhoto'] as String?,
          orderId: message.data['orderId'] as String?,
        );
      }
    }
  });

  messaging.getInitialMessage().then((initialMessage) {
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationNavigation(initialMessage.data);

        final sound = initialMessage.data['sound'];
        if (sound == 'okhrej') {
          final isEnabled = DriverArrivalOverlay.isEnabled;
          final hasCtx = navigatorKey.currentContext != null;
          debugPrint('🔔 [ARRIVAL-INIT] sound=$sound isEnabled=$isEnabled hasContext=$hasCtx');
          ApiClient.post('/api/debug/arrival-log', {
            'userId': UserLocal.uid,
            'sound': sound,
            'isEnabled': isEnabled,
            'hasCtx': hasCtx,
            'source': 'getInitialMessage',
            'timestamp': DateTime.now().toIso8601String(),
          }).catchError((_) {});

          if (hasCtx && isEnabled) {
            DriverArrivalOverlay.trigger(
              context: navigatorKey.currentContext!,
              driverName: initialMessage.data['driverName'] as String?,
              driverPhoto: initialMessage.data['driverPhoto'] as String?,
              orderId: initialMessage.data['orderId'] as String?,
          );
        }
      }});
    }
  }).catchError((_) {});

  messaging.getToken().then((fcmToken) {
    if (fcmToken == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ApiClient.put('/api/users/${user.uid}', {'fcmToken': fcmToken}).catchError((_) {});
      UserLocal.load(user.uid).catchError((_) {});
    }
  }).catchError((_) {});

  messaging.onTokenRefresh.listen((String newToken) {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      ApiClient.put('/api/users/${u.uid}', {'fcmToken': newToken}).catchError((_) {});
    }
  });
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title == null && body == null) return;
  final soundName = message.data['sound'] as String?;
  final bool isOkhrej = soundName == 'okhrej';
  final channelId = isOkhrej ? 'driver_arrival' : (soundName != null ? 'user_channel_$soundName' : 'user_channel');
  final channelName = isOkhrej ? 'إشعار وصول السائق' : (soundName != null ? 'إشعارات $soundName' : 'إشعارات المستخدم');

  final androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'إشعارات الطلبات والتوصيل',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    sound: isOkhrej ? const RawResourceAndroidNotificationSound('okhrej') : (soundName != null ? RawResourceAndroidNotificationSound(soundName) : null),
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
```

---

### 3. DriverArrivalOverlay — `C:\flutter_application_1\lib\driver_arrival_overlay.dart`

```dart
import 'dart:async';
import 'dart:developer';
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
    log('DriverArrivalOverlay: trigger called, isEnabled=$isEnabled, will launch in 10s');

    _showTimer = Timer(const Duration(seconds: 10), () async {
      try {
        log('DriverArrivalOverlay: launching arrival screen...');
        await _channel.invokeMethod('launchArrivalScreen', {
          'driverName': driverName ?? 'السائق',
          'driverPhoto': driverPhoto ?? '',
        });
        log('DriverArrivalOverlay: success');
      } catch (e) {
        log('DriverArrivalOverlay ERROR: $e');
      }
    });
  }

  static bool get isEnabled {
    final data = UserLocal.data;
    if (data != null && data['settings'] is Map) {
      final s = data['settings'] as Map;
      return s['enableDriverArrivalRing'] != false;
    }
    return true;
  }

  static void cancelPending() {
    _showTimer?.cancel();
    _showTimer = null;
  }
}
```

**ملاحظة:** `isEnabled` كيرجع `true` إذا الـ setting ما موجودش. الـ `enableDriverArrivalRing` defaults to `false` في `notification_settings_screen.dart` — يعني المستخدم لازم يفعّلو يدوياً.

---

### 4. MainActivity.kt — `C:\flutter_application_1\android\app\src\main\kotlin\com\deliv\customer\MainActivity.kt`

```kotlin
package com.deliv.customer

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: android.media.Ringtone? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createDriverArrivalChannel()
    }

    private fun createDriverArrivalChannel() {
        val channelId = "driver_arrival"
        val channelName = "إشعار وصول السائق"
        val soundUri = Uri.parse("android.resource://$packageName/${R.raw.okhrej}")

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "رنّة وصول السائق"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500)
            setSound(soundUri, AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
        }

        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.deliv.customer/ringtone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRingtone" -> {
                        try {
                            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
                            ringtone?.audioAttributes = android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                            ringtone?.play()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopRingtone" -> {
                        try {
                            ringtone?.stop()
                            ringtone = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "launchArrivalScreen" -> {
                        try {
                            val driverName = call.argument<String>("driverName") ?: "السائق"
                            val driverPhoto = call.argument<String>("driverPhoto") ?: ""
                            val intent = Intent(this, DriverArrivalActivity::class.java).apply {
                                putExtra("driverName", driverName)
                                putExtra("driverPhoto", driverPhoto)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "requestFullScreenIntent" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                try {
                                    val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                    startActivity(intent)
                                    result.success(true)
                                } catch (e2: Exception) {
                                    result.error("ERROR", e2.message, null)
                                }
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

---

### 5. DriverArrivalActivity.kt — `C:\flutter_application_1\android\app\src\main\kotlin\com\deliv\customer\DriverArrivalActivity.kt`

```kotlin
package com.deliv.customer

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.bumptech.glide.Glide
import java.util.Locale

class DriverArrivalActivity : Activity() {

    private var ringtone: Ringtone? = null
    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var secondsLeft = 60

    private val countdownRunnable = object : Runnable {
        override fun run() {
            secondsLeft--
            val tv = findViewById<TextView>(R.id.tvCountdown)
            if (tv != null) tv.text = String.format(Locale.US, "%ds", secondsLeft)
            if (secondsLeft > 0) {
                handler.postDelayed(this, 1000)
            } else {
                dismiss()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_driver_arrival)

        val driverName = intent.getStringExtra("driverName") ?: "السائق"
        val driverPhoto = intent.getStringExtra("driverPhoto") ?: ""

        findViewById<TextView>(R.id.tvDriverName).text = driverName

        if (driverPhoto.isNotEmpty()) {
            Glide.with(this)
                .load(driverPhoto)
                .circleCrop()
                .into(findViewById(R.id.ivDriver))
        }

        findViewById<Button>(R.id.btnClose).setOnClickListener {
            dismiss()
        }

        startRingtone()
        handler.postDelayed(countdownRunnable, 1000)
    }

    private fun startRingtone() {
        try {
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, ringtoneUri)
            if (ringtone == null) {
                playAssetAlarm()
                return
            }
            ringtone?.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone?.play()
        } catch (_: Exception) {
            playAssetAlarm()
        }
    }

    private fun playAssetAlarm() {
        try {
            val afd = assets.openFd("Alarm.mp3")
            mediaPlayer = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {}
    }

    private fun dismiss() {
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        try { mediaPlayer?.stop(); mediaPlayer?.release() } catch (_: Exception) {}
        ringtone = null
        mediaPlayer = null
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(countdownRunnable)
        try { ringtone?.stop() } catch (_: Exception) {}
        try { mediaPlayer?.stop(); mediaPlayer?.release() } catch (_: Exception) {}
        ringtone = null
        mediaPlayer = null
    }
}
```

---

### 6. AndroidManifest.xml — `C:\flutter_application_1\android\app\src\main\AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:label="@string/app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:networkSecurityConfig="@xml/network_security_config"
        android:allowBackup="false"
        android:dataExtractionRules="@xml/data_extraction_rules">

        <meta-data android:name="com.google.android.geo.API_KEY"
            android:value="AIzaSyCp2VwwSQSY2vvyCot-oq7UFvlO61xpo2s"/>
        
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="user_channel" />

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <activity
            android:name=".DriverArrivalActivity"
            android:exported="false"
            android:launchMode="singleInstance"
            android:taskAffinity="com.deliv.customer.arrival"
            android:theme="@style/LaunchTheme"
            android:showOnLockScreen="true"
            android:turnScreenOn="true"
            android:excludeFromRecents="true"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize"
            android:windowSoftInputMode="adjustResize" />

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
    </queries>
</manifest>
```

---

### 7. build.gradle.kts — `C:\flutter_application_1\android\app\build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.deliv.customer" 
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.deliv.customer"
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true 
    }

    signingConfigs {
        create("release") {
            storeFile = file("../../keystore.jks")?.takeIf { it.exists() }
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.github.bumptech.glide:glide:4.16.0")
}
```

**ملاحظة:** مكتبات Firebase Messaging الإضافية تم حذفها لأن Flutter plugin كيحتويها بالفعل.

---

### 8. proguard-rules.pro — `C:\flutter_application_1\android\app\proguard-rules.pro`

```proguard
# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
-dontwarn com.google.errorprone.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.maps.** { *; }
-dontwarn com.google.maps.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Lottie
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# HTTP
-keep class org.apache.** { *; }
-dontwarn org.apache.**

# JSON
-keep class com.fasterxml.** { *; }
-dontwarn com.fasterxml.**

# Keep generic signatures
-keepattributes Signature
-keepattributes *Annotation*

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep model classes used by Gson/Json
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp / Okio
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Keep serializable classes
-keepattributes EnclosingMethod
-keep class ** implements java.io.Serializable { *; }

# Keep source info for crash reporting
-keepattributes SourceFile,LineNumberTable

# Customer app native activities
-keep class com.deliv.customer.** { *; }
-keep class com.deliv.customer.DriverArrivalActivity { *; }
-keep class com.deliv.customer.MainActivity { *; }
```

---

### 9. Notification Settings Screen — `C:\flutter_application_1\lib\notification_settings_screen.dart`

```dart
// الملف الكامل موجود في المشروع — هذا الجزء المتعلق بالخاصية:

// المتغير:
bool _enableDriverArrivalRing = false;

// التحميل من settings:
_enableDriverArrivalRing = s['enableDriverArrivalRing'] == true;

// الحفظ:
'enableDriverArrivalRing': _enableDriverArrivalRing,

// الـ Toggle:
_buildToggleCard(
  icon: CupertinoIcons.alarm_fill,
  title: 'رنّة وصول السائق',
  subtitle: 'تشغيل رنة التلفون عندما يصل السائق',
  value: _enableDriverArrivalRing,
  onChanged: (v) async {
    if (v) {
      // يطلب إذن Full Screen Intent من إعدادات التلفون
      try {
        await _ringChannel.invokeMethod('requestFullScreenIntent');
      } catch (_) {}
    }
    setState(() {
      _enableDriverArrivalRing = v;
      _save();
    });
  },
),
```

**ملاحظة مهمة:** الـ toggle كيحفظ في `UserLocal.data['settings']['enableDriverArrivalRing']`. الـ default هو `false` — يعني لازم المستخدم يفعّلو يدوياً.

---

### 10. layout — `C:\flutter_application_1\android\app\src\main\res\layout\activity_driver_arrival.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#DD000000"
    android:gravity="center"
    android:orientation="vertical"
    android:padding="32dp">

    <ImageView
        android:id="@+id/ivDriver"
        android:layout_width="120dp"
        android:layout_height="120dp"
        android:layout_gravity="center"
        android:background="@drawable/circle_bg"
        android:padding="4dp"
        android:scaleType="centerCrop"
        android:src="@mipmap/ic_launcher" />

    <TextView
        android:id="@+id/tvTitle"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="24dp"
        android:text="السائق وصل!"
        android:textColor="#FFFFFF"
        android:textSize="28sp"
        android:textStyle="bold"
        android:fontFamily="serif" />

    <TextView
        android:id="@+id/tvDriverName"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="السائق"
        android:textColor="#B0FFFFFF"
        android:textSize="20sp"
        android:fontFamily="serif" />

    <TextView
        android:id="@+id/tvSubtitle"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="اخرج لاستلام طلبك"
        android:textColor="#99FFFFFF"
        android:textSize="18sp"
        android:fontFamily="serif" />

    <TextView
        android:id="@+id/tvCountdown"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="16dp"
        android:background="@drawable/countdown_bg"
        android:paddingHorizontal="20dp"
        android:paddingVertical="8dp"
        android:text="60s"
        android:textColor="#80FFFFFF"
        android:textSize="16sp"
        android:fontFamily="serif" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="48dp"
        android:text="⬇ اسحب للأسفل أو اضغط إغلاق ⬇"
        android:textColor="#60FFFFFF"
        android:textSize="14sp"
        android:fontFamily="serif" />

    <Button
        android:id="@+id/btnClose"
        android:layout_width="72dp"
        android:layout_height="72dp"
        android:layout_marginTop="32dp"
        android:background="@drawable/close_btn_bg"
        android:text="✕"
        android:textColor="#FFFFFF"
        android:textSize="28sp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="إغلاق"
        android:textColor="#80FFFFFF"
        android:textSize="16sp"
        android:fontFamily="serif" />

</LinearLayout>
```

---

### 11. Drawable Resources

**circle_bg.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#4D7D29C6" />
    <stroke android:width="3dp" android:color="#FF7D29C6" />
</shape>
```

**countdown_bg.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#1AFFFFFF" />
    <corners android:radius="20dp" />
</shape>
```

**close_btn_bg.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#FF0000" />
</shape>
```

---

### 12. Sound Files

| الملف | المسار | الوظيفة |
|---|---|---|
| `okhrej.mp3` | `android/app/src/main/res/raw/okhrej.mp3` | صوت الإشعار الرئيسي لـ okhrej |
| `Alarm.mp3` | `assets/Alarm.mp3` | صوت احتياطي (fallback) لـ DriverArrivalActivity |

---

### 13. pubspec.yaml Dependencies (المتعلقة)

```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
firebase_messaging: ^15.2.10
flutter_local_notifications: ^21.0.0
shared_preferences: ^2.2.2
```

---

## سير البيانات (Data Flow)

```
1. الدركاج يضغط "اخرج اخرج" في driver_order_detail_screen.dart
   ↓
2. FCMHelper.sendToUser() يبعث FCM notification لـ ownerId
   ↓
3. fcm.js sendToUser() يبعث:
   - notification: { title, body }
   - data: { sound: 'okhrej', driverName, driverPhoto, recipientId }
   - android: { notification: { sound: 'okhrej', channelId: 'driver_arrival' } }
   ↓
4. على جهاز الزبون:
   a) App in FOREGROUND → onMessage fires → DriverArrivalOverlay.trigger() → 10s delay → DriverArrivalActivity
   b) App in BACKGROUND → Android shows notification directly → الصوت كيشتغل من channel
   c) App KILLED → Android shows notification → المستخدم كيضغط → onMessageOpenedApp → DriverArrivalOverlay
```

---

## المشاكل اللي واجهتنا

### المشكلة #1: `onMessage` ما كيشتغلش当 App في Background

**السبب:** المستخدم كيختبر على نفس الجهاز — كيبدل من الأب تاع الدركاج للب تاع الزبون. كيبعث okhrej من دركاج → الأب تاع الزبون كيكون في **background**. `onMessage` كيشتغل **فقط** في foreground.

**الحالة الحالية:**
- `onMessage` → يشتغل غير كان الأب مفتوح قدامك (foreground)
- `onBackgroundMessage` → كيشتغل كيكون الأب في background، بس **ما كيقدرش يفتح Activity** (يعني DriverArrivalActivity ما كتفتحش)
- `onMessageOpenedApp` → كيشتغل كيضغط على الإشعار

**النتيجة:** الصوت كيشتغل من الإشعار (notification sound)، بس الشاشة الكاملة (DriverArrivalActivity) **ما كتظهرش** إلا كيكون الأب مفتوح أو كيضغط على الإشعار.

### المشكلة #2: `MyFirebaseMessagingService` كتصادم مع Flutter Plugin

**اللي درنا:** حاولنا نخلقوا `MyFirebaseMessagingService.kt` native كتستقبل okhrej في background وتفتح `DriverArrivalActivity` مباشرة.

**المشكل:** Flutter plugin كيحتوي `FlutterFirebaseMessagingReceiver` اللي كيتصادم مع أي custom `FirebaseMessagingService`. كياخد الإشعار قبل ما يوصل للـ custom service.

**النتيجة:** خذفناها واستعملنا `onBackgroundMessage` + local notifications بدلاً منها.

### المشكلة #3: Firebase Messaging Dependency مكررة

**اللي درنا:** أضفنا `implementation("com.google.firebase:firebase-messaging")` في `build.gradle.kts`.

**المشكل:** Flutter plugin كيحتويها بالفعل. التكرار كيسبب مشاكل.

**النتيجة:** شلناها من `build.gradle.kts`.

### المشكلة #4: Notification Channel `driver_arrival` غير موجودة

**اللي حصل:** السيرفر كيبعث `channelId: 'driver_arrival'` لكن الأب ما كانتش كتخلقها.

**التحذير:** `W/FirebaseMessaging: Notification Channel requested (driver_arrival) has not been created by the app.`

**النتيجة:** Android كيستخدم القناة الافتراضية (`user_channel`) اللي ما عندهاش صوت okhrej.

**الحل:** أضفنا `createDriverArrivalChannel()` في `MainActivity.kt` كتخلق القناة في Kotlin مع `okhrej.mp3`.

### المشكلة #5: Channel ID مكرر ومختلف

| مكان | Channel ID | الصوت |
|---|---|---|
| Dart `_initDeferredServices` | `driver_arrival_channel` | لا |
| Dart `_showLocalNotification` | `driver_arrival` | نعم (okhrej) |
| Dart `_firebaseMessagingBackgroundHandler` | `driver_arrival` | نعم (okhrej) |
| Kotlin `MainActivity.kt` | `driver_arrival` | نعم (okhrej) |
| السيرفر FCM | `driver_arrival` | — |
| Dart `_initDeferredServices` (الافتراضية) | `driver_arrival_channel` | لا |

**المشكل:** `driver_arrival_channel` ≠ `driver_arrival`. في Dart كاينين قنوات مختلفين، والسيرفر كيبعث `driver_arrival` والـ Dart كيخلق `driver_arrival_channel`.

### المشكلة #6: `_BannerItemState.setState()` during build

**الخطأ:** `setState() or markNeedsBuild() called during build`

**السبب:** `_onImageResolved` كيتنفذ داخل `imageBuilder` (أثناء build)، والصورة كتكون في الكاش → الـ listener كيرجع بسرعة → كيعاود `setState` قبل ما يكمل الـ build.

**الحل:**
```dart
// قبل (خاطئ):
setState(() => _imageSize = size);

// بعد (صحيح):
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) setState(() => _imageSize = size);
});
```

### المشكلة #7: `enableDriverArrivalRing` defaults to `false`

**في `notification_settings_screen.dart`:**
```dart
bool _enableDriverArrivalRing = false;  // default false!
```

**في `driver_arrival_overlay.dart`:**
```dart
static bool get isEnabled {
  // ...
  return s['enableDriverArrivalRing'] != false;  // returns true if null
}
```

**التناقض:** الـ overlay كيرجع `true` إذا الـ setting null (ما لقاهاش)، بس الـ screen كيبدأ بـ `false`. يعني:
- أول مرة: `isEnabled` = `true` (null != false)
- كيحفظ الـ settings: `isEnabled` = `false` (false == false)
- كيتفعّل: `isEnabled` = `true`

---

## TODO / الحلول المطلوبة

### الحل الأهم: فتح DriverArrivalActivity في Background

**المشكل:** `onBackgroundMessage` كيشتغل في Dart isolate ما كيقدرش يفتح native Activity.

**الخيارات:**
1. ** flutter_local_notifications `fullScreenIntent`**: في `onBackgroundMessage`، نعرضوا إشعار محلي مع `fullScreenIntent` كيوجه لـ `DriverArrivalActivity`. هذا كيشتغل حتى كان الأب مطفّي.
2. **WorkManager/Background Service**: نلقوا خدمة في الخلفية كتستقبل الإشعار وتفتح الـ Activity مباشرة.
3. **استعمال `notification` payload مع `click_action`**: نضيفوا `click_action` في الـ FCM payload كيوجه لـ `DriverArrivalActivity` مباشرة.

**الخيار الأسهل:** `fullScreenIntent` في `flutter_local_notifications` — لازم نتأكدوا أن المكتبة كتدعمها.

### الحل التاني: توقيف `enableDriverArrivalRing` للـ `true` كـ default

```dart
// في notification_settings_screen.dart:
bool _enableDriverArrivalRing = true;  // true بدل false
```

---

## معلومات تقنية إضافية

- **Device:** RMX3491 (Realme) — Android API 35
- **ProGuard:** `isMinifyEnabled = true` + `isShrinkResources = true`
- **Firebase SDK:** firebase-messaging: ^15.2.10
- **flutter_local_notifications:** ^21.0.0
- **التطبيق:** same device testing — نفس الجهاز لكل الأدوار
- **VPS:** PM2 `delivery-api` | MongoDB `walyyd` | `api.delivap.com`
- **same FCM token** مستعمل للدركاج + صاحب المحل على نفس الجهاز
