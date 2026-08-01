import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_1/app_cached_image.dart';
import 'dart:io';
import 'package:flutter_application_1/dashboard_screen.dart';
import 'products_list_screen.dart';
import 'stores_widget.dart';
import 'custom_order_story_view.dart';
import 'dart:math' as math;
import 'Services/api_client.dart';
import 'user_local.dart';
import 'main_page.dart';

const kPrimaryColor = Color(0xFF7D29C6);
const kPrimaryDark = Color(0xFF6D22AC);
const kAccentColor = Color(0xFF9232E8);
const kBgColor = Color(0xFFF1F0F5);
const kCardColor = Color(0xFFDCDAE6);
const kNeumShadow = Color(0xFFB8B1C8);
const kTextDark = Color(0xFF2D2A3A);
const kTextGrey = Color(0xFF6E6B7B);

// ── Category Cache ──────────────────────────────────────────────────────────
class _CatCache {
  static final Map<String, _CacheEntry> _store = {};

  static List<_CachedCategory>? get(String id) => _store[id]?.data;
  static bool has(String id) {
    final entry = _store[id];
    if (entry == null) return false;
    // ✅ TTL: 20 دقيقة — الأصناف نادراً ما تتغير أثناء اليوم، و pull-to-refresh هو الطريقة الأساسية للتحديث
    if (DateTime.now().difference(entry.fetchedAt).inMinutes >= 20) {
      _store.remove(id);
      return false;
    }
    return true;
  }
  static void set(String id, List<_CachedCategory> cats) {
    if (_store.length >= 50) {
      _store.remove(_store.keys.first);
    }
    _store[id] = _CacheEntry(data: cats, fetchedAt: DateTime.now());
  }
}

class _CacheEntry {
  final List<_CachedCategory> data;
  final DateTime fetchedAt;
  const _CacheEntry({required this.data, required this.fetchedAt});
}

class _CachedCategory {
  final String id, name, image;
  final String storeId;
  final double? distance;
  final double? lat, lng;
  final String openTime;
  final String closeTime;
  const _CachedCategory({
    required this.id,
    required this.name,
    required this.image,
    this.distance,
    required this.storeId,
    this.lat,
    this.lng,
    this.openTime = '',
    this.closeTime = '',
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  StoresView
// ══════════════════════════════════════════════════════════════════════════════
class StoresView extends StatefulWidget {
  final String templateId;
  final List<dynamic> stores; // ✅ نستقبل المتاجر من DashboardScreen باش ما نعاودوش fetch

  const StoresView({
    super.key,
    required this.templateId,
    required this.stores,
  });

  @override
  State<StoresView> createState() => _StoresViewState();
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = math.cos;
  var a =
      0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}

class _StoresViewState extends State<StoresView> with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  String _storeName = '';
  double? _storeLat, _storeLng;
  int _uiStyle = 1;
  Color _storeColor = kPrimaryColor;
  List<_CachedCategory> _categories = [];
  bool _loadingCats = false;
  bool _isOutOfRange = false;
  bool _locationNotSet = false;
  bool _showDistanceFlag = false;
  bool _allowMultiple = false;
  String _storeVille = '';

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650));

    // ✅ مستمع ذكي: أول ما يجهز الموقع في الداشبورد، هاد الكود راح يفيق ويعاود يحمل الأقسام
    LocationProvider().addListener(_checkDistanceAndLoad);

