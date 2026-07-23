import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/delivery_screen.dart' hide kPrimaryColor, kAccentColor, kBgColor, kCardColor, kShadowColor, kTextDark, kTextGrey, kSuccessColor;
import 'package:flutter_application_1/Services/socket_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter_application_1/dashboard_search_bar.dart' hide kTextColor;
import 'package:flutter_application_1/products_list_screen.dart' show Product, GlobalCart;
import 'package:flutter_application_1/cardd.dart' show CartScreen;
import 'order_models.dart';
import '../product_alternative_overlay.dart';

final List<Order> activeOrders = [];

String _formatTime(dynamic ts) {
  if (ts == null) return 'الآن';
  if (ts is String) return ts;
  if (ts is int) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return 'الآن';
}

// ── Neumorphic helpers ────────────────────────────────────────────────────────
List<BoxShadow> _neuShadow({double blur = 10, double offset = 4}) => [
  BoxShadow(
    color: const Color(0xFFB8B1C8).withOpacity(0.6),
    blurRadius: blur,
    offset: Offset(offset, offset),
  ),
  BoxShadow(
    color: const Color(0xFFFFFFFF), // أبيض صريح للجهة المقابلة
    blurRadius: blur,
    offset: Offset(-offset, -offset),
  ),
];


BoxDecoration _neuDeco({double radius = 18}) => BoxDecoration(
  color: kBgColor,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: _neuShadow(),
);

