// ══════════════════════════════════════════════════════════════════════════════
//  Order.dart
//  💡 اقتصادي — collection واحدة فقط: orders/{orderId}
//  ✅ بيانات حقيقية من API
//  ✅ Tab: طلبات جارية | طلبات منتهية
//  ✅ Summary card بأرقام حقيقية
//  ✅ Shimmer + stagger animations
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

import 'order_models.dart';
import 'active_orders_screen.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  OrdersScreen
// ══════════════════════════════════════════════════════════════════════════════

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<double> _summaryScale, _summaryFade;

  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;
  bool _showShimmer = true;

  late final TabController _tabCtrl;

  int _activeCount = 0;
  int _doneCount = 0;
  int _cancelledCount = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();

    _tabCtrl = TabController(length: 2, vsync: this);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000));

    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic)));

    _headerFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut));

    _summaryScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.55, curve: Curves.easeOutBack)));

    _summaryFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut));

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100))..repeat();
    _shimmerAnim = Tween<double>(
      begin: -1.5,
      end: 2.5).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showShimmer = false);
    });

    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ordersData = await ApiClient.getList('/api/orders?userId=${user.uid}');
      final transportData = await ApiClient.getList('/api/transport-orders?userId=${user.uid}');
      final serviceData = await ApiClient.getList('/api/service-orders?userId=${user.uid}');

      int active = 0, done = 0, cancelled = 0;
      for (final doc in [...ordersData, ...transportData, ...serviceData]) {
        final d = doc as Map<String, dynamic>;
        final status = d['status'] as String? ?? '';
        switch (status) {
          case 'pending':
          case 'accepted':
          case 'purchased':
          case 'on_way':
          case 'onway':
            active++;
            break;
          case 'delivered':
            done++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      if (mounted) {
        setState(() {
          _activeCount = active;
          _doneCount = done;
          _cancelledCount = cancelled;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _shimmerCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      child: Scaffold(
        backgroundColor: kBgColor,
        body: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
              bottom: false,
              child: user == null
              ? _notLoggedIn()
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            SlideTransition(
                              position: _headerSlide,
                              child: FadeTransition(
                                opacity: _headerFade,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                  child: _buildHeader()))),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                              child: ScaleTransition(
                                scale: _summaryScale,
                                child: FadeTransition(
                                  opacity: _summaryFade,
                                  child: _SummaryCard(
                                    active: _activeCount,
                                    done: _doneCount,
                                    cancelled: _cancelledCount,
                                    loaded: _statsLoaded)))),
                            const SizedBox(height: 16),
                          ])),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabBarDelegate(
                          _NeumTabBar(controller: _tabCtrl))),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _OrdersTab(
                        userId: user.uid,
                        statuses: const [
                          'pending',
                          'accepted',
                          'purchased',
                          'on_way',
                          'onway',
                        ],
                        emptyMsg: 'لا توجد طلبات جارية',
                        emptyIcon: CupertinoIcons.clock,
                        shimmerAnim: _shimmerAnim,
                        showShimmer: _showShimmer,
                        onChanged: _loadStats),
                      _OrdersTab(
                        userId: user.uid,
                        statuses: const ['delivered', 'cancelled'],
                        emptyMsg: 'لا توجد طلبات منتهية',
                        emptyIcon: CupertinoIcons.checkmark_seal,
                        shimmerAnim: _shimmerAnim,
                        showShimmer: _showShimmer,
                        onChanged: _loadStats),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _statsLoaded = false;
              _activeCount = 0;
              _doneCount = 0;
              _cancelledCount = 0;
            });
            _loadStats();
          },
          child: const _NeumBox(
            child: Icon(CupertinoIcons.refresh, color: kPrimaryColor, size: 20))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'طلبياتي',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: kTextColor,
                fontFamily: 'Amiri')),
            Container(
              width: 50,
              height: 3,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(10))),
          ]),
      ]);
  }

  Widget _notLoggedIn() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _NeumBox(
          size: 80,
          child: Icon(
            CupertinoIcons.person_crop_circle,
            color: kPrimaryColor,
            size: 40)),
        const SizedBox(height: 16),
        Text(
          'سجل دخولك لعرض طلبياتك',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade500,
            fontFamily: 'Amiri')),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  _SliverTabBarDelegate
