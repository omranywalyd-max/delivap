import 'dart:io';
import 'package:dashbord/map_picker_screen.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:dashbord/fcm_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

String _fmt(dynamic n) {
  if (n == null) return '0';
  final num v = n is num ? n : (num.tryParse(n.toString()) ?? 0);
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

const Color _kBg = Color(0xFFE8E6F0);
const Color _kPrimary = Color(0xFF5B0094);
const Color _kPrimaryLight = Color(0xFF9B59C8);
const Color _kDanger = Color(0xFFE53E6A);
const Color _kSuccess = Color(0xFF27AE7A);
const Color _kWarning = Color(0xFFF39C12);
const Color _kTextPrimary = Color(0xFF2D2540);
const Color _kTextSecondary = Color(0xFF7B6E99);

List<BoxShadow> _neuShadow({double blur = 10, double offset = 4}) => [
  BoxShadow(
    color: const Color(0xFFB8B1C8).withOpacity(0.6),
    blurRadius: blur,
    offset: Offset(offset, offset),
  ),
  BoxShadow(
    color: Colors.white,
    blurRadius: blur,
    offset: Offset(-offset, -offset),
  ),
];

BoxDecoration _neuBox({double radius = 16, EdgeInsetsGeometry? padding}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
      ),
      boxShadow: _neuShadow(),
      border: Border.all(color: _kPrimary.withOpacity(0.1)),
    );

class OwnerProjectOrdersPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String ownerId;
  const OwnerProjectOrdersPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.ownerId,
  });

  @override
  State<OwnerProjectOrdersPage> createState() => _OwnerProjectOrdersPageState();
}

