// ══════════════════════════════════════════════════════════════════════════════
//  products_list_screen.dart
//  UIStyle 1 → عرض عادي (3 في السطر)
//  UIStyle 2 → عرض بيتزا (2 في السطر) + PizzaDetailSheet + PizzaBoxAnimation
//  UIStyle 3 → عرض باتيسري (2 في السطر) + ProductDetailSheet
//  UIStyle 4 → خضر وفواكه (2 في السطر) + وزن/مبلغ Sheet
//  UIStyle 5 → كوسميتيك (2 في السطر) + تفاصيل Sheet
//  UIStyle 6 → مشاريع حسب الطلب (2 في السطر) + معرض صور Sheet
//  UIStyle 7 → فارماسي متعدد الأحجام (2 في السطر) + أحجام Sheet
//  UIStyle 8 → منتجات صور + سعر أساسي + أحجام اختيارية (2 في السطر) + تفاصيل Sheet
// ══════════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:add_to_cart_animation/add_to_cart_animation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/ModelSelectionDialog.dart';
import 'package:flutter_application_1/Services/delivery_screen.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/app_cached_image.dart';
import 'cardd.dart';
import 'product_detail_sheet.dart';
import 'user_local.dart';
import 'main_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Design Tokens
// ══════════════════════════════════════════════════════════════════════════════
const Color kPrimary = Color(0xFF7D29C6);
const Color kBg = Color(0xFFF1F0F5); // لون الداشبورد
const Color kCardColor = Color(0xFFDCDAE6); // لون ستوري فيو
const Color kSuccess = Color(0xFF27AE60); // الأخضر لعلامة الصح والتحديد الناجح
final Color kNeumShadow = const Color(0xFFB8B1C8).withOpacity(0.6);

// ══════════════════════════════════════════════════════════════════════════════
//  Domain Models
// ══════════════════════════════════════════════════════════════════════════════
class Product {
  final String imagePath, name, capacite, priceAffiche, description, productId, storeId, storeName, templateName, categoryName, categoryId;
  final double price;
  final double? storeLat;
  final double? storeLng;
    final bool hasPiecePrice; // جديد
  final double pricePerPiece; // جديد
  final int order;
  int quantity;
  final List<dynamic> models;
  String? selectedModelName;
  final List<dynamic> toppings;
  final int uiStyle;
  final List<dynamic> sizes;
  final List<dynamic> extraImages;
  final List<dynamic> variants;
  String note;

  String get displayName => selectedModelName != null ? "$name $selectedModelName" : name;

  Product({
    required this.imagePath,
    required this.name,
    required this.price,
        this.hasPiecePrice = false,
    this.pricePerPiece = 0,
    this.capacite = '',
    this.priceAffiche = '',
    this.description = '',
    this.productId = '',
    this.order = 0,
    this.quantity = 1,
    this.models = const [],
    this.selectedModelName,
    this.toppings = const [],
    this.storeId = '',
    this.storeLat,
    this.storeLng,
    this.templateName = '',
    this.categoryName = '',
    this.categoryId = '',
    this.storeName = '',
    this.uiStyle = 1,
    this.sizes = const [],
    this.extraImages = const [],
    this.variants = const [],
    this.note = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          productId == other.productId &&
          selectedModelName == other.selectedModelName);

  @override
  int get hashCode => productId.hashCode ^ (selectedModelName ?? '').hashCode;

  Product copyWith({String? selectedModelName, int? quantity, String? imagePath, String? note}) => Product(
    productId: productId,
    imagePath: imagePath ?? this.imagePath,
    name: name,
    price: price,
    order: order,
    capacite: capacite,
    priceAffiche: priceAffiche,
    description: description,
    models: models,
    quantity: quantity ?? this.quantity,
    selectedModelName: selectedModelName ?? this.selectedModelName,
    toppings: toppings,
    storeId: storeId,
    storeName: storeName,
    templateName: templateName,
    storeLat: storeLat,
    storeLng: storeLng,
    hasPiecePrice: hasPiecePrice,
    pricePerPiece: pricePerPiece,
    uiStyle: uiStyle,
    sizes: sizes,
    extraImages: extraImages,
    variants: variants,
    note: note ?? this.note,
    categoryName: categoryName,
    categoryId: categoryId,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ PizzaTopping — النكهة تحمل قائمة الأحجام الخاصة بها
// ══════════════════════════════════════════════════════════════════════════════
class PizzaSize {
  final String label;
  final double price;
  final String image;
  const PizzaSize({required this.label, required this.price, required this.image});
  factory PizzaSize.fromMap(Map<String, dynamic> m) => PizzaSize(
    label: m['label'] as String? ?? '',
    price: (m['price'] as num? ?? 0).toDouble(),
    image: m['image'] as String? ?? '',
  );
}

class PizzaTopping {
  final String label;
  final String image;
  final List<PizzaSize> sizes;
  const PizzaTopping({required this.label, required this.image, this.sizes = const []});
  factory PizzaTopping.fromMap(Map<String, dynamic> m) {
    final rawSizes = m['sizes'] as List<dynamic>? ?? [];
    final sizes = rawSizes.map((e) => PizzaSize.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    return PizzaTopping(label: m['label'] as String? ?? '', image: m['image'] as String? ?? '', sizes: sizes);
  }
}

class DrinkSize {
  final String label;
  final double price;
  DrinkSize({required this.label, required this.price});
}

class DrinkFlavor {
  final String label, image;
  final List<DrinkSize> sizes;
  DrinkFlavor({required this.label, required this.image, required this.sizes});
}

class DrinkItem {
  final String id, name;
  final List<DrinkFlavor> flavors;
  DrinkItem({required this.id, required this.name, required this.flavors});

  factory DrinkItem.fromMap(Map<String, dynamic> d) {
    final List rawFlavors = d['flavors'] ?? [];
    final flavors = rawFlavors.map((f) {
      final List rawSizes = f['sizes'] ?? [];
      final sizes = rawSizes.map((s) => DrinkSize(label: s['label'] ?? '', price: (s['price'] as num? ?? 0).toDouble())).toList();
      return DrinkFlavor(label: f['label'] ?? '', image: f['image'] ?? '', sizes: sizes);
    }).toList();
    return DrinkItem(id: d['_id'] ?? d['id'] ?? '', name: d['name'] ?? '', flavors: flavors);
  }

  double get price => flavors.isNotEmpty && flavors[0].sizes.isNotEmpty ? flavors[0].sizes[0].price : 0.0;
  String get image => flavors.isNotEmpty ? flavors[0].image : '';
}

// ══════════════════════════════════════════════════════════════════════════════
//  CartProvider + GlobalCart
// ══════════════════════════════════════════════════════════════════════════════
class CartProvider extends ChangeNotifier {
  final List<Product> _items = [];
  final Set<String> _itemKeys = {};
  String? lastError;

  List<Product> get items => List.unmodifiable(_items);

  bool containsVariant(String productId, String? modelName) =>
      _itemKeys.contains('${productId}_${modelName ?? ""}');

  bool containsProduct(String productId) => _items.any((item) => item.productId == productId);

  void _syncBadge() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalCart.cartKey.currentState?.runCartAnimation(count.toString());
    });
  }

  /// Returns true if the product was added, false if rejected due to style conflict.
  bool toggle(Product product) {
    final String key = '${product.productId}_${product.selectedModelName ?? ""}';
    final index = _items.indexWhere((item) => item.productId == product.productId && item.selectedModelName == product.selectedModelName);
    if (index == -1) {
      if (_items.isNotEmpty) {
        final existingStyle = _items.first.uiStyle;
        final newStyle = product.uiStyle;
        if ((newStyle == 6 || newStyle == 7) && existingStyle != newStyle) {
          lastError = 'عذراً، هذا النوع من المنتجات لا يمكن إضافته مع منتجات أخرى في السلة. يرجى تفريغ السلة أولاً.';
          return false;
        }
        if ((existingStyle == 6 || existingStyle == 7) && existingStyle != newStyle) {
          lastError = 'عذراً، هذا النوع من المنتجات لا يمكن إضافته مع منتجات أخرى في السلة. يرجى تفريغ السلة أولاً.';
          return false;
        }
      }
      _items.add(product);
      _itemKeys.add(key);
    } else {
      _items.removeAt(index);
      _itemKeys.remove(key);
      HapticFeedback.mediumImpact();
    }
    notifyListeners();
    _syncBadge();
    return true;
  }

  void clear() {
    _items.clear();
    _itemKeys.clear();
    notifyListeners();
    _syncBadge();
  }

  void updateQuantity(Product product, int newQuantity) {
    final index = _items.indexWhere((item) => item.productId == product.productId && item.selectedModelName == product.selectedModelName);
    if (index != -1) {
      _items[index].quantity = newQuantity;
      notifyListeners();
    }
  }

  void updateNote(Product product, String note) {
    final index = _items.indexWhere((item) => item.productId == product.productId && item.selectedModelName == product.selectedModelName);
    if (index != -1) {
      _items[index].note = note;
      notifyListeners();
    }
  }

  double get total => _items.fold(0.0, (sum, p) => sum + p.price * p.quantity);
  int get count => _items.length;
}

class GlobalCart {
  static final CartProvider provider = CartProvider();
  static final GlobalKey<CartIconKey> cartKey = GlobalKey<CartIconKey>();
  static List<Product> get items => provider.items.toList();

  /// Returns true if the product was successfully toggled.
  /// If the cart has a mix of style-7 and other styles, shows a snackbar and returns false.
  static bool safeToggle(Product product, BuildContext context) {
    if (!provider.toggle(product)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('عذراً، هذا النوع من المنتجات لا يمكن إضافته مع منتجات أخرى في السلة. يرجى تفريغ السلة أولاً.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return false;
    }
    return true;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Cache Layer
// ══════════════════════════════════════════════════════════════════════════════
class _CacheEntry {
  final List<Product> data;
  final DateTime time;
  _CacheEntry(this.data) : time = DateTime.now();
  bool get isValid => DateTime.now().difference(time).inMinutes < 10;
}

class _ProdCache {
  static final Map<String, _CacheEntry> _store = {};
  static const int _maxEntries = 100;
  static const int pageSize = 10;
  static String _key(String s, String c) => '${s}_$c';
  static List<Product>? get(String s, String c) {
    final entry = _store[_key(s, c)];
    if (entry == null || !entry.isValid) return null;
    return entry.data;
  }
  static void set(String s, String c, List<Product> p) {
    if (_store.length >= _maxEntries) {
      _store.remove(_store.keys.first);
    }
    _store.removeWhere((_, e) => !e.isValid);
    _store[_key(s, c)] = _CacheEntry(p);
  }
  static bool has(String s, String c) {
    final entry = _store[_key(s, c)];
    return entry != null && entry.isValid;
  }
}

class DrinkCacheEntry {
  final List<DrinkItem> data;
  final DateTime time;
  DrinkCacheEntry(this.data) : time = DateTime.now();
  bool get isValid => DateTime.now().difference(time).inMinutes < 10;
}

class DrinkCache {
  static final Map<String, DrinkCacheEntry> _store = {};
  static const int _maxEntries = 30;
  static List<DrinkItem>? get(String storeId) {
    final entry = _store[storeId];
    if (entry == null || !entry.isValid) {
      _store.remove(storeId);
      return null;
    }
    return entry.data;
  }
  static void set(String storeId, List<DrinkItem> drinks) {
    if (_store.length >= _maxEntries) {
      _store.remove(_store.keys.first);
    }
    _store[storeId] = DrinkCacheEntry(drinks);
  }
  static bool has(String storeId) {
    final entry = _store[storeId];
    return entry != null && entry.isValid;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ProductsListScreen
// ══════════════════════════════════════════════════════════════════════════════
class ProductsListScreen extends StatefulWidget {
  final String categoryName, categoryId, storeId, storeName, categoryImagePath, heroTag;
  final int uiStyle;
  final Color storeColor;
   final double? storeLat; 
  final double? storeLng;
  final String templateName;
  final String openTime;
  final String closeTime;

  const ProductsListScreen({
    super.key,
    required this.categoryName,
    required this.storeName,
    required this.categoryImagePath,
    required this.heroTag,
    required this.storeId,
    required this.categoryId,
    this.uiStyle = 1,
    this.storeLat, 
    this.storeLng,
    this.templateName = '',
    this.openTime = '',
    this.closeTime = '',
    required Color storeColor,
  }) : storeColor = storeColor;

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

// ══════════════════════════════════════════════════════════════════════════════
//  Sort Enum
// ══════════════════════════════════════════════════════════════════════════════
enum _SortMode { none, priceAsc, priceDesc }

class _ProductsListScreenState extends State<ProductsListScreen>
    with SingleTickerProviderStateMixin {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<DrinkItem> _drinks = [];

  bool _isLoading = true;
  bool _loadingMore = false;
  Map<String, dynamic>? _lastDoc;
  bool _hasMore = true;

  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearchMode = false;
  bool _isSearching = false;
  Timer? _searchDebounce;

  double _minPrice = 0, _maxPrice = 10000, _absoluteMax = 10000;
  late Function(GlobalKey) runAddToCartAnimation;
  final Set<String> _animatingIds = {};

  late final AnimationController _pageAnimController;
  late final Animation<double> _fadePage;

  _SortMode _sortMode = _SortMode.none;
  List<Map<String, dynamic>> _favorites = [];
  String? _selectedFavoriteId;
  bool _isOpenNow() {
    try {
      final now = TimeOfDay.now();
      final current = now.hour * 60 + now.minute;
      final openParts = widget.openTime.split(':');
      final closeParts = widget.closeTime.split(':');
      if (openParts.length < 2 || closeParts.length < 2) return true;
      final open = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final close = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
      if (close > open) {
        return current >= open && current <= close;
      } else {
        return current >= open || current <= close;
      }
    } catch (_) {
      return true;
    }
  }
  bool _loadingFavorites = true;
  bool _twoColumnView = false;

  bool get _showCartBar => GlobalCart.provider.count > 0;
  bool get _isPizzaStyle => widget.uiStyle == 2;
  bool get _isPatisserieStyle => widget.uiStyle == 3;
  bool get _isStyle4 => widget.uiStyle == 4;
  bool get _isStyle5 => widget.uiStyle == 5;
  bool get _isStyle6 => widget.uiStyle == 6;
  bool get _isStyle7 => widget.uiStyle == 7;
  bool get _isLargeCardStyle => widget.uiStyle >= 2;

  Color get _color => widget.storeColor;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadePage = CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut);

    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearch);
    _fetchFirstPage();

    // ✅ جلب المشروبات للستايلات 2 و 3
    if (_isPizzaStyle || _isPatisserieStyle) _fetchDrinks();

    _fetchFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    });
  }

  Future<void> _fetchFirstPage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_ProdCache.has(widget.storeId, widget.categoryId)) {
      final cached = _ProdCache.get(widget.storeId, widget.categoryId)!;
      if (mounted) {
        setState(() {
          _allProducts = List.from(cached);
          _computeMaxPrice();
          _applyLocalFilter();
          _isLoading = false;
        });
        _pageAnimController.forward();
      }
      _revalidateCache();
      return;
    }