// ══════════════════════════════════════════════════════════════════════════════

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);
  final Widget _tabBar;

  @override
  double get minExtent => 68.0;
  @override
  double get maxExtent => 68.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent) {
    return Container(
      color: kBgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  _NeumTabBar
// ══════════════════════════════════════════════════════════════════════════════

class _NeumTabBar extends StatelessWidget {
  final TabController controller;
  const _NeumTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: kNeumShadow, blurRadius: 8, offset: Offset(4, 4)),
          BoxShadow(color: kNeumLight, blurRadius: 8, offset: Offset(-4, -4)),
        ]),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color(0xFF9232E8),
              Color(0xFF7D29C6),
              Color(0xFF6D22AC),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
          ]),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black45,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: 'Amiri'),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          fontFamily: 'Amiri'),
        tabs: const [
          Tab(text: 'جارية'),
          Tab(text: 'منتهية'),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _SummaryCard
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final int active, done, cancelled;
  final bool loaded;

  const _SummaryCard({
    required this.active,
    required this.done,
    required this.cancelled,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    final total = active + done + cancelled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Color(0xFF9232E8),
            Color(0xFF7D29C6),
            Color(0xFF6D22AC),
          ],),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 195, 177, 200).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4)),
          BoxShadow(
            color: kNeumLight,
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ],
        border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor.withOpacity(0.07)))),
          Positioned(
            bottom: -20,
            right: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor.withOpacity(0.05)))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.chart_bar_fill,
                          color: kPrimaryColor,
                          size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'إجمالي: $total',
                          style: const TextStyle(
                            color: kPrimaryColor,
                            fontSize: 11,
                            fontFamily: 'Amiri')),
                      ])),
                  const Text(
                    'ملخص الطلبيات',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')),
                ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(
                    loaded ? '$cancelled' : '...',
                    'ملغاة',
                    Colors.red.shade300,
                    CupertinoIcons.xmark_circle_fill),
                  _vDiv(),
                  _stat(
                    loaded ? '$done' : '...',
                    'منتهية',
                    Colors.green.shade300,
                    CupertinoIcons.checkmark_seal_fill),
                  _vDiv(),
                  _stat(
                    loaded ? '$active' : '...',
                    'جارية',
                    const Color.fromARGB(255, 255, 255, 255),
                    CupertinoIcons.clock_fill),
                ]),
            ]),
        ]));
  }

  Widget _stat(String v, String l, Color c, IconData ic) => Column(
    children: [
      Icon(ic, color: c.withOpacity(0.85), size: 16),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(
          v,
          key: ValueKey(v),
          style: TextStyle(
            color: c,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1))),
      const SizedBox(height: 4),
      Text(
        l,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          fontFamily: 'Amiri')),
    ]);

  Widget _vDiv() => Container(
    width: 1,
    height: 50,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white24, Colors.transparent])));
}

// ══════════════════════════════════════════════════════════════════════════════
//  _OrdersTab
// ══════════════════════════════════════════════════════════════════════════════

class _OrdersTab extends StatefulWidget {
  final String userId;
  final List<String> statuses;
  final String emptyMsg;
  final IconData emptyIcon;
  final Animation<double> shimmerAnim;
  final bool showShimmer;
  final VoidCallback onChanged;

