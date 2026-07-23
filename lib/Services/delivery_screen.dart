  // ══════════════════════════════════════════════════════════════════════════════
  //  delivery_screen.dart — الشاشات الكاملة للخدمات
  //  ✅ ServiceType: delivery / pickup
  //  ✅ TransportType: taxi / minibus / truck
  //  ✅ ServiceOrderScreen — طلب توصيل أو إحضار
  //  ✅ TransportOrderScreen — طلب تاكسي / هارباني / فورغو
  //  ✅ MapPickerScreen — خريطة حقيقية GPS + بحث
  //  ✅ ServiceDriverSelectionScreen — رادار السائقين
  // ══════════════════════════════════════════════════════════════════════════════
    import 'dart:convert';

import 'package:flutter_application_1/Order/order_models.dart' hide kPrimaryColor, kAccentColor, kBgColor, kCardColor, kTextGrey, kSuccessColor;
import 'package:http/http.dart' as http;
  import 'dart:math' as math;
  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:flutter/cupertino.dart';
  import 'package:flutter/services.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cached_network_image/cached_network_image.dart';
  import 'package:google_maps_flutter/google_maps_flutter.dart';
  import 'package:geolocator/geolocator.dart';
  import 'package:geocoding/geocoding.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/driver_selection_screen.dart';