    _checkDistanceAndLoad();
  }

  @override
  void didUpdateWidget(StoresView old) {
    super.didUpdateWidget(old);
    if (old.templateId != widget.templateId || old.stores != widget.stores) {
      // ✅ نمسح cache القسم عشان force refresh (مثلاً بعد pull-to-refresh)
      _CatCache._store.remove(widget.templateId);
      _staggerCtrl.reset();
      _checkDistanceAndLoad();
    }
  }

  @override
  void dispose() {
    // ✅ تنظيف الذاكرة
    LocationProvider().removeListener(_checkDistanceAndLoad);
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkDistanceAndLoad() async {
    final locProv = LocationProvider();

    try {
      // ✅ نستعمل المتاجر الجاهزة من DashboardScreen (مررة عبر constructor)
      //    باش ما نعاودوش fetch زايد
      final storeData = widget.stores.firstWhere(
        (s) => s['_id'] == widget.templateId || s['id'] == widget.templateId,
        orElse: () => <String, dynamic>{},
      );
      _showDistanceFlag = storeData['showDistance'] ?? false;
      _allowMultiple = storeData['allowMultipleCategories'] ?? false;

      if (mounted) {
        setState(() {
          _locationNotSet = false;
          _isOutOfRange = false;
          _storeName = storeData['nom'] ?? '';
          _storeVille = storeData['ville'] ?? '';
          _storeLat = (storeData['lat'] as num?)?.toDouble();
          _storeLng = (storeData['lng'] as num?)?.toDouble();
          _uiStyle = (storeData['uiStyle'] as int?) ?? 1;
          _storeColor = StoreColorCache.fromHex(
            storeData['primaryColor'] ?? '#7C29C5');
        });
      }
      _loadCategories(widget.templateId);
    } catch (e) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _loadCategories(String templateId) async {
    final locProv = LocationProvider();

    if (!locProv.hasLocation && _showDistanceFlag && !_allowMultiple) {
      if (mounted) setState(() => _locationNotSet = true);
      return;
    }

    // ✅ إذا الكاش موجود → نعرضو فوراً (zero loading) ونجددو فالخلفية
    if (_CatCache.has(templateId)) {
      if (mounted) {
        setState(() {
          final cached = _CatCache.get(templateId);
          if (cached != null) _categories = cached;
          _isOutOfRange = false;
          _locationNotSet = false;
        });
        _staggerCtrl.forward(from: 0);
      }
    } else {
      if (mounted) setState(() => _loadingCats = true);
    }

    try {
      final cats = await ApiClient.getList('/api/categories?templateId=$templateId&storeId=$templateId');
      final List<_CachedCategory> validCats = [];
      for (var doc in cats) {
        final d = doc as Map<String, dynamic>;
        final docId = d['_id'] as String? ?? '';

        double catLat = (d['lat'] as num?)?.toDouble() ?? 0.0;
        double catLng = (d['lng'] as num?)?.toDouble() ?? 0.0;
        String specificStoreId =
            d['storeId'] ?? '';

        if (locProv.hasLocation && locProv.lat != null && locProv.lng != null && _showDistanceFlag && !_allowMultiple) {
          double dist = _calculateDistance(
            locProv.lat!,
            locProv.lng!,
            catLat,
            catLng);

          if (dist <= 35.0) {
            validCats.add(
              _CachedCategory(
                id: docId,
                name: d['nom'] ?? '',
                image: d['image'] ?? '',
                distance: dist,
                storeId:
                    specificStoreId,
                lat: catLat,
                lng: catLng,
                openTime: d['openTime'] ?? '',
                closeTime: d['closeTime'] ?? ''));
          }
        } else {
          validCats.add(
            _CachedCategory(
              id: docId,
              name: d['nom'] ?? '',
              image: d['image'] ?? '',
              storeId: specificStoreId,
              lat: catLat,
              lng: catLng,
              openTime: d['openTime'] ?? '',
              closeTime: d['closeTime'] ?? ''));
        }
      }
      // ✅ نخزن فال cache (حتى لو كان قديم، نحدثو)
      _CatCache.set(templateId, validCats);

      if (mounted) {
        setState(() {
          _categories = validCats;
          _loadingCats = false;
          _isOutOfRange =
              validCats.isEmpty && locProv.hasLocation && _showDistanceFlag && !_allowMultiple;
          _locationNotSet = false;
        });
        _staggerCtrl.forward(from: 0);
      }
      precacheImages(
        validCats.map((c) => c.image).where((i) => i.isNotEmpty).toList(),
      );
    } catch (e) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showDistanceFlag && !_allowMultiple) {
      if (_locationNotSet)
        return _buildMessage(
          "يجب تحديد موقعك أولاً لكي تظهر المحلات التي بنطاقك",
          CupertinoIcons.location_slash);
      if (_isOutOfRange)
        return _buildMessage(
          "نعتذر، لا توجد محلات في نطاقكم حالياً",
          CupertinoIcons.map_pin_slash);
    }

    // حساب عدد الكاردات الكلي = التصنيفات + كارد "حسب الطلب" (موش في ستايل المشاريع)
    final bool shouldShowCustomCard = _categories.isNotEmpty && _uiStyle == 1;
    final totalItems = _categories.length + (shouldShowCustomCard ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _storeName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kTextDark)),
              if (_storeVille.isNotEmpty)
                Text(
                  _storeVille,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Amiri',
                    color: kTextGrey)),
            ])),
        const SizedBox(height: 4),
        if (_loadingCats)
          const SizedBox(
            height: 150,
            child: Center(
              child: CupertinoActivityIndicator(color: kPrimaryColor)))
        else
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            clipBehavior: Clip.none,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.95),
            itemCount: totalItems,
            itemBuilder: (context, i) {
              if (shouldShowCustomCard && i == 1) {
                return _CustomOrderCard(
                  storeId: widget.templateId,
                  storeName: _storeName,
                  lat: _storeLat,
                  lng: _storeLng,
                  templateName: _storeName,
                  uiStyle: _uiStyle);
              }

              // بقية العناصر (الأقسام العادية)
              final catIndex = shouldShowCustomCard ? (i > 1 ? i - 1 : i) : i;
              final cat = _categories[catIndex];
              return CategoryCardWidget(
                key: ValueKey(cat.id),
                name: cat.name,
                imagePath: cat.image,
                categoryId: cat.id,
                storeId: cat.storeId!,
                storeName: cat.name,
                templateName: _storeName,
                lat: cat.lat,
                lng: cat.lng,
                uiStyle: _uiStyle,
                storeColor: _storeColor,
                distance: cat.distance,
                openTime: cat.openTime,
                closeTime: cat.closeTime);
            }),
      ]);
  }

  Widget _buildMessage(String msg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Amiri',
              color: Colors.grey.shade600,
              fontSize: 13)),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CustomOrderCard — كارد "حسب الطلب" الخاص