  const _OrdersTab({
    required this.userId,
    required this.statuses,
    required this.emptyMsg,
    required this.emptyIcon,
    required this.shimmerAnim,
    required this.showShimmer,
    required this.onChanged,
  });

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<dynamic> _transportDocs = [];
  List<dynamic> _serviceDocs = [];
  List<dynamic> _ordersDocs = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    SocketClient.init();
    _loadAll();
    SocketClient.on('service:updated', _onServiceUpdated);
    SocketClient.on('service:created', _onAnyOrderEvent);
    SocketClient.on('transport:updated', _onAnyOrderEvent);
    SocketClient.on('transport:created', _onAnyOrderEvent);
    SocketClient.on('order:updated', _onOrderUpdated);
    SocketClient.on('order:created', _onAnyOrderEvent);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getList('/api/transport-orders?userId=${widget.userId}'),
        ApiClient.getList('/api/service-orders?userId=${widget.userId}'),
        ApiClient.getList('/api/orders?userId=${widget.userId}'),
      ]);
      if (!mounted) return;
      setState(() {
        _transportDocs = (results[0]).where((d) {
          final m = d as Map<String, dynamic>;
          if (widget.statuses.contains(m['status'])) return true;
          if (widget.statuses.contains('cancelled')) {
            final rb = m['rejectedBy'];
            final hasRejected = rb is String ? rb.isNotEmpty : rb is List ? rb.isNotEmpty : false;
            if (hasRejected) { m['status'] = 'cancelled'; m['_rejected'] = true; return true; }
          }
          return false;
        }).toList();
        _serviceDocs = (results[1]).where((d) {
          final m = d as Map<String, dynamic>;
          if (widget.statuses.contains(m['status'])) return true;
          if (widget.statuses.contains('cancelled')) {
            final rb = m['rejectedBy'];
            final hasRejected = rb is String ? rb.isNotEmpty : rb is List ? rb.isNotEmpty : false;
            if (hasRejected) { m['status'] = 'cancelled'; m['_rejected'] = true; return true; }
          }
          return false;
        }).toList();
        _ordersDocs = (results[2]).where((d) {
          final m = d as Map<String, dynamic>;
          final hidden = List<String>.from(m['hiddenFor'] ?? []);
          if (hidden.contains(widget.userId)) return false;
          return widget.statuses.contains(m['status']);
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onServiceUpdated(data) {
    _loadAll();
    if (data is Map<String, dynamic>) {
      final co = data['counterOffer'] as Map<String, dynamic>?;
      if (co != null && co['status'] == 'pending') {
        final price = (co['proposedPrice'] as num?)?.toInt() ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('💰 عرض سعر جديد: $price DZD', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Color(0xFFe65100),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    }
  }

  void _onOrderUpdated(data) {
    _loadAll();
    if (data is Map<String, dynamic>) {
      final co = data['counterOffer'] as Map<String, dynamic>?;
      if (co != null && co['status'] == 'pending') {
        final price = (co['proposedPrice'] as num?)?.toInt() ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('💰 عرض سعر جديد: $price DZD', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Color(0xFFe65100),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    }
  }

  void _onAnyOrderEvent(_) {
    _loadAll();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SocketClient.off('service:updated', _onServiceUpdated);
    SocketClient.off('service:created', _onAnyOrderEvent);
    SocketClient.off('transport:updated', _onAnyOrderEvent);
    SocketClient.off('transport:created', _onAnyOrderEvent);
    SocketClient.off('order:updated', _onOrderUpdated);
    SocketClient.off('order:created', _onAnyOrderEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || widget.showShimmer) {
      return _ShimmerList(shimmerAnim: widget.shimmerAnim);
    }

    final totalItems = _transportDocs.length + _serviceDocs.length + _ordersDocs.length;
    if (totalItems == 0) {
      return _EmptyState(msg: widget.emptyMsg, icon: widget.emptyIcon);
    }

    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < _transportDocs.length) {
          final d = _transportDocs[index] as Map<String, dynamic>;
          final docId = d['_id'] as String? ?? '';
          return TransportCard(
            data: d,
            docId: docId,
            onChanged: widget.onChanged);
        }

        final serviceOffset = index - _transportDocs.length;
        if (serviceOffset < _serviceDocs.length) {
          final d = _serviceDocs[serviceOffset] as Map<String, dynamic>;
          final docId = d['_id'] as String? ?? '';
          return ServiceOrderCard(
            data: d,
            docId: docId,
            onChanged: widget.onChanged);
        }

        final productIndex = index - _transportDocs.length - _serviceDocs.length;
        final d = _ordersDocs[productIndex] as Map<String, dynamic>;
        final docId = d['_id'] as String? ?? '';
final items = ((d['items'] as List<dynamic>?) ?? []).map((item) {
  final m = item as Map<String, dynamic>;

  final double originalPrice = ((m['prix'] ?? m['price'] ?? 0) as num).toDouble();

  final double finalPrice = m['finalPrice'] != null 
      ? (m['finalPrice'] as num).toDouble() 
      : originalPrice;

  return OrderItem(
    name: m['name'] as String? ?? '',
    price: finalPrice,
    originalPrice: originalPrice,
    purchaseStatus: m['purchaseStatus'] as String? ?? '',
    alternativeName: m['alternativeName'] as String? ?? '',
    alternativePrice: ((m['alternativePrice'] as num?) ?? 0).toDouble(),
    alternativeStatus: m['alternativeStatus'] as String? ?? '',
    image: m['image'] as String? ?? m['imageUrl'] as String? ?? '',
    quantity: (m['quantity'] as int?) ?? 1,
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

        final order = Order(
          id: docId,
          items: items,
          deliveryFee: (d['deliveryFee'] as num? ?? 15).toDouble(),
          driverName: d['driverName'] as String?,
          status: statusFromString(d['status'] as String? ?? ''),
          time: _formatTime(d['createdAt']),
          address: d['address'] as String? ?? '',
          magasinId: d['magasinId'] as String?,
          customerConfirmed: d['customerConfirmed'] as bool? ?? false,
          driverId: d['driverId'] as String?,
          driverLat: (d['driverLat'] as num?)?.toDouble(),
          driverLng: (d['driverLng'] as num?)?.toDouble(),
          userLat: (d['userLat'] as num?)?.toDouble(),
          userLng: (d['userLng'] as num?)?.toDouble(),
          counterOffer: d['counterOffer'] as Map<String, dynamic>?);

        return AnimCard(
          order: order,
          index: index,
          docId: docId,
          onChanged: widget.onChanged);
      },
    ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return 'الآن';
    if (ts is String) {
      final dt = DateTime.tryParse(ts);
      if (dt != null) {
        final now = DateTime.now();
        if (dt.day == now.day && dt.month == now.month) {
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
    return 'الآن';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  AnimCard — stagger entrance (مستخدمة في _OrdersTab)
// ══════════════════════════════════════════════════════════════════════════════

class AnimCard extends StatefulWidget {
  final Order order;
  final int index;
  final String docId;
  final VoidCallback onChanged;

  const AnimCard({
    super.key,
    required this.order,
    required this.index,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<AnimCard> createState() => _AnimCardState();
}

class _AnimCardState extends State<AnimCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.65, curve: Curves.easeOut)));
    _scale = Tween<double>(
      begin: 0.82,
      end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    if (widget.index < 6) {
      Future.delayed(Duration(milliseconds: widget.index * 90), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // هنا عرفت المتغير باسم user
    if (user == null) return const SizedBox();

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _DetailsSheet(
                order: widget.order,
                docId: widget.docId,
                onChanged: widget.onChanged)),
            // ✅ التعديل هنا: نمرر user.uid بدلاً من userId
            child: OrderCard(
              order: widget.order, 
              docId: widget.docId, 
              userId: user.uid,
              onChanged: widget.onChanged)))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _OrderCard — بطاقة الطلبية في قائمة "طلبياتي"
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
//  _DetailsSheet — تفاصيل + إلغاء (للطلبات المنتهية وبعض الجارية)
// ══════════════════════════════════════════════════════════════════════════════

class _DetailsSheet extends StatefulWidget {
  final Order order;
  final String docId;
  final VoidCallback onChanged;

  const _DetailsSheet({
    required this.order,
    required this.docId,
    required this.onChanged,
  });

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ApiClient.put('/api/orders/${widget.docId}', {
            'status': 'cancelled',
            'updatedAt': DateTime.now().toIso8601String(),
          });
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${o.total.toStringAsFixed(0)} DZD',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Amiri'))),
                Text(
                  '#${widget.docId.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                    fontFamily: 'Amiri')),
              ])),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (o.status != OrderStatus.delivered &&
                      o.status != OrderStatus.cancelled)
                    _StatusBar(status: o.status),
                  if (o.status == OrderStatus.delivered)
                    _msgBox(
                      'تم توصيل طلبيتك بنجاح ✓',
                      const Color(0xFF00C853)),
                  if (o.status == OrderStatus.cancelled)
                    _msgBox('تم إلغاء هذه الطلبية', Colors.redAccent),
                  const SizedBox(height: 16),
                  _infoBox(
                    CupertinoIcons.location_fill,
                    'عنوان التوصيل',
                    o.address.isNotEmpty ? o.address : 'غير محدد'),
                  const SizedBox(height: 12),
                  _infoBox(CupertinoIcons.clock, 'وقت الطلب', o.time),
                  const SizedBox(height: 12),
                  _productsBox(o),
                  const SizedBox(height: 20),
                  if (o.canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                        child: _cancelling
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.xmark_circle,
                                    color: Colors.white,
                                    size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'إلغاء الطلبية',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      fontFamily: 'Amiri')),
                                ]))),
                ]))),
        ]));
  }

  Widget _msgBox(String msg, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          msg,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri')),
        const SizedBox(width: 8),
        Icon(CupertinoIcons.checkmark_seal_fill, color: color, size: 18),
      ]));

  Widget _infoBox(IconData icon, String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: _boxDeco(),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontFamily: 'Amiri')),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextColor,
                  fontFamily: 'Amiri'),
                textAlign: TextAlign.right),
            ])),
      ]));

  Widget _productsBox(Order o) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: _boxDeco(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'المنتجات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: kPrimaryColor,
            fontFamily: 'Amiri')),
        const SizedBox(height: 10),
        ...o.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(item.price * item.quantity).toStringAsFixed(0)} DZD',
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Amiri')),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.name} × ${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: item.alternativeStatus == 'accepted' ? Colors.grey : kTextColor,
                          fontFamily: 'Amiri',
                          decoration: item.alternativeStatus == 'accepted' ? TextDecoration.lineThrough : null,
                        ),
                        textAlign: TextAlign.right),
                      if (item.capacite.isNotEmpty)
                        Text(
                          'الحجم: ${item.capacite}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.purple,
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right),
                      if (item.alternativeStatus == 'accepted' && item.alternativeName.isNotEmpty)
                        Text(
                          '${item.alternativeName} × ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right),
                    ],
                  )),
              ]))),
        Divider(height: 16, color: Colors.grey.shade300),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${o.total.toStringAsFixed(0)} DZD',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: kPrimaryColor,
                fontFamily: 'Amiri')),
            const Text(
              'الإجمالي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: kTextColor,
                fontFamily: 'Amiri')),
          ]),
      ]));

  BoxDecoration _boxDeco() => BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [kBgColor, Color(0xFFE6E4F0)]),
    boxShadow: [
      BoxShadow(
        color: kNeumShadow.withOpacity(0.6),
        blurRadius: 10,
        offset: Offset(4, 4)),
      BoxShadow(
        color: kNeumLight,
        blurRadius: 10,
        offset: Offset(-4, -4)),
    ],
    border: Border.all(color: kPrimaryColor.withOpacity(0.1)));
}