    await _fetchFromServer();
  }

  Future<void> _revalidateCache() async {
    try {
      final data = await ApiClient.getList('/api/products?storeId=${widget.storeId}&categorieId=${widget.categoryId}&limit=${_ProdCache.pageSize}');
      if (!mounted || data.isEmpty) return;
      if (data.isNotEmpty) _lastDoc = data.last as Map<String, dynamic>;
      _hasMore = data.length == _ProdCache.pageSize;
      final fresh = _toProducts(data.cast<Map<String, dynamic>>());
      if (_dataChanged(_allProducts, fresh)) {
        _ProdCache.set(widget.storeId, widget.categoryId, fresh);
        if (mounted) {
          setState(() {
            _allProducts = fresh;
            _computeMaxPrice();
            _applyLocalFilter();
          });
        }
        precacheImages(
          fresh.map((p) => p.imagePath).where((i) => i.isNotEmpty).toList(),
        );
      }
    } catch (_) {}
  }

  bool _dataChanged(List<Product> oldList, List<Product> newList) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].productId != newList[i].productId ||
          oldList[i].name != newList[i].name ||
          oldList[i].price != newList[i].price ||
          oldList[i].imagePath != newList[i].imagePath) return true;
    }
    return false;
  }

  Future<void> _fetchFromServer({bool isInitial = true}) async {
    try {
      final data = await ApiClient.getList('/api/products?storeId=${widget.storeId}&categorieId=${widget.categoryId}&limit=${_ProdCache.pageSize}');

      if (data.isNotEmpty) _lastDoc = data.last as Map<String, dynamic>;
      _hasMore = data.length == _ProdCache.pageSize;
      final products = _toProducts(data.cast<Map<String, dynamic>>());
      _ProdCache.set(widget.storeId, widget.categoryId, products);

      if (mounted) {
        setState(() {
          _allProducts = products;
          _computeMaxPrice();
          _applyLocalFilter();
          _isLoading = false;
        });
        _pageAnimController.forward();
      }
      precacheImages(
        products.map((p) => p.imagePath).where((i) => i.isNotEmpty).toList(),
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null || _isSearchMode) return;
    setState(() => _loadingMore = true);
    try {
      final lastId = _lastDoc!['_id'] ?? _lastDoc!['id'] ?? '';
      final data = await ApiClient.getList('/api/products?storeId=${widget.storeId}&categorieId=${widget.categoryId}&lastId=$lastId&limit=${_ProdCache.pageSize}');

      if (data.isNotEmpty) _lastDoc = data.last as Map<String, dynamic>;
      _hasMore = data.length == _ProdCache.pageSize;
      final newProds = _toProducts(data.cast<Map<String, dynamic>>());
      final all = [..._allProducts, ...newProds];
      _ProdCache.set(widget.storeId, widget.categoryId, all);

      if (mounted) {
        setState(() {
          _allProducts = all;
          _computeMaxPrice();
          _applyLocalFilter();
          _loadingMore = false;
        });
      }
      precacheImages(
        newProds.map((p) => p.imagePath).where((i) => i.isNotEmpty).toList(),
      );
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ✅ تصليح: جلب المشروبات مع التخزين المؤقت
  Future<void> _fetchDrinks() async {
    if (DrinkCache.has(widget.storeId)) {
      if (mounted) setState(() => _drinks = DrinkCache.get(widget.storeId)!);
      return;
    }
    try {
      final drinksData = await ApiClient.getList('/api/drinks?storeId=${widget.storeId}');
      final drinks = drinksData.map((d) => DrinkItem.fromMap(d as Map<String, dynamic>)).toList();
      DrinkCache.set(widget.storeId, drinks);
      if (mounted) setState(() => _drinks = drinks);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  List<Product> _toProducts(List<Map<String, dynamic>> docs) =>
      docs.map((d) {
        final num rawPrice = (d['prix'] ?? d['price'] ?? 0) as num;
        return Product(
          productId: d['_id'] ?? d['id'] ?? '',
          imagePath: d['image'] ?? '',
          name: d['name'] ?? '',
          price: rawPrice.toDouble(),
          order: (d['order'] as num?)?.toInt() ?? 0,
          capacite: d['capacite'] ?? '',
          priceAffiche: '${rawPrice.toInt()} Da',
          description: d['description'] ?? '',
          models: d['models'] ?? [],
          toppings: d['toppings'] ?? [],
          storeId: widget.storeId,
          storeName: widget.storeName, // هذا سيضمن أخذ الاسم الصحيح للمحل دائماً
          templateName: widget.templateName,
          categoryName: widget.categoryName,
          storeLat: widget.storeLat,
          storeLng: widget.storeLng,
          uiStyle: widget.uiStyle,
          sizes: d['sizes'] ?? d['optionalSizes'] ?? [],
          extraImages: d['extraImages'] ?? [],
          variants: d['variants'] ?? [],
          hasPiecePrice: d['hasPiecePrice'] ?? false,
pricePerPiece: (d['pricePerPiece'] ?? 0).toDouble(),
        );
      }).toList();

  void _computeMaxPrice() {
    _absoluteMax = _allProducts.isEmpty ? 10000 : _allProducts.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    if (_maxPrice > _absoluteMax) _maxPrice = _absoluteMax;
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() => _searchQuery = q);
    if (q.isEmpty) {
      _searchDebounce?.cancel();
      setState(() {
        _isSearchMode = false;
        _isSearching = false;
        _applyLocalFilter();
      });
      return;
    }
    setState(() => _isSearchMode = true);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _searchFirestore(q));
  }

  Future<void> _searchFirestore(String q) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final tagData = await ApiClient.getList('/api/products?storeId=${widget.storeId}&categorieId=${widget.categoryId}&searchTags=$q&limit=20');

      final nameData = await ApiClient.getList('/api/products?storeId=${widget.storeId}&categorieId=${widget.categoryId}&name=$q&limit=20');

      final Map<String, Product> merged = {};
      for (final doc in [...tagData, ...nameData]) {
        final m = doc as Map<String, dynamic>;
        merged[m['_id'] ?? m['id'] ?? ''] = _toProducts([m]).first;
      }
      if (mounted) {
        setState(() {
          List<Product> results = merged.values.where((p) => p.price >= _minPrice && p.price <= _maxPrice).toList();
          if (_selectedFavoriteId != null) {
            final fav = _favorites.firstWhere((f) => f['id'] == _selectedFavoriteId, orElse: () => {});
            final ids = fav.isEmpty ? <dynamic>[] : (fav['productIds'] as List<dynamic>? ?? []);
            results = results.where((p) => ids.contains(p.productId)).toList();
          }
          if (_sortMode == _SortMode.priceAsc) {
            results.sort((a, b) => a.price.compareTo(b.price));
          } else if (_sortMode == _SortMode.priceDesc) {
            results.sort((a, b) => b.price.compareTo(a.price));
          } else {
            results.sort((a, b) => a.order.compareTo(b.order));
          }
          _filteredProducts = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _applyLocalFilter() {
    List<Product> result = _allProducts.where((p) => p.price >= _minPrice && p.price <= _maxPrice).toList();
    if (_selectedFavoriteId != null) {
      final fav = _favorites.firstWhere((f) => f['id'] == _selectedFavoriteId, orElse: () => {});
      final ids = fav.isEmpty ? <dynamic>[] : (fav['productIds'] as List<dynamic>? ?? []);
      result = result.where((p) => ids.contains(p.productId)).toList();
    }
    if (_sortMode == _SortMode.priceAsc) {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortMode == _SortMode.priceDesc) {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else {
      result.sort((a, b) => a.order.compareTo(b.order));
    }
    _filteredProducts = result;
  }

  Future<void> _fetchFavorites() async {
    try {
      final data = await ApiClient.getList('/api/favorites?storeId=${widget.storeId}');
      if (mounted) {
        setState(() {
          _favorites = data.map((d) {
            final m = d as Map<String, dynamic>;
            return {'id': m['_id'] ?? m['id'] ?? '', 'name': m['name'] ?? '', 'productIds': m['productIds'] ?? []};
          }).toList();
          _loadingFavorites = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFavorites = false);
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color.fromARGB(255, 119, 118, 118), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            const Text('ترتيب حسب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.black87)),
            const SizedBox(height: 16),
            _sortTile('الافتراضي', CupertinoIcons.list_bullet, _SortMode.none),
            const SizedBox(height: 10),
            _sortTile('أقل سعر', CupertinoIcons.arrow_down, _SortMode.priceAsc),
            const SizedBox(height: 10),
            _sortTile('أكبر سعر', CupertinoIcons.arrow_up, _SortMode.priceDesc),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(String label, IconData icon, _SortMode mode) {
    final bool sel = _sortMode == mode;
    final Color c = _color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortMode = mode;
          _applyLocalFilter();
        });
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFB8B1C8).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6), width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6), size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: Colors.black87, fontFamily: 'Amiri')),
            const Spacer(),
            if (sel) Icon(CupertinoIcons.checkmark_alt, color: c, size: 16),
          ],
        ),
      ),
    );
  }

  // ✅ التحقق من توافق السلة مع الـ uiStyle الحالي
  bool _cartCompatibleWithCurrentStyle() {
    bool hasStyle6 = GlobalCart.provider.items.any((p) => p.uiStyle == 6);
    bool hasStyle7 = GlobalCart.provider.items.any((p) => p.uiStyle == 7);
    bool hasOther = GlobalCart.provider.items.any((p) => p.uiStyle != 6 && p.uiStyle != 7);

    // ستايل 7 — لازم يكون وحده في السلة
    if (widget.uiStyle == 7 && GlobalCart.provider.count > 0) {
      if (hasStyle6 || hasOther) {
        _showCartIncompatibleDialog('مشروع حسب الطلب',
            'منتجات المشاريع (حسب الطلب) يجب أن تكون وحدها في السلة.\n'
            'يرجى إفراغ السلة أولاً أو إكمال طلبك الحالي.');
        return false;
      }
    }

    // ستايل 6 — لازم يكون وحده في السلة
    if (widget.uiStyle == 6 && GlobalCart.provider.count > 0 && !hasStyle6) {
      _showCartIncompatibleDialog('مشروع حسب الطلب',
          'منتجات المشاريع (حسب الطلب) يجب أن تكون وحدها في السلة.\n'
          'يرجى إفراغ السلة أولاً أو إكمال طلبك الحالي.');
      return false;
    }

    // يوجد ستايل 6 أو 7 في السلة ونحاول نضيف منتج عادي
    if (widget.uiStyle != 6 && widget.uiStyle != 7 && (hasStyle6 || hasStyle7)) {
      _showCartIncompatibleDialog('منتجات عادية',
          'لا يمكن إضافة هذا المنتج مع منتجات المشاريع (حسب الطلب) في نفس السلة.\n'
          'يرجى إفراغ السلة أو إكمال طلب المشاريع أولاً.');
      return false;
    }

    // نحاول نضيف ستايل 7 وفيه ستايل 7 غادي
    if (widget.uiStyle == 7 && hasStyle7) return true;

    return true;
  }

  void _showCartIncompatibleDialog(String type, String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('تعذر الإضافة',
            style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسناً',
                style: TextStyle(fontFamily: 'Amiri', color: Color(0xFF7D29C6))),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCartAction(Product product, GlobalKey imageKey) async {
    if (_animatingIds.contains(product.productId)) return;

    if (!_cartCompatibleWithCurrentStyle()) return;

    if (widget.uiStyle == 2) {
      _openPizzaDetailWithAnimation(product);
      return;
    }

    if (widget.uiStyle == 3) {
      _openPatisserieDetailSheet(product);
      return;
    }

    if (widget.uiStyle == 4) {
      _openStyle4Sheet(product);
      return;
    }

    if (widget.uiStyle == 5) {
      _openStyle5Sheet(product);
      return;
    }

    if (widget.uiStyle == 6) {
      _openStyle6Sheet(product);
      return;
    }

    if (widget.uiStyle == 7) {
      _openStyle7Sheet(product);
      return;
    }

    if (widget.uiStyle == 8) {
      _openStyle8Sheet(product);
      return;
    }

    if (product.models.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => ProductVariantsDialog(
          product: product,
          onAction: (variantProduct) => _processToggleCart(variantProduct, imageKey),
        ),
      );
    } else {
      await _processToggleCart(product, imageKey);
    }
  }

  Future<void> _processToggleCart(Product product, GlobalKey imageKey) async {
    final bool isAlreadyInCart = GlobalCart.provider.containsVariant(product.productId, product.selectedModelName);
    if (!isAlreadyInCart) {
      if (!GlobalCart.safeToggle(product, context)) return;
    } else {
      GlobalCart.provider.toggle(product);
    }
    if (mounted) setState(() {});
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    if (!isAlreadyInCart && imageKey.currentContext != null) {
      try {
        await runAddToCartAnimation(imageKey);
      } catch (e) {
      }
    }
  }

  // ✅ تصليح: فتح شيت الباتيسري مع تمرير المشروبات بشكل صحيح
  void _openPatisserieDetailSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(
        product: product,
        drinks: _drinks, // ✅ تمرير المشروبات المحملة
        isInCart: GlobalCart.provider.containsProduct(product.productId),
        onAddToCart: () {
          if (!GlobalCart.safeToggle(product, context)) return;
          GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
          setState(() {});
        },
      ),
    );
  }

  void _openPizzaDetailWithAnimation(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => _PizzaProductAnimationEntry(
        product: product,
        child: PizzaDetailSheet(
          product: product,
          storeId: widget.storeId,
          drinks: _drinks,
          storeColor: _color,
          onAddToCart: (cartProduct) {
            if (!GlobalCart.safeToggle(cartProduct, context)) return;
            GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // ═══ فتح شيت ستايل 4 (خضر وفواكه) ═══════════════════════════════════
  void _openStyle4Sheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Style4DetailSheet(product: product),
    );
  }

  // ═══ فتح شيت ستايل 5 (كوسميتيك) ═════════════════════════════════════
  void _openStyle5Sheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Style5DetailSheet(product: product),
    );
  }

  // ═══ فتح نموذج طلب مشروع حسب الطلب ═══════════════════════════════════
  void _openCustomProjectSheet() {
    _requireAuth(() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CustomProjectSheet(
          storeId: widget.storeId,
          storeName: widget.storeName,
          storeLat: widget.storeLat,
          storeLng: widget.storeLng,
        ),
      );
    });
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

  // ═══ فتح شيت ستايل 6 (مشاريع) ═══════════════════════════════════════
  void _openStyle6Sheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Style6DetailSheet(product: product),
    );
  }

  // ═══ فتح شيت ستايل 7 (فارماسي) ══════════════════════════════════════
  void _openStyle7Sheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Style7DetailSheet(product: product),
    );
  }

  // ═══ فتح شيت ستايل 8 (منتجات صور) ═══════════════════════════════════
  void _openStyle8Sheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Style8DetailSheet(product: product),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pageAnimController.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AddToCartAnimation(
      cartKey: GlobalCart.cartKey,
      height: 30,
      width: 30,
      opacity: 0.85,
      dragAnimation: const DragToCartAnimationOptions(rotation: false, duration: Duration(milliseconds: 200)),
      jumpAnimation: const JumpAnimationOptions(duration: Duration(milliseconds: 150)),
      createAddToCartAnimation: (fn) => runAddToCartAnimation = fn,
      child: Scaffold(
        backgroundColor: kBg,
        body: FadeTransition(
          opacity: _fadePage,
          child: Stack(
            children: [
              statusBarGradient(context),
              CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(context),
                  if (_isLoading)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator(color: kPrimary)))
                  else if (_isSearching)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))
                  else ...[
                    _isLargeCardStyle ? _buildPizzaGrid() : _buildNormalGrid(),
                    if (_loadingMore && !_isSearchMode)
                      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ],
              ),
              ListenableBuilder(
                listenable: GlobalCart.provider,
                builder: (context, _) => _showCartBar ? _buildCartBar(context) : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final Color activeColor = _color;
    return SliverAppBar(
      backgroundColor: kBg,
      automaticallyImplyLeading: false,
      pinned: true,
      primary: true,
      elevation: 0,
      toolbarHeight: 85,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _NeumorphicButton(
              onTap: () => Navigator.pop(context),
              child: Icon(CupertinoIcons.chevron_left, color: kPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.categoryName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
                  if (widget.openTime.isNotEmpty || widget.closeTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.clock, size: 12, color: _isOpenNow() ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.openTime} - ${widget.closeTime}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Amiri'),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _isOpenNow() ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isOpenNow() ? 'مفتوح' : 'مغلق',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isOpenNow() ? Colors.green : Colors.red, fontFamily: 'Amiri'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.uiStyle == 6)
                    GestureDetector(
                      onTap: _openCustomProjectSheet,
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF6D22AC)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('حسب الطلب', style: TextStyle(fontSize: 10, color: Colors.white, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              child: AddToCartIcon(
                key: GlobalCart.cartKey,
                icon: _NeumorphicContainer(
                  padding: const EdgeInsets.all(10),
                  child: Icon(CupertinoIcons.cart, color: kPrimary, size: 22),
                ),
                badgeOptions: BadgeOptions(active: true, backgroundColor: kPrimary, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_favorites.isEmpty ? (!_isLargeCardStyle ? 89 : 66) : (!_isLargeCardStyle ? 131 : 108)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _sortMode != _SortMode.none ? _color.withOpacity(0.12) : kBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kNeumShadow, width: _sortMode != _SortMode.none ? 1.5 : 1),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 6, offset: const Offset(3, 3)),
                          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 6, offset: const Offset(-3, -3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sortMode == _SortMode.priceAsc ? CupertinoIcons.arrow_up : _sortMode == _SortMode.priceDesc ? CupertinoIcons.arrow_down : CupertinoIcons.arrow_up_arrow_down,
                            size: 14,
                            color: _sortMode != _SortMode.none ? _color : Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text('ترتيب حسب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: _sortMode != _SortMode.none ? _color : Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CategorySearchBar(controller: _searchCtrl, query: _searchQuery, activeColor: Colors.black),
                  ),
                ],
              ),
            ),
            if (_favorites.isNotEmpty) _buildFavoritesBar(),
            if (!_isLargeCardStyle) _buildViewToggle(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _favorites.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            final bool sel = _selectedFavoriteId == null;
            return _FavChip(label: 'الكل', selected: sel, color: _color, onTap: () => setState(() { _selectedFavoriteId = null; _applyLocalFilter(); }));
          }
          final fav = _favorites[i - 1];
          final bool sel = _selectedFavoriteId == fav['id'];
          return _FavChip(label: fav['name'] as String, selected: sel, color: _color, onTap: () => setState(() { _selectedFavoriteId = sel ? null : fav['id'] as String; _applyLocalFilter(); }));
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    final Color c = _color;
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _twoColumnView = false),
            child: AnimatedScale(
              scale: !_twoColumnView ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: !_twoColumnView ? c.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: !_twoColumnView ? c.withOpacity(0.4) : Colors.transparent),
                  boxShadow: !_twoColumnView ? [BoxShadow(color: c.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Image.asset(
                  'assets/3.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  color: !_twoColumnView ? c : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _twoColumnView = true),
            child: AnimatedScale(
              scale: _twoColumnView ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _twoColumnView ? c.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _twoColumnView ? c.withOpacity(0.4) : Colors.transparent),
                  boxShadow: _twoColumnView ? [BoxShadow(color: c.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Image.asset(
                  'assets/2.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  color: _twoColumnView ? c : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalGrid() {
    final items = List<Product>.from(_filteredProducts);
    if (items.isEmpty) return _buildEmptySliver();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      sliver: SliverGrid(
        key: ValueKey('n_${items.length}'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _twoColumnView ? 2 : 3, mainAxisSpacing: 20, crossAxisSpacing: _twoColumnView ? 24 : 12, childAspectRatio: _twoColumnView ? 0.82 : 0.68),
        delegate: SliverChildBuilderDelegate((context, i) {
          final p = items[i];
          return _StaggeredProductCard(
            key: ValueKey('n_${p.productId}_$i'),
            product: p,
            index: i,
            drinks: _drinks,
            animatingIds: _animatingIds,
            storeColor: _color,
            onAddToCart: (key) => _handleCartAction(p, key),
          );
        }, childCount: items.length),
      ),
    );
  }

  // ✅ تحسين: كارد الباتيسري بنفس تصميم البيتزا لكن بدون أنيميشن الصندوق
  Widget _buildPizzaGrid() {
    final items = List<Product>.from(_filteredProducts);
    if (items.isEmpty) return _buildEmptySliver();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
      sliver: SliverGrid(
        key: ValueKey('p_${items.length}'),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 60, crossAxisSpacing: 16, childAspectRatio: 0.72),
        delegate: SliverChildBuilderDelegate((context, i) {
          final p = items[i];
          return _PizzaOverflowCard(
            key: ValueKey('p_${p.productId}_$i'),
            product: p,
            index: i,
            storeColor: _color,
            onTap: () => _handleCartAction(p, GlobalKey()),
          );
        }, childCount: items.length),
      ),
    );
  }

  Widget _buildEmptySliver() => SliverToBoxAdapter(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(CupertinoIcons.search, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_isSearchMode ? 'لا توجد نتائج للبحث' : 'لا توجد منتجات في هذا النطاق', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    ),
  );

  Widget _buildCartBar(BuildContext context) {
    return ListenableBuilder(
      listenable: GlobalCart.provider,
      builder: (context, _) {
        final total = GlobalCart.provider.total;
        final count = GlobalCart.provider.count;
        final Color activeColor = _color;
        return Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [activeColor, activeColor.withOpacity(0.8)], begin: Alignment.centerRight, end: Alignment.centerLeft),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Text('${total.toInt()} Da', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, fontFamily: 'Amiri')),
                      const Expanded(
                        child: Text('عرض السلة', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Amiri')),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.3))),
                        child: Text('$count منتج', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ UIStyle2/3 — كارد البيتزا/باتيسري (مشترك)
// ══════════════════════════════════════════════════════════════════════════════
class _PizzaOverflowCard extends StatefulWidget {
  final Product product;
  final int index;
  final VoidCallback onTap;
  final Color storeColor;

  const _PizzaOverflowCard({
    super.key,
    required this.product,
    required this.index,
    required this.onTap,
    this.storeColor = kPrimary,
  });

  @override
  State<_PizzaOverflowCard> createState() => _PizzaOverflowCardState();
}

class _PizzaOverflowCardState extends State<_PizzaOverflowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  bool get _isInCart => GlobalCart.provider.containsProduct(widget.product.productId);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 80 + widget.index * 90), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color c = widget.storeColor;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ListenableBuilder(
          listenable: GlobalCart.provider,
          builder: (context, _) {
            final inCart = _isInCart;
            return GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) {
                setState(() => _pressed = false);
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOut,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 60, left: 0, right: 0, bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
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
                          border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1)),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.product.name, textAlign: TextAlign.center,
                              textDirection: getTextDirection(widget.product.name),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87, fontFamily: 'Amiri', height: 1.3)),
                            if (widget.product.capacite.isNotEmpty)
                              Text(widget.product.capacite, textDirection: getTextDirection(widget.product.capacite), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: inCart
                                        ? const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)])
                                        : LinearGradient(colors: [c, c.withOpacity(0.75)], begin: Alignment.centerRight, end: Alignment.centerLeft),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 3))],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(inCart ? Icons.check_circle_outline_rounded : CupertinoIcons.cart_badge_plus, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(inCart ? 'في السلة' : 'اختر', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                                  ),
                                  child: Text(widget.product.priceAffiche.isNotEmpty ? widget.product.priceAffiche : '${widget.product.price.toInt()} Da',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF9C27B0), fontFamily: 'Amiri')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -10, left: 8, right: 8,
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          transform: Matrix4.identity()..translate(0.0, _pressed ? 4.0 : 0.0),
                          child: Container(
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: inCart
                                  ? [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 6))]
                                  : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: _pressed ? 6 : 16, offset: Offset(0, _pressed ? 3 : 10))],
                            ),
                            child: _buildNetworkImage(widget.product.imagePath, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                    if (inCart)
                      Positioned(
                        top: -2, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [c, c.withOpacity(0.8)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text('مختار', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ أنيميشن المنتج عند الضغط (للبيتزا فقط)
// ══════════════════════════════════════════════════════════════════════════════
class _PizzaProductAnimationEntry extends StatefulWidget {
  final Product product;
  final Widget child;
  const _PizzaProductAnimationEntry({required this.product, required this.child});

  @override
  State<_PizzaProductAnimationEntry> createState() => _PizzaProductAnimationEntryState();
}

class _PizzaProductAnimationEntryState extends State<_PizzaProductAnimationEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final Animation<double> _spin;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _spin = Tween<double>(begin: 0, end: math.pi * 2).animate(CurvedAnimation(parent: _spinCtrl, curve: Curves.easeInOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _spinCtrl, curve: const Interval(0.0, 0.4)));
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _spinCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _runEntrySequence();
  }

  Future<void> _runEntrySequence() async {
    await _spinCtrl.forward();
    if (mounted) setState(() => _showContent = true);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showContent) return widget.child;
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: AnimatedBuilder(
          animation: _spinCtrl,
          builder: (context, _) {
            return FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Transform.rotate(
                  angle: _spin.value,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 30, offset: const Offset(0, 15))],
                      ),
                      child: _buildNetworkImage(widget.product.imagePath, fit: BoxFit.contain),
                    ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ PizzaDetailSheet (للبيتزا فقط - مع أنيميشن الصندوق)
// ══════════════════════════════════════════════════════════════════════════════
class PizzaDetailSheet extends StatefulWidget {
  final Product product;
  final String storeId;
  final List<DrinkItem> drinks;
  final Function(Product) onAddToCart;
  final Color storeColor;

  const PizzaDetailSheet({
    super.key,
    required this.product,
    required this.storeId,
    required this.drinks,
    required this.onAddToCart,
    this.storeColor = kPrimary,
  });

  @override
  State<PizzaDetailSheet> createState() => _PizzaDetailSheetState();
}

class _PizzaDetailSheetState extends State<PizzaDetailSheet>
    with SingleTickerProviderStateMixin {
  List<PizzaTopping> _toppings = [];
  PizzaTopping? _selectedTopping;
  PizzaSize? _selectedSize;
  final Map<String, Map<String, dynamic>> _selectedDrinks = {};
  bool _isLoadingMeta = true;
  String _currentImage = '';
  bool _showBoxAnimation = false;
  int _quantity = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  late final AnimationController _entryAnim;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  Color get _c => widget.storeColor;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.product.imagePath;
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _entryFade = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _entryAnim.forward();
    _loadProductMeta();
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProductMeta() async {
    try {
      if (widget.product.toppings.isNotEmpty) {
        final toppings = widget.product.toppings.map((e) => PizzaTopping.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) {
          setState(() {
            _toppings = toppings;
            if (_toppings.isNotEmpty) {
              _selectedTopping = _toppings.first;
              if (_selectedTopping!.sizes.isNotEmpty) {
                _selectedSize = _selectedTopping!.sizes.first;
                _updateImage();
              }
            }
            _isLoadingMeta = false;
          });
        }
        return;
      }
      final d = await ApiClient.get('/api/products/${widget.product.productId}');
      if (d.isEmpty || !mounted) return;
      final toppings = (d['toppings'] as List<dynamic>? ?? []).map((e) => PizzaTopping.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) {
        setState(() {
          _toppings = toppings;
          if (_toppings.isNotEmpty) {
            _selectedTopping = _toppings.first;
            if (_selectedTopping!.sizes.isNotEmpty) {
              _selectedSize = _selectedTopping!.sizes.first;
              _updateImage();
            }
          }
          _isLoadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
  }

  void _updateImage() {
    if (_selectedTopping != null && _selectedTopping!.image.isNotEmpty) {
      _currentImage = _selectedTopping!.image;
    } else {
      _currentImage = widget.product.imagePath;
    }
  }

  double get _unitPrice {
    double base = _selectedSize?.price ?? widget.product.price;
    for (final entry in _selectedDrinks.entries) {
      final qty = (entry.value['qty'] as int? ?? 0);
      if (qty > 0) {
        final sizePrice = entry.value['sizePrice'] as double?;
        if (sizePrice != null) {
          base += sizePrice * qty;
        } else {
          final drink = widget.drinks.firstWhere((d) => d.id == entry.key, orElse: () => DrinkItem(id: '', name: '', flavors: []));
          base += drink.price * qty;
        }
      }
    }
    return base;
  }

  double get _totalPrice => _unitPrice * _quantity;
  bool get _canOrder {
    if (_selectedTopping == null) return false;
    if (_selectedTopping!.sizes.isNotEmpty) return _selectedSize != null;
    return true;
  }

  void _addToCart() {
  if (!_canOrder) return;

  // 1. تجهيز اسم البيتزا (الاسم الأصلي + النكهة)
  // مثال النتيجة: "بيتزا كاري - دجاج"
  final String pizzaNameWithTopping = '${widget.product.name} - ${_selectedTopping!.label}';

  // 2. إضافة البيتزا كمنتج منفصل
  final bool hasSize = _selectedSize != null;
  final String sizeLabel = hasSize ? _selectedSize!.label : '';
  final double productPrice = hasSize ? _selectedSize!.price : widget.product.price;
  final String productIdSuffix = hasSize
      ? '${_selectedTopping!.label}_${_selectedSize!.label}'
      : _selectedTopping!.label;
  final pizzaProduct = Product(
    productId: '${widget.product.productId}_${productIdSuffix}_${DateTime.now().millisecondsSinceEpoch}',
    storeId: widget.product.storeId,
    storeName: widget.product.storeName,
    imagePath: _currentImage,
    name: pizzaNameWithTopping,
    price: productPrice,
    priceAffiche: '${productPrice.toInt()} Da',
    description: widget.product.description,
    quantity: _quantity,
    capacite: sizeLabel,
    storeLat: widget.product.storeLat,
    storeLng: widget.product.storeLng,
    note: _noteCtrl.text.trim(),
    categoryName: widget.product.categoryName,
    templateName: widget.product.templateName,
  );
  if (!GlobalCart.safeToggle(pizzaProduct, context)) return;

  // 3. إضافة المشروبات كمنتجات منفصلة تماماً
  _selectedDrinks.forEach((drinkId, data) {
    int qty = data['qty'] ?? 0;
    if (qty > 0) {
      final drinkItem = widget.drinks.firstWhere((d) => d.id == drinkId);
      
      // اسم المشروب مع النكهة (مثل: حمود بوعلام - سيليكتو)
      String fullDrinkName = "${drinkItem.name} ${data['flavorLabel']}".trim();
      
      final drinkProduct = Product(
        productId: 'drink_${drinkId}_${data['flavorLabel']}_${DateTime.now().millisecondsSinceEpoch}',
        storeId: widget.product.storeId,
        storeName: widget.product.storeName,
        imagePath: drinkItem.image,
        name: fullDrinkName,
        price: (data['sizePrice'] as num).toDouble(),
        priceAffiche: '${data['sizePrice'].toInt()} Da',
        quantity: qty, 
        capacite: data['sizeLabel'] ?? '',
        storeLat: widget.product.storeLat,
        storeLng: widget.product.storeLng,
        note: '',
        categoryName: widget.product.categoryName,
        templateName: widget.product.templateName,
      );
      GlobalCart.provider.toggle(drinkProduct);
    }
  });

  // تشغيل الأنيميشن وإغلاق الشيت
  setState(() => _showBoxAnimation = true);
  HapticFeedback.mediumImpact();
  
  Future.delayed(const Duration(milliseconds: 4500), () {
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    if (mounted) Navigator.pop(context);
  });
}

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: screenH * 0.93,
          decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHandle(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroImage(),
                          const SizedBox(height: 16),
                          _buildProductHeader(),
                          _buildDivider(),
                          if (_isLoadingMeta)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CupertinoActivityIndicator(color: kPrimary)))
                          else ...[
                            if (_toppings.isNotEmpty) ...[
                              _sectionHeader('النكهة', CupertinoIcons.star_fill),
                              const SizedBox(height: 12),
                              _buildToppings(),
                              _buildDivider(),
                            ],
                            if (_selectedTopping != null && _selectedTopping!.sizes.isNotEmpty) ...[
                              _sectionHeader('الحجم', CupertinoIcons.resize),
                              const SizedBox(height: 12),
                              _buildSizes(),
                              _buildDivider(),
                            ],
                          ],
                          _buildQuantitySelector(),
                          _buildDivider(),
                          if (widget.drinks.isNotEmpty) ...[
                            _sectionHeader('المشروبات', CupertinoIcons.drop_fill, optional: true),
                            const SizedBox(height: 12),
                            _buildDrinksRow(),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
              if (_showBoxAnimation)
                Positioned.fill(
                  child: _PizzaBoxAnimationOverlay(pizzaImage: _currentImage, pizzaName: widget.product.name),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildHeroImage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(anim), child: child),
      ),
      child: Container(
        key: ValueKey(_currentImage),
        height: 250, width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: _c.withOpacity(0.12),
          boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _buildNetworkImage(_currentImage, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(key: ValueKey(_unitPrice), '${_unitPrice.toInt()} Da', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0), fontFamily: 'Amiri')),
                ),
              ),
              const SizedBox(width: 10),
              const Text('السعر', style: TextStyle(fontSize: 11, color: Color.fromARGB(255, 43, 43, 43), fontFamily: 'Amiri')),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(widget.product.name, textAlign: TextAlign.right, textDirection: getTextDirection(widget.product.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Amiri')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _QtyButton(icon: CupertinoIcons.minus, color: _c, onTap: () { if (_quantity > 1) setState(() => _quantity--); }),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(key: ValueKey(_quantity), '  $_quantity  ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _c, fontFamily: 'Amiri')),
              ),
              _QtyButton(icon: CupertinoIcons.plus, color: _c, onTap: () => setState(() => _quantity++)),
            ],
          ),
          Row(
            children: [
              const Text('الكمية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Amiri')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(CupertinoIcons.layers_alt, color: _c, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 14),
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Colors.transparent, _c.withOpacity(0.12), kNeumShadow.withOpacity(0.4), _c.withOpacity(0.12), Colors.transparent]),
    ),
  );

  Widget _sectionHeader(String text, IconData icon, {bool optional = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (optional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            child: Text('اختياري', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
          )
        else
          const SizedBox(),
        Row(
          children: [
            Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Amiri')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _c, size: 14),
            ),
          ],
        ),
      ],
    );
  }

  BoxDecoration _optionDeco(bool selected) => BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: selected ? const Color(0xFFD8CCF0) : Colors.white.withOpacity(0.2),
    border: Border.all(color: selected ? _c : const Color(0xFFB8B1C8).withOpacity(0.5), width: selected ? 2.8 : 1.2),
    boxShadow: selected
        ? [BoxShadow(color: _c.withOpacity(0.4), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 4))]
        : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
  );

  Widget _buildToppings() {
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
      children: _toppings.map((t) {
        final sel = _selectedTopping?.label == t.label;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedTopping = t;
            _selectedSize = t.sizes.isNotEmpty ? t.sizes.first : null;
            _updateImage();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: _optionDeco(sel),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sel) ...[
                  Icon(CupertinoIcons.checkmark_alt, color: _c, size: 13),
                  const SizedBox(width: 5),
                ],
                Text(t.label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? _c : Colors.black87, fontFamily: 'Amiri')),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizes() {
    final sizes = _selectedTopping?.sizes ?? [];
    if (sizes.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
      children: sizes.map((s) {
        final sel = _selectedSize?.label == s.label;
        return GestureDetector(
          onTap: () => setState(() => _selectedSize = s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: _optionDeco(sel),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sel ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle, color: sel ? kSuccess : const Color(0xFFB8B1C8), size: 18),
                const SizedBox(height: 6),
                Text(s.label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? _c : Colors.black87, fontFamily: 'Amiri')),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(fontSize: sel ? 12 : 11, color: Colors.black45, fontFamily: 'Amiri', fontWeight: FontWeight.w700),
                  child: Text('${s.price.toInt()} Da'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ✅ تصليح: عرض المشروبات مع اختيار النكهة والحجم
  Widget _buildDrinksRow() {
    return SizedBox(
      height: 155,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.drinks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final drink = widget.drinks[i];
          final drinkState = _selectedDrinks[drink.id];
          final qty = drinkState?['qty'] as int? ?? 0;
          final flavorLabel = drinkState?['flavorLabel'] as String? ?? '';
          final sizeLabel = drinkState?['sizeLabel'] as String? ?? '';
          final sel = qty > 0;

          String drinkImage = drink.image;
          if (flavorLabel.isNotEmpty) {
            final matchedFlavor = drink.flavors.firstWhere((f) => f.label == flavorLabel,
              orElse: () => drink.flavors.isNotEmpty ? drink.flavors.first : DrinkFlavor(label: '', image: '', sizes: []));
            if (matchedFlavor.image.isNotEmpty) drinkImage = matchedFlavor.image;
          }

          return GestureDetector(
            onTap: () => _showDrinkFlavorPicker(drink),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 100,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sel ? Colors.white : kBg.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _c : const Color(0xFFB8B1C8).withOpacity(0.4), width: sel ? 2.5 : 1.2),
                boxShadow: sel
                    ? [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: drinkImage.isNotEmpty
                        ? CachedNetworkImage(imageUrl: drinkImage, height: 52, width: 52, memCacheWidth: 104, fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(CupertinoIcons.drop_fill, color: _c.withOpacity(0.4), size: 36))
                        : Icon(CupertinoIcons.drop_fill, color: _c.withOpacity(0.4), size: 36),
                  ),
                  const SizedBox(height: 5),
                  Text(drink.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: sel ? Colors.black : Colors.black87),
                    textAlign: TextAlign.center),
                  if (sel && flavorLabel.isNotEmpty)
                    Text(flavorLabel, style: TextStyle(fontSize: 9, color: Colors.black87.withOpacity(0.7), fontFamily: 'Amiri'),
                      textAlign: TextAlign.center),
                  if (sel && sizeLabel.isNotEmpty)
                    Text(sizeLabel, style: TextStyle(fontSize: 9, color: Colors.black87.withOpacity(0.7), fontFamily: 'Amiri'), textAlign: TextAlign.center),
                  if (!sel)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                      ),
                      child: Text('${drink.price.toInt()} Da', style: TextStyle(fontSize: 10, color: const Color(0xFF2E7D32), fontFamily: 'Amiri', fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 4),
                  if (sel)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DrinkQtyBtn(icon: CupertinoIcons.minus, color: _c, onTap: () {
                          setState(() {
                            final currentQty = _selectedDrinks[drink.id]?['qty'] as int? ?? 0;
                            if (currentQty <= 1) _selectedDrinks.remove(drink.id);
                            else _selectedDrinks[drink.id]!['qty'] = currentQty - 1;
                          });
                        }),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('$qty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _c, fontFamily: 'Amiri'))),
                        _DrinkQtyBtn(icon: CupertinoIcons.plus, color: _c, onTap: () {
                          setState(() { _selectedDrinks[drink.id]!['qty'] = ((_selectedDrinks[drink.id]!['qty'] as int? ?? 0) + 1); });
                        }),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: _c.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _c.withOpacity(0.3))),
                      child: Text('أضف', style: TextStyle(fontSize: 10, color: _c, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDrinkFlavorPicker(DrinkItem drink) {
    if (drink.flavors.isEmpty || drink.flavors.every((f) => f.sizes.isEmpty)) {
      setState(() {
        final currentQty = _selectedDrinks[drink.id]?['qty'] as int? ?? 0;
        _selectedDrinks[drink.id] = {
          'price': drink.price, 'qty': currentQty + 1,
          'flavorLabel': '', 'sizeLabel': '', 'sizePrice': drink.price,
        };
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          DrinkFlavor? pickedFlavor = drink.flavors.isNotEmpty ? drink.flavors.first : null;
          DrinkSize? pickedSize = (pickedFlavor != null && pickedFlavor.sizes.isNotEmpty) ? pickedFlavor.sizes.first : null;

          return Container(
            decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: StatefulBuilder(
              builder: (innerCtx, setInner) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('اختر ${drink.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.black87)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(CupertinoIcons.drop_fill, color: _c, size: 14)),
                    ]),
                    const SizedBox(height: 16),
                    if (drink.flavors.isNotEmpty) ...[
                      Align(alignment: Alignment.centerRight, child: Text('النكهة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontFamily: 'Amiri'))),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
                        children: drink.flavors.map((f) {
                          final isSel = pickedFlavor?.label == f.label;
                          return GestureDetector(
                            onTap: () => setInner(() { pickedFlavor = f; pickedSize = f.sizes.isNotEmpty ? f.sizes.first : null; }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: _optionDeco(isSel),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (isSel) ...[Icon(CupertinoIcons.checkmark_alt, color: _c, size: 12), const SizedBox(width: 4)],
                                Text(f.label, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: Colors.black87, fontFamily: 'Amiri')),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (pickedFlavor != null && pickedFlavor!.sizes.isNotEmpty) ...[
                      Align(alignment: Alignment.centerRight, child: Text('الحجم', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontFamily: 'Amiri'))),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end,
                        children: pickedFlavor!.sizes.map((s) {
                          final isSel = pickedSize?.label == s.label;
                          return GestureDetector(
                            onTap: () => setInner(() => pickedSize = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: _optionDeco(isSel),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(isSel ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.circle, color: const Color(0xFFB8B1C8).withOpacity(0.6), size: 14),
                                const SizedBox(height: 4),
                                Text(s.label, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: Colors.black87, fontFamily: 'Amiri')),
                                const SizedBox(height: 3),
                                Text('${s.price.toInt()} Da', style: TextStyle(fontSize: 11, color: Colors.black45, fontFamily: 'Amiri', fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDrinks[drink.id] = {
                              'qty': 1, 'flavorLabel': pickedFlavor?.label ?? '',
                              'sizeLabel': pickedSize?.label ?? '',
                              'sizePrice': pickedSize?.price ?? pickedFlavor?.sizes.firstOrNull?.price ?? drink.price,
                            };
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_c, _c.withOpacity(0.75)], begin: Alignment.centerRight, end: Alignment.centerLeft),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 5))],
                          ),
                          child: const Center(child: Text('إضافة للطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri'))),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color.lerp(Colors.white, _c, 0.06)!, Color.lerp(Colors.white, _c, 0.15)!]),
              boxShadow: [
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(3, 3)),
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(-3, -3)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(key: ValueKey(_totalPrice), _totalPrice.toInt().toString(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _c, fontFamily: 'Amiri')),
                ),
                Text('Da', style: TextStyle(fontSize: 10, color: _c, fontFamily: 'Amiri')),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _canOrder ? _addToCart : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: _canOrder ? const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)], begin: Alignment.centerRight, end: Alignment.centerLeft) : null,
                  color: _canOrder ? null : Colors.grey.shade300,
                  boxShadow: _canOrder ? [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 16, offset: const Offset(0, 6))] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_canOrder ? CupertinoIcons.cart_badge_plus : CupertinoIcons.lock, color: _canOrder ? Colors.white : Colors.grey.shade500, size: 18),
                    const SizedBox(width: 8),
                    Text(_canOrder
                        ? 'أضف للسلة'
                        : _selectedTopping == null
                            ? 'اختر النكهة'
                            : 'اختر الحجم',
                      style: TextStyle(color: _canOrder ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Amiri')),
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
//  UIStyle 4 — Bottom Sheet للخضر والفواكه (وزن / مبلغ)
// ══════════════════════════════════════════════════════════════════════════════
const Color _purple = Color(0xFF7D29C6);
const Color _purpleLight = Color(0xFF9232E8);
const Color _purpleDark = Color(0xFF6D22AC);

mixin SheetEntryAnimation<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  void _initSheetAnimation() {
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  void _disposeSheetAnimation() {
    _entryCtrl.dispose();
  }

  Widget _buildSheetEntry(Widget child) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: child,
      ),
    );
  }
}

class Style4DetailSheet extends StatefulWidget {
  final Product product;
  final void Function(Product)? onProductAddedToTemplate;
  const Style4DetailSheet({required this.product, this.onProductAddedToTemplate});

  @override
  State<Style4DetailSheet> createState() => _Style4DetailSheetState();
}

class _Style4DetailSheetState extends State<Style4DetailSheet>
    with TickerProviderStateMixin, SheetEntryAnimation {
  int _method = 0; // 0=وزن, 1=مبلغ
  double _weight = 0.5;
    int _pieceCount = 1; // جديد: عداد الحبات
  final _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  double get _pricePerKg => widget.product.price;
double get _totalPrice {
    if (_method == 0) return _weight * _pricePerKg;
    if (_method == 1) return (double.tryParse(_amountCtrl.text) ?? 0);
    return _pieceCount * widget.product.pricePerPiece; // حساب سعر الحبات
  }
  
String get _weightDisplay {
  if (_method == 2) return '$_pieceCount حبة'; // إذا كانت بالحبة

  // حساب الوزن الإجمالي بالكيلوغرام أولاً
  double weightInKg = (_method == 0) ? _weight : (_totalPrice / _pricePerKg);

  if (weightInKg < 1.0) {
    // إذا كان أقل من 1 كيلو، نحولوه للغرام (مثلاً: 0.3 كغ تولي 300 غرام)
    return '${(weightInKg * 1000).toInt()} غرام';
  } else {
    // إذا كان 1 كيلو أو أكثر
    return '${weightInKg.toStringAsFixed(1)} كيلو';
  }
}
  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _initSheetAnimation();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _disposeSheetAnimation();
    super.dispose();
  }

  void _addToCart() {
    if (_totalPrice <= 0) return;
    String detail = "";
    if (_method == 0) detail = "وزن ${_weight.toStringAsFixed(1)} كغ";
    else if (_method == 1) detail = "مبلغ ${_amountCtrl.text} DA";
    else detail = "$_pieceCount حبة";
    
    final p = Product(
      productId: '${widget.product.productId}_${_method}_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: widget.product.imagePath,
      name: '${widget.product.name} ($detail)',
      price: _totalPrice,
      quantity: 1,
      capacite: _weightDisplay,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      uiStyle: 4,
      note: _noteCtrl.text.trim(),
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName,
    );
    widget.onProductAddedToTemplate?.call(p);
    if (!GlobalCart.safeToggle(p, context)) return;
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheetEntry(
      Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildHeroImage(),
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildMethodSelector(),
                    const SizedBox(height: 20),
                    _buildOrderSection(),
                    const SizedBox(height: 24),
                    _buildTotalAndCart(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildHeroImage() {
    return Container(
      height: 200, width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: _purple.withOpacity(0.06),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _buildNetworkImage(widget.product.imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Text('${_pricePerKg.toInt()} DA / كغ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.white)),
            ),
          ],
        ),
        const Spacer(),
        Flexible(
          child: Text(widget.product.name,
              textAlign: TextAlign.right,
              textDirection: getTextDirection(widget.product.name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
        ),
      ],
    );
  }

Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('طريقة الطلب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
        const SizedBox(height: 10),
        Row( // استعملنا Row عادي ونحسب المساحة
          children: [
            _methodBtn(1, 'حسب المبلغ'),
            const SizedBox(width: 8),
            _methodBtn(0, 'حسب الوزن'),
            if (widget.product.hasPiecePrice) ...[ // تظهر فقط إذا فعلها التاجر
              const SizedBox(width: 8),
              _methodBtn(2, 'بالحبة'),
            ],
          ],
        ),
      ],
    );
  }

  // دالة مساعدة لصنع الزر (عشان ما نكرر الكود)
  Widget _methodBtn(int m, String label) {
    bool isSel = _method == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSel ? const LinearGradient(colors: [_purpleDark, _purple, _purpleLight]) : null,
            color: isSel ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSel ? [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8)] : [],
            border: Border.all(color: isSel ? Colors.transparent : Colors.grey.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87, fontFamily: 'Amiri')),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.18)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.22), blurRadius: 14, offset: const Offset(4, 4))],
      ),
      child: _method == 0 
          ? _buildWeightMode() 
          : (_method == 1 ? _buildAmountMode() : _buildPieceMode()), // إضافة شرط الحبات
    );
  }

   Widget _buildPieceMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('عدد الحبات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _qtyBtn(CupertinoIcons.minus, () { if (_pieceCount > 1) setState(() => _pieceCount--); }),
            const SizedBox(width: 20),
            Text('$_pieceCount', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _purple)),
            const SizedBox(width: 20),
            _qtyBtn(CupertinoIcons.plus, () => setState(() => _pieceCount++)),
          ],
        ),
        Center(child: Text('سعر الحبة: ${widget.product.pricePerPiece.toInt()} DA', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Amiri'))),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: _purple.withOpacity(0.1)),
        child: Icon(icon, color: _purple, size: 20),
      ),
    );
  }

  Widget _buildWeightMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('الوزن', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (_weight > 0.5) setState(() => _weight -= 0.5);
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(CupertinoIcons.minus, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: TextField(
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: TextEditingController(text: _weight.toStringAsFixed(1)),
                onChanged: (v) {
                  final w = double.tryParse(v);
                  if (w != null && w > 0) setState(() => _weight = w);
                },
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: _purple),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() => _weight += 0.5),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('=  ${_weight.toStringAsFixed(1)}  كغ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF6E6B7B))),
        ),
      ],
    );
  }

  Widget _buildAmountMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('المبلغ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(' DA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: _purple)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple.withOpacity(0.3)),
                ),
                child: TextField(
                  controller: _amountCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: _purple),
                  decoration: const InputDecoration(
                    hintText: 'أدخل المبلغ',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFFB8B1C8)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('≈  $_weightDisplay',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: Color(0xFF6E6B7B))),
        ),
      ],
    );
  }

  Widget _buildTotalAndCart() {
    return Row(
      children: [
        GestureDetector(
          onTap: _totalPrice > 0 ? _addToCart : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _purple.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("أضف للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
              ],
            ),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('السعر', style: TextStyle(fontSize: 11, color: Color(0xFF6E6B7B), fontFamily: 'Amiri')),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(key: ValueKey(_totalPrice.toInt()), '${_totalPrice.toInt()} DA',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri', height: 1)),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  UIStyle 5 — Bottom Sheet للكوسميتيك
// ══════════════════════════════════════════════════════════════════════════════
class Style5DetailSheet extends StatefulWidget {
  final Product product;
  final void Function(Product)? onProductAddedToTemplate;
  const Style5DetailSheet({required this.product, this.onProductAddedToTemplate});

  @override
  State<Style5DetailSheet> createState() => _Style5DetailSheetState();
}

class _Style5DetailSheetState extends State<Style5DetailSheet>
    with TickerProviderStateMixin, SheetEntryAnimation {
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSheetAnimation();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _disposeSheetAnimation();
    super.dispose();
  }

  void _addToCart() {
    final p = Product(
      productId: '${widget.product.productId}_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: widget.product.imagePath,
      name: widget.product.name,
      price: widget.product.price,
      quantity: 1,
      capacite: widget.product.capacite,
      description: widget.product.description,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      uiStyle: 5,
      note: _noteCtrl.text.trim(),
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName,
    );
    widget.onProductAddedToTemplate?.call(p);
    if (!GlobalCart.safeToggle(p, context)) return;
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheetEntry(
      Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildHeroImage(),
                    const SizedBox(height: 20),
                    _buildHeader(),
                    if (widget.product.capacite.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSizeBadge(),
                    ],
                    const SizedBox(height: 20),
                    _buildDescription(),
                    const SizedBox(height: 30),
                    _buildAddToCart(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildHeroImage() {
    return Container(
      height: 260, width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [_purple.withOpacity(0.07), _purpleLight.withOpacity(0.04)]),
        boxShadow: [BoxShadow(color: _purple.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _buildNetworkImage(widget.product.imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(widget.product.name,
            textAlign: TextAlign.right,
            textDirection: getTextDirection(widget.product.name),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Text('${widget.product.price.toInt()} DA',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSizeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.resize, color: _purple, size: 16),
          const SizedBox(width: 8),
          Text('الحجم: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: _purple)),
          Text(widget.product.capacite,
              textDirection: getTextDirection(widget.product.capacite),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: _purple)),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.18)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.22), blurRadius: 14, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('الوصف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.info_circle_fill, color: Colors.white, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.product.description.isNotEmpty ? widget.product.description : 'لا يوجد وصف لهذا المنتج.',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6E6B7B), fontFamily: 'Amiri', height: 1.8)),
        ],
      ),
    );
  }

  Widget _buildAddToCart() {
    return GestureDetector(
      onTap: _addToCart,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _purple.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("أضف للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  UIStyle 6 — Bottom Sheet لمشاريع حسب الطلب (معرض صور + كمية)
// ══════════════════════════════════════════════════════════════════════════════
class Style6DetailSheet extends StatefulWidget {
  final Product product;
  final void Function(Product)? onProductAddedToTemplate;
  const Style6DetailSheet({required this.product, this.onProductAddedToTemplate});

  @override
  State<Style6DetailSheet> createState() => _Style6DetailSheetState();
}

class _Style6DetailSheetState extends State<Style6DetailSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _noteCtrl = TextEditingController();
  int _currentImageIndex = 0;
  int _quantity = 1;
  PizzaSize? _selectedSize;
  late final PageController _pageCtrl;
  List<PizzaSize> _sizes = [];

  late final AnimationController _entryAnim;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  List<String> get _images {
    final list = <String>[_currentImage];
    for (final e in widget.product.extraImages) {
      if (e is String && e.isNotEmpty) list.add(e);
    }
    return list;
  }

  String get _currentImage {
    if (_selectedSize != null && _selectedSize!.image.isNotEmpty) {
      return _selectedSize!.image;
    }
    return widget.product.imagePath;
  }

  double get _unitPrice => _selectedSize?.price ?? widget.product.price;
  double get _totalPrice => _unitPrice * _quantity;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _entryFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _entryAnim.forward();
    _pageCtrl = PageController();
    _sizes = widget.product.sizes
        .map((e) => PizzaSize.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (_sizes.isNotEmpty) _selectedSize = _sizes.first;
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _pageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _addToCart() {
    final p = Product(
      productId: '${widget.product.productId}_${_selectedSize?.label ?? ''}_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: _currentImage,
      name: widget.product.name,
      price: _unitPrice,
      quantity: _quantity,
      capacite: _selectedSize?.label ?? widget.product.capacite,
      description: widget.product.description,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      extraImages: widget.product.extraImages,
      uiStyle: 6,
      note: _noteCtrl.text.trim(),
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName,
    );
    widget.onProductAddedToTemplate?.call(p);
    if (!GlobalCart.safeToggle(p, context)) return;
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _entrySlide,
      child: FadeTransition(
        opacity: _entryFade,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildGallery(),
                      const SizedBox(height: 16),
                      _buildHeader(),
                      if (widget.product.description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildDescription(),
                      ],
                      if (_sizes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSizes(),
                      ],
                      const SizedBox(height: 20),
                      _buildQuantitySelector(),
                      const SizedBox(height: 24),
                      _buildTotalAndCart(),
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

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildGallery() {
    return Column(
      children: [
        Container(
          height: 260, width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
                colors: [_purple.withOpacity(0.07), _purpleLight.withOpacity(0.04)]),
            boxShadow: [BoxShadow(color: _purple.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.all(10),
                child: _buildNetworkImage(_images[i], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_images.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_images.length, (i) => GestureDetector(
              onTap: () => _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentImageIndex == i ? _purple : const Color(0xFFB8B1C8).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(widget.product.name,
            textAlign: TextAlign.right,
            textDirection: getTextDirection(widget.product.name),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_selectedSize != null && _selectedSize!.label.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withOpacity(0.2)),
                ),
                child: Text(_selectedSize!.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: _purple)),
              ),
            if (_selectedSize != null && _selectedSize!.label.isNotEmpty) const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Text('${_unitPrice.toInt()} DA',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purple.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(widget.product.description.isNotEmpty ? widget.product.description : 'لا يوجد وصف لهذا المنتج.',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6E6B7B), fontFamily: 'Amiri', height: 1.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('اختر الحجم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _sizes.map((size) {
            final sel = _selectedSize == size;
            final sizeImage = size.image.isNotEmpty ? size.image : widget.product.imagePath;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedSize = size;
                final idx = size.image.isNotEmpty ? _images.indexOf(size.image) : 0;
                if (idx >= 0) {
                  _currentImageIndex = idx;
                  _pageCtrl.jumpToPage(idx);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 110,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: sel ? const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft) : null,
                  color: sel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sel ? Colors.transparent : const Color(0xFFB8B1C8).withOpacity(0.3)),
                  boxShadow: sel
                      ? [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.25), blurRadius: 6, offset: const Offset(2, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildNetworkImage(sizeImage, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 4),
                    Text(size.label.isNotEmpty ? size.label : 'حجم',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri',
                            color: sel ? Colors.white : const Color(0xFF2D2A3A))),
                    Text('${size.price.toInt()} DA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Amiri',
                            color: sel ? Colors.white.withOpacity(0.9) : _purple)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.18)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () { if (_quantity < 99) setState(() => _quantity++); },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(key: ValueKey(_quantity), '$_quantity',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri')),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () { if (_quantity > 1) setState(() => _quantity--); },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: Icon(CupertinoIcons.minus, color: _purple, size: 16),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('الكمية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.layers_alt, color: Colors.white, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAndCart() {
    return Row(
      children: [
        GestureDetector(
          onTap: _addToCart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _purple.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("أضف للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
              ],
            ),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_quantity} × ${_unitPrice.toInt()} DA',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6E6B7B), fontFamily: 'Amiri')),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(key: ValueKey(_totalPrice.toInt()), '${_totalPrice.toInt()} DA',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri', height: 1)),
            ),
          ],
        ),
      ],
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
//  Custom Project Order Form — يُفتح فقط من زر AppBar (حسب الطلب)
// ══════════════════════════════════════════════════════════════════════════════
class _CustomProjectSheet extends StatefulWidget {
  final String storeId;
  final String storeName;
  final double? storeLat;
  final double? storeLng;

  const _CustomProjectSheet({
    required this.storeId,
    required this.storeName,
    this.storeLat,
    this.storeLng,
  });

  @override
  State<_CustomProjectSheet> createState() => _CustomProjectSheetState();
}

class _CustomProjectSheetState extends State<_CustomProjectSheet>
    with TickerProviderStateMixin, SheetEntryAnimation {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  List<File> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  bool _isUploading = false;
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _savedLocations = [];
  bool _loadingLocations = true;
  int _selectedLocationIndex = -1;
  bool _useMap = false;
  String _mapAddress = '';
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _initSheetAnimation();
    _loadLocations();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _detailsCtrl.dispose();
    _disposeSheetAnimation();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) setState(() => _loadingLocations = false); return; }
    try {
      final data = await ApiClient.getList('/api/saved-locations?userId=${user.uid}');
      if (mounted) {
        setState(() {
          _savedLocations = data.map((loc) {
            final m = loc as Map<String, dynamic>;
            return {
              'id': m['_id'] ?? m['id'] ?? '',
              'label': m['label'] as String? ?? '',
              'address': m['address'] as String? ?? '',
              'lat': m['lat'],
              'lng': m['lng'],
              'cityNameAr': m['cityNameAr'] as String? ?? '',
              'cityNameFr': m['cityNameFr'] as String? ?? '',
              'icon': _iconFromType(m['type'] as String? ?? 'other'),
            };
          }).where((loc) => (loc['label'] as String).isNotEmpty).toList();
          _loadingLocations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  IconData _iconFromType(String type) {
    switch (type) {
      case 'home': return CupertinoIcons.house_fill;
      case 'work': return CupertinoIcons.briefcase_fill;
      default: return CupertinoIcons.location_fill;
    }
  }

  String get _finalAddress {
    if (_useMap) return _mapAddress;
    if (_selectedLocationIndex >= 0 && _selectedLocationIndex < _savedLocations.length)
      return _savedLocations[_selectedLocationIndex]['address'] as String;
    return '';
  }

  bool _validate() {
    final missing = <String>[];
    if (_firstNameCtrl.text.trim().isEmpty) missing.add('الاسم');
    if (_lastNameCtrl.text.trim().isEmpty) missing.add('اللقب');
    if (_phoneCtrl.text.trim().isEmpty) missing.add('رقم الهاتف');
    if (_detailsCtrl.text.trim().isEmpty) missing.add('تفاصيل الطلبية');
    if (_finalAddress.isEmpty) missing.add('عنوان التوصيل');

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء ملء الحقول التالية: ${missing.join("، ")}',
            style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _selectedImages.addAll(picked.map((p) => File(p.path))));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submitProject() async {
    if (!_validate()) return;

    setState(() => _isUploading = true);
    try {
      _uploadedImageUrls = [];
      for (final file in _selectedImages) {
        final url = await ApiClient.upload(file);
        if (url.isNotEmpty) _uploadedImageUrls.add(url);
      }

      final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
      final phone = _phoneCtrl.text.trim();
      final details = _detailsCtrl.text.trim();
      final address = _finalAddress;

      final user = FirebaseAuth.instance.currentUser;
      final body = {
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'storeLat': widget.storeLat,
        'storeLng': widget.storeLng,
        'name': fullName,
        'phone': phone,
        'description': details,
        'location': address,
        'userLat': _selectedLat,
        'userLng': _selectedLng,
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'imageUrl': _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : '',
        'extraImages': _uploadedImageUrls.length > 1 ? _uploadedImageUrls.sublist(1) : [],
        'quantity': 1,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await ApiClient.post('/api/projects', body);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب المشروع بنجاح'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheetEntry(
      Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: 4),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildNameRow(),
                    const SizedBox(height: 16),
                    _buildTextField(_phoneCtrl, 'رقم الهاتف', CupertinoIcons.phone_fill, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildAddressSection(),
                    const SizedBox(height: 16),
                    _buildDetailsField(),
                    const SizedBox(height: 16),
                    _buildImagePicker(),
                    const SizedBox(height: 28),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF6D22AC)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              child: const Icon(CupertinoIcons.hammer_fill, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('طلب حسب الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
          ],
        ),
        const SizedBox(height: 8),
        const Text('املأ المعلومات وانتظر رد السائق', style: TextStyle(fontSize: 12, color: Color(0xFF6E6B7B), fontFamily: 'Amiri')),
      ],
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(_firstNameCtrl, 'الاسم', CupertinoIcons.person_fill),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(_lastNameCtrl, 'اللقب', CupertinoIcons.person_fill),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.25)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), blurRadius: 8, offset: const Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF6D22AC)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2D2A3A), fontFamily: 'Amiri'),
            cursorColor: kPrimary,
            decoration: InputDecoration(
              hintText: 'أدخل $label',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFB8B1C8), fontFamily: 'Amiri'),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('عنوان التوصيل', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('إجباري', style: TextStyle(fontSize: 9, color: Colors.red, fontFamily: 'Amiri')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingLocations)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
          ))
        else ...[
          ..._savedLocations.asMap().entries.map((e) {
            final i = e.key;
            final loc = e.value;
            final isSelected = !_useMap && _selectedLocationIndex == i;
              return GestureDetector(
              onTap: () => setState(() {
                _selectedLocationIndex = i;
                _useMap = false;
                _selectedLat = double.tryParse('${loc['lat']}');
                _selectedLng = double.tryParse('${loc['lng']}');
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimary.withOpacity(0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? kPrimary : const Color(0xFFB8B1C8).withOpacity(0.25),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: kPrimary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                      : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), blurRadius: 8, offset: const Offset(3, 3))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? kPrimary : Colors.transparent,
                        border: Border.all(color: isSelected ? kPrimary : Colors.grey.shade400, width: 2),
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(loc['label'] as String,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                color: isSelected ? kPrimary : const Color(0xFF2D2A3A), fontFamily: 'Amiri')),
                            Text(loc['address'] as String,
                              style: TextStyle(fontSize: 11,
                                color: isSelected ? kPrimary.withOpacity(0.8) : Colors.black45, fontFamily: 'Amiri'),
                              textAlign: TextAlign.right),
                          ],
                        ),
                      ),
                    ),
                    Icon(loc['icon'] as IconData,
                      color: isSelected ? kPrimary : const Color(0xFF6E6B7B), size: 22),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()),
              );
              if (result != null && mounted) {
                setState(() {
                  _useMap = true;
                  _selectedLocationIndex = -1;
                  if (result is Map) {
                    _mapAddress = result['address'].toString();
                    _selectedLat = double.tryParse(result['lat'].toString());
                    _selectedLng = double.tryParse(result['lng'].toString());
                  } else {
                    _mapAddress = result.toString();
                  }
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _useMap ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _useMap ? kPrimary : const Color(0xFFB8B1C8).withOpacity(0.25),
                  width: _useMap ? 2 : 1.2,
                ),
                boxShadow: _useMap
                    ? [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))]
                    : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), blurRadius: 8, offset: const Offset(3, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _useMap ? Colors.white : Colors.transparent,
                      border: Border.all(color: _useMap ? Colors.white : Colors.grey.shade400, width: 2),
                    ),
                    child: _useMap ? const Icon(Icons.check, size: 14, color: kPrimary) : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("تحديد من الخريطة",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                              color: _useMap ? Colors.white : const Color(0xFF2D2A3A), fontFamily: 'Amiri')),
                          Text(_useMap && _mapAddress.isNotEmpty ? _mapAddress : "اضغط لفتح الخريطة",
                            style: TextStyle(fontSize: 11,
                              color: _useMap ? Colors.white70 : Colors.black45, fontFamily: 'Amiri')),
                        ],
                      ),
                    ),
                  ),
                  Icon(CupertinoIcons.map_fill,
                    color: _useMap ? Colors.white : kPrimary, size: 22),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.25)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), blurRadius: 8, offset: const Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('تفاصيل الطلبية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF6D22AC)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _detailsCtrl,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2D2A3A), fontFamily: 'Amiri'),
            cursorColor: kPrimary,
            decoration: const InputDecoration(
              hintText: 'اكتب وصف الطلبية بالتفصيل (المنتجات، الكمية، المقاسات...)',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFFB8B1C8), fontFamily: 'Amiri'),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('صور الطلبية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('اختياري', style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Amiri')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImages[i], height: 80, width: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -4, right: -4,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.25), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), blurRadius: 8, offset: const Offset(3, 3))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedImages.isNotEmpty ? 'إضافة المزيد من الصور' : 'إضافة صور للمنتج',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF9232E8), Color(0xFF6D22AC)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.photo_fill, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _submitProject,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6D22AC), Color(0xFF7D29C6), Color(0xFF9232E8)], begin: Alignment.centerRight, end: Alignment.centerLeft),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isUploading ? CupertinoIcons.hourglass : CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(_isUploading ? 'جاري الرفع...' : 'إرسال الطلب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  UIStyle 7 — Bottom Sheet للفارماسي (متعدد الأحجام)
// ══════════════════════════════════════════════════════════════════════════════
class Style7DetailSheet extends StatefulWidget {
  final Product product;
  final void Function(Product)? onProductAddedToTemplate;
  const Style7DetailSheet({required this.product, this.onProductAddedToTemplate});

  @override
  State<Style7DetailSheet> createState() => _Style7DetailSheetState();
}

class _Style7DetailSheetState extends State<Style7DetailSheet>
    with TickerProviderStateMixin, SheetEntryAnimation {
  final TextEditingController _noteCtrl = TextEditingController();
  int _selectedVariantIndex = 0;
  int _quantity = 1;

  // Extract variants from product data
  List<Map<String, dynamic>> get _variants {
    if (widget.product.variants.isNotEmpty) {
      return widget.product.variants.map((v) {
        if (v is Map) return Map<String, dynamic>.from(v as Map);
        return <String, dynamic>{};
      }).toList();
    }
    // Fallback: derive from sizes field if variants not present
    if (widget.product.sizes.isNotEmpty) {
      return widget.product.sizes.map((s) {
        if (s is Map) {
          final m = Map<String, dynamic>.from(s as Map);
          return {
            'label': m['label'] ?? '',
            'unit': m['sizeUnit'] ?? m['unit'] ?? '',
            'price': m['price'] ?? widget.product.price,
            'image': m['image'] ?? widget.product.imagePath,
          };
        }
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  Map<String, dynamic> get _selectedVariant =>
      _variants.isNotEmpty ? _variants[_selectedVariantIndex] : {};

  String get _currentImage =>
      _selectedVariant['image']?.toString().isNotEmpty == true
          ? _selectedVariant['image'].toString()
          : widget.product.imagePath;

  double get _currentPrice =>
      (_selectedVariant['price'] as num?)?.toDouble() ?? widget.product.price;

  String get _currentLabel {
    final l = _selectedVariant['label']?.toString() ?? '';
    final u = _selectedVariant['unit']?.toString() ?? '';
    return l.isNotEmpty ? (u.isNotEmpty ? '$l $u' : l) : widget.product.capacite;
  }

  @override
  void initState() {
    super.initState();
    _initSheetAnimation();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _disposeSheetAnimation();
    super.dispose();
  }

  void _addToCart() {
    final p = Product(
      productId: '${widget.product.productId}_${_currentLabel}_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: _currentImage,
      name: '${widget.product.name} - $_currentLabel',
      price: _currentPrice,
      quantity: _quantity,
      capacite: _currentLabel,
      description: widget.product.description,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      uiStyle: 7,
      variants: widget.product.variants,
      note: _noteCtrl.text.trim(),
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName,
    );
    widget.onProductAddedToTemplate?.call(p);
    if (!GlobalCart.safeToggle(p, context)) return;
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheetEntry(
      Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildHeroImage(),
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildDescription(),
                    if (_variants.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildVariantsList(),
                    ],
                    const SizedBox(height: 20),
                    _buildQuantitySelector(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildTotalAndCart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildHeroImage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child)),
      child: Container(
        key: ValueKey(_currentImage),
        height: 240, width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [_purple.withOpacity(0.07), _purpleLight.withOpacity(0.04)]),
          boxShadow: [BoxShadow(color: _purple.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _buildNetworkImage(_currentImage, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(widget.product.name,
            textAlign: TextAlign.right,
            textDirection: getTextDirection(widget.product.name),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _purple.withOpacity(0.2)),
              ),
              child: Text(_currentLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: _purple)),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Text('${_currentPrice.toInt()} DA',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _purple.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(widget.product.description.isNotEmpty ? widget.product.description : 'لا يوجد وصف لهذا المنتج.',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6E6B7B), fontFamily: 'Amiri', height: 1.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('اختر الحجم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _variants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final v = _variants[i];
              final sel = i == _selectedVariantIndex;
              final vImg = v['image']?.toString() ?? widget.product.imagePath;
              final vLabel = v['label']?.toString() ?? '';
              final vUnit = v['unit']?.toString() ?? '';
              final vPrice = (v['price'] as num?)?.toDouble() ?? widget.product.price;

              return GestureDetector(
                onTap: () => setState(() => _selectedVariantIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft) : null,
                    color: sel ? null : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sel ? Colors.transparent : const Color(0xFFB8B1C8).withOpacity(0.3)),
                    boxShadow: sel
                        ? [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                        : [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.25), blurRadius: 6, offset: const Offset(2, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildNetworkImage(vImg, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 4),
                      Text(vLabel.isNotEmpty ? '$vLabel $vUnit' : 'حجم',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri',
                              color: sel ? Colors.white : const Color(0xFF2D2A3A))),
                      Text('${vPrice.toInt()} DA',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Amiri',
                              color: sel ? Colors.white.withOpacity(0.9) : _purple)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB8B1C8).withOpacity(0.18)),
        boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () { if (_quantity < 99) setState(() => _quantity++); },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(key: ValueKey(_quantity), '$_quantity',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri')),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () { if (_quantity > 1) setState(() => _quantity--); },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: Icon(CupertinoIcons.minus, color: _purple, size: 16),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('الكمية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.layers_alt, color: Colors.white, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAndCart() {
    final total = _currentPrice * _quantity;
    return Row(
      children: [
        GestureDetector(
          onTap: _addToCart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _purple.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("أضف للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
              ],
            ),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_quantity} × ${_currentPrice.toInt()} DA',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6E6B7B), fontFamily: 'Amiri')),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(key: ValueKey(total.toInt()), '${total.toInt()} DA',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri', height: 1)),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  uiStyle == 8 — منتجات صور + سعر أساسي + أحجام اختيارية + وصف
// ══════════════════════════════════════════════════════════════════════════════
class Style8DetailSheet extends StatefulWidget {
  final Product product;
  final void Function(Product)? onProductAddedToTemplate;
  const Style8DetailSheet({required this.product, this.onProductAddedToTemplate});

  @override
  State<Style8DetailSheet> createState() => _Style8DetailSheetState();
}

class _Style8DetailSheetState extends State<Style8DetailSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _noteCtrl = TextEditingController();
  int _selectedSizeIndex = -1;
  int _quantity = 1;
  int _currentImageIndex = 0;
  late final PageController _pageController;

  late final AnimationController _entryAnim;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  List<Map<String, dynamic>> get _sizes {
    if (widget.product.sizes.isNotEmpty) {
      return widget.product.sizes.map((s) {
        if (s is Map) return Map<String, dynamic>.from(s as Map);
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  double get _sizePrice {
    if (_selectedSizeIndex >= 0 && _selectedSizeIndex < _sizes.length) {
      return (_sizes[_selectedSizeIndex]['price'] as num?)?.toDouble() ?? 0;
    }
    return 0;
  }

  double get _totalPrice => (widget.product.price + _sizePrice) * _quantity;
  double get _unitPrice => widget.product.price + _sizePrice;

  String get _sizeLabel {
    if (_selectedSizeIndex >= 0 && _selectedSizeIndex < _sizes.length) {
      return _sizes[_selectedSizeIndex]['label']?.toString() ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _entryFade = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _entryAnim.forward();
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _noteCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _allImages {
    final imgs = <String>[widget.product.imagePath];
    for (final e in widget.product.extraImages) {
      final s = e.toString();
      if (s.isNotEmpty) imgs.add(s);
    }
    return imgs;
  }

  void _addToCart() {
    final nameSuffix = _sizeLabel.isNotEmpty ? ' - $_sizeLabel' : '';
    final p = Product(
      productId: '${widget.product.productId}_$_selectedSizeIndex\_${DateTime.now().millisecondsSinceEpoch}',
      storeId: widget.product.storeId,
      storeName: widget.product.storeName,
      imagePath: widget.product.imagePath,
      name: '${widget.product.name}$nameSuffix',
      price: _unitPrice,
      quantity: _quantity,
      capacite: _sizeLabel,
      description: widget.product.description,
      storeLat: widget.product.storeLat,
      storeLng: widget.product.storeLng,
      uiStyle: 8,
      sizes: widget.product.sizes,
      note: _noteCtrl.text.trim(),
      categoryName: widget.product.categoryName,
      templateName: widget.product.templateName,
    );
    widget.onProductAddedToTemplate?.call(p);
    if (!GlobalCart.safeToggle(p, context)) return;
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: Container(
          height: screenH * 0.91,
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: _purple.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, -8))],
          ),
          child: Column(children: [
            _buildHandle(),
            _buildImage(),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildAboutSection(),
                    const SizedBox(height: 18),
                    if (_sizes.isNotEmpty) ...[
                      _buildSectionTitle('اختر الحجم', CupertinoIcons.resize),
                      const SizedBox(height: 12),
                      _buildSizeSelector(),
                      const SizedBox(height: 18),
                    ],
                    _buildQuantitySelector(),
                    const SizedBox(height: 18),
                  ])),
            ),
            _buildBottomAction(),
          ])),
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      width: 44, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
    ),
  );

  Widget _buildImage() {
    final images = _allImages;
    final hasMultiple = images.length > 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
        ],
        border: Border.all(color: _purple.withOpacity(0.1))),
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
                            placeholder: (context, url) => const Center(child: CupertinoActivityIndicator(color: _purple)),
                            errorWidget: (context, url, error) => const Icon(Icons.fastfood, size: 60, color: Color(0xFF6E6B7B)))))))
                : Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: images.first.isNotEmpty
                            ? CachedNetworkImage(imageUrl: images.first, memCacheWidth: 400, fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(child: CupertinoActivityIndicator(color: _purple)),
                                errorWidget: (context, url, error) => const Icon(Icons.fastfood, size: 60, color: Color(0xFF6E6B7B)))
                            : Container(color: Colors.grey.shade200, child: const Icon(CupertinoIcons.photo, color: Colors.grey, size: 50))))),
       ),   if (hasMultiple)
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
                      color: _currentImageIndex == i ? _purple : kNeumShadow,
                      borderRadius: BorderRadius.circular(4))))),
           ), 
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _purple.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Text('${_unitPrice.toInt()} DA',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.white, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 12),
        Text(widget.product.name, textAlign: TextAlign.center, textDirection: getTextDirection(widget.product.name),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A), height: 1.3)),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
        ],
        border: Border.all(color: _purple.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('عن المنتج',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration:  BoxDecoration(
                  gradient: LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.info_circle_fill, color: Colors.white, size: 13)),
            ]),
          const SizedBox(height: 4),
          Divider(color: kNeumShadow.withOpacity(0.2), height: 18),
          Text(
            widget.product.description.isNotEmpty
                ? widget.product.description
                : 'لا يوجد وصف حالي لهذا المنتج.',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF6E6B7B), height: 1.9, fontFamily: 'Amiri')),
        ]));
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 13)),
      ]);
  }

  Widget _buildSizeSelector() {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedSizeIndex = -1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: _selectedSizeIndex == -1
                  ? const LinearGradient(colors: [Color(0xFFEDE7F6), Colors.white], begin: Alignment.topRight, end: Alignment.bottomLeft)
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kBg, Color(0xFFE6E4F0)]),
              border: Border.all(color: _selectedSizeIndex == -1 ? _purple : _purple.withOpacity(0.1), width: _selectedSizeIndex == -1 ? 2.5 : 1.2),
              boxShadow: _selectedSizeIndex == -1
                  ? [BoxShadow(color: _purple.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
                  : [
                      BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
                      BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
                    ]),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedSizeIndex == -1)
                  Icon(CupertinoIcons.checkmark_circle_fill, color: kSuccess, size: 18),
                const SizedBox(width: 5),
                Text('بدون', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13, color: _selectedSizeIndex == -1 ? _purple : const Color(0xFF2D2A3A))),
              ])),
        ),
        ..._sizes.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        final label = s['label']?.toString() ?? '';
        final price = (s['price'] as num?)?.toDouble() ?? 0;
        bool sel = _selectedSizeIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedSizeIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: sel
                  ? const LinearGradient(colors: [Color(0xFFEDE7F6), Colors.white], begin: Alignment.topRight, end: Alignment.bottomLeft)
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kBg, Color(0xFFE6E4F0)]),
              border: Border.all(color: sel ? _purple : _purple.withOpacity(0.1), width: sel ? 2.5 : 1.2),
              boxShadow: sel
                  ? [BoxShadow(color: _purple.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
                  : [
                      BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
                      BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
                    ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sel ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    color: sel ? kSuccess : kNeumShadow, size: 18),
                const SizedBox(height: 5),
                Text(label, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13, color: sel ? _purple : const Color(0xFF2D2A3A))),
                const SizedBox(height: 3),
                Text('${price.toInt()} DA', style: const TextStyle(fontSize: 11, color: Colors.black45, fontFamily: 'Amiri')),
              ])),
        );
      }).toList(),
    ]);
  }

  Widget _buildQuantitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
        ],
        border: Border.all(color: _purple.withOpacity(0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kNeumShadow.withOpacity(0.2))),
            child: Row(
              children: [
                _qtyCircleBtn(icon: CupertinoIcons.minus, onTap: () { if (_quantity > 1) setState(() => _quantity--); }),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: SizedBox(
                    width: 30,
                    child: Text(key: ValueKey(_quantity), '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri'))),
                ),
                const SizedBox(width: 8),
                _qtyCircleBtn(icon: CupertinoIcons.plus, onTap: () => setState(() => _quantity++), isAdd: true),
              ])),
          Row(
            children: [
              const Text('الكمية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(CupertinoIcons.layers_alt, color: Colors.white, size: 16)),
            ]),
        ]),
    );
  }

  Widget _qtyCircleBtn({required IconData icon, required VoidCallback onTap, bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: isAdd
              ? const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.topRight, end: Alignment.bottomLeft)
              : null,
          color: isAdd ? null : Colors.white,
          shape: BoxShape.circle,
          border: isAdd ? null : Border.all(color: kNeumShadow.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: kNeumShadow.withOpacity(0.28), blurRadius: 6, offset: const Offset(2, 2)),
            const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 6, offset: Offset(-2, -2)),
          ]),
        child: Icon(icon, size: 15, color: isAdd ? Colors.white : _purple)),
    );
  }

  Widget _buildBottomAction() {
    final total = _totalPrice;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)]),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
        ],
        border: Border.all(color: _purple.withOpacity(0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _addToCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purpleDark, _purple, _purpleLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _purple.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 7))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.cart_badge_plus, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("أضف للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri', letterSpacing: 0.3)),
                ])),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('السعر الإجمالي',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Amiri')),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(key: ValueKey(total.toInt()), '${total.toInt()} DA',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _purple, fontFamily: 'Amiri', height: 1)),
              ),
              if (_quantity > 1)
                Text('× $_quantity قطعة',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'Amiri')),
            ]),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ أنيميشن الصندوق (للبيتزا فقط)
