import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/ModelSelectionDialog.dart';
import 'products_list_screen.dart';

// ── الألوان الموحدة ─────────────────────────────────────────────
const Color _kPrimary      = Color(0xFF7D29C6);
const Color _kPrimaryDark  = Color(0xFF6D22AC);
const Color _kPrimaryLight = Color(0xFF9232E8);

const Color _kBg           = Color(0xFFF1F0F5);
const Color _kCardColor    = Color(0xFFDCDAE6);
const Color _kNeumShadow   = Color(0xFFB8B1C8);
const Color _kSuccess      = Color(0xFF27AE60);
const Color _kTextDark     = Color(0xFF2D2A3A);
const Color _kTextGrey     = Color(0xFF6E6B7B);
const Color _kSelectedBg   = Color(0xFFEDE7F6);

// ════════════════════════════════════════════════════════════════
//  DRINK DIALOG  (مربع المشروبات — كيما ProductVariantsDialog)
// ════════════════════════════════════════════════════════════════
class DrinkPickerDialog extends StatefulWidget {
  final DrinkItem drink;
  // Map: flavorLabel -> { sizeLabel -> qty }
  final Map<String, Map<String, int>> currentSelections;
  final void Function(Map<String, Map<String, int>> updated) onChanged;

  const DrinkPickerDialog({
    super.key,
    required this.drink,
    required this.currentSelections,
    required this.onChanged,
  });

  @override
  State<DrinkPickerDialog> createState() => _DrinkPickerDialogState();
}