// ══════════════════════════════════════════════════════════════════════════════
//  _StatusBar — شريط تتبع حالة الطلبية (5 خطوات)
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBar extends StatelessWidget {
  final OrderStatus status;
  const _StatusBar({required this.status});

  int get _step {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.purchased:
        return 2;
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
      (CupertinoIcons.cart_fill, 'شراء'),
      (CupertinoIcons.car_fill, 'طريق'),
      (CupertinoIcons.bag_fill_badge_plus, 'وصول'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            int lineIdx = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: _step > lineIdx ? kPrimaryColor : Colors.grey.shade300));
          }
          int idx = i ~/ 2;
          bool isCompleted = idx <= _step;
          bool isCurrent = idx == _step;
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
                    color: isCompleted ? kPrimaryColor : Colors.grey.shade300),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.3),
                            blurRadius: 6),
                        ]
                      : []),
                child: Icon(
                  steps[idx].$1,
                  size: isCurrent ? 16 : 12,
                  color: isCompleted ? Colors.white : Colors.grey.shade400)),
              const SizedBox(height: 4),
              Text(
                steps[idx].$2,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? kPrimaryColor : Colors.grey.shade400,
                  fontFamily: 'Amiri')),
            ]);
        })));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Shimmer + Empty + NeumBox
