import 'dart:async';

import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'driver_route_map_screen.dart';
import 'driver_app.dart';
import 'driver_order_detail_screen.dart';
import 'fcm_helper.dart';
import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  DriverActiveOrdersScreen
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
  List<Map<String, dynamic>> _onlyStandardOrders = []; // ←
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

      final standardOnly = combined
          .where(
            (item) =>
                !item.containsKey('projectId') &&
                !item.containsKey('transportType') &&
                !item.containsKey('serviceType'),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _allItems = combined;
        _onlyStandardOrders = standardOnly;
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
              // أضف هذا هنا لكي يتمكن من التحديث حتى لو كانت فارغة
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _OrderSummaryCard — كارد ملخّص الطلبية (ضغط → صفحة تفاصيل)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _OrderSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;
  final List<Map<String, dynamic>> allOrderDocs;
  final VoidCallback onRefresh; // ✅ 1. أضف هذا السطر

  const _OrderSummaryCard({
    required this.data,
    required this.index,
    required this.allOrderDocs,
    required this.onRefresh, // ✅ 2. أضفه هنا أيضاً
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'accepted';
    final isProject = data.containsKey('projectId');
    final isTransport = data.containsKey('transportType');
    final isService = data.containsKey('serviceType');

    final name = data['userName'] as String?
        ?? data['customerName'] as String?
        ?? data['name'] as String?
        ?? 'زبون';
    final address = data['address'] as String?
        ?? data['customerAddress'] as String?
        ?? data['deliveryAddress'] as String?
        ?? '';
    final double deliveryFee = (data['deliveryFee'] as num?
        ?? data['deliveryPrice'] as num?
        ?? 0).toDouble();
    final bool isFree = deliveryFee == 0;

    // عدد المنتجات / المشاريع
    final items = data['items'] as List? ?? [];
    final int totalItems = isProject ? 1 : items.length;
    final bool allDone = isProject || (totalItems > 0 && items.where((it) {
      final s = (it as Map)['purchaseStatus'] as String? ?? '';
      return s == 'purchased' || s == 'unavailable';
    }).length == totalItems);

    // ألوان الحالة
    final statusInfo = _statusInfo(status);

    // تجميع أسماء المحلات
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
            ),
          ),
        ).then(
          (_) => onRefresh(),
        ); // ✅ 3. استعملها هنا (نحي الـ _ قبل loadData)
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
            // ── شريط الحالة العلوي ──
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

            // ── محتوى الكارد ──
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

                  // ── فاصل ──
                  const Divider(height: 1, color: kDivider),

                  const SizedBox(height: 12),

                  // ── معلومات سريعة ──
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

                  // ── ملاحظات المنتجات ──
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
                  // ── وصف المشروع ──
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
          'label': 'تم التوصيل',
          'icon': CupertinoIcons.checkmark_alt_circle_fill,
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _ProjectSummaryCard — كارد توصيلية مشروع في الطلبيات الجارية
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ProjectSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh; // 1. أضف هذا السطر

  const _ProjectSummaryCard({required this.data, required this.onRefresh});
  // 2. أضفه هنا في الـ Constructor

  @override
  Widget build(BuildContext context) {
    final customerName = data['customerName'] ?? 'زبون';
    final storeName = data['storeName'] ?? '';
    final address = data['customerAddress'] ?? '';
    final totalPrice = (data['totalPrice'] ?? 0).toDouble();
    final imageUrl = data['imageUrl'] ?? '';
    final status = data['status'] as String? ?? 'accepted';

    final statusInfo = _statusInfo2(status);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverOrderDetailScreen(
              doc: data as dynamic,
              allOrderDocs: [data] as dynamic,
            ),
          ),
        ).then((_) => onRefresh());
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGreenMid.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${totalPrice.toInt()} DA',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                  const Spacer(),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            customerName,
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
                        child: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.building_2_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: kDivider),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoChip(
                        icon: CupertinoIcons.building_2_fill,
                        label: storeName,
                        color: kTextMid,
                        bg: const Color(0xFFF0EDF8),
                      ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectActiveDetailSheet(data: d),
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

  Map<String, dynamic> _statusInfo2(String status) {
    switch (status) {
      case 'accepted':
        return {
          'bg': kPrimaryPale,
          'color': kPrimary,
          'label': 'في انتظار التوجه',
          'icon': CupertinoIcons.clock_fill,
        };
      case 'near_owner':
        return {
          'bg': kWarning.withOpacity(0.12),
          'color': kWarning,
          'label': 'قرب صاحبة المشروع',
          'icon': CupertinoIcons.location_fill,
        };
      case 'picked_up':
        return {
          'bg': kGreenBg,
          'color': kGreen,
          'label': 'تم الاستلام',
          'icon': CupertinoIcons.checkmark_seal_fill,
        };
      case 'in_transit':
        return {
          'bg': kPrimaryPale,
          'color': kPrimaryLight,
          'label': 'في الطريق للزبون',
          'icon': CupertinoIcons.car_fill,
        };
      case 'near_customer':
        return {
          'bg': kPrimaryPale,
          'color': kPrimary,
          'label': 'قرب الزبون',
          'icon': CupertinoIcons.location_fill,
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _ProjectActiveDetailSheet — تفاصيل توصيلية مشروع في الطلبيات الجارية
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _ProjectActiveDetailSheet extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ProjectActiveDetailSheet({required this.data});

  @override
  State<_ProjectActiveDetailSheet> createState() => _ProjectActiveDetailSheetState();
}

class _ProjectActiveDetailSheetState extends State<_ProjectActiveDetailSheet> {
  static final Map<String, DateTime> _lastRingTimes = {};
  static const Duration _ringCooldown = Duration(seconds: 30);
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  int _ringRemainingSeconds(String orderId) {
    final lastRing = _lastRingTimes[orderId];
    if (lastRing == null) return 0;
    final elapsed = DateTime.now().difference(lastRing);
    final remaining = _ringCooldown - elapsed;
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }
  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final storeName = d['storeName'] ?? '';
    final customerName = d['customerName'] ?? 'زبون';
    final customerPhone = d['customerPhone'] ?? '';
    final bool phoneHidden = d['phoneHidden'] as bool? ?? false;
    final description = d['description'] ?? '';
    final imageUrl = d['imageUrl'] ?? '';
    final deliveryPrice = (d['deliveryPrice'] ?? 0).toDouble();
    final productPrice = (d['productPrice'] ?? 0).toDouble();
    final totalPrice = (d['totalPrice'] ?? 0).toDouble();
    final address = d['customerAddress'] ?? '';
    final double? lat = (d['customerLat'] as num?)?.toDouble();
    final double? lng = (d['customerLng'] as num?)?.toDouble();
    final hasCoords = (lat != null && lat != 0 && lng != null && lng != 0);

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: kBgMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تفاصيل توصيلية مشروع',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 20),
            if (imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (imageUrl.isNotEmpty) const SizedBox(height: 16),
            _row(CupertinoIcons.building_2_fill, 'المتجر', storeName),
            _row(CupertinoIcons.person_fill, 'الزبون', customerName),
            if (customerPhone.isNotEmpty && !phoneHidden)
              _row(CupertinoIcons.phone_fill, 'الهاتف', customerPhone),
            _row(CupertinoIcons.doc_text_fill, 'الوصف', description),
            if (d['capacite'] != null && (d['capacite'] as String).isNotEmpty)
              _row(CupertinoIcons.resize, 'الحجم', d['capacite'] as String),
            _row(
              Icons.local_shipping_outlined,
              'سعر التوصيل',
              '${deliveryPrice.toInt()} DA',
            ),
            _row(
              Icons.monetization_on_outlined,
              'سعر المنتج',
              '${productPrice.toInt()} DA',
            ),
            _row(CupertinoIcons.money_dollar, 'المجموع', '${totalPrice.toInt()} DA'),
            _row(CupertinoIcons.location_fill, 'العنوان', address),
            if (hasCoords) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final uri =
                              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                          launchUrlString(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text(
                          'موقع الزبون',
                          style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: _buildRingButton(d),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRingButton(Map<String, dynamic> d) {
    final orderId = d['_id']?.toString() ?? '';
    final remaining = _ringRemainingSeconds(orderId);
    final inCooldown = remaining > 0;

    return ElevatedButton.icon(
      onPressed: inCooldown
          ? null
          : () async {
              final userId = d['userId'];
              if (userId != null) {
                _lastRingTimes[orderId] = DateTime.now();
                final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                FCMHelper.sendToUser(
                  userId: userId,
                  title: '🔔 رنين من السائق',
                  body: 'السائق يتصل بك، اخرج لاستلام طلبيتك',
                  data: {
                    'orderId': d['_id'],
                    'sound': 'ring',
                    'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                    'driverPhoto': '${dData['photoUrl'] ?? ''}',
                  },
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 تم إشعار الزبون!', style: TextStyle(fontFamily: 'Amiri')),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
      icon: Icon(inCooldown ? CupertinoIcons.timer : CupertinoIcons.bell_fill, size: 18),
      label: Text(
        inCooldown ? '$remaining s' : 'رنين 🔔',
        style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: inCooldown ? Colors.grey : Colors.orange,
        disabledBackgroundColor: Colors.grey.shade400,
        disabledForegroundColor: Colors.white70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Amiri',
                color: kTextDark,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: kTextLight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _TransportSummaryCard — كارد طلبية نقل جارية (مقبولة)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _TransportSummaryCard extends StatelessWidget {
  final VoidCallback onRefresh; // 1. أضف السطر
  final Map<String, dynamic> data;
  const _TransportSummaryCard({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] ?? 'زبون';
    final transportType = data['transportType'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final toAddr = data['toAddress'] as String? ?? '';
    final price = (data['price'] as num? ?? 0).toDouble();
    final parcelImage = data['parcelImageUrl'] as String? ?? '';

    return GestureDetector(
      onTap: () async {
        await _showDetail(context, data);
        onRefresh();
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: kPrimaryPale,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGreenMid.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${price.toInt()} DA',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    transportType,
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    CupertinoIcons.car_detailed,
                    color: kPrimary,
                    size: 16,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Amiri',
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                fromAddr.length > 20
                                    ? '${fromAddr.substring(0, 20)}...'
                                    : fromAddr,
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimary, kPrimaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: parcelImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: parcelImage,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.car_detailed,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: kDivider),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoChip(
                        icon: Icons.location_on,
                        label: toAddr.length > 15
                            ? '${toAddr.substring(0, 15)}...'
                            : toAddr,
                        color: kTextMid,
                        bg: const Color(0xFFF0EDF8),
                      ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, Map<String, dynamic> d) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransportActiveDetailSheet(data: d),
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
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _TransportActiveDetailSheet — تفاصيل طلبية نقل جارية
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _TransportActiveDetailSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const _TransportActiveDetailSheet({required this.data});

  @override
  State<_TransportActiveDetailSheet> createState() =>
      _TransportActiveDetailSheetState();
}

class _TransportActiveDetailSheetState
    extends State<_TransportActiveDetailSheet> {
  bool _loading = false;

  String get _orderId => widget.data['_id'] ?? '';
  String get _userId => widget.data['userId'] ?? '';

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await ApiClient.put('/api/transport-orders/$_orderId', {
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      // Server sends FCM for status changes
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? 'accepted';
    final userName = d['userName'] ?? 'زبون';
    final userPhone = d['userPhone'] as String? ?? '';
    final userPhoneHidden = d['phoneHidden'] as bool? ?? false;
    final transportType = d['transportType'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final fromAddr = d['fromAddress'] as String? ?? '';
    final toAddr = d['toAddress'] as String? ?? '';
    final price = (d['price'] as num? ?? 0).toDouble();
    final fromImage = d['fromImage'] as String? ?? '';
    final toImage = d['toImage'] as String? ?? '';
    final parcelImage = d['parcelImageUrl'] as String? ?? '';
    final double? fromLat = (d['fromLat'] as num?)?.toDouble();
    final double? fromLng = (d['fromLng'] as num?)?.toDouble();
    final double? toLat = (d['toLat'] as num?)?.toDouble();
    final double? toLng = (d['toLng'] as num?)?.toDouble();
    final hasFromCoords =
        (fromLat != null && fromLat != 0 && fromLng != null && fromLng != 0);
    final hasToCoords =
        (toLat != null && toLat != 0 && toLng != null && toLng != 0);

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: kBgMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تفاصيل طلب النقل',
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  transportType,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    color: kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (parcelImage.isNotEmpty)
              Container(
                width: double.infinity,
                height: 160,
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: parcelImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            _row(CupertinoIcons.person_fill, 'الزبون', userName),
            if (userPhone.isNotEmpty && !userPhoneHidden)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:$userPhone');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: _row(
                  CupertinoIcons.phone_fill,
                  'الهاتف',
                  userPhone,
                  kSuccess,
                ),
              ),
            if (note.isNotEmpty)
              _row(CupertinoIcons.doc_text_fill, 'الوصف', note),
            _locationRow(
              CupertinoIcons.location_fill,
              'موقع الاستلام',
              fromAddr,
              fromLat,
              fromLng,
            ),
            _locationRow(
              Icons.location_on,
              'موقع التوصيل',
              toAddr,
              toLat,
              toLng,
            ),
            _row(CupertinoIcons.money_dollar, 'السعر', '${price.toInt()} DA'),
            if (fromImage.isNotEmpty)
              Container(
                width: double.infinity,
                height: 100,
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: fromImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (toImage.isNotEmpty)
              Container(
                width: double.infinity,
                height: 100,
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: toImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (hasFromCoords && hasToCoords) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final uri =
                        'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng&destination=$toLat,$toLng';
                    launchUrlString(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text(
                    'فتح الطريق من الاستلام إلى التوصيل',
                    style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (hasFromCoords) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final uri =
                          'https://www.google.com/maps/dir/?api=1&destination=$fromLat,$fromLng';
                      launchUrlString(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text(
                      'فتح موقع الاستلام في الخريطة',
                      style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              if (hasToCoords) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final uri =
                          'https://www.google.com/maps/dir/?api=1&destination=$toLat,$toLng';
                      launchUrlString(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text(
                      'فتح موقع التوصيل في الخريطة',
                      style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            if (status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _updateStatus('onway'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_right_circle_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'باشر التوصيل',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            if (status == 'onway')
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () {
                        setState(() => _loading = true);
                        if (_userId.isNotEmpty) {
                          FCMHelper.sendToUser(
                            userId: _userId,
                            title: '🚗 السائق راه قريب يوصل',
                            body: 'السائق راه قريب يوصل، وجّد روحك',
                            data: {'orderId': _orderId},
                          );
                        }
                        setState(() => _loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إشعار الزبون أنك قريب', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.car_fill, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('راني قريب نوصل', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () async {
                        setState(() => _loading = true);
                        if (_userId.isNotEmpty) {
                          final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                          FCMHelper.sendToUser(
                            userId: _userId,
                            title: '📍 السائق في موقع التوصيل',
                            body: 'السائق وصل إلى عنوانك، اخرج لاستلام طلبيتك',
                            data: {
                              'orderId': _orderId,
                              'sound': 'okhrej',
                              'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                              'driverPhoto': '${dData['photoUrl'] ?? ''}',
                            },
                          );
                        }
                        setState(() => _loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إشعار الزبون بوصولك', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.location_fill, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('اخرج اخرج', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _updateStatus('delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSuccess,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'تم التوصيل',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              if (status == 'delivered')
                Center(
                  child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kSuccess.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تم التوصيل بنجاح',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: kSuccess,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: kSuccess,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, [Color? highlight]) {
    final color = highlight ?? kTextDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: kPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  color: color,
                  fontSize: 13,
                  fontWeight: highlight != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label:',
              style: const TextStyle(
                fontFamily: 'Amiri',
                color: kTextLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(
    IconData icon,
    String label,
    String address,
    double? lat,
    double? lng,
  ) {
    final hasCoords = (lat != null && lat != 0 && lng != null && lng != 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: hasCoords
            ? () {
                final uri =
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                launchUrlString(uri, mode: LaunchMode.externalApplication);
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasCoords ? kPrimary.withOpacity(0.4) : kBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: hasCoords ? kPrimary : kTextLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    color: kTextDark,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$label:',
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  color: kTextLight,
                  fontSize: 11,
                ),
              ),
              if (hasCoords) ...[
                const SizedBox(width: 6),
                Icon(Icons.open_in_new, size: 14, color: kPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _ServiceSummaryCard — كارد طلبية توصيل/إحضار جارية (مقبولة)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ServiceSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _ServiceSummaryCard({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] ?? 'زبون';
    final serviceType = data['serviceType'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final toAddr = data['toAddress'] as String? ?? '';
    final price = (data['price'] as num? ?? 0).toDouble();
    final isDelivery = serviceType == 'delivery';

    return GestureDetector(
      onTap: () async {
        await _showDetail(context, data);
        onRefresh();
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: kPrimaryPale,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kGreenMid.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${price.toInt()} DA',
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isDelivery ? 'توصيل' : 'إحضار',
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.moped, color: kPrimary, size: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Amiri',
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                fromAddr.length > 20
                                    ? '${fromAddr.substring(0, 20)}...'
                                    : fromAddr,
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimary, kPrimaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.moped,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: kDivider),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoChip(
                        icon: Icons.location_on,
                        label: toAddr.length > 15
                            ? '${toAddr.substring(0, 15)}...'
                            : toAddr,
                        color: kTextMid,
                        bg: const Color(0xFFF0EDF8),
                      ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, Map<String, dynamic> d) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceActiveDetailSheet(data: d),
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
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  _ServiceActiveDetailSheet — تفاصيل طلبية توصيل/إحضار جارية
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ServiceActiveDetailSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ServiceActiveDetailSheet({required this.data});

  @override
  State<_ServiceActiveDetailSheet> createState() =>
      _ServiceActiveDetailSheetState();
}

class _ServiceActiveDetailSheetState extends State<_ServiceActiveDetailSheet> {
  bool _loading = false;

  String get _orderId => widget.data['_id'] ?? '';
  String get _userId => widget.data['userId'] ?? '';

  Future<void> _updateStatus(String newStatus, {String label = ''}) async {
    setState(() => _loading = true);
    try {
      await ApiClient.put('/api/service-orders/$_orderId', {
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      // Server sends FCM for status changes
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status = d['status'] as String? ?? 'accepted';
    final userName = d['userName'] ?? 'زبون';
    final userPhone = d['userPhone'] as String? ?? '';
    final userPhoneHidden = d['phoneHidden'] as bool? ?? false;
    final serviceType = d['serviceType'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final orderName = d['orderName'] as String? ?? '';
    final fromAddr = d['fromAddress'] as String? ?? '';
    final toAddr = d['toAddress'] as String? ?? '';
    final price = (d['price'] as num? ?? 0).toDouble();
    final parcelImage = d['parcelImageUrl'] as String? ?? '';
    final double? fromLat = (d['fromLat'] as num?)?.toDouble();
    final double? fromLng = (d['fromLng'] as num?)?.toDouble();
    final double? toLat = (d['toLat'] as num?)?.toDouble();
    final double? toLng = (d['toLng'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: kBgMain,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تفاصيل طلب ${serviceType == 'delivery' ? 'التوصيل' : 'الإحضار'}',
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  serviceType == 'delivery'
                      ? 'توصيل الطلبيات'
                      : 'إحضار الطلبيات',
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    color: kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (parcelImage.isNotEmpty)
              Container(
                width: double.infinity,
                height: 160,
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: parcelImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            _row(CupertinoIcons.person_fill, 'الزبون', userName),
            if (userPhone.isNotEmpty && !userPhoneHidden)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:$userPhone');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: _row(
                  CupertinoIcons.phone_fill,
                  'الهاتف',
                  userPhone,
                  kSuccess,
                ),
              ),
            if (note.isNotEmpty)
              _row(CupertinoIcons.doc_text_fill, 'الوصف', note),
            if (orderName.isNotEmpty)
              _row(CupertinoIcons.bag_fill, 'اسم الطلبية', orderName),
            _locationRow(CupertinoIcons.location_fill, 'موقع الاستلام', fromAddr, fromLat, fromLng),
            _locationRow(Icons.location_on, 'موقع التوصيل', toAddr, toLat, toLng),
            _row(CupertinoIcons.money_dollar, 'السعر', '${price.toInt()} DA'),
            const SizedBox(height: 20),
            if (status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _updateStatus('onway'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_right_circle_fill,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'باشر التوصيل',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            if (status == 'onway')
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () {
                        setState(() => _loading = true);
                        if (_userId.isNotEmpty) {
                          FCMHelper.sendToUser(
                            userId: _userId,
                            title: '🚗 السائق راه قريب يوصل',
                            body: 'السائق راه قريب يوصل، وجّد روحك',
                            data: {'orderId': _orderId},
                          );
                        }
                        setState(() => _loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إشعار الزبون أنك قريب', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.car_fill, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('راني قريب نوصل', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () async {
                        setState(() => _loading = true);
                        if (_userId.isNotEmpty) {
                          final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                          FCMHelper.sendToUser(
                            userId: _userId,
                            title: '📍 السائق في موقع التوصيل',
                            body: 'السائق وصل إلى عنوانك، اخرج لاستلام طلبيتك',
                            data: {
                              'orderId': _orderId,
                              'sound': 'okhrej',
                              'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                              'driverPhoto': '${dData['photoUrl'] ?? ''}',
                            },
                          );
                        }
                        setState(() => _loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إشعار الزبون بوصولك', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.location_fill, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('اخرج اخرج', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _updateStatus('delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSuccess,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'تم التوصيل',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              if (status == 'delivered')
                Center(
                  child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kSuccess.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تم التوصيل بنجاح',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: kSuccess,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: kSuccess,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(
    IconData icon,
    String label,
    String address,
    double? lat,
    double? lng,
  ) {
    final hasCoords = (lat != null && lat != 0 && lng != null && lng != 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: hasCoords
            ? () {
                final uri =
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                launchUrlString(uri, mode: LaunchMode.externalApplication);
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasCoords ? kPrimary.withOpacity(0.4) : kBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: hasCoords ? kPrimary : kTextLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    color: kTextDark,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$label:',
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  color: kTextLight,
                  fontSize: 11,
                ),
              ),
              if (hasCoords) ...[
                const SizedBox(width: 6),
                Icon(Icons.open_in_new, size: 14, color: kPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, [
    Color? highlight,
  ]) {
    final color = highlight ?? kTextDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: kPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Amiri',
                  color: color,
                  fontSize: 13,
                  fontWeight: highlight != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label:',
              style: const TextStyle(
                fontFamily: 'Amiri',
                color: kTextLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



