import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/products_list_screen.dart';
import 'package:flutter_application_1/ModelSelectionDialog.dart';
import 'package:flutter_application_1/product_detail_sheet.dart';
import 'package:flutter_application_1/dashboard_screen.dart';
import 'dart:math' as math;
import 'dart:async';

// ✅ تحديث الألوان لتتناسب مع الستايل البنفسجي البارد الجديد
const kPrimary = Color(0xFF7D29C6);
const kSecondary = Color(0xFF9232E8);
const kLavenderGrey = Color(0xFFB8B1C8);
const kBgCool = Color(0xFFF1F0F5);
const kTextColor = Color(0xFF2D2A3A);

class DashboardSearchBar extends StatefulWidget {
  final List<dynamic> stores;
  const DashboardSearchBar({super.key, required this.stores});
  @override
  State<DashboardSearchBar> createState() => _DashboardSearchBarState();
}

class _DashboardSearchBarState extends State<DashboardSearchBar>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _borderCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _borderAnim;

  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  bool _isFocused = false;
  bool _hasText = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _query = '';

  List<_ProductResult> _results = [];
  Timer? _debounce;
  List<Map<String, dynamic>> _allStores = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAllStores();

    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      _manageAnimations();
    });

    _textCtrl.addListener(() {
      final q = _textCtrl.text.trim();
      setState(() {
        _hasText = q.isNotEmpty;
        _query = q;
      });
      _manageAnimations();
      if (q.isEmpty) {
        setState(() { _results = []; _hasMore = true; });
        return;
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (q.isNotEmpty) _search(q, isNewSearch: true);
      });
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && _query.isNotEmpty) {
          _search(_query, isNewSearch: false);
        }
      }
    });
  }

  void _setupAnimations() {
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _borderCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _borderAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _borderCtrl, curve: Curves.linear));
  }

  void _manageAnimations() {
    if (_isFocused || _hasText) {
      if (!_borderCtrl.isAnimating) _borderCtrl.repeat();
    } else {
      _borderCtrl.stop();
      _borderCtrl.reset();
    }
  }

  Future<void> _search(String query, {required bool isNewSearch}) async {
  if (!mounted) return;

  if (isNewSearch) {
    setState(() {
      _isSearching = true;
      _results = [];
      _hasMore = true;
    });
  } else {
    setState(() => _isLoadingMore = true);
  }

  try {
    final q = query.toLowerCase().trim();
    final data = await ApiClient.getList('/api/products?search=$q');

    for (final d in data) {
    }

    // فلترة المنتجات حسب المحلات المرئية (distance)
    final locProv = LocationProvider();
    final storeList = _allStores.isNotEmpty ? _allStores : widget.stores.cast<Map<String, dynamic>>().toList();
    final visibleStoreIds = <String>{};
    for (final s in storeList) {
      final storeId = (s['_id'] ?? s['id'] ?? '') as String;
      if (storeId.isEmpty) continue;
      final showDistance = s['showDistance'] == true;
      final allowMultiple = s['allowMultipleCategories'] == true;
      final sLat = (s['lat'] as num?)?.toDouble() ?? 0;
      final sLng = (s['lng'] as num?)?.toDouble() ?? 0;
      if (!showDistance || allowMultiple) {
        visibleStoreIds.add(storeId);
        continue;
      }
      if (locProv.hasLocation && locProv.lat != null && locProv.lng != null) {
        final sLat = (s['lat'] as num?)?.toDouble() ?? 0;
        final sLng = (s['lng'] as num?)?.toDouble() ?? 0;
        if (sLat == 0 || sLng == 0) { visibleStoreIds.add(storeId); continue; }
        final dist = _calculateDistance(locProv.lat!, locProv.lng!, sLat, sLng);
        if (dist <= 35.0) visibleStoreIds.add(storeId);
      } else {
      }
    }

    final items = (data as List)
      .where((d) {
        final sid = d['storeId'] ?? '';
        if (sid.isEmpty) return true;
        if (storeList.isEmpty) return true;
        if (!visibleStoreIds.contains(sid)) {
          final inStores = storeList.any((s) => (s['_id'] ?? s['id'] ?? '') == sid);
          if (!inStores) return true;
          return false;
        }
        return true;
      })
      .map((d) {
        String sName = (d['storeName'] as String?)?.isNotEmpty == true ? d['storeName'] : '';
        if (sName.isEmpty) {
          final sid = d['storeId'] ?? '';
          if (sid.isNotEmpty) {
            final found = storeList.cast<Map<String, dynamic>>().firstWhere(
              (s) => (s['_id'] ?? s['id'] ?? '') == sid,
              orElse: () => <String, dynamic>{},
            );
            sName = (found['nom'] as String?) ?? (found['name'] as String?) ?? '';
          }
        }
        if (sName.isEmpty) sName = 'متجر';
        return _ProductResult(
      productId: d['_id'] ?? d['id'] ?? '',
      storeId: d['storeId'] ?? '',
      storeName: sName,
      categoryId: d['categorieId'] ?? '',
      categoryName: d['categorieNom'] ?? '',
      name: d['name'] ?? '',
      imagePath: d['image'] ?? '',
      price: (d['prix'] ?? d['price'] ?? 0).toDouble(),
      prixAffiche: d['prixAffiche'] ?? '${(d['prix']??0).toInt()} DA',
      capacite: d['capacite'] ?? '',
      description: d['description'] ?? '',
      uiStyle: (d['uiStyle'] as num?)?.toInt() ?? 1,
      models: d['models'] is List ? d['models'] : [],
      toppings: d['toppings'] is List ? d['toppings'] : [],
      sizes: d['sizes'] is List ? d['sizes'] : d['optionalSizes'] is List ? d['optionalSizes'] : [],
      extraImages: d['extraImages'] is List ? d['extraImages'] : [],
      variants: d['variants'] is List ? d['variants'] : [],
      hasPiecePrice: d['hasPiecePrice'] ?? false,
      pricePerPiece: (d['pricePerPiece'] ?? 0).toDouble(),
    );
  }).toList();

    if (mounted) {
      setState(() {
        if (isNewSearch) {
          _results = items;
        } else {
          _results.addAll(items);
        }
        _isSearching = false;
        _isLoadingMore = false;
        _hasMore = items.length >= 10;
      });
    }
  } catch (e) {
    if (mounted) setState(() { _isSearching = false; _isLoadingMore = false; });
  }
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = math.cos;
  var a = 0.5 - c((lat2 - lat1) * p) / 2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * math.asin(math.sqrt(a));
}


  @override
  void dispose() {
    _glowCtrl.dispose(); _borderCtrl.dispose(); _textCtrl.dispose(); _focusNode.dispose(); _scrollCtrl.dispose();
    _debounce?.cancel(); super.dispose();
  }

  Future<void> _loadAllStores() async {
    try {
      final stores = await ApiClient.getList('/api/stores');
      if (mounted) setState(() => _allStores = stores.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !(_isFocused || _hasText),
      onPopInvokedWithResult: (didPop, result) {
        if (_isFocused || _hasText) {
          _textCtrl.clear();
          _focusNode.unfocus();
          setState(() => _results = []);
        }
      },
      child: Column(
        children: [
          _buildSearchBarUI(),
          if (_hasText && (_results.isNotEmpty || _isSearching))
            _ResultsList(results: _results, query: _query, isLoading: _isSearching, isLoadingMore: _isLoadingMore, scrollController: _scrollCtrl, onAddToCart: _onAddToCart),
          if (_hasText && !_isSearching && _results.isEmpty && _query.length > 1)
            _EmptyResult(query: _query),
        ],
      ),
    );
  }

  Widget _buildSearchBarUI() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnim, _borderAnim]),
      builder: (context, child) {
        return SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. الإطار المتدرج الدوار (حين التركيز)
              if (_isFocused || _hasText)
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        kPrimary.withOpacity(0.6),
                        Colors.transparent,
                        kSecondary.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                      transform: GradientRotation(_borderAnim.value * 2 * math.pi),
                    ),
                  ),
                ),

              // 2. جسم السيرش بار (المتدرج واللامع)
              Container(
                margin: const EdgeInsets.all(3),
                height: 48,
                decoration: BoxDecoration(
                  // ✅ تدرج ألوان بارد بلمعة احترافية
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      const Color(0xFFF1F0F5),
                      const Color(0xFFE6E4F0), // لمعة خفيفة
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  // ✅ إطار خفيف ليعطي مظهر الزجاج
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFocused || _hasText)
                          ? kPrimary.withOpacity(0.3 * _glowAnim.value)
                          : kLavenderGrey.withOpacity(0.4),
                      blurRadius: (_isFocused || _hasText) ? 15 : 8,
                      offset: const Offset(3, 3),
                    ),
                     BoxShadow(
                      color: const Color(0xFFB8B1C8).withOpacity(0.6),
                      blurRadius: 8,
                      offset: Offset(-3, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    if (_isSearching)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                    else
                      Icon(
                        CupertinoIcons.search_circle_fill,
                        color: _isFocused ? kPrimary : kLavenderGrey,
                        size: 32,
                      ),

                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 14, color: kTextColor, fontWeight: FontWeight.bold, fontFamily: 'Amiri'),
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن منتج محدد...',
                          hintStyle: TextStyle(color: kLavenderGrey, fontSize: 13, fontWeight: FontWeight.normal, fontFamily: 'Amiri'),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),

                    if (_hasText)
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: kPrimary, size: 20),
                        onPressed: () {
                          _textCtrl.clear();
                          _focusNode.unfocus();
                          setState(() => _results = []);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onAddToCart(_ProductResult p) async {
    // load store-level data
    String templateName = '';
    String storeDisplayName = '';
    double? storeLat;
    double? storeLng;
    try {
      final store = await ApiClient.get('/api/stores/${p.storeId}');
      if (store is Map) {
        storeDisplayName = (store['nom'] as String?) ?? '';
        storeLat = (store['lat'] as num?)?.toDouble();
        storeLng = (store['lng'] as num?)?.toDouble();
        final templateId = store['templateId'] as String?;
        if (templateId != null && templateId.isNotEmpty) {
          final allStores = _allStores.isNotEmpty ? _allStores : widget.stores.cast<Map<String, dynamic>>().toList();
          final templateStore = allStores.cast<Map<String, dynamic>>().firstWhere(
            (s) => (s['_id'] ?? s['id'] ?? '') == templateId,
            orElse: () => <String, dynamic>{},
          );
          templateName = (templateStore['nom'] as String?) ?? '';
          if (templateName.isEmpty) {
            try {
              final temp = await ApiClient.get('/api/stores/$templateId');
              if (temp is Map) templateName = (temp['nom'] as String?) ?? '';
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    if (templateName.isEmpty) templateName = storeDisplayName;
    if (storeDisplayName.isEmpty) storeDisplayName = p.storeName;
    if (storeDisplayName.isEmpty) storeDisplayName = 'متجر';
    if (p.categoryName.isNotEmpty) storeDisplayName = p.categoryName;

    final product = Product(
      productId: p.productId,
      name: p.name,
      price: p.price,
      imagePath: p.imagePath,
      capacite: p.capacite,
      description: p.description,
      priceAffiche: p.prixAffiche,
      storeId: p.storeId,
      storeName: storeDisplayName,
      templateName: templateName,
      storeLat: (storeLat != null && storeLat != 0) ? storeLat : null,
      storeLng: (storeLng != null && storeLng != 0) ? storeLng : null,
      categoryName: p.categoryName.isNotEmpty ? p.categoryName : p.categoryId,
      uiStyle: p.uiStyle,
      models: p.models,
      toppings: p.toppings,
      sizes: p.sizes,
      extraImages: p.extraImages,
      variants: p.variants,
      hasPiecePrice: p.hasPiecePrice,
      pricePerPiece: p.pricePerPiece,
    );
    if (!mounted) return;

    if (!mounted) return;
    if (p.uiStyle == 2) {
      List<DrinkItem> drinks = DrinkCache.get(p.storeId) ?? [];
      if (drinks.isEmpty) {
        try {
          final data = await ApiClient.getList('/api/drinks?storeId=${p.storeId}');
          drinks = data.map((d) => DrinkItem.fromMap(d as Map<String, dynamic>)).toList();
          DrinkCache.set(p.storeId, drinks);
        } catch (_) {}
      }
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (_) => PizzaDetailSheet(
          product: product,
          storeId: p.storeId,
          drinks: drinks,
          storeColor: kPrimary,
          onAddToCart: (cartProduct) {
            if (!GlobalCart.safeToggle(cartProduct, context)) return;
            GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
          },
        ),
      );
      return;
    }

    if (p.uiStyle == 3) {
      List<DrinkItem> drinks = DrinkCache.get(p.storeId) ?? [];
      if (drinks.isEmpty) {
        try {
          final data = await ApiClient.getList('/api/drinks?storeId=${p.storeId}');
          drinks = data.map((d) => DrinkItem.fromMap(d as Map<String, dynamic>)).toList();
          DrinkCache.set(p.storeId, drinks);
        } catch (_) {}
      }
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ProductDetailSheet(
          product: product,
          drinks: drinks,
          isInCart: GlobalCart.provider.containsProduct(product.productId),
          onAddToCart: () {
            if (!GlobalCart.safeToggle(product, context)) return;
            GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
          },
        ),
      );
      return;
    }

    if (p.uiStyle == 4) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style4DetailSheet(product: product),
      );
      return;
    }

    if (p.uiStyle == 5) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style5DetailSheet(product: product),
      );
      return;
    }

    if (p.uiStyle == 6) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style6DetailSheet(product: product),
      );
      return;
    }

    if (p.uiStyle == 7) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style7DetailSheet(product: product),
      );
      return;
    }

    if (p.uiStyle == 8) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Style8DetailSheet(product: product),
      );
      return;
    }

    if (product.models.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => ProductVariantsDialog(
          product: product,
          onAction: (variantProduct) {
            GlobalCart.provider.toggle(variantProduct);
            GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت الإضافة: ${variantProduct.displayName}', style: const TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: const Color(0xFF27AE60),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      );
      return;
    }

    GlobalCart.provider.toggle(product);
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
  }
}