class _DrinkPickerDialogState extends State<DrinkPickerDialog>
    with TickerProviderStateMixin {

  late final AnimationController _dialogAnim;
  late final Animation<double>   _dialogFade;
  late final Animation<Offset>   _dialogSlide;

  // النكهة المحددة حاليًا لعرض أحجامها
  DrinkFlavor? _activeFlavor;

  // نسخة محلية قابلة للتعديل
  late Map<String, Map<String, int>> _selections;

  @override
  void initState() {
    super.initState();

    // نسخ عميق
    _selections = {};
    widget.currentSelections.forEach((fl, sizes) {
      _selections[fl] = Map<String, int>.from(sizes);
    });

    // إذا كان فيه نكهة واحدة فقط — نفتحها مباشرة
    if (widget.drink.flavors.length == 1) {
      _activeFlavor = widget.drink.flavors.first;
    }

    _dialogAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320));
    _dialogFade = CurvedAnimation(parent: _dialogAnim, curve: Curves.easeOut);
    _dialogSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero).animate(CurvedAnimation(parent: _dialogAnim, curve: Curves.easeOutCubic));

    _dialogAnim.forward();
  }

  @override
  void dispose() {
    _dialogAnim.dispose();
    super.dispose();
  }

  // إجمالي كمية هذا المشروب
  int get _totalQty {
    int t = 0;
    _selections.forEach((_, sizes) => sizes.forEach((_, q) => t += q));
    return t;
  }

  // كمية نكهة معينة
  int _flavorQty(String flavorLabel) {
    int t = 0;
    (_selections[flavorLabel] ?? {}).forEach((_, q) => t += q);
    return t;
  }

  // كمية حجم معين
  int _sizeQty(String flavorLabel, String sizeLabel) =>
      _selections[flavorLabel]?[sizeLabel] ?? 0;

  void _addSize(String flavorLabel, String sizeLabel) {
    setState(() {
      _selections[flavorLabel] ??= {};
      _selections[flavorLabel]![sizeLabel] =
          (_selections[flavorLabel]![sizeLabel] ?? 0) + 1;
    });
    widget.onChanged(_selections);
  }

  void _removeSize(String flavorLabel, String sizeLabel) {
    setState(() {
      final current = _selections[flavorLabel]?[sizeLabel] ?? 0;
      if (current <= 1) {
        _selections[flavorLabel]?.remove(sizeLabel);
        if (_selections[flavorLabel]?.isEmpty ?? false) {
          _selections.remove(flavorLabel);
        }
        // إذا ما بقاش كمية في هذه النكهة — نرجع لعرض النكهات
        if (_flavorQty(flavorLabel) == 0 && _activeFlavor?.label == flavorLabel) {
          _activeFlavor = null;
        }
      } else {
        _selections[flavorLabel]![sizeLabel] = current - 1;
      }
    });
    widget.onChanged(_selections);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _dialogFade,
      child: SlideTransition(
        position: _dialogSlide,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: _NeumCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── هيدر المشروب ─────────────────────────────────
                _buildHeader(),
                const SizedBox(height: 16),
                _buildGradientDivider(),
                const SizedBox(height: 14),

                // ── المحتوى: إما النكهات أو الأحجام ─────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero).animate(anim),
                      child: child)),
                  child: _activeFlavor == null
                      ? _buildFlavorsList()
                      : _buildSizesList(_activeFlavor!)),

                const SizedBox(height: 16),

                // ── زر الإغلاق ───────────────────────────────────
                _buildCloseButton(),
                const SizedBox(height: 4),
              ])))));
  }

  // ── هيدر ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // صورة المشروب الصغيرة
        if (widget.drink.image.isNotEmpty)
          Container(
            width: 44, height: 44,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kBg,
              boxShadow: [
                BoxShadow(color: _kNeumShadow.withOpacity(0.3),
                    blurRadius: 6, offset: const Offset(2, 2)),
                const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 6,
                    offset: Offset(-2, -2)),
              ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.drink.image,
                memCacheWidth: 100,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    Icon(CupertinoIcons.drop_fill,
                        color: _kPrimary.withOpacity(0.4), size: 22)))),

        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.drink.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  fontFamily: 'Amiri',
                  color: _kTextDark),
                textAlign: TextAlign.center),
              const SizedBox(height: 2),
              // إذا كان فيه نكهة مفتوحة — نبين "رجوع"
              if (_activeFlavor != null)
                GestureDetector(
                  onTap: () => setState(() => _activeFlavor = null),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.chevron_right,
                          size: 11, color: _kPrimary),
                      const SizedBox(width: 4),
                      Text(
                        _activeFlavor!.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kPrimary,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w600)),
                    ]))
              else
                Text(
                  'اختر النكهة والحجم',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'Amiri')),
            ])),

        // Badge الإجمالي
        if (_totalQty > 0)
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _kPrimary.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ]),
            child: Center(
              child: Text(
                '$_totalQty',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri')))),
      ]);
  }

  // ── قائمة النكهات ────────────────────────────────────────────────
  Widget _buildFlavorsList() {
    return ConstrainedBox(
      key: const ValueKey('flavors'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: widget.drink.flavors.map((flavor) {
            final fQty = _flavorQty(flavor.label);
            final bool hasQty = fQty > 0;

            return _FlavorRow(
              flavor: flavor,
              qty: fQty,
              isSelected: hasQty,
              onTap: () => setState(() => _activeFlavor = flavor));
          }).toList())));
  }

  // ── قائمة الأحجام ────────────────────────────────────────────────
  Widget _buildSizesList(DrinkFlavor flavor) {
    return ConstrainedBox(
      key: ValueKey('sizes_${flavor.label}'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: flavor.sizes.map((size) {
            final qty = _sizeQty(flavor.label, size.label);
            final bool hasQty = qty > 0;

            return _SizeRow(
              size: size,
              qty: qty,
              isInCart: hasQty,
              onAdd: () => _addSize(flavor.label, size.label),
              onRemove: () => _removeSize(flavor.label, size.label));
          }).toList())));
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 13),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _kNeumShadow.withOpacity(0.45),
                blurRadius: 8, offset: const Offset(4, 4)),
            const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 8,
                offset: Offset(-4, -4)),
          ]),
        child: const Text(
          'إغلاق',
          style: TextStyle(
            color: _kTextGrey,
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
            fontSize: 14))));
  }

  Widget _buildGradientDivider() => Container(
    height: 1.2,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          _kNeumShadow.withOpacity(0.4),
          Colors.transparent,
        ])));
}

// ════════════════════════════════════════════════════════════════
//  صف النكهة  (كيما صف الموديل في ProductVariantsDialog)
// ════════════════════════════════════════════════════════════════
class _FlavorRow extends StatelessWidget {
  final DrinkFlavor flavor;
  final int qty;
  final bool isSelected;
  final VoidCallback onTap;