// ══════════════════════════════════════════════════════════════════════════════
class _CustomOrderCard extends StatefulWidget {
  final String storeId;
  final String storeName;
  final double? lat;
  final double? lng;
  final String templateName;
  final int uiStyle;
  const _CustomOrderCard({
    required this.storeId,
    required this.storeName,
    this.lat,
    this.lng,
    this.templateName = '',
    this.uiStyle = 1,
  });

  @override
  State<_CustomOrderCard> createState() => _CustomOrderCardState();
}

class _CustomOrderCardState extends State<_CustomOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    // 1. إصلاح الأنيميشن: جعل النطاق من 0 إلى 1 لتفادي الخطأ
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    // 2. استخدام Tween لتحديد القيم المطلوبة (التكبير والتصغير)
    _pulse = Tween<double>(
      begin: 0.97,
      end: 1.03).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _requireAuth(() => _showCustomOrderSheet(context)),
      child: ScaleTransition(
        scale: _pulse,
        child: Padding(
          // 1. أضفنا Padding هنا لتصغير حجم الكارد بالنسبة للمربع ✅
          padding: const EdgeInsets.all(12.0),
          child: Container(
            // تقليل الـ Padding الداخلي للكارد
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // تصغير نصف القطر قليلاً
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6D22AC),
                  Color(0xFF7D29C6),
                  Color(0xFF9232E8),
                ]),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
              ]),
            child: Center(
              // تأكد أن كل شيء في المنتصف
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 2. تصغير حجم حاوية الأيقونة من 64 إلى 45 ✅
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.2)),
                    child: const Icon(
                      CupertinoIcons.bag_badge_plus,
                      color: Colors.white,
                      size: 22)), // تصغير الأيقونة لـ 22

                  const SizedBox(height: 8),

                  // 3. تصغير الخط من 15 إلى 13 ✅
                  const Text(
                    'حسب الطلب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Amiri')),

                  const SizedBox(height: 4),

                  // 4. تصغير الشارة السفلية ✅
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15)),
                    child: const Text(
                      'اطلب الآن',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white70,
                        fontFamily: 'Amiri'))),
                ]))))));
  }

  void _showCustomOrderSheet(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => CustomOrderStoryView(
          storeId: widget.storeId,
          storeName: widget.storeName,
          storeLat: widget.lat,
          storeLng: widget.lng,
          templateName: widget.templateName,
          uiStyle: widget.uiStyle),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: child),
        transitionDuration: const Duration(milliseconds: 350)),
    );
  }

  void _requireAuth(VoidCallback action) {
    if (UserLocal.uid == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
          content: const Text('لازم تكون مسجل دخولك', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: 15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('رجوع', style: TextStyle(fontFamily: 'Amiri')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 3)),
                  (_) => false,
                );
              },
              child: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Amiri')),
            ),
          ],
        ),
      );
    } else {
      action();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CustomOrderSheet — شيت الطلب الخاص (صورة + ملاحظة + سعر + إضافة للسلة)
// ══════════════════════════════════════════════════════════════════════════════
class _CustomOrderSheet extends StatefulWidget {
  final String storeId;
  final String storeName;
  final double? storeLat;
  final double? storeLng;
  final String templateName;
  const _CustomOrderSheet({
    required this.storeId,
    required this.storeName,
    this.storeLat,
    this.storeLng,
    this.templateName = '',
  });

  @override
  State<_CustomOrderSheet> createState() => _CustomOrderSheetState();
}

class _CustomOrderSheetState extends State<_CustomOrderSheet>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  bool _isAdding = false;

  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _noteCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<String> _uploadImage(File file) async {
    try {
      return await ApiClient.upload(file);
    } catch (e) {
      return "";
    }
  }

  Future<void> _addToCart() async {
    final note = _noteCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (note.isEmpty && _selectedImage == null) {
      _snack('أضف صورة أو وصف للطلب', isError: true);
      return;
    }

    setState(() => _isAdding = true);

    String imageUrl = "";

    // ✅ الرفع إلى السيرفر
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
      if (!mounted) return;
      if (imageUrl.isEmpty) {
        _snack('فشل رفع الصورة، تأكد من الاتصال', isError: true);
        setState(() => _isAdding = false);
        return;
      }
    }

    // ✅ إنشاء المنتج: الآن imagePath يحتوي على رابط HTTPS
    final customProduct = Product(
      productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: note.isNotEmpty ? note : 'طلب خاص',
      price: price,
      imagePath: imageUrl,
      priceAffiche: price > 0 ? '${price.toInt()} DA' : 'سعر يُحدد',
      description: note,
      storeName: widget.storeName,
      storeLat: widget.storeLat,
      storeLng: widget.storeLng,
      storeId: widget.storeId,
      categoryName: 'طلب خاص',
      templateName: widget.templateName,
      selectedModelName: imageUrl.isNotEmpty
          ? 'مع صورة توضيحية'
          : 'طلب نصي فقط');

    GlobalCart.provider.toggle(customProduct);

    if (mounted) {
      Navigator.maybePop(context);
    }
    if (mounted) {
      _snack('✅ تمت الإضافة للسلة');
    }
  }

  void _snack(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: isError ? Colors.redAccent : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80);
    if (picked != null && mounted)
      setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _pickImageCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80);
    if (picked != null && mounted)
      setState(() => _selectedImage = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10))),

              // Header بتدرج بنفسجي
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [kPrimaryDark, kPrimaryColor, kAccentColor],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                  ]),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                      child: const Icon(
                        CupertinoIcons.bag_badge_plus,
                        color: Colors.white,
                        size: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.storeName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'Amiri')),
                          const Text(
                            'اطلب ما تريد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri')),
                          const Text(
                            'أضف صورة وملاحظة وسنجلب لك ما تريد',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'Amiri')),
                        ])),
                  ])),

              // المحتوى
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // منطقة الصورة
                      const SizedBox(height: 4),
                      _sectionLabel('الصورة (اختياري)', CupertinoIcons.camera),
                      const SizedBox(height: 10),

                      GestureDetector(
                        onTap: () => _showImageSourceDialog(),
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: _selectedImage == null
                                ? LinearGradient(
                                    colors: [
                                      kPrimaryColor.withOpacity(0.06),
                                      kAccentColor.withOpacity(0.04),
                                    ])
                                : null,
                            border: Border.all(
                              color: _selectedImage != null
                                  ? kPrimaryColor
                                  : kNeumShadow.withOpacity(0.4),
                              width: _selectedImage != null ? 2 : 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: kNeumShadow.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(4, 4)),
                              BoxShadow(
                                color: Color(0xFFB8B1C8).withOpacity(0.6),
                                blurRadius: 8,
                                offset: Offset(-4, -4)),
                            ]),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.contain,
                                        cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                                        cacheHeight: (180 * MediaQuery.of(context).devicePixelRatio).round()),
                                      // زر تغيير الصورة
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: GestureDetector(
                                          onTap: () => _showImageSourceDialog(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.55),
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.camera,
                                                  color: Colors.white,
                                                  size: 14),
                                                SizedBox(width: 5),
                                                Text(
                                                  'تغيير',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontFamily: 'Amiri')),
                                              ])))),
                                    ]))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [kPrimaryDark, kPrimaryColor]),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: kPrimaryColor.withOpacity(
                                              0.4),
                                            blurRadius: 12),
                                        ]),
                                      child: const Icon(
                                        CupertinoIcons.camera,
                                        color: Colors.white,
                                        size: 26)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'اضغط لإضافة صورة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryColor,
                                        fontFamily: 'Amiri')),
                                    const SizedBox(height: 4),
                                    Text(
                                      'من الكاميرا أو المعرض',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontFamily: 'Amiri')),
                                  ]))),

                      const SizedBox(height: 20),

                      // الملاحظة / الوصف
                      _sectionLabel(
                        'الوصف والملاحظة',
                        CupertinoIcons.text_bubble),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: kBgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: kNeumShadow.withOpacity(0.5),
                              blurRadius: 6,
                              offset: const Offset(3, 3)),
                            BoxShadow(
                              color: Color(0xFFB8B1C8).withOpacity(0.6),
                              blurRadius: 6,
                              offset: Offset(-3, -3)),
                          ]),
                        child: TextField(
                          controller: _noteCtrl,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kTextDark,
                            fontFamily: 'Amiri'),
                          decoration: const InputDecoration(
                            hintText:
                                'مثال: أريد بيتزا مارغريتا كبيرة مع إضافة جبنة إضافية...',
                            hintStyle: TextStyle(
                              color: kTextGrey,
                              fontSize: 12,
                              fontFamily: 'Amiri'),
                            prefixIcon: Icon(
                              CupertinoIcons.text_bubble,
                              color: kPrimaryColor,
                              size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14)))),

                      const SizedBox(height: 16),

                      // السعر التقريبي
                      _sectionLabel(
                        'السعر التقريبي (اختياري)',
                        CupertinoIcons.money_dollar_circle),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: kBgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: kNeumShadow.withOpacity(0.5),
                              blurRadius: 6,
                              offset: const Offset(3, 3)),
                            BoxShadow(
                              color: Color(0xFFB8B1C8).withOpacity(0.6),
                              blurRadius: 6,
                              offset: Offset(-3, -3)),
                          ]),
                        child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kTextDark,
                            fontFamily: 'Amiri'),
                          decoration: const InputDecoration(
                            hintText: '0 DA',
                            hintStyle: TextStyle(
                              color: kTextGrey,
                              fontSize: 13,
                              fontFamily: 'Amiri'),
                            prefixIcon: Icon(
                              CupertinoIcons.money_dollar_circle,
                              color: kPrimaryColor,
                              size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14)))),

                      // ملاحظة توضيحية
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: kPrimaryColor.withOpacity(0.15))),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.info_circle,
                              color: kPrimaryColor,
                              size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'سيتصل بك السائق للتأكيد من الطلب قبل الشراء',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kPrimaryColor.withOpacity(0.9),
                                  fontFamily: 'Amiri'),
                                textAlign: TextAlign.right)),
                          ])),

                      const SizedBox(height: 80),
                    ]))),

              // زر الإضافة للسلة
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: kBgColor,
                  boxShadow: [
                    BoxShadow(
                      color: kNeumShadow.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, -5)),
                  ]),
                child: GestureDetector(
                  onTap: _isAdding ? null : _addToCart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: _isAdding
                          ? null
                          : const LinearGradient(
                              colors: [
                                kPrimaryDark,
                                kPrimaryColor,
                                kAccentColor,
                              ],
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft),
                      color: _isAdding ? Colors.grey.shade300 : null,
                      boxShadow: _isAdding
                          ? []
                          : [
                              BoxShadow(
                                color: kPrimaryColor.withOpacity(0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                            ]),
                    child: Stack(
                      children: [
                        if (!_isAdding)
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
                                    Colors.white.withOpacity(0.2),
                                    Colors.transparent,
                                  ])))),
                        Center(
                          child: _isAdding
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
                                      CupertinoIcons.cart_badge_plus,
                                      color: Colors.white,
                                      size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'إضافة للسلة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Amiri')),
                                  ])),
                      ])))),
            ]))));
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kTextDark,
            fontFamily: 'Amiri')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryDark, kPrimaryColor]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 8),
            ]),
          child: Icon(icon, color: Colors.white, size: 13)),
      ]);
  }

  void _showImageSourceDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text(
          'اختر مصدر الصورة',
          style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImageCamera();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: kPrimaryColor),
                SizedBox(width: 8),
                Text(
                  'الكاميرا',
                  style: TextStyle(fontFamily: 'Amiri', color: kPrimaryColor)),
              ])),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: kPrimaryColor),
                SizedBox(width: 8),
                Text(
                  'المعرض',
                  style: TextStyle(fontFamily: 'Amiri', color: kPrimaryColor)),
              ])),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CategoryCardWidget