// ══════════════════════════════════════════════════════════════════════════════

class _ShimmerList extends StatelessWidget {
  final Animation<double> shimmerAnim;
  const _ShimmerList({required this.shimmerAnim});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
    itemCount: 3,
    itemBuilder: (_, i) => AnimatedBuilder(
      animation: shimmerAnim,
      builder: (_, __) => Container(
        height: 130,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kBgColor, Color(0xFFE6E4F0)]),
          boxShadow: [
            BoxShadow(
              color: kNeumShadow.withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4)),
            BoxShadow(
              color: kNeumLight,
              blurRadius: 10,
              offset: Offset(-4, -4)),
          ],
          border: Border.all(color: kPrimaryColor.withOpacity(0.1))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: kNeumShadow.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      width: 200,
                      decoration: BoxDecoration(
                        color: kNeumShadow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5))),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 150,
                      decoration: BoxDecoration(
                        color: kNeumShadow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5))),
                  ])),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    shimmerAnim.value * MediaQuery.of(context).size.width,
                    0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.5),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0]))))),
            ])))));
}

class _EmptyState extends StatelessWidget {
  final String msg;
  final IconData icon;
  const _EmptyState({required this.msg, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.3),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade400,
                    blurRadius: 12,
                    offset: const Offset(4, 4)),
                   BoxShadow(
                    color: Color(0xFFB8B1C8).withOpacity(0.6),
                    blurRadius: 12,
                    offset: Offset(-4, -4)),
                ]),
              child: Icon(icon, color: kPrimaryColor, size: 36)))),
        const SizedBox(height: 10),
        Text(
          msg,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextColor,
            fontFamily: 'Amiri')),
      ]));
}

class _NeumBox extends StatelessWidget {
  final Widget child;
  final double size;
  const _NeumBox({required this.child, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: kBgColor,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: kNeumShadow, blurRadius: 6, offset: Offset(3, 3)),
        BoxShadow(color: kNeumLight, blurRadius: 6, offset: Offset(-3, -3)),
      ]),
    child: Center(child: child));
}