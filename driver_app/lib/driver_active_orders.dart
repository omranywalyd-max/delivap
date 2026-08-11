import 'dart:async';

import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_route_map_screen.dart';
import 'driver_order_detail_screen.dart';
import 'theme.dart';

// ============================================================================
//  DriverActiveOrdersScreen — شاشة الطلبيات الجارية للسائق
// ============================================================================
class DriverActiveOrdersScreen extends StatefulWidget {
  const DriverActiveOrdersScreen({super.key});

  @override
  State<DriverActiveOrdersScreen> createState() =>
      _DriverActiveOrdersScreenState();
}

class _DriverActiveOrdersScreenState extends State<DriverActiveOrdersScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _vehicleType = '';
  List<Map<String, dynamic>> _allItems = [];
  bool _loading = true;
  bool _isRefreshing = false;
  bool _pendingRefresh = false;
  Timer? _socketDebounce;

  void _onSocketEvent(dynamic _) {
    if (!mounted) return;
    _socketDebounce?.cancel();
    _socketDebounce = Timer(const Duration(milliseconds: 300), _loadData);
  }

  @override
  void initState() {
    super.initState();
    _loadData();

    SocketClient().on('order:updated', _onSocketEvent);
    SocketClient().on('order:created', _onSocketEvent);
    SocketClient().on('project_delivery:updated', _onSocketEvent);
    SocketClient().on('project_delivery:created', _onSocketEvent);
    SocketClient().on('transport:updated', _onSocketEvent);
    SocketClient().on('transport:created', _onSocketEvent);
    SocketClient().on('service:updated', _onSocketEvent);
    SocketClient().on('service:created', _onSocketEvent);
  }

  @override
  void dispose() {
    _socketDebounce?.cancel();
    SocketClient().off('order:updated', _onSocketEvent);
    SocketClient().off('order:created', _onSocketEvent);
    SocketClient().off('project_delivery:updated', _onSocketEvent);
    SocketClient().off('project_delivery:created', _onSocketEvent);
    SocketClient().off('transport:updated', _onSocketEvent);
    SocketClient().off('transport:created', _onSocketEvent);
    SocketClient().off('service:updated', _onSocketEvent);
    SocketClient().off('service:created', _onSocketEvent);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isRefreshing) {
      _pendingRefresh = true;
      return;
    }
    _isRefreshing = true;
    _pendingRefresh = false;
    try {
      final driverFuture = ApiClient.get('/api/drivers/$_uid')
          .then((v) => v)
          .catchError((_) => <String, dynamic>{});
      final ordersFuture = ApiClient.getList(
              '/api/orders?driverId=$_uid&status=accepted,purchased,onway')
          .then((v) => v.cast<Map<String, dynamic>>())
          .catchError((_) => <Map<String, dynamic>>[]);
      final projectsFuture = ApiClient.getList(
              '/api/project-deliveries?driverId=$_uid&status=accepted,onway_to_store,picked_up,onway')
          .then((v) => v.cast<Map<String, dynamic>>())
          .catchError((_) => <Map<String, dynamic>>[]);
      final transportFuture = ApiClient.getList(
              '/api/transport-orders?driverId=$_uid&status=accepted,onway')
          .then((v) => v.cast<Map<String, dynamic>>())
          .catchError((_) => <Map<String, dynamic>>[]);
      final serviceFuture = ApiClient.getList(
              '/api/service-orders?driverId=$_uid&status=accepted,onway')
          .then((v) => v.cast<Map<String, dynamic>>())
          .catchError((_) => <Map<String, dynamic>>[]);

      final results = await Future.wait([
        driverFuture,
        ordersFuture,
        projectsFuture,
        transportFuture,
        serviceFuture,
      ]);
      if (!mounted) return;
      final driverData = results[0] as Map<String, dynamic>;
      if (driverData['vehicleType'] != null) {
        _vehicleType = driverData['vehicleType'] as String? ?? '';
      }
      final orders = results[1] as List<Map<String, dynamic>>;
      final projects = results[2] as List<Map<String, dynamic>>;
      final transport = results[3] as List<Map<String, dynamic>>;
      final service = results[4] as List<Map<String, dynamic>>;

      final combined = [...orders, ...projects, ...transport, ...service];
      combined.sort((a, b) {
        final ta = a['createdAt'] as String?;
        final tb = b['createdAt'] as String?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      combined.removeWhere(
          (item) => item['status'] == 'delivered' || item['status'] == 'cancelled');

      if (!mounted) return;
      setState(() {
        _allItems = combined;
        _loading = false;
      });
    } catch (e) {
      debugPrint("_loadData error: $e");
      if (mounted) setState(() => _loading = false);
    } finally {
      _isRefreshing = false;
      if (_pendingRefresh && mounted) _loadData();
    }
  }

  int get _count => _allItems.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgMain,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: kPrimary,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الطلبيات الجارية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  Text(
                    'اشتري ووصّل بأمان 🚚',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 10,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_vehicleType == 'motorcycle' && _allItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DriverRouteMapScreen(activeOrders: _allItems),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.map_rounded, color: kPrimary, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'تتبع المسار',
                        style: TextStyle(
                          color: kPrimary,
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _allItems.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _buildEmptyState(),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: kPrimary,
              child: ListView.builder(
                itemCount: _allItems.length,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, i) {
                  final d = _allItems[i];
                  return _OrderSummaryCard(
                    data: d,
                    index: i,
                    allOrderDocs: _allItems,
                    vehicleType: _vehicleType,
                    onRefresh: _loadData,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: kBgMain,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kShadow.withOpacity(0.5),
                  blurRadius: 14,
                  offset: const Offset(5, 5),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 14,
                  offset: Offset(-5, -5),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.bag, size: 42, color: kAccent),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد طلبيات جارية',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kTextDark,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ستظهر طلبياتك المقبولة هنا',
            style: TextStyle(
              fontSize: 13,
              color: kTextLight,
              fontFamily: 'Amiri',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  _OrderSummaryCard — كارد ملخّص الطلبية (ضغط → صفحة تفاصيل)
// ============================================================================
class _OrderSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final List<Map<String, dynamic>> allOrderDocs;
  final String vehicleType;
  final VoidCallback onRefresh;

  const _OrderSummaryCard({
    required this.data,
    required this.index,
    required this.allOrderDocs,
    required this.vehicleType,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'accepted';
    final isProject = data.containsKey('projectId');
    final isTransport = data.containsKey('transportType');
    final isService = data.containsKey('serviceType');

    final name = isProject
        ? (data['storeName'] as String? ?? 'صاحب المشروع')
        : (data['userName'] as String?
            ?? data['customerName'] as String?
            ?? data['name'] as String?
            ?? 'زبون');
    final address = data['address'] as String?
        ?? data['customerAddress'] as String?
        ?? data['deliveryAddress'] as String?
        ?? '';
    final double deliveryFee = (data['deliveryFee'] as num?
        ?? data['deliveryPrice'] as num?
        ?? 0).toDouble();
    final bool isFree = deliveryFee == 0;

    final items = data['items'] as List? ?? [];
    final int totalItems = isProject ? 1 : items.length;
    final bool allDone = isProject || (totalItems > 0 && items.where((it) {
      final s = (it as Map)['purchaseStatus'] as String? ?? '';
      return s == 'purchased' || s == 'unavailable';
    }).length == totalItems);

    final statusInfo = _statusInfo(status);

    final Set<String> stores = {};
    int notesCount = 0;
    for (final item in items) {
      final sn = (item as Map)['storeName'] as String? ?? '';
      final tn = item['templateName'] as String? ?? '';
      final cn = item['categoryName'] as String? ?? '';
      String header;
      if (cn.isNotEmpty && tn.isNotEmpty) {
        header = '$cn — $tn';
      } else if (sn.isNotEmpty && tn.isNotEmpty) {
        header = '$sn — $tn';
      } else if (sn.isNotEmpty) {
        header = sn;
      } else if (tn.isNotEmpty) {
        header = tn;
      } else {
        header = '';
      }
      if (header.isNotEmpty) stores.add(header);
      final n = item['note'] as String? ?? '';
      if (n.isNotEmpty) notesCount++;
    }
    if (data['storeName'] is String && (data['storeName'] as String).isNotEmpty) {
      stores.add(data['storeName'] as String);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverOrderDetailScreen(
              doc: data as dynamic,
              allOrderDocs: allOrderDocs as dynamic,
              vehicleType: vehicleType,
            ),
          ),
        ).then(
          (_) => onRefresh(),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // شريط الحالة العلوي
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusInfo['bg'] as Color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // رسوم التوصيل
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFree
                          ? Colors.orange.withOpacity(0.15)
                          : kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFree
                            ? Colors.orange.withOpacity(0.4)
                            : kGreenMid.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      isFree ? '🎁 مجاني' : '${deliveryFee.toInt()} DA',
                      style: TextStyle(
                        color: isFree ? Colors.orange.shade700 : kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                  const Spacer(),
                  // الحالة
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusInfo['label'] as String,
                        style: TextStyle(
                          color: statusInfo['color'] as Color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        statusInfo['icon'] as IconData,
                        color: statusInfo['color'] as Color,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // محتوى الكارد
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // صف اسم الزبون
                  Row(
                    children: [
                      // سهم الدخول
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryPale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          color: kPrimary,
                          size: 14,
                        ),
                      ),
                      const Spacer(),
                      // الاسم
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Amiri',
                              color: kTextDark,
                            ),
                          ),
                          if (address.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.location_fill,
                                  color: kAccent,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  address.length > 30
                                      ? '${address.substring(0, 30)}...'
                                      : address,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextLight,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // أفاتار
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kPrimary, kPrimaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // فاصل
                  const Divider(height: 1, color: kDivider),

                  const SizedBox(height: 12),

                  // معلومات سريعة
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // نوع الطلبية
                        _infoChip(
                          icon: isProject
                              ? CupertinoIcons.doc_text_fill
                              : isTransport
                                  ? CupertinoIcons.car_fill
                                  : isService
                                      ? CupertinoIcons.wrench_fill
                                      : CupertinoIcons.cart_fill,
                          label: isProject
                              ? 'مشروع'
                              : isTransport
                                  ? 'نقل'
                                  : isService
                                      ? 'خدمة'
                                      : '$totalItems منتج',
                          color: allDone ? kGreen : kPrimary,
                          bg: allDone ? kGreenBg : kPrimaryPale,
                        ),
                        // المحلات
                        if (stores.isNotEmpty)
                          _infoChip(
                            icon: CupertinoIcons.building_2_fill,
                            label: stores.length == 1
                                ? stores.first
                                : '${stores.length} محلات',
                            color: kTextMid,
                            bg: const Color(0xFFF0EDF8),
                          ),
                        // المنتجات بملاحظات
                        if (notesCount > 0)
                          _infoChip(
                            icon: CupertinoIcons.doc_text_fill,
                            label: '$notesCount ملاحظة',
                            color: kWarning,
                            bg: kWarning.withOpacity(0.12),
                          ),
                        // ضغط للتفاصيل
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [kPrimary, kPrimaryLight],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'عرض التفاصيل',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ملاحظات المنتجات
                  if (notesCount > 0) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: kDivider),
                    const SizedBox(height: 10),
                    ...items.where((it) {
                      final n = (it as Map)['note'] as String? ?? '';
                      return n.isNotEmpty;
                    }).map((it) {
                      final m = it as Map;
                      final n = m['note'] as String? ?? '';
                      final itemName = m['name'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(CupertinoIcons.doc_text_fill, color: kWarning, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$itemName: $n',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kWarning,
                                  fontFamily: 'Amiri',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  // وصف المشروع
                  if (isProject && data['description'] is String && (data['description'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: kDivider),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.doc_text_fill, color: kPrimary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data['description'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMid,
                              fontFamily: 'Amiri',
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color, size: 12),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'accepted':
        return {
          'bg': kPrimaryPale,
          'color': kPrimary,
          'label': 'في الطريق للمحل',
          'icon': CupertinoIcons.bag_fill,
        };
      case 'onway_to_store':
        return {
          'bg': kWarning.withOpacity(0.12),
          'color': kWarning,
          'label': 'في الطريق للمتجر',
          'icon': CupertinoIcons.car_fill,
        };
      case 'picked_up':
        return {
          'bg': kGreenBg,
          'color': kGreen,
          'label': 'تم الاستلام من المتجر',
          'icon': CupertinoIcons.checkmark_seal_fill,
        };
      case 'purchased':
        return {
          'bg': kGreenBg,
          'color': kGreen,
          'label': 'تم الشراء',
          'icon': CupertinoIcons.checkmark_seal_fill,
        };
      case 'onway':
      case 'in_transit':
        return {
          'bg': kPrimaryPale,
          'color': kPrimaryLight,
          'label': 'في الطريق للزبون',
          'icon': CupertinoIcons.car_fill,
        };
      case 'near_customer':
        return {
          'bg': kSuccess.withOpacity(0.12),
          'color': kSuccess,
          'label': 'قرب الزبون',
          'icon': CupertinoIcons.location_fill,
        };
      case 'delivered':
        return {
          'bg': kGreenBg,
          'color': kGreen,
          'label': 'تم إكمال الطلب',
          'icon': CupertinoIcons.checkmark_alt_circle_fill,
        };
      case 'cancelled':
        return {
          'bg': kRedBg,
          'color': kDanger,
          'label': 'ملغاة',
          'icon': CupertinoIcons.xmark_circle_fill,
        };
      default:
        return {
          'bg': kPrimaryPale,
          'color': kPrimary,
          'label': 'جارية',
          'icon': CupertinoIcons.clock_fill,
        };
    }
  }
}
