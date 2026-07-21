import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'products_list_screen.dart';
import 'Services/api_client.dart';
import 'Services/delivery_screen.dart';

const _kPrimaryColor = Color(0xFF7D29C6);

class CustomOrderStoryView extends StatefulWidget {
  final String storeId;
  final String storeName;
  final double? storeLat;
  final double? storeLng;
  final String templateName;
  final int uiStyle;

  const CustomOrderStoryView({
    super.key,
    required this.storeId,
    required this.storeName,
    this.storeLat,
    this.storeLng,
    this.templateName = '',
    this.uiStyle = 1,
  });

  @override
  State<CustomOrderStoryView> createState() => _CustomOrderStoryViewState();
}

class _CustomOrderStoryViewState extends State<CustomOrderStoryView>
    with TickerProviderStateMixin {
  File? _selectedImage;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  String? _purchaseAddress;
  double? _purchaseLat;
  double? _purchaseLng;
  bool _isAdding = false;

  late final AnimationController _pageCtrl;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _storeNameCtrl.text = widget.storeName;
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _sizeCtrl.dispose();
    _storeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()));
    if (result != null && mounted) {
      setState(() {
        _purchaseAddress = result['address'] ?? '';
        _purchaseLat = (result['lat'] as num?)?.toDouble();
        _purchaseLng = (result['lng'] as num?)?.toDouble();
      });
    }
  }

  Future<String> _uploadImage(File file) async {
    try {
      return await ApiClient.upload(file);
    } catch (e) {
      return "";
    }
  }

  Future<void> _addToCart() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final desc = _descCtrl.text.trim();
    final storeName = _storeNameCtrl.text.trim();

    if (name.isEmpty) {
      _snack('أدخل اسم المنتج', isError: true);
      return;
    }
    if (storeName.isEmpty) {
      _snack('أدخل اسم المحل', isError: true);
      return;
    }

    setState(() => _isAdding = true);

    String imageUrl = "";

    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl.isEmpty) {
        _snack('فشل رفع الصورة، تأكد من الاتصال', isError: true);
        setState(() => _isAdding = false);
        return;
      }
    }

    final customProduct = Product(
      productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      price: price,
      imagePath: imageUrl,
      priceAffiche: price > 0 ? '${price.toInt()} DA' : 'سعر يُحدد',
      description: desc.isNotEmpty ? desc : name,
      note: desc.isNotEmpty ? desc : name,
      capacite: _sizeCtrl.text.trim(),
      storeName: storeName,
      storeLat: _purchaseLat ?? widget.storeLat,
      storeLng: _purchaseLng ?? widget.storeLng,
      storeId: widget.storeId,
      categoryName: 'طلب خاص',
      templateName: widget.templateName,
      uiStyle: widget.uiStyle,
      selectedModelName: null,
    );

    GlobalCart.provider.toggle(customProduct);

    if (mounted) {
      Navigator.pop(context);
      _snack('✅ تمت الإضافة للسلة');
    }
  }

  void _snack(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: isError ? Colors.redAccent : _kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImageSourceDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('اختر مصدر الصورة',
            style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: _kPrimaryColor),
                SizedBox(width: 8),
                Text('الكاميرا',
                    style:
                        TextStyle(fontFamily: 'Amiri', color: _kPrimaryColor)),
              ]),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: _kPrimaryColor),
                SizedBox(width: 8),
                Text('المعرض',
                    style:
                        TextStyle(fontFamily: 'Amiri', color: _kPrimaryColor)),
              ]),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child:
              const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri'))),
      ),
    );
  }

  Widget _fieldBox(String hint, IconData icon, TextEditingController ctrl,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textAlign: TextAlign.right,
          maxLines: maxLines,
          style: const TextStyle(
              fontSize: 14, color: Colors.white, fontFamily: 'Amiri'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
                fontFamily: 'Amiri'),
            suffixIcon: Icon(icon,
                color: Colors.white.withOpacity(0.45), size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final imageH = screenH * 0.28;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          statusBarGradient(context),
          SlideTransition(
        position: _slideUp,
        child: GestureDetector(
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity != null && d.primaryVelocity! > 500) {
              Navigator.pop(context);
            }
          },
          child: Column(
            children: [
              // ── Image header (28% of screen) ──
              SizedBox(
                height: imageH + MediaQuery.of(context).padding.top,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF1A1A2E),
                            child: const Center(
                              child: Icon(CupertinoIcons.photo_on_rectangle,
                                  color: Colors.white24, size: 48),
                            ),
                          ),
                    // Dark overlay
                    IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.black87,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top bar
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.xmark,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(widget.storeName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'Amiri')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Camera button center
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_selectedImage != null
                                      ? CupertinoIcons.camera_viewfinder
                                      : CupertinoIcons.camera,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                  _selectedImage != null
                                      ? 'تغيير الصورة'
                                      : 'أضف صورة',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'Amiri')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable form ──
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, safeBottom + 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _fieldBox('اسم المنتج', CupertinoIcons.tag, _nameCtrl),
                      const SizedBox(height: 12),
                      _fieldBox('السعر التقريبي (اختياري)',
                          CupertinoIcons.money_dollar_circle, _priceCtrl,
                          keyboard: TextInputType.number),
                      const SizedBox(height: 12),
                      _fieldBox('المقاس / الحجم (اختياري)',
                          CupertinoIcons.resize, _sizeCtrl),
                      const SizedBox(height: 12),

                      // ── Location picker ──
                      GestureDetector(
                        onTap: _pickLocation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _purchaseAddress != null
                                    ? _kPrimaryColor.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  _purchaseAddress != null
                                      ? CupertinoIcons.check_mark_circled_solid
                                      : CupertinoIcons.map_pin_ellipse,
                                  color: _purchaseAddress != null
                                      ? const Color(0xFF34C759)
                                      : Colors.white.withOpacity(0.45),
                                  size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _purchaseAddress ?? 'تحديد محل الشراء (اختياري)',
                                  style: TextStyle(
                                    color: _purchaseAddress != null
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.45),
                                    fontSize: 13,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_left,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _fieldBox('اسم المحل', CupertinoIcons.building_2_fill,
                          _storeNameCtrl),
                      const SizedBox(height: 12),
                      _fieldBox('الوصف (اختياري)', CupertinoIcons.text_bubble,
                          _descCtrl,
                          maxLines: 3),
                    ],
                  ),
                ),
              ),

              // ── Bottom button ──
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, safeBottom + 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.95),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: _isAdding ? null : _addToCart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _isAdding
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6D22AC),
                                Color(0xFF7D29C6),
                                Color(0xFF9232E8),
                              ],
                            ),
                      color: _isAdding ? Colors.grey.shade800 : null,
                      boxShadow: _isAdding
                          ? []
                          : [
                              BoxShadow(
                                color: _kPrimaryColor.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isAdding
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.cart_badge_plus,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'إضافة للسلة',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ],
    ),
  );
  }
}
