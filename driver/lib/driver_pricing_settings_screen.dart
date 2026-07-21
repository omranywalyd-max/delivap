// ════════════════════════════════════════════════════════════════════════════
//  driver_pricing_settings_screen.dart
//  شاشة إعداد التسعير للسائق — مع دعم وضع التعديل + تحديد المدينة بـ GPS
//  ✅ تُعرض مرة واحدة إذا لم يكن deliveryConfig موجوداً (وضع إلزامي)
//  ✅ أو تُعرض من صفحة البروفيل للتعديل (isEditMode: true)
//  ✅ التسعير مرتبط بالمدينة الحالية للسائق (GPS → geocoding)
//  ✅ تحفظ البيانات في Firestore → drivers/{uid}/deliveryConfig
// ════════════════════════════════════════════════════════════════════════════

import 'package:dashbord/driver_app.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/map_picker_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:dashbord/theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// MapPickerScreen — يُستخدم لتحديد الموقع يدوياً
// تأكد من أن هذا الملف موجود في مشروعك (نفس ملف delivery_screen.dart أو Services/)

// ════════════════════════════════════════════════════════════════════════════
//  DriverPricingSettingsScreen
// ════════════════════════════════════════════════════════════════════════════
class DriverPricingSettingsScreen extends StatefulWidget {
  /// isEditMode = true → جاء من البروفيل، يرجع للخلف بعد الحفظ
  /// isEditMode = false (default) → وضع إلزامي عند أول مرة
  final bool isEditMode;

  const DriverPricingSettingsScreen({super.key, this.isEditMode = false});

  @override
  State<DriverPricingSettingsScreen> createState() =>
      _DriverPricingSettingsScreenState();
}

