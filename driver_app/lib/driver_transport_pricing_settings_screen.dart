// ════════════════════════════════════════════════════════════════════════════
//  driver_transport_pricing_settings_screen.dart
//  شاشة إعداد تسعيرة النقل (سيارة / هاربين / فورغو) — حسب مدينة السائق
//  ✅ تُعرض مرة واحدة إذا لم يكن transportConfig موجوداً (وضع إلزامي)
//  ✅ أو تُعرض من صفحة البروفيل للتعديل (isEditMode: true)
//  ✅ التسعير مرتبط بالمدينة الحالية للسائق (GPS → geocoding)
//  ✅ تحفظ البيانات في Firestore → drivers/{uid}/transportConfig
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

// ════════════════════════════════════════════════════════════════════════════
//  DriverTransportPricingSettingsScreen
// ════════════════════════════════════════════════════════════════════════════
class DriverTransportPricingSettingsScreen extends StatefulWidget {
  /// isEditMode = true → جاء من البروفيل، يرجع للخلف بعد الحفظ
  /// isEditMode = false (default) → وضع إلزامي عند أول مرة
  final bool isEditMode;

  const DriverTransportPricingSettingsScreen({super.key, this.isEditMode = false});

  @override
  State<DriverTransportPricingSettingsScreen> createState() =>
      _DriverTransportPricingSettingsScreenState();
}