  const _FlavorRow({
    required this.flavor,
    required this.qty,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Colors.white, _kSelectedBg])
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kBg, Color(0xFFE6E4F0)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _kPrimary.withOpacity(0.5)
                : _kPrimary.withOpacity(0.1),
            width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: _kNeumShadow.withOpacity(0.35),
                      blurRadius: 6, offset: const Offset(3, 3)),
                  const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 6,
                      offset: Offset(-3, -3)),
                ]
              : [
                  BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                  BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
                ]),
        child: Row(
          children: [
            // سهم الدخول
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(color: _kPrimary.withOpacity(0.35),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ]),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.chevron_left,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  const Text(
                    'اختر',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Amiri')),
                ])),

            const SizedBox(width: 12),

            // صورة النكهة
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _kBg,
                boxShadow: [
                  BoxShadow(color: _kNeumShadow.withOpacity(0.3),
                      blurRadius: 4, offset: const Offset(2, 2)),
                ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: flavor.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: flavor.image,
                        memCacheWidth: 100,
                        fit: BoxFit.contain,
                        placeholder: (_, __) =>
                            const CupertinoActivityIndicator(radius: 8),
                        errorWidget: (_, __, ___) => Icon(
                          CupertinoIcons.drop_fill,
                          color: _kPrimary.withOpacity(0.3), size: 22))
                    : Icon(CupertinoIcons.drop_fill,
                        color: _kPrimary.withOpacity(0.3), size: 22))),

            const SizedBox(width: 12),

            // الاسم والسعر
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isSelected) ...[
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kPrimaryDark, _kPrimary]),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri'))),
                      ],
                      Expanded(
                        child: Text(
                          flavor.label,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? _kPrimary : _kTextDark,
                            fontFamily: 'Amiri'))),
                    ]),
                  const SizedBox(height: 3),
                  Text(
                    '${flavor.sizes.length} مقاس متاح',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontFamily: 'Amiri'),
                    textAlign: TextAlign.right),
                ])),
          ])));
  }
}

// ════════════════════════════════════════════════════════════════
//  صف الحجم  (مع عداد + / -)
// ════════════════════════════════════════════════════════════════
class _SizeRow extends StatefulWidget {
  final DrinkSize size;
  final int qty;
  final bool isInCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _SizeRow({
    required this.size,
    required this.qty,
    required this.isInCart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_SizeRow> createState() => _SizeRowState();
}

class _SizeRowState extends State<_SizeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.91)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.91, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: widget.isInCart
            ? const LinearGradient(
                colors: [Colors.white, _kCardColor])
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBg, Color(0xFFE6E4F0)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isInCart
              ? _kSuccess.withOpacity(0.5)
              : _kPrimary.withOpacity(0.1),
          width: widget.isInCart ? 2 : 1),
        boxShadow: widget.isInCart
            ? [
                BoxShadow(color: _kNeumShadow.withOpacity(0.3),
                    blurRadius: 6, offset: const Offset(3, 3)),
                const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 6,
                    offset: Offset(-3, -3)),
              ]
            : [
                BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
              ]),
      child: Row(
        children: [
          // ── عداد + / - ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _scale,
            builder: (_, child) =>
                Transform.scale(scale: _scale.value, child: child),
            child: _buildCounter()),

          const SizedBox(width: 14),

          // ── الاسم والسعر ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.isInCart)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: _kSuccess,
                          shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 10)),
                    Expanded(
                      child: Text(
                        widget.size.label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: widget.isInCart ? _kPrimary : _kTextDark,
                          fontFamily: 'Amiri'))),
                  ]),
                const SizedBox(height: 4),
                Text(
                  '${widget.size.price.toInt()} DA',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kSuccess,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri'),
                  textAlign: TextAlign.right),
              ])),
        ]));
  }

  Widget _buildCounter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر +
        GestureDetector(
          onTap: () {
            _ctrl.forward(from: 0);
            widget.onAdd();
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: _kPrimary.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 3)),
              ]),
            child: const Icon(CupertinoIcons.plus,
                color: Colors.white, size: 16))),

        const SizedBox(width: 8),

        // الكمية
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: SizedBox(
            width: 24,
            child: Text(
              key: ValueKey(widget.qty),
              '${widget.qty}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.qty > 0 ? _kPrimary : Colors.grey.shade300,
                fontFamily: 'Amiri')))),

        const SizedBox(width: 8),

        // زر -
        GestureDetector(
          onTap: widget.qty > 0 ? () {
            _ctrl.forward(from: 0);
            widget.onRemove();
          } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.qty > 0 ? Colors.white : _kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.qty > 0
                    ? _kPrimary.withOpacity(0.4)
                    : _kNeumShadow.withOpacity(0.2)),
              boxShadow: widget.qty > 0
                  ? [BoxShadow(color: _kNeumShadow.withOpacity(0.25),
                      blurRadius: 5, offset: const Offset(2, 2))]
                  : null),
            child: Icon(CupertinoIcons.minus,
                size: 16,
                color: widget.qty > 0 ? _kPrimary : Colors.grey.shade300))),
      ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  CARD نيومورفيك للديالوغ