// ══════════════════════════════════════════════════════════════════════════════
class _PizzaBoxAnimationOverlay extends StatefulWidget {
  final String pizzaImage;
  final String pizzaName;
  const _PizzaBoxAnimationOverlay({required this.pizzaImage, required this.pizzaName});

  @override
  State<_PizzaBoxAnimationOverlay> createState() => _PizzaBoxAnimationOverlayState();
}

class _PizzaBoxAnimationOverlayState extends State<_PizzaBoxAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _pizzaCtrl;
  late final AnimationController _openBoxCtrl;
  late final AnimationController _lidCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _bgFade;
  late final Animation<double> _pizzaScale;
  late final Animation<double> _pizzaOpacity;
  late final Animation<Offset> _pizzaOffset;
  late final Animation<double> _openBoxY;
  late final Animation<double> _openBoxOpacity;
  late final Animation<double> _openBoxFadeOut;
  late final Animation<double> _lidY;
  late final Animation<double> _lidOpacity;
  late final Animation<double> _shakeX;
  late final Animation<double> _exitY;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _bgExit;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _pizzaCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _openBoxCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _lidCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _bgFade = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);
    _pizzaOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.25)).animate(CurvedAnimation(parent: _pizzaCtrl, curve: Curves.easeInCubic));
    _pizzaScale = Tween<double>(begin: 1.0, end: 0.55).animate(CurvedAnimation(parent: _pizzaCtrl, curve: Curves.easeInCubic));
    _pizzaOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _pizzaCtrl, curve: const Interval(0.65, 1.0)));
    _openBoxY = Tween<double>(begin: -400, end: 0).animate(CurvedAnimation(parent: _openBoxCtrl, curve: Curves.ease));
    _openBoxOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _openBoxCtrl, curve: const Interval(0.0, 0.4)));
    _openBoxFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _lidCtrl, curve: const Interval(0.3, 0.8)));
    _lidY = Tween<double>(begin: -350, end: 0).animate(CurvedAnimation(parent: _lidCtrl, curve: Curves.fastLinearToSlowEaseIn));
    _lidOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _lidCtrl, curve: const Interval(0.0, 0.5)));
    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _exitY = Tween<double>(begin: 0, end: -300).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.fastOutSlowIn));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _exitCtrl, curve: const Interval(0.4, 1.0)));
    _bgExit = Tween<double>(begin: 0.72, end: 0.0).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _bgCtrl.forward();
    _openBoxCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _pizzaCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _lidCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _shakeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _exitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pizzaCtrl.dispose();
    _openBoxCtrl.dispose();
    _lidCtrl.dispose();
    _shakeCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgCtrl, _exitCtrl]),
      builder: (context, _) {
        final bgOpacity = (_bgFade.value * _bgExit.value).clamp(0.0, 0.72);
        return Container(
          color: Colors.black.withOpacity(bgOpacity),
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pizzaCtrl, _openBoxCtrl, _lidCtrl, _shakeCtrl, _exitCtrl]),
              builder: (context, _) {
              return Transform.translate(
                offset: Offset(_shakeX.value, _exitY.value),
                child: Opacity(
                  opacity: _exitOpacity.value.clamp(0.0, 1.0),
                    child: SizedBox(
                    width: 360, height: 400,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: 70, left: 0, right: 0,
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(0, _openBoxY.value),
                              child: Opacity(
                                opacity: (_openBoxOpacity.value * _openBoxFadeOut.value).clamp(0.0, 1.0),
                                child: Image.asset('assets/images/open-box.png', width: 250, height: 250, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildFallbackBox()),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, _pizzaOffset.value.dy * 100),
                          child: Transform.scale(
                            scale: _pizzaScale.value,
                            child: Opacity(
                              opacity: _pizzaOpacity.value.clamp(0.0, 1.0),
                              child: Container(
                                width: 150, height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 24, offset: const Offset(0, 12))],
                                ),
                                child: ClipOval(child: _buildNetworkImage(widget.pizzaImage, fit: BoxFit.cover)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 100, left: 0, right: 0,
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(0, _lidY.value),
                              child: Opacity(
                                opacity: _lidOpacity.value.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 20, offset: const Offset(2, 2))],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset('assets/images/top-box.png', width: 200, height: 200, fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _buildFallbackLid()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      
    );
    },
    );
  }

  Widget _buildFallbackBox() => Container(
    width: 200, height: 120,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8C065), Color(0xFFD4A853)]),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 6))],
    ),
  );

  Widget _buildFallbackLid() => Container(
    width: 200, height: 35,
    decoration: BoxDecoration(
      color: const Color(0xFFD4A853),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(0, -2))],
    ),
    child: const Center(child: Text('🍕', style: TextStyle(fontSize: 18))),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  زر الكمية
