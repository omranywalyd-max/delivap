// ══════════════════════════════════════════════════════════════════════════════
//  driver_selection_screen.dart — شاشة اختيار السائق (رادار مباشر)
//  ✅ شيت السائق: اسم + رقم + تعليقات الزبائن من Firestore
//  ✅ تعليقات: إضافة + تعديل + حذف (خاصة بكل زبون)
//  ✅ صورة الزبون حسب الجنس (assets/images/avatar.png أو avatarf.png)
// ══════════════════════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/main_page.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';
import 'package:flutter_application_1/user_local.dart';
import 'package:flutter_application_1/products_list_screen.dart';



// ─── ثوابت الألوان ────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF7D29C6);
const _kPrimaryLt = Color(0xFF9232E8);
const _kBg = Color(0xFFF1F0F5);
const _kCard = Color(0xFFDCDAE6);
const _kNeumLight = Color(0xFFD8D7DE);
const _kNeumShadow = Color(0xFFB8B1C8);
const _kTextDark = Color(0xFF2D2A3A);
const _kTextGrey = Color(0xFF6E6B7B);
const _kSuccess = Color(0xFF27AE60);
const _kDanger = Color(0xFFD50000);

List<BoxShadow> _neu({double b = 8, double o = 3}) => [
  BoxShadow(
    color: _kNeumShadow.withOpacity(0.55),
    blurRadius: b,
    offset: Offset(o, o)),
  BoxShadow(
    color: Colors.white.withOpacity(0.85),
    blurRadius: b,
    offset: Offset(-o, -o)),
];

// ─── مواضع الرادار ────────────────────────────────────────────────────────────
const List<_SlotConfig> _kSlots = [
  _SlotConfig(angle: -90, radius: 0.36),
  _SlotConfig(angle: -30, radius: 0.22),
  _SlotConfig(angle: 30, radius: 0.38),
  _SlotConfig(angle: 90, radius: 0.21),
  _SlotConfig(angle: 150, radius: 0.37),
  _SlotConfig(angle: 210, radius: 0.22),
  _SlotConfig(angle: -150, radius: 0.35),
  _SlotConfig(angle: -60, radius: 0.20),
  _SlotConfig(angle: 120, radius: 0.38),
  _SlotConfig(angle: 0, radius: 0.22),
];

class _SlotConfig {
  final double angle;
  final double radius;
  const _SlotConfig({required this.angle, required this.radius});
}

// ─── نموذج السائق ─────────────────────────────────────────────────────────────
class DriverModel {
  final String uid, firstName, lastName, phone;
  final String? photoUrl, gender, vehicleType;
  final double totalEarnings;
  final String cityNameAr, cityNameFr;
  final int totalDeliveries;

  const DriverModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.cityNameAr,
    required this.cityNameFr,
    this.photoUrl,
    this.gender,
    this.vehicleType,
    this.totalEarnings = 0,
    this.totalDeliveries = 0,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isFemale => gender == 'female' || gender == 'أنثى';

  factory DriverModel.fromMap(Map<String, dynamic> d) {
    return DriverModel(
      uid: d['uid'] as String? ?? d['_id'] as String,
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      gender: d['gender'] as String?,
      vehicleType: d['vehicleType'] as String?,
      cityNameAr:
          d['cityNameAr'] as String? ??
          d['cityName'] as String? ??
          '',
      cityNameFr: d['cityNameFr'] as String? ?? '',
      totalEarnings: (d['totalEarnings'] as num? ?? 0).toDouble(),
      totalDeliveries: d['totalDeliveries'] as int? ?? 0);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DriverSelectionScreen
// ══════════════════════════════════════════════════════════════════════════════
class DriverSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String? transportType;
  const DriverSelectionScreen({super.key, required this.orderData, this.transportType});

  @override
  State<DriverSelectionScreen> createState() => DriverModelSelectionScreenState();
}

class DriverModelSelectionScreenState extends State<DriverSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse1, _pulse2, _pulse3;

