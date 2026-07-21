import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher_string.dart';

import 'fcm_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dashbord/driver_active_orders.dart';
import 'package:dashbord/driver_settings_screen.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:dashbord/driver_pricing_settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;

// ══════════════════════════════════════════════════════════════════════════════
//  ① ألوان (مرجعية من AppTheme)
// ══════════════════════════════════════════════════════════════════════════════
const Color kBg = AppTheme.background;
const Color kPrimary = AppTheme.primary;
const Color kPrimaryDark = AppTheme.primaryDark;
const Color kAccent = AppTheme.accent;
const Color kTextDark = AppTheme.textDark;
const Color kTextGrey = AppTheme.textGrey;
const Color kDanger = AppTheme.danger;
const Color kSuccess = AppTheme.success;
const Color kWarning = AppTheme.warning;
const Color kInfo = AppTheme.info;
const Color kNeumShadow = AppTheme.neumShadow;

const List<String> kRejectionReasons = AppTheme.rejectionReasons;

// ══════════════════════════════════════════════════════════════════════════════
//  ② DriverModel
// ══════════════════════════════════════════════════════════════════════════════
class DriverModel {
  final String cityNameAr;
  final String cityNameFr;
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String photoUrl;
  final bool isOnline;
  final bool isActive;
  final bool isVerified;
  final double lat;
  final double lng;
  final String cityName;
  final int totalDeliveries;
  final int cancelledDeliveries;
  final double totalEarnings;
  final bool hasSetPricing;
  final Map<String, dynamic> pricing;
  final bool canSetPricing;
  final bool canUploadPhoto;
  final double commissionPercent;
  final double cash;
  final double lastCommissionResetEarnings;
  final String vehicleType;

  DriverModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.cityNameAr = '',
    this.cityNameFr = '',
    this.photoUrl = '',
    this.hasSetPricing = false,
    this.canSetPricing = false,
    this.canUploadPhoto = false,
    this.isOnline = false,
    this.isActive = false,
    this.isVerified = false,
    this.lat = 0,
    this.lng = 0,
    this.cityName = '',
    this.totalDeliveries = 0,
    this.cancelledDeliveries = 0,
    this.totalEarnings = 0,
    this.pricing = const {},
    this.commissionPercent = 0,
    this.cash = 0,
    this.lastCommissionResetEarnings = 0,
    this.vehicleType = '',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory DriverModel.fromMap(String uid, Map<String, dynamic> d) =>
      DriverModel(
        uid: uid,
        firstName: d['firstName'] ?? '',
        lastName: d['lastName'] ?? '',
        email: d['email'] ?? '',
        phone: d['phone'] ?? '',
        cityNameAr: d['cityNameAr'] ?? '',
        cityNameFr: d['cityNameFr'] ?? '',
        photoUrl: d['photoUrl'] ?? '',
        isOnline: d['isOnline'] ?? false,
        isActive: d['isActive'] ?? false,
        isVerified: d['isVerified'] ?? false,
        lat: (d['lat'] ?? 0).toDouble(),
        lng: (d['lng'] ?? 0).toDouble(),
        cityName: d['cityName'] ?? '',
        totalDeliveries: d['totalDeliveries'] ?? 0,
        cancelledDeliveries: d['cancelledDeliveries'] ?? 0,
        totalEarnings: (d['totalEarnings'] ?? 0).toDouble(),
        pricing: Map<String, dynamic>.from(d['pricing'] ?? {}),
        hasSetPricing: d['hasSetPricing'] == true,
        canSetPricing: d['canSetPricing'] == true,
        canUploadPhoto: d['canUploadPhoto'] == true,
        commissionPercent: (d['commissionPercent'] ?? 0).toDouble(),
        cash: (d['cash'] ?? 0).toDouble(),
        lastCommissionResetEarnings: (d['lastCommissionResetEarnings'] ?? 0)
            .toDouble(),
        vehicleType: d['vehicleType'] ?? '',
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  ③ DriverService
// ══════════════════════════════════════════════════════════════════════════════
class DriverService {
  static final _auth = FirebaseAuth.instance;
  static String? get uid => _auth.currentUser?.uid;
  static StreamSubscription<Position>? _locSub;

  static Future<void> signIn(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  static Future<void> register({
    required String email,
    required String pass,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: pass,
    );
    await ApiClient.put('/api/drivers/${cred.user!.uid}', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'isOnline': false,
      'isActive': false,
      'isVerified': true,
      'totalDeliveries': 0,
      'cancelledDeliveries': 0,
      'totalEarnings': 0,
      'photoUrl': '',
      'createdAt': DateTime.now().toIso8601String(),
      'lastCommissionResetEarnings': 0,
    });
  }

  static Future<void> signOut() async {
    stopLocationSharing();
    _timer?.cancel();
    _timer = null;
    _ctl?.close();
    _ctl = null;
    _cached = null;
    _socketListening = false;
    SocketClient().off('driver:updated', _onDriverUpdated);
    if (uid != null) {
      await ApiClient.put('/api/drivers/$uid', {'isOnline': false});
      await ApiClient.post('/api/clear-token', {'uid': uid, 'role': 'driver'}).catchError((_) {});
    }
    ApiClient.setToken(null);
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> updateDriverPricing(Map<String, dynamic> config) async {
    if (uid == null) return;
    await ApiClient.put('/api/drivers/$uid', {
      'deliveryConfig': config,
      'hasSetPricing': true,
      'pricing': {
        'baseFare': config['basePrice'],
        'perKm': config['extraDistPrice'],
        'minFare': config['basePrice'],
      },
    });
  }

  static Future<void> toggleOnline(bool next) async {
    if (uid == null) return;
    await ApiClient.put('/api/drivers/$uid', {'isOnline': next});
  }

  static Future<void> startLocationSharing() async {
    if (uid == null) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    _locSub =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'دليڤ - تتبع الموقع',
              notificationText: 'جاري تتبع موقعك لتوصيل الطلبيات',
              enableWakeLock: true,
            ),
          ),
        ).listen((pos) {
          SocketClient().emit('driver:location', {
            'driverId': uid,
            'lat': pos.latitude,
            'lng': pos.longitude,
          });
        });
  }

  static const _locChannel = MethodChannel('com.deliv.driver/location');

  static void stopLocationSharing() {
    _locSub?.cancel();
    _locSub = null;
    _locChannel.invokeMethod('stopLocationService').catchError((_) {});
  }

  static DriverModel? _cached;
  static StreamController<DriverModel?>? _ctl;
  static Timer? _timer;

  static Future<void> refresh() async {
    final id = uid;
    if (id == null) return;
    try {
      final data = await ApiClient.get('/api/drivers/$id');
      _cached = DriverModel.fromMap(id, data);
      if (_ctl != null && !_ctl!.isClosed) _ctl!.add(_cached);
    } catch (_) {
      if (_ctl != null && !_ctl!.isClosed) _ctl!.add(null);
    }
  }

  static Stream<DriverModel?> driverStream() {
    if (uid == null) return Stream.value(null);
    if (_ctl == null) {
      _ctl = StreamController<DriverModel?>.broadcast(
        onCancel: () {
          _timer?.cancel();
          _timer = null;
        },
      );
    }
    if (_cached != null && !_ctl!.isClosed) _ctl!.add(_cached);
    _startPolling();
    return _ctl!.stream;
  }

  static bool _socketListening = false;
  static void _onDriverUpdated(dynamic _) {
    final id = uid;
    if (id == null) return;
    ApiClient.get('/api/drivers/$id').then((data) {
      _cached = DriverModel.fromMap(id, data);
      if (_ctl != null && !_ctl!.isClosed) _ctl!.add(_cached);
    }).catchError((_) {});
  }