import 'package:flutter_application_1/user_local.dart';

  // ── Enums ─────────────────────────────────────────────────────────────────────
  enum ServiceType { delivery, pickup }

  enum TransportType { taxi, minibus, truck }

  // ── ألوان موحدة ───────────────────────────────────────────────────────────────
  const Color kPrimaryColor = Color(0xFF7D29C6);
  const Color kAccentColor = Color(0xFF9232E8);
  const Color kBgColor = Color(0xFFF1F0F5);
  const Color kCardColor = Color(0xFFDCDAE6);
  const Color kShadowColor = Color(0xFFB8B1C8);
  const Color kTextDark = Color(0xFF2D2A3A);
  const Color kTextGrey = Color(0xFF6E6B7B);
  const Color kSuccessColor = Color(0xFF27AE60);

  // ── Neumorphic shadow helper ───────────────────────────────────────────────────
  List<BoxShadow> neuShadow({double blur = 8, double offset = 3}) => [
    BoxShadow(
      color: kShadowColor.withOpacity(0.55),
      blurRadius: blur,
      offset: Offset(offset, offset)),
    BoxShadow(
      color: Colors.white.withOpacity(0.9),
      blurRadius: blur,
      offset: Offset(-offset, -offset)),
  ];

  // ══════════════════════════════════════════════════════════════════════════════
  //  ServiceOrderScreen — توصيل / إحضار طلبيات
  // ══════════════════════════════════════════════════════════════════════════════
  class ServiceOrderScreen extends StatefulWidget {
    final ServiceType serviceType;
    final String title;
    const ServiceOrderScreen({
      super.key,
      required this.serviceType,
      required this.title,
    });

    @override
    State<ServiceOrderScreen> createState() => _ServiceOrderScreenState();
  }

  class _ServiceOrderScreenState extends State<ServiceOrderScreen>
      with SingleTickerProviderStateMixin {
    late AnimationController _ctrl;
    late Animation<double> _fade;
    late Animation<Offset> _slide;

    // بيانات الطلب
    final _noteCtrl = TextEditingController();
    final _orderNameCtrl = TextEditingController(); // للإحضار فقط
    final _priceCtrl = TextEditingController();

    // موقع الإرسال
    List<Map<String, dynamic>> _savedLocations = [];
    bool _loadingLocations = true;
    int _fromLocationIndex = -1;
    bool _fromUseMap = false;
    String _fromMapAddress = '';
    double? _fromLat, _fromLng;

    // موقع الاستلام
    int _toLocationIndex = -1;
    bool _toUseMap = false;
    String _toMapAddress = '';
    double? _toLat, _toLng;

    // صورة الطرد
    File? _parcelImage;
    bool _uploadingImage = false;
    String? _parcelImageUrl;

    bool _isLoading = false;

    bool get _isDelivery => widget.serviceType == ServiceType.delivery;

    String get _fromAddress {
      if (_fromUseMap) return _fromMapAddress;
      if (_fromLocationIndex >= 0 && _fromLocationIndex < _savedLocations.length)
        return _savedLocations[_fromLocationIndex]['address'] as String;
      return '';
    }

    String get _toAddress {
      if (_toUseMap) return _toMapAddress;
      if (_toLocationIndex >= 0 && _toLocationIndex < _savedLocations.length)
        return _savedLocations[_toLocationIndex]['address'] as String;
      return '';
    }

    bool get _canConfirm {
      if (_isLoading || _uploadingImage) return false;
      if (!_isDelivery && _orderNameCtrl.text.trim().isEmpty) return false;
      if (_priceCtrl.text.trim().isEmpty) return false;
      return _fromAddress.isNotEmpty && _toAddress.isNotEmpty;
    }

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500));
      _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward();
      _loadSavedLocations();
    }

    @override
    void dispose() {
      _ctrl.dispose();
      _noteCtrl.dispose();
      _orderNameCtrl.dispose();
      _priceCtrl.dispose();
      super.dispose();
    }

    Future<void> _loadSavedLocations() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingLocations = false);
        return;
      }
      try {
        final data = await ApiClient.getList('/api/users/${user.uid}/saved-locations');
        if (mounted) {
          setState(() {
            _savedLocations = data
                .map(
                  (doc) => {
                    'id': doc['_id'],
                    'label': doc['label'] as String? ?? '',
                    'address': doc['address'] as String? ?? '',
                    'lat': doc['lat'],
                    'lng': doc['lng'],
                    'type': doc['type'] as String? ?? 'other',
                  })
                .where((l) => (l['label'] as String).isNotEmpty)
                .toList();
            _loadingLocations = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingLocations = false);
      }
    }

    Future<void> _pickParcelImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70);
      if (picked == null) return;
      setState(() {
        _parcelImage = File(picked.path);
        _parcelImageUrl = null;
      });
    }

    Future<String?> _uploadParcelImage() async {
      if (_parcelImage == null) return null;
      setState(() => _uploadingImage = true);
      try {
        final url = await ApiClient.upload(_parcelImage!);
        if (mounted) setState(() => _uploadingImage = false);
        return url;
      } catch (_) {
        if (mounted) setState(() => _uploadingImage = false);
        return null;
      }
    }

    Future<void> _confirmOrder() async {
      if (!_canConfirm) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginDialog();
        return;
      }
      setState(() => _isLoading = true);

      try {
        final userData = await ApiClient.get('/api/users/${user.uid}') as Map<String, dynamic>? ?? {};
        final apiName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        final userName = apiName.isNotEmpty ? apiName : (FirebaseAuth.instance.currentUser?.displayName ?? 'زبون');
        final userPhone = userData['phone'] as String? ?? '';

        // إحداثيات من
        double? fromLat = _fromUseMap
            ? _fromLat
            : (_fromLocationIndex >= 0
                  ? ((_savedLocations[_fromLocationIndex]['lat'] as num?)
                        ?.toDouble())
                  : null);
        double? fromLng = _fromUseMap
            ? _fromLng
            : (_fromLocationIndex >= 0
                  ? ((_savedLocations[_fromLocationIndex]['lng'] as num?)
                        ?.toDouble())
                  : null);

        // إحداثيات إلى
        double? toLat = _toUseMap
            ? _toLat
            : (_toLocationIndex >= 0
                  ? ((_savedLocations[_toLocationIndex]['lat'] as num?)
                        ?.toDouble())
                  : null);
        double? toLng = _toUseMap
            ? _toLng
            : (_toLocationIndex >= 0
                  ? ((_savedLocations[_toLocationIndex]['lng'] as num?)
                        ?.toDouble())
                  : null);

        final orderData = {
          'userId': user.uid,
          'userName': userName.isNotEmpty ? userName : 'زبون',
          'userPhone': userPhone,
          'serviceType': _isDelivery ? 'delivery' : 'pickup',
          'fromAddress': _fromAddress,
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toAddress': _toAddress,
          'toLat': toLat,
          'toLng': toLng,
          'orderName': _isDelivery ? '' : _orderNameCtrl.text.trim(),
          'note': _noteCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
          'status': 'pending',
          'driverId': null,
          'collection': 'service-orders',
          '_parcelImagePath': _parcelImage?.path,
        };

        if (!mounted) return;
        Navigator.push(
          context,
          _slideRoute(ServiceDriverSelectionScreen(orderData: orderData)));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ خطأ: $e',
                style: const TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
        }
      }
    }

    void _showLoginDialog() {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text(
            'تسجيل الدخول مطلوب',
            style: TextStyle(fontFamily: 'Amiri')),
          content: const Text(
            'يجب تسجيل الدخول لاستخدام الخدمة',
            style: TextStyle(fontFamily: 'Amiri')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Amiri'))),
          ]));
    }

    IconData _iconFromType(String type) {
      if (type == 'home') return CupertinoIcons.house_fill;
      if (type == 'work') return CupertinoIcons.briefcase_fill;
      return CupertinoIcons.location_fill;
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBgColor,
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 120),
              child: Column(
                children: [
                  _buildServiceBanner(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // ── اسم الطلبية (إحضار فقط) ─────────────────────
                        if (!_isDelivery) ...[
                          const SizedBox(height: 24),
                          _sectionLabel('اسم الطلبية *', CupertinoIcons.bag_fill),
                          const SizedBox(height: 10),
                          _buildNeuTextField(
                            ctrl: _orderNameCtrl,
                            hint: 'مثال: طرد من أمازون، دواء، ملابس...',
                            icon: CupertinoIcons.bag_fill,
                            onChanged: (_) => setState(() {})),
                        ],

                        // ── موقع الإرسال (من) ─────────────────────────────
                        const SizedBox(height: 24),
                        _sectionLabel(
                          _isDelivery ? 'من أين تُرسل؟ *' : 'موقع الإحضار *',
                          CupertinoIcons.location),
                        const SizedBox(height: 10),
                        _buildLocationPicker(
                          isFrom: true,
                          selectedIndex: _fromLocationIndex,
                          useMap: _fromUseMap,
                          mapAddress: _fromMapAddress,
                          onSelectSaved: (i) => setState(() {
                            _fromLocationIndex = i;
                            _fromUseMap = false;
                          }),
                          onSelectMap: (addr, lat, lng) => setState(() {
                            _fromUseMap = true;
                            _fromLocationIndex = -1;
                            _fromMapAddress = addr;
                            _fromLat = lat;
                            _fromLng = lng;
                          })),

                        // ── موقع الاستلام (إلى) ───────────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel(
                          _isDelivery ? 'إلى أين تُوصَّل؟ *' : 'موقع التوصيل *',
                          CupertinoIcons.location_fill),
                        const SizedBox(height: 10),
                        _buildLocationPicker(
                          isFrom: false,
                          selectedIndex: _toLocationIndex,
                          useMap: _toUseMap,
                          mapAddress: _toMapAddress,
                          onSelectSaved: (i) => setState(() {
                            _toLocationIndex = i;
                            _toUseMap = false;
                          }),
                          onSelectMap: (addr, lat, lng) => setState(() {
                            _toUseMap = true;
                            _toLocationIndex = -1;
                            _toMapAddress = addr;
                            _toLat = lat;
                            _toLng = lng;
                          })),

                        // ── صورة الطرد ────────────────────────────────────
                        const SizedBox(height: 24),
                        _sectionLabel(
                          'صورة الطرد (اختياري)',
                          CupertinoIcons.photo),
                        const SizedBox(height: 10),
                        _buildParcelImagePicker(),

                        // ── ملاحظة ────────────────────────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel(
                          'ملاحظة للسائق (اختياري)',
                          CupertinoIcons.text_bubble),
                        const SizedBox(height: 10),
                        _buildNeuTextField(
                          ctrl: _noteCtrl,
                          hint: 'مثال: وزن الطرد حوالي 5 كلغ، حجمه كبير...',
                          icon: CupertinoIcons.text_bubble),

                        // ── السعر ─────────────────────────────────────────
                        const SizedBox(height: 20),
                        _sectionLabel(
                          'السعر المتفق عليه (DA) *',
                          CupertinoIcons.money_dollar_circle),
                        const SizedBox(height: 10),
                        _buildPriceField(),

                        // ── زر التأكيد ────────────────────────────────────
                        const SizedBox(height: 28),
                        _buildConfirmButton(),
                        const SizedBox(height: 16),
                      ])),
                ])))));
    }

    AppBar _buildAppBar() => AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: neuShadow(blur: 6, offset: 3)),
          child: const Icon(
            CupertinoIcons.chevron_left,
            color: kPrimaryColor,
            size: 20))),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: kTextDark,
          fontWeight: FontWeight.bold,
          fontSize: 17,
          fontFamily: 'Amiri')));

    Widget _buildServiceBanner() {
      final colors = _isDelivery
          ? [const Color(0xFF6D22AC), kPrimaryColor, kAccentColor]
          : [
              const Color(0xFF1A237E),
              const Color(0xFF283593),
              const Color(0xFF3949AB),
            ];
      final mainColor = _isDelivery ? kPrimaryColor : const Color(0xFF283593);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: mainColor.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
          ]),
        child: Stack(
          children: [
            Positioned(
              top: -15,
              right: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)))),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.18), Colors.transparent])))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16)),
                  child: Icon(
                    _isDelivery
                        ? CupertinoIcons.cube_box_fill
                        : CupertinoIcons.bag_fill,
                    color: Colors.white,
                    size: 30)),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _isDelivery ? 'توصيل لباب دارك' : 'إحضار من أي مكان',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri')),
                      const SizedBox(height: 4),
                      Text(
                        _isDelivery
                            ? 'حدد مواقع الإرسال والاستلام أدناه'
                            : 'أعطنا التفاصيل ونتكفل بالباقي',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontFamily: 'Amiri'),
                        textAlign: TextAlign.right),
                    ])),
              ]),
          ]));
    }

    Widget _sectionLabel(String text, IconData icon) => Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kTextDark,
              fontFamily: 'Amiri'),
            textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.1),
            shape: BoxShape.circle),
          child: Icon(icon, color: kPrimaryColor, size: 14)),
      ]);

    Widget _buildNeuTextField({
      required TextEditingController ctrl,
      required String hint,
      required IconData icon,
      int maxLines = 1,
      void Function(String)? onChanged,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: neuShadow(blur: 7, offset: 3)),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 14,
            color: kTextDark,
            fontFamily: 'Amiri'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 12,
              fontFamily: 'Amiri'),
            prefixIcon: Icon(icon, color: kPrimaryColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14))));
    }

    Widget _buildPriceField() {
      return Container(
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
          boxShadow: neuShadow(blur: 7, offset: 3)),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'DA',
                style: TextStyle(
                  color: kPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Amiri'))),
            Expanded(
              child: TextField(
                controller: _priceCtrl,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 18,
                  color: kTextDark,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14)))),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                CupertinoIcons.money_dollar_circle,
                color: kPrimaryColor.withOpacity(0.5),
                size: 20)),
          ]));
    }

    Widget _buildLocationPicker({
      required bool isFrom,
      required int selectedIndex,
      required bool useMap,
      required String mapAddress,
      required Function(int) onSelectSaved,
      required Function(String, double?, double?) onSelectMap,
    }) {
      return Column(
        children: [
          if (_loadingLocations)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(color: kPrimaryColor))
          else ...[
            ..._savedLocations.asMap().entries.map((e) {
              final i = e.key;
              final loc = e.value;
              final isSel = !useMap && selectedIndex == i;
              return GestureDetector(
                onTap: () => onSelectSaved(i),
                child: _buildLocationTile(
                  label: loc['label'] as String,
                  address: loc['address'] as String,
                  icon: _iconFromType(loc['type'] as String),
                  isSelected: isSel));
            }),
            const SizedBox(height: 8),
          ],
          // زر الخريطة
          GestureDetector(
            onTap: () async {
              final res = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()));
              if (res != null && mounted) {
                onSelectMap(res['address'] ?? '', res['lat'], res['lng']);
              }
            },
            child: _buildLocationTile(
              label: 'تحديد من الخريطة',
              address: useMap && mapAddress.isNotEmpty
                  ? mapAddress
                  : 'اضغط لفتح الخريطة',
              icon: CupertinoIcons.map_fill,
              isSelected: useMap)),
        ]);
    }

    Widget _buildLocationTile({
      required String label,
      required String address,
      required IconData icon,
      required bool isSelected,
    }) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
          boxShadow: [
            BoxShadow(
              color: kShadowColor.withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4)),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(
            color: isSelected ? kPrimaryColor.withOpacity(0.6) : kPrimaryColor.withOpacity(0.1),
            width: isSelected ? 2 : 1)),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? kPrimaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? kPrimaryColor : Colors.grey.shade400,
                  width: 2)),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null),
            const SizedBox(width: 10),
            Icon(
              icon,
              color: isSelected ? kPrimaryColor : kShadowColor,
              size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? kPrimaryColor : kTextDark,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? kTextGrey : Colors.black45,
                      fontFamily: 'Amiri'),
                    textAlign: TextAlign.right),
                ])),
          ]));
    }

    Widget _buildParcelImagePicker() {
      return GestureDetector(
        onTap: _pickParcelImage,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _parcelImage != null
                  ? kPrimaryColor
                  : kShadowColor.withOpacity(0.35),
              width: _parcelImage != null ? 2 : 1),
            boxShadow: neuShadow(blur: 6, offset: 3)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _parcelImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_parcelImage!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _parcelImage = null;
                            _parcelImageUrl = null;
                          }),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16)))),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(10)),
                          child: const Text(
                            'تغيير',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Amiri')))),
                    ])
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.1),
                            shape: BoxShape.circle),
                          child: const Icon(
                            CupertinoIcons.camera,
                            color: kPrimaryColor,
                            size: 26)),
                        const SizedBox(height: 8),
                        const Text(
                          'اضغط لرفع صورة الطرد',
                          style: TextStyle(
                            fontSize: 12,
                            color: kTextGrey,
                            fontFamily: 'Amiri')),
                      ])))));
    }

    Widget _buildConfirmButton() {
      return GestureDetector(
        onTap: _canConfirm ? _confirmOrder : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _canConfirm
                ? const LinearGradient(
                    colors: [Color(0xFF6D22AC), kPrimaryColor, kAccentColor],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft)
                : null,
            color: _canConfirm ? null : Colors.grey.shade300,
            boxShadow: _canConfirm
                ? [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                  ]
                : []),
          child: Stack(
            children: [
              if (_canConfirm)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 29,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.transparent,
                        ])))),
              Center(
                child: _isLoading || _uploadingImage
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _canConfirm
                                ? CupertinoIcons.checkmark_shield_fill
                                : CupertinoIcons.lock,
                            color: _canConfirm
                                ? Colors.white
                                : Colors.grey.shade500,
                            size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _canConfirm
                                ? 'تأكيد الطلبية واختيار السائق'
                                : 'أكمل البيانات المطلوبة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                              color: _canConfirm
                                  ? Colors.white
                                  : Colors.grey.shade500)),
                        ])),
            ])));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  TransportOrderScreen — تاكسي / هارباني / فورغو
  // ══════════════════════════════════════════════════════════════════════════════
  class TransportOrderScreen extends StatefulWidget {
    final TransportType serviceType;
    final String title;
    const TransportOrderScreen({
      super.key,
      required this.serviceType,
      required this.title,
    });

    @override
    State<TransportOrderScreen> createState() => _TransportOrderScreenState();
  }

  class _TransportOrderScreenState extends State<TransportOrderScreen>
      with SingleTickerProviderStateMixin {
    late AnimationController _ctrl;
    late Animation<double> _fade;
    late Animation<Offset> _slide;

    final _noteCtrl = TextEditingController();
    final _priceCtrl = TextEditingController();

    // صور اختيارية
    final _picker = ImagePicker();
    XFile? _fromImageFile;
    XFile? _toImageFile;
    XFile? _parcelImageFile;

    // من
    List<Map<String, dynamic>> _savedLocations = [];
    bool _loadingLocations = true;
    int _fromIndex = -1;
    bool _fromMap = false;
    String _fromAddr = '';
    double? _fromLat, _fromLng;

    // إلى
    int _toIndex = -1;
    bool _toMap = false;
    String _toAddr = '';
    double? _toLat, _toLng;

    bool _isLoading = false;

    Color get _accentColor {
      switch (widget.serviceType) {
        case TransportType.taxi:
          return const Color(0xFFE65100);
        case TransportType.minibus:
          return const Color(0xFF00695C);
        case TransportType.truck:
          return const Color(0xFF4527A0);
      }
    }

    IconData get _serviceIcon {
      switch (widget.serviceType) {
        case TransportType.taxi:
          return CupertinoIcons.car_fill;
        case TransportType.minibus:
          return CupertinoIcons.bus;
        case TransportType.truck:
          return CupertinoIcons.cube_box;
      }
    }

    String get _serviceName {
      switch (widget.serviceType) {
        case TransportType.taxi:
          return 'car';
        case TransportType.minibus:
          return 'transport';
        case TransportType.truck:
          return 'truck';
      }
    }

    String get _fromFinalAddress {
      if (_fromMap) return _fromAddr;
      if (_fromIndex >= 0 && _fromIndex < _savedLocations.length)
        return _savedLocations[_fromIndex]['address'] as String;
      return '';
    }

    String get _toFinalAddress {
      if (_toMap) return _toAddr;
      if (_toIndex >= 0 && _toIndex < _savedLocations.length)
        return _savedLocations[_toIndex]['address'] as String;
      return '';
    }

    bool get _canConfirm =>
        !_isLoading &&
        _fromFinalAddress.isNotEmpty &&
        _toFinalAddress.isNotEmpty &&
        _priceCtrl.text.trim().isNotEmpty;

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500));
      _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward();
      _loadLocations();
    }

    @override
    void dispose() {
      _ctrl.dispose();
      _noteCtrl.dispose();
      _priceCtrl.dispose();
      super.dispose();
    }

    Future<void> _pickImage(void Function(XFile?) onPicked) async {
      final img = await _picker.pickImage(source: ImageSource.gallery);
      if (img != null && mounted) onPicked(img);
    }

    Widget _buildImagePicker({required XFile? file, required String label, required void Function(XFile?) onPicked}) {
      return GestureDetector(
        onTap: () => _pickImage(onPicked),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: neuShadow(blur: 6, offset: 3),
            border: Border.all(
              color: file != null ? _accentColor.withOpacity(0.5) : Colors.grey.shade300)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                file != null ? label : label,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Amiri',
                  color: file != null ? _accentColor : Colors.black54)),
              const SizedBox(width: 8),
              if (file != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(file.path),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover))
              else
                Icon(
                  CupertinoIcons.photo_fill,
                  color: _accentColor.withOpacity(0.5),
                  size: 22),
              const SizedBox(width: 8),
              if (file != null)
                GestureDetector(
                  onTap: () => setState(() => onPicked(null)),
                  child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red, size: 18)),
            ])));
    }

    Future<void> _loadLocations() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingLocations = false);
        return;
      }
      try {
        final data = await ApiClient.getList('/api/users/${user.uid}/saved-locations');
        if (mounted) {
          setState(() {
            _savedLocations = data
                .map(
                  (doc) => {
                    'id': doc['_id'],
                    'label': doc['label'] as String? ?? '',
                    'address': doc['address'] as String? ?? '',
                    'lat': doc['lat'],
                    'lng': doc['lng'],
                    'type': doc['type'] as String? ?? 'other',
                  })
                .where((l) => (l['label'] as String).isNotEmpty)
                .toList();
            _loadingLocations = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingLocations = false);
      }
    }

    Future<void> _confirmOrder() async {
      if (!_canConfirm) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      setState(() => _isLoading = true);
      try {
        final userData = await ApiClient.get('/api/users/${user.uid}') as Map<String, dynamic>? ?? {};
        final apiName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        final userName = apiName.isNotEmpty ? apiName : (FirebaseAuth.instance.currentUser?.displayName ?? 'زبون');

        double? fromLat = _fromMap
            ? _fromLat
            : (_fromIndex >= 0
                  ? ((_savedLocations[_fromIndex]['lat'] as num?)?.toDouble())
                  : null);
        double? fromLng = _fromMap
            ? _fromLng
            : (_fromIndex >= 0
                  ? ((_savedLocations[_fromIndex]['lng'] as num?)?.toDouble())
                  : null);
        double? toLat = _toMap
            ? _toLat
            : (_toIndex >= 0
                  ? ((_savedLocations[_toIndex]['lat'] as num?)?.toDouble())
                  : null);
        double? toLng = _toMap
            ? _toLng
            : (_toIndex >= 0
                  ? ((_savedLocations[_toIndex]['lng'] as num?)?.toDouble())
                  : null);

        final orderData = {
          'userId': user.uid,
          'userName': userName.isNotEmpty ? userName : 'زبون',
          'userPhone': userData['phone'] as String? ?? '',
          'fromAddress': _fromFinalAddress,
          'fromLat': fromLat,
          'fromLng': fromLng,
          'toAddress': _toFinalAddress,
          'toLat': toLat,
          'toLng': toLng,
          'note': _noteCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
          'status': 'pending',
          'driverId': null,
          'collection': 'transport-orders',
          'transportType': _serviceName,
          '_fromImagePath': _fromImageFile?.path,
          '_toImagePath': _toImageFile?.path,
          '_parcelImagePath': _parcelImageFile?.path,
        };

        if (!mounted) return;
        Navigator.push(
          context,
          _slideRoute(ServiceDriverSelectionScreen(
            orderData: orderData,
            transportType: _serviceName)));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ خطأ: $e',
                style: const TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
        }
      }
    }

    IconData _iconFromType(String type) {
      if (type == 'home') return CupertinoIcons.house_fill;
      if (type == 'work') return CupertinoIcons.briefcase_fill;
      return CupertinoIcons.location_fill;
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: neuShadow(blur: 6, offset: 3)),
              child: const Icon(
                CupertinoIcons.chevron_left,
                color: kPrimaryColor,
                size: 20))),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              fontFamily: 'Amiri'))),
        body: Stack(
          children: [
            statusBarGradient(context),
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 120),
                  child: Column(
                    children: [
                      // بانر الخدمة
                      Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor.withOpacity(0.9), _accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                      ]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16)),
                          child: Icon(
                            _serviceIcon,
                            color: Colors.white,
                            size: 28)),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri')),
                              const SizedBox(height: 4),
                              Text(
                                'حدد نقطة الانطلاق والوصول أدناه',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 11,
                                  fontFamily: 'Amiri')),
                            ])),
                      ])),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // من أين
                        _sectionLabel('نقطة الانطلاق *', CupertinoIcons.location),
                        const SizedBox(height: 10),
                        _buildLocationPicker(
                          isFrom: true,
                          selectedIndex: _fromIndex,
                          useMap: _fromMap,
                          mapAddress: _fromAddr,
                          onSelectSaved: (i) => setState(() {
                            _fromIndex = i;
                            _fromMap = false;
                          }),
                          onSelectMap: (addr, lat, lng) => setState(() {
                            _fromMap = true;
                            _fromIndex = -1;
                            _fromAddr = addr;
                            _fromLat = lat;
                            _fromLng = lng;
                          })),

                        const SizedBox(height: 20),

                        // إلى أين
                        _sectionLabel(
                          'نقطة الوصول *',
                          CupertinoIcons.location_fill),
                        const SizedBox(height: 10),
                        _buildLocationPicker(
                          isFrom: false,
                          selectedIndex: _toIndex,
                          useMap: _toMap,
                          mapAddress: _toAddr,
                          onSelectSaved: (i) => setState(() {
                            _toIndex = i;
                            _toMap = false;
                          }),
                          onSelectMap: (addr, lat, lng) => setState(() {
                            _toMap = true;
                            _toIndex = -1;
                            _toAddr = addr;
                            _toLat = lat;
                            _toLng = lng;
                          })),

                        const SizedBox(height: 16),

                        _buildImagePicker(
                          file: _fromImageFile,
                          label: 'صورة موقع الانطلاق (اختياري)',
                          onPicked: (f) => setState(() => _fromImageFile = f)),
                        _buildImagePicker(
                          file: _toImageFile,
                          label: 'صورة موقع الوصول (اختياري)',
                          onPicked: (f) => setState(() => _toImageFile = f)),

                        const SizedBox(height: 20),

                        _sectionLabel(
                          'ملاحظة (اختياري)',
                          CupertinoIcons.text_bubble),
                        const SizedBox(height: 10),
                        _buildNeuTextField(
                          ctrl: _noteCtrl,
                          hint: 'مثال: عدد الركاب، نوع الحمولة...',
                          icon: CupertinoIcons.text_bubble),

                        const SizedBox(height: 20),

                        _buildImagePicker(
                          file: _parcelImageFile,
                          label: 'صورة الطلبية (اختياري)',
                          onPicked: (f) => setState(() => _parcelImageFile = f)),

                        const SizedBox(height: 20),

                        _sectionLabel(
                          'السعر المتفق عليه (DA) *',
                          CupertinoIcons.money_dollar_circle),
                        const SizedBox(height: 10),
                        _buildPriceField(),

                        const SizedBox(height: 28),
                        _buildConfirmButton(),
                        const SizedBox(height: 16),
                      ])),
                ])))),
                ],
              ),
            );
    }

    Widget _sectionLabel(String text, IconData icon) => Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kTextDark,
              fontFamily: 'Amiri'),
            textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            shape: BoxShape.circle),
          child: Icon(icon, color: _accentColor, size: 14)),
      ]);

    Widget _buildNeuTextField({
      required TextEditingController ctrl,
      required String hint,
      required IconData icon,
      int maxLines = 1,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: neuShadow(blur: 7, offset: 3)),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 14,
            color: kTextDark,
            fontFamily: 'Amiri'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 12,
              fontFamily: 'Amiri'),
            prefixIcon: Icon(icon, color: _accentColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14))));
    }

    Widget _buildPriceField() {
      return Container(
        decoration: BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accentColor.withOpacity(0.2)),
          boxShadow: neuShadow(blur: 7, offset: 3)),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Text(
                'DA',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Amiri'))),
            Expanded(
              child: TextField(
                controller: _priceCtrl,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 18,
                  color: kTextDark,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.black38, fontSize: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14)))),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                CupertinoIcons.money_dollar_circle,
                color: _accentColor.withOpacity(0.4),
                size: 20)),
          ]));
    }

    Widget _buildLocationPicker({
      required bool isFrom,
      required int selectedIndex,
      required bool useMap,
      required String mapAddress,
      required Function(int) onSelectSaved,
      required Function(String, double?, double?) onSelectMap,
    }) {
      return Column(
        children: [
          if (_loadingLocations)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(color: kPrimaryColor))
          else ...[
            ..._savedLocations.asMap().entries.map((e) {
              final i = e.key;
              final loc = e.value;
              final isSel = !useMap && selectedIndex == i;
              return GestureDetector(
                onTap: () => onSelectSaved(i),
                child: _buildTile(
                  loc['label'] as String,
                  loc['address'] as String,
                  _iconFromType(loc['type'] as String),
                  isSel));
            }),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: () async {
              final res = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()));
              if (res != null && mounted)
                onSelectMap(res['address'] ?? '', res['lat'], res['lng']);
            },
            child: _buildTile(
              'تحديد من الخريطة',
              useMap && mapAddress.isNotEmpty ? mapAddress : 'اضغط لفتح الخريطة',
              CupertinoIcons.map_fill,
              useMap)),
        ]);
    }

    Widget _buildTile(
      String label,
      String address,
      IconData icon,
      bool isSelected) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
          boxShadow: [
            BoxShadow(
              color: kShadowColor.withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4)),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(
            color: isSelected ? kPrimaryColor.withOpacity(0.6) : kPrimaryColor.withOpacity(0.1),
            width: isSelected ? 2 : 1)),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _accentColor : Colors.grey.shade400,
                  width: 2)),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null),
            const SizedBox(width: 10),
            Icon(icon, color: isSelected ? _accentColor : kShadowColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? _accentColor : kTextDark,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? kTextGrey : Colors.black45,
                      fontFamily: 'Amiri'),
                    textAlign: TextAlign.right),
                ])),
          ]));
    }

    Widget _buildConfirmButton() {
      return GestureDetector(
        onTap: _canConfirm ? _confirmOrder : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _canConfirm
                ? LinearGradient(
                    colors: [_accentColor.withOpacity(0.85), _accentColor],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft)
                : null,
            color: _canConfirm ? null : Colors.grey.shade300,
            boxShadow: _canConfirm
                ? [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                  ]
                : []),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _canConfirm
                            ? CupertinoIcons.checkmark_shield_fill
                            : CupertinoIcons.lock,
                        color: _canConfirm ? Colors.white : Colors.grey.shade500,
                        size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _canConfirm
                            ? 'تأكيد الطلبية واختيار السائق'
                            : 'أكمل البيانات المطلوبة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          color: _canConfirm
                              ? Colors.white
                              : Colors.grey.shade500)),
                    ]))));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  ServiceDriverSelectionScreen — رادار السائقين
  // ══════════════════════════════════════════════════════════════════════════════
  const List<_SlotCfg> _kSlots = [
    _SlotCfg(angle: -90, radius: 0.36),
    _SlotCfg(angle: -30, radius: 0.22),
    _SlotCfg(angle: 30, radius: 0.38),
    _SlotCfg(angle: 90, radius: 0.21),
    _SlotCfg(angle: 150, radius: 0.37),
    _SlotCfg(angle: 210, radius: 0.22),
    _SlotCfg(angle: -150, radius: 0.35),
    _SlotCfg(angle: -60, radius: 0.20),
    _SlotCfg(angle: 120, radius: 0.38),
    _SlotCfg(angle: 0, radius: 0.22),
  ];

  class _SlotCfg {
    final double angle, radius;
    const _SlotCfg({required this.angle, required this.radius});
  }

  class ServiceDriverSelectionScreen extends StatefulWidget {
    final Map<String, dynamic> orderData;
    final String? transportType;
    const ServiceDriverSelectionScreen({
      super.key,
      required this.orderData,
      this.transportType,
    });

    @override
    State<ServiceDriverSelectionScreen> createState() =>
        _ServiceDriverSelectionScreenState();
  }

  class _ServiceDriverSelectionScreenState
      extends State<ServiceDriverSelectionScreen>
      with TickerProviderStateMixin {
    late AnimationController _pulseCtrl, _cardCtrl;
    late Animation<double> _p1, _p2, _p3;
    late Animation<Offset> _cardSlide;
    late Animation<double> _cardFade;

    Map<String, dynamic>? _selectedDriver;
    bool _confirming = false;
    List<Map<String, dynamic>> _driversList = [];
    bool _loadingDrivers = true;
    List<String> _cities = [];
    String? _selectedCity;

    @override
    void initState() {
      super.initState();
      _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800))..repeat();
      _p1 = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _pulseCtrl,
          curve: const Interval(0.0, 0.85, curve: Curves.easeOut)));
      _p2 = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _pulseCtrl,
          curve: const Interval(0.2, 0.95, curve: Curves.easeOut)));
      _p3 = Tween<double>(begin: 0, end: 1).animate(
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
      _loadCities();
    }

    Future<void> _loadCities() async {
      try {
        final uCityAr = (UserLocal.data?['cityNameAr'] as String? ?? '').trim();
        final uCityFr = (UserLocal.data?['cityNameFr'] as String? ?? '').trim();
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

    Future<void> _loadDrivers() async {
      try {
        final data = await ApiClient.getList('/api/drivers?isOnline=true');
        if (mounted) {
          setState(() {
            _driversList = data.cast<Map<String, dynamic>>();
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

    void _select(Map<String, dynamic> d) {
      if (_selectedDriver?['uid'] == d['uid']) return;
      setState(() => _selectedDriver = d);
      _cardCtrl.forward(from: 0);
    }

    void _openDriverSheet(Map<String, dynamic> d) {
      final driver = DriverModel.fromMap(d);
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
        final collection = widget.orderData['collection'] as String? ?? 'service-orders';
        final data = Map<String, dynamic>.from(widget.orderData)
          ..remove('collection')
          ..addAll({
            'driverId': _selectedDriver!['uid'],
            'driverName':
                '${_selectedDriver!['firstName']} ${_selectedDriver!['lastName']}',
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        // رفع الصور عند إرسال الطلبية للسائق
        if (data['_parcelImagePath'] is String) {
          final file = File(data['_parcelImagePath'] as String);
          if (await file.exists()) {
            data['parcelImageUrl'] = await ApiClient.upload(file);
          }
        }
        if (data['_fromImagePath'] is String) {
          final file = File(data['_fromImagePath'] as String);
          if (await file.exists()) {
            data['fromImage'] = await ApiClient.upload(file);
          }
        }
        if (data['_toImagePath'] is String) {
          final file = File(data['_toImagePath'] as String);
          if (await file.exists()) {
            data['toImage'] = await ApiClient.upload(file);
          }
        }
        data.remove('_parcelImagePath');
        data.remove('_fromImagePath');
        data.remove('_toImagePath');
        final created = await ApiClient.post('/api/$collection', data);
        final orderId = created['_id'] as String;

        final driverData = await ApiClient.get('/api/drivers/${_selectedDriver!['uid']}') as Map<String, dynamic>?;
        final fcmToken = driverData?['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          final isTransport = collection == 'transport-orders';
          final title = isTransport ? '🚗 طلب نقل جديد' : '📦 طلب توصيل جديد';
          final addr = data['fromAddress'] as String? ?? data['toAddress'] as String? ?? '';
          final price = (data['price'] as num? ?? 0).toDouble();
          await ApiClient.post('/api/notify-driver', {
            'driverId': _selectedDriver!['uid'],
            'title': title,
            'body': 'من: $addr | السعر: ${price.toInt()} DZD',
            'data': {'orderId': orderId, 'type': 'new_order'},
          });
        }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => _ConfirmedScreen(orderId: orderId)),
          (r) => false);
      } catch (e) {
        if (mounted) {
          setState(() => _confirming = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ خطأ: $e',
                style: const TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))));
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: neuShadow(blur: 6, offset: 3)),
              child: const Icon(
                CupertinoIcons.chevron_left,
                color: kPrimaryColor,
                size: 20))),
          title: const Text(
            'اختر سائقك',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextDark,
              fontFamily: 'Amiri'))),
        body: Stack(
          children: [
            statusBarGradient(context),
            _loadingDrivers
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor))
                : _buildDriversContent(),
          ],
        ),
        );
    }

    Widget _buildDriversContent() {
      final drivers = _driversList.where((d) {
        // فلترة صارمة: يجب أن يكون السائق متصلاً ونشطاً
        final bool isOnline = d['isOnline'] == true;
        final bool isActive = d['isActive'] == true;
        if (!isOnline || !isActive) return false;

        if (_selectedCity != null && _selectedCity!.isNotEmpty) {
          String normalize(String s) => s.trim().replaceAll('_', ' ');
          final dAr = normalize(d['cityNameAr'] as String? ?? '');
          final dFr = normalize(d['cityNameFr'] as String? ?? '');
          final dCn = normalize(d['cityName'] as String? ?? '');
          final sel = normalize(_selectedCity!);
          if (dAr != sel && dFr != sel && dCn != sel) return false;
        }

        if (widget.transportType == null) {
          final vehicle = (d['vehicleType'] as String? ?? '');
          return vehicle == 'motorcycle';
        }
        final vehicle = (d['vehicleType'] as String? ?? '').toLowerCase();
        final type = widget.transportType!;
        if (type.contains('car')) return vehicle.contains('car');
        if (type.contains('transport')) return vehicle.contains('minibus') || vehicle.contains('harbin');
        if (type.contains('truck')) return vehicle.contains('truck') || vehicle.contains('fourgon');
        if (type.contains('motorcycle') || type == 'delivery' || type == 'pickup') return vehicle.contains('motorcycle');
        return true;
      }).map((d) {
        return {
          'uid': d['uid'],
          'firstName': d['firstName'] as String? ?? '',
          'lastName': d['lastName'] as String? ?? '',
          'phone': d['phone'] as String? ?? '',
          'photoUrl': d['photoUrl'] as String?,
          'totalDeliveries': d['totalDeliveries'] as int? ?? 0,
          'vehicleType': d['vehicleType'] as String? ?? '',
        };
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
                  border: Border.all(color: kShadowColor.withOpacity(0.3)),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCity,
                  hint: const Text('فلترة حسب المدينة', style: TextStyle(fontFamily: 'Amiri', fontSize: 13, color: kTextGrey)),
                  underline: const SizedBox(),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  onChanged: (val) => setState(() {
                    _selectedCity = val;
                    _selectedDriver = null;
                  }),
                  items: _cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)))).toList(),
                ),
              ),
            ),
          Expanded(
            child: drivers.isEmpty ? _noDrivers() : _buildRadar(drivers)),
          if (_selectedDriver != null) _buildDriverCard(_selectedDriver!),
          _buildConfirmBtn(),
        ]);
    }

    Widget _buildRadar(List<Map<String, dynamic>> drivers) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final sz = math.min(w, h);
          final cx = w / 2;
          final cy = h / 2;
          final count = math.min(drivers.length, _kSlots.length);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _RadarPainter())),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _PulsePainter(
                      p1: _p1.value,
                      p2: _p2.value,
                      p3: _p3.value,
                      maxR: sz * 0.42)))),
              Positioned(left: cx - 36, top: cy - 36, child: _center()),
              ...List.generate(count, (i) {
                final s = _kSlots[i];
                final rad = s.angle * math.pi / 180;
                final r = sz * s.radius;
                final dx = cx + r * math.cos(rad);
                final dy = cy + r * math.sin(rad);
                final d = drivers[i];
                final isSel = _selectedDriver?['uid'] == d['uid'];
                return Positioned(
                  left: dx - 39,
                  top: dy - 39,
                  child: GestureDetector(
                    onTap: () => _select(d),
                    onLongPress: () => _openDriverSheet(d),
                    child: _DriverPin(driver: d, isSelected: isSel)));
              }),
            ]);
        });
    }

    Widget _center() => Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBgColor,
        boxShadow: neuShadow(blur: 12, offset: 4)),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kPrimaryColor, kAccentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 1),
            ]),
          child: const Icon(
            CupertinoIcons.location_fill,
            color: Colors.white,
            size: 22))));

    Widget _noDrivers() => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBgColor,
              boxShadow: neuShadow(blur: 14, offset: 5)),
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
              color: kTextDark,
              fontFamily: 'Amiri')),
          const SizedBox(height: 8),
          Text(
            'حاول مرة أخرى بعد قليل',
            style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Amiri')),
        ]));

    Widget _buildDriverCard(Map<String, dynamic> d) => SlideTransition(
      position: _cardSlide,
      child: FadeTransition(
        opacity: _cardFade,
        child: GestureDetector(
          onTap: () => _openDriverSheet(d),
          child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
            boxShadow: [
              BoxShadow(
                color: kShadowColor.withOpacity(0.6),
                blurRadius: 10,
                offset: Offset(4, 4)),
              BoxShadow(
                color: Colors.white,
                blurRadius: 10,
                offset: Offset(-4, -4)),
            ],
            border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.chat_bubble_text,
                                  color: kPrimaryColor,
                                  size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'اضغط لقراءة التعليقات',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: kPrimaryColor,
                                    fontFamily: 'Amiri')),
                              ])),
                      ]),
                    const SizedBox(height: 6),
                    Text(
                      '${d['firstName']} ${d['lastName']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                        fontFamily: 'Amiri')),
                    const SizedBox(height: 4),
                    Text(
                      d['phone'] as String,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontFamily: 'Amiri')),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${d['totalDeliveries']} توصيلة',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500)),
                      ]),
                  ])),
              const SizedBox(width: 14),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBgColor,
                  border: Border.all(color: kPrimaryColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.25),
                      blurRadius: 10),
                  ]),
                child: ClipOval(child: _avatar(d))),
            ])))));

    Widget _avatar(Map<String, dynamic> d) {
      final url = d['photoUrl'] as String? ?? '';
      return url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Image.asset(
                'assets/images/avatar.png',
                fit: BoxFit.cover),
            )
          : Image.asset(
              'assets/images/avatar.png',
              fit: BoxFit.cover);
    }

    Widget _buildConfirmBtn() {
      final en = _selectedDriver != null && !_confirming;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        child: GestureDetector(
          onTap: en ? _confirm : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: en
                  ? const LinearGradient(
                      colors: [Color(0xFF6D22AC), kPrimaryColor, kAccentColor],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft)
                  : null,
              color: en ? null : Colors.grey.shade300,
              boxShadow: en
                  ? [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                    ]
                  : []),
            child: Center(
              child: _confirming
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_shield_fill,
                          color: en ? Colors.white : Colors.grey.shade500,
                          size: 20),
                        const SizedBox(width: 8),
                        Text(
                          en
                              ? 'تأكيد السائق وإرسال الطلبية'
                              : 'اختر سائقاً من الرادار',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri',
                            color: en ? Colors.white : Colors.grey.shade500)),
                      ])))));
    }
  }

  // ── DriverPin ─────────────────────────────────────────────────────────────────
  class _DriverPin extends StatelessWidget {
    final Map<String, dynamic> driver;
    final bool isSelected;
    const _DriverPin({required this.driver, required this.isSelected});

    @override
    Widget build(BuildContext context) {
      final fn = driver['firstName'] as String? ?? '';
      final ln = driver['lastName'] as String? ?? '';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBgColor,
              border: Border.all(
                color: isSelected ? kPrimaryColor : Colors.transparent,
                width: 3),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.5),
                        blurRadius: 18,
                        spreadRadius: 2),
                    ]
                  : neuShadow(blur: 8, offset: 3)),
            child: ClipOval(child: _buildAvatar())),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(maxWidth: 82),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? kPrimaryColor : kBgColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.3),
                        blurRadius: 8),
                    ]
                  : neuShadow(blur: 4, offset: 2)),
            child: Text(
              '$fn ${ln.isNotEmpty ? '${ln[0]}.' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : kTextDark,
                fontFamily: 'Amiri'))),
        ]);
    }

    Widget _buildAvatar() {
      final url = driver['photoUrl'] as String? ?? '';
      return url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Image.asset(
                'assets/images/avatar.png',
                width: 58,
                height: 58,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              'assets/images/avatar.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover);
    }
  }

  // ── Radar painters ────────────────────────────────────────────────────────────
  class _RadarPainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
      final c = Offset(size.width / 2, size.height / 2);
      final maxR = math.min(size.width, size.height) * 0.44;
      final paint = Paint()
        ..color = kPrimaryColor.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (int i = 1; i <= 3; i++) canvas.drawCircle(c, maxR * i / 3, paint);
      final lp = Paint()
        ..color = kPrimaryColor.withOpacity(0.05)
        ..strokeWidth = 1;
      for (int i = 0; i < 6; i++) {
        final a = (math.pi / 3) * i;
        canvas.drawLine(
          c,
          Offset(c.dx + maxR * math.cos(a), c.dy + maxR * math.sin(a)),
          lp);
      }
    }

    @override
    bool shouldRepaint(_) => false;
  }

  class _PulsePainter extends CustomPainter {
    final double p1, p2, p3, maxR;
    const _PulsePainter({
      required this.p1,
      required this.p2,
      required this.p3,
      required this.maxR,
    });
    @override
    void paint(Canvas canvas, Size size) {
      final c = Offset(size.width / 2, size.height / 2);
      void dp(double t) {
        if (t <= 0) return;
        canvas.drawCircle(
          c,
          maxR * t,
          Paint()
            ..color = kPrimaryColor.withOpacity((1 - t) * 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      }

      dp(p1);
      dp(p2);
      dp(p3);
    }

    @override
    bool shouldRepaint(_PulsePainter o) => o.p1 != p1 || o.p2 != p2 || o.p3 != p3;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  _ConfirmedScreen
  // ══════════════════════════════════════════════════════════════════════════════
  class _ConfirmedScreen extends StatefulWidget {
    final String orderId;
    const _ConfirmedScreen({required this.orderId});
    @override
    State<_ConfirmedScreen> createState() => _ConfirmedScreenState();
  }

  class _ConfirmedScreenState extends State<_ConfirmedScreen>
      with SingleTickerProviderStateMixin {
    late AnimationController _ctrl;
    late Animation<double> _scale, _fade;
    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700));
      _scale = Tween<double>(
        begin: 0.5,
        end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
      _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
      _ctrl.forward();
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBgColor,
        body: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kBgColor,
                          boxShadow: neuShadow(blur: 20, offset: 8)),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [kSuccessColor, Color(0xFF2ECC71)]),
                              boxShadow: [
                                BoxShadow(
                                  color: kSuccessColor.withOpacity(0.4),
                                  blurRadius: 16),
                              ]),
                            child: const Icon(
                              CupertinoIcons.checkmark_seal_fill,
                              color: Colors.white,
                              size: 38)))),
                      const SizedBox(height: 32),
                      const Text(
                        'تم تأكيد الطلبية! 🎉',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                          fontFamily: 'Amiri'),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(
                        'سيتواصل معك السائق قريباً',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontFamily: 'Amiri'),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '#${widget.orderId.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri'))),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (_) => false),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6D22AC),
                                kPrimaryColor,
                                kAccentColor,
                              ],
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimaryColor.withOpacity(0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 7)),
                            ]),
                          child: const Center(
                            child: Text(
                              'الرجوع للرئيسية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri'))))),
                    ]))))),),
                  ],
                ),
              );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  MapPickerScreen — خريطة حقيقية GPS + بحث + تأكيد
  // ══════════════════════════════════════════════════════════════════════════════
  class MapPickerScreen extends StatefulWidget {
    const MapPickerScreen({super.key});
    @override
    State<MapPickerScreen> createState() => _MapPickerScreenState();
  }

  class _MapPickerScreenState extends State<MapPickerScreen> {
    String _cityAr = '';
    String _cityFr = '';
    GoogleMapController? _mapCtrl;
    final _searchCtrl = TextEditingController();
    LatLng _selectedLatLng = const LatLng(36.7372, 3.0863);
    String _selectedAddress = '';
    bool _loadingLocation = true, _loadingAddress = false;

    @override
    void initState() {
      super.initState();
      _getUserLocation();
    }

    @override
    void dispose() {
      _mapCtrl?.dispose();
      _searchCtrl.dispose();
      super.dispose();
    }

    Future<void> _getUserLocation() async {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied)
          perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (mounted) setState(() => _loadingLocation = false);
          return;
        }
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedLatLng = ll;
          _loadingLocation = false;
        });
        _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: ll, zoom: 16)));
        await _reverseGeocode(ll);
      } catch (_) {
        if (mounted) setState(() => _loadingLocation = false);
      }
    }

    Future<void> _reverseGeocode(LatLng ll) async {
    if (!mounted) return;
    setState(() => _loadingAddress = true);
    try {
      // 1. طلب الاسم بالعربية من Nominatim (أدق للجزائر)
      final urlAr = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=ar';
      final respAr = await http.get(Uri.parse(urlAr), headers: {'User-Agent': 'walyyid-app'});

      // 2. طلب الاسم بالفرنسية
      final urlFr = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=fr';
      final respFr = await http.get(Uri.parse(urlFr), headers: {'User-Agent': 'walyyid-app'});

      if (respAr.statusCode == 200 && respFr.statusCode == 200) {
        final jsonAr = jsonDecode(respAr.body);
        final jsonFr = jsonDecode(respFr.body);
        
        final addrAr = jsonAr['address'];
        final addrFr = jsonFr['address'];

        // محاولة جلب اسم البلدية أو المدينة
        String cityAr = addrAr['city'] ?? addrAr['town'] ?? addrAr['village'] ?? addrAr['municipality'] ?? addrAr['county'] ?? '';
        String cityFr = addrFr['city'] ?? addrFr['town'] ?? addrFr['village'] ?? addrFr['municipality'] ?? addrFr['county'] ?? '';

        setState(() {
          // تنظيف الأسماء من الفواصل والتكرار
          _cityAr = cityAr.split(RegExp(r'[،,]')).first.trim();
          _cityFr = cityFr.split(RegExp(r'[،,]')).first.trim();
          
          // إذا بقيت العربية فارغة أو فرنسية، نضع تنبيهاً أو نستخدم الاسم المتوفر
          _selectedAddress = _cityAr.isNotEmpty ? _cityAr : _cityFr;
        });
        
        if (mounted) _selectedAddress = 'موقع محدد';
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }
    Future<void> _searchPlace(String q) async {
      if (q.trim().isEmpty) return;
      try {
        final locs = await locationFromAddress(q);
        if (!mounted || locs.isEmpty) return;
        final ll = LatLng(locs.first.latitude, locs.first.longitude);
        setState(() => _selectedLatLng = ll);
        _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: ll, zoom: 15)));
        await _reverseGeocode(ll);
      } catch (_) {}
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: kBgColor,
        body: Stack(
          children: [
            statusBarGradient(context),
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLatLng,
                zoom: 15),
              onMapCreated: (ctrl) {
                _mapCtrl = ctrl;
              },
              onTap: (ll) async {
                setState(() => _selectedLatLng = ll);
                await _reverseGeocode(ll);
              },
              markers: {
                Marker(
                  markerId: const MarkerId('sel'),
                  position: _selectedLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(280)),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false),

            // شريط البحث
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                          ]),
                        child: TextField(
                          controller: _searchCtrl,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          onSubmitted: _searchPlace,
                          style: const TextStyle(
                            fontSize: 13,
                            color: kTextDark,
                            fontFamily: 'Amiri'),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن مكان...',
                            hintStyle: const TextStyle(
                              color: Colors.black38,
                              fontSize: 13,
                              fontFamily: 'Amiri'),
                            prefixIcon: GestureDetector(
                              onTap: () => _searchPlace(_searchCtrl.text),
                              child: const Icon(
                                CupertinoIcons.search,
                                color: kPrimaryColor,
                                size: 20)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13))))),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                          ]),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          color: kPrimaryColor,
                          size: 20))),
                  ]))),

            // زر موقعي
            Positioned(
              bottom: 220,
              right: 16,
              child: GestureDetector(
                onTap: _getUserLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D22AC), kPrimaryColor, kAccentColor],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                    ]),
                  child: _loadingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.location_fill,
                              color: Colors.white,
                              size: 18),
                            SizedBox(width: 6),
                            Text(
                              'موقعي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri')),
                          ])))),

            // البطاقة السفلية
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                  boxShadow: [
                    BoxShadow(
                      color: kShadowColor.withOpacity(0.6),
                      blurRadius: 10,
                      offset: Offset(4, 4)),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                      offset: Offset(-4, -4)),
                  ],
                  border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10)))),
                    const Text(
                      'الموقع المحدد',
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextGrey,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Amiri')),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                        boxShadow: [
                          BoxShadow(
                            color: kShadowColor.withOpacity(0.6),
                            blurRadius: 10,
                            offset: Offset(4, 4)),
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-4, -4)),
                        ],
                        border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
                      child: Row(
                        children: [
                          _loadingAddress
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kPrimaryColor))
                              : const Icon(
                                  CupertinoIcons.location_solid,
                                  color: kPrimaryColor,
                                  size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _loadingAddress
                                  ? 'جاري تحديد العنوان...'
                                  : _selectedAddress.isEmpty
                                  ? 'اضغط على الخريطة لتحديد موقعك'
                                  : _selectedAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedAddress.isEmpty
                                    ? Colors.black38
                                    : kTextDark,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Amiri'),
                              textAlign: TextAlign.right)),
                        ])),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: (_selectedAddress.isEmpty || _loadingAddress)
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'address': _selectedAddress,
                                'lat': _selectedLatLng.latitude,
                                'lng': _selectedLatLng.longitude,
                                'cityNameAr': _cityAr, // 👈 أضف هذا
                                'cityNameFr': _cityFr, // 👈 أضف هذا
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: (_selectedAddress.isEmpty || _loadingAddress)
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF6D22AC),
                                    kPrimaryColor,
                                    kAccentColor,
                                  ],
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft),
                          color: (_selectedAddress.isEmpty || _loadingAddress)
                              ? Colors.grey.shade300
                              : null,
                          boxShadow: (_selectedAddress.isEmpty || _loadingAddress)
                              ? []
                              : [
                                  BoxShadow(
                                    color: kPrimaryColor.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                                ]),
                        child: Center(
                          child: Text(
                            _selectedAddress.isEmpty
                                ? 'حدد موقعك أولاً'
                                : 'تأكيد الموقع',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                              color: (_selectedAddress.isEmpty || _loadingAddress)
                                  ? Colors.grey.shade500
                                  : Colors.white))))),
                  ]))),

            // شاشة التحميل GPS
            if (_loadingLocation)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: kPrimaryColor),
                      SizedBox(height: 12),
                      Text(
                        'جاري تحديد موقعك...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Amiri')),
                    ]))),
          ]));
    }
  }

  // ── Route helper ──────────────────────────────────────────────────────────────
  Route _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: anim, child: child)),
    transitionDuration: const Duration(milliseconds: 350));