  late AnimationController _cardCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  DriverModel? _selectedDriver;
  bool _confirming = false;
  List<DriverModel> _allDrivers = [];
  bool _loadingDrivers = true;
  Map<String, dynamic> _driverFreeDeliveries = {};
  Map<String, dynamic> _driverLoyalties = {};
  bool _selectedDriverHasFreeDelivery = false;
  List<String> _cities = [];
  String? _selectedCity;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800))..repeat();

    _pulse1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut)));
    _pulse2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.2, 0.95, curve: Curves.easeOut)));
    _pulse3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380));
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn);

    _loadDrivers();
    _loadUserFreeDeliveries();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      String uCityAr = widget.orderData['userCityName'] as String? ?? '';
      final String uCityFr = widget.orderData['userCityNameFr'] as String? ?? '';
      if (uCityAr.isEmpty) {
        uCityAr = UserLocal.data?['cityName'] as String? ?? '';
      }
      final vt = widget.transportType ?? 'motorcycle';
      final data = await ApiClient.getList('/api/drivers/cities?vehicleType=$vt');
      final allCities = data.cast<String>();
      if (mounted) {
        String normalize(String s) => s.trim().replaceAll('_', ' ');
        String? autoSelect;
        final uAr = normalize(uCityAr);
        final uFr = normalize(uCityFr);
        for (final c in allCities) {
          final cn = normalize(c);
          if (uAr.isNotEmpty && cn == uAr) { autoSelect = c; break; }
          if (uFr.isNotEmpty && cn == uFr) { autoSelect = c; break; }
        }
        setState(() {
          _cities = allCities;
          _selectedCity = autoSelect;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserFreeDeliveries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final data = await ApiClient.get('/api/users/${user.uid}');
      if (data != null && mounted) {
        final driverFree = data['driverFreeDelivery'] as Map<String, dynamic>? ?? {};
        final driverLoyalty = data['driverLoyalty'] as Map<String, dynamic>? ?? {};
        setState(() {
          _driverFreeDeliveries = driverFree;
          _driverLoyalties = driverLoyalty;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final data = await ApiClient.getList('/api/drivers?isOnline=true&isActive=true');
      if (mounted) {
        setState(() {
          _allDrivers = data.map((d) => DriverModel.fromMap(d)).toList();
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  void _selectDriver(DriverModel driver) {
    if (_selectedDriver?.uid == driver.uid) return;
    final hasFree = _driverFreeDeliveries[driver.uid] == true;
    setState(() {
      _selectedDriver = driver;
      _selectedDriverHasFreeDelivery = hasFree;
    });
    _cardCtrl.forward(from: 0);
  }

  // ✅ فتح شيت التعليقات
  void _openDriverSheet(DriverModel driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverModelCommentsSheet(driver: driver));
  }

  Future<void> _confirm() async {
    if (_selectedDriver == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final orderData = {
        ...widget.orderData,
        'driverId': _selectedDriver!.uid,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_selectedDriverHasFreeDelivery) {
        orderData['isFreeDelivery'] = true;
        orderData['deliveryFee'] = 0;
        orderData['total'] = (orderData['subtotal'] as num? ?? 0).toDouble();
      }
      final isTransport = widget.transportType != null;
      String orderId;

      if (isTransport) {
        final created = await ApiClient.post('/api/transport-orders', orderData);
        orderId = (created['_id'] as String?) ?? '';
        if (orderId.isEmpty) throw Exception('لم يتم حفظ الطلبية، حاول مجدداً');
        await ApiClient.post('/api/notify-driver', {
          'driverId': _selectedDriver!.uid,
          'title': '🚗 طلب نقل جديد',
          'body': 'من: ${widget.orderData['pickup']?['address'] as String? ?? ''} | السعر: ${widget.orderData['price'] as String? ?? '0'} DZD',
          'data': {'orderId': orderId, 'type': 'new_transport_order'},
        });
      } else {
        final created = await ApiClient.post('/api/orders', orderData);
        orderId = (created['_id'] as String?) ?? '';
        if (orderId.isEmpty) throw Exception('لم يتم حفظ الطلبية، حاول مجدداً');

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final freeDel = <String, dynamic>{};
          if (widget.orderData['isFreeDelivery'] == true) {
            freeDel['hasFreeDelivery'] = false;
          }
          if (_selectedDriverHasFreeDelivery) {
            freeDel['hasFreeDelivery'] = false;
            freeDel['driverFreeDelivery.${_selectedDriver!.uid}'] = false;
          }
          if (freeDel.isNotEmpty) {
            await ApiClient.put('/api/users/${user.uid}', freeDel);
          }
        }

        final feeText = (orderData['deliveryFee'] as num? ?? 0) == 0
            ? 'توصيل مجاني'
            : '${(orderData['deliveryFee'] as num? ?? 0).toInt()} DZD';
        await ApiClient.post('/api/notify-driver', {
          'driverId': _selectedDriver!.uid,
          'title': '📦 طلبية جديدة',
          'body': 'من: ${widget.orderData['address'] as String? ?? ''} | المبلغ: ${(orderData['total'] as num? ?? 0).toInt()} DZD | $feeText',
          'data': {'orderId': orderId, 'type': 'new_order'},
        });
      }

      GlobalCart.provider.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
        (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: SafeArea(
            bottom: false,
            child: _buildBody()),
        ),
        statusBarGradient(context),
      ],
    );
  }

  Widget _buildBody() {
    String uCityAr = widget.orderData['userCityName'] as String? ?? '';
    if (uCityAr.isEmpty) {
      uCityAr = UserLocal.data?['cityName'] as String? ?? '';
    }

    if (_loadingDrivers) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final filteredDrivers = _allDrivers.where((d) {
      String dAr = d.cityNameAr.trim();
      String uAr = uCityAr.trim();

      bool cityMatch = false;
      if (_selectedCity != null && _selectedCity!.isNotEmpty) {
        cityMatch = dAr == _selectedCity!.trim();
      } else if (uAr.isNotEmpty) {
        cityMatch = dAr == uAr;
      }

      if (!cityMatch) return false;

      if (widget.transportType != null) {
        if (d.vehicleType != widget.transportType) return false;
      } else {
        if (d.vehicleType != 'motorcycle') return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        if (_cities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kNeumShadow.withOpacity(0.3)),
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedCity,
                hint: const Text('فلترة حسب المدينة', style: TextStyle(fontFamily: 'Amiri', fontSize: 13, color: kTextGrey)),
                underline: const SizedBox(),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                onChanged: (val) => setState(() => _selectedCity = val),
                items: _cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)))).toList(),
              ),
            ),
          ),
        Expanded(
          child: filteredDrivers.isEmpty
              ? _buildNoDrivers()
              : _buildRadar(filteredDrivers)),
        if (_selectedDriver != null) _buildDriverCard(_selectedDriver!),
        _buildConfirmButton(),
      ],
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    leading: GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neu(b: 6, o: 3)),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: _kPrimary,
          size: 20))),
    title: const Text(
      'اختر سائقك',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _kTextDark,
        fontFamily: 'Amiri')));

  // ─── رادار السائقين ───────────────────────────────────────────────────────
  Widget _buildRadar(List<DriverModel> drivers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final size = min(w, h);
        final cx = w / 2;
        final cy = h / 2;
        final count = min(drivers.length, _kSlots.length);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _RadarPainter())),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _PulsePainter(
                    pulse1: _pulse1.value,
                    pulse2: _pulse2.value,
                    pulse3: _pulse3.value,
                    maxRadius: size * 0.42)))),
            Positioned(left: cx - 36, top: cy - 36, child: _buildCenterDot()),
            ...List.generate(count, (i) {
              final slot = _kSlots[i];
              final rad = slot.angle * pi / 180.0;
              final radius = size * slot.radius;
              final dx = cx + radius * cos(rad);
              final dy = cy + radius * sin(rad);
              final driver = drivers[i];
              final isSelected = _selectedDriver?.uid == driver.uid;

              return Positioned(
                left: dx - 39,
                top: dy - 39,
                child: GestureDetector(
                  onTap: () => _selectDriver(driver),
                  // ✅ ضغط طويل يفتح شيت التعليقات
                  onLongPress: () => _openDriverSheet(driver),
                  child: DriverModelPin(driver: driver, isSelected: isSelected)));
            }),
          ]);
      });
  }

  // ─── المركز ───────────────────────────────────────────────────────────────
  Widget _buildCenterDot() => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _kBg,
      boxShadow: _neu(b: 12, o: 4)),
    child: Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_kPrimary, _kPrimaryLt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1),
          ]),
        child: const Icon(
          CupertinoIcons.location_fill,
          color: Colors.white,
          size: 22))));

  // ─── لا يوجد سائقون ───────────────────────────────────────────────────────
  Widget _buildNoDrivers() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBg,
            boxShadow: _neu(b: 14, o: 5)),
          child: const Icon(
            CupertinoIcons.car_fill,
            color: Color(0xFFCCCCCC),
            size: 44)),
        const SizedBox(height: 24),
        const Text(
          'لا يوجد سائقون متاحون الآن',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _kTextDark,
            fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Text(
          'حاول مرة أخرى بعد قليل',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
            fontFamily: 'Amiri')),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => setState(() {}),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _neu(b: 8, o: 4)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.refresh, color: _kPrimary, size: 18),
                SizedBox(width: 8),
                Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri')),
              ]))),
      ]));

  // ─── بطاقة السائق المختار (قابلة للضغط لفتح التعليقات) ───────────────────
  Widget _buildDriverCard(DriverModel driver) {
    return SlideTransition(
      position: _cardSlide,
      child: FadeTransition(
        opacity: _cardFade,
        child: GestureDetector(
          // ✅ ضغط على الكارد يفتح شيت التعليقات
          onTap: () => _openDriverSheet(driver),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBg, Color(0xFFE6E4F0)]),
              boxShadow: [
                BoxShadow(
                  color: _kNeumShadow.withOpacity(0.6),
                  blurRadius: 10,
                  offset: Offset(4, 4)),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(-4, -4)),
              ],
              border: Border.all(color: _kPrimary.withOpacity(0.1))),
            child: Row(
              children: [
                // ✅ مؤشر "اضغط لقراءة التعليقات"
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // اسم السائق
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_driverFreeDeliveries[driver.uid] == true)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_kSuccess, _kSuccess.withOpacity(0.7)]),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Text(
                              'هدية 🎁',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri')))
                        else
                          Builder(builder: (_) {
                            final loyalty = (_driverLoyalties[driver.uid] as num?)?.toInt() ?? 0;
                            if (loyalty > 0) {
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade700.withOpacity(0.3))),
                                child: Text(
                                  '$loyalty/5 🎁',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Amiri')),
                              );
                            }
                            return const SizedBox();
                          }),
                        Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.chat_bubble_text,
                                  color: _kPrimary,
                                  size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'اضغط لقراءة التعليقات',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _kPrimary,
                                    fontFamily: 'Amiri')),
                              ])),
                      ]),
                        ]),
                      const SizedBox(height: 6),
                      Text(
                        driver.fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark,
                          fontFamily: 'Amiri'),
                        textAlign: TextAlign.right),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            driver.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontFamily: 'Amiri')),
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.phone_fill,
                            color: _kPrimary,
                            size: 14),
                        ]),
                    ])),
                const SizedBox(width: 14),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBg,
                    border: Border.all(color: _kPrimary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.25),
                        blurRadius: 12),
                    ]),
                  child: ClipOval(child: _buildAvatar(driver))),
              ])))));
  }

  Widget _buildAvatar(DriverModel driver) => driver.photoUrl != null && driver.photoUrl!.isNotEmpty
      ? CachedNetworkImage(
          imageUrl: driver.photoUrl!,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Image.asset(
            driver.isFemale ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
            width: 68,
            height: 68,
            fit: BoxFit.cover,
          ),
        )
      : Image.asset(
          driver.isFemale ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
          width: 68,
          height: 68,
          fit: BoxFit.cover);

  // ─── زر التأكيد ───────────────────────────────────────────────────────────
  Widget _buildConfirmButton() {
    final isEnabled = _selectedDriver != null && !_confirming;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedDriverHasFreeDelivery)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kSuccess.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kSuccess.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎁', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'توصيل مجاني مع هذا السائق!',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kSuccess,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri'),
                  ),
                ],
              ),
            ),
          AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [_kPrimary, _kPrimaryLt],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft)
              : null,
          color: isEnabled ? null : Colors.grey.shade300,
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
                ]
              : []),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isEnabled ? _confirm : null,
            child: Center(
              child: _confirming
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_shield_fill,
                          color: isEnabled
                              ? Colors.white
                              : Colors.grey.shade500,
                          size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEnabled ? 'تأكيد السائق' : 'اختر سائقاً من الرادار',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isEnabled
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontFamily: 'Amiri')),
                      ]))))),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ شيت التعليقات — معلومات السائق + تعليقات الزبائن