// ══════════════════════════════════════════════════════════════════════════════
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _QtyButton({required this.icon, required this.onTap, this.color = kPrimary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kBg,
          boxShadow: [
            BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 6, offset: const Offset(3, 3)),
            BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 6, offset: const Offset(-3, -3)),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _DrinkQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _DrinkQtyBtn({required this.icon, required this.onTap, this.color = kPrimary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, size: 11, color: color),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  UIStyle 1 — Normal Product Card
// ══════════════════════════════════════════════════════════════════════════════
class _StaggeredProductCard extends StatefulWidget {
  final Product product;
  final int index;
  final Set<String> animatingIds;
  final Function(GlobalKey) onAddToCart;
  final Color storeColor;
  final List<DrinkItem> drinks;

  const _StaggeredProductCard({
    super.key,
    required this.product,
    required this.index,
    required this.animatingIds,
    required this.onAddToCart,
    required this.drinks,
    this.storeColor = Colors.black,
  });

  @override
  State<_StaggeredProductCard> createState() => _StaggeredProductCardState();
}

class _StaggeredProductCardState extends State<_StaggeredProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad));
    Future.delayed(Duration(milliseconds: 40 + widget.index * 25), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: ProductCardWidget(
        product: widget.product,
        animatingIds: widget.animatingIds,
        storeColor: widget.storeColor,
        onAddToCart: widget.onAddToCart,
        drinks: widget.drinks,
        index: widget.index,
      ),
    ),
  );
}