// ✅ تعديل قائمة النتائج لتتناسب مع الخلفية الجديدة
class _ResultsList extends StatelessWidget {
  final List<_ProductResult> results;
  final String query;
  final bool isLoading;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final Function(_ProductResult) onAddToCart;

  const _ResultsList({required this.results, required this.query, required this.isLoading, required this.isLoadingMore, required this.scrollController, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0F5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), offset: const Offset(0, 8)),
        ],
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.6), width: 1),
      ),
      child: isLoading
          ? const Padding(padding: EdgeInsets.all(30), child: CupertinoActivityIndicator(color: kPrimary))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: results.length,
                    itemBuilder: (context, index) => _ProductTile(product: results[index], query: query, onAddToCart: onAddToCart),
                  ),
                ),
                if (isLoadingMore)
                  const Padding(padding: EdgeInsets.all(12), child: CupertinoActivityIndicator(radius: 8, color: kPrimary)),
              ],
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final _ProductResult product;
  final String query;
  final Function(_ProductResult) onAddToCart;

  const _ProductTile({required this.product, required this.query, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: () => onAddToCart(product),
        leading: Container(
          decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.add_shopping_cart, color: kPrimary, size: 18), onPressed: () => onAddToCart(product)),
        ),
        title: Text(product.name, textAlign: TextAlign.right, textDirection: getTextDirection(product.name), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextColor, fontFamily: 'Amiri')),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (product.models.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('موديلات', style: TextStyle(fontSize: 9, color: kPrimary, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
              ),
            Text("${product.price.toInt()} DZD - ${product.categoryName.isNotEmpty ? product.categoryName : product.storeName}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: kLavenderGrey, fontFamily: 'Amiri')),
          ],
        ),
        trailing: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: const Color(0xFFB8B1C8).withOpacity(0.6), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 5)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.imagePath.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imagePath,
                    fit: BoxFit.cover,
                    memCacheWidth: 100,
                    memCacheHeight: 100,
                    placeholder: (_, __) => Container(color: const Color(0xFFB8B1C8).withOpacity(0.6)),
                    errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag, size: 20, color: kLavenderGrey),
                  )
                : const Icon(Icons.shopping_bag, size: 20, color: kLavenderGrey),
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final String query;
  const _EmptyResult({required this.query});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text('لا توجد نتائج لـ "$query"', style: const TextStyle(color: kLavenderGrey, fontFamily: 'Amiri', fontSize: 13)),
    );
  }
}

class _ProductResult {
  final String productId, storeId, storeName, categoryId, categoryName;
  final String name, imagePath, prixAffiche, capacite, description;
  final double price;
  final int uiStyle;
  final List<dynamic> models, toppings, sizes, extraImages, variants;
  final bool hasPiecePrice;
  final double pricePerPiece;
  const _ProductResult({
    required this.productId, required this.storeId, required this.storeName,
    required this.categoryId, this.categoryName = '',
    required this.name, required this.imagePath, required this.price,
    required this.prixAffiche, required this.capacite, this.description = '',
    this.uiStyle = 1,
    this.models = const [], this.toppings = const [],
    this.sizes = const [], this.extraImages = const [], this.variants = const [],
    this.hasPiecePrice = false, this.pricePerPiece = 0,
  });
}