// ══════════════════════════════════════════════════════════════════════════════
class DriverModelCommentsSheet extends StatefulWidget {
  final DriverModel driver;
  const DriverModelCommentsSheet({required this.driver});

  @override
  State<DriverModelCommentsSheet> createState() => DriverModelCommentsSheetState();
}

class DriverModelCommentsSheetState extends State<DriverModelCommentsSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sending = false;
  String? _editingCommentId;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  Future<void> _loadComments() async {
    try {
        final data = await ApiClient.getList('/api/comments?driverId=${widget.driver.uid}');
      if (mounted) {
        setState(() {
          _comments = data.cast<Map<String, dynamic>>();
          _loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
    _loadComments();
    // استماع للتحديثات المباشرة
    SocketClient.on('comment:updated', _onCommentUpdated);
  }

  void _onCommentUpdated(_) {
    if (mounted) _loadComments();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _commentCtrl.dispose();
    SocketClient.off('comment:updated', _onCommentUpdated);
    super.dispose();
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    if (ts is String) {
      final dt = DateTime.tryParse(ts);
      if (dt == null) return '';
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      // جلب بيانات الزبون
      final ud = await ApiClient.get('/api/users/${user.uid}') as Map<String, dynamic>? ?? {};
      final apiName = '${ud['firstName'] ?? ''} ${ud['lastName'] ?? ''}'
          .trim();
      final userName = apiName.isNotEmpty ? apiName : (FirebaseAuth.instance.currentUser?.displayName ?? 'زبون');
      final userGender = ud['gender'] as String? ?? '';
      final userPhoto = ud['photoUrl'] as String? ?? '';

     if (_editingCommentId != null) {
    // للتعديل: نبعث للرابط /api/comments/:id
    await ApiClient.put('/api/comments/${_editingCommentId!}', {
      'text': text,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  } else {
    // للإضافة: نبعث للرابط /api/comments ونزيدو الـ driverId في الجسم (Body)
    await ApiClient.post('/api/comments', {
      'driverId': widget.driver.uid, // ✅ ضروري نزيدوه هنا في الـ Body
      'text': text,
      'userId': user.uid,
      'userName': userName,
      'userPhoto': userPhoto,
      'userGender': userGender,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
      _commentCtrl.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ: $e',
              style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: _kDanger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendReply(String commentId, String text) async {
    if (text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ud = await ApiClient.get('/api/users/${user.uid}') as Map<String, dynamic>? ?? {};
      final apiName = '${ud['firstName'] ?? ''} ${ud['lastName'] ?? ''}'.trim();
      final userName = apiName.isNotEmpty ? apiName : (user.displayName ?? 'زبون');
      await ApiClient.post('/api/comments/$commentId/reply', {
        'text': text,
        'userId': user.uid,
        'userName': userName,
        'userPhoto': ud['photoUrl'] as String? ?? '',
        'userGender': ud['gender'] as String? ?? '',
      });
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: _kDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await ApiClient.delete('/api/drivers/${widget.driver.uid}/comments/$commentId');
    _loadComments();
  }

  void _startEdit(String commentId, String text) {
    setState(() {
      _editingCommentId = commentId;
      _commentCtrl.text = text;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _commentCtrl.clear();
    });
  }

  void _showCommentOptions(String commentId, String text, bool isMyComment, {String userName = ''}) {
    if (isMyComment) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _startEdit(commentId, text);
              },
              child: const Text(
                'تعديل التعليق',
                style: TextStyle(fontFamily: 'Amiri', color: _kPrimary))),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _deleteComment(commentId);
              },
              child: const Text(
                'حذف التعليق',
                style: TextStyle(fontFamily: 'Amiri'))),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')))));
    } else {
      // تعليق غير تاعي → تبليغ
      showCupertinoModalPopup(
        context: context,
        builder: (_) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _reportComment(commentId, text, userName);
              },
              child: const Text(
                'الإبلاغ عن هذا التعليق',
                style: TextStyle(fontFamily: 'Amiri'))),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')))));
    }
  }

  Future<void> _reportComment(String commentId, String text, String userName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await ApiClient.post('/api/comments/$commentId/report', {
        'userId': user.uid,
        'userName': user.displayName ?? 'زبون',
        'reason': 'محتوى غير لائق',
        'note': text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('تم الإبلاغ بنجاح', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: _kDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    }
  }

  Widget _buildCommentsList(String? currentUserId) {
    if (_loadingComments) {
      return const Center(
        child: CupertinoActivityIndicator(color: _kPrimary));
    }

    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kBg,
                shape: BoxShape.circle,
                boxShadow: _neu(b: 10, o: 4)),
              child: Icon(
                CupertinoIcons.chat_bubble,
                size: 32,
                color: Colors.grey.shade400)),
            const SizedBox(height: 14),
            const Text(
              'لا توجد تعليقات بعد',
              style: TextStyle(
                color: Colors.black45,
                fontFamily: 'Amiri',
                fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'كن أول من يكتب تعليقاً!',
              style: TextStyle(
                color: Colors.black26,
                fontFamily: 'Amiri',
                fontSize: 12)),
          ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: _comments.length,
      itemBuilder: (_, i) {
        final d = _comments[i];
        final commentId = d['_id'] as String;
        final isMyComment = d['userId'] == currentUserId;
        final userName = d['userName'] as String? ?? 'زبون';
        final text = d['text'] as String? ?? '';
        final userGender = d['userGender'] as String? ?? '';
        final userPhoto = d['userPhoto'] as String? ?? '';
        final isFemale =
            userGender == 'أنثى' || userGender == 'female';
        final timeStr = _formatTime(d['createdAt']);
        final isEdited = d['updatedAt'] != null;
        final replies = (d['replies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        return _CommentTile(
          key: ValueKey(commentId),
          commentId: commentId,
          text: text,
          userName: userName,
          userPhoto: userPhoto,
          isFemale: isFemale,
          timeStr: timeStr,
          isEdited: isEdited,
          isMyComment: isMyComment,
          replies: replies,
          onOptions: () => _showCommentOptions(commentId, text, isMyComment, userName: userName),
          onLongPress: () => _showCommentOptions(commentId, text, isMyComment, userName: userName),
          onReply: (replyText) => _sendReply(commentId, replyText));
      });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────────────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10))),

              // ── هيدر السائق (تدرج بنفسجي) ──────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)]),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7D29C6).withOpacity(0.35),
                      blurRadius: 14,
                      offset: Offset(0, 5)),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15))),
                child: Row(
                  children: [
                    // معلومات
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.driver.fullName.isNotEmpty
                                ? widget.driver.fullName
                                : 'السائق',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Amiri')),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                widget.driver.phone.isNotEmpty
                                    ? widget.driver.phone
                                    : '---',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontFamily: 'Amiri')),
                              const SizedBox(width: 6),
                              const Icon(
                                CupertinoIcons.phone_fill,
                                color: Colors.white70,
                                size: 14),
                            ]),
                        ])),
                    const SizedBox(width: 14),
                    // صورة السائق
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 2)),
                      child: ClipOval(
                        child: widget.driver.photoUrl != null && widget.driver.photoUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.driver.photoUrl!,
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Image.asset(
                                  widget.driver.isFemale
                                      ? 'assets/images/avatarf.png'
                                      : 'assets/images/avatar.png',
                                  width: 65,
                                  height: 65,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                widget.driver.isFemale
                                    ? 'assets/images/avatarf.png'
                                    : 'assets/images/avatar.png',
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover))),
                  ])),

              const SizedBox(height: 12),

              // ── عنوان التعليقات ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'تعليقات الزبائن',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark,
                        fontFamily: 'Amiri')),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.1),
                        shape: BoxShape.circle),
                      child: const Icon(
                        CupertinoIcons.chat_bubble_text_fill,
                        color: _kPrimary,
                        size: 14)),
                  ])),
              const SizedBox(height: 8),

              // ── قائمة التعليقات ─────────────────────────────────────
              Expanded(
                child: _buildCommentsList(currentUserId)),

              // ── حقل إضافة تعليق ─────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: _kBg,
                  boxShadow: [
                    BoxShadow(
                      color: _kNeumShadow.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, -5)),
                  ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شريط التعديل
                    if (_editingCommentId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: _cancelEdit,
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: _kDanger,
                                  fontSize: 12,
                                  fontFamily: 'Amiri'))),
                            const SizedBox(width: 10),
                            const Text(
                              'تعديل التعليق',
                              style: TextStyle(
                                color: _kTextGrey,
                                fontSize: 12,
                                fontFamily: 'Amiri')),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.pencil,
                              color: _kTextGrey,
                              size: 12),
                          ])),

                    Row(
                      children: [
                        const SizedBox(width: 8),
                        // زر الإرسال
                        GestureDetector(
                          onTap: _sending ? null : _sendComment,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF6D22AC),
                                  _kPrimary,
                                  _kPrimaryLt,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _kPrimary.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                              ]),
                            child: Center(
                              child: _sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                  : Icon(
                                      _editingCommentId != null
                                          ? CupertinoIcons.checkmark_alt
                                          : CupertinoIcons.paperplane_fill,
                                      color: Colors.white,
                                      size: 18)))),
                        const SizedBox(width: 10),
                        // حقل النص
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: _neu(b: 6, o: 3)),
                            child: TextField(
                              controller: _commentCtrl,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              minLines: 1,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _kTextDark,
                                fontFamily: 'Amiri'),
                              decoration: const InputDecoration(
                                hintText: 'اكتب تعليقك على هذا السائق...',
                                hintStyle: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 12,
                                  fontFamily: 'Amiri'),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12))))),
                      ]),
                  ])),
            ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ كارد التعليق (تصميم نيومورفيك مليح)