TextDirection getTextDirection(String text) {
  int arabic = 0, latin = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF || r >= 0x0750 && r <= 0x077F || r >= 0x08A0 && r <= 0x08FF) arabic++;
    if (r >= 0x0041 && r <= 0x005A || r >= 0x0061 && r <= 0x007A || r >= 0x0030 && r <= 0x0039) latin++;
  }
  if (arabic >= latin) return TextDirection.rtl;
  return TextDirection.ltr;
}

class ProductCardWidget extends StatefulWidget {
  final Product product;
  final Function(GlobalKey) onAddToCart;
  final Set<String> animatingIds;
  final Color storeColor;
  final List<DrinkItem> drinks;
  final int index;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.animatingIds,
    required this.drinks,
    this.storeColor = Colors.black,
    this.index = 0,
  });

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> {
  final GlobalKey _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final Color c = widget.storeColor;
    return ListenableBuilder(
      listenable: GlobalCart.provider,
      builder: (context, _) {
        final bool isInCart = GlobalCart.provider.containsProduct(widget.product.productId);
        return GestureDetector(
          onTap: () => widget.onAddToCart(_imageKey),
          child: AnimatedScale(
            scale: isInCart ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _GradientNeumCard(
              isInCart: isInCart,
              storeColor: c,
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          key: _imageKey,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.expand(child: _buildProductImage(widget.product.imagePath, index: widget.index)),
                        ),
                        if (isInCart)
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(widget.product.displayName, textAlign: TextAlign.center,
                      textDirection: getTextDirection(widget.product.displayName),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87, fontFamily: 'Amiri')),
                  ),
                  Center(
                    child: Text(widget.product.capacite, textAlign: TextAlign.center,
                      textDirection: getTextDirection(widget.product.capacite),
                      style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.product.priceAffiche, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                      GestureDetector(
                        onTap: () => showProductDetail(
                          context: context,
                          product: widget.product,
                          drinks: widget.drinks,
                          isInCart: isInCart,
                          onAddToCart: () => widget.onAddToCart(_imageKey),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(String path, {int index = 0}) {
    if (path.isEmpty) return const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey));
    if (path.startsWith('http')) {
      return _StaggeredNetworkImage(
        imageUrl: path,
        index: index,
        memCacheWidth: 280,
      );
    }
    return Image.asset(path, fit: BoxFit.contain, cacheWidth: 280,
      errorBuilder: (_, __, ___) => const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)));
  }
}

class _StaggeredNetworkImage extends StatefulWidget {
  final String imageUrl;
  final int index;
  final int memCacheWidth;
  const _StaggeredNetworkImage({required this.imageUrl, required this.index, this.memCacheWidth = 280});
  @override
  State<_StaggeredNetworkImage> createState() => _StaggeredNetworkImageState();
}

class _StaggeredNetworkImageState extends State<_StaggeredNetworkImage> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const Center(child: CupertinoActivityIndicator(radius: 10));
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: widget.memCacheWidth,
      placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(radius: 10)),
      errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey, size: 28),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════