class _DriverTransportPricingSettingsScreenState
    extends State<DriverTransportPricingSettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── المدينة الحالية ──────────────────────────────────────────────────────
  String _cityName = '';
  double? _cityLat;
  double? _cityLng;
  bool _loadingCity = true;
  String _cityError = '';
  String _cityNameAr = '';
  String _cityNameFr = '';

  // ── نوع المركبة الخاص بالسائق (يُسعر مركبته هو فقط) ─────────────────────
  String _vehicleType = 'car';

  // ── تسعيرة مركبة السائق ─────────────────────────────────────────────────
  double _basePrice = 300;
  double _baseDist = 5;
  double _extraDistPrice = 25;

  bool _saving = false;
  bool _loadingExisting = false;

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

    // 0. نجيب البيانات الموجودة من حساب السائق
    try {
      final uid = DriverService.uid;
      if (uid != null) {
        final d = await ApiClient.get('/api/drivers/$uid');
        if (_cityNameAr.isEmpty) _cityNameAr = d['cityNameAr'] as String? ?? '';
        if (_cityNameFr.isEmpty) _cityNameFr = d['cityNameFr'] as String? ?? '';
        if (_cityName.isEmpty) _cityName = d['cityName'] as String? ?? _cityNameAr;
        if (_cityLat == null) _cityLat = (d['cityLat'] as num?)?.toDouble();
        if (_cityLng == null) _cityLng = (d['cityLng'] as num?)?.toDouble();
        final vt = (d['vehicleType'] as String? ?? '').toLowerCase();
        if (['car', 'harbin', 'fourgon', 'minibus', 'truck'].contains(vt)) {
          _vehicleType = vt == 'minibus' ? 'harbin' : (vt == 'truck' ? 'fourgon' : vt);
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

    // 4. نجيب تسعيرة النقل الموجودة (إن وجدت)
    await _loadExistingConfig();
  }

  // ── تحميل التسعيرة الموجودة من حساب السائق ─────────────────────────────
  Future<void> _loadExistingConfig() async {
    setState(() => _loadingExisting = true);
    try {
      final uid = DriverService.uid;
      if (uid == null) {
        setState(() => _loadingExisting = false);
        return;
      }

      final data = await ApiClient.get('/api/drivers/$uid');

      final config = data['transportConfig'];

      if (config == null) {
        setState(() => _loadingExisting = false);
        return;
      }

      Map<String, dynamic> cfg;
      if (config is Map) {
        cfg = Map<String, dynamic>.from(config);
      } else {
        setState(() => _loadingExisting = false);
        return;
      }

      Map<String, dynamic> own = {};
      if (cfg[_vehicleType] is Map) {
        own = Map<String, dynamic>.from(cfg[_vehicleType] as Map);
      }

      setState(() {
        _basePrice = (own['basePrice'] as num? ?? _basePrice).toDouble();
        _baseDist = (own['baseDist'] as num? ?? _baseDist).toDouble();
        _extraDistPrice = (own['extraDistPrice'] as num? ?? _extraDistPrice).toDouble();
      });
    } catch (_) {}
    setState(() => _loadingExisting = false);
  }

  // ── حفظ البيانات ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;

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

      // تجميع بيانات تسعيرة النقل (مركبة السائق فقط) — النموذج: كيلومتر مشمول + كيلومتر إضافي
      final transportData = {
        _vehicleType: {
          'basePrice': _basePrice,
          'baseDist': 1,
          'extraDistPrice': _extraDistPrice,
        },
        'cityName': _cityName,
        'cityNameAr': _cityNameAr.isNotEmpty ? _cityNameAr : _cityName,
        'cityNameFr': _cityNameFr.isNotEmpty ? _cityNameFr : _cityName,
        'cityLat': _cityLat,
        'cityLng': _cityLng,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final updateData = {
        'transportConfig': transportData,
        'cityName': _cityName,
        'cityLat': _cityLat,
        'cityLng': _cityLng,
        'hasSetTransportPricing': true,
      };
      if (_cityNameAr.isNotEmpty) updateData['cityNameAr'] = _cityNameAr;
      if (_cityNameFr.isNotEmpty) updateData['cityNameFr'] = _cityNameFr;
      await ApiClient.put('/api/drivers/$uid', updateData);

      // 2. تحديث إعدادات المدينة العامة لنوع المركبة فقط (كل مركبة ومدينتها وحدها)
      await ApiClient.put('/api/wilaya_configs/$_cityName', {
        'vehicleType': _vehicleType,
        'basePrice': _basePrice,
        'baseDist': 1,
        'extraDistPrice': _extraDistPrice,
        'cityName': _cityName,
        'cityNameAr': _cityNameAr.isNotEmpty ? _cityNameAr : _cityName,
        'cityNameFr': _cityNameFr.isNotEmpty ? _cityNameFr : _cityName,
        'cityLat': _cityLat,
        'cityLng': _cityLng,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      _snack('✅ تم حفظ تسعيرة النقل بنجاح');

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
                onTap: value < max
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
                onTap: value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null),
            ]),

          const SizedBox(width: 10),
          // ── 2. العنوان (جهة اليمين) مع Expanded ───────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
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
  Widget _sectionTitle(String title, IconData icon, Color color, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kTextDark)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Amiri',
                  color: kTextGrey)),
            ]),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isEditMode,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: kBg,
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
                  'تعديل تسعيرة النقل',
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
                        _buildHeader(),
                        _buildWarningBanner(),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildOwnVehicleSection(),
                                const SizedBox(height: 4),
                                _buildSaveButton(),
                                const SizedBox(height: 20),
                              ]))),
                      ]))))));
  }

  // ── قسم مركبة السائق (حسب نوع مركبته) ───────────────────────────────────
  Widget _buildOwnVehicleSection() {
    final (title, icon, color, maxBase, maxExtra) = switch (_vehicleType) {
      'harbin' => (
          'تسعيرة الهاربين',
          CupertinoIcons.bus,
          const Color(0xFF00695C),
          10000.0,
          1000.0,
        ),
      'fourgon' => (
          'تسعيرة الفورغو',
          CupertinoIcons.cube_box,
          const Color(0xFF4527A0),
          15000.0,
          1500.0,
        ),
      _ => (
          'تسعيرة السيارة',
          CupertinoIcons.car_fill,
          const Color(0xFFE65100),
          5000.0,
          500.0,
        ),
    };

    return Column(
      children: [
        _sectionTitle(
          title,
          icon,
          color,
          'تسعيرة مركبتك في مدينتك الحالية'),
        _field(
          label: 'سعر الكيلومتر المشمول',
          unit: 'DA',
          value: _basePrice,
          step: 10,
          min: 50,
          max: maxBase,
          subtitle: 'سعر الكيلومتر الأول المشمول في التوصيل',
          onChanged: (v) => setState(() => _basePrice = v)),
        _field(
          label: 'سعر كل كيلومتر إضافي',
          unit: 'DA',
          value: _extraDistPrice,
          step: 5,
          min: 0,
          max: maxExtra,
          subtitle: 'كل كيلومتر بعد الكيلومتر المشمول',
          onChanged: (v) => setState(() => _extraDistPrice = v)),
      ]);
  }

  // ── رأس الشاشة ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBg,
              boxShadow: neuShadow(blur: 14, offset: 5)),
            child: const Icon(
              CupertinoIcons.car_fill,
              color: kPrimary,
              size: 30)),
          const SizedBox(height: 12),
          Text(
            widget.isEditMode ? 'تعديل تسعيرة النقل' : 'إعداد تسعيرة النقل',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: kTextDark)),
          const SizedBox(height: 4),
          Text(
            widget.isEditMode
                ? 'عدّل أسعار النقل لمدينتك الحالية'
                : 'حدّد أسعار النقل لمركبتك في مدينتك قبل استقبال أي طلبية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Amiri',
              color: kTextGrey)),
          const SizedBox(height: 10),
          _buildCityBadge(),
          const SizedBox(height: 10),
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

          if (lat == null || lng == null) return;

          setState(() {
            _loadingCity = true;
            _cityError = '';
          });

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
                  ? 'ستُطبَّق تسعيرة النقل الجديدة على طلبيات النقل القادمة في "$_cityName" فقط.'
                  : 'يجب ضبط أسعار النقل مرة واحدة فقط لكي تتمكن من استقبال طلبيات النقل. '
                        'يمكنك تعديلها لاحقاً من الإعدادات.',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Amiri',
                color: kWarning,
                height: 1.5))),
        ]));
  }

  // ── زر الحفظ ────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
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
                          'حفظ تسعيرة النقل والمتابعة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                      ])),
          ])));
  }
}