class _OwnerProjectOrdersPageState extends State<OwnerProjectOrdersPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    SocketClient().join('user_${widget.ownerId}');
    SocketClient().on('project:created', (_) => _loadProjects());
    SocketClient().on('project:updated', (_) => _loadProjects());
    SocketClient().on('order:created', _onOwnerOrderCreated);
  }

  void _onOwnerOrderCreated(_) => _loadProjects();

  @override
  void dispose() {
    SocketClient().off('project:created');
    SocketClient().off('project:updated');
    SocketClient().off('order:created', _onOwnerOrderCreated);
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final results = await Future.wait([
        ApiClient.getList('/api/projects?storeId=${widget.storeId}'),
        ApiClient.getList('/api/project-deliveries?storeOwnerId=${widget.ownerId}'),
      ]);
      final projects = (results[0] as List).cast<Map<String, dynamic>>();
      final deliveries = (results[1] as List).cast<Map<String, dynamic>>();
      final delMap = <String, Map<String, dynamic>>{};
      for (final d in deliveries) {
        final pid = d['projectId'] as String? ?? '';
        if (pid.isNotEmpty) delMap[pid] = d;
      }
      for (final p in projects) {
        final pid = p['_id'] as String? ?? '';
        if (delMap.containsKey(pid)) {
          p['_delivery'] = delMap[pid];
        }
      }
      if (mounted) {
        setState(() {
          _projects = projects;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNewDelivery() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateDeliveryPage()),
    );
    if (result == null) return;
    if (!mounted) return;

    final imagePath = result['imagePath'] as String;
    final productName = result['product'] as String;

    // رفع الصورة
    String? imageUrl;
    try {
      imageUrl = await ApiClient.upload(File(imagePath));
    } catch (_) {}

    // اختيار السائق
    final driverDoc = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _DriverSelectionPage(storeId: widget.storeId)),
    );
    if (driverDoc == null) return;
    if (!mounted) return;
    final driverId = driverDoc['id'] as String;
    final driverName = driverDoc['name'] as String;

    // الحصول على userId الخاص بالسائق للإشعارات
    String driverUserId = '';
    try {
      final driverData = await ApiClient.get('/api/drivers/$driverId');
      driverUserId = (driverData['userId'] as String?) ?? (driverData['uid'] as String?) ?? '';
    } catch (_) {}

    // إنشاء مشروع أولاً
    setState(() => _processing = true);
    try {
      final productPrice = (result['productPrice'] as num).toDouble();
      final deliveryPrice = (result['deliveryPrice'] as num).toDouble();
      final project = await ApiClient.post('/api/projects', {
        'name': result['name'],
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'productPrice': productPrice,
        'productName': productName,
        'imageUrl': imageUrl ?? '',
        'description': result['extra'],
        'storeLat': result['pickupLat'],
        'storeLng': result['pickupLng'],
        'location': result['pickupAddress'],
        'userLat': result['deliveryLat'],
        'userLng': result['deliveryLng'],
        'status': 'processing',
      });
      final projectId = project['_id'] as String? ?? '';

      // إنشاء التوصيلية
      final delivery = await ApiClient.post('/api/project-deliveries', {
        'projectId': projectId,
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'storeOwnerId': widget.ownerId,
        'customerName': result['name'],
        'productName': productName,
        'imageUrl': imageUrl ?? '',
        'productPrice': productPrice,
        'deliveryPrice': deliveryPrice,
        'totalPrice': productPrice + deliveryPrice,
        'description': result['extra'],
        'storeLat': result['pickupLat'],
        'storeLng': result['pickupLng'],
        'storeAddress': result['pickupAddress'],
        'customerLat': result['deliveryLat'],
        'customerLng': result['deliveryLng'],
        'customerAddress': result['deliveryAddress'],
        'driverId': driverId,
        'driverName': driverName,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // إشعار للسائق بتوصيلية جديدة
      if (driverUserId.isNotEmpty) {
        FCMHelper.sendToUser(
          userId: driverUserId,
          title: '📦 توصيلية مشروع جديد',
          body: 'من ${widget.storeName} | ${_fmt(deliveryPrice)} دج',
          data: {'deliveryId': (delivery['_id'] as String?) ?? '', 'type': 'project_delivery'},
        );
      }

      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إنشاء التوصيلية', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: _kSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProjects();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _projects.where((p) {
      final s = p['status'] as String? ?? '';
      return s == 'pending' || s == 'processing';
    }).toList();
    final finished = _projects.where((p) {
      final s = p['status'] as String? ?? '';
      return s == 'completed' || s == 'cancelled' || s == 'delivered';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          title: const Text(
            "طلبات المشاريع",
            style: TextStyle(fontFamily: 'Amiri', color: _kTextPrimary, fontSize: 16),
          ),
          backgroundColor: _kBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kPrimary),
          bottom: TabBar(
            indicatorColor: _kPrimary,
            indicatorWeight: 3,
            labelColor: _kPrimary,
            unselectedLabelColor: _kTextSecondary,
            labelStyle: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
            tabs: [
              Tab(text: 'جارية (${active.length})'),
              Tab(text: 'منتهية (${finished.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : TabBarView(
                children: [
                  _buildList(active, emptyMsg: 'لا توجد طلبات جارية'),
                  _buildList(finished, emptyMsg: 'لا توجد طلبات منتهية'),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNewDelivery,
          backgroundColor: _kPrimary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "إضافة طلبية جديدة",
            style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required String emptyMsg}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.doc_text, size: 60, color: _kTextSecondary.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text(emptyMsg, style: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final d = items[i];
        return _ProjectOrderCard(
          projectId: d['_id'] ?? '',
          data: d,
          storeId: widget.storeId,
          storeName: widget.storeName,
          ownerId: widget.ownerId,
          onRefresh: _loadProjects,
        );
      },
    );
  }
}

class _ProjectOrderCard extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> data;
  final String storeId;
  final String storeName;
  final String ownerId;
  final VoidCallback onRefresh;

  const _ProjectOrderCard({
    required this.projectId,
    required this.data,
    required this.storeId,
    required this.storeName,
    required this.ownerId,
    required this.onRefresh,
  });

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is String) {
      try {
        final dt = DateTime.parse(ts);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return '';
  }

  Widget _buildPriceRow() {
    final del = data['_delivery'] as Map<String, dynamic>?;
    if (del == null) return const SizedBox.shrink();
    final counter = del['counterOffer'] as Map<String, dynamic>?;
    if (counter != null) {
      final proposed = (counter['proposedPrice'] as num? ?? 0).toDouble();
      final driverName = counter['driverName'] as String? ?? '';
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_fmt(proposed)} دج', style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13, color: _kDanger)),
            const SizedBox(width: 4),
            Text('اقتراح $driverName', style: const TextStyle(fontFamily: 'Amiri', fontSize: 10, color: _kTextSecondary)),
          ],
        ),
      );
    }
    final total = (del['totalPrice'] as num? ?? 0).toDouble();
    if (total > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_fmt(total)} دج', style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
            const SizedBox(width: 4),
            const Text('المجموع', style: const TextStyle(fontFamily: 'Amiri', fontSize: 10, color: _kTextSecondary)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'زبون';
    final phone = data['phone'] ?? '';
    final status = data['status'] ?? 'pending';
    final imageUrl = data['imageUrl'] ?? '';
    final desc = data['description'] ?? '';
    final location = data['location'] ?? '';
    final quantity = data['quantity'];
    final productPrice = data['productPrice'];

    Map<String, dynamic> _statusMeta(String s) {
      switch (s) {
        case 'pending': return {'label': 'جديد', 'color': _kWarning};
        case 'processing': return {'label': 'قيد المعالجة', 'color': Colors.orange};
        case 'completed': return {'label': 'مكتمل', 'color': _kSuccess};
        case 'delivered': return {'label': 'تم التوصيل', 'color': _kSuccess};
        case 'cancelled': return {'label': 'ملغي', 'color': _kDanger};
        default: return {'label': s, 'color': _kTextSecondary};
      }
    }
    final st = _statusMeta(status);
    final statusColor = st['color'] as Color;
    final statusLabel = st['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _showDetail(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _neuBox(),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.bold,
                          color: _kTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      color: _kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(data['createdAt']),
                    style: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary, fontSize: 11),
                  ),
                  if (quantity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'الكمية: $quantity',
                        style: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary, fontSize: 11),
                      ),
                    ),
                  if (productPrice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'السعر: ${_fmt(productPrice)} دج',
                        style: const TextStyle(fontFamily: 'Amiri', color: _kPrimary, fontSize: 11),
                      ),
                    ),
                  _buildPriceRow(),
                ],
              ),
              const Spacer(),
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: _kBg,
                      child: const Icon(
                        Icons.image_outlined,
                        color: _kTextSecondary,
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

  Future<void> _showDetail(BuildContext context) async {
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectOrderDetailSheet(
        projectId: projectId,
        data: data,
        storeId: storeId,
        storeName: storeName,
        ownerId: ownerId,
        onDeleted: onRefresh,
        onReady: onRefresh,
      ),
    );
  }
}

class _ProjectOrderDetailSheet extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> data;
  final String storeId;
  final String storeName;
  final String ownerId;
  final VoidCallback onDeleted;
  final VoidCallback onReady;

  const _ProjectOrderDetailSheet({
    required this.projectId,
    required this.data,
    required this.storeId,
    required this.storeName,
    required this.ownerId,
    required this.onDeleted,
    required this.onReady,
  });

  @override
  State<_ProjectOrderDetailSheet> createState() =>
      _ProjectOrderDetailSheetState();
}