Widget _buildNetworkImage(String url, {BoxFit fit = BoxFit.contain}) {
  if (url.isEmpty) {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 30)),
    );
  }
  if (url.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: 400,
      placeholder: (_, __) => const Center(child: CupertinoActivityIndicator()),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade100,
        child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 30)),
      ),
    );
  }
  return Image.asset(url, fit: fit,
    errorBuilder: (_, __, ___) => Container(
      color: Colors.grey.shade100,
      child: const Icon(CupertinoIcons.photo, color: Colors.grey),
    ),
  );
}

class _GradientNeumCard extends StatelessWidget {
  final Widget child;
  final bool isInCart;
  final EdgeInsets? padding;
  final double radius;
  final Color storeColor;

  const _GradientNeumCard({
    required this.child,
    this.isInCart = false,
    this.padding,
    this.radius = 20,
    this.storeColor = kPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
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
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: Color(0xFF7D29C6).withOpacity(0.1)),
      ),
      child: child,
    );
  }
}

class _NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets? padding;
  final double radius;
  final bool inset;
  final BoxBorder? border;

  const _NeumorphicContainer({
    required this.child,
    this.color,
    this.padding,
    this.radius = 20,
    this.inset = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? kBg,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: inset
            ? [
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(2, 2)),
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(-2, -2)),
              ]
            : [
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(4, 4)),
                BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(-4, -4)),
              ],
      ),
      child: child,
    ),
  );
}