// ══════════════════════════════════════════════════════════════════════════════
//  OrderModel
// ══════════════════════════════════════════════════════════════════════════════
class OrderModel {
  static Order fromDoc(Map<String, dynamic> d, String id) {
    final items = (d['items'] as List? ?? []).map((item) {
      final m = item as Map<String, dynamic>;

      // ✅ السعر الأصلي
      final originalPrice =
          ((m['prix'] ?? m['price'] ?? m['totalItem'] ?? 0) as num).toDouble();

      // ✅ finalPrice إذا غيّر السائق السعر
      final finalPrice = m['finalPrice'] != null
          ? (m['finalPrice'] as num).toDouble()
          : originalPrice;

      return OrderItem(
        name: m['name'] as String? ?? '',
        price: finalPrice,
        originalPrice: originalPrice,
        image: m['image'] as String? ?? m['imageUrl'] as String? ?? '',
        quantity: (m['quantity'] as int?) ?? 1,
        purchaseStatus: m['purchaseStatus'] as String? ?? '',
        alternativeName: m['alternativeName'] as String? ?? '',
        alternativePrice: ((m['alternativePrice'] as num?) ?? 0).toDouble(),
        alternativeStatus: m['alternativeStatus'] as String? ?? '',
        uiStyle: (m['uiStyle'] as int?) ?? 1,
        capacite: m['capacite'] as String? ?? '',
        categoryName: m['categoryName'] as String? ?? '',
        templateName: m['templateName'] as String? ?? '',
        storeName: m['storeName'] as String? ?? '',
        storeId: m['storeId'] as String? ?? '',
        sizes: (m['sizes'] as List?) ?? [],
        extraImages: (m['extraImages'] as List?) ?? [],
        variants: (m['variants'] as List?) ?? [],
      );
    }).toList();

    return Order(
      id: id,
      magasinId: d['magasinId'] as String?,
      items: items,
      deliveryFee: (d['deliveryFee'] as num? ?? 15).toDouble(),
      driverName: d['driverName'] as String?,
      status: statusFromString(d['status'] as String? ?? ''),
      time: _formatTime(d['createdAt']),
      address: d['address'] as String? ?? '',
      customerConfirmed: d['customerConfirmed'] as bool? ?? false,
      driverId: d['driverId'] as String?,
      driverLat: (d['driverLat'] as num?)?.toDouble(),
      driverLng: (d['driverLng'] as num?)?.toDouble(),
      userLat: (d['userLat'] as num?)?.toDouble(),
      userLng: (d['userLng'] as num?)?.toDouble(),
      counterOffer: d['counterOffer'] as Map<String, dynamic>?,
      isFreeDelivery: d['isFreeDelivery'] == true,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LocationsCache
// ══════════════════════════════════════════════════════════════════════════════
class LocationsCache {
  static String? _cachedUid;
  static List<Map<String, dynamic>> _data = [];
  static bool isValid(String uid) => _cachedUid == uid && _data.isNotEmpty;
  static List<Map<String, dynamic>> get data => _data;
  static void set(String uid, List<Map<String, dynamic>> locations) {
    _cachedUid = uid;
    _data = locations;
  }

  static void clear() {
    _cachedUid = null;
    _data = [];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ActiveOrdersScreen
// ══════════════════════════════════════════════════════════════════════════════
class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});
  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pageCtrl;
  Timer? _autoRefreshTimer;
  Timer? _updateIndicatorTimer;
  bool _showUpdateBadge = false;

  List<Map<String, dynamic>> _rawOrders = [];
  List<Map<String, dynamic>> _transportDocs = [];
  List<Map<String, dynamic>> _serviceDocs = [];
  List<Map<String, dynamic>> _projectDeliveries = [];
  static final Set<String> _cleanedProjects = {};
  static final Set<String> _restoredFreeDeliveries = {};
  static final Set<String> _shownAlternativeOverlays = {};
  bool _loadingOrders = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SocketClient.init();
    SocketClient.onReconnect(_loadOrders);
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _loadOrders();
    SocketClient.on('order:updated', (data) => _handleEvent('order', data));
    SocketClient.on('order:created', (data) => _handleEvent('order', data));
    SocketClient.on('service:updated', (data) => _handleEvent('service', data));
    SocketClient.on('service:created', (data) => _handleEvent('service', data));
    SocketClient.on('transport:updated', (data) => _handleEvent('transport', data));
    SocketClient.on('transport:created', (data) => _handleEvent('transport', data));
    SocketClient.on('delivery:updated', (data) => _handleEvent('delivery', data));
    SocketClient.on('delivery:created', (data) => _handleEvent('delivery', data));
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final uid = user.uid;
      final activeStatuses = 'pending,accepted,purchased,on_way,onway';
      final results = await Future.wait([
        ApiClient.getList('/api/orders?status=$activeStatuses&userId=$uid'),
        ApiClient.getList('/api/transport-orders?userId=$uid'),
        ApiClient.getList('/api/service-orders?userId=$uid'),
        ApiClient.getList('/api/project-deliveries?userId=$uid'),
      ]);
      if (mounted) {
        setState(() {
          _rawOrders = results[0].cast<Map<String, dynamic>>();
          _transportDocs = results[1].cast<Map<String, dynamic>>();
          _serviceDocs = results[2].cast<Map<String, dynamic>>();
          _projectDeliveries = results[3].cast<Map<String, dynamic>>();

          // إزالة الطلبيات المرفوضة من السائق + إرجاع هدية التوصيل
          for (final o in _rawOrders) {
            final rejectedBy = o['rejectedBy'];
            final hasRejected = rejectedBy is String
                ? rejectedBy.isNotEmpty
                : rejectedBy is List ? (rejectedBy as List).isNotEmpty : false;
            if (hasRejected) _restoreFreeDelivery(o);
          }
          _rawOrders.removeWhere((o) {
            final rejectedBy = o['rejectedBy'];
            if (rejectedBy is String) return rejectedBy.isNotEmpty;
            if (rejectedBy is List) return (rejectedBy as List).isNotEmpty;
            return false;
          });
          _serviceDocs.removeWhere((o) {
            final rejectedBy = o['rejectedBy'];
            if (rejectedBy is String) return rejectedBy.isNotEmpty;
            if (rejectedBy is List) return (rejectedBy as List).isNotEmpty;
            return false;
          });
          _transportDocs.removeWhere((o) {
            final rejectedBy = o['rejectedBy'];
            if (rejectedBy is String) return rejectedBy.isNotEmpty;
            if (rejectedBy is List) return (rejectedBy as List).isNotEmpty;
            return false;
          });
          _projectDeliveries.removeWhere((o) {
            final rejectedBy = o['rejectedBy'];
            if (rejectedBy is String) return rejectedBy.isNotEmpty;
            if (rejectedBy is List) return (rejectedBy as List).isNotEmpty;
            return false;
          });

          _loadingOrders = false;
        });
        for (final o in _rawOrders) {
          _checkAndShowAlternativeOverlay(o);
        }
      }
      SocketClient.join('user_$uid');
    } catch (e) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _handleEvent(String type, dynamic data) {
    if (data == null) return;
    
    final updatedItem = data is Map ? Map<String, dynamic>.from(data) : (data as Map<String, dynamic>);
    final String itemId = updatedItem['_id'] ?? updatedItem['id'] ?? '';
    final String status = updatedItem['status'] ?? '';

    if (itemId.isEmpty) return;

    setState(() {
      List<Map<String, dynamic>> targetList;
      switch (type) {
        case 'service': targetList = _serviceDocs; break;
        case 'transport': targetList = _transportDocs; break;
        case 'delivery': targetList = _projectDeliveries; break;
        default: targetList = _rawOrders; break;
      }

      int index = targetList.indexWhere((o) => (o['_id'] ?? o['id']) == itemId);

      final rejectedBy = updatedItem['rejectedBy'];
      final hasRejected = rejectedBy is String
          ? rejectedBy.isNotEmpty
          : rejectedBy is List ? (rejectedBy as List).isNotEmpty : false;

      if (index != -1) {
        if (status == 'delivered' || status == 'cancelled' || hasRejected) {
          if (status == 'cancelled' || hasRejected) {
            _restoreFreeDelivery(targetList[index]);
          }
          targetList.removeAt(index);
        } else {
          targetList[index] = updatedItem;
        }
      } else if (status != 'delivered' && status != 'cancelled' && !hasRejected) {
        targetList.insert(0, updatedItem);
      }
    });

    _checkAndShowAlternativeOverlay(updatedItem);
    _flashUpdateBadge();
  }

  void _checkAndShowAlternativeOverlay(Map<String, dynamic> orderData) {
    if (!ProductAlternativeOverlayHelper.isEnabled) return;
    final items = orderData['items'] as List? ?? [];
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final purchaseStatus = m['purchaseStatus'] as String? ?? '';
      final alternativeStatus = m['alternativeStatus'] as String? ?? '';
      final alternativeName = m['alternativeName'] as String? ?? '';
      if (purchaseStatus == 'unavailable' &&
          alternativeStatus == 'pending' &&
          alternativeName.isNotEmpty) {
        final itemName = m['name'] as String? ?? '';
        final overlayKey = '${orderData["_id"]}_$itemName';
        if (_shownAlternativeOverlays.contains(overlayKey)) continue;
        _shownAlternativeOverlays.add(overlayKey);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          ProductAlternativeOverlayHelper.show(
            context: context,
            orderId: orderData['_id'] as String? ?? '',
            driverName: orderData['driverName'] as String? ?? 'السائق',
            productName: itemName,
            productPrice: ((m['prix'] ?? m['price'] ?? 0) as num).toDouble(),
            alternativeName: alternativeName,
            alternativePrice: ((m['alternativePrice'] as num?) ?? 0).toDouble(),
            onRefresh: () => _loadOrders(),
          );
        });
      }
    }
  }

  Future<void> _restoreFreeDelivery(Map<String, dynamic> order) async {
    final id = order['_id'] as String? ?? order['id'] as String? ?? '';
    if (id.isEmpty || _restoredFreeDeliveries.contains(id)) return;
    final isFree = order['isFreeDelivery'] == true;
    if (!isFree) return;
    _restoredFreeDeliveries.add(id);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final driverId = order['driverId'] as String?;
      final update = <String, dynamic>{};
      if (driverId != null && driverId.isNotEmpty) {
        update['driverFreeDelivery.$driverId'] = true;
      } else {
        update['hasFreeDelivery'] = true;
      }
      await ApiClient.put('/api/users/$uid', update);
    } catch (_) {}
  }

  void _flashUpdateBadge() {
    _updateIndicatorTimer?.cancel();
    setState(() => _showUpdateBadge = true);
    _updateIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showUpdateBadge = false);
    });
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadOrders();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _updateIndicatorTimer?.cancel();
    _pageCtrl.dispose();
    
    // إلغاء كل المستمعين لهذا النوع من الأحداث
    SocketClient.off('order:updated');
    SocketClient.off('order:created');
    SocketClient.off('service:updated');
    SocketClient.off('service:created');
    SocketClient.off('transport:updated');
    SocketClient.off('transport:created');
    SocketClient.off('delivery:updated');
    SocketClient.off('delivery:created');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! > 500) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
              bottom: false,
              child: user == null
                  ? _notLoggedIn()
                  : Column(
                      children: [
                        DashboardSearchBar(stores: []),
                        Expanded(child: _buildContent(user.uid)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() => _loadOrders();

  Widget _buildContent(String uid) {
    List<Widget> sections = [];

    if (_loadingOrders) {
      sections.add(SizedBox(
        height: 200,
        child: Center(child: CupertinoActivityIndicator(color: kPrimaryColor)),
      ));
    } else {
      if (_projectDeliveries.isNotEmpty) {
        sections.add(_buildSectionHeader('مشاريعي'));
        sections.addAll(
          _projectDeliveries.map((d) => _ProjectDeliveryCard(doc: d)),
        );
        sections.add(const SizedBox(height: 8));
      }

      var orders = _rawOrders.where((doc) {
        final hidden = List<String>.from(doc['hiddenFor'] ?? []);
        return !hidden.contains(uid);
      }).toList();

      var orderModels = orders.map((doc) => OrderModel.fromDoc(doc, doc['_id'] ?? '')).toList();

      final activeStatuses = {'pending', 'accepted', 'purchased', 'on_way', 'onway'};
      final transportOrders = _transportDocs.where((d) => activeStatuses.contains(d['status'])).toList();
      final serviceOrders = _serviceDocs.where((d) => activeStatuses.contains(d['status'])).toList();

      if (transportOrders.isNotEmpty) {
        sections.add(_buildSectionHeader('طلبات النقل'));
        for (var d in transportOrders) {
          sections.add(TransportCard(
            data: d,
            docId: d['_id'] ?? '',
            onChanged: _loadOrders,
          ));
        }
        sections.add(const SizedBox(height: 8));
      }

      if (serviceOrders.isNotEmpty) {
        sections.add(_buildSectionHeader('طلبات الخدمة'));
        for (var d in serviceOrders) {
          sections.add(ServiceOrderCard(
            data: d,
            docId: d['_id'] ?? '',
            onChanged: _loadOrders,
          ));
        }
        sections.add(const SizedBox(height: 8));
      }

      if (orderModels.isNotEmpty) {
        sections.add(_buildSectionHeader('الطلبات'));
        for (var i = 0; i < orderModels.length; i++) {
          sections.add(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: _AnimatedOrderCard(
                key: ValueKey(orderModels[i].id),
                order: orderModels[i],
                index: i,
                docId: orderModels[i].id,
                userId: uid,
                onChanged: _loadOrders,
              ),
            ),
          );
        }
      }

      if (sections.isEmpty) {
        sections.add(_emptyState());
      }
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: kPrimaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: sections,
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showUpdateBadge)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, __) => Opacity(
              opacity: v,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'تم التحديث',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        const Text(
          'الطلبات الجارية',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    ),
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(CupertinoIcons.chevron_left, color: kPrimaryColor),
      onPressed: () => Navigator.pop(context),
    ),
  );

  Widget _notLoggedIn() => const Center(
    child: Text(
      'سجل دخولك لعرض طلبياتك',
      style: TextStyle(
        fontSize: 16,
        color: Color(0xFF6E6B7B),
        fontFamily: 'Amiri',
      ),
    ),
  );

  Widget _emptyState({String msg = 'لا توجد طلبات جارية'}) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kBgColor,
            boxShadow: _neuShadow(blur: 12, offset: 5),
          ),
          child: const Icon(
            CupertinoIcons.clock,
            color: kPrimaryColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          msg,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kTextColor,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(String title) => Padding(
  padding: const EdgeInsets.only(bottom: 6, top: 16),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: kPrimaryColor,
      fontFamily: 'Amiri',
    ),
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
//  _AnimatedOrderCard
// ══════════════════════════════════════════════════════════════════════════════
class _AnimatedOrderCard extends StatefulWidget {
  final Order order;
  final int index;
  final String docId, userId;
  final VoidCallback? onChanged;
  const _AnimatedOrderCard({
    super.key,
    required this.order,
    required this.index,
    required this.docId,
    required this.userId,
    this.onChanged,
  });
  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.65, curve: Curves.easeOut),
      ),
    );
    _scale = Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AnimatedOrderCard old) {
    super.didUpdateWidget(old);
    _ctrl.reset();
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _slide,
    child: FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: OrderCard(
          order: widget.order,
          docId: widget.docId,
          userId: widget.userId,
          onChanged: widget.onChanged,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  OrderCard — بطاقة الطلبية (Stream داخلي)
// ══════════════════════════════════════════════════════════════════════════════
class OrderCard extends StatefulWidget {
  final Order order;
  final String docId, userId;
  final VoidCallback? onChanged;
  const OrderCard({
    super.key,
    required this.order,
    required this.docId,
    required this.userId,
    this.onChanged,
  });
  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isConfirming = false;
  bool _isConfirmed = false;

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'في الانتظار ⏳';
      case OrderStatus.accepted:
        return 'تم القبول ✓';
      case OrderStatus.purchased:
        return 'تم الشراء 🛒';
      case OrderStatus.onway:
        return 'في الطريق 🚗';
      case OrderStatus.delivered:
        return 'تم التوصيل 🎉';
      case OrderStatus.cancelled:
        return 'ملغاة ✗';
    }
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return kWarningColor;
      case OrderStatus.accepted:
        return kSuccessColor;
      case OrderStatus.purchased:
        return Colors.blue;
      case OrderStatus.onway:
        return kPrimaryColor;
      case OrderStatus.delivered:
        return kSuccessColor;
      case OrderStatus.cancelled:
        return kDangerColor;
    }
  }

  Future<void> _hideOrder() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('حذف الطلبية', style: TextStyle(fontFamily: 'Amiri')),
        content: const Text(
          'سيتم إخفاء هذه الطلبية من قائمتك',
          style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Amiri')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.put('/api/orders/${widget.docId}/hide', {
      'userId': widget.userId,
    });
  }

  Future<void> _confirmReceipt() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      final currentOrder = await ApiClient.get('/api/orders/${widget.docId}');
      final alreadyConfirmed = currentOrder != null && currentOrder['customerConfirmed'] == true;
      if (!alreadyConfirmed) {
        await ApiClient.put('/api/orders/${widget.docId}', {
          'customerConfirmed': true,
          'status': 'delivered',
        });
      }
      if (widget.order.isFreeDelivery) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استلام الطلبية، شكراً لك!', style: const TextStyle(fontFamily: 'Amiri')),
              backgroundColor: kPrimaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        bool alreadyVerified = false;
        if (!alreadyConfirmed) {
          try {
            final userData = await ApiClient.put('/api/users/${widget.userId}/loyalty', {
              'driverId': widget.order.driverId,
              'orderId': widget.docId,
            }) as Map<String, dynamic>? ?? {};
            alreadyVerified = userData['isVerified'] ?? false;
          } catch (_) {}
        } else {
          alreadyVerified = true;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                alreadyVerified ? 'تم استلام الطلبية، شكراً لك!' : 'تم توثيق حسابك بنجاح، لن يظهر رقمك للسائقين بعد الآن',
                style: const TextStyle(fontFamily: 'Amiri')),
              backgroundColor: alreadyVerified ? kPrimaryColor : kSuccessColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تأكيد الاستلام: $e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _isConfirming = false;
        _isConfirmed = true;
      });
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;
    final counterOffer = order.counterOffer;
    final hasCounterOffer = counterOffer != null && counterOffer['status'] == 'pending';

        // ✅ هل فيه منتجات تغير سعرها؟
        final hasPriceChanges = order.items.any(
          (item) =>
              item.purchaseStatus == 'purchased' &&
              item.originalPrice != item.price,
        );

        final bool canTrack =
            order.status == OrderStatus.accepted ||
            order.status == OrderStatus.purchased ||
            order.status == OrderStatus.onway;

        final bool isDone =
            order.status == OrderStatus.delivered ||
            order.status == OrderStatus.cancelled;

        final Color statusColor = _statusColor(order.status);

        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => OrderDetailsSheet(
              order: order,
              docId: widget.docId,
              userId: widget.userId,
              onRefresh: () => setState(() {}),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: const [
                  Color(0xFFF5F4F9),
                  Color(0xFFEEECF5),
                  Color(0xFFE6E4F0),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: statusColor.withOpacity(0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: kNeumShadow.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: const Color(0xFFD8D7DE),
                  blurRadius: 10,
                  offset: const Offset(-4, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── الهيدر ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // ✅ زر حذف للطلبيات المنتهية فقط
                          if (isDone)
                            GestureDetector(
                              onTap: _hideOrder,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: kDangerColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  CupertinoIcons.trash,
                                  size: 14,
                                  color: kDangerColor,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // شارة الحالة
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  statusColor.withOpacity(0.15),
                                  statusColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _statusLabel(order.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '#${widget.docId.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: kTextColor,
                            ),
                          ),
                          Text(
                            order.time,
                            style: const TextStyle(
                              color: Color(0xFF6E6B7B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 10),

                  // ── شريط الحالة ───────────────────────────────────────
                  _StatusTracker(status: order.status),
                  const SizedBox(height: 12),

                  // ✅ بانر تعديل السعر
                  if (hasPriceChanges) _PriceChangedBanner(items: order.items),

                  // ✅ بانر البدائل غير المتوفرة
                  if (order.items.any((i) => i.purchaseStatus == 'unavailable' && i.alternativeStatus == 'pending' && i.alternativeName.isNotEmpty))
                    _UnavailableAlternativesBanner(
                      items: order.items,
                      orderId: widget.docId,
                      userId: widget.userId,
                      onRefresh: widget.onChanged ?? () => setState(() {}),
                    ),

                  // ── بانر عرض السعر المضاد من السائق ─────────────────
                  if (hasCounterOffer)
                    _CounterOfferBanner(
                      counterOffer: counterOffer!,
                      orderId: widget.docId,
                      userId: widget.userId,
              onRefresh: widget.onChanged ?? () => setState(() {}),
                    ),

                  // ── صور المنتجات ───────────────────────────────────────
                  if (order.items.isNotEmpty)
                    SizedBox(
                      height: 45,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: order.items.length,
                        itemBuilder: (context, i) {
                          final it = order.items[i];
                          final isReplaced = it.alternativeStatus == 'accepted';
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isReplaced ? Colors.green : Colors.grey.shade200),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Opacity(
                                    opacity: isReplaced ? 0.35 : 1,
                                    child: it.image.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: it.image,
                                            memCacheWidth: 90,
                                            fit: BoxFit.contain,
                                            errorWidget: (c, e, s) => const Icon(Icons.shopping_bag, size: 18),
                                          )
                                        : const Icon(Icons.shopping_bag, size: 18),
                                  ),
                                ),
                              ),
                              if (isReplaced)
                                Positioned(
                                  right: 4, bottom: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('بديل', style: TextStyle(color: Colors.white, fontSize: 7, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── الإجمالي + العنوان ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${order.total.toStringAsFixed(0)} DZD',
                          style: const TextStyle(
                            color: kPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                order.address.isNotEmpty
                                    ? order.address
                                    : 'غير محدد',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6E6B7B),
                                  fontFamily: 'Amiri',
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.location_fill,
                              color: kPrimaryColor,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── أزرار الإجراءات ────────────────────────────────────
                  const SizedBox(height: 12),

                  // زر التتبع
                  if (canTrack)
                    _ActionButton(
                      label: 'تتبع السائق المباشر',
                      icon: CupertinoIcons.location_solid,
                      gradient: const [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverTrackingScreen(
                            orderId: widget.docId,
                            userLat: order.userLat,
                            userLng: order.userLng,
                            driverLat: order.driverLat,
                            driverLng: order.driverLng,
                          ),
                        ),
                      ),
                    ),

                  // ✅ زر تغيير السائق (pending فقط)
                  if (order.status == OrderStatus.pending) ...[
                    const SizedBox(height: 8),
                    _ActionButton(
                      label: 'تغيير السائق',
                      icon: CupertinoIcons.arrow_2_circlepath,
                      gradient: const [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)],
                      onTap: () =>
                          _showChangeDriverSheet(context, order, widget.docId),
                    ),
                  ],

                  // ✅ زر إعادة الطلب (منتهية / ملغاة)
                  if (order.status == OrderStatus.cancelled || order.status == OrderStatus.delivered) ...[
                    const SizedBox(height: 8),
                    _ActionButton(
                      label: 'إعادة الطلب',
                      icon: CupertinoIcons.refresh_circled,
                      gradient: const [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1D8348)],
                      onTap: () =>
                          _reorderToCart(context, order, widget.docId),
                    ),
                  ],

                  // ✅ زر تم الاستلام (خارج الكارد)
                  if (order.status == OrderStatus.delivered && !order.customerConfirmed && !_isConfirmed && !order.isFreeDelivery) ...[
                    const SizedBox(height: 8),
                    _ActionButton(
                      label: _isConfirming ? 'جاري التأكيد...' : 'لقد استلمت الطلبية ✅',
                      icon: _isConfirming ? CupertinoIcons.hourglass : CupertinoIcons.check_mark_circled_solid,
                      gradient: _isConfirming
                        ? const [Color(0xFF95A5A6), Color(0xFF7F8C8D), Color(0xFF636E72)]
                        : const [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1D8348)],
                      onTap: _isConfirming ? () {} : () => _confirmReceipt(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
  }

  void _showChangeDriverSheet(BuildContext context, Order order, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeDriverSheet(
        orderId: docId,
        currentDriverId: order.driverId,
        isReorder: false,
      ),
    );
  }

  Future<void> _reorderToCart(BuildContext context, Order order, String docId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final storeId = order.items.isNotEmpty ? order.items.first.storeId : null;
      final storeName = order.items.isNotEmpty ? order.items.first.storeName : '';
      final templateName = order.items.isNotEmpty ? order.items.first.templateName : '';

      List<Map<String, dynamic>> apiProducts = [];
      try {
        final raw = storeId != null && storeId.isNotEmpty
            ? await ApiClient.getList('/api/products?storeId=$storeId')
            : await ApiClient.getList('/api/products');
        apiProducts = raw.cast<Map<String, dynamic>>();
      } catch (_) {}

      final List<Product> toAdd = [];
      final List<String> notFound = [];

      for (final item in order.items) {
        Map<String, dynamic>? match;
        for (final p in apiProducts) {
          if ((p['name'] as String? ?? '') == item.name) {
            match = p;
            break;
          }
        }

        if (match != null) {
          final pid = (match['_id'] ?? match['id'] ?? '') as String;
          toAdd.add(Product(
            productId: pid,
            name: item.name,
            price: item.price,
            imagePath: (match['image'] as String?) ?? item.image,
            capacite: item.capacite,
            description: match['description'] as String? ?? '',
            priceAffiche: (match['prixAffiche'] as String?) ?? '',
            storeId: storeId ?? '',
            storeName: storeName,
            templateName: templateName,
            uiStyle: item.uiStyle,
            sizes: item.sizes,
            extraImages: item.extraImages,
            variants: item.variants,
            quantity: item.quantity,
          ));
        } else {
          notFound.add(item.name);
        }
      }

      GlobalCart.provider.clear();
      for (final p in toAdd) {
        GlobalCart.provider.toggle(p);
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));

        String msg = '✅ تم إضافة ${toAdd.length} منتجات إلى السلة';
        if (notFound.isNotEmpty) {
          msg += '\n⚠️ غير متوفر: ${notFound.join('، ')}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
          backgroundColor: notFound.isEmpty ? const Color(0xFF27AE60) : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ تعذرت إعادة الطلب: $e', style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ _PriceChangedBanner — بانر تعديل السعر من السائق
// ══════════════════════════════════════════════════════════════════════════════
class _PriceChangedBanner extends StatelessWidget {
  final List<OrderItem> items;
  const _PriceChangedBanner({required this.items});

  @override
  Widget build(BuildContext context) {
    final changedItems = items
        .where(
          (i) => i.purchaseStatus == 'purchased' && i.originalPrice != i.price,
        )
        .toList();

    if (changedItems.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // العنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'تم تعديل سعر بعض المنتجات',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                color: Colors.orange,
                size: 15,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // تفاصيل المنتجات المعدلة
          ...changedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // السعر الجديد
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kSuccessColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.price.toInt()} DZD',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: kSuccessColor,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 12,
                      color: Colors.orange,
                    ),
                  ),
                  // السعر القديم
                  Text(
                    '${item.originalPrice.toInt()} DZD',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      decoration: TextDecoration.lineThrough,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextColor,
                        fontFamily: 'Amiri',
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
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

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ _ChangeDriverSheet — bottom sheet السائقين أون لاين
// ══════════════════════════════════════════════════════════════════════════════
class _ChangeDriverSheet extends StatefulWidget {
  final String orderId;
  final String? currentDriverId;
  final bool isReorder;

  const _ChangeDriverSheet({
    required this.orderId,
    required this.currentDriverId,
    required this.isReorder,
  });

  @override
  State<_ChangeDriverSheet> createState() => _ChangeDriverSheetState();
}

class _ChangeDriverSheetState extends State<_ChangeDriverSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedDriverId;
  bool _confirming = false;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  List<String> _cities = [];
  String? _selectedCity;
  bool _loadingDrivers = true;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _selectedDriverId = widget.currentDriverId;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _loadDrivers();
    _loadCities();
    SocketClient.on('driver:status_changed', _onDriverStatusChanged);
  }

  void _onDriverStatusChanged(_) => _loadDrivers();

  Future<void> _loadCities() async {
    try {
      final data = await ApiClient.getList('/api/drivers/cities?isOnline=true&vehicleType=motorcycle');
      if (mounted) setState(() => _cities = data.cast<String>());
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await ApiClient.getList('/api/drivers?isOnline=true&vehicleType=motorcycle');
      if (mounted) {
        setState(() {
          _drivers = drivers.cast<Map<String, dynamic>>();
          _applyFilter();
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  void _applyFilter() {
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _filteredDrivers = List.from(_drivers);
    } else {
      _filteredDrivers = _drivers.where((d) {
        final city = (d['cityName'] ?? '').toString().trim();
        return city == _selectedCity;
      }).toList();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    SocketClient.off('driver:status_changed', _onDriverStatusChanged);
    super.dispose();
  }

  Future<void> _confirmDriver() async {
    if (_selectedDriverId == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      await ApiClient.put('/api/orders/${widget.orderId}', {
        'driverId': _selectedDriverId,
        'status': 'pending',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✅ تم تغيير السائق بنجاح',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: kBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isReorder
                            ? kSuccessColor.withOpacity(0.1)
                            : kAccentColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isReorder
                            ? CupertinoIcons.refresh_circled
                            : CupertinoIcons.arrow_2_circlepath,
                        color: widget.isReorder ? kSuccessColor : kAccentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.isReorder ? 'إعادة الطلب' : 'تغيير السائق',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: kTextColor,
                              fontFamily: 'Amiri',
                            ),
                          ),
                          Text(
                            widget.isReorder
                                ? 'اختر سائقاً لإعادة إرسال الطلبية'
                                : 'اختر سائقاً آخر من المتاحين الآن',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextGrey,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_cities.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kNeumShadow.withOpacity(0.3)),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCity,
                      hint: const Text('فلترة حسب المدينة', style: TextStyle(fontFamily: 'Amiri', fontSize: 13, color: kTextGrey)),
                      underline: const SizedBox(),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      onChanged: (val) => setState(() { _selectedCity = val; _applyFilter(); }),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('جميع المدن', style: TextStyle(fontFamily: 'Amiri', fontSize: 13))),
                        ..._cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _loadingDrivers
                    ? const Center(
                        child: CupertinoActivityIndicator(color: kPrimaryColor),
                      )
                    : _filteredDrivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kBgColor,
                                    boxShadow: _neuShadow(blur: 10, offset: 4),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.car_fill,
                                    color: Colors.grey,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'لا يوجد سائقون متاحون الآن',
                                  style: TextStyle(
                                    color: kTextGrey,
                                    fontFamily: 'Amiri',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: _filteredDrivers.length,
                      itemBuilder: (_, i) {
                        final d = _filteredDrivers[i];
                        final driverId = d['uid'] as String? ?? d['_id'] as String? ?? d['id'] as String? ?? '';
                        final firstName = d['firstName'] as String? ?? '';
                        final lastName = d['lastName'] as String? ?? '';
                        final photoUrl = d['photoUrl'] as String?;
                        final deliveries = d['totalDeliveries'] as int? ?? 0;
                        final isSelected = _selectedDriverId == driverId;
                        final isCurrent = widget.currentDriverId == driverId;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedDriverId = driverId),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? kPrimaryColor.withOpacity(0.06)
                                  : kBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? kPrimaryColor
                                    : kNeumShadow.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: kPrimaryColor.withOpacity(0.2),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : _neuShadow(blur: 6, offset: 3),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? kPrimaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? kPrimaryColor
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (isCurrent) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: kWarningColor
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'الحالي',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: kWarningColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Amiri',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            '$firstName $lastName',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: kTextColor,
                                              fontFamily: 'Amiri',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$deliveries توصيلة',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: kTextGrey,
                                              fontFamily: 'Amiri',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            CupertinoIcons.star_fill,
                                            color: Color(0xFFFFC107),
                                            size: 11,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '4.${(deliveries % 9)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: kTextGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kBgColor,
                                    border: isSelected
                                        ? Border.all(
                                            color: kPrimaryColor,
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: _neuShadow(blur: 6, offset: 3),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/avatar.png',
                                      fit: BoxFit.cover,
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
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: GestureDetector(
                  onTap: (_selectedDriverId == null || _confirming)
                      ? null
                      : _confirmDriver,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: _selectedDriverId != null
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF6D22AC),
                                kPrimaryColor,
                                kAccentColor,
                              ],
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                            )
                          : null,
                      color: _selectedDriverId == null
                          ? Colors.grey.shade300
                          : null,
                      boxShadow: _selectedDriverId != null
                          ? [
                              BoxShadow(
                                color: kPrimaryColor.withOpacity(0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: _confirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.checkmark_shield_fill,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDriverId != null
                                      ? (widget.isReorder
                                            ? 'إعادة الطلب'
                                            : 'تأكيد السائق')
                                      : 'اختر سائقاً من القائمة',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Amiri',
                                    color: _selectedDriverId != null
                                        ? Colors.white
                                        : Colors.grey.shade600,
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
    );
  }

  Widget _driverInitial(String name) => Container(
    color: kPrimaryColor.withOpacity(0.1),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: kPrimaryColor,
          fontFamily: 'Amiri',
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ _ReportDriverSheet — الإبلاغ عن السائق
// ══════════════════════════════════════════════════════════════════════════════
class _ReportDriverSheet extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String userId;
  final String? driverName;

  const _ReportDriverSheet({
    required this.orderId,
    required this.driverId,
    required this.userId,
    this.driverName,
  });

  @override
  State<_ReportDriverSheet> createState() => _ReportDriverSheetState();
}

class _ReportDriverSheetState extends State<_ReportDriverSheet> {
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReport() async {
  if (_noteCtrl.text.trim().isEmpty || _sending) return;
  setState(() => _sending = true);

  try {
    final userData = await ApiClient.get('/api/users/${widget.userId}') as Map<String, dynamic>? ?? {};
    final String apiName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final String fullName = apiName.isNotEmpty ? apiName : (FirebaseAuth.instance.currentUser?.displayName ?? 'زبون');

    await ApiClient.post('/api/reports', {
      'type': 'customer_report',
      'driverId': widget.driverId,
      'driverName': widget.driverName,
      'userId': widget.userId,
      'userName': fullName,
      'orderId': widget.orderId,
      'reason': 'شكوى',
      'note': _noteCtrl.text.trim(),
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(' تم إرسال البلاغ بنجاح للإدارة', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Color(0xFF27AE60),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (mounted) setState(() => _sending = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kDangerColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.flag_fill,
                    color: kDangerColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الإبلاغ عن السائق',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      Text(
                        'اكتب تفاصيل البلاغ',
                        style: TextStyle(
                          fontSize: 11,
                          color: kTextGrey,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'تفاصيل البلاغ *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextGrey,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: kBgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _neuShadow(blur: 6, offset: 3),
                    ),
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: 5,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب تفاصيل البلاغ...',
                        hintStyle: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          fontFamily: 'Amiri',
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.text_bubble,
                          color: kPrimaryColor,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: (_noteCtrl.text.trim().isEmpty || _sending)
                        ? null
                        : _sendReport,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _noteCtrl.text.trim().isNotEmpty
                            ? LinearGradient(
                                colors: [kDangerColor, Colors.red.shade700],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                              )
                            : null,
                        color: _noteCtrl.text.trim().isEmpty
                            ? Colors.grey.shade300
                            : null,
                        boxShadow: _noteCtrl.text.trim().isNotEmpty
                            ? [
                                BoxShadow(
                                  color: kDangerColor.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    CupertinoIcons.flag_fill,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _noteCtrl.text.trim().isNotEmpty
                                        ? 'إرسال البلاغ'
                                        : 'اكتب تفاصيل البلاغ أولاً',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Amiri',
                                      color: _noteCtrl.text.trim().isNotEmpty
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✅ _DriverInfoSheet — معلومات السائق وطلبياته
// ══════════════════════════════════════════════════════════════════════════════
class _DriverInfoSheet extends StatefulWidget {
  final String driverId;
  const _DriverInfoSheet({required this.driverId});
  @override
  State<_DriverInfoSheet> createState() => _DriverInfoSheetState();
}

class _DriverInfoSheetState extends State<_DriverInfoSheet> {
  List<Map<String, dynamic>> _completedOrders = [];
  Map<String, dynamic>? _driverData;
  bool _loading = true;
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  double _calcDeliveryFees = 0;
  double _totalOrderValue = 0;
  double _cash = 0;
  double _hold = 0;
  double _commissionPercent = 0;
  double _lastReset = 0;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/api/drivers/${widget.driverId}'),
        ApiClient.getList('/api/orders?driverId=${widget.driverId}&status=delivered'),
        ApiClient.get('/api/config'),
      ]);
      if (!mounted) return;
      final driver = results[0] as Map<String, dynamic>? ?? {};
      final orders = (results[1] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final config = results[2] as Map<String, dynamic>? ?? {};
      double fees = 0;
      double ordersTotal = 0;
      for (final o in orders) {
        fees += (o['deliveryFee'] as num? ?? 0).toDouble();
        ordersTotal += (o['total'] as num? ?? 0).toDouble();
      }
      final vType = (driver['vehicleType'] as String? ?? '').replaceAll(' ', '_');
      final commissionKey = 'commission_$vType';
      final commissionPercent = (config[commissionKey] as num? ??
              config['defaultCommissionPercent'] as num? ??
              0)
          .toDouble();
      setState(() {
        _driverData = driver;
        _completedOrders = orders;
        _totalEarnings = (driver['totalEarnings'] as num? ?? 0).toDouble();
        _totalDeliveries = (driver['totalDeliveries'] as int? ?? 0);
        _calcDeliveryFees = fees;
        _totalOrderValue = ordersTotal;
        _cash = (driver['cash'] as num? ?? 0).toDouble();
        _hold = (driver['hold'] as num? ?? 0).toDouble();
        _commissionPercent = commissionPercent;
        _lastReset = (driver['lastCommissionResetEarnings'] as num? ?? 0).toDouble();
        _discount = (driver['discount'] as num? ?? 0).toDouble();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _calcCommission => _cash * _commissionPercent / 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.person_fill, color: kPrimaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _driverData != null
                            ? '${_driverData!['firstName'] ?? ''} ${_driverData!['lastName'] ?? ''}'.trim()
                            : 'معلومات السائق',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextColor, fontFamily: 'Amiri'),
                      ),
                      Text(
                        '$_totalDeliveries توصيلة',
                        style: const TextStyle(fontSize: 11, color: kTextGrey, fontFamily: 'Amiri'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: CupertinoActivityIndicator(color: kPrimaryColor)))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kPrimaryColor.withOpacity(0.12), kPrimaryColor.withOpacity(0.04)],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('الرصيد المالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimaryColor, fontFamily: 'Amiri')),
                          const SizedBox(height: 12),
                          _finRow('القيمة الإجمالية للطلبيات', '${_totalOrderValue.toStringAsFixed(0)} د.ج', kTextColor, bold: true),
                          const SizedBox(height: 8),
                          _finRow('إجمالي الأرباح (التوصيل فقط)', '${_totalEarnings.toStringAsFixed(0)} د.ج', kPrimaryColor),
                          const SizedBox(height: 8),
                          _finRow('النقدي', '${_cash.toStringAsFixed(0)} د.ج', Colors.green),
                          const SizedBox(height: 8),
                          _finRow('المحجوز', '${_hold.toStringAsFixed(0)} د.ج', Colors.orange.shade700),
                          const SizedBox(height: 8),
                          if (_discount > 0) ...[
                            _finRow('الخصم', '-${_discount.toStringAsFixed(0)} د.ج', Colors.red),
                            const SizedBox(height: 8),
                          ],
                          _finRow('العمولة (${_commissionPercent.toInt()}%)', '${_calcCommission.toStringAsFixed(0)} د.ج', Colors.red.shade400),
                          if (_totalEarnings > 0) ...[
                            const SizedBox(height: 12),
                            Divider(color: kPrimaryColor.withOpacity(0.2), height: 1),
                            const SizedBox(height: 10),
                            _finRow('الصافي', '${(_totalEarnings - _discount - _calcCommission).toStringAsFixed(0)} د.ج', kTextColor, bold: true),
                          ],
                        ],
                      ),
                    ),

                    if (_completedOrders.isEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          Icon(CupertinoIcons.tray, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('لا توجد طلبيات منجزة بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)),
                        ],
                      )
                    else ...[
                      const Text('آخر الطلبيات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextGrey, fontFamily: 'Amiri')),
                      const SizedBox(height: 8),
                      ..._completedOrders.take(10).map((o) {
                        final items = (o['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final deliveryFee = (o['deliveryFee'] as num? ?? 0).toDouble();
                        final userName = o['userName'] as String? ?? 'زبون';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${deliveryFee.toInt()} دينار', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontFamily: 'Amiri')),
                                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor, fontFamily: 'Amiri')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...items.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '• ${item['name'] ?? ''} x${item['quantity'] ?? 1}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Amiri'),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              )),
                              if (items.length > 3)
                                Text('+${items.length - 3} منتجات أخرى', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'Amiri')),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _finRow(String label, String value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color, fontFamily: 'Amiri')),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Amiri')),
      ],
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
//  OrderDetailsSheet
// ══════════════════════════════════════════════════════════════════════════════
class OrderDetailsSheet extends StatefulWidget {
  final Order order;
  final String docId, userId;
  final VoidCallback onRefresh;

  const OrderDetailsSheet({
    super.key,
    required this.order,
    required this.docId,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<OrderDetailsSheet> createState() => OrderDetailsSheetState();
}

class OrderDetailsSheetState extends State<OrderDetailsSheet> {
  bool _cancelling = false;
  bool _isConfirming = false;
  Timer? _debounce;
  Timer? _refreshTimer;
  late Order _order;
  bool get canUserEdit => _order.status == OrderStatus.pending;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    SocketClient.on('order:updated', _onOrderUpdated);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshOrder();
    });
    _refreshOrder();
  }

  void _onOrderUpdated(dynamic data) {
    if (!mounted) return;
    if (data is Map && data['_id'] == widget.docId) {
      _refreshOrder();
    }
  }

  Future<void> _refreshOrder() async {
    try {
      final data = await ApiClient.get('/api/orders/${widget.docId}');
      if (data != null && mounted) {
        setState(() {
          _order = OrderModel.fromDoc(data, widget.docId);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    SocketClient.off('order:updated', _onOrderUpdated);
    _refreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _onItemChanged() {
    setState(() {});
    widget.onRefresh();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _saveItems);
  }

  Future<void> _saveItems() async {
    final itemsData = _order.items
        .map(
          (i) => {
            'name': i.name,
            'prix': i.originalPrice,
            'price': i.originalPrice,
            'finalPrice': i.price,
            'image': i.image,
            'quantity': i.quantity,
            'totalItem': i.price * i.quantity,
            'purchaseStatus': i.purchaseStatus,
            'alternativeName': i.alternativeName,
            'alternativePrice': i.alternativePrice,
            'alternativeStatus': i.alternativeStatus,
            'storeName': i.storeName,
            'storeId': i.storeId,
            'templateName': i.templateName,
            'uiStyle': i.uiStyle,
            'capacite': i.capacite,
          },
        )
        .toList();
    try {
      await ApiClient.put('/api/orders/${widget.docId}', {
        'items': itemsData,
        'subtotal': _order.subtotal,
        'total': _order.subtotal + _order.deliveryFee,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _cancelOrder() async {
    final TextEditingController reasonCtrl = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: kBgColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: kDangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.xmark_circle_fill,
                color: kDangerColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'إلغاء الطلبية',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'أخبرنا لماذا تود إلغاء الطلبية؟\nهذا يساعد السائق على فهم السبب.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 13,
                color: kTextGrey,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: kNeumShadow.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 5,
                    offset: Offset(-2, -2),
                  ),
                ],
              ),
              child: TextField(
                controller: reasonCtrl,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'اكتب السبب هنا (مثلاً: غيرت رأيي، تأخر السائق...)',
                  hintStyle: TextStyle(color: Color(0xFFB8B1C8), fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'تراجع',
                    style: TextStyle(fontFamily: 'Amiri', color: kTextGrey),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (reasonCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يرجى كتابة سبب الإلغاء',
                            style: TextStyle(fontFamily: 'Amiri'),
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDangerColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'تأكيد الإلغاء',
                    style: TextStyle(fontFamily: 'Amiri', color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _cancelling = true);

    try {
      final String reason = reasonCtrl.text.trim();
      String customerName = "زبون";
      final userData = await ApiClient.get('/api/users/${user?.uid}') as Map<String, dynamic>?;
      if (userData != null) {
        customerName =
            userData['name'] ?? userData['userName'] ?? "زبون";
      }

      await ApiClient.put('/api/orders/${widget.docId}', {
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledBy': user?.uid,
        'cancelledByName': customerName,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (widget.order.driverId != null) {
  await ApiClient.post('/api/notifications', {
    'toId': widget.order.driverId,
    'orderId': widget.docId,
    'title': '❌ قام الزبون بإلغاء الطلبية',
    'body': 'سبب الإلغاء: $reason',
    'type': 'order_cancelled',
    'createdAt': DateTime.now().toIso8601String(),
    'isRead': false,
    'hiddenFor': [],
  });
  try {
    await ApiClient.post('/api/notify-driver', {
      'driverId': widget.order.driverId,
      'title': '❌ قام الزبون بإلغاء الطلبية',
      'body': 'سبب الإلغاء: $reason',
      'data': {'orderId': widget.docId, 'type': 'order_cancelled'},
    });
  } catch (_) {}
  }

      if (mounted) {
        setState(() => _cancelling = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم إلغاء الطلبية وإشعار السائق',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: kPrimaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductSheet(
        existingItems: _order.items,
        onAdd: (item) async {
          final existing = _order.items
              .where((i) => i.name == item.name)
              .firstOrNull;
          if (existing != null)
            existing.quantity++;
          else
            _order.items.add(item);
          _onItemChanged();
        },
      ),
    );
  }

  void _showEditAddress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressPickerSheet(
        userId: widget.userId,
        docId: widget.docId,
        currentAddress: _order.address,
        onSelected: (newAddress) async {
          setState(() => _order.address = newAddress);
          widget.onRefresh();
          await ApiClient.put('/api/orders/${widget.docId}', {
            'address': newAddress,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        },
      ),
    );
  }

  void _showChangeDriver() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeDriverSheet(
        orderId: widget.docId,
        currentDriverId: _order.driverId,
        isReorder: false,
      ),
    );
  }

  void _showReport() {
    if (_order.driverId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDriverSheet(
        orderId: widget.docId,
        driverId: _order.driverId!,
        userId: widget.userId,
        driverName: _order.driverName,
      ),
    );
  }



Future<void> _confirmReceiptByCustomer() async {
  if (_isConfirming) return;
  setState(() => _isConfirming = true);

  bool alreadyConfirmed = false;
  try {
    final currentOrder = await ApiClient.get('/api/orders/${widget.docId}');
    alreadyConfirmed = currentOrder != null && currentOrder['customerConfirmed'] == true;
  } catch (_) {}

  setState(() => _order = Order(
    id: _order.id,
    items: _order.items,
    deliveryFee: _order.deliveryFee,
    status: _order.status,
    time: _order.time,
    address: _order.address,
    driverName: _order.driverName,
    customerConfirmed: true,
    magasinId: _order.magasinId,
    driverId: _order.driverId,
    driverLat: _order.driverLat,
    driverLng: _order.driverLng,
    userLat: _order.userLat,
    userLng: _order.userLng,
    isFreeDelivery: _order.isFreeDelivery,
  ));
  bool orderUpdated = false;
  if (!alreadyConfirmed) {
    try {
      await ApiClient.put('/api/orders/${widget.docId}', {
        'customerConfirmed': true,
        'status': 'delivered',
      });
      orderUpdated = true;
    } catch (e) {
      setState(() => _isConfirming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تأكيد الاستلام: $e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } else {
    orderUpdated = true;
  }
  if (_order.isFreeDelivery) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استلام الطلبية، شكراً لك!',
            style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _isConfirming = false);
    return;
  }

  bool loyaltyUpdated = false;
  if (!alreadyConfirmed) {
    try {
      final userData = await ApiClient.put('/api/users/${widget.userId}/loyalty', {
        'driverId': _order.driverId,
        'orderId': widget.docId,
      }) as Map<String, dynamic>? ?? {};
      final bool alreadyVerified = userData['isVerified'] ?? false;
      loyaltyUpdated = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alreadyVerified ? 'تم استلام الطلبية، شكراً لك!' : 'تم توثيق حسابك بنجاح، لن يظهر رقمك للسائقين بعد الآن',
              style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: alreadyVerified ? kPrimaryColor : kSuccessColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
    if (mounted && !orderUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث الولاء: $e', style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  if (mounted) {
    Navigator.pop(context);
    widget.onRefresh();
  }
}
}

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${widget.docId.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Row(
                  children: [
                    Text(
                      'طلبيتي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('🛍️', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                children: [
                  // ── المنتجات ─────────────────────────────────────────
                  _glassBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (canUserEdit)
                              GestureDetector(
                                onTap: _showAddProduct,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimaryColor.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.add,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'إضافة منتج',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              const SizedBox(),
                            const Text(
                              'المنتجات',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._order.items.map(
                          (item) => _CartStyleItemRow(
                            item: item,
                            canEdit: canUserEdit,
                            orderId: widget.docId,
                            userId: widget.userId,
                            onRefresh: widget.onRefresh,
                            onChanged: _onItemChanged,
                            onDelete: () {
                              setState(() => _order.items.remove(item));
                              widget.onRefresh();
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 800),
                                _saveItems,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── الأسعار ──────────────────────────────────────────
                  _glassBox(
                    child: Column(
                      children: [
                        _priceRow(
                          'سعر المنتجات',
                          '${_order.subtotal.toStringAsFixed(0)} DZD',
                          kTextColor,
                        ),
                        const SizedBox(height: 10),
                        _priceRow(
                          'سعر التوصيل',
                          '${_order.deliveryFee.toStringAsFixed(0)} DZD',
                          Colors.black54,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        _priceRow(
                          'الإجمالي',
                          '${_order.total.toStringAsFixed(0)} DZD',
                          kPrimaryColor,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── العنوان ──────────────────────────────────────────
                  _glassBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        canUserEdit
                            ? GestureDetector(
                                onTap: _showEditAddress,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimaryColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.pencil,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'تعديل',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.lock_fill,
                                color: Color(0xFFB8B1C8),
                                size: 16,
                              ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'موقع التوصيل',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6E6B7B),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _order.address.isNotEmpty
                                      ? _order.address
                                      : 'غير محدد',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kTextColor,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.location_fill,
                          size: 18,
                          color: kPrimaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_order.status == OrderStatus.pending) ...[
                    _ActionButton(
                      label: 'تغيير السائق',
                      icon: CupertinoIcons.arrow_2_circlepath,
                      gradient: [kPrimaryColor, kAccentColor],
                      onTap: _showChangeDriver,
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (_order.status == OrderStatus.delivered && !_order.customerConfirmed && !_order.isFreeDelivery)
  Padding(
    padding: const EdgeInsets.only(top: 10),
    child: _ActionButton(
      label: _isConfirming ? 'جاري التأكيد...' : 'لقد استلمت الطلبية ✅',
      icon: _isConfirming ? CupertinoIcons.hourglass : CupertinoIcons.check_mark_circled_solid,
      gradient: _isConfirming 
        ? [Color(0xFF95A5A6), Color(0xFF7F8C8D), Color(0xFF636E72)]
        : const [Color(0xFF2ECC71), Color(0xFF27AE60), Color(0xFF1D8348)],
      onTap: _isConfirming ? () {} : () => _confirmReceiptByCustomer(),
    ),
  ),

                  if (_order.driverId != null) ...[
                    GestureDetector(
                      onTap: _showReport,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kBgColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: kDangerColor.withOpacity(0.25),
                          ),
                          boxShadow: _neuShadow(blur: 6, offset: 3),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.flag,
                              color: kDangerColor,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'الإبلاغ عن السائق',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kDangerColor,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (_order.canCancel)
                    GestureDetector(
                      onTap: _cancelling ? null : _cancelOrder,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: kBgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _neuShadow(blur: 8, offset: 4),
                        ),
                        child: _cancelling
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.redAccent,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.xmark_circle,
                                    color: Colors.red.shade400,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'إلغاء الطلبية',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade400,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.lock_fill,
                            color: Color(0xFFB8B1C8),
                            size: 15,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'لا يمكن إلغاء الطلبية بعد قبول السائق',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black38,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ],
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

  Widget _glassBox({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kBgColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: kNeumShadow.withOpacity(0.6),
          blurRadius: 10,
          offset: const Offset(4, 4),
        ),
        BoxShadow(
          color: const Color(0xFFD8D7DE),
          blurRadius: 10,
          offset: const Offset(-4, -4),
        ),
      ],
    ),
    child: child,
  );

  Widget _priceRow(
    String label,
    String value,
    Color color, {
    bool bold = false,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: bold ? 16 : 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: color,
          fontFamily: 'Amiri',
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: bold ? 16 : 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: Colors.black54,
          fontFamily: 'Amiri',
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ActionButton
// ══════════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DriverTrackingScreen
// ══════════════════════════════════════════════════════════════════════════════
class DriverTrackingScreen extends StatefulWidget {
  final String orderId;
  final double? userLat, userLng, driverLat, driverLng;
  const DriverTrackingScreen({
    super.key,
    required this.orderId,
    this.userLat,
    this.userLng,
    this.driverLat,
    this.driverLng,
  });
  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  LatLng? _driverPos, _userPos, _targetPos;
  double _distanceMeters = 0;
  int _etaMinutes = 0;
  bool _notifSent = false;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  String _storeName = '', _driverName = '', _driverPhoto = '';
  List<Map<String, dynamic>> _items = [];
  double _deliveryFee = 0;
  double _avgSpeedKmh = 30;
  Timer? _pollTimer;

  double get _avgSpeedMps => _avgSpeedKmh / 3.6;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (widget.driverLat != null)
      _driverPos = LatLng(widget.driverLat!, widget.driverLng!);
    if (widget.userLat != null)
      _userPos = LatLng(widget.userLat!, widget.userLng!);
    _listenToDriverLocation();
    _updateMapElements();
    _loadOrderDetails();
    SocketClient.on('order:updated', _onMapOrderUpdated);
  }

  Future<void> _loadOrderDetails() async {
    try {
      final data = await ApiClient.get('/api/orders/${widget.orderId}');
      if (data != null && mounted) {
        final driverId = data['driverId'] as String?;
        String dName = '', dPhoto = '';
        if (driverId != null) {
          try {
            final driverData = await ApiClient.get('/api/drivers/$driverId');
            if (driverData != null) {
              dName = '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'.trim();
              dPhoto = driverData['photoUrl'] as String? ?? '';
            }
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _storeName = data['items'] is List && data['items'].isNotEmpty
                ? (data['items'][0]['storeName'] as String? ?? '')
                : '';
            _items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            _deliveryFee = (data['deliveryFee'] as num? ?? 0).toDouble();
            _driverName = dName;
            _driverPhoto = dPhoto;
            _resolveTarget();
          });
          _updateMapElements();
          _checkDistance();
        }
      }
    } catch (_) {}
  }

  void _resolveTarget() {
    if (_items.isEmpty || _driverPos == null) {
      _targetPos = _userPos;
      return;
    }
    // Get unique unpurchased store positions
    final stores = <LatLng>[];
    final seen = <String>{};
    for (final item in _items) {
      if ((item['purchaseStatus'] as String? ?? '') == 'purchased') continue;
      final lat = (item['storeLat'] as num?)?.toDouble();
      final lng = (item['storeLng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final key = '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
      if (seen.add(key)) stores.add(LatLng(lat, lng));
    }

    if (stores.isEmpty) { _targetPos = _userPos; return; }
    if (stores.length == 1 || _userPos == null) { _targetPos = stores.first; return; }

    if (stores.length >= 5) {
      // Nearest-neighbor heuristic for 5+ stores
      _targetPos = _nearestNeighbor(stores);
    } else {
      // TSP exact optimal for <5 stores
      var best = stores;
      var bestDist = double.infinity;
      for (final perm in _permutations(stores)) {
        var dist = Geolocator.distanceBetween(
          _driverPos!.latitude, _driverPos!.longitude,
          perm.first.latitude, perm.first.longitude,
        );
        for (var i = 0; i < perm.length - 1; i++) {
          dist += Geolocator.distanceBetween(
            perm[i].latitude, perm[i].longitude,
            perm[i + 1].latitude, perm[i + 1].longitude,
          );
        }
        dist += Geolocator.distanceBetween(
          perm.last.latitude, perm.last.longitude,
          _userPos!.latitude, _userPos!.longitude,
        );
        if (dist < bestDist) { bestDist = dist; best = perm; }
      }
      _targetPos = best.first;
    }
  }

  List<List<T>> _permutations<T>(List<T> items) {
    if (items.length <= 1) return [List<T>.from(items)];
    final result = <List<T>>[];
    for (var i = 0; i < items.length; i++) {
      final rest = <T>[...items.take(i), ...items.skip(i + 1)];
      for (final perm in _permutations(rest)) {
        result.add([items[i], ...perm]);
      }
    }
    return result;
  }

  LatLng _nearestNeighbor(List<LatLng> stores) {
    var remaining = List<LatLng>.from(stores);
    var current = _driverPos!;
    LatLng? closest;
    var minDist = double.infinity;
    for (final s in remaining) {
      final d = Geolocator.distanceBetween(
        current.latitude, current.longitude,
        s.latitude, s.longitude,
      );
      if (d < minDist) { minDist = d; closest = s; }
    }
    return closest ?? stores.first;
  }

  String? _trackedDriverId;

  void _listenToDriverLocation() async {
    try {
      final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
      if (!mounted) return;
      final driverId = orderData['driverId'] as String?;
      if (driverId == null) return;

      _trackedDriverId = driverId;
      SocketClient.join('track_driver_$driverId');

      // جلب موقع السائق الحالي من وثيقة السائق
      try {
        final driverData = await ApiClient.get('/api/drivers/$driverId');
        if (mounted && driverData != null) {
          final lat = driverData['lat'] as num?;
          final lng = driverData['lng'] as num?;
          if (lat != null && lng != null) {
            setState(() {
              _driverPos = LatLng(lat.toDouble(), lng.toDouble());
            });
            _updateMapElements();
            _checkDistance();
          }
        }
      } catch (_) {}

      // تحديث دوري كاحتياطي في حال انقطاع socket
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (!mounted) return;
        try {
          final driverData = await ApiClient.get('/api/drivers/$driverId');
          if (mounted && driverData != null) {
            final lat = driverData['lat'] as num?;
            final lng = driverData['lng'] as num?;
            if (lat != null && lng != null) {
              setState(() {
                _driverPos = LatLng(lat.toDouble(), lng.toDouble());
              });
              _updateMapElements();
              _checkDistance();
            }
          }
        } catch (_) {}
      });

      SocketClient.on('driver:location_updated', _onDriverLocationUpdated);
    } catch (_) {}
  }

  void _updateMapElements() {
    if (!mounted) return;
    _resolveTarget();
    final nm = <Marker>{};
    final np = <Polyline>{};
    if (_driverPos != null)
      nm.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: const InfoWindow(title: 'السائق'),
        ),
      );
    if (_targetPos != null && _userPos != null &&
        (_targetPos!.latitude != _userPos!.latitude ||
         _targetPos!.longitude != _userPos!.longitude)) {
      nm.add(
        Marker(
          markerId: const MarkerId('target'),
          position: _targetPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'المتجر الحالي'),
        ),
      );
    }
    if (_userPos != null)
      nm.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _userPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقع التوصيل'),
        ),
      );
    if (_driverPos != null && _targetPos != null) {
      np.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_driverPos!, _targetPos!],
          color: kPrimaryColor,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }
    setState(() {
      _markers
        ..clear()
        ..addAll(nm);
      _polylines
        ..clear()
        ..addAll(np);
    });
    if (_mapCtrl != null && _driverPos != null && _targetPos != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_driverPos!.latitude, _targetPos!.latitude),
          math.min(_driverPos!.longitude, _targetPos!.longitude),
        ),
        northeast: LatLng(
          math.max(_driverPos!.latitude, _targetPos!.latitude),
          math.max(_driverPos!.longitude, _targetPos!.longitude),
        ),
      );
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  void _checkDistance() {
    if (_driverPos == null || _targetPos == null) return;
    final dist = Geolocator.distanceBetween(
      _driverPos!.latitude,
      _driverPos!.longitude,
      _targetPos!.latitude,
      _targetPos!.longitude,
    );
    final eta = _avgSpeedMps > 0 ? (dist / _avgSpeedMps / 60).round() : 0;
    setState(() {
      _distanceMeters = dist;
      _etaMinutes = eta;
    });
    if (dist <= 50 && !_notifSent) {
      _notifSent = true;
      HapticFeedback.heavyImpact();
    }
  }

  String _formatDistance() => _distanceMeters < 1000
      ? '${_distanceMeters.toStringAsFixed(0)} م'
      : '${(_distanceMeters / 1000).toStringAsFixed(1)} كم';

  String _formatETA() {
    if (_distanceMeters <= 0) return '...';
    if (_etaMinutes < 1) return 'أقل من دقيقة';
    if (_etaMinutes < 60) return '≈ $_etaMinutes دقيقة';
    final h = _etaMinutes ~/ 60;
    final m = _etaMinutes % 60;
    return '≈ $h س $m د';
  }

  String _estimatedArrival() {
    if (_distanceMeters <= 0) return '';
    final arrival = DateTime.now().add(Duration(minutes: _etaMinutes));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return 'يصل حوالي $h:$m';
  }

  void _onMapOrderUpdated(_) {
    if (mounted) _loadOrderDetails();
  }

  void _onDriverLocationUpdated(data) {
    if (!mounted || _trackedDriverId == null) return;
    if (data['driverId'] != _trackedDriverId) return;
    setState(() {
      _driverPos = LatLng(data['lat'], data['lng']);
    });
    _updateMapElements();
    _checkDistance();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapCtrl?.dispose();
    _pollTimer?.cancel();
    if (_trackedDriverId != null) {
      SocketClient.leave('track_driver_$_trackedDriverId');
    }
    SocketClient.off('driver:location_updated', _onDriverLocationUpdated);
    SocketClient.off('order:updated', _onMapOrderUpdated);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = _driverPos ?? _userPos ?? const LatLng(36.7538, 3.0588);
    final statusSteps = ['accepted', 'purchased', 'onway', 'delivered'];
    final stepLabels = ['قبول', 'شراء', 'توصيل', 'استلام'];
    final currentIdx = statusSteps.indexOf('onway');
    return Scaffold(
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              _updateMapElements();
            },
          ),
          // ── Top bar ──────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kBgColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _neuShadow(blur: 6, offset: 2),
                          ),
                          child: const Icon(CupertinoIcons.chevron_left, color: kPrimaryColor, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تتبع السائق',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri', color: kTextColor,
                          ),
                        ),
                      ),
                      // ETA chip
                      if (_distanceMeters > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9232E8), Color(0xFF7D29C6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatETA(),
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.bold, fontFamily: 'Amiri',
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.clock, color: Colors.white, size: 12),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Transform.scale(
                          scale: _pulse.value,
                          child: Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'مباشر',
                        style: TextStyle(fontSize: 11, color: Colors.green, fontFamily: 'Amiri'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Bottom panel ─────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20, 20, 20,
                    MediaQuery.of(context).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 44, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Store + Driver row
                      Row(
                        children: [
                          if (_driverName.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _driverName,
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: kTextColor, fontFamily: 'Amiri',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kPrimaryColor.withOpacity(0.1),
                                    border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      'assets/images/avatar.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(width: 1, height: 24, color: Colors.grey.shade300),
                                const SizedBox(width: 12),
                              ],
                            ),
                          Icon(CupertinoIcons.bag_fill, color: kPrimaryColor, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _storeName.isNotEmpty ? _storeName : 'الطلبية',
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold,
                                color: kTextColor, fontFamily: 'Amiri',
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Progress steps
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kPrimaryColor.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: List.generate(stepLabels.length, (i) {
                            final isActive = i <= currentIdx;
                            final isLast = i == stepLabels.length - 1;
                            return Expanded(
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive ? kSuccessColor : Colors.grey.shade300,
                                        ),
                                        child: Center(
                                          child: isActive
                                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                                              : Text('${i + 1}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        stepLabels[i],
                                        style: TextStyle(
                                          fontSize: 9, fontFamily: 'Amiri',
                                          color: isActive ? kSuccessColor : Colors.grey.shade400,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        height: 2,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: i < currentIdx ? kSuccessColor : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ETA + Distance + Arrival
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            _infoTile('المسافة', _distanceMeters > 0 ? _formatDistance() : '...', CupertinoIcons.location_fill, kPrimaryColor),
                            Container(width: 1, height: 44, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8)),
                            _infoTile('الوقت المتبقي', _distanceMeters > 0 ? _formatETA() : '...', CupertinoIcons.clock_fill, Colors.orange),
                            Container(width: 1, height: 44, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 8)),
                            _infoTile('وقت الوصول', _distanceMeters > 0 ? _estimatedArrival() : '...', CupertinoIcons.flag_fill, kSuccessColor),
                          ],
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
    );
  }

  Widget _infoTile(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13,
                color: color, fontFamily: 'Amiri',
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9, color: Color(0xFF6E6B7B), fontFamily: 'Amiri',
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }



// ══════════════════════════════════════════════════════════════════════════════
//  _CartStyleItemRow — مع badge تعديل السعر
// ══════════════════════════════════════════════════════════════════════════════
class _CartStyleItemRow extends StatefulWidget {
  final OrderItem item;
  final bool canEdit;
  final String orderId;
  final String userId;
  final VoidCallback onChanged, onDelete;
  final VoidCallback? onRefresh;
  const _CartStyleItemRow({
    required this.item,
    required this.canEdit,
    required this.orderId,
    required this.userId,
    required this.onChanged,
    required this.onDelete,
    this.onRefresh,
  });

  @override
  State<_CartStyleItemRow> createState() => _CartStyleItemRowState();
}

class _CartStyleItemRowState extends State<_CartStyleItemRow> {
  bool _altLoading = false;
  Timer? _altTimer;
  int _altRemainingSeconds = 120;

  static final Map<String, int> _savedTimers = {};
  static final Map<String, int> _savedStartTimestamps = {};

  OrderItem get item => widget.item;

  String get _timerKey => '${widget.orderId}_${item.name}';

  @override
  void initState() {
    super.initState();
    if (_hasPendingAlternative) _restoreOrStartTimer();
  }

  @override
  void didUpdateWidget(_CartStyleItemRow old) {
    super.didUpdateWidget(old);
    if (_hasPendingAlternative && (_altTimer == null || !_altTimer!.isActive)) {
      _restoreOrStartTimer();
    } else if (!_hasPendingAlternative) {
      _altTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _altTimer?.cancel();
    if (_altRemainingSeconds > 0) {
      _savedTimers[_timerKey] = _altRemainingSeconds;
    }
    super.dispose();
  }

  void _restoreOrStartTimer() {
    final key = _timerKey;
    final savedTimestamp = _savedStartTimestamps[key];
    if (savedTimestamp != null) {
      final elapsed = ((DateTime.now().millisecondsSinceEpoch - savedTimestamp) ~/ 1000);
      final remaining = 120 - elapsed;
      if (remaining <= 0) {
        _autoRejectAlternative();
        return;
      }
      _altRemainingSeconds = remaining;
    } else {
      _savedStartTimestamps[key] = DateTime.now().millisecondsSinceEpoch;
      _altRemainingSeconds = 120;
    }
    _startAltTimer();
  }

  void _startAltTimer() {
    _altTimer?.cancel();
    _altTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _altRemainingSeconds--;
        if (_altRemainingSeconds <= 0) {
          timer.cancel();
          _savedStartTimestamps.remove(_timerKey);
          _savedTimers.remove(_timerKey);
          _autoRejectAlternative();
        }
      });
    });
  }

  Future<void> _autoRejectAlternative() async {
    if (_altLoading) return;
    try {
      final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
      final List items = List.from(orderData['items'] as List? ?? []);
      final idx = items.indexWhere((i) => (i is Map) && (i['name'] == item.name));
      if (idx == -1) return;
      items[idx]['alternativeStatus'] = 'rejected';
      await ApiClient.put('/api/orders/${widget.orderId}', {'items': items, 'updatedAt': DateTime.now().toIso8601String()});
      widget.onChanged();
    } catch (_) {}
  }
  bool get canEdit => widget.canEdit;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;

  bool get _isPizza => item.name.contains('|');

  bool get _priceChanged =>
      item.purchaseStatus == 'purchased' &&
      item.originalPrice != item.price;

  bool get _hasPendingAlternative =>
      widget.item.purchaseStatus == 'unavailable' &&
      widget.item.alternativeStatus == 'pending' &&
      widget.item.alternativeName.isNotEmpty;

  bool get _isUnavailable =>
      widget.item.purchaseStatus == 'unavailable' &&
      (widget.item.alternativeStatus.isEmpty ||
          widget.item.alternativeStatus == 'rejected');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _isUnavailable
            ? kDangerColor.withOpacity(0.05)
            : _hasPendingAlternative
                ? kWarningColor.withOpacity(0.05)
                : kBgColor,
        border: _priceChanged
            ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5)
            : _isUnavailable
                ? Border.all(color: kDangerColor.withOpacity(0.3), width: 1.2)
                : _hasPendingAlternative
                    ? Border.all(
                        color: kWarningColor.withOpacity(0.3), width: 1.2)
                    : null,
        boxShadow: [
          BoxShadow(
            color: kNeumShadow.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_priceChanged)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle,
                      color: Colors.orange, size: 12),
                  const SizedBox(width: 5),
                  Text(
                    'تم تعديل السعر: ${widget.item.originalPrice.toInt()} ← ${widget.item.price.toInt()} DZD',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          if (_isUnavailable)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kDangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kDangerColor.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.xmark_circle_fill,
                      color: kDangerColor, size: 12),
                  SizedBox(width: 5),
                  Text(
                    'غير متوفر',
                    style: TextStyle(
                      fontSize: 10,
                      color: kDangerColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          _isPizza ? _buildPizzaItem() : _buildNormalItem(isReplaced: _hasPendingAlternative, isAccepted: widget.item.alternativeStatus == 'accepted'),
          if (_hasPendingAlternative) _buildAlternativeSection(),
        ],
      ),
    );
  }
  Widget _buildAlternativeSection() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWarningColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWarningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('بديل مقترح من السائق',
                  style: TextStyle(
                      fontSize: 11,
                      color: kWarningColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kWarningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('في انتظار موافقتك',
                    style: TextStyle(
                        fontSize: 10,
                        color: kWarningColor,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Amiri')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${widget.item.name}" لم يجده السائق، البديل المقترح:',
            style: const TextStyle(
              fontSize: 11,
              color: kTextGrey,
              fontFamily: 'Amiri',
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.photo, color: Colors.grey, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.item.alternativeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontFamily: 'Amiri',
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.item.alternativePrice.toInt()} DZD',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPizzaItem() {
    final parts = item.name.split('|').map((s) => s.trim()).toList();
    final pizzaName = parts.isNotEmpty ? parts[0] : item.name;
    final pizzaSize = parts.length > 1 ? parts[1] : '';
    final pizzaTops = parts.length > 2 ? parts[2] : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: item.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.image,
                    memCacheWidth: 144,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Center(
                      child: Text('🍕', style: TextStyle(fontSize: 28)),
                    ),
                  )
                : const Center(
                    child: Text('🍕', style: TextStyle(fontSize: 28)),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pizzaName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                  fontFamily: 'Amiri',
                ),
                textAlign: TextAlign.right,
              ),
              if (pizzaSize.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📏 $pizzaSize',
                    style: const TextStyle(
                      fontSize: 11,
                      color: kPrimaryColor,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (pizzaTops.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '🧀 $pizzaTops',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontFamily: 'Amiri',
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (canEdit)
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'حذف',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    '${item.price.toStringAsFixed(0)} DZD',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalItem({bool isReplaced = false, bool isAccepted = false}) {
    if (isAccepted) {
      return Column(
        children: [
          Row(
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: kDangerColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.image,
                          fit: BoxFit.contain,
                          memCacheWidth: 150,
                          color: Colors.black38,
                          colorBlendMode: BlendMode.saturation,
                          placeholder: (_, __) => const Center(
                            child: CupertinoActivityIndicator(radius: 10),
                          ),
                          errorWidget: (_, __, ___) =>
                              const Icon(CupertinoIcons.bag, color: kDangerColor),
                        )
                      : const Icon(CupertinoIcons.bag, color: kDangerColor, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black38,
                        fontFamily: 'Amiri',
                        decoration: TextDecoration.lineThrough,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kDangerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'محذوف',
                        style: TextStyle(
                          color: kDangerColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Text(
                    '× ${item.quantity}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'بديل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.alternativeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.alternativePrice.toInt()} DZD',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (isReplaced) {
      return Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: kDangerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.contain,
                      memCacheWidth: 150,
                      color: Colors.black38,
                      colorBlendMode: BlendMode.saturation,
                      placeholder: (_, __) => const Center(
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                      errorWidget: (_, __, ___) =>
                          const Icon(CupertinoIcons.bag, color: kDangerColor),
                    )
                  : const Icon(CupertinoIcons.bag, color: kDangerColor, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                    fontFamily: 'Amiri',
                    decoration: TextDecoration.lineThrough,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kDangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'غير متوفر',
                    style: const TextStyle(
                      color: kDangerColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text(
                '× ${item.quantity}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: item.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.contain,
                    memCacheWidth: 150,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const Center(
                      child: CupertinoActivityIndicator(radius: 10),
                    ),
                    errorWidget: (_, __, ___) =>
                        const Icon(CupertinoIcons.bag, color: kPrimaryColor),
                  )
                : const Icon(CupertinoIcons.bag, color: kPrimaryColor, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                  fontFamily: 'Amiri',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
              if (item.categoryName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.categoryName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Amiri',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '${(item.price * item.quantity).toStringAsFixed(0)} DZD',
                style: const TextStyle(
                  color: kPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Amiri',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          children: [
            if (canEdit)
              Container(
                decoration: BoxDecoration(
                  color: kBgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _neuShadow(blur: 6, offset: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(Icons.remove, () {
                      if (item.quantity > 1) {
                        item.quantity--;
                        onChanged();
                      }
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                    _qtyBtn(Icons.add, () {
                      item.quantity++;
                      onChanged();
                    }),
                  ],
                ),
              )
            else
              Text(
                '× ${item.quantity}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            const SizedBox(height: 8),
            if (canEdit)
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'حذف',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _neuShadow(blur: 4, offset: 2),
      ),
      child: Icon(icon, size: 16, color: kPrimaryColor),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _AddProductSheet
// ══════════════════════════════════════════════════════════════════════════════
class _AddProductSheet extends StatefulWidget {
  final List<OrderItem> existingItems;
  final Function(OrderItem) onAdd;
  const _AddProductSheet({required this.existingItems, required this.onAdd});
  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool _searching = false;
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String q) async {
    final trimmed = q.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final allProducts = await ApiClient.getList('/api/products');
      final Map<String, Map<String, dynamic>> merged = {};
      for (final doc in allProducts) {
        final d = doc as Map<String, dynamic>;
        final name = (d['name'] as String? ?? '').toLowerCase();
        final tags = (d['tags'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
        if (name.contains(trimmed) || tags.any((t) => t.contains(trimmed))) {
          final docId = d['_id'] as String? ?? '';
          merged[docId] = {
            'name': d['name'] ?? '',
            'price': (d['prix'] ?? d['price'] ?? 0 as num).toDouble(),
            'image': d['image'] ?? '',
            'id': docId,
          };
        }
      }
      if (mounted)
        setState(() {
          _results = merged.values.toList();
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: const BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'إضافة منتج للطلبية',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: kBgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _neuShadow(blur: 6, offset: 3),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن منتج...',
                hintStyle: TextStyle(color: Color(0xFF6E6B7B), fontSize: 13, fontFamily: 'Amiri'),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: kPrimaryColor,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CupertinoActivityIndicator(color: kPrimaryColor),
              )
            else if (_query.isNotEmpty && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد نتائج',
                  style: TextStyle(
                    color: Color(0xFF6E6B7B),
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    final already = widget.existingItems.any(
                      (e) => e.name == p['name'],
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: already
                                ? null
                                : () {
                                    widget.onAdd(
                                      OrderItem(
                                        name: p['name'],
                                        price: p['price'],
                                        originalPrice: p['price'],
                                        image: p['image'] ?? '',
                                        uiStyle: (p['uiStyle'] as int?) ?? 1,
                                        capacite: p['capacite'] as String? ?? '',
                                        templateName: p['templateName'] as String? ?? '',
                                        storeName: p['storeName'] as String? ?? '',
                                        storeId: p['storeId'] as String? ?? '',
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: already
                                    ? Colors.grey.shade300
                                    : kPrimaryColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: already
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: kPrimaryColor.withOpacity(
                                            0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                              ),
                              child: Text(
                                already ? 'موجود ✓' : 'إضافة',
                                style: TextStyle(
                                  color: already
                                      ? Colors.grey.shade600
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p['name'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: kTextColor,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                  Text(
                                    '${(p['price'] as double).toStringAsFixed(0)} DZD',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kPrimaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              if ((p['image'] as String).isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: p['image'],
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 80,
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _AddressPickerSheet
// ══════════════════════════════════════════════════════════════════════════════
class _AddressPickerSheet extends StatefulWidget {
  final String userId, currentAddress, docId;
  final Function(String) onSelected;
  const _AddressPickerSheet({
    required this.userId,
    required this.docId,
    required this.currentAddress,
    required this.onSelected,
  });
  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  List<Map<String, dynamic>> _locations = [];
  int _selectedIndex = -1;
  bool _loading = true, _useMap = false;
  String _mapAddress = '';
  double? _selectedLat, _selectedLng;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    if (LocationsCache.isValid(widget.userId)) {
      _updateSelection(LocationsCache.data);
      return;
    }
    try {
      final listData = await ApiClient.getList('/api/saved-locations?userId=${widget.userId}');
      final list = listData
          .map(
            (doc) {
              final d = doc as Map<String, dynamic>;
              return {
              'label': d['label'] as String? ?? '',
              'address': d['address'] as String? ?? '',
              'type': d['type'] as String? ?? 'other',
              'lat': d['lat'],
              'lng': d['lng'],
            };},

          )
          .toList();
      LocationsCache.set(widget.userId, list);
      _updateSelection(list);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateSelection(List<Map<String, dynamic>> list) {
    int sel = -1;
    for (int i = 0; i < list.length; i++) {
      if (list[i]['address'] == widget.currentAddress) {
        sel = i;
        break;
      }
    }
    if (mounted)
      setState(() {
        _locations = list;
        _selectedIndex = sel;
        _loading = false;
      });
  }

  void _confirm() async {
    final addr = _useMap ? _mapAddress : _locations[_selectedIndex]['address']!;
    widget.onSelected(addr);
    await ApiClient.put('/api/orders/${widget.docId}', {
          'address': addr,
          'userLat': _useMap ? _selectedLat : _locations[_selectedIndex]['lat'],
          'userLng': _useMap ? _selectedLng : _locations[_selectedIndex]['lng'],
          'updatedAt': DateTime.now().toIso8601String(),
        });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'تغيير موقع التوصيل',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                  fontFamily: 'Amiri',
                ),
              ),
              SizedBox(width: 8),
              Icon(
                CupertinoIcons.location_fill,
                color: kPrimaryColor,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CupertinoActivityIndicator(color: kPrimaryColor),
            )
          else ...[
            ..._locations.asMap().entries.map((e) {
              final i = e.key;
              final loc = e.value;
              final isSel = !_useMap && _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedIndex = i;
                  _useMap = false;
                }),
                child: _buildAddressCard(
                  label: loc['label'],
                  address: loc['address'],
                  icon: _iconFromType(loc['type']),
                  isSelected: isSel,
                ),
              );
            }),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final res = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                );
                if (res != null && mounted)
                  setState(() {
                    _useMap = true;
                    _selectedIndex = -1;
                    _mapAddress = res['address'];
                    _selectedLat = res['lat'];
                    _selectedLng = res['lng'];
                  });
              },
              child: _buildAddressCard(
                label: 'تحديد من الخريطة',
                address: _useMap && _mapAddress.isNotEmpty
                    ? _mapAddress
                    : 'اضغط لفتح الخريطة',
                icon: CupertinoIcons.map_fill,
                isSelected: _useMap,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_selectedIndex >= 0 || (_useMap && _mapAddress.isNotEmpty))
                    ? _confirm
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'تأكيد الموقع الجديد',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard({
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
        color: isSelected ? kPrimaryColor : kBgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : _neuShadow(blur: 6, offset: 3),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.white : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: kPrimaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Icon(
            icon,
            color: isSelected ? Colors.white70 : kPrimaryColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : kTextColor,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white70 : Colors.black45,
                    fontFamily: 'Amiri',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFromType(String type) {
    if (type == 'home') return CupertinoIcons.house_fill;
    if (type == 'work') return CupertinoIcons.briefcase_fill;
    return CupertinoIcons.location_fill;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _StatusTracker — ✅ يدعم purchased كمرحلة مستقلة
// ══════════════════════════════════════════════════════════════════════════════
class _StatusTracker extends StatelessWidget {
  final OrderStatus status;
  const _StatusTracker({required this.status});

  int get _step {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.purchased:
        return 2; // ✅ مرحلة مستقلة
      case OrderStatus.onway:
        return 3;
      case OrderStatus.delivered:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      (CupertinoIcons.clock, 'انتظار'),
      (CupertinoIcons.checkmark_circle, 'قبول'),
      (CupertinoIcons.cart_fill, 'شراء'), // ✅ مرحلة purchased
      (CupertinoIcons.car_fill, 'طريق'),
      (CupertinoIcons.bag_fill_badge_plus, 'وصول'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineIdx = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: _step > lineIdx ? kPrimaryColor : Colors.grey.shade300,
              ),
            );
          }
          final idx = i ~/ 2;
          final isCompleted = idx <= _step;
          final isCurrent = idx == _step;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isCurrent ? 32 : 24,
                height: isCurrent ? 32 : 24,
                decoration: BoxDecoration(
                  color: isCompleted ? kPrimaryColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? kPrimaryColor : Colors.grey.shade300,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  steps[idx].$1,
                  size: isCurrent ? 16 : 12,
                  color: isCompleted ? Colors.white : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[idx].$2,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? kPrimaryColor : Colors.grey.shade400,
                  fontFamily: 'Amiri',
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _UnavailableAlternativesBanner
// ══════════════════════════════════════════════════════════════════════════════
class _UnavailableAlternativesBanner extends StatefulWidget {
  final List<OrderItem> items;
  final String orderId;
  final String userId;
  final VoidCallback onRefresh;

  const _UnavailableAlternativesBanner({
    required this.items,
    required this.orderId,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<_UnavailableAlternativesBanner> createState() =>
      _UnavailableAlternativesBannerState();
}

class _UnavailableAlternativesBannerState
    extends State<_UnavailableAlternativesBanner> {
  bool _loading = false;
  final Set<String> _respondedItems = {};
  final Map<String, Timer> _itemTimers = {};
  final Map<String, int> _itemRemaining = {};

  static final Map<String, int> _savedStartTimestamps = {};

  String _timerKey(String itemName) => '${widget.orderId}_$itemName';

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  @override
  void didUpdateWidget(_UnavailableAlternativesBanner old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) _respondedItems.clear();
    _startTimers();
  }

  @override
  void dispose() {
    for (final t in _itemTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _startTimers() {
    final pendingItems = widget.items
        .where((i) =>
            i.purchaseStatus == 'unavailable' &&
            i.alternativeStatus == 'pending' &&
            i.alternativeName.isNotEmpty)
        .toList();
    for (final item in pendingItems) {
      if (!_itemTimers.containsKey(item.name)) {
        final key = _timerKey(item.name);
        final savedTimestamp = _savedStartTimestamps[key];
        if (savedTimestamp != null) {
          final elapsed = ((DateTime.now().millisecondsSinceEpoch - savedTimestamp) ~/ 1000);
          final remaining = 120 - elapsed;
          if (remaining <= 0) {
            _autoRejectAlternative(item.name);
            continue;
          }
          _itemRemaining[item.name] = remaining;
        } else {
          _savedStartTimestamps[key] = DateTime.now().millisecondsSinceEpoch;
          _itemRemaining[item.name] = 120;
        }
        _itemTimers[item.name] = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() {
            _itemRemaining[item.name] = (_itemRemaining[item.name] ?? 120) - 1;
            if ((_itemRemaining[item.name] ?? 0) <= 0) {
              timer.cancel();
              _savedStartTimestamps.remove(_timerKey(item.name));
              _autoRejectAlternative(item.name);
            }
          });
        });
      }
    }
  }

  Future<void> _autoRejectAlternative(String itemName) async {
    try {
      final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
      final List items = List.from(orderData['items'] as List? ?? []);
      final idx = items.indexWhere(
        (i) => i['name'] == itemName && i['purchaseStatus'] == 'unavailable',
      );
      if (idx == -1) return;
      items[idx]['alternativeStatus'] = 'rejected';
      await ApiClient.put('/api/orders/${widget.orderId}', {
        'items': items,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      widget.onRefresh();
    } catch (_) {}
  }

  Future<void> _respond(String itemName, bool accepted) async {
    setState(() {
      _loading = true;
      _respondedItems.add(itemName);
    });
    try {
      final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
      final List items = List.from(orderData['items'] as List? ?? []);
      final idx = items.indexWhere(
        (i) => i['name'] == itemName && i['purchaseStatus'] == 'unavailable',
      );
      if (idx == -1) return;
      if (accepted) {
        items[idx]['alternativeStatus'] = 'accepted';
        items[idx]['purchaseStatus'] = 'purchased';
        items[idx]['finalPrice'] = items[idx]['alternativePrice'];
      } else {
        items[idx]['alternativeStatus'] = 'rejected';
      }
      double newSubtotal = items.fold(0.0, (sum, item) {
        final ps = item['purchaseStatus'] as String? ?? '';
        if (ps == 'unavailable') return sum;
        final p = (item['finalPrice'] ?? item['price'] ?? item['prix'] ?? 0.0) as num;
        final q = (item['quantity'] ?? 1) as int;
        return sum + p.toDouble() * q;
      });
      await ApiClient.put('/api/orders/${widget.orderId}', {
        'items': items,
        'subtotal': newSubtotal,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      widget.onRefresh();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pendingItems = widget.items
        .where((i) =>
            i.purchaseStatus == 'unavailable' &&
            i.alternativeStatus == 'pending' &&
            i.alternativeName.isNotEmpty &&
            !_respondedItems.contains(i.name))
        .toList();
    if (pendingItems.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kWarningColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: kWarningColor.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'بدائل مقترحة من السائق في انتظار موافقتك',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kWarningColor,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.exclamationmark_circle_fill,
                  color: kWarningColor, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          ...pendingItems.map(
            (item) {
              final remaining = _itemRemaining[item.name] ?? 120;
              final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
              final seconds = (remaining % 60).toString().padLeft(2, '0');
              final timerColor = remaining <= 30 ? kDangerColor : kWarningColor;

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '"${item.name}" لم يجده السائق',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                          fontFamily: 'Amiri',
                          decoration: TextDecoration.lineThrough,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(CupertinoIcons.photo, color: Colors.grey, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.alternativeName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.alternativePrice.toInt()} DZD',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: timerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: timerColor),
                                const SizedBox(width: 4),
                                Text('$minutes:$seconds',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: timerColor,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Amiri')),
                              ],
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _respond(item.name, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)],
                                        begin: Alignment.centerRight,
                                        end: Alignment.centerLeft,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kPrimaryColor.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Text('موافق',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Amiri')),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _respond(item.name, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE53935), Color(0xFFC62828), Color(0xFFB71C1C)],
                                        begin: Alignment.centerRight,
                                        end: Alignment.centerLeft,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kDangerColor.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Text('رفض',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Amiri')),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CounterOfferBanner
// ══════════════════════════════════════════════════════════════════════════════
class _CounterOfferBanner extends StatefulWidget {
  final Map<String, dynamic> counterOffer;
  final String orderId;
  final String userId;
  final VoidCallback? onRefresh;

  const _CounterOfferBanner({
    required this.counterOffer,
    required this.orderId,
    required this.userId,
    this.onRefresh,
  });

  @override
  State<_CounterOfferBanner> createState() => _CounterOfferBannerState();
}

class _CounterOfferBannerState extends State<_CounterOfferBanner> {
  bool _loading = false;

  Future<void> _acceptOffer() async {
    setState(() => _loading = true);
    final price = (widget.counterOffer['proposedPrice'] as num? ?? 0)
        .toDouble();
    final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
    final subtotal = (orderData['subtotal'] as num? ?? 0).toDouble();
    await ApiClient.put('/api/orders/${widget.orderId}', {
      'deliveryFee': price,
      'total': subtotal + price,
      'counterOffer': {
        ...(orderData['counterOffer'] as Map<String, dynamic>? ?? {}),
        'status': 'accepted'
      },
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      widget.counterOffer['status'] = 'accepted';
      SocketClient.emit('order:updated', {
        '_id': widget.orderId,
        'counterOffer.status': 'accepted',
      });
      if (widget.onRefresh != null) widget.onRefresh!();
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectOffer() async {
    setState(() => _loading = true);
    await ApiClient.put('/api/orders/${widget.orderId}', {
      'counterOffer.status': 'rejected',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      widget.counterOffer['status'] = 'rejected';
      SocketClient.emit('order:updated', {
        '_id': widget.orderId,
        'counterOffer.status': 'rejected',
      });
      if (widget.onRefresh != null) widget.onRefresh!();
      setState(() => _loading = false);
    }
  }

  Future<void> _chooseOtherDriver() async {
    setState(() => _loading = true);
    await ApiClient.put('/api/orders/${widget.orderId}', {
      'counterOffer.status': 'rejected',
      'driverId': null,
      'status': 'pending',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      widget.counterOffer['status'] = 'rejected';
      SocketClient.emit('order:updated', {
        '_id': widget.orderId,
        'counterOffer.status': 'rejected',
      });
      if (widget.onRefresh != null) widget.onRefresh!();
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.counterOffer['driverName'] as String? ?? 'السائق';
    final proposedPrice = (widget.counterOffer['proposedPrice'] as num? ?? 0)
        .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor.withOpacity(0.08),
            kPrimaryColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'عرض سعر من السائق',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: kWarningColor,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.money_dollar_circle_fill,
                color: kWarningColor,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$driverName يقترح سعر توصيل: ${proposedPrice.toInt()} DA',
            style: const TextStyle(
              fontSize: 13,
              color: kTextColor,
              fontFamily: 'Amiri',
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: CupertinoActivityIndicator(color: kWarningColor),
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _acceptOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccessColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'قبول السعر الجديد: ${proposedPrice.toInt()} DA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _rejectOffer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: kBgColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _neuShadow(blur: 5, offset: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'رفض العرض',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Amiri',
                                color: kDangerColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _chooseOtherDriver,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: kBgColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _neuShadow(blur: 5, offset: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'اختر سائقاً آخر',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Amiri',
                                color: kPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TransportCard — بطاقة طلبية نقل (تاكسي / هارباني / فورغو)
// ══════════════════════════════════════════════════════════════════════════════

class TransportCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onChanged;

  const TransportCard({
    super.key,
    required this.data,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<TransportCard> createState() => _TransportCardState();
}

class _TransportCardState extends State<TransportCard> {
  bool _counterLoading = false;

  Color get _accentColor {
    final type = widget.data['transportType'] as String? ?? '';
    if (type.contains('سيارة') || type.contains('taxi')) return const Color(0xFFE65100);
    if (type.contains('هارباني') || type.contains('minibus')) return const Color(0xFF00695C);
    if (type.contains('فورغو') || type.contains('truck')) return const Color(0xFF4527A0);
    return kPrimaryColor;
  }

  IconData get _serviceIcon {
    final type = widget.data['transportType'] as String? ?? '';
    if (type.contains('سيارة') || type.contains('taxi')) return CupertinoIcons.car_fill;
    if (type.contains('هارباني') || type.contains('minibus')) return CupertinoIcons.bus;
    if (type.contains('فورغو') || type.contains('truck')) return CupertinoIcons.cube_box;
    return CupertinoIcons.car_fill;
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'pending': return 'في الانتظار ⏳';
      case 'accepted': return 'تم القبول ✓';
      case 'on_way': return 'في الطريق 🚗';
      case 'onway': return 'في الطريق 🚗';
      case 'delivered': return 'تم التوصيل 🎉';
      case 'cancelled': return 'ملغاة ✗';
      default: return s ?? '...';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'pending': return kWarningColor;
      case 'accepted': return kSuccessColor;
      case 'on_way': return kPrimaryColor;
      case 'onway': return kPrimaryColor;
      case 'delivered': return kSuccessColor;
      case 'cancelled': return kDangerColor;
      default: return Colors.grey;
    }
  }

  Future<void> _acceptOffer(double proposedPrice) async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final coDriverName = co?['driverName'] as String? ?? '';
      final userName = d['userName'] as String? ?? 'الزبون';
      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'price': proposedPrice,
        'status': 'accepted',
        'driverId': coDriverId,
        'driverName': coDriverName,
        'counterOffer.status': 'accepted',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      d['status'] = 'accepted';
      d['price'] = proposedPrice;
      d['driverId'] = coDriverId;
      d['driverName'] = coDriverName;
      if (co != null) co['status'] = 'accepted';
      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '💰 $userName قبل عرض السعر الجديد',
            'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
            'data': {'orderId': widget.docId, 'type': 'counter_accepted'},
          });
        } catch (_) {}
      }
      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _rejectOffer() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final userName = d['userName'] as String? ?? 'الزبون';
      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (co != null) co['status'] = 'rejected';
      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '❌ $userName رفض عرض السعر',
            'body': '',
            'data': {'orderId': widget.docId, 'type': 'counter_rejected'},
          });
        } catch (_) {}
      }
      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? 'pending';
    final color = _statusColor(status);
    final typeLabel = d['transportType'] as String? ?? '';
    final rejectedBy = List<String>.from(d['rejectedBy'] ?? []);
    final rejectionReason = d['rejectionReason'] as String?;
    final counterOffer = d['counterOffer'] as Map<String, dynamic>?;
    final hasPendingCounter = counterOffer != null && (counterOffer['status'] as String? ?? '') == 'pending';
    final proposedPrice = (counterOffer?['proposedPrice'] as num? ?? 0).toDouble();
    final coDriverName = counterOffer?['driverName'] as String? ?? 'السائق';

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TransportDetailsSheet(
          data: d,
          docId: widget.docId,
          onChanged: widget.onChanged,
        ),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kNeumShadow.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                      color: color,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_serviceIcon, color: _accentColor, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: kTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(CupertinoIcons.location, d['fromAddress'] as String? ?? ''),
            const SizedBox(height: 4),
            _infoRow(CupertinoIcons.arrow_right_circle_fill, d['toAddress'] as String? ?? ''),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(d['price'] as num? ?? 0).toStringAsFixed(0)} DZD',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kPrimaryColor,
                    fontFamily: 'Amiri',
                  ),
                ),
                if (d['driverName'] != null)
                  Row(
                    children: [
                      Text(
                        d['driverName'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.person_fill, size: 14, color: Colors.grey),
                    ],
                  ),
              ],
            ),
            if (hasPendingCounter) ...[
              const SizedBox(height: 12),
              _buildCounterOffer(d, proposedPrice, coDriverName),
            ],
            if (rejectedBy.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kDangerColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kDangerColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          rejectionReason ?? 'السائق رفض الطلب',
                          style: TextStyle(fontSize: 12, color: kDangerColor.withOpacity(0.8), fontFamily: 'Amiri'),
                        ),
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.exclamationmark_bubble, color: kDangerColor, size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showChangeDriverSheet(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.arrow_2_circlepath, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'اختر سائقاً آخر',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Amiri'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCounterOffer(Map<String, dynamic> d, double proposedPrice, String coDriverName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withOpacity(0.08), kPrimaryColor.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.money_dollar_circle_fill, color: kWarningColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${proposedPrice.toInt()} DZD',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kWarningColor, fontFamily: 'Amiri'),
                  ),
                ],
              ),
              Text(
                'عرض سعر من $coDriverName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextColor, fontFamily: 'Amiri'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_counterLoading)
            const Center(child: CupertinoActivityIndicator(color: kPrimaryColor))
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _acceptOffer(proposedPrice),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('قبول',
                              style: const TextStyle(fontSize: 13, fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _rejectOffer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.xmark_circle_fill, color: kDangerColor, size: 16),
                          const SizedBox(width: 6),
                          Text('رفض',
                              style: const TextStyle(fontSize: 13, fontFamily: 'Amiri', color: kDangerColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showChangeDriverSheet(BuildContext context) {
    final d = widget.data;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransportDetailsSheet(
        data: d,
        docId: widget.docId,
        onChanged: widget.onChanged,
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontFamily: 'Amiri', color: kTextColor),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: Colors.grey.shade500),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ServiceOrderCard — بطاقة طلبية توصيل/إحضار
// ══════════════════════════════════════════════════════════════════════════════

class ServiceOrderCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onChanged;

  const ServiceOrderCard({
    super.key,
    required this.data,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<ServiceOrderCard> createState() => _ServiceOrderCardState();
}

class _ServiceOrderCardState extends State<ServiceOrderCard> {
  bool _counterLoading = false;
  bool get _isDelivery => widget.data['serviceType'] == 'delivery';

  Color get _accentColor => _isDelivery ? kPrimaryColor : const Color(0xFF283593);

  IconData get _serviceIcon => _isDelivery ? CupertinoIcons.cube_box_fill : CupertinoIcons.bag_fill;

  String _serviceLabel(bool isDelivery) => isDelivery ? 'توصيل' : 'إحضار';

  String _statusLabel(String? s) {
    switch (s) {
      case 'pending': return 'في الانتظار';
      case 'accepted': return 'تم القبول';
      case 'on_way': return 'في الطريق';
      case 'onway': return 'في الطريق';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغاة';
      default: return s ?? '...';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'pending': return kWarningColor;
      case 'accepted': return kSuccessColor;
      case 'on_way': return kPrimaryColor;
      case 'onway': return kPrimaryColor;
      case 'delivered': return kSuccessColor;
      case 'cancelled': return kDangerColor;
      default: return Colors.grey;
    }
  }

  Future<void> _acceptOffer(double proposedPrice) async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final coDriverName = co?['driverName'] as String? ?? '';
      final customerName = d['userName'] as String? ?? 'الزبون';
      final serviceType = d['serviceType'] as String? ?? '';
      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'price': proposedPrice,
        'status': 'accepted',
        'driverId': coDriverId,
        'driverName': coDriverName,
        'counterOffer.status': 'accepted',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      d['status'] = 'accepted';
      d['price'] = proposedPrice;
      d['driverId'] = coDriverId;
      d['driverName'] = coDriverName;
      if (co != null) co['status'] = 'accepted';
      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '💰 $customerName قبل عرض السعر الجديد',
            'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
            'data': {'orderId': widget.docId, 'type': 'counter_accepted'},
          });
        } catch (_) {}
      }
      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _rejectOffer() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final customerName = d['userName'] as String? ?? 'الزبون';
      final serviceType = d['serviceType'] as String? ?? '';
      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (co != null) co['status'] = 'rejected';
      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '❌ $customerName رفض عرض السعر',
            'body': '',
            'data': {'orderId': widget.docId, 'type': 'counter_rejected'},
          });
        } catch (_) {}
      }
      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? 'pending';
    final color = _statusColor(status);
    final counterOffer = d['counterOffer'] as Map<String, dynamic>?;
    final hasPendingCounter = counterOffer != null && (counterOffer['status'] as String? ?? '') == 'pending';
    final proposedPrice = (counterOffer?['proposedPrice'] as num? ?? 0).toDouble();
    final coDriverName = counterOffer?['driverName'] as String? ?? 'السائق';

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ServiceOrderDetailsSheet(
          data: d,
          docId: widget.docId,
          onChanged: widget.onChanged,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.12), width: 1.2),
          boxShadow: [
            BoxShadow(color: kNeumShadow.withOpacity(0.5), blurRadius: 10, offset: const Offset(4, 4)),
            BoxShadow(color: const Color(0xFFD8D7DE), blurRadius: 10, offset: const Offset(-4, -4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: color),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_serviceIcon, color: _accentColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _serviceLabel(_isDelivery),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: kTextColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow(CupertinoIcons.location, d['fromAddress'] as String? ?? ''),
              const SizedBox(height: 4),
              _infoRow(CupertinoIcons.arrow_right_circle_fill, d['toAddress'] as String? ?? ''),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(d['price'] as num? ?? 0).toStringAsFixed(0)} DZD',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor, fontFamily: 'Amiri'),
                  ),
                  if (d['driverName'] != null)
                    Row(
                      children: [
                        Text(d['driverName'] as String,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.person_fill, size: 14, color: Colors.grey),
                      ],
                    ),
                ],
              ),
              if (hasPendingCounter) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kPrimaryColor.withOpacity(0.08), kPrimaryColor.withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kPrimaryColor.withOpacity(0.35), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.money_dollar_circle_fill, color: kWarningColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${proposedPrice.toInt()} DZD',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kWarningColor, fontFamily: 'Amiri'),
                              ),
                            ],
                          ),
                          Text(
                            'عرض سعر من $coDriverName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextColor, fontFamily: 'Amiri'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_counterLoading)
                        const Center(child: CupertinoActivityIndicator(color: kPrimaryColor))
                      else
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _acceptOffer(proposedPrice),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text('قبول',
                                          style: const TextStyle(fontSize: 13, fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: _rejectOffer,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.xmark_circle_fill, color: kDangerColor, size: 16),
                                      const SizedBox(width: 6),
                                      Text('رفض',
                                          style: const TextStyle(fontSize: 13, fontFamily: 'Amiri', color: kDangerColor, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (d['status'] == 'cancelled') ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    try {
                      await ApiClient.put('/api/service-orders/${widget.docId}', {
                        'status': 'pending',
                        'driverId': null,
                        'rejectedBy': null,
                        'rejectionReason': null,
                        'updatedAt': DateTime.now().toIso8601String(),
                      });
                      widget.onChanged();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red.shade700),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF27AE60).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.refresh_circled, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('إعادة الطلب', style: TextStyle(fontSize: 13, fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, fontFamily: 'Amiri', color: kTextColor),
              textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: Colors.grey.shade500),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ServiceOrderDetailsSheet — تفاصيل طلبية توصيل/إحضار
// ══════════════════════════════════════════════════════════════════════════════

class ServiceOrderDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onChanged;

  const ServiceOrderDetailsSheet({
    super.key,
    required this.data,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<ServiceOrderDetailsSheet> createState() => _ServiceOrderDetailsSheetState();
}

class _ServiceOrderDetailsSheetState extends State<ServiceOrderDetailsSheet> {
  bool _cancelling = false;
  bool _counterLoading = false;

  bool get _isDelivery => widget.data['serviceType'] == 'delivery';

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      final d = widget.data;
      final driverId = d['driverId'] as String?;
      final userName = d['userName'] as String? ?? 'زبون';

      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'status': 'cancelled',
        'cancelledBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (driverId != null && driverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': driverId,
          'orderId': widget.docId,
          'title': '❌ قام الزبون بإلغاء الطلبية',
          'body': 'تم إلغاء طلبية التوصيل/الإحضار.',
          'type': 'order_cancelled',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (driverId != null && driverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': driverId,
            'title': '❌ قام الزبون بإلغاء الطلبية',
            'body': 'تم إلغاء طلبية التوصيل/الإحضار.',
            'data': {'orderId': widget.docId, 'type': 'order_cancelled'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        );
      }
    }
  }

  Future<void> _acceptCounterOffer(double proposedPrice) async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final coDriverName = co?['driverName'] as String? ?? '';
      final customerName = d['userName'] as String? ?? 'الزبون';
      final serviceType = d['serviceType'] as String? ?? '';

      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'price': proposedPrice,
        'status': 'accepted',
        'driverId': coDriverId,
        'driverName': coDriverName,
        'counterOffer.status': 'accepted',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      d['status'] = 'accepted';
      d['price'] = proposedPrice;
      d['driverId'] = coDriverId;
      d['driverName'] = coDriverName;
      if (co != null) co['status'] = 'accepted';

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '💰 $customerName قبل عرض السعر',
          'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
          'type': 'counter_accepted',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '💰 $customerName قبل عرض السعر',
            'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
            'data': {'orderId': widget.docId, 'type': 'counter_accepted'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _rejectCounterOffer() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final customerName = d['userName'] as String? ?? 'الزبون';
      final serviceType = d['serviceType'] as String? ?? '';

      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (co != null) co['status'] = 'rejected';

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '❌ $customerName رفض عرض السعر',
          'body': '',
          'type': 'counter_rejected',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '❌ $customerName رفض عرض السعر',
            'body': '',
            'data': {'orderId': widget.docId, 'type': 'counter_rejected'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _chooseOtherDriver() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;

      await ApiClient.put('/api/service-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'driverId': null,
        'status': 'pending',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (co != null) co['status'] = 'rejected';
      d['status'] = 'pending';
      d['driverId'] = null;

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '🔄 اختار الزبون سائقاً آخر',
          'body': 'الزبون اختار سائقاً آخر لطلب التوصيل.',
          'type': 'counter_rejected',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? 'pending';
    final canCancel = status == 'pending';
    final fromAddr = d['fromAddress'] as String? ?? '';
    final toAddr = d['toAddress'] as String? ?? '';
    final orderName = d['orderName'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final price = (d['price'] as num? ?? 0).toDouble();
    final driverName = d['driverName'] as String? ?? '';
    final parcelImage = d['parcelImageUrl'] as String? ?? '';
    final counterOffer = d['counterOffer'] as Map<String, dynamic>?;
    final hasPendingCounter = counterOffer != null && (counterOffer['status'] as String? ?? '') == 'pending';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${price.toInt()} DZD',
                      style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
                ),
                Text(_isDelivery ? 'توصيل الطلبيات' : 'إحضار الطلبيات',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor, fontFamily: 'Amiri')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (status == 'delivered')
                    _msgBox('تم التوصيل بنجاح', const Color(0xFF00C853))
                  else if (status == 'cancelled')
                    _msgBox('تم إلغاء هذه الطلبية', Colors.redAccent),
                  if (hasPendingCounter) ...[
                    const SizedBox(height: 12),
                    _counterOfferBanner(counterOffer!),
                  ],
                  if (parcelImage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _imageBox('صورة الطرد', parcelImage),
                  ],
                  const SizedBox(height: 12),
                  _infoBox(CupertinoIcons.location, 'موقع الاستلام', fromAddr),
                  if (orderName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoBox(CupertinoIcons.bag_fill, 'اسم الطلبية', orderName),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoBox(CupertinoIcons.doc_text_fill, 'ملاحظة', note),
                  ],
                  const SizedBox(height: 12),
                  _infoBox(Icons.location_on, 'موقع التوصيل', toAddr),
                  const SizedBox(height: 12),
                  _infoBox(CupertinoIcons.money_dollar, 'السعر', '${price.toInt()} DZD'),
                  if (driverName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoBox(CupertinoIcons.person_fill, 'السائق', driverName),
                  ],
                  const SizedBox(height: 20),
                  if (canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _cancelling
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.xmark_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('إلغاء الطلبية',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
                                ],
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

  Widget _counterOfferBanner(Map<String, dynamic> co) {
    final driverName = co['driverName'] as String? ?? 'السائق';
    final proposedPrice = (co['proposedPrice'] as num? ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withOpacity(0.08), kPrimaryColor.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('عرض سعر من السائق',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kWarningColor, fontFamily: 'Amiri')),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.money_dollar_circle_fill, color: kWarningColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text('$driverName يقترح سعر توصيل: ${proposedPrice.toInt()} DA',
              style: const TextStyle(fontSize: 13, color: kTextColor, fontFamily: 'Amiri'), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          if (_counterLoading)
            const Center(child: CupertinoActivityIndicator(color: kWarningColor))
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptCounterOffer(proposedPrice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccessColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('قبول السعر الجديد: ${proposedPrice.toInt()} DA',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _rejectCounterOffer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kBgColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _neuShadow(blur: 5, offset: 2),
                      ),
                      child: const Center(
                        child: Text('رفض العرض',
                            style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: kDangerColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _msgBox(String msg, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
        const SizedBox(width: 8),
        Icon(CupertinoIcons.checkmark_seal_fill, color: color, size: 18),
      ],
    ),
  );

  Widget _infoBox(IconData icon, String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [kBgColor, Color(0xFFE6E4F0)],
      ),
      boxShadow: [
        BoxShadow(color: kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
        BoxShadow(color: kNeumLight, blurRadius: 10, offset: Offset(-4, -4)),
      ],
      border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Amiri')),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextColor, fontFamily: 'Amiri'),
                  textAlign: TextAlign.right),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _imageBox(String label, String url) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [kBgColor, Color(0xFFE6E4F0)],
      ),
      boxShadow: [
        BoxShadow(color: kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
        BoxShadow(color: kNeumLight, blurRadius: 10, offset: Offset(-4, -4)),
      ],
      border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            memCacheWidth: 600,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 180,
              color: Colors.grey.shade200,
              child: const Center(child: CupertinoActivityIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 180,
              color: Colors.grey.shade200,
              child: const Icon(CupertinoIcons.photo_fill, color: Colors.grey),
            ),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  TransportDetailsSheet — تفاصيل طلبية النقل
// ══════════════════════════════════════════════════════════════════════════════

class TransportDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onChanged;

  const TransportDetailsSheet({
    super.key,
    required this.data,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<TransportDetailsSheet> createState() => _TransportDetailsSheetState();
}

class _TransportDetailsSheetState extends State<TransportDetailsSheet> {
  bool _cancelling = false;
  bool _counterLoading = false;

  Color get _accentColor {
    final type = widget.data['transportType'] as String? ?? '';
    if (type.contains('سيارة') || type.contains('taxi')) return const Color(0xFFE65100);
    if (type.contains('هارباني') || type.contains('minibus')) return const Color(0xFF00695C);
    if (type.contains('فورغو') || type.contains('truck')) return const Color(0xFF4527A0);
    return kPrimaryColor;
  }

  IconData get _serviceIcon {
    final type = widget.data['transportType'] as String? ?? '';
    if (type.contains('سيارة') || type.contains('taxi')) return CupertinoIcons.car_fill;
    if (type.contains('هارباني') || type.contains('minibus')) return CupertinoIcons.bus;
    if (type.contains('فورغو') || type.contains('truck')) return CupertinoIcons.cube_box;
    return CupertinoIcons.car_fill;
  }

  Future<void> _acceptCounterOffer(double proposedPrice) async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final coDriverName = co?['driverName'] as String? ?? '';
      final customerName = d['userName'] as String? ?? 'الزبون';

      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'price': proposedPrice,
        'status': 'accepted',
        'driverId': coDriverId,
        'driverName': coDriverName,
        'counterOffer.status': 'accepted',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      d['status'] = 'accepted';
      d['price'] = proposedPrice;
      d['driverId'] = coDriverId;
      d['driverName'] = coDriverName;
      if (co != null) co['status'] = 'accepted';

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '💰 $customerName قبل عرض السعر',
          'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
          'type': 'counter_accepted',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '💰 $customerName قبل عرض السعر',
            'body': 'السعر الجديد: ${proposedPrice.toInt()} DZD',
            'data': {'orderId': widget.docId, 'type': 'counter_accepted'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _rejectCounterOffer() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;
      final customerName = d['userName'] as String? ?? 'الزبون';

      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (co != null) co['status'] = 'rejected';

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '❌ $customerName رفض عرض السعر',
          'body': '',
          'type': 'counter_rejected',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (coDriverId != null && coDriverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': coDriverId,
            'title': '❌ $customerName رفض عرض السعر',
            'body': '',
            'data': {'orderId': widget.docId, 'type': 'counter_rejected'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) setState(() => _counterLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _chooseOtherDriver() async {
    setState(() => _counterLoading = true);
    try {
      final d = widget.data;
      final co = d['counterOffer'] as Map<String, dynamic>?;
      final coDriverId = co?['driverId'] as String?;

      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'counterOffer.status': 'rejected',
        'driverId': null,
        'status': 'pending',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (co != null) co['status'] = 'rejected';
      d['status'] = 'pending';
      d['driverId'] = null;

      if (coDriverId != null && coDriverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': coDriverId,
          'orderId': widget.docId,
          'title': '🔄 اختار الزبون سائقاً آخر',
          'body': 'الزبون اختار سائقاً آخر لطلب النقل.',
          'type': 'counter_rejected',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _counterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      final d = widget.data;
      final driverId = d['driverId'] as String?;

      await ApiClient.put('/api/transport-orders/${widget.docId}', {
        'status': 'cancelled',
        'cancelledBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (driverId != null && driverId.isNotEmpty) {
        await ApiClient.post('/api/notifications', {
          'toId': driverId,
          'orderId': widget.docId,
          'title': '❌ قام الزبون بإلغاء طلبية النقل',
          'body': 'تم إلغاء طلبية النقل.',
          'type': 'order_cancelled',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'hiddenFor': [],
        });
      }

      if (driverId != null && driverId.isNotEmpty) {
        try {
          await ApiClient.post('/api/notify-driver', {
            'driverId': driverId,
            'title': '❌ قام الزبون بإلغاء الطلبية',
            'body': 'تم إلغاء طلبية النقل.',
            'data': {'orderId': widget.docId, 'type': 'order_cancelled'},
          });
        } catch (_) {}
      }

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? '';
    final canCancel = status == 'pending' || status == 'accepted';
    final driverName = d['driverName'] as String?;
    final counterOffer = d['counterOffer'] as Map<String, dynamic>?;
    final hasPendingCounter = counterOffer != null && (counterOffer['status'] as String? ?? '') == 'pending';

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor.withOpacity(0.9), _accentColor],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(d['price'] as num? ?? 0).toStringAsFixed(0)} DZD',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22,
                            fontWeight: FontWeight.bold, fontFamily: 'Amiri',
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              d['transportType'] as String? ?? '',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 16,
                                fontWeight: FontWeight.bold, fontFamily: 'Amiri',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(_serviceIcon, color: Colors.white, size: 24),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailBox(CupertinoIcons.location, 'نقطة الانطلاق', d['fromAddress'] as String? ?? ''),
                  const SizedBox(height: 12),
                  _detailBox(CupertinoIcons.location_fill, 'نقطة الوصول', d['toAddress'] as String? ?? ''),
                  if (d['fromImage'] != null) ...[
                    const SizedBox(height: 12),
                    _imageBox('صورة الانطلاق', d['fromImage'] as String),
                  ],
                  if (d['toImage'] != null) ...[
                    const SizedBox(height: 12),
                    _imageBox('صورة الوصول', d['toImage'] as String),
                  ],
                  if (d['parcelImageUrl'] != null) ...[
                    const SizedBox(height: 12),
                    _imageBox('صورة الطلبية', d['parcelImageUrl'] as String),
                  ],
                  if ((d['note'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailBox(CupertinoIcons.text_bubble, 'ملاحظة', d['note'] as String),
                  ],
                  if (driverName != null) ...[
                    const SizedBox(height: 12),
                    _detailBox(CupertinoIcons.person_fill, 'السائق', driverName),
                  ],
                  if (hasPendingCounter) ...[
                    const SizedBox(height: 12),
                    _transportCounterOfferBanner(counterOffer!),
                  ],
                  const SizedBox(height: 24),
                  if (canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _cancelling
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.xmark_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('إلغاء الطلبية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri')),
                                ],
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

  Widget _transportCounterOfferBanner(Map<String, dynamic> co) {
    final driverName = co['driverName'] as String? ?? 'السائق';
    final proposedPrice = (co['proposedPrice'] as num? ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor.withOpacity(0.08), kPrimaryColor.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('عرض سعر من السائق',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kWarningColor, fontFamily: 'Amiri')),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.money_dollar_circle_fill, color: kWarningColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text('$driverName يقترح سعر نقل: ${proposedPrice.toInt()} DA',
              style: const TextStyle(fontSize: 13, color: kTextColor, fontFamily: 'Amiri'), textAlign: TextAlign.right),
          const SizedBox(height: 12),
          if (_counterLoading)
            const Center(child: CupertinoActivityIndicator(color: kWarningColor))
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptCounterOffer(proposedPrice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSuccessColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('قبول السعر الجديد: ${proposedPrice.toInt()} DA',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _rejectCounterOffer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kBgColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _neuShadow(blur: 5, offset: 2),
                      ),
                      child: const Center(
                        child: Text('رفض العرض',
                            style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: kDangerColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _chooseOtherDriver,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kBgColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _neuShadow(blur: 5, offset: 2),
                      ),
                      child: const Center(
                        child: Text('اختر سائقاً آخر',
                            style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: kPrimaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailBox(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [kBgColor, Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow.withOpacity(0.6), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: kNeumLight, blurRadius: 10, offset: Offset(-4, -4)),
        ],
        border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: kPrimaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Amiri')),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextColor, fontFamily: 'Amiri'), textAlign: TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ProjectDeliveryCard
// ══════════════════════════════════════════════════════════════════════════════
class _ProjectDeliveryCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _ProjectDeliveryCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc;
    final status = d['status'] as String? ?? 'pending';
    final rejectedBy = List<String>.from(d['rejectedBy'] ?? []);
    final rejectionReason = d['rejectionReason'] as String?;
    final driverName = d['driverName'] as String?;
    final description = d['description'] as String? ?? '';
    final counterOffer = d['counterOffer'] as Map<String, dynamic>?;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (counterOffer != null) {
      statusText = 'عرض سعر جديد 💜';
      statusColor = kWarningColor;
      statusIcon = CupertinoIcons.money_dollar;
    } else if (status == 'accepted') {
      statusText = 'تم القبول ✓';
      statusColor = kSuccessColor;
      statusIcon = CupertinoIcons.check_mark_circled;
    } else if (status == 'onway_to_store') {
      statusText = 'السائق في الطريق للمتجر 🚗';
      statusColor = kWarningColor;
      statusIcon = CupertinoIcons.car_fill;
    } else if (status == 'picked_up') {
      statusText = 'تم الاستلام من المتجر 📦';
      statusColor = kSuccessColor;
      statusIcon = CupertinoIcons.checkmark_seal_fill;
    } else if (status == 'onway') {
      statusText = 'السائق في الطريق إليك 🚚';
      statusColor = kPrimaryColor;
      statusIcon = CupertinoIcons.car_fill;
    } else if (status == 'delivered') {
      statusText = 'تم التوصيل ✅';
      statusColor = kSuccessColor;
      statusIcon = CupertinoIcons.checkmark_alt_circle_fill;
    } else if (rejectedBy.isNotEmpty) {
      statusText = 'تم الرفض ✗';
      statusColor = kDangerColor;
      statusIcon = CupertinoIcons.xmark_circle;
    } else {
      statusText = 'قيد المعالجة ⏳';
      statusColor = kWarningColor;
      statusIcon = CupertinoIcons.clock;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFF5F0FA), Color(0xFFEDE4F5)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow.withOpacity(0.5), blurRadius: 8, offset: const Offset(3, 3)),
          const BoxShadow(color: Color(0xFFD8D7DE), blurRadius: 8, offset: Offset(-3, -3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const Spacer(),
                Text(
                  description,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextColor, fontFamily: 'Amiri'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor, fontFamily: 'Amiri'),
                  ),
                ),
                if (counterOffer != null)
                  Text(
                    '${(counterOffer['proposedPrice'] as num?)?.toInt() ?? 0} د.ج',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryColor, fontFamily: 'Amiri'),
                  ),
                if (driverName != null && status == 'accepted')
                  Text(
                    'السائق: $driverName',
                    style: const TextStyle(fontSize: 12, color: kTextGrey, fontFamily: 'Amiri'),
                  ),
              ],
            ),
            if (rejectionReason != null && rejectedBy.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(CupertinoIcons.exclamationmark_bubble, color: kDangerColor.withOpacity(0.6), size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      rejectionReason,
                      style: TextStyle(fontSize: 12, color: kDangerColor.withOpacity(0.7), fontFamily: 'Amiri'),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
            if (d['storeOwnerId'] != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showReportOwnerSheet(context, d),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kDangerColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kDangerColor.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.flag, color: kDangerColor, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'الإبلاغ عن صاحب المشروع',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kDangerColor, fontFamily: 'Amiri'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showReportOwnerSheet(BuildContext context, Map<String, dynamic> d) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportOwnerSheet(
      deliveryId: d['_id'] ?? '',
      ownerId: d['storeOwnerId'] ?? '',
      ownerName: d['storeName'] ?? 'صاحب مشروع',
      userId: d['userId'] ?? '',
      customerName: d['customerName'] ?? 'زبون',
    ),
  );
}

class _ReportOwnerSheet extends StatefulWidget {
  final String deliveryId;
  final String ownerId;
  final String ownerName;
  final String userId;
  final String customerName;

  const _ReportOwnerSheet({
    required this.deliveryId,
    required this.ownerId,
    required this.ownerName,
    required this.userId,
    required this.customerName,
  });

  @override
  State<_ReportOwnerSheet> createState() => _ReportOwnerSheetState();
}

class _ReportOwnerSheetState extends State<_ReportOwnerSheet> {
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_noteCtrl.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/reports', {
        'type': 'customer_report_owner',
        'userId': widget.userId,
        'userName': widget.customerName,
        'ownerId': widget.ownerId,
        'ownerName': widget.ownerName,
        'orderId': widget.deliveryId,
        'reason': 'شكوى',
        'note': _noteCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' تم إرسال البلاغ بنجاح للإدارة', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(CupertinoIcons.flag_fill, color: kDangerColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('الإبلاغ عن ${widget.ownerName}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFamily: 'Amiri', fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: kBgColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _neuShadow(blur: 5, offset: 2),
            ),
            child: TextField(
              controller: _noteCtrl,
              maxLines: 4,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'اكتب تفاصيل البلاغ...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13, fontFamily: 'Amiri'),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: (_noteCtrl.text.trim().isEmpty || _sending) ? null : _send,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _noteCtrl.text.trim().isEmpty ? Colors.grey.shade300 : kDangerColor,
              ),
              child: Center(
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال البلاغ', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