// ══════════════════════════════════════════════════════════════════════════════
class CategoryCardWidget extends StatefulWidget {
  final String name, imagePath, categoryId, storeId, storeName, templateName;
  final int uiStyle;
  final Color storeColor;
  final double? distance;
  final double? lat, lng;
  final String openTime;
  final String closeTime;

  const CategoryCardWidget({
    super.key,
    required this.name,
    required this.imagePath,
    required this.categoryId,
    required this.storeId,
    required this.storeName,
    required this.uiStyle,
    required this.storeColor,
    required this.templateName,
    this.distance,
    this.lat,
    this.lng,
    this.openTime = '',
    this.closeTime = '',
  });

  @override
  State<CategoryCardWidget> createState() => _CategoryCardWidgetState();
}

class _CategoryCardWidgetState extends State<CategoryCardWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductsListScreen(
            categoryId: widget.categoryId,
            categoryName: widget.name,
            storeId: widget.storeId,
            storeName: widget.storeName,
            categoryImagePath: widget.imagePath,
            heroTag: 'card_${widget.categoryId}',
            uiStyle: widget.uiStyle,
            storeColor: widget.storeColor,
            storeLat: widget.lat,
            storeLng: widget.lng,
            templateName: widget.templateName,
            openTime: widget.openTime,
            closeTime: widget.closeTime))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
              color: Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1))),
        child: Column(
          children: [
            Expanded(
              flex: 7,
              child: CachedNetworkImage(
                imageUrl: widget.imagePath,
                fit: BoxFit.contain,
                memCacheWidth: (MediaQuery.of(context).size.width / 2 * MediaQuery.of(context).devicePixelRatio).round(),
                imageBuilder: (context, img) => Transform.scale(
                  scale: 1.1,
                  child: Image(image: img, fit: BoxFit.contain)),
                placeholder: (_, __) =>
                    const Center(child: CupertinoActivityIndicator(radius: 10)),
                errorWidget: (_, __, ___) => Icon(
                  Icons.category_rounded,
                  size: 40,
                  color: widget.storeColor.withOpacity(0.4)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: widget.distance != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${widget.distance!.toStringAsFixed(1)} km",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                        Flexible(
                          child: Text(
                            widget.name,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: kTextDark,
                              fontFamily: 'Amiri'))),
                      ])
                  : Center(
                      child: Text(
                        widget.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: kTextDark,
                          fontFamily: 'Amiri')))),
          ])));
  }
}