// ════════════════════════════════════════════════════════════════
class _NeumCard extends StatelessWidget {
  final Widget child;
  const _NeumCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: child);
  }
}

// ════════════════════════════════════════════════════════════════
//  PRODUCT DETAIL SHEET
// ════════════════════════════════════════════════════════════════
class ProductDetailSheet extends StatefulWidget {
  final Product product;
  final List<DrinkItem> drinks;
  final bool isInCart;
  final VoidCallback onAddToCart;
  final void Function(Product)? onProductAddedToTemplate;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.drinks,
    required this.isInCart,
    required this.onAddToCart,
    this.onProductAddedToTemplate,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet>
    with TickerProviderStateMixin {

  PizzaTopping? _selectedTopping;
  PizzaSize?    _selectedSize;

  // ── هيكل جديد للمشروبات المختارة ────────────────────────────────
  // drinkId -> flavorLabel -> sizeLabel -> qty
  final Map<String, Map<String, Map<String, int>>> _drinksSelections = {};

  final TextEditingController _noteCtrl = TextEditingController();
  int _productQuantity = 1;
  int _currentImageIndex = 0;
  late PageController _pageController;

  late AnimationController _btnCtrl;
  late Animation<double>   _btnScale;
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;
  late ScrollController    _scrollController;
  double _imageHeight = 240;
  static const double _maxImageHeight = 240;
  static const double _minImageHeight = 110;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController()..addListener(_onScroll);

    if (widget.product.toppings.isNotEmpty) {
      _selectedTopping = PizzaTopping.fromMap(
          Map<String, dynamic>.from(widget.product.toppings[0] as Map));
      if (_selectedTopping!.sizes.isNotEmpty)
        _selectedSize = _selectedTopping!.sizes.first;
    }

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _btnScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.93), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.93, end: 1.0), weight: 60),
    ]).animate(_btnCtrl);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _entryFade =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {
      _imageHeight = (_maxImageHeight - _scrollController.offset)
          .clamp(_minImageHeight, _maxImageHeight);
    });
  }

  double get _unitPrice =>
      _selectedSize?.price ?? widget.product.price;

  // إجمالي المشروبات
  double get _drinksTotal {
    double total = 0;
    _drinksSelections.forEach((drinkId, flavors) {
      final drink = widget.drinks.firstWhere(
        (d) => d.id == drinkId,
        orElse: () => widget.drinks.first);
      flavors.forEach((flavorLabel, sizes) {
        sizes.forEach((sizeLabel, qty) {
          // نحاول نلقى السعر تاع الحجم
          double sizePrice = drink.price;
          for (final f in drink.flavors) {
            if (f.label == flavorLabel) {
              for (final s in f.sizes) {
                if (s.label == sizeLabel) {
                  sizePrice = s.price;
                  break;
                }
              }
            }
          }
          total += sizePrice * qty;
        });
      });
    });
    return total;
  }

  double get _totalDisplayPrice =>
      (_unitPrice * _productQuantity) + _drinksTotal;

  // إجمالي كمية مشروب معين
  int _drinkTotalQty(String drinkId) {
    int t = 0;
    (_drinksSelections[drinkId] ?? {}).forEach((_, sizes) {
      sizes.forEach((_, q) => t += q);
    });
    return t;
  }

  // فتح ديالوغ المشروب
  void _openDrinkDialog(DrinkItem drink) {
    // نحضر الاختيارات الحالية بتحويل الهيكل
    final Map<String, Map<String, int>> current = {};
    (_drinksSelections[drink.id] ?? {}).forEach((fl, sizes) {
      current[fl] = Map<String, int>.from(sizes);
    });

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => DrinkPickerDialog(
        drink: drink,
        currentSelections: current,
        onChanged: (updated) {
          setState(() {
            if (updated.isEmpty) {
              _drinksSelections.remove(drink.id);
            } else {
              // تحويل Map<String, Map<String,int>> -> Map<String,Map<String,int>>
              _drinksSelections[drink.id] = {};
              updated.forEach((fl, sizes) {
                _drinksSelections[drink.id]![fl] = Map<String, int>.from(sizes);
              });
            }
          });
        }));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _btnCtrl.dispose();
    _entryCtrl.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.91,
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.18),
                blurRadius: 40,
                offset: const Offset(0, -8)),
            ]),
          child: Column(children: [
            _buildHandle(),
            _buildHeroImage(),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildProductHeader(),
                    const SizedBox(height: 18),
                    _buildAboutProductSection(),
                    const SizedBox(height: 18),
                    _buildProductQuantitySelector(),
                    const SizedBox(height: 18),

                    if (widget.product.toppings.isNotEmpty) ...[
                      _buildSectionTitle(
                          "اختر النكهة", CupertinoIcons.star_fill),
                      const SizedBox(height: 12),
                      _buildToppingsList(),
                      const SizedBox(height: 18),
                    ],

                    if (_selectedTopping != null &&
                        _selectedTopping!.sizes.isNotEmpty) ...[
                      _buildSectionTitle(
                          "المقاس", CupertinoIcons.resize),
                      const SizedBox(height: 12),
                      _buildSizesList(),
                      const SizedBox(height: 18),
                    ],

                    if (widget.drinks.isNotEmpty) ...[
                      _buildSectionTitle(
                          "أضف مشروبات (اختياري)",
                          CupertinoIcons.drop_fill),
                      const SizedBox(height: 12),
                      _buildDrinksSection(),
                      const SizedBox(height: 18),
                    ],

                    const SizedBox(height: 110),
                  ]))),
            _buildBottomActionCard(),
          ]))));
  }

  // ── هيدر المنتج ─────────────────────────────────────────────────
  Widget _buildProductHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _kPrimary.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5))
            ]),
          child: Text(
            '${_unitPrice.toInt()} DA',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: Colors.white,
              letterSpacing: 0.5))),
        if (widget.product.capacite.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kPrimary.withOpacity(0.2))),
            child: Text(
              widget.product.capacite,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Amiri',
                color: _kPrimary))),
        ],
        const SizedBox(height: 12),
        Text(
          widget.product.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            color: _kTextDark,
            height: 1.3)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '4.8',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            ...List.generate(
              5,
              (i) => Icon(
                i < 4
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.star_lefthalf_fill,
                color: const Color(0xFFFFC107),
                size: 13)),
          ]),
      ]);
  }

  // ── وصف المنتج ──────────────────────────────────────────────────
  Widget _buildAboutProductSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                "عن المنتج",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: _kTextDark)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.info_circle_fill,
                    color: Colors.white, size: 13)),
            ]),
          const SizedBox(height: 4),
          Divider(color: _kNeumShadow.withOpacity(0.2), height: 18),
          Text(
            widget.product.description.isNotEmpty
                ? widget.product.description
                : "لا يوجد وصف حالي لهذا المنتج.",
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              color: _kTextGrey,
              height: 1.9,
              fontFamily: 'Amiri')),
        ]));
  }

  // ── كمية المنتج ─────────────────────────────────────────────────
  Widget _buildProductQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kNeumShadow.withOpacity(0.2))),
            child: Row(
              children: [
                _qtyCircleBtn(
                  icon: CupertinoIcons.minus,
                  onTap: () {
                    if (_productQuantity > 1)
                      setState(() => _productQuantity--);
                  }),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: SizedBox(
                    width: 30,
                    child: Text(
                      key: ValueKey(_productQuantity),
                      '$_productQuantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _kPrimary,
                        fontFamily: 'Amiri')))),
                const SizedBox(width: 8),
                _qtyCircleBtn(
                  icon: CupertinoIcons.plus,
                  onTap: () => setState(() => _productQuantity++),
                  isAdd: true),
              ])),
          Row(
            children: [
              const Text(
                'الكمية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _kTextDark,
                  fontFamily: 'Amiri')),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: _kPrimary.withOpacity(0.3),
                        blurRadius: 8, offset: const Offset(0, 3)),
                  ]),
                child: const Icon(CupertinoIcons.layers_alt,
                    color: Colors.white, size: 16)),
            ]),
        ]));
  }

  Widget _qtyCircleBtn(
      {required IconData icon,
      required VoidCallback onTap,
      bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: isAdd
              ? const LinearGradient(
                  colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft)
              : null,
          color: isAdd ? null : Colors.white,
          shape: BoxShape.circle,
          border: isAdd
              ? null
              : Border.all(color: _kNeumShadow.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: _kNeumShadow.withOpacity(0.28),
                blurRadius: 6, offset: const Offset(2, 2)),
            const BoxShadow(color: Color(0xFFD8D7DE),
                blurRadius: 6, offset: Offset(-2, -2)),
          ]),
        child: Icon(icon,
            size: 15,
            color: isAdd ? Colors.white : _kPrimary)));
  }



  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      width: 42, height: 4,
      decoration: BoxDecoration(
        color: _kNeumShadow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10))));

  List<String> get _allImages {
    final imgs = <String>[widget.product.imagePath];
    if (widget.product.extraImages.isNotEmpty) {
      for (var e in widget.product.extraImages) {
        final s = e.toString();
        if (s.isNotEmpty) imgs.add(s);
      }
    }
    return imgs;
  }

  Widget _buildHeroImage() {
    final images = _allImages;
    final hasMultiple = images.length > 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      height: _imageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: Column(
        children: [
          Expanded(
            child: hasMultiple
                ? PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentImageIndex = i),
                    itemCount: images.length,
                    itemBuilder: (_, i) => Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(27),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CachedNetworkImage(
                            imageUrl: images[i],
                            memCacheWidth: 400,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                                child: CupertinoActivityIndicator(color: _kPrimary)),
                            errorWidget: (context, url, error) => const Icon(
                                Icons.fastfood, size: 60, color: _kTextGrey))))))
                : Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: CachedNetworkImage(
                          imageUrl: images.first,
                          memCacheWidth: 400,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                              child: CupertinoActivityIndicator(color: _kPrimary)),
                          errorWidget: (context, url, error) => const Icon(
                              Icons.fastfood, size: 60, color: _kTextGrey)))))),
          if (hasMultiple)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == i ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == i ? _kPrimary : _kNeumShadow,
                      borderRadius: BorderRadius.circular(4)))))),
        ]));
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _kTextDark,
              fontFamily: 'Amiri')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: _kPrimary.withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 3)),
            ]),
          child: Icon(icon, color: Colors.white, size: 13)),
      ]);
  }

  Widget _buildToppingsList() {
    return SizedBox(
      height: 106,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.product.toppings.length,
        itemBuilder: (context, i) {
          final rawTopping = widget.product.toppings[i];
          final topping = PizzaTopping.fromMap(
              Map<String, dynamic>.from(rawTopping as Map));
          bool isSelected = _selectedTopping?.label == topping.label;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedTopping = topping;
              _selectedSize = topping.sizes.isNotEmpty
                  ? topping.sizes.first
                  : null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 85,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft)
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kBg, Color(0xFFE6E4F0)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : _kPrimary.withOpacity(0.1),
                  width: 1.2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: _kPrimary.withOpacity(0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 5))
                      ]
                    : [
                        BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                        BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
                      ]),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: CachedNetworkImage(
                          imageUrl: topping.image,
                          memCacheWidth: 200,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorWidget: (c, u, e) => const Icon(
                              Icons.fastfood, size: 22, color: _kTextGrey))))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 3, 5, 7),
                    child: Text(
                      topping.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : _kTextDark,
                        fontFamily: 'Amiri'),
                      textAlign: TextAlign.center)),
                ])));
        }));
  }

  Widget _buildSizesList() {
    final sizes = _selectedTopping?.sizes ?? [];
    if (sizes.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: sizes.map((s) {
        bool isSelected = _selectedSize?.label == s.label;
        return GestureDetector(
          onTap: () => setState(() => _selectedSize = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [_kSelectedBg, Colors.white],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft)
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kBg, Color(0xFFE6E4F0)]),
              border: Border.all(
                color: isSelected ? _kPrimary : _kPrimary.withOpacity(0.1),
                width: isSelected ? 2.5 : 1.2),
              boxShadow: isSelected
                  ? [BoxShadow(color: _kPrimary.withOpacity(0.2),
                      blurRadius: 12, offset: const Offset(0, 4))]
                  : [
                      BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                      BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
                    ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color: isSelected ? _kSuccess : _kNeumShadow,
                  size: 18),
                const SizedBox(height: 5),
                Text(s.label,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? _kPrimary : _kTextDark)),
                const SizedBox(height: 3),
                Text('${s.price.toInt()} DA',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        fontFamily: 'Amiri')),
              ])));
      }).toList());
  }

  // ── قسم المشروبات (الجديد — كارد + badge + زر لفتح الديالوغ) ──
  Widget _buildDrinksSection() {
    return Column(
      children: widget.drinks.map((drink) {
        final totalQty = _drinkTotalQty(drink.id);
        final bool hasSelection = totalQty > 0;

        // نجمع ملخص الاختيارات للعرض
        final List<String> summaryLines = [];
        (_drinksSelections[drink.id] ?? {}).forEach((fl, sizes) {
          sizes.forEach((sz, qty) {
            if (qty > 0) summaryLines.add('$qty× $fl - $sz');
          });
        });

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: hasSelection
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBg, Color(0xFFE6E4F0)]),
            color: hasSelection ? Colors.white : null,
            border: Border.all(
              color: hasSelection
                  ? _kPrimary.withOpacity(0.55)
                  : _kPrimary.withOpacity(0.1),
              width: hasSelection ? 2.0 : 1.0),
            boxShadow: hasSelection
                ? [
                    BoxShadow(color: _kPrimary.withOpacity(0.12),
                        blurRadius: 16, offset: const Offset(0, 6)),
                    BoxShadow(color: _kNeumShadow.withOpacity(0.2),
                        blurRadius: 8, offset: const Offset(3, 3)),
                  ]
                : [
                    BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
                    BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
                  ]),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── زر فتح الديالوغ ─────────────────────────────
                GestureDetector(
                  onTap: () => _openDrinkDialog(drink),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kPrimaryDark, _kPrimary, _kPrimaryLight],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: _kPrimary.withOpacity(0.38),
                            blurRadius: 10, offset: const Offset(0, 4)),
                      ]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasSelection
                              ? CupertinoIcons.pencil
                              : CupertinoIcons.plus,
                          color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          hasSelection ? 'تعديل' : 'أضف',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'Amiri')),
                      ]))),

                const SizedBox(width: 12),

                // ── معلومات المشروب ─────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        drink.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          color: _kTextDark),
                        textAlign: TextAlign.right),
                      const SizedBox(height: 3),
                      // ملخص الاختيارات
                      if (summaryLines.isNotEmpty)
                        ...summaryLines.map(
                          (line) => Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kPrimary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _kPrimary,
                                fontFamily: 'Amiri',
                                fontWeight: FontWeight.w600),
                              textAlign: TextAlign.right)))
                      else
                        Text(
                          'ابدأ من ${drink.price.toInt()} DA',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.w500)),
                    ])),

                const SizedBox(width: 10),

                // ── صورة مع badge ───────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 62, width: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: hasSelection
                              ? [_kPrimary.withOpacity(0.08),
                                 _kPrimaryLight.withOpacity(0.05)]
                              : [_kBg, _kCardColor.withOpacity(0.4)]),
                        border: Border.all(
                          color: hasSelection
                              ? _kPrimary.withOpacity(0.2)
                              : _kNeumShadow.withOpacity(0.15))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: drink.image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: drink.image,
                                height: 62, width: 62,
                                memCacheWidth: 124,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(
                                  CupertinoIcons.drop_fill,
                                  color: _kPrimary.withOpacity(0.3),
                                  size: 28))
                            : Icon(CupertinoIcons.drop_fill,
                                color: _kPrimary.withOpacity(0.35),
                                size: 28))),
                    // Badge
                    if (hasSelection)
                      Positioned(
                        top: -7, right: -7,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kPrimaryDark, _kPrimary]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _kPrimary.withOpacity(0.45),
                                  blurRadius: 7,
                                  offset: const Offset(0, 2)),
                            ]),
                          child: Center(
                            child: Text(
                              '$totalQty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri'))))),
                  ]),
              ])));
      }).toList());
  }

  void _addToCartWithModel(Product variant) {
    _doAddToCart(variant.name, variant.imagePath, selectedModelName: variant.selectedModelName);
  }

  void _doAddToCart(String mainName, String imagePath, {String? selectedModelName}) {
    String name = mainName;
    if (_selectedTopping != null) {
      name = "$mainName - ${_selectedTopping!.label}";
    }

    final mainProduct = Product(
      productId: '${widget.product.productId}_${_selectedSize?.label ?? 'default'}_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: (_selectedTopping != null && _selectedTopping!.image.isNotEmpty) ? _selectedTopping!.image : imagePath,
      name: name,
      price: _unitPrice,
      quantity: _productQuantity,
      capacite: _selectedSize?.label ?? widget.product.capacite,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      note: _noteCtrl.text.trim(),
      selectedModelName: selectedModelName,
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName);
    if (!GlobalCart.provider.toggle(mainProduct)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('عذراً، هذا النوع من المنتجات لا يمكن إضافته مع منتجات أخرى في السلة. يرجى تفريغ السلة أولاً.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }

    widget.onProductAddedToTemplate?.call(mainProduct);

    _drinksSelections.forEach((drinkId, flavors) {
      final drinkItem = widget.drinks.firstWhere((d) => d.id == drinkId);
      flavors.forEach((flavorLabel, sizes) {
        sizes.forEach((sizeLabel, qty) {
          if (qty > 0) {
            double sPrice = drinkItem.price;
            String sImage = drinkItem.image;
            for (var f in drinkItem.flavors) {
              if (f.label == flavorLabel) {
                if (f.image.isNotEmpty) sImage = f.image;
                for (var s in f.sizes) {
                  if (s.label == sizeLabel) { sPrice = s.price; break; }
                }
              }
            }

            final dP = Product(
              productId: 'drink_${drinkId}_${flavorLabel}_${sizeLabel}_${DateTime.now().millisecondsSinceEpoch}',
              storeId: widget.product.storeId,
              storeName: widget.product.storeName,
              imagePath: sImage,
              name: "${drinkItem.name} - $flavorLabel",
              price: sPrice,
              quantity: qty,
              capacite: sizeLabel,
              storeLat: widget.product.storeLat,
              storeLng: widget.product.storeLng,
              note: '',
              categoryName: widget.product.categoryName,
              templateName: widget.product.templateName);
            GlobalCart.provider.toggle(dP);
          }
        });
      });
    });

    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  // ── الكارد السفلي ───────────────────────────────────────────────
  Widget _buildBottomActionCard() {
    final int totalDrinksQty = _drinksSelections.values.fold(
      0,
      (sum, flavors) => sum +
          flavors.values.fold(
              0, (s2, sizes) => s2 + sizes.values.fold(0, (s3, q) => s3 + q)));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: _kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalDrinksQty > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPrimary.withOpacity(0.15))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$totalDrinksQty مشروب مضاف',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.drop_fill,
                      color: _kPrimary, size: 13),
                ])),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScaleTransition(
                scale: _btnScale,
                child: GestureDetector(
                  onTap: () {
                    _btnCtrl.forward(from: 0);

                    if (widget.product.models.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (ctx) => ProductVariantsDialog(
                          product: widget.product,
                          onAction: (variant) => _addToCartWithModel(variant),
                        ),
                      );
                      return;
                    }
                    _doAddToCart(widget.product.name, widget.product.imagePath);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kPrimaryDark,
                          _kPrimary,
                          _kPrimaryLight,
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 7)),
                      ]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(CupertinoIcons.cart_badge_plus,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "أضف للسلة",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'Amiri',
                            letterSpacing: 0.3)),
                      ])))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "السعر الإجمالي",
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontFamily: 'Amiri')),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Text(
                      key: ValueKey(_totalDisplayPrice.toInt()),
                      "${_totalDisplayPrice.toInt()} DA",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _kPrimary,
                        fontFamily: 'Amiri',
                        height: 1))),
                  if (_productQuantity > 1)
                    Text(
                      '× $_productQuantity قطعة',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'Amiri')),
                ]),
            ]),
        ]));
  }
}

// ════════════════════════════════════════════════════════════════
//  دالة العرض
// ════════════════════════════════════════════════════════════════
void showProductDetail({
  required BuildContext context,
  required Product product,
  required List<DrinkItem> drinks,
  required bool isInCart,
  required VoidCallback onAddToCart,
  void Function(Product)? onProductAddedToTemplate,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ProductDetailSheet(
      product: product,
      drinks: drinks,
      isInCart: isInCart,
      onAddToCart: onAddToCart,
      onProductAddedToTemplate: onProductAddedToTemplate));
}