// ══════════════════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final String commentId, text, userName, userPhoto, timeStr;
  final bool isFemale, isMyComment, isEdited;
  final VoidCallback onOptions;
  final VoidCallback? onLongPress;
  final List<Map<String, dynamic>> replies;
  final void Function(String replyText) onReply;

  const _CommentTile({
    super.key,
    required this.commentId,
    required this.text,
    required this.userName,
    required this.userPhoto,
    required this.isFemale,
    required this.timeStr,
    required this.isEdited,
    required this.isMyComment,
    required this.onOptions,
    this.onLongPress,
    required this.replies,
    required this.onReply,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _showReplies = false;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
          child: GestureDetector(
            onLongPress: widget.onLongPress,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kBg, Color(0xFFE6E4F0)]),
            boxShadow: [
              BoxShadow(
                color: _kNeumShadow.withOpacity(0.6),
                blurRadius: 10,
                offset: Offset(4, 4)),
              BoxShadow(
                color: Colors.white,
                blurRadius: 10,
                offset: Offset(-4, -4)),
            ],
            border: widget.isMyComment
                ? Border.all(color: _kPrimary.withOpacity(0.1))
                : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── الهيدر: صورة + اسم + وقت + 3 نقاط ──────────────────
              Row(
                children: [
                  // 3 نقاط (لتعليق الزبون الخاص فقط)
                  if (widget.isMyComment)
                    GestureDetector(
                      onTap: widget.onOptions,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _kBg,
                          shape: BoxShape.circle,
                          boxShadow: _neu(b: 4, o: 2)),
                        child: const Icon(
                          CupertinoIcons.ellipsis,
                          color: _kTextGrey,
                          size: 15)))
                  else
                    const SizedBox(width: 24),

                  const Spacer(),

                  // اسم + وقت
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isMyComment) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2),
                              decoration: BoxDecoration(
                                color: _kPrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                'أنت',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri'))),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            widget.userName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: widget.isMyComment
                                  ? _kPrimary
                                  : _kTextDark,
                              fontFamily: 'Amiri')),
                        ]),
                      if (widget.timeStr.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isEdited)
                              const Text(
                                '(معدّل) ',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.black38,
                                  fontFamily: 'Amiri')),
                            Text(
                              widget.timeStr,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black38)),
                          ]),
                    ]),

                  const SizedBox(width: 10),

                  // صورة الزبون
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kBg,
                      border: widget.isMyComment
                          ? Border.all(
                              color: _kPrimary.withOpacity(0.3),
                              width: 1.5)
                          : null,
                      boxShadow: _neu(b: 5, o: 2)),
                    child: ClipOval(
                      child: Image.asset(
                        widget.isFemale
                            ? 'assets/images/avatarf.png'
                            : 'assets/images/avatar.png',
                        fit: BoxFit.cover)),
                  ),]),

              const SizedBox(height: 10),

              // ── نص التعليق ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isMyComment
                      ? _kPrimary.withOpacity(0.05)
                      : Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: widget.isMyComment
                      ? Border.all(color: _kPrimary.withOpacity(0.1))
                      : Border.all(color: Colors.white.withOpacity(0.7))),
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kTextDark,
                    fontFamily: 'Amiri',
                    height: 1.5),
                  textAlign: TextAlign.right)),

              // ── زر الرد ──────────────────────────────────────────────
              if (widget.replies.isNotEmpty || _showReplies)
                const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => setState(() =>
                        _showReplies = !_showReplies),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showReplies ? 'إخفاء الردود' : 'رد',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kPrimary,
                              fontFamily: 'Amiri')),
                          const SizedBox(width: 4),
                          Icon(
                            _showReplies
                                ? Icons.expand_less
                                : Icons.reply,
                            size: 14,
                            color: _kPrimary),
                          if (widget.replies.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(
                              '(${widget.replies.length})',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _kPrimary,
                                fontFamily: 'Amiri')),
                          ],
                        ])),
                  ),
                ]),

              // ── الردود المموعة ──────────────────────────────────────
              if (_showReplies && widget.replies.isNotEmpty)
                ...widget.replies.map((r) => Padding(
                  padding: const EdgeInsets.only(
                      top: 6, right: 20),
                  child: _buildReplyTile(r))),

              // ── حقل كتابة رد ─────────────────────────────────────────
              if (_showReplies)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            color: _kBg,
                            borderRadius:
                                BorderRadius.circular(16),
                            boxShadow: _neu(b: 3, o: 1)),
                          child: TextField(
                            controller: _replyCtrl,
                            style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Amiri'),
                            decoration: const InputDecoration(
                              hintText: 'اكتب رداً...',
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Amiri'),
                              border: InputBorder.none,
                              isDense: true),
                            textDirection: TextDirection.rtl,
                          )),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          widget.onReply(_replyCtrl.text);
                          _replyCtrl.clear();
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            shape: BoxShape.circle),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 16)),
                      ),
                    ]),
                  ),
            ])))));
  }

  Widget _buildReplyTile(Map<String, dynamic> r) {
    final rName = r['userName'] as String? ?? 'زبون';
    final rText = r['text'] as String? ?? '';
    final rPhoto = r['userPhoto'] as String? ?? '';
    final rGender = r['userGender'] as String? ?? '';
    final rFemale = rGender == 'أنثى' || rGender == 'female';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _kPrimary,
                        fontFamily: 'Amiri')),
                const SizedBox(height: 3),
                Text(rText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kTextDark,
                        fontFamily: 'Amiri',
                        height: 1.4),
                    textAlign: TextAlign.right),
              ])),
          const SizedBox(width: 8),
          ClipOval(
            child: SizedBox(
              width: 26,
              height: 26,
              child: Image.asset(
                rFemale
                    ? 'assets/images/avatarf.png'
                    : 'assets/images/avatar.png',
                fit: BoxFit.cover),
            )),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  دبوس السائق في الرادار