class _ProjectOrderDetailSheetState extends State<_ProjectOrderDetailSheet> {
  bool _processing = false;

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is String) {
      try {
        final dt = DateTime.parse(ts);
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return '';
  }

  Future<void> _rejectProject() async {
    final TextEditingController reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "رفض الطلب",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "هل أنت متأكد من رفض طلب المشروع هذا؟",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'سبب الرفض (اختياري)',
                hintStyle: const TextStyle(
                  fontFamily: 'Amiri',
                  color: _kTextSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Amiri')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "رفض",
              style: TextStyle(fontFamily: 'Amiri', color: _kDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    await ApiClient.put('/api/projects/${widget.projectId}', {
      'status': 'rejected',
      'rejectReason': reasonCtrl.text.trim(),
      'rejectedAt': DateTime.now().toIso8601String(),
    });
    if (widget.data['userId'] != null) {
      await ApiClient.post('/api/notifications', {
        'toId': widget.data['userId'],
        'title': '❌ تم رفض طلب المشروع',
        'body': reasonCtrl.text.trim().isNotEmpty
            ? 'سبب الرفض: ${reasonCtrl.text.trim()}'
            : 'تم رفض طلب مشروعك من قبل التاجر.',
        'type': 'project_rejected',
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
      });
    }
    if (mounted) {
      Navigator.pop(context);
      widget.onReady();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ تم رفض الطلب وإشعار الزبون',
            style: TextStyle(fontFamily: 'Amiri'),
          ),
          backgroundColor: _kWarning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _acceptProject() async {
    setState(() => _processing = true);
    final ctx = context;

    // 1) تحديد الموقع + السعر (شيت واحد)
    if (!ctx.mounted) { if (mounted) setState(() => _processing = false); return; }
    final customerPrice = (widget.data['productPrice'] as num? ?? 0).toDouble();
    final locationAndPrices = await showModalBottomSheet<Map<String, dynamic>>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationAndPriceSheet(initialProductPrice: customerPrice),
    );
    if (locationAndPrices == null) { if (mounted) setState(() => _processing = false); return; }

    final sLat = locationAndPrices['lat'] as double;
    final sLng = locationAndPrices['lng'] as double;
    final sAddress = locationAndPrices['address'] as String? ?? '';
    final deliveryPrice = locationAndPrices['deliveryPrice'] as double;
    final productPrice = locationAndPrices['productPrice'] as double;

    // 2) اختيار السائق
    if (!ctx.mounted) { if (mounted) setState(() => _processing = false); return; }
    final driverDoc = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _DriverSelectionPage(storeId: widget.storeId)),
    );
    if (driverDoc == null) { if (mounted) setState(() => _processing = false); return; }
    final driverId = driverDoc['id'] as String;
    final driverName = driverDoc['name'] as String;

    // الحصول على userId الخاص بالسائق للإشعارات
    String driverUserId = '';
    try {
      final driverData = await ApiClient.get('/api/drivers/$driverId');
      driverUserId = (driverData['userId'] as String?) ?? (driverData['uid'] as String?) ?? '';
    } catch (_) {}

    // 3) إنشاء التوصيلية
    setState(() => _processing = true);
    try {
      final Map<String, dynamic> delivery = await ApiClient.post('/api/project-deliveries', {
        'projectId': widget.projectId,
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'storeOwnerId': widget.ownerId,
        'customerName': widget.data['name'] ?? '',
        'customerPhone': widget.data['phone'] ?? '',
        'customerAddress': widget.data['location'] ?? '',
        'customerLat': (widget.data['userLat'] ?? 0).toDouble(),
        'customerLng': (widget.data['userLng'] ?? 0).toDouble(),
        'description': widget.data['description'] ?? '',
        'imageUrl': widget.data['imageUrl'] ?? '',
        'userId': widget.data['userId'] ?? '',
        'deliveryPrice': deliveryPrice,
        'productPrice': productPrice,
        'totalPrice': deliveryPrice + productPrice,
        'storeLat': sLat,
        'storeLng': sLng,
        'storeAddress': sAddress,
        'driverId': driverId,
        'driverName': driverName,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // تحديث حالة المشروع
      await ApiClient.put('/api/projects/${widget.projectId}', {'status': 'processing'});

      // إشعار للسائق بتوصيلية جديدة
      if (driverUserId.isNotEmpty) {
        FCMHelper.sendToUser(
          userId: driverUserId,
          title: '📦 توصيلية مشروع جديد',
          body: 'من ${widget.storeName} إلى ${widget.data['name'] ?? ''} | ${_fmt(deliveryPrice)} دج',
          data: {'deliveryId': (delivery['_id'] as String?) ?? '', 'type': 'project_delivery'},
        );
      }

      // حفظ التوصيلية في data باش تظهر في الشيت
      widget.data['_delivery'] = delivery;

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('✅ تم إرسال التوصيلية إلى $driverName، في انتظار رده'),
            backgroundColor: _kSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: _kDanger),
        );
      }
    }
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] ?? 'زبون';
    final phone = widget.data['phone'] ?? '';
    final desc = widget.data['description'] ?? '';
    final capacite = widget.data['capacite'] ?? '';
    final location = widget.data['location'] ?? '';
    final imageUrl = widget.data['imageUrl'] ?? '';
    final quantity = widget.data['quantity'];
    final productPrice = widget.data['productPrice'];
    final isPending = (widget.data['status'] ?? 'pending') == 'pending';

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isPending)
                  Row(
                    children: [
                      _actionBtn(
                        Icons.close_rounded,
                        _kWarning,
                        _rejectProject,
                        label: 'رفض',
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        Icons.check_circle_outline,
                        _kSuccess,
                        _acceptProject,
                        label: 'قبول',
                      ),
                    ],
                  ),
                const Text(
                  "تفاصيل الطلب",
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (imageUrl.isNotEmpty) const SizedBox(height: 16),
            _infoRow(CupertinoIcons.person_fill, 'الاسم', name),
            _infoRow(CupertinoIcons.phone_fill, 'الهاتف', phone),
            _infoRow(CupertinoIcons.doc_text_fill, 'الوصف', desc),
            _infoRow(CupertinoIcons.location_fill, 'الموقع', location),
            if (quantity != null)
              _infoRow(Icons.shopping_bag_outlined, 'الكمية', '$quantity'),
            if (capacite != null && capacite.toString().isNotEmpty)
              _infoRow(CupertinoIcons.resize, 'المقاس / الحجم', '$capacite'),
            if (productPrice != null)
              _infoRow(Icons.monetization_on_outlined, 'سعر المنتجات', '${_fmt(productPrice)} دج'),
            _infoRow(
              CupertinoIcons.clock_fill,
              'التاريخ',
              _formatDate(widget.data['createdAt']),
            ),
            // حالة التوصيل إن وجدت
            _buildDeliveryStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatus() {
    final delivery = widget.data['_delivery'] as Map<String, dynamic>?;
    if (delivery == null) return const SizedBox.shrink();
    final status = delivery['status'] ?? '';
    final driverName = delivery['driverName'] ?? '';
    final counterOffer = delivery['counterOffer'];
    final hasCounter = counterOffer != null && counterOffer['status'] == 'pending';
    final isPendingDriver = status == 'pending';

    String statusText;
    Color statusColor;
    switch (status) {
      case 'pending':
        statusText = '🚚 في انتظار رد السائق';
        statusColor = _kWarning;
        break;
      case 'accepted':
        statusText = '✅ السائق قبل التوصيلية';
        statusColor = _kSuccess;
        break;
      case 'near_owner':
        statusText = '🛵 السائق في الطريق إليك';
        statusColor = _kPrimary;
        break;
      case 'picked_up':
        statusText = '📦 تم الاستلام منك';
        statusColor = _kPrimary;
        break;
      case 'in_transit':
        statusText = '🚚 في الطريق للزبون';
        statusColor = _kPrimary;
        break;
      case 'near_customer':
        statusText = '🛵 السائق قرب الزبون';
        statusColor = _kPrimary;
        break;
      case 'delivered':
        statusText = '✅ تم التوصيل بنجاح';
        statusColor = _kSuccess;
        break;
      default:
        statusText = status;
        statusColor = _kTextSecondary;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _neuBox(radius: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'حالة التوصيل:',
              style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: _kTextSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (driverName.isNotEmpty)
                  Text(driverName, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextSecondary)),
                Row(
                  children: [
                    Text(statusText, style: TextStyle(fontFamily: 'Amiri', fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                  ],
                ),
              ],
            ),
            if (hasCounter) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('💰 السائق اقترح ${counterOffer['proposedPrice']} DA بدلاً من ${delivery['deliveryPrice']} DA',
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 14, color: _kTextPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _handleCounter(context, 'reject'),
                    icon: const Icon(Icons.close, color: _kDanger, size: 18),
                    label: const Text('رفض', style: TextStyle(fontFamily: 'Amiri', color: _kDanger)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _handleCounter(context, 'accept'),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('قبول', style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: _kSuccess),
                  ),
                ],
              ),
            ],
            if (isPendingDriver) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _processing ? null : () => _cancelDriver(context),
                    icon: const Icon(Icons.cancel_outlined, color: _kDanger, size: 18),
                    label: const Text('إلغاء السائق', style: TextStyle(fontFamily: 'Amiri', color: _kDanger, fontSize: 12)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _processing ? null : () => _changeDriver(context),
                    icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                    label: const Text('تغيير السائق', style: TextStyle(fontFamily: 'Amiri', color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleCounter(BuildContext context, String action) async {
    setState(() => _processing = true);
    try {
      final deliveryId = widget.data['_delivery']['_id'];
      final Map<String, dynamic> res = await ApiClient.put('/api/project-deliveries/$deliveryId/owner-price-response', {'action': action});
      if (mounted) {
        setState(() => widget.data['_delivery'] = res);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept' ? '✅ تم قبول السعر الجديد' : '❌ تم رفض عرض السعر'),
          backgroundColor: action == 'accept' ? _kSuccess : _kDanger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _kDanger));
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _changeDriver(BuildContext context) async {
    final driverDoc = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _DriverSelectionPage(storeId: widget.storeId)),
    );
    if (driverDoc == null) return;
    if (!mounted) return;
    final newDriverId = driverDoc['id'] as String;
    final newDriverName = driverDoc['name'] as String;

    setState(() => _processing = true);
    try {
      final deliveryId = widget.data['_delivery']['_id'];
      final updated = await ApiClient.put('/api/project-deliveries/$deliveryId', {
        'driverId': newDriverId,
        'driverName': newDriverName,
        'status': 'pending',
      });
      widget.data['_delivery'] = updated;

      // إشعار للسائق الجديد
      String driverUserId = '';
      try {
        final driverData = await ApiClient.get('/api/drivers/$newDriverId');
        driverUserId = (driverData['userId'] as String?) ?? (driverData['uid'] as String?) ?? '';
      } catch (_) {}
      if (driverUserId.isNotEmpty) {
        FCMHelper.sendToUser(
          userId: driverUserId,
          title: '📦 توصيلية مشروع جديد',
          body: 'من ${widget.storeName} | ${_fmt(widget.data['_delivery']['deliveryPrice'])} دج',
          data: {'deliveryId': deliveryId, 'type': 'project_delivery'},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم تغيير السائق', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: _kSuccess, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: _kDanger, behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _cancelDriver(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إلغاء السائق', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
        content: const Text('هل أنت متأكدة من إلغاء هذا السائق؟', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع', style: TextStyle(fontFamily: 'Amiri'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء السائق', style: TextStyle(fontFamily: 'Amiri', color: _kDanger))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      final deliveryId = widget.data['_delivery']['_id'];
      await ApiClient.put('/api/project-deliveries/$deliveryId', {
        'driverId': null,
        'driverName': null,
        'status': 'cancelled',
      });
      // تحديث المشروع ليعود pending
      await ApiClient.put('/api/projects/${widget.projectId}', {'status': 'pending'});

      if (mounted) {
        widget.data.remove('_delivery');
        widget.onReady();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم إلغاء السائق، يمكنك اختيار سائق جديد', style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: _kWarning, behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: _kDanger, behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _processing = false);
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap, {String label = ''}) =>
      GestureDetector(
        onTap: _processing ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: _processing
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(label, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                      ),
                    Icon(icon, color: color, size: 20),
                  ],
                ),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _neuBox(radius: 12, padding: const EdgeInsets.all(14)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Amiri',
                color: _kTextPrimary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$label:",
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: _kTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CreateDeliveryPage extends StatefulWidget {
  const _CreateDeliveryPage();
  @override
  State<_CreateDeliveryPage> createState() => _CreateDeliveryPageState();
}

class _CreateDeliveryPageState extends State<_CreateDeliveryPage> {
  final _nameCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  final _productPriceCtrl = TextEditingController();
  final _deliveryPriceCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  XFile? _pickedImage;
  Map<String, dynamic>? _pickupLocation;
  Map<String, dynamic>? _deliveryLocation;
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _productCtrl.dispose();
    _productPriceCtrl.dispose();
    _deliveryPriceCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('توصيلية جديدة', style: TextStyle(fontFamily: 'Amiri', fontSize: 16, color: _kTextPrimary)),
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الزبون *', labelStyle: TextStyle(fontFamily: 'Amiri'), border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Amiri')),
          const SizedBox(height: 12),
          TextField(controller: _productCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج *', labelStyle: TextStyle(fontFamily: 'Amiri'), border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Amiri')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (img != null) setState(() => _pickedImage = img);
                  },
                  icon: Icon(_pickedImage != null ? Icons.check : Icons.image, size: 18),
                  label: Text(_pickedImage != null ? 'تم اختيار الصورة' : 'صورة المنتج *', style: const TextStyle(fontFamily: 'Amiri', fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: _pickedImage != null ? _kSuccess : _kTextSecondary, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              if (_pickedImage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _pickedImage = null),
                    child: const Icon(Icons.close, color: _kDanger, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _productPriceCtrl, decoration: const InputDecoration(labelText: 'سعر المنتج (دج) *', labelStyle: TextStyle(fontFamily: 'Amiri'), border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Amiri'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: _deliveryPriceCtrl, decoration: const InputDecoration(labelText: 'سعر التوصيل (دج) *', labelStyle: TextStyle(fontFamily: 'Amiri'), border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Amiri'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final loc = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
              if (loc != null) setState(() => _pickupLocation = loc);
            },
            icon: Icon(_pickupLocation != null ? Icons.check_circle : Icons.location_on, size: 18, color: _pickupLocation != null ? _kSuccess : _kTextSecondary),
            label: Text(
              _pickupLocation != null ? 'موقع الاستلام: ${_pickupLocation!['address'] ?? ''}' : 'موقع الاستلام *',
              style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: _pickupLocation != null ? _kSuccess : _kTextSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_pickupLocation != null)
            Text('${_pickupLocation!['lat']}, ${_pickupLocation!['lng']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final loc = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
              if (loc != null) setState(() => _deliveryLocation = loc);
            },
            icon: Icon(_deliveryLocation != null ? Icons.check_circle : Icons.location_on, size: 18, color: _deliveryLocation != null ? _kSuccess : _kTextSecondary),
            label: Text(
              _deliveryLocation != null ? 'موقع التوصيل: ${_deliveryLocation!['address'] ?? ''}' : 'موقع التوصيل *',
              style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: _deliveryLocation != null ? _kSuccess : _kTextSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_deliveryLocation != null)
            Text('${_deliveryLocation!['lat']}, ${_deliveryLocation!['lng']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(controller: _extraCtrl, decoration: const InputDecoration(labelText: 'معلومات إضافية (اختياري)', labelStyle: TextStyle(fontFamily: 'Amiri'), border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Amiri'), maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : () async {
                final missing = <String>[];
                if (_nameCtrl.text.trim().isEmpty) missing.add('اسم الزبون');
                if (_productCtrl.text.trim().isEmpty) missing.add('اسم المنتج');
                if (_pickedImage == null) missing.add('صورة المنتج');
                if (_productPriceCtrl.text.trim().isEmpty) missing.add('سعر المنتج');
                if (_deliveryPriceCtrl.text.trim().isEmpty) missing.add('سعر التوصيل');
                if (_pickupLocation == null) missing.add('موقع الاستلام');
                if (_deliveryLocation == null) missing.add('موقع التوصيل');

                if (missing.isNotEmpty) {
                  await showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('حقول ناقصة', style: TextStyle(fontFamily: 'Amiri')),
                      content: Text('الرجاء تعبئة الحقول التالية:\n${missing.map((m) => '• $m').join('\n')}', style: const TextStyle(fontFamily: 'Amiri')),
                      actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('حسناً', style: TextStyle(fontFamily: 'Amiri')))],
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'name': _nameCtrl.text.trim(),
                  'product': _productCtrl.text.trim(),
                  'productPrice': double.tryParse(_productPriceCtrl.text.trim()) ?? 0,
                  'deliveryPrice': double.tryParse(_deliveryPriceCtrl.text.trim()) ?? 0,
                  'extra': _extraCtrl.text.trim(),
                  'pickupLat': _pickupLocation!['lat'],
                  'pickupLng': _pickupLocation!['lng'],
                  'pickupAddress': _pickupLocation!['address'] ?? '',
                  'deliveryLat': _deliveryLocation!['lat'],
                  'deliveryLng': _deliveryLocation!['lng'],
                  'deliveryAddress': _deliveryLocation!['address'] ?? '',
                  'imagePath': _pickedImage!.path,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(_sending ? 'جاري الإرسال...' : 'تأكيد', style: const TextStyle(fontFamily: 'Amiri', fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSelectionSheet extends StatefulWidget {
  final String storeId;
  const _DriverSelectionSheet({required this.storeId});

  @override
  State<_DriverSelectionSheet> createState() => _DriverSelectionSheetState();
}

class _DriverSelectionSheetState extends State<_DriverSelectionSheet> {
  String? _selectedDriverId;
  String? _selectedDriverName;
  String _searchQuery = '';
  String _vehicleFilter = 'دراجة نارية';
  String _cityFilter = '';
  List<Map<String, dynamic>> _drivers = [];
  bool _loadingDrivers = true;
  List<String> _cities = [];
  final _cityCtrl = TextEditingController();
  final _cityFocus = FocusNode();


  final _vehicleTypes = ['دراجة نارية', 'سيارة', 'هاربين', 'فورغو'];

  String _vehicleToApi(String arabic) {
    switch (arabic) {
      case 'دراجة نارية': return 'motorcycle';
      case 'سيارة': return 'car';
      case 'هاربين': return 'harbin';
      case 'فورغو': return 'fourgon';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerCity();
    _loadCities();
    _loadDrivers();
  }

  Future<void> _loadOwnerCity() async {
    try {
      final store = await ApiClient.get('/api/stores/${widget.storeId}');
      if (store is Map) {
        final ville = store['ville'] as String? ?? '';
        if (ville.isNotEmpty && _cityFilter.isEmpty) {
          _cityFilter = ville;
          _cityCtrl.text = ville;
          _loadDrivers();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCities() async {
    try {
      final data = await ApiClient.getList('/api/drivers/cities');
      if (data.isNotEmpty) {
        _cities = data.map((c) => c.toString()).where((n) => n.isNotEmpty).toList();
        if (mounted) setState(() {});
        return;
      }
    } catch (_) {}
    // Fallback: extract cities from drivers if API endpoint doesn't exist
    _extractCitiesFromDrivers();
  }

  Future<void> _extractCitiesFromDrivers() async {
    try {
      final vehicleParam = _vehicleFilter.isNotEmpty ? '&vehicleType=${_vehicleToApi(_vehicleFilter)}' : '';
      final data = await ApiClient.getList('/api/drivers?isOnline=true&isActive=true$vehicleParam');
      final cities = data.map<String>((d) {
        if (d is Map) return (d['cityName'] as String? ?? '').toString();
        return '';
      }).where((n) => n.isNotEmpty).toSet().toList()..sort();
      if (cities.isNotEmpty && mounted) {
        setState(() => _cities = cities);
      }
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final vehicleParam = _vehicleFilter.isNotEmpty ? '&vehicleType=${_vehicleToApi(_vehicleFilter)}' : '';
      final params = 'isOnline=true&isActive=true$vehicleParam${_cityFilter.isNotEmpty ? '&cityName=$_cityFilter' : ''}';
      final data = await ApiClient.getList('/api/drivers?$params');
      if (mounted) {
        setState(() {
          _drivers = data.cast<Map<String, dynamic>>();
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          // filters row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // vehicle type filter
                Expanded(
                  child: _buildDropdown(
                    value: _vehicleFilter,
                    items: _vehicleTypes,
                    onChanged: (v) {
                      setState(() {
                        _vehicleFilter = v;
                        _loadingDrivers = true;
                      });
                      _loadDrivers();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // city filter (recherche)
                Expanded(
                  child: _buildCitySearchField(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث عن سائق...',
                hintStyle: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary),
                prefixIcon: const Icon(CupertinoIcons.search, color: _kPrimary),
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // count badge
          if (!_loadingDrivers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_drivers.length} سائق متاح',
                    style: const TextStyle(fontFamily: 'Amiri', fontSize: 12, color: _kSuccess),
                  ),
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.person_2_fill, size: 14, color: _kSuccess),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingDrivers
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : _buildDriverList(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedDriverId == null
                    ? null
                    : () => Navigator.pop(context, {'id': _selectedDriverId, 'name': _selectedDriverName}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: _kTextSecondary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  "اختيار السائق",
                  style: TextStyle(fontFamily: 'Amiri', fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySearchField() {
    final suggestions = _cities.where((c) =>
        c.toLowerCase().contains(_cityCtrl.text.toLowerCase())).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _cityCtrl,
            focusNode: _cityFocus,
            decoration: InputDecoration(
              hintText: 'المدينة',
              hintStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextSecondary),
              border: InputBorder.none,
              suffixIcon: _cityFilter.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _cityCtrl.clear();
                        setState(() { _cityFilter = ''; _loadingDrivers = true; });
                        _loadDrivers();
                      },
                      child: const Icon(CupertinoIcons.clear_circled, size: 18),
                    )
                  : null,
            ),
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.isNotEmpty && _cities.any((c) => c == v)) {
                setState(() { _cityFilter = v; _loadingDrivers = true; });
                _loadDrivers();
                _cityFocus.unfocus();
              }
            },
          ),
        ),
        if (_cityCtrl.text.isNotEmpty && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: suggestions.take(10).map((c) => GestureDetector(
                onTap: () {
                  _cityCtrl.text = c;
                  setState(() { _cityFilter = c; _loadingDrivers = true; });
                  _loadDrivers();
                  _cityFocus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(c, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary)),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          onChanged: (v) { if (v != null) onChanged(v); },
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Amiri')))).toList(),
        ),
      ),
    );
  }

  Widget _buildDriverList() {
    var docs = _drivers.where((d) {
      final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim().toLowerCase();
      final city = (d['cityName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || name.contains(q) || city.contains(q);
    }).toList();

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person, size: 50, color: _kTextSecondary.withOpacity(0.35)),
            const SizedBox(height: 10),
            const Text("لا يوجد سائقون متاحون", style: TextStyle(fontFamily: 'Amiri', color: _kTextSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i];
        final driverId = d['uid'] ?? d['_id'] ?? '';
        final fName = d['firstName'] ?? '';
        final lName = d['lastName'] ?? '';
        final fullName = '$fName $lName'.trim();
        final city = d['cityName'] ?? '';
        final vehicle = d['vehicleType'] ?? '';
        final isSelected = _selectedDriverId == driverId;

        return GestureDetector(
          onTap: () => setState(() { _selectedDriverId = driverId; _selectedDriverName = fullName; }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? const LinearGradient(colors: [_kPrimaryLight, _kPrimary], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
              boxShadow: isSelected ? [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : _neuShadow(blur: 6, offset: 3),
              border: isSelected ? null : Border.all(color: _kPrimary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    color: isSelected ? Colors.white : _kTextSecondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fullName, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : _kTextPrimary)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (vehicle.isNotEmpty)
                            Text(vehicle, style: TextStyle(fontFamily: 'Amiri', fontSize: 11, color: isSelected ? Colors.white70 : _kTextSecondary)),
                          if (vehicle.isNotEmpty && city.isNotEmpty) const SizedBox(width: 8),
                          if (city.isNotEmpty)
                            Text(city, style: TextStyle(fontFamily: 'Amiri', fontSize: 11, color: isSelected ? Colors.white70 : _kTextSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white.withOpacity(0.2) : _kBg),
                  child: Icon(CupertinoIcons.person_fill, color: isSelected ? Colors.white : _kPrimary, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _DriverSelectionPage — صفحة اختيار السائق (full page بدل sheet)
// ══════════════════════════════════════════════════════════════════════════════
class _DriverSelectionPage extends StatefulWidget {
  final String storeId;
  const _DriverSelectionPage({required this.storeId});

  @override
  State<_DriverSelectionPage> createState() => _DriverSelectionPageState();
}

class _DriverSelectionPageState extends State<_DriverSelectionPage> {
  String? _selectedDriverId;
  String? _selectedDriverName;
  String _searchQuery = '';
  String _vehicleFilter = 'دراجة نارية';
  String _cityFilter = '';
  List<Map<String, dynamic>> _drivers = [];
  bool _loadingDrivers = true;
  List<String> _cities = [];
  final _cityCtrl = TextEditingController();
  final _cityFocus = FocusNode();

  final _vehicleTypes = ['دراجة نارية', 'سيارة', 'هاربين', 'فورغو'];

  String _vehicleToApi(String arabic) {
    switch (arabic) {
      case 'دراجة نارية': return 'motorcycle';
      case 'سيارة': return 'car';
      case 'هاربين': return 'harbin';
      case 'فورغو': return 'fourgon';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerCity();
    _loadCities();
    _loadDrivers();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerCity() async {
    try {
      final store = await ApiClient.get('/api/stores/${widget.storeId}');
      if (store is Map) {
        final ville = store['ville'] as String? ?? '';
        if (ville.isNotEmpty && _cityFilter.isEmpty) {
          _cityFilter = ville;
          _cityCtrl.text = ville;
          _loadDrivers();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCities() async {
    try {
      final data = await ApiClient.getList('/api/drivers/cities');
      if (data.isNotEmpty) {
        _cities = data.map((c) => c.toString()).where((n) => n.isNotEmpty).toList();
        if (mounted) setState(() {});
        return;
      }
    } catch (_) {}
    _extractCitiesFromDrivers();
  }

  Future<void> _extractCitiesFromDrivers() async {
    try {
      final vehicleParam = _vehicleFilter.isNotEmpty ? '&vehicleType=${_vehicleToApi(_vehicleFilter)}' : '';
      final data = await ApiClient.getList('/api/drivers?isOnline=true&isActive=true$vehicleParam');
      final cities = data.map<String>((d) {
        if (d is Map) return (d['cityName'] as String? ?? '').toString();
        return '';
      }).where((n) => n.isNotEmpty).toSet().toList()..sort();
      if (cities.isNotEmpty && mounted) {
        setState(() => _cities = cities);
      }
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final vehicleParam = _vehicleFilter.isNotEmpty ? '&vehicleType=${_vehicleToApi(_vehicleFilter)}' : '';
      final params = 'isOnline=true&isActive=true$vehicleParam${_cityFilter.isNotEmpty ? '&cityName=$_cityFilter' : ''}';
      final data = await ApiClient.getList('/api/drivers?$params');
      if (mounted) {
        setState(() {
          _drivers = data.cast<Map<String, dynamic>>();
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('اختيار سائق', style: TextStyle(fontFamily: 'Amiri', fontSize: 16, color: _kTextPrimary)),
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildDropdown(
                  value: _vehicleFilter,
                  items: _vehicleTypes,
                  onChanged: (v) {
                    setState(() { _vehicleFilter = v; _loadingDrivers = true; });
                    _loadDrivers();
                  },
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildCitySearchField()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث عن سائق...',
                hintStyle: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary),
                prefixIcon: const Icon(CupertinoIcons.search, color: _kPrimary),
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!_loadingDrivers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${_drivers.length} سائق متاح', style: const TextStyle(fontFamily: 'Amiri', fontSize: 12, color: _kSuccess)),
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.person_2_fill, size: 14, color: _kSuccess),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingDrivers
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : _buildDriverList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySearchField() {
    final suggestions = _cities.where((c) =>
        c.toLowerCase().contains(_cityCtrl.text.toLowerCase())).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _cityCtrl,
            focusNode: _cityFocus,
            decoration: InputDecoration(
              hintText: 'المدينة',
              hintStyle: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextSecondary),
              border: InputBorder.none,
              suffixIcon: _cityFilter.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _cityCtrl.clear();
                        setState(() { _cityFilter = ''; _loadingDrivers = true; });
                        _loadDrivers();
                      },
                      child: const Icon(CupertinoIcons.clear_circled, size: 18),
                    )
                  : null,
            ),
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.isNotEmpty && _cities.any((c) => c == v)) {
                setState(() { _cityFilter = v; _loadingDrivers = true; });
                _loadDrivers();
                _cityFocus.unfocus();
              }
            },
          ),
        ),
        if (_cityCtrl.text.isNotEmpty && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: suggestions.take(10).map((c) => GestureDetector(
                onTap: () {
                  _cityCtrl.text = c;
                  setState(() { _cityFilter = c; _loadingDrivers = true; });
                  _loadDrivers();
                  _cityFocus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(c, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary)),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required ValueChanged<String> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          onChanged: (v) { if (v != null) onChanged(v); },
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _kTextPrimary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontFamily: 'Amiri')))).toList(),
        ),
      ),
    );
  }

  Widget _buildDriverList() {
    final filtered = _drivers.where((d) {
      if (_searchQuery.isEmpty) return true;
      final fName = (d['firstName'] as String? ?? '').toLowerCase();
      final lName = (d['lastName'] as String? ?? '').toLowerCase();
      final fullName = '$fName $lName'.trim();
      final city = (d['cityName'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return fullName.contains(q) || city.contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.person_2_fill, size: 50, color: _kTextSecondary.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text('لا يوجد سائقين متاحين', style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: _kTextSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final d = filtered[i];
        final driverUid = d['uid'] as String? ?? d['_id'] as String? ?? d['id'] as String? ?? '';
        final isSelected = _selectedDriverId == driverUid;
        final fName = d['firstName'] as String? ?? '';
        final lName = d['lastName'] as String? ?? '';
        final fullName = '$fName $lName'.trim();
        final vehicle = d['vehicleType'] as String? ?? '';
        final city = d['cityName'] as String? ?? '';

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDriverId = driverUid;
              _selectedDriverName = fullName.isNotEmpty ? fullName : (d['name'] as String? ?? '');
            });
            Navigator.pop(context, {'id': driverUid, 'name': _selectedDriverName});
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? _kPrimary : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? _kPrimary : _kPrimary.withOpacity(0.15)),
              boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fullName, style: TextStyle(fontFamily: 'Amiri', fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : _kTextPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (vehicle.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.2) : _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(vehicle, style: TextStyle(fontFamily: 'Amiri', fontSize: 11, color: isSelected ? Colors.white : _kPrimary)),
                            ),
                          if (vehicle.isNotEmpty && city.isNotEmpty) const SizedBox(width: 8),
                          if (city.isNotEmpty)
                            Text(city, style: TextStyle(fontFamily: 'Amiri', fontSize: 11, color: isSelected ? Colors.white70 : _kTextSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white.withOpacity(0.2) : _kBg),
                  child: Icon(CupertinoIcons.person_fill, color: isSelected ? Colors.white : _kPrimary, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _LocationAndPriceSheet — تحديد موقع الاستلام + الأسعار في شيت واحد
// ══════════════════════════════════════════════════════════════════════════════
class _LocationAndPriceSheet extends StatefulWidget {
  final double initialProductPrice;
  const _LocationAndPriceSheet({this.initialProductPrice = 0});
  @override
  State<_LocationAndPriceSheet> createState() => _LocationAndPriceSheetState();
}

class _LocationAndPriceSheetState extends State<_LocationAndPriceSheet> {
  late final TextEditingController _productCtrl;
  final _deliveryCtrl = TextEditingController();
  Map<String, dynamic>? _location;

  @override
  void initState() {
    super.initState();
    _productCtrl = TextEditingController(
      text: widget.initialProductPrice > 0
          ? widget.initialProductPrice.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _deliveryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 25, right: 25,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 16),
          const Center(child: Text("قبول الطلب",
              style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 18, color: _kTextPrimary))),
          const SizedBox(height: 24),
          // اختيار الموقع
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final loc = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                );
                if (loc != null) setState(() => _location = loc);
              },
              icon: Icon(
                _location != null ? Icons.check_circle : Icons.location_on,
                size: 20,
                color: _location != null ? _kSuccess : _kPrimary,
              ),
              label: Text(
                _location != null ? 'موقعك: ${_location!['address'] ?? ''}' : 'حدد موقعك من الخريطة',
                style: TextStyle(fontFamily: 'Amiri', fontSize: 13, color: _location != null ? _kSuccess : _kTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _location != null ? _kSuccess.withOpacity(0.4) : _kPrimary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_location != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${_location!['lat']}, ${_location!['lng']}',
                  style: const TextStyle(fontSize: 10, color: _kTextSecondary)),
            ),
          const SizedBox(height: 16),
          // سعر قبض (من الزبون)
          _priceField(_productCtrl, 'سعر القبض', Icons.monetization_on_outlined),
          const SizedBox(height: 12),
          // سعر التوصيل
          _priceField(_deliveryCtrl, 'سعر التوصيل', Icons.local_shipping_outlined),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("إرسال", style: TextStyle(fontFamily: 'Amiri', fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField(TextEditingController ctrl, String label, IconData icon) =>
      Container(
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _neuShadow(blur: 6, offset: 3),
          border: Border.all(color: _kPrimary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('DA', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Amiri', fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: _kPrimary, size: 18),
            ),
          ],
        ),
      );

  void _submit() {
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد موقعك من الخريطة'), backgroundColor: _kDanger, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final product = double.tryParse(_productCtrl.text.trim());
    final delivery = double.tryParse(_deliveryCtrl.text.trim());
    if (product == null || delivery == null || product < 0 || delivery < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال أسعار صحيحة'), backgroundColor: _kDanger, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    Navigator.pop(context, {
      'lat': _location!['lat'],
      'lng': _location!['lng'],
      'address': _location!['address'] ?? '',
      'productPrice': product,
      'deliveryPrice': delivery,
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CustomerLocationSheet — عرض وتعديل موقع توصيل الزبون
// ══════════════════════════════════════════════════════════════════════════════
class _CustomerLocationSheet extends StatefulWidget {
  final String initialAddress;
  final double initialLat;
  final double initialLng;

  const _CustomerLocationSheet({
    required this.initialAddress,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_CustomerLocationSheet> createState() => _CustomerLocationSheetState();
}

class _CustomerLocationSheetState extends State<_CustomerLocationSheet> {
  late String _address;
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    _lat = widget.initialLat;
    _lng = widget.initialLng;
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _address = result['address'] as String? ?? '';
        _lat = (result['lat'] as num?)?.toDouble() ?? 0;
        _lng = (result['lng'] as num?)?.toDouble() ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInitial = (_lat != 0 && _lng != 0);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "موقع توصيل الزبون",
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _kTextPrimary,
                ),
              ),
              SizedBox(width: 8),
              Icon(CupertinoIcons.location_fill, color: _kDanger, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: _neuBox(radius: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.map_pin_ellipse,
                      size: 16,
                      color: _kPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _address.isNotEmpty ? _address : 'لا يوجد عنوان',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          color: _address.isNotEmpty
                              ? _kTextPrimary
                              : _kTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "العنوان:",
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (hasInitial) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        size: 16,
                        color: _kPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_lat, $_lng',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 12,
                          color: _kTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "الإحداثيات:",
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          color: _kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pickOnMap,
              icon: const Icon(CupertinoIcons.map, size: 18),
              label: const Text(
                "تعديل موقع التوصيل",
                style: TextStyle(fontFamily: 'Amiri', fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kWarning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'address': _address,
                'lat': _lat,
                'lng': _lng,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "استمرار",
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
