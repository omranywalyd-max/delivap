import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/products_list_screen.dart';

class ProductVariantsDialog extends StatefulWidget {
  final Product product;
  final Function(Product) onAction;

  const ProductVariantsDialog({
    super.key,
    required this.product,
    required this.onAction,
  });

  @override
  State<ProductVariantsDialog> createState() => _ProductVariantsDialogState();
}

TextDirection _textDirection(String text) {
  if (text.isEmpty) return TextDirection.rtl;
  final hasArabic = text.contains(RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]'));
  final hasLatinOrDigit = text.contains(RegExp(r'[a-zA-Z0-9]'));
  if (hasArabic && hasLatinOrDigit) return TextDirection.ltr;
  if (hasArabic) return TextDirection.rtl;
  return TextDirection.ltr;
}

class _ProductVariantsDialogState extends State<ProductVariantsDialog>
    with TickerProviderStateMixin {
  late final AnimationController _dialogAnim;
  late final Animation<double> _dialogFade;
  late final Animation<Offset> _dialogSlide;

  final Map<String, AnimationController> _btnControllers = {};
  final Map<String, Animation<double>> _btnScales = {};

  final Color kShadow = const Color(0xFFB8B1C8).withOpacity(0.5);
  final Color kSuccessGreen = const Color(0xFF27AE60);

  @override
  void initState() {
    super.initState();

    _dialogAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _dialogFade = CurvedAnimation(parent: _dialogAnim, curve: Curves.easeOut);
    _dialogSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dialogAnim, curve: Curves.easeOutCubic));

    for (final m in widget.product.models) {
      final String mName = m['name'] ?? '';
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
      final scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.91)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.91, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60,
        ),
      ]).animate(ctrl);
      _btnControllers[mName] = ctrl;
      _btnScales[mName] = scale;
    }

    _dialogAnim.forward();
  }

  @override
  void dispose() {
    _dialogAnim.dispose();
    for (final c in _btnControllers.values) {
      c.dispose();
    }
    super.dispose();
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _DialogNeumContainer(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            radius: 30,
            child: ListenableBuilder(
              listenable: GlobalCart.provider,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kPrimary.withOpacity(0.15), kPrimary.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.square_stack_3d_up_fill,
                            color: kPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            widget.product.name,
                            textDirection: _textDirection(widget.product.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Amiri',
                              color: Color(0xFF2D2540),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختر النوع الذي تريده',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF7B6E99),
                        fontFamily: 'Amiri',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildDivider(),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: widget.product.models.map((m) {
                            final String mName = m['name'] ?? '';
                            final String mImage = m['image'] ?? '';
                            final bool isInCart = GlobalCart.provider
                                .containsVariant(
                                  widget.product.productId,
                                  mName,
                                );
                            return _buildVariantRow(
                              mName: mName,
                              mImage: mImage,
                              isInCart: isInCart,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kBg,
                              const Color(0xFFE6E4F0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kShadow,
                              blurRadius: 8,
                              offset: const Offset(4, 4),
                            ),
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 8,
                              offset: const Offset(-4, -4),
                            ),
                          ],
                        ),
                        child: Text(
                          'إغلاق',
                          style: TextStyle(
                            color: const Color(0xFF7B6E99),
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() => Container(
    height: 1.5,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          kPrimary.withOpacity(0.2),
          Colors.transparent,
        ],
      ),
    ),
  );

  Widget _buildVariantRow({
    required String mName,
    required String mImage,
    required bool isInCart,
  }) {
    final ctrl = _btnControllers[mName];
    final scale = _btnScales[mName];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInCart
              ? kSuccessGreen.withOpacity(0.5)
              : kPrimary.withOpacity(0.1),
          width: isInCart ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kShadow,
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: scale ?? const AlwaysStoppedAnimation(1.0),
            builder: (_, child) =>
                Transform.scale(scale: scale?.value ?? 1.0, child: child),
            child: GestureDetector(
              onTap: () {
                ctrl?.stop();
                ctrl?.reset();
                final Product variantProd = widget.product.copyWith(
                  selectedModelName: mName,
                  imagePath: mImage.isNotEmpty ? mImage : widget.product.imagePath,
                );
                widget.onAction(variantProd);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isInCart
                        ? [const Color(0xFFE53935), const Color(0xFFC62828)]
                        : [kPrimary, const Color(0xFF4B3A8C)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: (isInCart ? Colors.red : kPrimary).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInCart
                          ? CupertinoIcons.trash
                          : CupertinoIcons.cart_badge_plus,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isInCart ? 'إزالة' : 'أضف',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: kShadow.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: mImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: mImage,
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const CupertinoActivityIndicator(radius: 8),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported,
                        size: 20,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.photo,
                      size: 20,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isInCart)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: kSuccessGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    Expanded(
                      child:                       Text(
                        '${widget.product.name} $mName',
                        textAlign: TextAlign.right,
                        textDirection: _textDirection('${widget.product.name} $mName'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D2540),
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.product.priceAffiche,
                      style: TextStyle(
                        fontSize: 12,
                        color: kSuccessGreen,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    const Text(
                      "  |  ",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    Text(
                      widget.product.capacite,
                      textDirection: getTextDirection(widget.product.capacite),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7B6E99),
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogNeumContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;

  const _DialogNeumContainer({
    required this.child,
    this.padding,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}