// ══════════════════════════════════════════════════════════════════════════════
class DriverModelPin extends StatelessWidget {
  final DriverModel driver;
  final bool isSelected;
  const DriverModelPin({required this.driver, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBg,
            border: Border.all(
              color: isSelected ? _kPrimary : Colors.transparent,
              width: 3),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.5),
                      blurRadius: 18,
                      spreadRadius: 2),
                  ]
                : [
                    const BoxShadow(
                      color: _kNeumShadow,
                      blurRadius: 8,
                      offset: Offset(3, 3)),
                    const BoxShadow(
                      color: _kNeumLight,
                      blurRadius: 8,
                      offset: Offset(-3, -3)),
                  ]),
          child: ClipOval(child: _buildAvatarContent())),

        const SizedBox(height: 5),

        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? _kPrimary : _kBg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 8)]
                : const [
                    BoxShadow(
                      color: _kNeumShadow,
                      blurRadius: 4,
                      offset: Offset(2, 2)),
                    BoxShadow(
                      color: _kNeumLight,
                      blurRadius: 4,
                      offset: Offset(-2, -2)),
                  ]),
          child: Text(
            driver.fullName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : _kTextDark,
              fontFamily: 'Amiri'))),
      ]);
  }

  Widget _buildAvatarContent() => driver.photoUrl != null && driver.photoUrl!.isNotEmpty
      ? CachedNetworkImage(
          imageUrl: driver.photoUrl!,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Image.asset(
            driver.isFemale ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        )
      : Image.asset(
          driver.isFemale ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
          width: 58,
          height: 58,
          fit: BoxFit.cover);
}

// ══════════════════════════════════════════════════════════════════════════════
//  رسام دوائر الرادار
// ══════════════════════════════════════════════════════════════════════════════
class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = min(size.width, size.height) * 0.44;
    final paint = Paint()
      ..color = _kPrimary.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxR * i / 3, paint);
    }

    final linePaint = Paint()
      ..color = _kPrimary.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i;
      canvas.drawLine(
        center,
        Offset(center.dx + maxR * cos(angle), center.dy + maxR * sin(angle)),
        linePaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  رسام موجات النبض
// ══════════════════════════════════════════════════════════════════════════════
class _PulsePainter extends CustomPainter {
  final double pulse1, pulse2, pulse3, maxRadius;
  const _PulsePainter({
    required this.pulse1,
    required this.pulse2,
    required this.pulse3,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    void drawPulse(double t) {
      if (t <= 0) return;
      canvas.drawCircle(
        center,
        maxRadius * t,
        Paint()
          ..color = _kPrimary.withOpacity((1 - t) * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    }

    drawPulse(pulse1);
    drawPulse(pulse2);
    drawPulse(pulse3);
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.pulse1 != pulse1 || old.pulse2 != pulse2 || old.pulse3 != pulse3;
}