  static void _startPolling() {
    if (_timer != null) return;
    final id = uid!;
    Future<void> fetch() async {
      try {
        final data = await ApiClient.get('/api/drivers/$id');
        _cached = DriverModel.fromMap(id, data);
        if (_ctl != null && !_ctl!.isClosed) _ctl!.add(_cached);
      } catch (_) {
        if (_ctl != null && !_ctl!.isClosed) _ctl!.add(null);
      }
    }
    fetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());
    if (!_socketListening) {
      _socketListening = true;
      SocketClient().on('driver:updated', _onDriverUpdated);
    }
  }

  static Future<void> updateFcmToken() async {
    if (uid == null) return;
    // لازم المكتبة تكون مستوردة باش هاد السطر يخدم
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ApiClient.put('/api/drivers/$uid', {
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now().toIso8601String(),
      });
    }
  }
  // داخل كلاس DriverService في ملف driver_dashboard.dart

  static Future<void> acceptOrder(String orderId) async {
    final orderData = await ApiClient.get('/api/orders/$orderId');
    final String? userId = orderData['userId'] as String?;
    final driverData = await ApiClient.get('/api/drivers/$uid');
    final driverName =
        '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
            .trim();
    final name = driverName.isNotEmpty ? driverName : 'السائق';
    final hasPendingCo =
        orderData['counterOffer'] is Map &&
        (orderData['counterOffer']['status'] as String? ?? '') == 'pending';

    await ApiClient.put('/api/orders/$orderId', {
      'status': 'accepted',
      'driverId': uid,
      'acceptedAt': DateTime.now().toIso8601String(),
      if (hasPendingCo) 'counterOffer.status': 'rejected',
    });

  }

  static Future<void> rejectOrder(String orderId, [String? reason]) async {
    final orderData = await ApiClient.get('/api/orders/$orderId');
    final userId = orderData['userId'] as String?;
    await ApiClient.put('/api/orders/$orderId', {
      'status': 'pending',
      'driverId': null,
      'rejectedBy': uid,
      if (reason != null) 'rejectionReason': reason,
    });
    if (userId != null) {
      FCMHelper.sendToUser(
        userId: userId,
        title: '❌ تم رفض طلبك',
        body: reason != null ? 'السائق رفض الطلب: $reason' : 'السائق رفض طلبك.',
        data: {'orderId': orderId},
      );
    }
  }

  static Future<void> counterOfferOrder({
    required String orderId,
    required double proposedPrice,
    required String driverName,
  }) async {
    final result = await ApiClient.put('/api/orders/$orderId', {
      'counterOffer': {
        'proposedPrice': proposedPrice,
        'driverName': driverName,
        'status': 'pending',
        'driverId': uid,
        'createdAt': DateTime.now().toIso8601String(),
      },
    });
    final userId = result['userId'] as String?;
    if (userId != null) {
      final priceStr = proposedPrice == proposedPrice.roundToDouble()
          ? proposedPrice.toInt().toString()
          : proposedPrice.toStringAsFixed(2);
      FCMHelper.sendToUser(
        userId: userId,
        title: 'طلبية من المتجر',
        body: 'السائق $driverName أرسل إليك عرض سعر جديد: $priceStr DZD',
        data: {'orderId': orderId, 'orderType': 'order'},
      );
    }
  }

  // ───── Project deliveries ─────
  static Future<bool> acceptProjectDelivery(String deliveryId) async {
    final res = await ApiClient.put('/api/project-deliveries/$deliveryId/driver-response', {
      'action': 'accept',
    });
    return res.isNotEmpty && res['status'] == 'accepted';
  }

  static Future<bool> rejectProjectDelivery(
    String deliveryId, [
    String? reason,
  ]) async {
    final res = await ApiClient.put('/api/project-deliveries/$deliveryId/driver-response', {
      'action': 'reject',
      if (reason != null) 'reason': reason,
    });
    return res.isNotEmpty;
  }

  static Future<bool> counterOfferProjectDelivery({
    required String deliveryId,
    required double proposedPrice,
    required String driverName,
  }) async {
    final res = await ApiClient.put('/api/project-deliveries/$deliveryId/driver-response', {
      'action': 'counter',
      'proposedPrice': proposedPrice,
    });
    return res.isNotEmpty;
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    // 1. تحديث حالة الطلب في قاعدة البيانات
    await ApiClient.put('/api/orders/$orderId', {
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });

  }

  static Future<void> incrementDeliveryStats({
    required double earnings,
    bool cancelled = false,
  }) async {
    if (uid == null) return;
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await ApiClient.put('/api/drivers/$uid/stats/$monthKey', {
      'deliveries': 1,
      'earnings': earnings,
      if (cancelled) 'cancelled': 1,
      'month': now.month,
      'year': now.year,
    });
  }

  static Future<Map<String, dynamic>> getMonthlyStats(
    int year,
    int month,
  ) async {
    if (uid == null) return {};
    final key = '$year-${month.toString().padLeft(2, '0')}';
    try {
      return await ApiClient.get('/api/drivers/$uid/stats/$key');
    } catch (_) {
      return {};
    }
  }

  // ───── Transport orders ─────
  static Future<void> acceptTransportOrder(String orderId) async {
    final snap = await ApiClient.get('/api/transport-orders/$orderId');
    final userId = snap['userId'] as String?;
    final transportType = snap['transportType'] as String? ?? 'نقل';
    final driverData = await ApiClient.get('/api/drivers/$uid');
    final driverName =
        '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
            .trim();
    final name = driverName.isNotEmpty ? driverName : 'السائق';
    final hasPendingCo =
        snap['counterOffer'] is Map &&
        (snap['counterOffer']['status'] as String? ?? '') == 'pending';
    await ApiClient.put('/api/transport-orders/$orderId', {
      'status': 'accepted',
      'driverId': uid,
      'acceptedAt': DateTime.now().toIso8601String(),
      if (hasPendingCo) 'counterOffer.status': 'rejected',
    });
  }

  static Future<void> rejectTransportOrder(
    String orderId, [
    String? reason,
  ]) async {
    final snap = await ApiClient.get('/api/transport-orders/$orderId');
    final userId = snap['userId'] as String?;
    final transportType = snap['transportType'] as String? ?? 'نقل';
    await ApiClient.put('/api/transport-orders/$orderId', {
      'status': 'pending',
      'driverId': null,
      'rejectedBy': uid,
      if (reason != null) 'rejectionReason': reason,
    });
    if (userId != null) {
      FCMHelper.sendToUser(
        userId: userId,
        title: '❌ طلب $transportType',
        body: reason != null
            ? 'السائق رفض الطلب: $reason'
            : 'السائق رفض طلب النقل.',
        data: {'orderId': orderId},
      );
    }
  }

  static Future<void> counterOfferTransportOrder({
    required String orderId,
    required double proposedPrice,
    required String driverName,
  }) async {
    final result = await ApiClient.put('/api/transport-orders/$orderId', {
      'counterOffer': {
        'proposedPrice': proposedPrice,
        'driverName': driverName,
        'status': 'pending',
        'driverId': uid,
        'createdAt': DateTime.now().toIso8601String(),
      },
    });
    final userId = result['userId'] as String?;
    if (userId != null) {
      final transportType = result['transportType'] as String? ?? 'نقل';
      final priceStr = proposedPrice == proposedPrice.roundToDouble()
          ? proposedPrice.toInt().toString()
          : proposedPrice.toStringAsFixed(2);
      FCMHelper.sendToUser(
        userId: userId,
        title: 'طلب $transportType',
        body: 'السائق $driverName أرسل إليك عرض سعر جديد: $priceStr DZD',
        data: {'orderId': orderId, 'orderType': 'transport'},
      );
    }
  }

  // ───── Service orders (توصيل/إحضار الطلبيات) ─────
  static Future<void> acceptServiceOrder(String orderId) async {
    final snap = await ApiClient.get('/api/service-orders/$orderId');
    final userId = snap['userId'] as String?;
    final serviceType = snap['serviceType'] as String? ?? '';
    final title = serviceType == 'delivery'
        ? '✅ توصيل الطلبيات'
        : '✅ إحضار طلبية';
    final driverData = await ApiClient.get('/api/drivers/$uid');
    final driverName =
        '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
            .trim();
    final name = driverName.isNotEmpty ? driverName : 'السائق';
    final hasPendingCo =
        snap['counterOffer'] is Map &&
        (snap['counterOffer']['status'] as String? ?? '') == 'pending';
    await ApiClient.put('/api/service-orders/$orderId', {
      'status': 'accepted',
      'driverId': uid,
      'acceptedAt': DateTime.now().toIso8601String(),
      if (hasPendingCo) 'counterOffer.status': 'rejected',
    });
  }

  static Future<void> rejectServiceOrder(
    String orderId, [
    String? reason,
  ]) async {
    final snap = await ApiClient.get('/api/service-orders/$orderId');
    final userId = snap['userId'] as String?;
    final serviceType = snap['serviceType'] as String? ?? '';
    final title = serviceType == 'delivery'
        ? '❌ توصيل الطلبيات'
        : '❌ إحضار طلبية';
    await ApiClient.put('/api/service-orders/$orderId', {
      'status': 'pending',
      'driverId': null,
      'rejectedBy': uid,
      if (reason != null) 'rejectionReason': reason,
    });
    if (userId != null) {
      FCMHelper.sendToUser(
        userId: userId,
        title: title,
        body: reason != null
            ? 'السائق رفض الطلب: $reason'
            : 'السائق رفض الطلبية.',
        data: {'orderId': orderId},
      );
    }
  }

  static Future<void> counterOfferServiceOrder({
    required String orderId,
    required double proposedPrice,
    required String driverName,
  }) async {
    final result = await ApiClient.put('/api/service-orders/$orderId', {
      'counterOffer': {
        'proposedPrice': proposedPrice,
        'driverName': driverName,
        'status': 'pending',
        'driverId': uid,
        'createdAt': DateTime.now().toIso8601String(),
      },
    });
    final userId = result['userId'] as String?;
    if (userId != null) {
      final serviceType = result['serviceType'] as String? ?? '';
      final title = serviceType == 'delivery'
          ? 'توصيل الطلبيات'
          : 'إحضار طلبية';
      final priceStr = proposedPrice == proposedPrice.roundToDouble()
          ? proposedPrice.toInt().toString()
          : proposedPrice.toStringAsFixed(2);
      FCMHelper.sendToUser(
        userId: userId,
        title: title,
        body: 'السائق $driverName أرسل إليك عرض سعر جديد: $priceStr DZD',
        data: {'orderId': orderId, 'orderType': 'service'},
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ④ ConnectivityBanner
// ══════════════════════════════════════════════════════════════════════════════
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});
  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _online = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(
          () =>
              _online = result.isNotEmpty && result.first.rawAddress.isNotEmpty,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: kDanger,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.wifi_slash, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Text(
            'لا يوجد اتصال بالإنترنت',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑤ ويدجتات مشتركة
// ══════════════════════════════════════════════════════════════════════════════
class NeuTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final bool hasError;

  const NeuTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: hasError
            ? [
                BoxShadow(
                  color: kDanger.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: kDanger.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(-4, -4),
                ),
              ]
            : neuShadow(),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 14,
          color: kTextDark,
          fontFamily: 'Amiri',
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: kTextGrey,
            fontSize: 13,
            fontFamily: 'Amiri',
          ),
          prefixIcon: Icon(icon, color: kPrimary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const GradientButton({
    super.key,
    required this.label,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [kPrimaryDark, kPrimary, kAccent],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLoading ? Colors.grey : kPrimary).withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Amiri',
                  ),
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑥ شاشة الدخول للسائق
// ══════════════════════════════════════════════════════════════════════════════
class DriverSignInScreen extends StatefulWidget {
  const DriverSignInScreen({super.key});
  @override
  State<DriverSignInScreen> createState() => _DriverSignInScreenState();
}

class _DriverSignInScreenState extends State<DriverSignInScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _emailErr = false;
  bool _passErr = false;
  String? _error;

  late AnimationController _logoCtrl, _formCtrl;
  late Animation<double> _logoScale, _logoFade, _formFade;
  late Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _formFade = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic));
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 350), _formCtrl.forward);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _formCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password':
        return 'كلمة السر غير صحيحة';
      case 'invalid-credential':
        return 'البريد أو كلمة السر غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت';
      default:
        return 'حدث خطأ، حاول مرة أخرى';
    }
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() {
      _emailErr = email.isEmpty || !email.contains('@');
      _passErr = pass.length < 6;
      _error = null;
    });

    if (_emailErr || _passErr) return;

    setState(() => _loading = true);

    try {
      ApiClient.setToken(null);
      await DriverService.signIn(email, pass);

      final data = await ApiClient.get(
        '/api/drivers/${FirebaseAuth.instance.currentUser!.uid}',
      );

      if (!mounted) return;

      if (data.isEmpty) {
        setState(() => _error = 'حسابك غير موجود في قاعدة السائقين');
        return;
      }

      if (data['isActive'] != true) {
        setState(() => _error = 'حسابك بانتظار تفعيل الإدارة ⏳');
        return;
      }

      bool canSetPricing = data['canSetPricing'] == true;
      bool hasSetPricing = data['hasSetPricing'] == true;

      if (canSetPricing && !hasSetPricing) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DriverPricingSettingsScreen(isEditMode: false),
          ),
        );
        return;
      }

      await DriverService.updateFcmToken();
      await DriverService.startLocationSharing();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverMainShell()),
        (r) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ _signIn FirebaseAuthException: ${e.code} — ${e.message}');
      setState(() => _error = _authError(e.code));
    } catch (e) {
      debugPrint('❌ _signIn error: $e');
      setState(() => _error = 'حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'استعادة كلمة السر',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        content: NeuTextField(
          controller: ctrl,
          hint: 'البريد الإلكتروني',
          icon: CupertinoIcons.mail,
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: kTextGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: ctrl.text.trim(),
                );
              } catch (_) {}
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم إرسال رابط الاستعادة إلى بريدك',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Amiri'),
                  ),
                ),
              );
            },
            child: const Text(
              'إرسال',
              style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_right, color: kPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 50),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: kBg,
                          shape: BoxShape.circle,
                          boxShadow: neuShadow(blur: 20, offset: 8),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          size: 54,
                          color: kPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'DelivDriver',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kPrimary,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'سجّل دخولك لمتابعة طلبياتك',
                        style: TextStyle(
                          fontSize: 13,
                          color: kTextGrey,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 46),
              FadeTransition(
                opacity: _formFade,
                child: SlideTransition(
                  position: _formSlide,
                  child: Column(
                    children: [
                      NeuTextField(
                        controller: _emailCtrl,
                        hint: 'البريد الإلكتروني',
                        icon: CupertinoIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        hasError: _emailErr,
                      ),
                      const SizedBox(height: 14),
                      NeuTextField(
                        controller: _passCtrl,
                        hint: 'كلمة السر',
                        icon: CupertinoIcons.lock,
                        obscure: _obscure,
                        hasError: _passErr,
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            color: kTextGrey,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _showForgotPassword,
                          child: const Text(
                            'نسيت كلمة السر؟',
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: kDanger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kDanger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: kDanger,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: kDanger,
                                    fontSize: 13,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 22),
                      GradientButton(
                        label: 'دخول',
                        isLoading: _loading,
                        onTap: _signIn,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DriverRegisterScreen(),
                              ),
                            ),
                            child: const Text(
                              'إنشاء حساب سائق جديد',
                              style: TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'رجوع للقائمة',
                          style: TextStyle(
                            color: kTextGrey,
                            fontFamily: 'Amiri',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑦ شاشة إنشاء حساب السائق
// ══════════════════════════════════════════════════════════════════════════════
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});
  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen>
    with TickerProviderStateMixin {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscure1 = true;
  String? _error;
  final Map<String, bool> _fieldErrors = {};

  String _vehicleType = '';
  bool _acceptedTerms = false;
  final List<String> _vehicleTypes = ['motorcycle', 'car', 'harbin', 'fourgon'];

  String _cityName = '';
  String _cityNameAr = '';
  String _cityNameFr = '';
  double? _cityLat, _cityLng;
  bool _detectingLocation = false;

  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [
      _firstCtrl,
      _lastCtrl,
      _phoneCtrl,
      _emailCtrl,
      _passCtrl,
      _confCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _detectCity() async {
    setState(() {
      _detectingLocation = true;
      _cityName = '';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _detectingLocation = false);
          _showSnackBar('يجب السماح بالوصول للموقع');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _detectingLocation = false);
        _showSnackBar('الرجاء السماح بالموقع من الإعدادات');
        await Geolocator.openAppSettings();
        return;
      }
    } catch (_) {}

    try {
      // 2. جلب الإحداثيات (بدلنا Accuracy لـ low باش تكون سريعة وماتتبلوكااش)
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 10));

      _cityLat = pos.latitude;
      _cityLng = pos.longitude;

      // 3. الاتصال بالخارج لجلب اسم المدينة
      final headers = {'User-Agent': 'delivery_app_v2'};
      final urlAr =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=ar';
      final urlFr =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=fr';

      final resps = await Future.wait([
        http.get(Uri.parse(urlAr), headers: headers),
        http.get(Uri.parse(urlFr), headers: headers),
      ]);

      if (resps[0].statusCode == 200) {
        final jsonAr = jsonDecode(resps[0].body);
        final jsonFr = jsonDecode(resps[1].body);
        final addrAr = jsonAr['address'] ?? {};

        String findCity(Map addr) =>
            addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['state'] ??
            '';

        setState(() {
          _cityNameAr = findCity(addrAr);
          _cityNameFr = findCity(jsonFr['address'] ?? {});
          _cityName = _cityNameAr.isNotEmpty ? _cityNameAr : _cityNameFr;
          _detectingLocation = false;
        });
        _showSnackBar('تم تحديد الموقع بنجاح ✅');
      }
    } catch (e) {
      setState(() => _detectingLocation = false);
      _showSnackBar('تأكد من تشغيل الـ GPS والإنترنت');
      debugPrint("Error details: $e");
    }
  }

  bool _validate() {
    final errors = <String, bool>{};
    String? firstError;

    if (_firstCtrl.text.trim().isEmpty) {
      errors['first'] = true;
      firstError ??= 'الاسم مطلوب';
    }
    if (_lastCtrl.text.trim().isEmpty) {
      errors['last'] = true;
      firstError ??= 'اللقب مطلوب';
    }
    if (_phoneCtrl.text.trim().length < 9) {
      errors['phone'] = true;
      firstError ??= 'رقم الهاتف يجب أن لا يقل عن 9 أرقام';
    }
    if (!_emailCtrl.text.contains('@') || _emailCtrl.text.isEmpty) {
      errors['email'] = true;
      firstError ??= 'البريد الإلكتروني غير صالح';
    }
    if (_passCtrl.text.length < 8) {
      errors['pass'] = true;
      firstError ??= 'كلمة السر يجب أن لا تقل عن 8 أحرف';
    }
    if (_confCtrl.text != _passCtrl.text || _confCtrl.text.isEmpty) {
      errors['conf'] = true;
      firstError ??= 'تأكيد كلمة السر غير مطابق';
    }
    if (_vehicleType.isEmpty) {
      errors['vehicle'] = true;
      firstError ??= 'يرجى اختيار نوع المركبة';
    }
    if (!_acceptedTerms) {
      errors['terms'] = true;
      firstError ??= 'يجب الموافقة على الشروط والقوانين';
    }

    setState(() {
      _fieldErrors.clear();
      _fieldErrors.addAll(errors);
    });

    if (firstError != null) _showSnackBar(firstError, isError: true);
    return errors.isEmpty;
  }

  String _authError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'هذا البريد الإلكتروني مسجل مسبقاً!';
        case 'weak-password':
          return 'كلمة السر ضعيفة جداً';
        case 'invalid-email':
          return 'صيغة البريد الإلكتروني غير صحيحة';
        case 'network-request-failed':
          return 'تحقق من الاتصال بالإنترنت';
        default:
          return 'خطأ في المصادقة: ${e.message}';
      }
    }
    return 'حدث خطأ غير متوقع';
  }

  Future<void> _register() async {
    _fieldErrors.clear();
    if (!_validate()) return;
    if (_cityName.isEmpty || _cityNameAr.isEmpty || _cityLat == null) {
      _showSnackBar('يجب تحديد موقعك أولاً', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await DriverService.register(
        email: _emailCtrl.text.trim(),
        pass: _passCtrl.text.trim(),
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      final uid = DriverService.uid;
      if (uid != null) {
        await ApiClient.put('/api/drivers/$uid', {
          'vehicleType': _vehicleType,
          'cityNameAr': _cityNameAr,
          'cityNameFr': _cityNameFr,
          'cityName': _cityName,
          'cityLat': _cityLat,
          'cityLng': _cityLng,
          'lat': _cityLat,
          'lng': _cityLng,
          'isActive': false,
          'isOnline': false,
          'isVerified': true,
          'hasSetPricing': false,
          'canSetPricing': false,
          'totalDeliveries': 0,
          'cancelledDeliveries': 0,
          'totalEarnings': 0,
          'photoUrl': '',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'lastCommissionResetEarnings': 0,
        });
      }

      _showSnackBar('تم إنشاء حسابك بنجاح! يرجى انتظار تفعيل الإدارة ✅');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverSignInScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ _register error: $e');
      final errorMsg = _authError(e);
      setState(() {
        _error = errorMsg;
        _loading = false;
      });
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri'),
        ),
        backgroundColor: isError ? kDanger : kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: neuBox(radius: 12),
            child: const Icon(
              CupertinoIcons.chevron_right,
              color: kPrimary,
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'إنشاء حساب سائق',
          style: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: FadeTransition(
            opacity: _pageFade,
            child: SlideTransition(
              position: _pageSlide,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: kBg,
                      shape: BoxShape.circle,
                      boxShadow: neuShadow(blur: 14, offset: 6),
                    ),
                    child: const Icon(
                      CupertinoIcons.car_detailed,
                      size: 40,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _buildVehicleTypeDropdown(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: NeuTextField(
                          controller: _lastCtrl,
                          hint: 'اللقب',
                          icon: CupertinoIcons.person,
                          hasError: _fieldErrors['last'] ?? false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuTextField(
                          controller: _firstCtrl,
                          hint: 'الاسم',
                          icon: CupertinoIcons.person,
                          hasError: _fieldErrors['first'] ?? false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    controller: _phoneCtrl,
                    hint: 'رقم الهاتف',
                    icon: CupertinoIcons.phone,
                    keyboardType: TextInputType.phone,
                    hasError: _fieldErrors['phone'] ?? false,
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    controller: _emailCtrl,
                    hint: 'البريد الإلكتروني',
                    icon: CupertinoIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    hasError: _fieldErrors['email'] ?? false,
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    controller: _passCtrl,
                    hint: 'كلمة السر',
                    icon: CupertinoIcons.lock,
                    obscure: _obscure,
                    hasError: _fieldErrors['pass'] ?? false,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        color: kTextGrey,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    controller: _confCtrl,
                    hint: 'تأكيد كلمة السر',
                    icon: CupertinoIcons.lock,
                    obscure: _obscure1,
                    hasError: _fieldErrors['conf'] ?? false,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure1 = !_obscure1),
                      child: Icon(
                        _obscure1
                            ? CupertinoIcons.eye_slash
                            : CupertinoIcons.eye,
                        color: kTextGrey,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildLocationButton(),
                  const SizedBox(height: 14),
                  _buildTermsCheckbox(),
                  if (_error != null) _errorBox(_error!),
                  const SizedBox(height: 30),
                  GradientButton(
                    label: 'إنشاء الحساب',
                    isLoading: _loading,
                    onTap: _register,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'ملاحظة: حسابك سيخضع لمراجعة الإدارة قبل التفعيل النهائي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 11,
                        color: kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: _detectingLocation ? null : _detectCity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _cityName.isNotEmpty ? kSuccess.withOpacity(0.05) : kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _detectingLocation
                ? kPrimary
                : (_cityName.isNotEmpty ? kSuccess : kPrimary.withOpacity(0.2)),
            width: 1.5,
          ),
          boxShadow: neuShadow(blur: 5, offset: 2),
        ),
        child: Row(
          children: [
            if (_detectingLocation)
              const CupertinoActivityIndicator()
            else
              Icon(
                _cityName.isNotEmpty
                    ? Icons.check_circle
                    : CupertinoIcons.location_circle,
                color: _cityName.isNotEmpty ? kSuccess : kPrimary,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _detectingLocation
                    ? 'جاري جلب موقعك.. انتظر قليلاً'
                    : (_cityName.isNotEmpty
                          ? 'موقعك: $_cityName'
                          : 'اضغط لتحديد موقعك الجغرافي'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13,
                  fontWeight: _cityName.isNotEmpty
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _cityName.isNotEmpty ? kSuccess : kTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeDropdown() {
    return GestureDetector(
      onTap: () => _showVehiclePicker(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _vehicleType.isNotEmpty ? kPrimary.withOpacity(0.05) : kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _fieldErrors['vehicle'] == true
                ? kDanger
                : (_vehicleType.isNotEmpty
                      ? kPrimary
                      : kPrimary.withOpacity(0.2)),
            width: 1.5,
          ),
          boxShadow: neuShadow(blur: 5, offset: 2),
        ),
        child: Row(
          children: [
            Icon(
              _vehicleType.isNotEmpty
                  ? Icons.check_circle
                  : CupertinoIcons.car_detailed,
              color: _vehicleType.isNotEmpty ? kSuccess : kPrimary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _vehicleType.isNotEmpty ? _vehicleLabel(_vehicleType) : 'اختر نوع المركبة',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13,
                  fontWeight: _vehicleType.isNotEmpty
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _vehicleType.isNotEmpty ? kTextDark : kTextGrey,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_down, color: kPrimary, size: 18),
          ],
        ),
      ),
    );
  }

  String _vehicleLabel(String v) {
    switch (v) {
      case 'motorcycle': return 'دراجة نارية';
      case 'car': return 'سيارة';
      case 'harbin': return 'هاربين';
      case 'fourgon': return 'فورغو';
      default: return v;
    }
  }

  void _showVehiclePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'اختر نوع المركبة',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _vehicleTypes.map((v) {
            final selected = _vehicleType == v;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _vehicleType = v);
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? kPrimary.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? kPrimary : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? kPrimary : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _vehicleLabel(v),
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected ? kPrimary : kTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: _showTermsDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: _fieldErrors['terms'] == true
              ? kDanger.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: _fieldErrors['terms'] == true
              ? Border.all(color: kDanger.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _acceptedTerms ? Icons.check_circle : Icons.check_circle_outline,
              color: _acceptedTerms ? kSuccess : kTextGrey,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'أوافق على جميع الشروط والقوانين',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13,
                  fontWeight: _acceptedTerms
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _acceptedTerms ? kSuccess : kTextDark,
                ),
              ),
            ),
            Icon(CupertinoIcons.doc_text, color: kPrimary, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showTermsDialog() async {
    double commissionPercent = 0;
    try {
      try {
        final configData = await ApiClient.get('/api/config');
        commissionPercent =
            (configData[_vehicleType.isNotEmpty
                        ? 'commission_${_vehicleType.replaceAll(' ', '_')}'
                        : ''] ??
                    configData['defaultCommissionPercent'] ??
                    0)
                .toDouble();
      } catch (_) {}
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TermsDialog(
        commissionPercent: commissionPercent,
        onAgreed: () {
          setState(() => _acceptedTerms = true);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kDanger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: kDanger,
          fontSize: 12,
          fontFamily: 'Amiri',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑧ شاشة التحقق من البريد الإلكتروني
// ══════════════════════════════════════════════════════════════════════════════
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  bool _checking = false;
  bool _canResendEmail = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerification(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
    }
    final updatedUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '🔍 _checkVerification — uid: ${updatedUser?.uid}, emailVerified: ${updatedUser?.emailVerified}',
    );
    if (updatedUser != null && updatedUser.emailVerified && mounted) {
      _timer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverSignInScreen()),
      );
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: kBg,
                  shape: BoxShape.circle,
                  boxShadow: neuShadow(blur: 20, offset: 8),
                ),
                child: const Icon(
                  CupertinoIcons.mail_solid,
                  size: 54,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'تحقق من بريدك الإلكتروني',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'أرسلنا لك رابط التفعيل. افتحه وعد هنا لتكمل تسجيل دخولك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextGrey,
                  fontFamily: 'Amiri',
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              if (_checking)
                const CircularProgressIndicator(color: kPrimary)
              else
                GradientButton(label: 'تحقق الآن', onTap: _checkVerification),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _canResendEmail
                    ? () async {
                        setState(() => _canResendEmail = false);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          await user?.sendEmailVerification();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم إعادة إرسال رابط التفعيل',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Amiri'),
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'فشل الإرسال: $e',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        await Future.delayed(const Duration(seconds: 30));
                        if (mounted) setState(() => _canResendEmail = true);
                      }
                    : null,
                child: const Text(
                  'إعادة الإرسال',
                  style: TextStyle(color: kPrimary, fontFamily: 'Amiri'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // أضف async هنا
                  await FirebaseAuth.instance
                      .signOut(); // أضف await هنا لضمان الخروج التام
                  if (mounted) {
                    // وجهه لصفحة تسجيل الدخول مباشرة وليس لمسار عام
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const DriverSignInScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: kTextGrey, fontFamily: 'Amiri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑨ DriverMainShell
// ══════════════════════════════════════════════════════════════════════════════
class DriverMainShell extends StatefulWidget {
  const DriverMainShell({super.key});
  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell> {
  int _index = 0;
  int _activeOrdersCount = 0;

  final List<Widget> _pages = const [
    DriverDashboardScreen(),
    DriverActiveOrdersScreen(),
    DriverNotificationsScreen(),
    DriverProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveCount();
    // ← استعمل keys مختلفة على مستوى Shell
    SocketClient().on('order:updated_shell', (_) => _loadActiveCount());
    SocketClient().on('order:created_shell', (_) => _loadActiveCount());
    SocketClient().on(
      'project_delivery:updated_shell',
      (_) => _loadActiveCount(),
    );
    SocketClient().on(
      'project_delivery:created_shell',
      (_) => _loadActiveCount(),
    );
    SocketClient().on('transport:updated_shell', (_) => _loadActiveCount());
    SocketClient().on('transport:created_shell', (_) => _loadActiveCount());
    SocketClient().on('service:updated_shell', (_) => _loadActiveCount());
    SocketClient().on('service:created_shell', (_) => _loadActiveCount());
  }

  @override
  void dispose() {
    SocketClient().off('order:updated_shell');
    SocketClient().off('order:created_shell');
    SocketClient().off('project_delivery:updated_shell');
    SocketClient().off('project_delivery:created_shell');
    SocketClient().off('transport:updated_shell');
    SocketClient().off('transport:created_shell');
    SocketClient().off('service:updated_shell');
    SocketClient().off('service:created_shell');
    super.dispose();
  }

  Future<void> _loadActiveCount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final orders = await ApiClient.getList(
        '/api/orders?driverId=$uid&status=accepted,purchased,onway',
      );
      final projects = await ApiClient.getList(
        '/api/project-deliveries?driverId=$uid&status=accepted,onway_to_store,picked_up,onway',
      );
      final transports = await ApiClient.getList(
        '/api/transport-orders?driverId=$uid&status=accepted,onway',
      );
      final services = await ApiClient.getList(
        '/api/service-orders?driverId=$uid&status=accepted,onway',
      );
      final total =
          orders.length + projects.length + transports.length + services.length;
      if (mounted) setState(() => _activeOrdersCount = total);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    const tabs = [
      (Icons.home_rounded, 'الرئيسية'),
      (Icons.local_shipping_rounded, 'طلبياتي'),
      (Icons.notifications_rounded, 'الإشعارات'),
      (Icons.person_rounded, 'حسابي'),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFF3D0063), Color(0xFF5B0094), Color(0xFF8E24AA)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.4),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final selected = _index == i;

              // ── badge على "طلبياتي" (index 1) ──
              Widget iconWidget = Icon(
                tabs[i].$1,
                color: selected ? Colors.white : Colors.white.withOpacity(0.5),
                size: 22,
              );
              if (i == 1 && _activeOrdersCount > 0) {
                iconWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    iconWidget,
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$_activeOrdersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                  if (i == 1) _loadActiveCount();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: selected ? 16 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Text(
                          tabs[i].$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑩ DriverDashboardScreen
// ══════════════════════════════════════════════════════════════════════════════
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _toggling = false;
  int _refreshKey = 0;
  bool _online = false;
  bool _synced = true;
  late final void Function(dynamic) _onServiceUpdated;
  late final void Function(dynamic) _onServiceCreated;
  late final void Function(dynamic) _onTransportUpdated;
  late final void Function(dynamic) _onTransportCreated;
  late final void Function(dynamic) _onOrderUpdated;
  late final void Function(dynamic) _onOrderCreated;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ✅ اضف هاذ الأسطر هنا باش يبدا السائق يستقبل الإشعارات
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (DriverService.uid != null) {
        await DriverNotificationHelper.init(DriverService.uid!);
        await DriverService.updateFcmToken(); // تخزين التوكن في الفايربيز
      }
    });

    _onServiceUpdated = (_) { setState(() => _refreshKey++); };
    _onServiceCreated = (_) { setState(() => _refreshKey++); };
    _onTransportUpdated = (_) { setState(() => _refreshKey++); };
    _onTransportCreated = (_) { setState(() => _refreshKey++); };
    _onOrderUpdated = (_) { setState(() => _refreshKey++); };
    _onOrderCreated = (_) { setState(() => _refreshKey++); };
    SocketClient().on('service:updated', _onServiceUpdated);
    SocketClient().on('service:created', _onServiceCreated);
    SocketClient().on('transport:updated', _onTransportUpdated);
    SocketClient().on('transport:created', _onTransportCreated);
    SocketClient().on('order:updated', _onOrderUpdated);
    SocketClient().on('order:created', _onOrderCreated);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SocketClient().off('service:updated', _onServiceUpdated);
    SocketClient().off('service:created', _onServiceCreated);
    SocketClient().off('transport:updated', _onTransportUpdated);
    SocketClient().off('transport:created', _onTransportCreated);
    SocketClient().off('order:updated', _onOrderUpdated);
    SocketClient().off('order:created', _onOrderCreated);
    super.dispose();
  }

  Future<void> _toggleOnline(bool current) async {
    HapticFeedback.mediumImpact();
    final next = !current;
    setState(() => _toggling = true);

    await DriverService.toggleOnline(next);

    if (mounted)
      setState(() {
        _toggling = false;
        _online = next;
        _synced = false;
      });

    if (next) {
      await DriverService.startLocationSharing();
    } else {
      DriverService.stopLocationSharing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverModel?>(
      stream: DriverService.driverStream(),
      builder: (ctx, snap) {
        final driver = snap.data;
        if (driver != null && mounted) {
          if (_synced || driver.isOnline == _online) {
            _online = driver.isOnline;
            _synced = true;
          }
        }
        return Scaffold(
          backgroundColor: kBg,
          body: SafeArea(
            child: Column(
              children: [
                const ConnectivityBanner(),
                Expanded(
                  child: RawScrollbar(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        _buildHeader(driver),
                        const SizedBox(height: 12),
                        _buildToggleButton(driver),
                        const SizedBox(height: 16),
                        if (_online)
                          _UnifiedIncomingList(
                            driver: driver!,
                            key: ValueKey('orders_$_refreshKey'),
                          )
                        else
                          _buildOfflineState(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(DriverModel? driver) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: neuBox(radius: 12, blur: 6, offset: 2),
          child: driver?.photoUrl.isNotEmpty == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                    imageUrl: driver!.photoUrl,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(
                  CupertinoIcons.person_circle,
                  color: kPrimary,
                  size: 30,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                driver == null
                    ? 'جاري التحميل...'
                    : 'مرحباً، ${driver.firstName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                  fontFamily: 'Amiri',
                ),
              ),
              if (driver?.cityName.isNotEmpty == true)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        driver!.cityName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kPrimary,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      CupertinoIcons.location_solid,
                      size: 10,
                      color: kPrimary,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(DriverModel? driver) {
    return GestureDetector(
      onTap: _toggling ? null : () => _toggleOnline(_online),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: _online ? kSuccess.withOpacity(0.12) : kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _online ? kSuccess.withOpacity(0.3) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: _online
              ? [BoxShadow(color: kSuccess.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : neuShadow(blur: 8, offset: 4),
        ),
        child: _toggling
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: kPrimary,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _online ? kSuccess : Colors.grey.shade300,
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      alignment: _online ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _online ? 'متصل 🟢' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _online ? kSuccess : kTextGrey,
                            fontFamily: 'Amiri',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _online ? 'أنت مرئي للزبائن' : 'اضغط لكي تظهر عند الزبائن',
                          style: TextStyle(
                            fontSize: 12,
                            color: _online ? kSuccess.withOpacity(0.7) : kTextGrey,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kBg,
            shape: BoxShape.circle,
            boxShadow: neuShadow(blur: 14, offset: 6),
          ),
          child: Icon(
            Icons.person_off_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'أنت مخفي حالياً',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kTextDark,
            fontFamily: 'Amiri',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اضغط على المفتاح أعلاه لتظهر للزبائن وتبدأ باستقبال الطلبيات',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextGrey, fontSize: 12, fontFamily: 'Amiri'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DriverOrder Model
// ══════════════════════════════════════════════════════════════════════════════
class DriverOrder {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userGender;
  final bool userVerified;
  final bool phoneHidden;
  final String address;
  final String doorNumber;
  final String doorColor;
  final String locationImage;
  final String housingType;
  final String floor;
  final double total;
  final double deliveryFee;
  final double subtotal;
  final List<DriverOrderItem> items;
  final Color storeColor;
  final double? userLat;
  final double? userLng;
  final String driverNote;

  DriverOrder({
    required this.id,
    this.userId = '',
    required this.userName,
    this.userPhone = '',
    this.userGender = 'male',
    this.userVerified = false,
    this.phoneHidden = false,
    required this.address,
    this.doorNumber = '',
    this.doorColor = '',
    this.locationImage = '',
    this.housingType = '',
    this.floor = '',
    required this.total,
    this.deliveryFee = 0,
    this.subtotal = 0,
    this.items = const [],
    this.storeColor = kPrimary,
    this.userLat,
    this.userLng,
    this.driverNote = '',
  });

  factory DriverOrder.fromMap(String id, Map<String, dynamic> d) {
    final storeColorVal = d['storeColor'];
    return DriverOrder(
      id: id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? 'زبون',
      userPhone: d['userPhone'] ?? '',
      userGender: d['userGender'] ?? 'male',
      userVerified: d['userVerified'] ?? false,
      phoneHidden: d['phoneHidden'] ?? false,
      address: d['address'] ?? 'بدون عنوان',
      doorNumber: d['doorNumber'] as String? ?? '',
      doorColor: d['doorColor'] as String? ?? '',
      locationImage: d['locationImage'] as String? ?? '',
      housingType: d['housingType'] as String? ?? '',
      floor: d['floor'] as String? ?? '',
      total: (d['total'] ?? 0).toDouble(),
      deliveryFee: (d['deliveryFee'] ?? 0).toDouble(),
      subtotal: (d['subtotal'] ?? 0).toDouble(),
      userLat: d['userLat']?.toDouble(),
      userLng: d['userLng']?.toDouble(),
      driverNote: d['driverNote'] ?? '',
      storeColor: storeColorVal is String
          ? Color(int.parse(storeColorVal))
          : kPrimary,
      items: (d['items'] as List? ?? [])
          .map((i) => DriverOrderItem.fromMap(i))
          .toList(),
    );
  }

  double distanceKmFrom(double dLat, double dLng) {
    if (userLat == null || userLng == null || dLat == 0) return 0;
    return Geolocator.distanceBetween(dLat, dLng, userLat!, userLng!) / 1000;
  }
}

class DriverOrderItem {
  final String name;
  final int quantity;
  final double price;
  final String image;
  final String storeName;
  final String capacite;
  final String templateName;
  final String categoryName;
  final String note;

  DriverOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.image = '',
    this.storeName = '',
    this.capacite = '',
    this.templateName = '',
    this.categoryName = '',
    this.note = '',
  });

  factory DriverOrderItem.fromMap(Map m) => DriverOrderItem(
    name: m['name'] ?? '',
    quantity: m['quantity'] ?? 1,
    price: (m['finalPrice'] ?? m['price'] ?? m['prix'] ?? 0).toDouble(),
    image: m['image'] ?? '',
    storeName: m['storeName'] ?? '',
    capacite: m['capacite'] ?? '',
    templateName: m['templateName'] ?? '',
    categoryName: m['categoryName'] ?? '',
    note: m['note'] ?? '',
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _IncomingOrdersList
// ══════════════════════════════════════════════════════════════════════════════
class _IncomingOrdersList extends StatelessWidget {
  final DriverModel driver;
  const _IncomingOrdersList({required this.driver});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadOrders(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(color: kPrimary),
          );
        }
        final docs = snap.data ?? [];
        final filtered = docs.where((d) {
          final rejected = List<String>.from(d['rejectedBy'] ?? []);
          return !rejected.contains(driver.uid);
        }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: neuBox(radius: 50),
                  child: Icon(
                    CupertinoIcons.clock,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد طلبيات موجهة لك حالياً',
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            return _IncomingOrderCard(
              order: DriverOrder.fromMap('${filtered[i]['_id']}', filtered[i]),
              driverLat: driver.lat,
              driverLng: driver.lng,
              animDelay: i * 70,
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    try {
      final result = await ApiClient.getList(
        '/api/orders?driverId=${driver.uid}&status=pending',
      );
      return result.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ProjectDeliveryList — قائمة توصيليات المشاريع للسائق
// ══════════════════════════════════════════════════════════════════════════════
class _ProjectDeliveryList extends StatelessWidget {
  final DriverModel driver;
  const _ProjectDeliveryList({required this.driver});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadDeliveries(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(color: kPrimary),
          );
        }
        final docs = snap.data ?? [];
        final filtered = docs.where((d) {
          final rejected = List<String>.from(d['rejectedBy'] ?? []);
          return !rejected.contains(driver.uid);
        }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: neuBox(radius: 50),
                  child: Icon(
                    CupertinoIcons.clock,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد توصيليات مشاريع',
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            return _ProjectDeliveryCard(
              deliveryId: '${filtered[i]['_id']}',
              data: filtered[i],
              driverLat: driver.lat,
              driverLng: driver.lng,
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadDeliveries() async {
    try {
      final result = await ApiClient.getList(
        '/api/project-deliveries?driverId=${driver.uid}&status=pending',
      );
      return result.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _UnifiedIncomingList — قائمة موحّدة: طلبيات + توصيليات مشاريع
// ══════════════════════════════════════════════════════════════════════════════
String _mapVehicleToTransportType(String vehicleType) {
  switch (vehicleType) {
    case 'car':
      return 'car';
    case 'minibus':
    case 'harbin':
      return 'transport';
    case 'truck':
    case 'fourgon':
      return 'truck';
    default:
      return vehicleType;
  }
}

List<String> _getTransportTypesForDriver(String vehicleType) {
  final mapped = _mapVehicleToTransportType(vehicleType);
  return {vehicleType, mapped}.where((t) => t.isNotEmpty).toList();
}

class _UnifiedIncomingList extends StatefulWidget {
  final DriverModel driver;
  const _UnifiedIncomingList({super.key, required this.driver});

  @override
  State<_UnifiedIncomingList> createState() => _UnifiedIncomingListState();
}

class _UnifiedIncomingListState extends State<_UnifiedIncomingList> {
  int _refreshKey = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _refreshKey++);
    });
    SocketClient().on('order:created', (_) {
      if (mounted) setState(() => _refreshKey++);
    });
    SocketClient().on('order:updated', (_) {
      if (mounted) setState(() => _refreshKey++);
    });
    SocketClient().on('project_delivery:created', (_) {
      if (mounted) setState(() => _refreshKey++);
    });
    SocketClient().on('transport:created', (_) {
      if (mounted) setState(() => _refreshKey++);
    });
    SocketClient().on('service:created', (_) {
      if (mounted) setState(() => _refreshKey++);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    SocketClient().off('order:created');
    SocketClient().off('order:updated');
    SocketClient().off('project_delivery:created');
    SocketClient().off('transport:created');
    SocketClient().off('service:created');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // نفس الكود القديم بالضبط، بس أضف key للـ FutureBuilder:
    final transportTypes = _getTransportTypesForDriver(
      widget.driver.vehicleType,
    );
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('unified_$_refreshKey'), // ← هذا السطر الجديد
      future: _loadAll(transportTypes),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(color: kPrimary),
          );
        }
        final allDocs = snap.data ?? [];
        if (allDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: neuBox(radius: 50),
                  child: Icon(
                    CupertinoIcons.clock,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد طلبيات موجهة لك حالياً',
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allDocs.length,
          itemBuilder: (_, i) {
            final d = allDocs[i];
            final isProject = d.containsKey('projectId');
            final isTransport = d.containsKey('transportType');
            final isService = d.containsKey('serviceType');
            if (isProject) {
              return _ProjectDeliveryCard(
                deliveryId: '${d['_id']}',
                data: d,
                driverLat: widget.driver.lat,
                driverLng: widget.driver.lng,
                animDelay: i * 70,
              );
            }
            if (isTransport) {
              return _TransportOrderCard(data: d, docId: '${d['_id']}');
            }
            if (isService) {
              return _ServiceOrderCard(data: d, docId: '${d['_id']}');
            }
            final order = DriverOrder.fromMap('${d['_id']}', d);
            return _IncomingOrderCard(
              order: order,
              driverLat: widget.driver.lat,
              driverLng: widget.driver.lng,
              animDelay: i * 70,
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAll(
    List<String> transportTypes,
  ) async {
    try {
      final results = await Future.wait([
        ApiClient.getList(
          '/api/orders?driverId=${widget.driver.uid}&status=pending',
        ),
        ApiClient.getList(
          '/api/project-deliveries?driverId=${widget.driver.uid}&status=pending',
        ),
        if (transportTypes.isNotEmpty)
          ApiClient.getList(
            '/api/transport-orders?status=pending&transportType=${transportTypes.join(',')}',
          ),
        ApiClient.getList(
          '/api/service-orders?driverId=${widget.driver.uid}&status=pending',
        ),
      ]);
      final allDocs = <Map<String, dynamic>>[];
      for (final list in results) {
        for (final item in list) {
          final d = item as Map<String, dynamic>;
          final rejected = List<String>.from(d['rejectedBy'] ?? []);
          if (!rejected.contains(widget.driver.uid)) {
            allDocs.add(d);
          }
        }
      }
      allDocs.sort((a, b) {
        final ta = a['createdAt'] as String?;
        final tb = b['createdAt'] as String?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return allDocs.take(20).toList();
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ProjectDeliveryCard — كارد توصيلية مشروع للسائق
// ══════════════════════════════════════════════════════════════════════════════

class _ProjectDeliveryCard extends StatefulWidget {
  final String deliveryId;
  final Map<String, dynamic> data;
  final double driverLat;
  final double driverLng;
  final int animDelay;

  const _ProjectDeliveryCard({
    required this.deliveryId,
    required this.data,
    required this.driverLat,
    required this.driverLng,
    this.animDelay = 0,
  });

  @override
  State<_ProjectDeliveryCard> createState() => _ProjectDeliveryCardState();
}

class _ProjectDeliveryCardState extends State<_ProjectDeliveryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.animDelay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  double get _distKm {
    if (widget.driverLat == 0 || widget.driverLng == 0) return 0;
    final sLat = (widget.data['storeLat'] ?? 0).toDouble();
    final sLng = (widget.data['storeLng'] ?? 0).toDouble();
    if (sLat == 0 || sLng == 0) return 0;
    return Geolocator.distanceBetween(
          widget.driverLat,
          widget.driverLng,
          sLat,
          sLng,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final storeName = d['storeName'] ?? '';
    final customerName = d['customerName'] ?? 'زبون';
    final totalPrice = (d['totalPrice'] ?? 0).toDouble();

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: GestureDetector(
          onTap: () => _showDetail(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8B1C8).withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 8,
                  offset: Offset(-3, -3),
                ),
              ],
              border: Border.all(color: kPrimary.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.bag_fill,
                    color: kPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: kTextDark,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextGrey,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kSuccess.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${totalPrice.toInt()} DA',
                    style: const TextStyle(
                      color: kSuccess,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectDeliveryDetailSheet(
        deliveryId: widget.deliveryId,
        data: widget.data,
        driverLat: widget.driverLat,
        driverLng: widget.driverLng,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ProjectDeliveryDetailSheet — تفاصيل توصيلية مشروع للسائق
// ══════════════════════════════════════════════════════════════════════════════
class _ProjectDeliveryDetailSheet extends StatefulWidget {
  final String deliveryId;
  final Map<String, dynamic> data;
  final double driverLat;
  final double driverLng;

  const _ProjectDeliveryDetailSheet({
    required this.deliveryId,
    required this.data,
    required this.driverLat,
    required this.driverLng,
  });

  @override
  State<_ProjectDeliveryDetailSheet> createState() =>
      _ProjectDeliveryDetailSheetState();
}

class _ProjectDeliveryDetailSheetState
    extends State<_ProjectDeliveryDetailSheet> {
  bool _accepting = false;
  bool _counterOffering = false;
  final TextEditingController _counterPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _counterPriceCtrl.dispose();
    super.dispose();
  }

  double get _distKm {
    if (widget.driverLat == 0 || widget.driverLng == 0) return 0;
    final sLat = (widget.data['storeLat'] ?? 0).toDouble();
    final sLng = (widget.data['storeLng'] ?? 0).toDouble();
    if (sLat == 0 || sLng == 0) return 0;
    return Geolocator.distanceBetween(
          widget.driverLat,
          widget.driverLng,
          sLat,
          sLng,
        ) /
        1000;
  }

Future<void> _accept() async {
  setState(() => _accepting = true);
  HapticFeedback.mediumImpact();
  final ok = await DriverService.acceptProjectDelivery(widget.deliveryId);
    if (mounted) {
    if (ok) {
      // إشعار للزبون بأن السائق قبل التوصيلية
      final userId = widget.data['userId'];
      if (userId != null && userId is String && userId.isNotEmpty) {
        FCMHelper.sendToUser(
          userId: userId,
          title: '🚚 تم تعيين سائق لطلبك',
          body: 'السائق ${widget.data['driverName'] ?? ''} في طريقه إليك',
          data: {'type': 'driver_accepted'},
        );
      }
      // إشعار لصاحبة المشروع بأن السائق قبل التوصيلية
      final storeOwnerId = widget.data['storeOwnerId'];
      if (storeOwnerId != null && storeOwnerId is String && storeOwnerId.isNotEmpty) {
        FCMHelper.sendToUser(
          userId: storeOwnerId,
          title: '✅ السائق قبل التوصيلية',
          body: 'السائق ${widget.data['driverName'] ?? ''} قبل توصيلية ${widget.data['storeName'] ?? ''}',
          data: {'type': 'project_delivery_accepted', 'deliveryId': widget.deliveryId},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ تم قبول التوصيلية بنجاح',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/driver',
        (route) => false,
      );
    } else {
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '❌ فشل قبول التوصيلية، حاول مرة أخرى',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  void _showRejectDialog() {
    String? selected;
    bool showCounterPriceInput = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'سبب الرفض',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                ...kRejectionReasons.map((reason) {
                  final isSel = selected == reason;
                  return GestureDetector(
                    onTap: () => setModal(() {
                      selected = reason;
                      showCounterPriceInput = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: isSel
                          ? BoxDecoration(
                              color: kDanger,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: kDanger.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFB8B1C8).withOpacity(0.6),
                                  blurRadius: 10,
                                  offset: Offset(4, 4),
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 10,
                                  offset: Offset(-4, -4),
                                ),
                              ],
                              border: Border.all(
                                color: kPrimary.withOpacity(0.1),
                              ),
                            ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFFB8B1C8),
                                width: 2,
                              ),
                            ),
                            child: isSel
                                ? const Icon(
                                    Icons.check,
                                    size: 13,
                                    color: kDanger,
                                  )
                                : null,
                          ),
                          const Spacer(),
                          Text(
                            reason,
                            style: TextStyle(
                              color: isSel ? Colors.white : kTextDark,
                              fontSize: 14,
                              fontFamily: 'Amiri',
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => setModal(() {
                    selected = 'السعر غير مناسب';
                    showCounterPriceInput = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: selected == 'السعر غير مناسب'
                        ? BoxDecoration(
                            color: kWarning,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: kWarning.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFB8B1C8).withOpacity(0.6),
                                blurRadius: 10,
                                offset: Offset(4, 4),
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(-4, -4),
                              ),
                            ],
                            border: Border.all(
                              color: kPrimary.withOpacity(0.1),
                            ),
                          ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected == 'السعر غير مناسب'
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(
                              color: selected == 'السعر غير مناسب'
                                  ? Colors.white
                                  : const Color(0xFFB8B1C8),
                              width: 2,
                            ),
                          ),
                          child: selected == 'السعر غير مناسب'
                              ? const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: kWarning,
                                )
                              : null,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'السعر غير مناسب — اقترح سعراً',
                              style: TextStyle(
                                color: selected == 'السعر غير مناسب'
                                    ? Colors.white
                                    : kTextDark,
                                fontSize: 14,
                                fontFamily: 'Amiri',
                                fontWeight: selected == 'السعر غير مناسب'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.money_dollar_circle,
                              color: selected == 'السعر غير مناسب'
                                  ? Colors.white
                                  : kWarning,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (showCounterPriceInput) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: neuShadow(blur: 6, offset: 2),
                      border: Border.all(color: kWarning.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'DA',
                            style: TextStyle(
                              color: kWarning,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _counterPriceCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'أدخل السعر المقترح...',
                              hintStyle: TextStyle(
                                color: Colors.black38,
                                fontFamily: 'Amiri',
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            CupertinoIcons.tag_fill,
                            color: kWarning,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(
                          _counterPriceCtrl.text.trim(),
                        );
                        if (price == null || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'أدخل سعراً صحيحاً',
                                style: TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: kDanger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _counterOffering = true);
                        final driverData = await ApiClient.get(
                          '/api/drivers/${DriverService.uid}',
                        );
                        final driverName =
                            '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
                                .trim();
                        final ok = await DriverService.counterOfferProjectDelivery(
                          deliveryId: widget.deliveryId,
                          proposedPrice: price,
                          driverName: driverName.isNotEmpty
                              ? driverName
                              : 'السائق',
                        );
                        if (mounted) {
                          setState(() => _counterOffering = false);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '✅ تم إرسال عرض السعر'
                                    : '❌ فشل إرسال العرض',
                                style: const TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: ok ? kWarning : kDanger,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kWarning,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'إرسال السعر المقترح',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                if (selected != null && !showCounterPriceInput) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await DriverService.rejectProjectDelivery(
                          widget.deliveryId,
                          selected,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? '❌ تم رفض التوصيلية'
                                  : '❌ فشل الرفض، حاول مرة أخرى',
                              style: const TextStyle(fontFamily: 'Amiri'),
                            ),
                            backgroundColor: kDanger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDanger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'تأكيد الرفض',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final docId = widget.deliveryId;
    final storeName = d['storeName'] ?? '';
    final customerName = d['customerName'] ?? 'زبون';
    final customerPhone = d['customerPhone'] ?? '';
    final customerPhoneHidden = d['phoneHidden'] as bool? ?? false;
    final description = d['description'] ?? '';
    final imageUrl = d['imageUrl'] ?? '';
    final deliveryPrice = (d['deliveryPrice'] ?? 0).toDouble();
    final productPrice = (d['productPrice'] ?? 0).toDouble();
    final totalPrice = (d['totalPrice'] ?? 0).toDouble();
    final dist = _distKm;
    final address = d['customerAddress'] ?? '';
    final note = d['note'] as String? ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${docId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Text(
                  'تفاصيل توصيلية مشروع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: kTextDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _sectionBox(
                    child: Row(
                      children: [
                        if (customerPhone.isNotEmpty && !customerPhoneHidden)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('tel:$customerPhone');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: kSuccess.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kSuccess.withOpacity(0.3)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.phone_fill, color: kSuccess, size: 18),
                                  SizedBox(height: 3),
                                  Text('اتصل', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              customerName.isNotEmpty ? customerName : 'زبون',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Amiri', color: kTextDark),
                            ),
                            if (customerPhone.isNotEmpty && !customerPhoneHidden) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: customerPhone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('تم نسخ الرقم', style: TextStyle(fontFamily: 'Amiri')),
                                      backgroundColor: kPrimary,
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.doc_on_clipboard, color: kPrimary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(customerPhone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Amiri')),
                                  ],
                                ),
                              ),
                            ],
                            if (dist > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.location, color: kPrimary, size: 12),
                                  const SizedBox(width: 4),
                                  Text('${dist.toStringAsFixed(1)} كم منك', style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Amiri')),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kBg,
                            border: Border.all(color: kPrimary, width: 2),
                          ),
                          child: ClipOval(
                            child: Icon(CupertinoIcons.person_crop_circle_fill, color: kPrimary, size: 38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (imageUrl.isNotEmpty) ...[
                          Container(
                            width: double.infinity, height: 160,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                        ],
                        _infoRow(CupertinoIcons.building_2_fill, 'المتجر', storeName),
                        _infoRow(CupertinoIcons.person_fill, 'الزبون', customerName),
                        if (!customerPhoneHidden)
                          _infoRow(CupertinoIcons.phone_fill, 'الهاتف', customerPhone),
                        if (description.isNotEmpty)
                          _infoRow(CupertinoIcons.doc_text_fill, 'الوصف', description),
                        if (note.isNotEmpty)
                          _infoRow(CupertinoIcons.chat_bubble_text, 'ملاحظة', note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        _priceRow('سعر التوصيل', '${deliveryPrice.toInt()} DA', kTextDark),
                        const SizedBox(height: 8),
                        _priceRow('سعر المنتج', '${productPrice.toInt()} DA', kTextGrey),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: Colors.grey.shade300, height: 1),
                        ),
                        _priceRow('الإجمالي', '${totalPrice.toInt()} DA', kPrimary, bold: true, fontSize: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        // موقع المتجر (الاستلام)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final sLat = (d['storeLat'] as num?)?.toDouble();
                                final sLng = (d['storeLng'] as num?)?.toDouble();
                                final hasStore = sLat != null && sLat != 0 && sLng != null && sLng != 0;
                                if (hasStore) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$sLat,$sLng/'));
                                } else if (storeName.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(storeName)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kPrimary, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('المتجر (الاستلام)', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  storeName.isNotEmpty ? storeName : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.building_2_fill, color: kPrimary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // موقع الزبون (التوصيل)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final cLat = (d['customerLat'] as num?)?.toDouble();
                                final cLng = (d['customerLng'] as num?)?.toDouble();
                                final hasCustomer = cLat != null && cLat != 0 && cLng != null && cLng != 0;
                                if (hasCustomer) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$cLat,$cLng/'));
                                } else if (address.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(address)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDanger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kDanger, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('موقع التوصيل', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  address.isNotEmpty ? address : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.location_fill, color: kDanger, size: 18),
                          ],
                        ),
                        if (dist > 0) ...[
                          Divider(color: Colors.grey.shade300, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${dist.toStringAsFixed(1)} كم بينك وبين الزبون', style: TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                              const SizedBox(width: 6),
                              Icon(CupertinoIcons.arrow_right_arrow_left, color: kPrimary, size: 14),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _counterOffering ? null : _showRejectDialog,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.5), blurRadius: 7, offset: const Offset(3, 3)),
                                const BoxShadow(color: Colors.white, blurRadius: 7, offset: Offset(-3, -3)),
                              ],
                            ),
                            child: _counterOffering
                                ? const Center(child: CupertinoActivityIndicator(color: kDanger))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 18),
                                      SizedBox(width: 6),
                                      Text('رفض', style: TextStyle(color: kDanger, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _accepting ? null : _accept,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimary.withOpacity(0.85), kPrimary],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: kPrimary.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: _accepting
                                ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.checkmark_shield, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBox({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kPrimary.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.3), blurRadius: 6, offset: const Offset(3, 3)),
        const BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
      ],
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, color: kTextDark, fontFamily: 'Amiri')),
        ),
        const SizedBox(width: 6),
        Text('$label:', style: const TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
      ],
    ),
  );

  Widget _priceRow(String label, String value, Color color, {bool bold = false, double fontSize = 13}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Amiri')),
        const Spacer(),
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 13, fontFamily: 'Amiri')),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _TransportOrderCard — كارد طلبية نقل (هاربين / فورغو / سيارة)
// ══════════════════════════════════════════════════════════════════════════════
class _TransportOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _TransportOrderCard({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] ?? 'زبون';
    final note = data['note'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final toAddr = data['toAddress'] as String? ?? '';
    final price = (data['price'] as num? ?? 0).toDouble();
    final transportType = data['transportType'] as String? ?? '';
    final hasNote = note.isNotEmpty;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(3, 3),
            ),
            const BoxShadow(
              color: Colors.white,
              blurRadius: 8,
              offset: Offset(-3, -3),
            ),
          ],
          border: Border.all(color: kPrimary.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.bag_fill,
                color: kPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kTextDark,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fromAddr.length > 20
                        ? '${fromAddr.substring(0, 20)}...'
                        : fromAddr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kTextGrey,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasNote)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: kWarning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_text_fill, color: kWarning, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '1',
                      style: TextStyle(
                        color: kWarning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ),
            if (hasNote) const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: price == 0
                    ? Colors.orange.withOpacity(0.12)
                    : kSuccess.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                price == 0 ? 'مجاني' : '${price.toInt()} DA',
                style: TextStyle(
                  color: price == 0 ? Colors.orange : kSuccess,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransportOrderDetailSheet(docId: docId, data: data),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ServiceOrderCard — كارد طلبية توصيل/إحضار للسائق
// ══════════════════════════════════════════════════════════════════════════════

class _ServiceOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _ServiceOrderCard({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] ?? 'زبون';
    final note = data['note'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final price = (data['price'] as num? ?? 0).toDouble();
    final serviceType = data['serviceType'] as String? ?? '';
    final hasNote = note.isNotEmpty;
    final secondaryText = serviceType == 'delivery' ? 'توصيل: $fromAddr' : 'إحضار: $fromAddr';

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(3, 3),
            ),
            const BoxShadow(
              color: Colors.white,
              blurRadius: 8,
              offset: Offset(-3, -3),
            ),
          ],
          border: Border.all(color: kPrimary.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.bag_fill,
                color: kPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kTextDark,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secondaryText.length > 25
                        ? '${secondaryText.substring(0, 25)}...'
                        : secondaryText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kTextGrey,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasNote)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: kWarning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_text_fill, color: kWarning, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '1',
                      style: TextStyle(
                        color: kWarning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ),
            if (hasNote) const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: price == 0
                    ? Colors.orange.withOpacity(0.12)
                    : kSuccess.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                price == 0 ? 'مجاني' : '${price.toInt()} DA',
                style: TextStyle(
                  color: price == 0 ? Colors.orange : kSuccess,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceOrderDetailSheet(docId: docId, data: data),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ServiceOrderDetailSheet — تفاصيل طلبية توصيل/إحضار مع قبول/رفض/تغيير سعر
// ══════════════════════════════════════════════════════════════════════════════

class _ServiceOrderDetailSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ServiceOrderDetailSheet({required this.docId, required this.data});

  @override
  State<_ServiceOrderDetailSheet> createState() =>
      _ServiceOrderDetailSheetState();
}

class _ServiceOrderDetailSheetState extends State<_ServiceOrderDetailSheet> {
  bool _accepting = false;
  bool _rejecting = false;

  final TextEditingController _counterPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _counterPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final userName = d['userName'] ?? 'زبون';
    final userPhone = d['userPhone'] as String? ?? '';
    final userPhoneHidden = d['phoneHidden'] as bool? ?? false;
    final serviceType = d['serviceType'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final fromAddr = d['fromAddress'] as String? ?? '';
    final toAddr = d['toAddress'] as String? ?? '';
    final price = (d['price'] as num? ?? 0).toDouble();
    final orderName = d['orderName'] as String? ?? '';
    final parcelImage = d['parcelImageUrl'] as String? ?? '';
    final fromLat = (d['fromLat'] as num?)?.toDouble();
    final fromLng = (d['fromLng'] as num?)?.toDouble();
    final toLat = (d['toLat'] as num?)?.toDouble();
    final toLng = (d['toLng'] as num?)?.toDouble();
    final hasFromCoords = fromLat != null && fromLat != 0 && fromLng != null && fromLng != 0;
    final hasToCoords = toLat != null && toLat != 0 && toLng != null && toLng != 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${widget.docId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'طلب ${serviceType == 'delivery' ? 'توصيل' : 'إحضار'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _sectionBox(
                    child: Row(
                      children: [
                        if (userPhone.isNotEmpty && !userPhoneHidden)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('tel:$userPhone');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: kSuccess.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kSuccess.withOpacity(0.3)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.phone_fill, color: kSuccess, size: 18),
                                  SizedBox(height: 3),
                                  Text('اتصل', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              userName.isNotEmpty ? userName : 'زبون',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Amiri',
                                color: kTextDark,
                              ),
                            ),
                            if (userPhone.isNotEmpty && !userPhoneHidden) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: userPhone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('تم نسخ الرقم', style: TextStyle(fontFamily: 'Amiri')),
                                      backgroundColor: kPrimary,
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.doc_on_clipboard, color: kPrimary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(userPhone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Amiri')),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kBg,
                            border: Border.all(color: kPrimary, width: 2),
                          ),
                          child: ClipOval(
                            child: Icon(CupertinoIcons.person_crop_circle_fill, color: kPrimary, size: 38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (parcelImage.isNotEmpty) ...[
                          Container(
                            width: double.infinity, height: 160,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(imageUrl: parcelImage, fit: BoxFit.cover),
                            ),
                          ),
                        ],
                        if (orderName.isNotEmpty)
                          _infoRow(CupertinoIcons.bag_fill, 'اسم الطلبية', orderName),
                        _infoRow(CupertinoIcons.location_fill, 'من', fromAddr.isNotEmpty ? fromAddr : 'غير محدد'),
                        _infoRow(Icons.location_on, 'إلى', toAddr.isNotEmpty ? toAddr : 'غير محدد'),
                        if (note.isNotEmpty)
                          _infoRow(CupertinoIcons.doc_text_fill, 'ملاحظة', note),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: Colors.grey.shade300, height: 1),
                        ),
                        _priceRow('الإجمالي', '${price.toInt()} DZD', kPrimary, bold: true, fontSize: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        // موقع الاستلام
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (hasFromCoords) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$fromLat,$fromLng/'));
                                } else if (fromAddr.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(fromAddr)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kPrimary, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('موقع الاستلام', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  fromAddr.isNotEmpty ? fromAddr : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_down_circle_fill, color: kPrimary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // موقع التوصيل
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (hasToCoords) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$toLat,$toLng/'));
                                } else if (toAddr.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(toAddr)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDanger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kDanger, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('موقع التوصيل', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  toAddr.isNotEmpty ? toAddr : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.location_fill, color: kDanger, size: 18),
                          ],
                        ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(note, style: const TextStyle(fontSize: 12, color: kTextGrey, fontFamily: 'Amiri'), textAlign: TextAlign.right),
                                ),
                                const SizedBox(width: 8),
                                const Icon(CupertinoIcons.chat_bubble_text, color: kInfo, size: 14),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _rejecting ? null : () => _showRejectDialog(context),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.5), blurRadius: 7, offset: const Offset(3, 3)),
                                const BoxShadow(color: Colors.white, blurRadius: 7, offset: Offset(-3, -3)),
                              ],
                            ),
                            child: _rejecting
                                ? const Center(child: CupertinoActivityIndicator(color: kDanger))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 18),
                                      SizedBox(width: 6),
                                      Text('رفض', style: TextStyle(color: kDanger, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _accepting ? null : () => _accept(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimary.withOpacity(0.85), kPrimary],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: kPrimary.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: _accepting
                                ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.checkmark_shield, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('قبول الطلبية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    setState(() => _accepting = true);
    try {
      await DriverService.acceptServiceOrder(widget.docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ تم قبول الطلبية بنجاح', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: kSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/driver', (route) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('❌ فشل القبول'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showRejectDialog(BuildContext context) {
    String? selected;
    bool showCounterPriceInput = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx2).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'سبب الرفض',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: kTextDark),
                    ),
                    SizedBox(width: 8),
                    Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 20),
                  ],
                ),
                const SizedBox(height: 16),

                ...kRejectionReasons.map((reason) {
                  final isSel = selected == reason;
                  return GestureDetector(
                    onTap: () => setModal(() {
                      selected = reason;
                      showCounterPriceInput = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: isSel
                          ? BoxDecoration(
                              color: kDanger,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: kDanger.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                              ),
                              boxShadow: [
                                BoxShadow(color: Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                                BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
                              ],
                              border: Border.all(color: kPrimary.withOpacity(0.1)),
                            ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? Colors.white : Colors.transparent,
                              border: Border.all(color: isSel ? Colors.white : const Color(0xFFB8B1C8), width: 2),
                            ),
                            child: isSel
                                ? const Icon(Icons.check, size: 13, color: kDanger)
                                : null,
                          ),
                          const Spacer(),
                          Text(
                            reason,
                            style: TextStyle(
                              color: isSel ? Colors.white : kTextDark,
                              fontSize: 14,
                              fontFamily: 'Amiri',
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                GestureDetector(
                  onTap: () => setModal(() {
                    selected = 'السعر غير مناسب';
                    showCounterPriceInput = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: selected == 'السعر غير مناسب'
                        ? BoxDecoration(
                            color: kWarning,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: kWarning.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                            ),
                            boxShadow: [
                              BoxShadow(color: Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                              BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
                            ],
                            border: Border.all(color: kPrimary.withOpacity(0.1)),
                          ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected == 'السعر غير مناسب' ? Colors.white : Colors.transparent,
                            border: Border.all(
                              color: selected == 'السعر غير مناسب' ? Colors.white : const Color(0xFFB8B1C8),
                              width: 2,
                            ),
                          ),
                          child: selected == 'السعر غير مناسب'
                              ? const Icon(Icons.check, size: 13, color: kWarning)
                              : null,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'السعر غير مناسب — اقترح سعراً',
                              style: TextStyle(
                                color: selected == 'السعر غير مناسب' ? Colors.white : kTextDark,
                                fontSize: 14,
                                fontFamily: 'Amiri',
                                fontWeight: selected == 'السعر غير مناسب' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(CupertinoIcons.money_dollar_circle, color: selected == 'السعر غير مناسب' ? Colors.white : kWarning, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (showCounterPriceInput) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: neuShadow(blur: 6, offset: 2),
                      border: Border.all(color: kWarning.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('DA', style: TextStyle(color: kWarning, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _counterPriceCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFamily: 'Amiri', fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: 'أدخل السعر المقترح...',
                              hintStyle: TextStyle(color: Colors.black38, fontFamily: 'Amiri', fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(CupertinoIcons.tag_fill, color: kWarning, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(_counterPriceCtrl.text.trim());
                        if (price == null || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('أدخل سعراً صحيحاً', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: kDanger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          );
                          return;
                        }
                        Navigator.pop(ctx2);
                        final driverData = await ApiClient.get('/api/drivers/${DriverService.uid}');
                        final driverName = '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'.trim();
                        await DriverService.counterOfferServiceOrder(
                          orderId: widget.docId,
                          proposedPrice: price,
                          driverName: driverName.isNotEmpty ? driverName : 'السائق',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('✅ تم إرسال عرض السعر للزبون', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: kSuccess, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kWarning,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.money_dollar_circle, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('إرسال السعر المقترح للزبون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                if (!showCounterPriceInput)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () async {
                              Navigator.pop(ctx2);
                              setState(() => _rejecting = true);
                              await DriverService.rejectServiceOrder(widget.docId, selected!);
                              if (mounted) Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDanger,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 15)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionBox({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kPrimary.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.3), blurRadius: 6, offset: const Offset(3, 3)),
        const BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
      ],
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, color: kTextDark, fontFamily: 'Amiri')),
        ),
        const SizedBox(width: 6),
        Text('$label:', style: const TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
      ],
    ),
  );

  Widget _priceRow(String label, String value, Color color, {bool bold = false, double fontSize = 13}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Amiri')),
        const Spacer(),
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 13, fontFamily: 'Amiri')),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
class _DriverStatementSheet extends StatefulWidget {
  final DriverModel? driver;
  const _DriverStatementSheet({this.driver});

  @override
  State<_DriverStatementSheet> createState() => _DriverStatementSheetState();
}

class _DriverStatementSheetState extends State<_DriverStatementSheet> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/drivers/${DriverService.uid}/settlements');
      _list = data.cast<Map<String, dynamic>>();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final pct = d?.commissionPercent ?? 0;
    final cash = d?.cash ?? 0;
    final pending = cash * pct / 100;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('كشف الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: kPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: _sumCell('${cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', const Color(0xFF00897B))),
                  Expanded(child: _sumCell('${pct.toStringAsFixed(0)}%', 'نسبة الخصم', Colors.amber.shade700)),
                  Expanded(child: _sumCell('${pending.toStringAsFixed(0)} دج', 'المبلغ المخصوم', Colors.red.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_list.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد تسجيلات بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey))))
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollCtl,
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _list[i];
                    final createdAt = s['createdAt'] ?? '';
                    String dt = '';
                    if (createdAt is String) {
                      try { final d2 = DateTime.parse(createdAt); dt = '${d2.year}/${d2.month.toString().padLeft(2,'0')}/${d2.day.toString().padLeft(2,'0')} ${d2.hour.toString().padLeft(2,'0')}:${d2.minute.toString().padLeft(2,'0')}'; } catch (_) { dt = createdAt.substring(0, 16); }
                    }
                    final cashAt = (s['cashAtSettlement'] ?? 0).toDouble();
                    final cpct = (s['commissionPercent'] ?? 0).toDouble();
                    final commAmt = (s['commissionAmount'] ?? 0).toDouble();
                    final disc = (s['discount'] ?? 0).toDouble();
                    final collected = (s['amountCollected'] ?? 0).toDouble();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(dt, style: const TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey)),
                                const Spacer(),
                                Text('-${collected.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red, fontFamily: 'Amiri')),
                              ],
                            ),
                            const Divider(),
                            _row('المبلغ الحالي', '${cashAt.toStringAsFixed(0)} دج'),
                            _row('نسبة الخصم', '$cpct%'),
                            _row('قيمة الخصم', '${commAmt.toStringAsFixed(0)} دج'),
                            if (disc > 0) _row('خصم إضافي', '${disc.toStringAsFixed(0)} دج'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sumCell(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color, fontFamily: 'Amiri')),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
        Text(value, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _TransportOrderDetailSheet — تفاصيل طلبية نقل مع قبول/رفض/تغيير سعر
// ══════════════════════════════════════════════════════════════════════════════

class _TransportOrderDetailSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _TransportOrderDetailSheet({required this.docId, required this.data});

  @override
  State<_TransportOrderDetailSheet> createState() =>
      _TransportOrderDetailSheetState();
}

class _TransportOrderDetailSheetState
    extends State<_TransportOrderDetailSheet> {
  bool _accepting = false;
  bool _rejecting = false;
  bool _counterOffering = false;
  final _counterPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _counterPriceCtrl.dispose();
    super.dispose();
  }

Future<void> _accept() async {
  setState(() => _accepting = true);
  HapticFeedback.mediumImpact();
  await DriverService.acceptTransportOrder(widget.docId);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✅ تم قبول طلب النقل',
          style: TextStyle(fontFamily: 'Amiri'),
        ),
        backgroundColor: kSuccess,
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/driver',
      (route) => false,
    );
  }
}

  Future<void> _reject(String reason) async {
    setState(() => _rejecting = true);
    await DriverService.rejectTransportOrder(widget.docId, reason);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ تم رفض الطلبية',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kDanger,
        ),
      );
    }
  }

  Future<void> _counterOffer() async {
    final price = double.tryParse(_counterPriceCtrl.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إدخال سعر صحيح',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kWarning,
        ),
      );
      return;
    }
    setState(() => _counterOffering = true);
    final driverData = await ApiClient.get('/api/drivers/${DriverService.uid}');
    final driverName =
        '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
            .trim();
    await DriverService.counterOfferTransportOrder(
      orderId: widget.docId,
      proposedPrice: price,
      driverName: driverName.isNotEmpty ? driverName : 'السائق',
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '📩 تم اقتراح السعر',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kSuccess,
        ),
      );
    }
  }

  void _showRejectDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RejectTransportSheet(
        onReject: (reason) async {
          Navigator.pop(ctx);
          await _reject(reason);
        },
        onCounterOffer: () {
          Navigator.pop(ctx);
          _showCounterOfferInput();
        },
      ),
    );
  }

  void _showCounterOfferInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CounterOfferTransportSheet(
        controller: _counterPriceCtrl,
        loading: _counterOffering,
        onSubmit: () {
          Navigator.pop(ctx);
          _counterOffer();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final userName = d['userName'] ?? 'زبون';
    final userPhone = d['userPhone'] as String? ?? '';
    final userPhoneHidden = d['phoneHidden'] as bool? ?? false;
    final note = d['note'] as String? ?? '';
    final fromAddr = d['fromAddress'] as String? ?? '';
    final toAddr = d['toAddress'] as String? ?? '';
    final price = (d['price'] as num? ?? 0).toDouble();
    final parcelImage = d['parcelImageUrl'] as String? ?? '';
    final fromLat = (d['fromLat'] as num?)?.toDouble();
    final fromLng = (d['fromLng'] as num?)?.toDouble();
    final toLat = (d['toLat'] as num?)?.toDouble();
    final toLng = (d['toLng'] as num?)?.toDouble();
    final hasFromCoords = fromLat != null && fromLat != 0 && fromLng != null && fromLng != 0;
    final hasToCoords = toLat != null && toLat != 0 && toLng != null && toLng != 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${widget.docId.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Text(
                  'تفاصيل طلب النقل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _sectionBox(
                    child: Row(
                      children: [
                        if (userPhone.isNotEmpty && !userPhoneHidden)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('tel:$userPhone');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: kSuccess.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kSuccess.withOpacity(0.3)),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.phone_fill, color: kSuccess, size: 18),
                                  SizedBox(height: 3),
                                  Text('اتصل', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              userName.isNotEmpty ? userName : 'زبون',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Amiri',
                                color: kTextDark,
                              ),
                            ),
                            if (userPhone.isNotEmpty && !userPhoneHidden) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: userPhone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('تم نسخ الرقم', style: TextStyle(fontFamily: 'Amiri')),
                                      backgroundColor: kPrimary,
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.doc_on_clipboard, color: kPrimary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(userPhone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'Amiri')),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kBg,
                            border: Border.all(color: kPrimary, width: 2),
                          ),
                          child: ClipOval(
                            child: Icon(CupertinoIcons.person_crop_circle_fill, color: kPrimary, size: 38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        // موقع الاستلام
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (hasFromCoords) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$fromLat,$fromLng/'));
                                } else if (fromAddr.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(fromAddr)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kPrimary, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('موقع الاستلام', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  fromAddr.isNotEmpty ? fromAddr : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_down_circle_fill, color: kPrimary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // موقع التوصيل
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (hasToCoords) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/$toLat,$toLng/'));
                                } else if (toAddr.isNotEmpty) {
                                  await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent(toAddr)}'));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDanger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.map_fill, color: kDanger, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('موقع التوصيل', style: TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text(
                                  toAddr.isNotEmpty ? toAddr : 'غير محدد',
                                  style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w500, fontFamily: 'Amiri'),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.location_fill, color: kDanger, size: 18),
                          ],
                        ),
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(note, style: const TextStyle(fontSize: 12, color: kTextGrey, fontFamily: 'Amiri'), textAlign: TextAlign.right),
                                ),
                                const SizedBox(width: 8),
                                const Icon(CupertinoIcons.chat_bubble_text, color: kInfo, size: 14),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionBox(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: Colors.grey.shade300, height: 1),
                        ),
                        _priceRow('الإجمالي', '${price.toInt()} DZD', kPrimary, bold: true, fontSize: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _rejecting ? null : _showRejectDialog,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.5), blurRadius: 7, offset: const Offset(3, 3)),
                                const BoxShadow(color: Colors.white, blurRadius: 7, offset: Offset(-3, -3)),
                              ],
                            ),
                            child: _rejecting
                                ? const Center(child: CupertinoActivityIndicator(color: kDanger))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 18),
                                      SizedBox(width: 6),
                                      Text('رفض', style: TextStyle(color: kDanger, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _accepting ? null : _accept,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimary.withOpacity(0.85), kPrimary],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: kPrimary.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: _accepting
                                ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.checkmark_shield, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBox({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kPrimary.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.3), blurRadius: 6, offset: const Offset(3, 3)),
        const BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
      ],
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, color: kTextDark, fontFamily: 'Amiri')),
        ),
        const SizedBox(width: 6),
        Text('$label:', style: const TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri')),
      ],
    ),
  );

  Widget _priceRow(String label, String value, Color color, {bool bold = false, double fontSize = 13}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontFamily: 'Amiri')),
        const Spacer(),
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 13, fontFamily: 'Amiri')),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _RejectTransportSheet — ورقة اختيار سبب الرفض لطلبيات النقل
// ══════════════════════════════════════════════════════════════════════════════
class _RejectTransportSheet extends StatefulWidget {
  final Future<void> Function(String reason) onReject;
  final VoidCallback onCounterOffer;
  const _RejectTransportSheet({
    required this.onReject,
    required this.onCounterOffer,
  });

  @override
  State<_RejectTransportSheet> createState() => _RejectTransportSheetState();
}

class _RejectTransportSheetState extends State<_RejectTransportSheet> {
  String? _selected;
  bool _loading = false;

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    await widget.onReject(_selected!);
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [...kRejectionReasons, 'السعر غير مناسب'];
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'سبب الرفض',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) {
            final isSelected = _selected == r;
            final isCounter = r == 'السعر غير مناسب';
            return GestureDetector(
              onTap: () {
                if (isCounter) {
                  widget.onCounterOffer();
                } else {
                  setState(() => _selected = r);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? kDanger.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? kDanger
                        : const Color(0xFFDDD0F0).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (isSelected)
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: kDanger,
                        size: 20,
                      )
                    else
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kTextGrey),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      r,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        color: isSelected ? kDanger : kTextDark,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (_selected != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'تأكيد الرفض',
                        style: TextStyle(fontFamily: 'Amiri'),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDanger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CounterOfferTransportSheet — إدخال سعر مقترح لطلبيات النقل
// ══════════════════════════════════════════════════════════════════════════════
class _CounterOfferTransportSheet extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  const _CounterOfferTransportSheet({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'اقتراح سعر',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'أدخل السعر المقترح',
              hintStyle: const TextStyle(fontFamily: 'Amiri', color: kTextGrey),
              suffixText: 'DA',
              suffixStyle: const TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال السعر المقترح',
                      style: TextStyle(fontFamily: 'Amiri'),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kWarning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _IncomingOrderCard — كارد جديد بتصميم راقي مطابق لـ ActiveOrderSmartCard
// ══════════════════════════════════════════════════════════════════════════════
class _IncomingOrderCard extends StatefulWidget {
  final DriverOrder order;
  final double driverLat;
  final double driverLng;
  final int animDelay;

  const _IncomingOrderCard({
    required this.order,
    required this.driverLat,
    required this.driverLng,
    this.animDelay = 0,
  });

  @override
  State<_IncomingOrderCard> createState() => _IncomingOrderCardState();
}

class _IncomingOrderCardState extends State<_IncomingOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.animDelay), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  double get _distKm {
    if (widget.driverLat == 0 || widget.driverLng == 0) return 0;
    return widget.order.distanceKmFrom(widget.driverLat, widget.driverLng);
  }

  // تجميع المنتجات حسب اسم المحل
  Map<String, List<DriverOrderItem>> get _groupedItems {
    final Map<String, List<DriverOrderItem>> grouped = {};
    for (final item in widget.order.items) {
      final key = item.storeName.isNotEmpty && item.templateName.isNotEmpty
          ? '${item.storeName} — ${item.templateName}'
          : item.storeName.isNotEmpty
          ? item.storeName
          : 'منتجات';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  void _openDetails() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: widget.order,
        driverLat: widget.driverLat,
        driverLng: widget.driverLng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final color = o.storeColor;
    final bool isFree = o.deliveryFee == 0;
    final storeNames = o.items.map((e) => e.storeName).toSet().join('، ');
    final notesCount = o.items.where((e) => e.note.isNotEmpty).length;

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: GestureDetector(
          onTap: _openDetails,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8B1C8).withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 8,
                  offset: Offset(-3, -3),
                ),
              ],
              border: Border.all(color: kPrimary.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.bag_fill,
                    color: kPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        o.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: kTextDark,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        storeNames,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kTextGrey,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (notesCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kWarning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.doc_text_fill, color: kWarning, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          '$notesCount',
                          style: TextStyle(
                            color: kWarning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFree
                        ? Colors.orange.withOpacity(0.12)
                        : kSuccess.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFree ? 'مجاني' : '${o.deliveryFee.toInt()} DA',
                    style: TextStyle(
                      color: isFree ? Colors.orange : kSuccess,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ① شريط العلوي ───────────────────────────────────────────────────────
  Widget _buildTopBar(DriverOrder o, Color color, bool isFree) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          // سعر التوصيل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isFree
                  ? Colors.orange.withOpacity(0.13)
                  : kSuccess.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isFree
                    ? Colors.orange.withOpacity(0.4)
                    : kSuccess.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: isFree
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.orange, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'توصيل مجاني',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.money_dollar_circle_fill,
                        color: kSuccess,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${o.deliveryFee.toInt()} DA',
                        style: const TextStyle(
                          color: kSuccess,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
          ),
          const Spacer(),
          // رقم الطلب + شارة جديدة
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: kWarning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'جديد 🔔',
                  style: TextStyle(
                    color: kWarning,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '#${o.id.substring(0, 5).toUpperCase()}',
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ② صف الزبون ─────────────────────────────────────────────────────────
  Widget _buildCustomerRow(DriverOrder o, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          // زر فتح التفاصيل
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(CupertinoIcons.eye_fill, color: color, size: 16),
          ),
          const Spacer(),
          // الاسم والموثق
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.userVerified) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF1877F2).withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Color(0xFF1877F2),
                            size: 9,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'موثق',
                            style: TextStyle(
                              color: Color(0xFF1877F2),
                              fontSize: 9,
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    o.userName.isNotEmpty ? o.userName : 'زبون',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                      color: kTextDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.location_fill,
                    size: 10,
                    color: kTextGrey,
                  ),
                  const SizedBox(width: 3),
                  SizedBox(
                    width: 160,
                    child: Text(
                      o.address,
                      style: const TextStyle(
                        fontSize: 10,
                        color: kTextGrey,
                        fontFamily: 'Amiri',
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 10),
          // أفاتار
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBg,
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                  boxShadow: neuShadow(blur: 5, offset: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    o.userGender == 'female'
                        ? 'assets/images/avatarf.png'
                        : 'assets/images/avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      CupertinoIcons.person_fill,
                      color: color,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (o.userVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1877F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ③ قسم المحلات والمنتجات ──────────────────────────────────────────────
  Widget _buildStoresSection(Color color) {
    final grouped = _groupedItems;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          children: grouped.entries.map((entry) {
            return _buildStoreGroup(entry.key, entry.value, color);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStoreGroup(
    String storeName,
    List<DriverOrderItem> items,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15), width: 1.2),
      ),
      child: Column(
        children: [
          // ترويسة المحل
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.12), color.withOpacity(0.06)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  storeName,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(width: 5),
                Icon(CupertinoIcons.building_2_fill, color: color, size: 12),
              ],
            ),
          ),
          // المنتجات
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              children: items
                  .map((item) => _buildProductRow(item, color))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(DriverOrderItem item, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ), // مسافة عمودية أكبر للوضوح
      child: Row(
        crossAxisAlignment: CrossAxisAlignment
            .start, // محاذاة من الأعلى لكي لا يختل التصميم عند التفاف النص
        children: [
          // ① السعر والكمية - جعل الكمية بارزة جداً للسائق
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  '× ${item.quantity}', // الكمية واضحة
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900, // خط عريض جداً
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(item.price * item.quantity).toInt()} DA',
                style: const TextStyle(
                  fontSize: 11,
                  color: kTextGrey,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // ② اسم المنتج والحجم - يدعم النص الطويل (Wrapping)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.name, // الاسم كامل (بيتزا كاري - دجاج)
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                    height: 1.2, // مسافة مريحة بين الأسطر إذا نزل النص
                  ),
                  textAlign: TextAlign.right,
                  softWrap: true,
                ),

                if (item.categoryName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.categoryName,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Amiri',
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),

                if (item.capacite.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      item.capacite,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ④ صورة المنتج
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildPlaceholderIcon(color),
                  )
                : _buildPlaceholderIcon(color),
          ),
        ],
      ),
    );
  }

  // ويدجت أيقونة بديلة في حال عدم وجود صورة
  Widget _buildPlaceholderIcon(Color color) {
    return Container(
      width: 48,
      height: 48,
      color: Colors.white,
      child: Icon(
        CupertinoIcons.cube_box,
        size: 20,
        color: color.withOpacity(0.4),
      ),
    );
  }

  // ── ④ شريط المسافة والإجمالي ─────────────────────────────────────────────
  Widget _buildInfoStrip(DriverOrder o, Color color) {
    final dist = _distKm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          // الإجمالي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${o.total.toInt()} DA',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Amiri',
                    height: 1,
                  ),
                ),
                const Text(
                  'الإجمالي',
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 9,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // المسافة
          if (dist > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kInfo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kInfo.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${dist.toStringAsFixed(1)} كم',
                        style: const TextStyle(
                          color: kInfo,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Amiri',
                          height: 1,
                        ),
                      ),
                      const Text(
                        'المسافة',
                        style: TextStyle(
                          color: kTextGrey,
                          fontSize: 9,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.location_fill,
                    color: kInfo,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── ⑤ أزرار القبول والرفض ──────────────────────────────────────────────
  Widget _buildActionRow(DriverOrder o, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          // زر الرفض
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _openDetails(); // يفتح الشيت للرفض من هناك
              },
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: neuShadow(blur: 5, offset: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 16),
                    SizedBox(width: 5),
                    Text(
                      'رفض',
                      style: TextStyle(
                        color: kDanger,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // زر القبول
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                try {
                  await DriverService.acceptOrder(o.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '✅ تم قبول الطلبية بنجاح',
                          style: TextStyle(fontFamily: 'Amiri'),
                        ),
                        backgroundColor: kSuccess,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    Navigator.of(context).pushNamedAndRemoveUntil('/driver', (route) => false);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '❌ فشل قبول الطلبية: $e',
                          style: const TextStyle(fontFamily: 'Amiri'),
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.85), color],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_shield,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'قبول الطلبية',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _OrderDetailSheet — شيت واحد + dispose صحيح
// ══════════════════════════════════════════════════════════════════════════════
class _OrderDetailSheet extends StatefulWidget {
  final DriverOrder order;
  final double driverLat;
  final double driverLng;

  const _OrderDetailSheet({
    required this.order,
    required this.driverLat,
    required this.driverLng,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _accepting = false;
  bool _rejecting = false;
  bool _counterOffering = false;

  final TextEditingController _counterPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _counterPriceCtrl.dispose();
    super.dispose();
  }

  DriverOrder get o => widget.order;

  double get _distKm {
    if (widget.driverLat == 0 || widget.driverLng == 0) return 0;
    return o.distanceKmFrom(widget.driverLat, widget.driverLng);
  }

Future<void> _accept() async {
  setState(() => _accepting = true);
  HapticFeedback.mediumImpact();
  await DriverService.acceptOrder(o.id);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '✅ تم قبول الطلبية بنجاح',
          style: TextStyle(fontFamily: 'Amiri'),
        ),
        backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    // ✅ روح لصفحة طلبياتي مباشرة
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/driver',
      (route) => false,
    );
  }
}

  void _showRejectDialog() {
    String? selected;
    bool showCounterPriceInput = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: const BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'سبب الرفض',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: kTextDark,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(CupertinoIcons.xmark_circle, color: kDanger, size: 20),
                  ],
                ),
                const SizedBox(height: 16),

                ...kRejectionReasons.map((reason) {
                  final isSel = selected == reason;
                  return GestureDetector(
                    onTap: () => setModal(() {
                      selected = reason;
                      showCounterPriceInput = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: isSel
                          ? BoxDecoration(
                              color: kDanger,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: kDanger.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFB8B1C8).withOpacity(0.6),
                                  blurRadius: 10,
                                  offset: Offset(4, 4),
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 10,
                                  offset: Offset(-4, -4),
                                ),
                              ],
                              border: Border.all(
                                color: kPrimary.withOpacity(0.1),
                              ),
                            ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFFB8B1C8),
                                width: 2,
                              ),
                            ),
                            child: isSel
                                ? const Icon(
                                    Icons.check,
                                    size: 13,
                                    color: kDanger,
                                  )
                                : null,
                          ),
                          const Spacer(),
                          Text(
                            reason,
                            style: TextStyle(
                              color: isSel ? Colors.white : kTextDark,
                              fontSize: 14,
                              fontFamily: 'Amiri',
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                GestureDetector(
                  onTap: () => setModal(() {
                    selected = 'السعر غير مناسب';
                    showCounterPriceInput = true;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: selected == 'السعر غير مناسب'
                        ? BoxDecoration(
                            color: kWarning,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: kWarning.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFB8B1C8).withOpacity(0.6),
                                blurRadius: 10,
                                offset: Offset(4, 4),
                              ),
                              BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(-4, -4),
                              ),
                            ],
                            border: Border.all(
                              color: kPrimary.withOpacity(0.1),
                            ),
                          ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected == 'السعر غير مناسب'
                                ? Colors.white
                                : Colors.transparent,
                            border: Border.all(
                              color: selected == 'السعر غير مناسب'
                                  ? Colors.white
                                  : const Color(0xFFB8B1C8),
                              width: 2,
                            ),
                          ),
                          child: selected == 'السعر غير مناسب'
                              ? const Icon(
                                  Icons.check,
                                  size: 13,
                                  color: kWarning,
                                )
                              : null,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'السعر غير مناسب — اقترح سعراً',
                              style: TextStyle(
                                color: selected == 'السعر غير مناسب'
                                    ? Colors.white
                                    : kTextDark,
                                fontSize: 14,
                                fontFamily: 'Amiri',
                                fontWeight: selected == 'السعر غير مناسب'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.money_dollar_circle,
                              color: selected == 'السعر غير مناسب'
                                  ? Colors.white
                                  : kWarning,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (showCounterPriceInput) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: neuShadow(blur: 6, offset: 2),
                      border: Border.all(color: kWarning.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'DA',
                            style: TextStyle(
                              color: kWarning,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _counterPriceCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'أدخل السعر المقترح...',
                              hintStyle: TextStyle(
                                color: Colors.black38,
                                fontFamily: 'Amiri',
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            CupertinoIcons.tag_fill,
                            color: kWarning,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(
                          _counterPriceCtrl.text.trim(),
                        );
                        if (price == null || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'أدخل سعراً صحيحاً',
                                style: TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: kDanger,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _counterOffering = true);
                        final driverData = await ApiClient.get(
                          '/api/drivers/${DriverService.uid}',
                        );
                        final driverName =
                            '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
                                .trim();
                        await DriverService.counterOfferOrder(
                          orderId: o.id,
                          proposedPrice: price,
                          driverName: driverName.isNotEmpty
                              ? driverName
                              : 'السائق',
                        );
                        if (mounted) {
                          setState(() => _counterOffering = false);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '✅ تم إرسال عرض السعر للزبون',
                                style: TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: kSuccess,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kWarning,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.money_dollar_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'إرسال السعر المقترح للزبون',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                if (!showCounterPriceInput)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              setState(() => _rejecting = true);
                              await DriverService.rejectOrder(o.id, selected!);
                              if (mounted) Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kDanger,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'تأكيد الرفض',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = o.storeColor;

    final Map<String, List<DriverOrderItem>> byStore = {};
    for (final item in o.items) {
      final key = item.categoryName.isNotEmpty
          ? (item.categoryName == 'عرض خاص' && item.templateName.isNotEmpty
              ? '${item.categoryName} — ${item.templateName}'
              : item.categoryName)
          : item.storeName.isNotEmpty && item.templateName.isNotEmpty
          ? '${item.storeName} — ${item.templateName}'
          : item.storeName.isNotEmpty
          ? item.storeName
          : 'منتجات';
      byStore.putIfAbsent(key, () => []).add(item);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#${o.id.substring(0, 6).toUpperCase()}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Text(
                  'تفاصيل الطلبية 🛍️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // ── معلومات الزبون ──
                  _sectionBox(
                    color: color,
                    child: Row(
                      children: [
                        if (!o.phoneHidden && o.userPhone.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                launchUrl(Uri.parse('tel:${o.userPhone}')),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: kSuccess.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: kSuccess.withOpacity(0.3),
                                ),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.phone_fill,
                                    color: kSuccess,
                                    size: 18,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'اتصل',
                                    style: TextStyle(
                                      color: kSuccess,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (o.userVerified)
                                  Container(
                                    margin: const EdgeInsets.only(left: 5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1877F2,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF1877F2,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified,
                                          color: Color(0xFF1877F2),
                                          size: 10,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'موثق',
                                          style: TextStyle(
                                            color: Color(0xFF1877F2),
                                            fontSize: 9,
                                            fontFamily: 'Amiri',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  o.userName.isNotEmpty ? o.userName : 'زبون',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Amiri',
                                    color: kTextDark,
                                  ),
                                ),
                              ],
                            ),
                            if (!o.phoneHidden && o.userPhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: o.userPhone),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'تم نسخ الرقم 📋',
                                        style: TextStyle(fontFamily: 'Amiri'),
                                      ),
                                      backgroundColor: kPrimary,
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.doc_on_clipboard,
                                      color: color,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      o.userPhone,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                        fontFamily: 'Amiri',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_distKm > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.location,
                                    color: color,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_distKm.toStringAsFixed(1)} كم منك',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),
                        _buildAvatar(o.userGender, o.userVerified, color, 54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── المنتجات مجمعة حسب المحل ──
                  _sectionBox(
                    color: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ...byStore.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: color.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                        fontFamily: 'Amiri',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      CupertinoIcons.building_2_fill,
                                      color: color,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...entry.value.map(
                                (item) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: color.withOpacity(0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.price.toInt()} DZD',
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Amiri',
                                            ),
                                          ),
                                          Text(
                                            '× ${item.quantity}',
                                            style: const TextStyle(
                                              color: kTextGrey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                fontFamily: 'Amiri',
                                                color: kTextDark,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                            if (item.note.isNotEmpty)
                                              Text(
                                                '📝 ${item.note}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: kWarning.withOpacity(0.8),
                                                  fontFamily: 'Amiri',
                                                ),
                                                textAlign: TextAlign.right,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (item.image.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            border: Border.all(
                                              color: color.withOpacity(0.2),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: item.image,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Icon(
                                                CupertinoIcons.photo,
                                                color: color,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── الأسعار ──
                  _sectionBox(
                    color: color,
                    child: Column(
                      children: [
                        _priceRow(
                          'سعر المنتجات',
                          '${o.subtotal.toInt()} DZD',
                          kTextDark,
                        ),
                        const SizedBox(height: 8),
                        _priceRow(
                          'رسوم التوصيل',
                          '${o.deliveryFee.toInt()} DZD',
                          kTextGrey,
                        ),
                        if (o.deliveryFee == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 6, bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: kSuccess.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: kSuccess.withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'طلبية مكافأة للزبون — التوصيل مجاني',
                                  style: TextStyle(
                                    color: kSuccess,
                                    fontSize: 11,
                                    fontFamily: 'Amiri',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  CupertinoIcons.gift_fill,
                                  color: kSuccess,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            color: Colors.grey.shade300,
                            height: 1,
                          ),
                        ),
                        _priceRow(
                          'الإجمالي',
                          '${o.total.toInt()} DZD',
                          color,
                          bold: true,
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── العنوان ──
                  _sectionBox(
                    color: color,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final url = o.userLat != null
                                    ? Uri.parse(
                                        'https://www.google.com/maps/dir/?api=1'
                                        '&destination=${o.userLat},${o.userLng}',
                                      )
                                    : Uri.parse(
                                        'https://www.google.com/maps/search/'
                                        '${Uri.encodeComponent(o.address)}',
                                      );
                                if (await canLaunchUrl(url)) launchUrl(url);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  CupertinoIcons.map_fill,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'موقع التسليم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kTextGrey,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  o.address.isNotEmpty ? o.address : 'غير محدد',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kTextDark,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              CupertinoIcons.location_fill,
                              color: color,
                              size: 18,
                            ),
                          ],
                        ),
                        if (_distKm > 0) ...[
                          Divider(color: Colors.grey.shade300, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${_distKm.toStringAsFixed(1)} كم بينك وبين الزبون',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.arrow_right_arrow_left,
                                color: color,
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                        if (o.driverNote.isNotEmpty) ...[
                          Divider(color: Colors.grey.shade300, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  o.driverNote,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kTextGrey,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.chat_bubble_text,
                                color: kInfo,
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── أزرار القبول والرفض ──
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _rejecting ? null : _showRejectDialog,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: neuShadow(blur: 7, offset: 3),
                            ),
                            child: _rejecting
                                ? const Center(
                                    child: CupertinoActivityIndicator(
                                      color: kDanger,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.xmark_circle,
                                        color: kDanger,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'رفض',
                                        style: TextStyle(
                                          color: kDanger,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _accepting ? null : _accept,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color.withOpacity(0.85), color],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _accepting
                                ? const Center(
                                    child: CupertinoActivityIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_shield,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'قبول الطلبية',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String gender,
    bool verified,
    Color borderColor,
    double size,
  ) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kBg,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: neuShadow(blur: 6, offset: 3),
          ),
          child: ClipOval(
            child: Image.asset(
              gender == 'female' ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.person_fill,
                color: borderColor,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        if (verified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF1877F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Widget _sectionBox({required Widget child, required Color color}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: neuShadow(blur: 6, offset: 3),
        ),
        child: child,
      );

  Widget _priceRow(
    String label,
    String value,
    Color color, {
    bool bold = false,
    double fontSize = 13,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: color,
          fontFamily: 'Amiri',
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black54,
          fontFamily: 'Amiri',
        ),
      ),
    ],
  );
}

class DriverNotificationHelper {
  // سميه DriverNotificationHelper باش ما تتلفلكش
  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init(String driverId) async {
    try {
      await FirebaseMessaging.instance.requestPermission();

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // ✅ التعديل هنا: التخزين في كولكشن drivers وليس users
        await ApiClient.put('/api/drivers/$driverId', {
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
        });
        debugPrint("✅ Driver Token Saved in drivers collection");
      }

      // إعدادات القناة (لازم orders_channel باش يسمع للزبون)
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _localPlugin.initialize(
        settings: InitializationSettings(android: androidInit, iOS: iosInit),
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showOrderBanner(message);
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        ApiClient.put('/api/drivers/$driverId', {
          'fcmToken': newToken,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
        });
        debugPrint("✅ Driver FCM Token Refreshed");
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  static void _showOrderBanner(RemoteMessage message) {
    final title = message.data['title'] ?? message.notification?.title;
    final body = message.data['body'] ?? message.notification?.body;
    if (title == null && body == null) return;
    _localPlugin.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'orders_channel',
          'طلبات التوصيل',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          vibrationPattern: Int64List.fromList([0, 2000]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑪ DriverNotificationsScreen
// ══════════════════════════════════════════════════════════════════════════════
// ── الشاشة الرئيسية للإشعارات ──────────────────────────────────────────
class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});
  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _showReportSheet(Map<String, dynamic> order) async {
    final customerName = order['userName'] ?? 'زبون غير معروف';
    final customerId = order['userId'] ?? '';
    final orderId = order['orderId'] ?? order['_id'] ?? '';
    final cancelReason = order['cancelReason'] ?? 'لم يذكر الزبون سبباً';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CancelDetailSheet(
        customerName: customerName,
        customerId: customerId,
        orderId: orderId is String ? orderId : '$orderId',
        cancelReason: cancelReason is String ? cancelReason : '$cancelReason',
        driverId: _uid,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCancelledOrders() async {
    try {
      final result = await ApiClient.getList(
          '/api/orders?driverId=$_uid&status=cancelled');
      return result.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      return intl.DateFormat('yyyy/MM/dd HH:mm')
          .format(DateTime.parse('$ts'));
    } catch (_) {
      return '$ts';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'الطلبات الملغية',
          style: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadCancelledOrders(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(color: kPrimary),
            );
          }
          final orders = snap.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: kBg,
                      shape: BoxShape.circle,
                      boxShadow: neuShadow(blur: 16, offset: 7),
                    ),
                    child: Icon(
                      CupertinoIcons.checkmark_shield_fill,
                      size: 50,
                      color: Colors.green.shade300,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'لا توجد طلبات ملغية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final orderId = o['orderId'] ?? o['_id'] ?? '';
              final customerName = o['userName'] ?? 'زبون';
              final cancelReason = o['cancelReason'] ?? 'بدون سبب';
              final time = _formatTime(o['updatedAt'] ?? o['createdAt']);
              final total = o['total'] ?? o['subtotal'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: neuShadow(),
                  border: Border.all(
                    color: kDanger.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // رأس البطاقة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            time,
                            style: const TextStyle(
                              color: kTextGrey,
                              fontSize: 10,
                              fontFamily: 'Amiri',
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'ملغية',
                                style: TextStyle(
                                  color: kDanger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                CupertinoIcons.xmark_shield_fill,
                                color: kDanger,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // معلومات الطلبية
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'الزبون: $customerName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    fontFamily: 'Amiri',
                                    color: kTextDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'رقم الطلب: ${orderId is String ? orderId.substring(0, orderId.length > 10 ? 10 : orderId.length).toUpperCase() : orderId}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Amiri',
                                    color: kTextGrey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المبلغ: $total دج',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Amiri',
                                    color: kTextDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kDanger.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'سبب الإلغاء: $cancelReason',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: kDanger,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: neuShadow(blur: 5, offset: 2),
                            ),
                            child: const Icon(
                              CupertinoIcons.doc_text_fill,
                              color: kDanger,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showReportSheet(o),
                          icon: const Icon(CupertinoIcons.flag_fill, size: 16),
                          label: const Text(
                            'الإبلاغ عن الزبون',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDanger.withOpacity(0.15),
                            foregroundColor: kDanger,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── شاشة تفاصيل الإلغاء والإبلاغ المحسنة ──────────────────────────────────
class _CancelDetailSheet extends StatefulWidget {
  final String customerName, customerId, orderId, cancelReason, driverId;
  const _CancelDetailSheet({
    required this.customerName,
    required this.customerId,
    required this.orderId,
    required this.cancelReason,
    required this.driverId,
  });

  @override
  State<_CancelDetailSheet> createState() => _CancelDetailSheetState();
}

class _CancelDetailSheetState extends State<_CancelDetailSheet> {
  final _reportCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submitReport() async {
    if (_reportCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى كتابة سبب الإبلاغ',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: kDanger,
        ),
      );
      return;
    }
    setState(() => _loading = true);

    try {
      // تخزين كامل البيانات في الفيربيس
      final driverUser = FirebaseAuth.instance.currentUser;
      await ApiClient.post('/api/reports', {
        'type': 'driver_report',
        'driverId': widget.driverId,
        'driverName': driverUser?.displayName ?? 'سائق',
        'userId': widget.customerId,
        'userName': widget.customerName,
        'orderId': widget.orderId,
        'reason': widget.cancelReason,
        'note': _reportCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال البلاغ بنجاح.. سنقوم بمراجعته',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: kSuccess,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 25),

            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'تفاصيل الإلغاء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                  ),
                ),
                SizedBox(width: 10),
                Icon(CupertinoIcons.info_circle_fill, color: kPrimary),
              ],
            ),

            const SizedBox(height: 20),

            // معلومات الزبون في كارد صغير
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: neuShadow(blur: 5, offset: 2),
              ),
              child: Column(
                children: [
                  _infoLine(
                    "اسم الزبون:",
                    widget.customerName,
                    kPrimary,
                    isBold: true,
                  ),
                  const Divider(height: 20),
                  _infoLine(
                    "رقم الطلبية:",
                    widget.orderId.substring(0, 10).toUpperCase(),
                    kTextGrey,
                  ),
                  const Divider(height: 20),
                  _infoLine(
                    "سبب الإلغاء:",
                    widget.cancelReason,
                    kDanger,
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'الإبلاغ عن سلوك الزبون',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                color: kDanger,
              ),
            ),
            const SizedBox(height: 12),

            // حقل إدخال البلاغ "نيومورفيك"
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white,
                    offset: const Offset(-3, -3),
                    blurRadius: 5,
                  ),
                  BoxShadow(
                    color: kTextGrey.withOpacity(0.2),
                    offset: const Offset(3, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TextField(
                controller: _reportCtrl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Amiri', fontSize: 13),
                decoration: const InputDecoration(
                  hintText:
                      'لماذا تريد الإبلاغ عن هذا الزبون؟ (مثلاً: لا يرد على الاتصال، ألغى بعد الشراء...)',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Amiri',
                    color: Colors.grey,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(18),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // زر الإرسال
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDanger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 5,
                  shadowColor: kDanger.withOpacity(0.4),
                ),
                child: _loading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'إرسال بلاغ رسمي',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Amiri',
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(
                            CupertinoIcons.flag_fill,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(color: kTextGrey, fontFamily: 'Amiri'),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(
    String label,
    String value,
    Color valColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valColor,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.normal,
              fontFamily: 'Amiri',
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: kTextGrey,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ⑫ DriverProfileScreen
// ══════════════════════════════════════════════════════════════════════════════
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  DateTime _lastRefresh = DateTime.now();
  final _picker = ImagePicker();

  Future<void> _pickPhoto(DriverModel driver) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      final url = await ApiClient.upload(File(picked.path));
      if (driver.photoUrl.isNotEmpty) {
        await ApiClient.deleteImageUrl(driver.photoUrl).catchError((_) {});
      }
      await ApiClient.put('/api/drivers/${driver.uid}', {'photoUrl': url});
      await DriverService.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تغيير الصورة', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverModel?>(
      stream: DriverService.driverStream(),
      builder: (ctx, snap) {
        final driver = snap.data;
        return Container(
          color: kBg,
          child: Column(
            children: [
              const ConnectivityBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await DriverService.refresh();
                    if (mounted) setState(() => _lastRefresh = DateTime.now());
                  },
                  color: kPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'ملفي الشخصي',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: kBg,
                          shape: BoxShape.circle,
                          boxShadow: neuShadow(blur: 16, offset: 7),
                        ),
                        child: ClipOval(
                          child: driver?.photoUrl.isNotEmpty == true
                              ? CachedNetworkImage(
                                  imageUrl: driver!.photoUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Image.asset(
                                    'assets/images/avatar.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/avatar.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      if (driver?.canUploadPhoto == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => _pickPhoto(driver!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: kPrimary.withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.photo_fill, size: 14, color: kPrimary),
                                  SizedBox(width: 6),
                                  Text(
                                    'تغيير الصورة',
                                    style: TextStyle(fontSize: 12, color: kPrimary, fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        driver?.fullName ?? '—',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      if (driver?.cityName.isNotEmpty == true)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              driver!.cityName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: kPrimary,
                                fontFamily: 'Amiri',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.location_solid,
                              size: 13,
                              color: kPrimary,
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              '${(driver?.totalEarnings ?? 0).toStringAsFixed(0)} دج',
                              'المجموع الكلي',
                              kWarning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              '${(driver?.cash ?? 0).toStringAsFixed(0)} دج',
                              'الموجود',
                              const Color(0xFF00897B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              '${(driver?.commissionPercent ?? 0).toStringAsFixed(0)}%',
                              'نسبة الخصم',
                              const Color(0xFFE67E22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _kpiCard(
                              '${((driver?.cash ?? 0) * (driver?.commissionPercent ?? 0) / 100).toStringAsFixed(0)} دج',
                              'المبلغ اللي يتخصم',
                              const Color(0xFFE74C3C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _infoCard(CupertinoIcons.mail, driver?.email ?? '—'),
                      const SizedBox(height: 10),
                      _infoCard(CupertinoIcons.phone, driver?.phone ?? '—'),
                      const SizedBox(height: 10),
                      if (driver?.canSetPricing == true) ...[
                        _infoCard(
                          CupertinoIcons.money_dollar_circle,
                          'تعديل إعدادات التسعيرة',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DriverPricingSettingsScreen(
                                      isEditMode: true,
                                    ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                      _infoCard(
                        CupertinoIcons.money_dollar_circle,
                        'كشف الحساب',
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _DriverStatementSheet(driver: driver),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      _infoCard(
                        CupertinoIcons.chat_bubble_2_fill,
                        'التعليقات',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _DriverCommentsScreen(
                                driverName: '${driver?.firstName ?? ''} ${driver?.lastName ?? ''}'.trim(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kInfo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kInfo.withOpacity(0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              color: kInfo,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'سيتم جمع موقعك لتتبع الطلبيات حتى عند تصغير التطبيق أو إغلاق الشاشة.',
                                style: TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 11,
                                  color: kInfo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          await DriverService.signOut();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushNamedAndRemoveUntil('/login', (r) => false);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: kDanger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kDanger.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.square_arrow_right,
                                color: kDanger,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'تسجيل الخروج',
                                style: TextStyle(
                                  color: kDanger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DriverSettingsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: kPrimary.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.settings,
                                color: kPrimary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'الإعدادات',
                                style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: () {
                          final diff = DateTime.now().difference(_lastRefresh);
                          final text = diff.inSeconds < 60
                              ? 'آخر تحديث: منذ ${diff.inSeconds} ثانية'
                              : diff.inMinutes < 60
                                  ? 'آخر تحديث: منذ ${diff.inMinutes} دقيقة'
                                  : 'آخر تحديث: منذ ${diff.inHours} ساعة';
                          return Text(text,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                              fontFamily: 'Amiri'));
                        }(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _kpiCard(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: neuShadow(blur: 8, offset: 4),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color,
            fontFamily: 'Amiri',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kTextGrey,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    ),
  );

  Widget _infoCard(IconData icon, String text, {VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: neuShadow(blur: 8, offset: 4),
          ),
          child: Row(
            children: [
              Icon(icon, color: kPrimary, size: 18),
              const Spacer(),
              Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 14,
                  color: kTextDark,
                ),
              ),
            ],
          ),
        ),
      );
}

Future<List<Map<String, dynamic>>> _loadDriverComments() async {
  try {
    final result = await ApiClient.getList(
      '/api/drivers/${DriverService.uid}/comments',
    );
    return result.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  شاشة التعليقات للسائق
// ══════════════════════════════════════════════════════════════════════════════
class _DriverCommentsScreen extends StatelessWidget {
  final String driverName;
  const _DriverCommentsScreen({required this.driverName});

  @override
  Widget build(BuildContext context) {
    final dn = driverName;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'التعليقات',
          style: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: neuBox(radius: 12),
            child: const Icon(CupertinoIcons.chevron_right, color: kPrimary),
          ),
        ),
      ),
      body: DriverService.uid == null
          ? const Center(child: Text('يجب تسجيل الدخول'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadDriverComments(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kPrimary),
                  );
                }
                final docs = snap.data ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chat_bubble_2,
                          size: 50,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد تعليقات بعد',
                          style: TextStyle(
                            color: kTextGrey,
                            fontSize: 14,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final commentId = '${d['_id']}';
                    final userName = d['userName'] as String? ?? 'زبون';
                    final text = d['text'] as String? ?? '';
                    final replies = (d['replies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                    final timeStr = _formatCommentTime(d['createdAt']);
                    final userPhoto = d['userPhoto'] as String? ?? '';
                    final userGender = d['userGender'] as String? ?? '';
                    return _CommentCard(
                      commentId: commentId,
                      userName: userName,
                      driverName: dn,
                      text: text,
                      replies: replies,
                      timeStr: timeStr,
                      userPhoto: userPhoto,
                      userGender: userGender,
                    );
                  },
                );
              },
            ),
    );
  }

  static String _formatCommentTime(dynamic ts) {
    if (ts == null) return '';
    final t = ts is String ? DateTime.parse(ts) : DateTime.parse(ts.toString());
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _CommentCard extends StatefulWidget {
  final String commentId;
  final String userName;
  final String driverName; // <--- الجديد
  final String text;
  List<Map<String, dynamic>> replies; // <--- جعلناها قابلة للتعديل محلياً
  final String timeStr;
  final String userPhoto;
  final String userGender;

  _CommentCard({
    required this.commentId,
    required this.userName,
    required this.driverName, // <--- الجديد
    required this.text,
    required this.replies,
    required this.timeStr,
    this.userPhoto = '',
    this.userGender = '',
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _expanded = false;
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  int get _replyCount => widget.replies.length;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post(
        '/api/comments/${widget.commentId}/reply',
        {'driverId': DriverService.uid, 'userName': widget.driverName, 'text': text},
      );
      
      // تحديث محلي فوراً
      setState(() {
        widget.replies.add({
          'userName': widget.driverName,
          'text': text,
          'createdAt': DateTime.now().toIso8601String(),
        });
        _replyCtrl.clear();
        _expanded = true; // نفتح التعليق ليظهر الرد
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')), backgroundColor: kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(widget.timeStr, style: const TextStyle(fontSize: 10, color: kTextGrey, fontFamily: 'Amiri')),
              const Spacer(),
              Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark, fontFamily: 'Amiri')),
              const SizedBox(width: 8),
              // منطق الصورة الذكي
              ClipOval(
                child: (widget.userPhoto.isNotEmpty && !widget.userPhoto.contains('default'))
                  ? Image.network(widget.userPhoto, width: 24, height: 24, fit: BoxFit.cover)
                  : Image.asset(
                      widget.userGender == 'female' ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
                      width: 24, height: 24, fit: BoxFit.cover,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.text, style: const TextStyle(fontSize: 14, color: kTextDark, fontFamily: 'Amiri', height: 1.5)),
          const SizedBox(height: 12),
          if (_expanded && _replyCount > 0) ...[
            Container(
              padding: const EdgeInsets.only(right: 12, top: 8),
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: kPrimary, width: 2))),
              child: Column(children: widget.replies.map((r) => _ReplyTile(reply: r)).toList()),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'اكتب رداً...',
                    hintStyle: const TextStyle(fontSize: 12, fontFamily: 'Amiri'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: kBg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      onPressed: _addReply,
                      icon: const Icon(CupertinoIcons.paperplane_fill, color: kPrimary),
                    ),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _replyCount > 0 ? (_expanded ? 'إخفاء الردود' : 'عرض $_replyCount ردود') : 'رد',
                style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600, fontFamily: 'Amiri'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Map<String, dynamic> reply;
  const _ReplyTile({required this.reply});

  @override
  Widget build(BuildContext context) {
    final name = reply['userName'] as String? ?? 'مستخدم';
    final text = reply['text'] as String? ?? '';
    final rPhoto = reply['userPhoto'] as String? ?? '';
    final rGender = reply['userGender'] as String? ?? '';
    final ts = reply['createdAt'] ?? '';
    String timeStr = '';
    if (ts is String) {
      try { final d = DateTime.parse(ts); final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) timeStr = 'الآن';
      else if (diff.inHours < 1) timeStr = 'منذ ${diff.inMinutes} دقيقة';
      else if (diff.inDays < 1) timeStr = 'منذ ${diff.inHours} ساعة';
      else timeStr = '${d.day}/${d.month}'; } catch (_) { timeStr = ''; }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextDark, fontFamily: 'Amiri')),
              const SizedBox(width: 6),
              Image.asset(
                rGender == 'female' ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
                width: 16, height: 16, fit: BoxFit.cover,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontSize: 12, color: kTextGrey, fontFamily: 'Amiri')),
        ],
      ),
    );
  }
}

class _EarningsData {
  final double percent;
  final double totalEarnings;
  final double pendingCommission;
  final double discount;
  final List<Map<String, dynamic>> stats;

  _EarningsData({
    required this.percent,
    required this.totalEarnings,
    required this.pendingCommission,
    required this.discount,
    required this.stats,
  });
}

Future<_EarningsData> _loadEarningsData() async {
  try {
    final driverData = await ApiClient.get('/api/drivers/${DriverService.uid}');
    final percent = (driverData['commissionPercent'] ?? 0).toDouble();
    final totalEarnings = (driverData['totalEarnings'] ?? 0).toDouble();
    final cash = (driverData['cash'] ?? 0).toDouble();
    final discount = (driverData['discount'] ?? 0).toDouble();
    final pendingCommission = cash * percent / 100;
    final statsResult = await ApiClient.getList(
      '/api/drivers/${DriverService.uid}/stats',
    );
    final stats = statsResult.cast<Map<String, dynamic>>();
    return _EarningsData(
      percent: percent,
      totalEarnings: totalEarnings,
      pendingCommission: pendingCommission,
      discount: discount,
      stats: stats,
    );
  } catch (_) {
    return _EarningsData(
      percent: 0,
      totalEarnings: 0,
      pendingCommission: 0,
      discount: 0,
      stats: [],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  شاشة كشف الحساب الشهري
// ══════════════════════════════════════════════════════════════════════════════
class _MonthlyStatementScreen extends StatelessWidget {
  const _MonthlyStatementScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'كشف حساب شهري',
          style: TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: neuBox(radius: 12),
            child: const Icon(CupertinoIcons.chevron_right, color: kPrimary),
          ),
        ),
      ),
      body: DriverService.uid == null
          ? const Center(child: Text('يجب تسجيل الدخول'))
          : FutureBuilder<_EarningsData>(
              future: _loadEarningsData(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CupertinoActivityIndicator(color: kPrimary),
                  );
                }
                final data = snap.data;
                final percent = data?.percent ?? 0;
                final totalEarnings = data?.totalEarnings ?? 0;
                final pendingCommission = data?.pendingCommission ?? 0;
                final discount = data?.discount ?? 0;
                final docs = data?.stats ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _summaryCell(
                                  '${totalEarnings.toStringAsFixed(0)} دج',
                                  'إجمالي الأرباح',
                                  kPrimary,
                                ),
                              ),
                              Expanded(
                                child: _summaryCell(
                                  '${percent.toStringAsFixed(0)}%',
                                  'نسبة الخصم',
                                  kWarning,
                                ),
                              ),
                              Expanded(
                                child: _summaryCell(
                                  '${pendingCommission.toStringAsFixed(0)} دج',
                                  'المبلغ اللي يتخصم',
                                  kDanger,
                                ),
                              ),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: 8),
                            _summaryCell(
                              '${discount.toStringAsFixed(0)} دج',
                              'خصم إضافي',
                              Colors.purple,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'لا توجد إحصائيات بعد',
                            style: TextStyle(
                              color: kTextGrey,
                              fontSize: 14,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                      )
                    else
                      ...docs.map((d) {
                        final month = d['month'] as int? ?? 1;
                        final year = d['year'] as int? ?? 2024;
                        final earnings = (d['earnings'] ?? 0).toDouble();
                        final deliveries = d['deliveries'] ?? 0;
                        final commission = earnings * percent / 100;
                        final netEarnings = earnings - commission;
                        final months = [
                          'يناير',
                          'فبراير',
                          'مارس',
                          'أبريل',
                          'ماي',
                          'يونيو',
                          'يوليو',
                          'أوت',
                          'سبتمبر',
                          'أكتوبر',
                          'نوفمبر',
                          'ديسمبر',
                        ];
                        final monthName = months[month - 1];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '$monthName $year',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: kTextDark,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kSuccess.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$deliveries توصيلة',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: kSuccess,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Amiri',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _statItem(
                                      '${earnings.toStringAsFixed(0)} دج',
                                      'الإجمالي',
                                      kPrimary,
                                    ),
                                  ),
                                  Expanded(
                                    child: _statItem(
                                      '-${commission.toStringAsFixed(0)} دج',
                                      'الخصم $percent%',
                                      kDanger,
                                    ),
                                  ),
                                  Expanded(
                                    child: _statItem(
                                      '${netEarnings.toStringAsFixed(0)} دج',
                                      'الصافي',
                                      kSuccess,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }

  static Widget _summaryCell(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: color,
            fontFamily: 'Amiri',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kTextGrey,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    );
  }

  static Widget _statItem(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
              fontFamily: 'Amiri',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: kTextGrey,
              fontFamily: 'Amiri',
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  نافذة الشروط والقوانين مع عداد 8 ثواني
// ══════════════════════════════════════════════════════════════════════════════
class _TermsDialog extends StatefulWidget {
  final double commissionPercent;
  final VoidCallback onAgreed;

  const _TermsDialog({required this.commissionPercent, required this.onAgreed});

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog>
    with SingleTickerProviderStateMixin {
  int _countdown = 8;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown = _countdown - 1);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAgree = _countdown == 0;
    return AlertDialog(
      backgroundColor: kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      title: const Text(
        'الشروط والقوانين',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Amiri',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: kPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _termItem(
              'نسبة الخصم: ${widget.commissionPercent.toStringAsFixed(0)}% من كل توصيلة',
              Icons.percent,
              kWarning,
            ),
            _termItem(
              'يجب تسديد الخصم شهرياً وإلا سيتم تعليق حسابك',
              Icons.calendar_month,
              kDanger,
            ),
            _termItem(
              'التطبيق غير مسؤول عن أي حادث أو ضرر يحدث أثناء التوصيل',
              Icons.shield_outlined,
              kTextGrey,
            ),
            _termItem(
              'يجب التحقق من كل طلبية قبل استلامها والتأكد من صحتها',
              Icons.verified_outlined,
              kInfo,
            ),
            _termItem(
              'أنت المسؤول الوحيد عن سلامة الطلبيات أثناء التوصيل',
              Icons.person_outline,
              kPrimary,
            ),
            _termItem(
              'أتعهد بعدم توصيل أي مواد غير قانونية أو غير شرعية',
              Icons.gavel_outlined,
              kDanger,
            ),
            _termItem(
              'أتعهد بعدم تفويت الصلاة في المسجد بسبب الطلبيات إلا في حالات خاصة',
              Icons.mosque_outlined,
              kSuccess,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'عند الموافقة، تلتزم بجميع الشروط المذكورة أعلاه.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 12,
                  color: kTextDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAgree ? kPrimary : Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: canAgree ? widget.onAgreed : null,
            child: Text(
              canAgree ? 'موافق' : 'انتظر $_countdown ثانية',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _termItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 13,
                color: kTextDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