class _NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _NeumorphicButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: _NeumorphicContainer(padding: const EdgeInsets.all(10), radius: 15, child: child),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _FavChip — مستطيل المفضلة
// ══════════════════════════════════════════════════════════════════════════════
class _FavChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FavChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey.shade400, width: selected ? 0 : 1),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 3))]
              : [
                  BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(3, 3)),
                  BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(-3, -3)),
                ],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? Colors.white : Colors.black87, fontFamily: 'Amiri')),
      ),
    );
  }
}

class _CategorySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final Color activeColor;

  const _CategorySearchBar({
    required this.controller,
    required this.query,
    this.activeColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: query.isNotEmpty ? 16 : 6, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 6, offset: const Offset(-4, -4)),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 14, left: 6),
              child: Icon(CupertinoIcons.search, color: query.isNotEmpty ? Colors.black : Colors.black, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), fontFamily: 'Amiri'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'ابحث داخل التصنيف...',
                  hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, fontFamily: 'Amiri'),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                cursorColor: Colors.black,
              ),
            ),
            if (query.isNotEmpty)
              GestureDetector(
                onTap: () => controller.clear(),
                child: Container(
                  margin: const EdgeInsets.only(left: 8, right: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(2, 2)),
                      BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 4, offset: const Offset(-2, -2)),
                    ],
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.black, size: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}