class _DriverPricingSettingsScreenState
    extends State<DriverPricingSettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── المدينة الحالية ──────────────────────────────────────────────────────
  String _cityName = '';
  double? _cityLat;
  double? _cityLng;
  bool _loadingCity = true;
  String _cityError = '';
  String _cityNameAr = '';
  String _cityNameFr = '';

  // ── الحزمة الأساسية ────────────────────────────────────────────────────
  double _basePrice = 200;
  int _baseCats = 2;
  double _baseQty = 5;
  double _baseDist = 5;

  // ── رسوم الإضافات (لكل وحدة) ────────────────────────────────────────────
  double _extraCatPrice = 30;
  double _extraQtyPrice = 20;
  double _extraDistPrice = 15;

  bool _saving = false;
  bool _loadingExisting = false;
  bool _cityPricingLocked = false;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    _initCityAndData();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── تحديد المدينة بـ GPS ────────────────────────────────────────────────
  Future<void> _initCityAndData() async {
    setState(() {
      _loadingCity = true;
      _cityError = '';
    });

    // 0. نجيب البيانات الموجودة من حساب السائق (على الأقل اللغات)
    try {
      final uid = DriverService.uid;
      if (uid != null) {
        final d = await ApiClient.get('/api/drivers/$uid');
        if (d is Map) {
          if (_cityNameAr.isEmpty) _cityNameAr = d['cityNameAr'] as String? ?? '';
          if (_cityNameFr.isEmpty) _cityNameFr = d['cityNameFr'] as String? ?? '';
          if (_cityName.isEmpty) _cityName = d['cityName'] as String? ?? _cityNameAr;
          if (_cityLat == null) _cityLat = (d['cityLat'] as num?)?.toDouble();
          if (_cityLng == null) _cityLng = (d['cityLng'] as num?)?.toDouble();
        }
      }
    } catch (_) {}

    try {
      // 1. اطلب الصلاحية
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _cityError = 'صلاحية الموقع مرفوضة. فعّلها من إعدادات الجهاز.';
          _loadingCity = false;
        });
        return;
      }

      // 2. اجلب الموقع
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8)));

      _cityLat = pos.latitude;
      _cityLng = pos.longitude;

      // 3. Reverse geocoding بالعربية والفرنسية
      final urlAr =
          'https://nominatim.openstreetmap.org/reverse?format=json'
          '&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=ar';
      final urlFr =
          'https://nominatim.openstreetmap.org/reverse?format=json'
          '&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=fr';

      final resps = await Future.wait([
        http.get(Uri.parse(urlAr), headers: {'User-Agent': 'deliveryyy-driver-app/1.0'}).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse(urlFr), headers: {'User-Agent': 'deliveryyy-driver-app/1.0'}).timeout(const Duration(seconds: 6)),
      ]);

      String findCity(Map addr) =>
          addr['city'] as String? ??
          addr['town'] as String? ??
          addr['village'] as String? ??
          addr['county'] as String? ??
          addr['state_district'] as String? ??
          addr['state'] as String? ??
          '';

      if (resps[0].statusCode == 200 && resps[1].statusCode == 200) {
        final jsonAr = jsonDecode(resps[0].body) as Map<String, dynamic>;
        final jsonFr = jsonDecode(resps[1].body) as Map<String, dynamic>;
        final addrAr = jsonAr['address'] as Map<String, dynamic>? ?? {};
        final addrFr = jsonFr['address'] as Map<String, dynamic>? ?? {};

        setState(() {
          _cityNameAr = findCity(addrAr);
          _cityNameFr = findCity(addrFr);
          _cityName = _cityNameAr.isNotEmpty ? _cityNameAr : _cityNameFr;
          _loadingCity = false;
        });
      } else {
        setState(() {
          _cityName = 'غير معروف';
          _loadingCity = false;
        });
      }
    } catch (e) {
      setState(() {
        _cityError = 'تعذّر تحديد موقعك. تحقق من تفعيل GPS.';
        _loadingCity = false;
      });
    }

    // 4. نجيب التسعيرة الموجودة للمدينة (إن وجدت)
    await _loadExistingConfig();
  }

  // ── تحميل الإعدادات الموجودة (wilaya_configs أولاً، ثم حساب السائق) ───
  Future<void> _loadExistingConfig() async {
    setState(() => _loadingExisting = true);
    try {
      Map<String, dynamic>? cityConfig;
      bool fromServer = false;

      // 1. نحاول نجيب التسعيرة من wilaya_configs (السيرفر)
      // نجرب بالاسم العربي أولاً
      if (_cityNameAr.isNotEmpty) {
        final serverData = await ApiClient.get('/api/wilaya-configs/$_cityNameAr');
        if (serverData is Map && serverData['basePrice'] != null) {
          cityConfig = Map<String, dynamic>.from(serverData as Map);
          fromServer = true;
        }
      }
      // إذا ما لقيناش، نجرب بالاسم الفرنسي
      if (cityConfig == null && _cityNameFr.isNotEmpty) {
        final serverData = await ApiClient.get('/api/wilaya-configs/$_cityNameFr');
        if (serverData is Map && serverData['basePrice'] != null) {
          cityConfig = Map<String, dynamic>.from(serverData as Map);
          fromServer = true;
        }
      }
      // إذا ما لقيناش، نجرب بالاسم الرئيسي
      if (cityConfig == null) {
        final serverData = await ApiClient.get('/api/wilaya-configs/$_cityName');
        if (serverData is Map && serverData['basePrice'] != null) {
          cityConfig = Map<String, dynamic>.from(serverData as Map);
          fromServer = true;
        }
      }

      if (cityConfig != null) {
        // وجدنا تسعيرة للمدينة — نعبي الحقول ونقفل التعديل
        setState(() {
          _basePrice = (cityConfig!['basePrice'] as num? ?? 200).toDouble();
          _baseCats = (cityConfig['baseCats'] as num? ?? 2).toInt();
          _baseQty = (cityConfig['baseQty'] as num? ?? 5).toDouble();
          _baseDist = (cityConfig['baseDist'] as num? ?? 5).toDouble();
          _extraCatPrice = (cityConfig['extraCatPrice'] as num? ?? 30).toDouble();
          _extraQtyPrice = (cityConfig['extraQtyPrice'] as num? ?? 20).toDouble();
          _extraDistPrice = (cityConfig['extraDistPrice'] as num? ?? 15).toDouble();
          _cityPricingLocked = fromServer;
        });
        setState(() => _loadingExisting = false);
        return;
      }

      // 2. إذا ما لقيناش في السيرفر، نحاول من حساب السائق (للتعديل فقط)
      if (widget.isEditMode) {
        final uid = DriverService.uid;
        if (uid == null) {
          setState(() => _loadingExisting = false);
          return;
        }

        final data = await ApiClient.get('/api/drivers/$uid');
        if (data is! Map) {
          setState(() => _loadingExisting = false);
          return;
        }

        final config = data['deliveryConfig'];
        if (config == null) {
          setState(() => _loadingExisting = false);
          return;
        }

        Map<String, dynamic>? driverConfig;
        if (config is Map) {
          final cities = config['cities'];
          if (cities is Map && _cityName.isNotEmpty && cities[_cityName] != null) {
            driverConfig = Map<String, dynamic>.from(cities[_cityName] as Map);
          } else if (config['basePrice'] != null) {
            driverConfig = Map<String, dynamic>.from(config);
          }
        }

        if (driverConfig != null) {
          setState(() {
            _basePrice = (driverConfig!['basePrice'] as num? ?? 200).toDouble();
            _baseCats = (driverConfig['baseCats'] as num? ?? 2).toInt();
            _baseQty = (driverConfig['baseQty'] as num? ?? 5).toDouble();
            _baseDist = (driverConfig['baseDist'] as num? ?? 5).toDouble();
            _extraCatPrice = (driverConfig['extraCatPrice'] as num? ?? 30).toDouble();
            _extraQtyPrice = (driverConfig['extraQtyPrice'] as num? ?? 20).toDouble();
            _extraDistPrice = (driverConfig['extraDistPrice'] as num? ?? 15).toDouble();
          });
        }
      }
    } catch (_) {}
    setState(() => _loadingExisting = false);
  }

  // ── حفظ البيانات ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;

    // إذا التسعيرة مقفولة (محددة من الإدارة) → مجرد رجوع بدون حفظ
    if (_cityPricingLocked) {
      if (widget.isEditMode) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DriverMainShell()),
          (route) => false);
      }
      return;
    }

    // التأكد من وجود اسم المدينة
    if (_cityName.isEmpty || _loadingCity) {
      _snack('انتظر حتى يتم تحديد مدينتك', isError: true);
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final uid = DriverService.uid;
      if (uid == null) {
        _snack('خطأ: لم يتم التعرف على السائق', isError: true);
        return;
      }

      // تجميع بيانات التسعيرة
      final pricingData = {
        'basePrice': _basePrice,
        'baseCats': _baseCats,
        'baseQty': _baseQty,
        'baseDist': _baseDist,
        'extraCatPrice': _extraCatPrice,
        'extraQtyPrice': _extraQtyPrice,
        'extraDistPrice': _extraDistPrice,
        'cityName': _cityName,
        'cityNameAr': _cityNameAr.isNotEmpty ? _cityNameAr : _cityName,
        'cityNameFr': _cityNameFr.isNotEmpty ? _cityNameFr : _cityName,
        'cityLat': _cityLat,
        'cityLng': _cityLng,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // 1. تحديث وثيقة السائق
      final updateData = {
        'deliveryConfig': pricingData,
        'pricing': pricingData,
        'cityName': _cityName,
        'cityLat': _cityLat,
        'cityLng': _cityLng,
        'hasSetPricing': true,
      };
      if (_cityNameAr.isNotEmpty) updateData['cityNameAr'] = _cityNameAr;
      if (_cityNameFr.isNotEmpty) updateData['cityNameFr'] = _cityNameFr;
      await ApiClient.put('/api/drivers/$uid', updateData);

      // 2. تحديث إعدادات المدينة العامة — طلب واحد فقط
      await ApiClient.put('/api/wilaya_configs/$_cityName', pricingData);

      if (!mounted) return;

      _snack('✅ تم حفظ الإعدادات بنجاح');

      // 3. التحكم في الوجهة بعد الحفظ
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        if (widget.isEditMode) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DriverMainShell()),
            (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('حدث خطأ أثناء الحفظ، حاول مجدداً', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: isError ? kDanger : kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ── بناء حقل قيمة بأزرار + و - ─────────────────────────────────────────
  // ── بناء حقل قيمة بأزرار + و - (نسخة محسنة للأجهزة الصغيرة) ──────────────
  Widget _field({
    required String label,
    required String unit,
    required double value,
    required double step,
    required double min,
    required double max,
    required void Function(double) onChanged,
    String? subtitle,
  }) {
    final display = (value == value.roundToDouble())
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1))),
      child: Row(
        children: [
          // ── 1. أزرار التحكم (جهة اليسار) ─────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roundBtn(
                icon: CupertinoIcons.plus,
                onTap: !_cityPricingLocked && value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 70),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withOpacity(0.2))),
                child: Text(
                  '$display $unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kPrimary))),
              const SizedBox(width: 8),
              _roundBtn(
                icon: CupertinoIcons.minus,
                onTap: !_cityPricingLocked && value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null),
            ]),

          const SizedBox(width: 10), // مسافة فاصلة
          // ── 2. العنوان (جهة اليمين) مع Expanded لمنع الـ Overflow ───────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  // يسمح للنص بالنزول لسطر ثاني إذا كان طويلاً
                  // يضع نقاط إذا كان طويلاً جداً
                  style: const TextStyle(
                    fontSize: 13, // تصغير الخط قليلاً
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: kTextGrey,
                      fontFamily: 'Amiri')),
              ])),
        ]));
  }

  // ── زر دائري نيومورفيك ──────────────────────────────────────────────────
  Widget _roundBtn({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kBg,
          boxShadow: enabled ? neuShadow(blur: 6, offset: 2) : [],
          border: Border.all(
            color: enabled ? kPrimary.withOpacity(0.2) : Colors.grey.shade300)),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? kPrimary : Colors.grey.shade400)));
  }

  // ── عنوان قسم ────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: kTextDark)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15)),
        ]));
  }

  // ── كارد المعاينة ────────────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    // مثال: 3 تصنيفات، 8 منتجات، 9 كيلومتر
    final extraCat = (_baseCats > 0) ? 1 : 0; // تصنيف واحد إضافي
    final extraQty = (_baseQty < 8) ? (8 - _baseQty) : 0.0;
    final extraDist = (_baseDist < 9) ? (9 - _baseDist) : 0.0;
    final exampleTotal =
        _basePrice +
        (extraCat > 0 ? extraCat * _extraCatPrice : 0) +
        (extraQty > 0 ? extraQty * _extraQtyPrice : 0) +
        (extraDist > 0 ? extraDist * _extraDistPrice : 0);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // عنوان الكارد
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'مثال توضيحي على تسعيرتك',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kTextDark)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kInfo.withOpacity(0.1),
                  shape: BoxShape.circle),
                child: Icon(CupertinoIcons.lightbulb, color: kInfo, size: 14)),
            ]),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade300, height: 1),
          const SizedBox(height: 10),

          // تفاصيل المثال
          _previewRow(
            'الحزمة الأساسية',
            '${_basePrice.toInt()} DA',
            '${_baseCats} تصنيف، ${_baseQty.toInt()} منتج، ${_baseDist.toInt()} كم',
            kPrimary),

          if (extraCat > 0)
            _previewRow(
              'تصنيف إضافي × $extraCat',
              '${(extraCat * _extraCatPrice).toInt()} DA',
              '${_extraCatPrice.toInt()} DA لكل تصنيف',
              kWarning),

          if (extraQty > 0)
            _previewRow(
              'منتجات إضافية × ${extraQty.toStringAsFixed(0)}',
              '${(extraQty * _extraQtyPrice).toInt()} DA',
              '${_extraQtyPrice.toInt()} DA لكل منتج',
              kWarning),

          if (extraDist > 0)
            _previewRow(
              'مسافة إضافية × ${extraDist.toStringAsFixed(0)} كم',
              '${(extraDist * _extraDistPrice).toInt()} DA',
              '${_extraDistPrice.toInt()} DA لكل كيلومتر',
              kWarning),

          Divider(color: Colors.grey.shade300, height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${exampleTotal.toInt()} DA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kPrimary)),
              const Text(
                'إجمالي الطلبية في المثال',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Amiri',
                  color: kTextGrey)),
            ]),

          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kInfo.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kInfo.withOpacity(0.2))),
            child: Text(
              'هذا مثال لطلبية بـ ${_baseCats + 1} تصنيف، 8 منتجات، و9 كم. '
              'يتم احتساب الإضافات فوق الحزمة الأساسية تلقائياً.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Amiri',
                color: kInfo,
                height: 1.5))),
        ]));
  }

  Widget _previewRow(String label, String amount, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: color)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Amiri',
                  color: kTextDark)),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Amiri',
                  color: kTextGrey)),
            ]),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ في وضع التعديل يسمح بالرجوع، في الوضع الإلزامي لا
      canPop: widget.isEditMode,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: kBg,
        // ✅ AppBar بسيط فقط في وضع التعديل
        appBar: widget.isEditMode
            ? AppBar(
                backgroundColor: kBg,
                elevation: 0,
                centerTitle: true,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kBg,
                      shape: BoxShape.circle,
                      boxShadow: neuShadow(blur: 6, offset: 2)),
                    child: const Icon(
                      CupertinoIcons.chevron_right,
                      color: kPrimary,
                      size: 18))),
                title: const Text(
                  'تعديل التسعيرة',
                  style: TextStyle(
                    color: kTextDark,
                    fontFamily: 'Amiri',
                    fontSize: 16,
                    fontWeight: FontWeight.bold)))
            : null,
        body: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: SafeArea(
              child: _loadingExisting
                  ? const Center(
                      child: CupertinoActivityIndicator(color: kPrimary))
                  : Column(
                      children: [
                        // ── رأس الشاشة ────────────────────────────────────────
                        _buildHeader(),

                        // ── رسالة التنبيه ─────────────────────────────────────
                        _buildWarningBanner(),

                        // ── المحتوى القابل للتمرير ─────────────────────────────
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // ── قسم 1: الحزمة الأساسية ────────────────────
                                _sectionTitle(
                                  'الحزمة الأساسية',
                                  CupertinoIcons.cube_box,
                                  kPrimary),

                                _field(
                                  label: 'السعر الأساسي',
                                  unit: 'DA',
                                  value: _basePrice,
                                  step: 10,
                                  min: 50,
                                  max: 2000,
                                  subtitle: 'السعر الأدنى للطلبية',
                                  onChanged: (v) =>
                                      setState(() => _basePrice = v)),

                                _field(
                                  label: 'عدد التصنيفات المشمولة',
                                  unit: 'تصنيف',
                                  value: _baseCats.toDouble(),
                                  step: 1,
                                  min: 1,
                                  max: 10,
                                  subtitle: 'مشمولة في السعر الأساسي',
                                  onChanged: (v) =>
                                      setState(() => _baseCats = v.toInt())),

                                _field(
                                  label: 'عدد المنتجات المشمول',
                                  unit: 'منتج',
                                  value: _baseQty,
                                  step: 1,
                                  min: 1,
                                  max: 100,
                                  subtitle: 'عدد المنتجات المشمول',
                                  onChanged: (v) =>
                                      setState(() => _baseQty = v)),

                                _field(
                                  label: 'المسافة المشمولة',
                                  unit: 'كم',
                                  value: _baseDist,
                                  step: 1,
                                  min: 1,
                                  max: 100,
                                  subtitle: 'المسافة المشمولة من موقعك',
                                  onChanged: (v) =>
                                      setState(() => _baseDist = v)),

                                // ── قسم 2: رسوم الإضافات ──────────────────────
                                _sectionTitle(
                                  'رسوم الإضافات',
                                  CupertinoIcons.add_circled,
                                  kWarning),

                                _field(
                                  label: 'رسم كل تصنيف إضافي',
                                  unit: 'DA',
                                  value: _extraCatPrice,
                                  step: 5,
                                  min: 0,
                                  max: 500,
                                  subtitle: 'فوق الحد المشمول',
                                  onChanged: (v) =>
                                      setState(() => _extraCatPrice = v)),

                                _field(
                                  label: 'رسم كل منتج إضافي',
                                  unit: 'DA',
                                  value: _extraQtyPrice,
                                  step: 5,
                                  min: 0,
                                  max: 200,
                                  subtitle: 'فوق العدد المشمول',
                                  onChanged: (v) =>
                                      setState(() => _extraQtyPrice = v)),

                                _field(
                                  label: 'رسم كل كيلومتر إضافي',
                                  unit: 'DA',
                                  value: _extraDistPrice,
                                  step: 5,
                                  min: 0,
                                  max: 200,
                                  subtitle: 'فوق المسافة المشمولة',
                                  onChanged: (v) =>
                                      setState(() => _extraDistPrice = v)),

                                const SizedBox(height: 4),

                                // ── كارد المعاينة ─────────────────────────────
                                _buildPreviewCard(),

                                const SizedBox(height: 24),

                                // ── زر الحفظ ──────────────────────────────────
                                _buildSaveButton(),

                                const SizedBox(height: 20),
                              ]))),
                      ]))))));
  }

  // ── رأس الشاشة ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          // أيقونة
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBg,
              boxShadow: neuShadow(blur: 14, offset: 5)),
            child: const Icon(
              CupertinoIcons.money_dollar_circle_fill,
              color: kPrimary,
              size: 30)),
          const SizedBox(height: 12),
          Text(
            widget.isEditMode ? 'تعديل تسعيرة التوصيل' : 'إعداد تسعيرة التوصيل',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: kTextDark)),
          const SizedBox(height: 4),
          Text(
            widget.isEditMode
                ? 'عدّل أسعارك لمدينتك الحالية'
                : 'حدّد أسعارك قبل استقبال أي طلبية',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Amiri',
              color: kTextGrey)),
          const SizedBox(height: 10),
          // ✅ شارة المدينة الحالية
          _buildCityBadge(),
          const SizedBox(height: 10),
          // ✅ زر تحديد الموقع يدوياً من الخريطة
          _buildMapPickerButton(),
        ]));
  }

  // ── زر تحديد الموقع يدوياً من الخريطة ───────────────────────────────────
  Widget _buildMapPickerButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (_) => const MapPickerScreen()));
        if (result != null && mounted) {
          final lat = (result['lat'] as num?)?.toDouble();
          final lng = (result['lng'] as num?)?.toDouble();
          final addr = result['address'] as String? ?? '';

          if (lat == null || lng == null) return;

          setState(() {
            _loadingCity = true;
            _cityError = '';
          });

          // استخراج المدينة من الإحداثيات المختارة
          try {
            final url =
                'https://nominatim.openstreetmap.org/reverse?format=json'
                '&lat=$lat&lon=$lng&accept-language=ar';
            final resp = await http.get(
              Uri.parse(url),
              headers: {'User-Agent': 'deliveryyy-driver-app/1.0'});
            if (resp.statusCode == 200) {
              final json = jsonDecode(resp.body) as Map<String, dynamic>;
              final address = json['address'] as Map<String, dynamic>?;
              final city =
                  address?['city'] as String? ??
                  address?['town'] as String? ??
                  address?['village'] as String? ??
                  address?['county'] as String? ??
                  address?['state_district'] as String? ??
                  address?['state'] as String? ??
                  'غير معروف';
              setState(() {
                _cityName = city;
                _cityLat = lat;
                _cityLng = lng;
                _loadingCity = false;
              });
              await _loadExistingConfig();
            }
          } catch (_) {
            setState(() {
              _cityError = 'تعذّر تحديد المدينة من الموقع المحدد';
              _loadingCity = false;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimary.withOpacity(0.25)),
          boxShadow: neuShadow(blur: 6, offset: 2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.map_pin_ellipse,
              color: kPrimary,
              size: 16),
            const SizedBox(width: 8),
            Text(
              _cityName.isNotEmpty
                  ? 'تعديل الموقع من الخريطة'
                  : 'تحديد موقعك من الخريطة',
              style: const TextStyle(
                color: kPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri')),
          ])));
  }

  // ── شارة المدينة الحالية ──────────────────────────────────────────────────
  Widget _buildCityBadge() {
    if (_loadingCity) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: neuShadow(blur: 6, offset: 2)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: kPrimary, radius: 8),
            SizedBox(width: 8),
            Text(
              'جاري تحديد موقعك...',
              style: TextStyle(
                color: kTextGrey,
                fontSize: 12,
                fontFamily: 'Amiri')),
          ]));
    }

    if (_cityError.isNotEmpty) {
      return GestureDetector(
        onTap: _initCityAndData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kDanger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kDanger.withOpacity(0.3))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                color: kDanger,
                size: 14),
              const SizedBox(width: 6),
              Text(
                _cityError,
                style: const TextStyle(
                  color: kDanger,
                  fontSize: 11,
                  fontFamily: 'Amiri')),
              const SizedBox(width: 6),
              const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  color: kDanger,
                  fontSize: 11,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold)),
            ])));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryDark, kPrimary],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3)),
        ]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.location_solid,
            color: Colors.white,
            size: 14),
          const SizedBox(width: 6),
          Text(
            'تسعيرة مدينة: $_cityName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri')),
        ]));
  }

  // ── شريط التنبيه ─────────────────────────────────────────────────────────
  Widget _buildWarningBanner() {
    if (_cityPricingLocked) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kInfo.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kInfo.withOpacity(0.3))),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.lock_fill,
              color: kInfo,
              size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'هذه التسعيرة محددة من الإدارة لمدينة $_cityName ولا يمكن تعديلها.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Amiri',
                  color: kInfo,
                  height: 1.5))),
          ]));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kWarning.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWarning.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: kWarning,
            size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isEditMode
                  ? 'ستُطبَّق التسعيرة الجديدة على الطلبيات القادمة في "$_cityName" فقط.'
                  : 'يجب ضبط إعداداتك مرة واحدة فقط لكي تتمكن من استقبال الطلبيات. '
                        'يمكنك تعديلها لاحقاً من الإعدادات.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Amiri',
                color: kWarning,
                height: 1.5))),
        ]));
  }

  // ── زر الحفظ/العودة ────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    if (_cityPricingLocked) {
      return GestureDetector(
        onTap: _save,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [kPrimaryDark, kPrimary],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6)),
            ]),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.arrow_left,
                  color: Colors.white,
                  size: 20),
                SizedBox(width: 10),
                Text(
                  'رجوع',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri')),
              ])),
        ));
    }
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _saving
              ? null
              : const LinearGradient(
                  colors: [kPrimaryDark, kPrimary, kAccent],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft),
          color: _saving ? Colors.grey.shade300 : null,
          boxShadow: _saving
              ? []
              : [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
                ]),
        child: Stack(
          children: [
            if (!_saving)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.transparent,
                      ])))),
            Center(
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_shield_fill,
                          color: Colors.white,
                          size: 20),
                        SizedBox(width: 10),
                        Text(
                          'حفظ التسعيرة والمتابعة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                      ])),
          ])));
  }
}
