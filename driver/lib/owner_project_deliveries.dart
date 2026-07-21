import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color _kBg = Color(0xFFE8E6F0);
const Color _kPrimary = Color(0xFF5B0094);
const Color _kPrimaryLight = Color(0xFF9B59C8);
const Color _kDanger = Color(0xFFE53E6A);
const Color _kSuccess = Color(0xFF27AE7A);
const Color _kWarning = Color(0xFFF39C12);
const Color _kTextPrimary = Color(0xFF2D2540);
const Color _kTextSecondary = Color(0xFF7B6E99);

List<BoxShadow> _neuShadow({double blur = 10, double offset = 4}) => [
  BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: blur, offset: Offset(offset, offset)),
  BoxShadow(color: Colors.white, blurRadius: blur, offset: Offset(-offset, -offset)),
];

class OwnerProjectDeliveriesPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String ownerId;
  const OwnerProjectDeliveriesPage({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.ownerId,
  });

  @override
  State<OwnerProjectDeliveriesPage> createState() => _OwnerProjectDeliveriesPageState();
}

class _OwnerProjectDeliveriesPageState extends State<OwnerProjectDeliveriesPage> {
  String _filter = 'active';
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
    SocketClient().join('user_${widget.ownerId}');
    SocketClient().on('project_delivery:created', (_) => _loadDeliveries());
    SocketClient().on('project_delivery:updated', (_) => _loadDeliveries());
    SocketClient().on('delivery:created', (_) => _loadDeliveries());
    SocketClient().on('delivery:updated', (_) => _loadDeliveries());
    SocketClient().on('order:created', _onOwnerOrderCreated);
  }

  void _onOwnerOrderCreated(_) => _loadDeliveries();

  @override
  void dispose() {
    SocketClient().off('project_delivery:created');
    SocketClient().off('project_delivery:updated');
    SocketClient().off('delivery:created');
    SocketClient().off('delivery:updated');
    SocketClient().off('order:created', _onOwnerOrderCreated);
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    try {
      final data = await ApiClient.getList('/api/project-deliveries?storeOwnerId=${widget.ownerId}');
      if (mounted) {
        setState(() {
          _deliveries = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text("توصيل المشاريع",
            style: TextStyle(fontFamily: 'Amiri', color: _kTextPrimary, fontSize: 16)),
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kPrimary),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(CupertinoIcons.slider_horizontal_3, color: _kPrimary),
            onSelected: (v) {
              setState(() => _filter = v);
              _loadDeliveries();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'active', child: Text("النشطة", style: TextStyle(fontFamily: 'Amiri'))),
              const PopupMenuItem(value: 'delivered', child: Text("المكتملة", style: TextStyle(fontFamily: 'Amiri'))),
              const PopupMenuItem(value: 'all', child: Text("الكل", style: TextStyle(fontFamily: 'Amiri'))),
            ],
          ),
        ],
      ),
     body: RefreshIndicator(
  onRefresh: _loadDeliveries, // ✅ السحب للأسفل يحدث القائمة
  color: _kPrimary,
  child: _loading
      ? const Center(child: CircularProgressIndicator(color: _kPrimary))
      : _buildList(),
),
    );
  }

  Widget _buildList() {
    var docs = List<Map<String, dynamic>>.from(_deliveries);

    if (_filter == 'active') {
      docs = docs.where((d) {
        final s = d['status'] ?? '';
        return s != 'delivered' && s != 'cancelled';
      }).toList();
    } else if (_filter == 'delivered') {
      docs = docs.where((d) {
        final s = d['status'] ?? '';
        return s == 'delivered';
      }).toList();
    }

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.shopping_cart, size: 60, color: _kTextSecondary.withOpacity(0.35)),
            const SizedBox(height: 12),
            const Text("لا توجد توصيليات",
                style: TextStyle(fontFamily: 'Amiri', color: _kTextSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final d = docs[i];
        return _ProjectDeliveryCard(
          deliveryId: d['_id'] ?? '',
          data: d,
          ownerId: widget.ownerId,
          onRefresh: _loadDeliveries, // ✅ نمرر دالة التحديث للكارد
        );
      },
    );
  }
}

class _ProjectDeliveryCard extends StatelessWidget {
  final String deliveryId;
  final Map<String, dynamic> data;
  final String ownerId;
  final VoidCallback onRefresh;

  const _ProjectDeliveryCard({
    required this.deliveryId,
    required this.data,
    required this.ownerId,
    required this.onRefresh,
  });

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'بانتظار السائق';
      case 'accepted': return 'قيد التوصيل';
      case 'onway_to_store': return 'في الطريق للمتجر';
      case 'picked_up': return 'تم الاستلام من المتجر';
      case 'purchased': return 'تم الشراء';
      case 'onway': return 'في الطريق للزبون';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return _kWarning;
      case 'accepted': case 'purchased': return _kPrimary;
      case 'onway_to_store': return _kWarning;
      case 'picked_up': return _kSuccess;
      case 'onway': return _kPrimary;
      case 'delivered': return _kSuccess;
      case 'cancelled': return _kDanger;
      default: return _kTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = data['customerName'] ?? 'زبون';
    final driverName = data['driverName'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final status = data['status'] ?? 'pending';
    final deliveryPrice = (data['deliveryPrice'] ?? 0).toDouble();
    final productPrice = (data['productPrice'] ?? 0).toDouble();
    final totalPrice = (data['totalPrice'] ?? deliveryPrice + productPrice).toDouble();
    final hasCounter = data['counterOffer'] != null;
    final counterStatus = hasCounter ? data['counterOffer']['status'] ?? '' : '';
    final counterPrice = hasCounter ? data['counterOffer']['proposedPrice'] ?? 0 : 0;
    final hasRejection = data['rejectionReason'] is String && (data['rejectionReason'] as String).isNotEmpty;
    final bool isPendingWithNoDriver = status == 'pending' && driverName.isEmpty && !hasRejection;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: _kPrimary.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── شريط الحالة العلوي ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasRejection
                    ? _kDanger.withOpacity(0.12)
                    : _statusColor(status).withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (hasRejection ? _kDanger : _statusColor(status)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasRejection ? 'رفض السائق' : _statusText(status),
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasRejection ? _kDanger : _statusColor(status),
                      ),
                    ),
                  ),
                  if (hasCounter && counterStatus == 'pending')
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kWarning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.money_dollar,
                              color: _kWarning, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            '${counterPrice.toInt()} DA',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 10,
                              color: _kWarning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                      color: _kTextPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // ── المحتوى ──
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // وصف مختصر
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 12,
                          color: _kTextSecondary,
                        ),
                      ),
                    ),
                  // السائق والمبلغ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (driverName.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                color: _kTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(CupertinoIcons.person_fill,
                                size: 14, color: _kTextSecondary),
                          ],
                        ),
                      if (driverName.isNotEmpty) const SizedBox(width: 12),
                      // السعر الأصلي أو المقبول
                      if (!hasCounter || counterStatus == 'accepted')
                        Text(
                          '${totalPrice.toInt()} DA',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            color: _kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      // السعر المقترح (قيد الانتظار)
                      if (hasCounter && counterStatus == 'pending')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${counterPrice.toInt()} DA',
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'بدلاً من ${totalPrice.toInt()} DA',
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                color: _kTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      // السعر المرفوض (نبقي السعر القديم)
                      if (hasCounter && counterStatus == 'rejected')
                        Text(
                          '${totalPrice.toInt()} DA',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            color: _kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  // رسالة عرض السعر
                  if (hasCounter && counterStatus == 'pending') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kWarning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kWarning.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.money_dollar,
                              color: _kWarning, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'السائق اقترح سعر جديد',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: _kWarning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasCounter && counterStatus == 'accepted') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kSuccess.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kSuccess.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.checkmark_seal_fill,
                              color: _kSuccess, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'تم قبول عرض السعر',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: _kSuccess,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasCounter && counterStatus == 'rejected') ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kDanger.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kDanger.withOpacity(0.15)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.xmark_circle_fill,
                              color: _kDanger, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'تم رفض عرض السعر',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: _kDanger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // رسالة الرفض
                  if (hasRejection) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kDanger.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kDanger.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                                  color: _kDanger, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                data['rejectionReason'] as String? ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 11,
                                  color: _kDanger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'اعثر على سائق آخر',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: _kDanger,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // رسالة انتظار
                  if (isPendingWithNoDriver) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kWarning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kWarning.withOpacity(0.15)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.clock_fill,
                              color: _kWarning, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'بانتظار سائق...',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: _kWarning,
                            ),
                          ),
                        ],
                      ),
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

 void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryDetailSheet(
        deliveryId: deliveryId,
        data: data,
        ownerId: ownerId,
      ),
    ).then((_) {
      // ✅ هادا هو السطر السحري اللي يخلي القائمة تتحدث آلياً
      onRefresh(); 
    });
  }
}

class _DeliveryDetailSheet extends StatefulWidget {
  final String deliveryId;
  final Map<String, dynamic> data;
  final String ownerId;
  const _DeliveryDetailSheet({
    required this.deliveryId,
    required this.data,
    required this.ownerId,
  });

  @override
  State<_DeliveryDetailSheet> createState() => _DeliveryDetailSheetState();
}

class _DeliveryDetailSheetState extends State<_DeliveryDetailSheet> {
  bool _loading = false;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  void _showReportSheet(String type, String targetName, String targetId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSheet(
        type: type,
        targetName: targetName,
        targetId: targetId,
        ownerId: widget.ownerId,
        deliveryId: widget.deliveryId,
      ),
    );
  }

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

  String _statusText(String s) {
    switch (s) {
      case 'pending': return 'بانتظار السائق';
      case 'accepted': return 'قيد التوصيل';
      case 'onway_to_store': return 'في الطريق للمتجر';
      case 'picked_up': return 'تم الاستلام من المتجر';
      case 'purchased': return 'تم الشراء';
      case 'onway': return 'في الطريق للزبون';
      case 'delivered': return 'تم التوصيل';
      case 'cancelled': return 'ملغي';
      default: return s;
    }
  }

  Future<void> _handleCounter(bool accept) async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> res = await ApiClient.put(
        '/api/project-deliveries/${widget.deliveryId}/owner-price-response',
        {'action': accept ? 'accept' : 'reject'},
      );
      if (mounted) {
        setState(() => _data = res);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'تم قبول السعر المقترح ✅' : 'تم رفض السعر المقترح ❌'),
            backgroundColor: accept ? _kSuccess : _kDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحديث: $e'), backgroundColor: _kDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final status = d['status'] ?? 'pending';
    final customerName = d['customerName'] ?? '';
    final customerPhone = d['customerPhone'] ?? '';
    final description = d['description'] ?? '';
    final imageUrl = d['imageUrl'] ?? '';
    final driverName = d['driverName'] ?? '';
    final deliveryPrice = d['deliveryPrice'] ?? 0;
    final productPrice = d['productPrice'] ?? 0;
    final totalPrice = d['totalPrice'] ?? 0;
    final counterOffer = d['counterOffer'];
    final hasPendingCounter = counterOffer != null && counterOffer['status'] == 'pending';
    final hasRejection = d['rejectionReason'] is String && (d['rejectionReason'] as String).isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
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
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 16),
            const Text("تفاصيل التوصيلية",
                style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 18, color: _kTextPrimary)),
            const SizedBox(height: 20),
            if (imageUrl.isNotEmpty) Container(
              width: double.infinity, height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
              ),
            ),
            if (imageUrl.isNotEmpty) const SizedBox(height: 16),
            _infoRow(CupertinoIcons.person_fill, 'الزبون', customerName),
            _infoRow(CupertinoIcons.phone_fill, 'الهاتف', customerPhone),
            _infoRow(CupertinoIcons.doc_text_fill, 'الوصف', description),
            _infoRow(CupertinoIcons.person, 'السائق', driverName.isNotEmpty ? driverName : '---'),
            _infoRow(Icons.local_shipping_outlined, 'سعر التوصيل', '${(deliveryPrice as num).toInt()} DA'),
            _infoRow(Icons.monetization_on_outlined, 'سعر المنتج', '${(productPrice as num).toInt()} DA'),
            _infoRow(CupertinoIcons.money_dollar, 'المجموع', '${(totalPrice as num).toInt()} DA'),
            _infoRow(CupertinoIcons.clock_fill, 'التاريخ', _formatDate(d['createdAt'])),
            const SizedBox(height: 8),
            // حالة الرفض
            if (hasRejection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kDanger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kDanger.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                            color: _kDanger, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'السائق رفض التوصيلية',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.bold,
                            color: _kDanger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d['rejectionReason'] as String? ?? '',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        color: _kDanger,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اعثر على سائق آخر',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        color: _kDanger,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text("الحالة: ${_statusText(status)}",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _statusColor(status))),
              ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReportButton(
                    label: 'الإبلاغ عن الزبون',
                    icon: CupertinoIcons.flag_fill,
                    onTap: () => _showReportSheet('owner_report_customer', customerName, d['userId'] ?? ''),
                  ),
                ),
                if (driverName.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ReportButton(
                      label: 'الإبلاغ عن السائق',
                      icon: CupertinoIcons.flag_fill,
                      onTap: () => _showReportSheet('owner_report_driver', driverName, d['driverId'] ?? ''),
                    ),
                  ),
                ],
              ],
            ),

            if (hasPendingCounter) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kWarning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kWarning.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text("اقتراح سعر من السائق",
                        style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kWarning)),
                    const SizedBox(height: 8),
                    Text("${counterOffer!['proposedPrice']} DA",
                        style: TextStyle(fontFamily: 'Amiri', fontSize: 22, fontWeight: FontWeight.bold, color: _kPrimary)),
                    Text("بواسطة: ${counterOffer['driverName'] ?? ''}",
                        style: TextStyle(fontFamily: 'Amiri', color: _kTextSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loading ? null : () => _handleCounter(true),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text("قبول", style: TextStyle(fontFamily: 'Amiri')),
                          style: ElevatedButton.styleFrom(backgroundColor: _kSuccess, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _loading ? null : () => _handleCounter(false),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text("رفض", style: TextStyle(fontFamily: 'Amiri')),
                          style: ElevatedButton.styleFrom(backgroundColor: _kDanger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (counterOffer != null && counterOffer['status'] == 'accepted')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSuccess.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kSuccess.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.checkmark_seal_fill,
                        color: _kSuccess, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'تم قبول عرض السعر (${counterOffer['proposedPrice']} DA)',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        color: _kSuccess,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else if (counterOffer != null && counterOffer['status'] == 'rejected')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kDanger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kDanger.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.xmark_circle_fill,
                        color: _kDanger, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'تم رفض عرض السعر (${counterOffer['proposedPrice']} DA)',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        color: _kDanger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending': return _kWarning;
      case 'accepted': case 'purchased': return _kPrimary;
      case 'onway_to_store': return _kWarning;
      case 'picked_up': return _kSuccess;
      case 'onway': return _kPrimary;
      case 'delivered': return _kSuccess;
      case 'cancelled': return _kDanger;
      default: return _kTextSecondary;
    }
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: _neuShadow(blur: 5, offset: 2),
        border: Border.all(color: _kPrimary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kPrimary),
          const SizedBox(width: 6),
          Expanded(child: Text(value, textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'Amiri', color: _kTextPrimary, fontSize: 13))),
          const SizedBox(width: 6),
          Text("$label:", style: const TextStyle(fontFamily: 'Amiri', color: _kTextSecondary, fontSize: 11)),
        ],
      ),
    ),
  );
}

// ── زر الإبلاغ ──
class _ReportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ReportButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _kDanger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kDanger.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: _kDanger),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontFamily: 'Amiri', fontSize: 12, fontWeight: FontWeight.w600, color: _kDanger)),
          ],
        ),
      ),
    );
  }
}

// ── شاشة الإبلاغ ──
class _ReportSheet extends StatefulWidget {
  final String type;
  final String targetName;
  final String targetId;
  final String ownerId;
  final String deliveryId;
  const _ReportSheet({
    required this.type,
    required this.targetName,
    required this.targetId,
    required this.ownerId,
    required this.deliveryId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
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
    final ownerName = FirebaseAuth.instance.currentUser?.displayName ?? 'صاحب مشروع';
    try {
      final Map<String, dynamic> body = {
        'type': widget.type,
        'ownerId': widget.ownerId,
        'ownerName': ownerName,
        'orderId': widget.deliveryId,
        'reason': 'شكوى',
        'note': _noteCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      if (widget.type == 'owner_report_customer') {
        body['userId'] = widget.targetId;
        body['userName'] = widget.targetName;
      } else {
        body['driverId'] = widget.targetId;
        body['driverName'] = widget.targetName;
      }
      await ApiClient.post('/api/reports', body);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' تم إرسال البلاغ بنجاح للإدارة', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: _kSuccess,
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
          Row(
            children: [
              const Icon(CupertinoIcons.flag_fill, color: _kDanger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('الإبلاغ عن ${widget.targetName}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFamily: 'Amiri', fontSize: 16, fontWeight: FontWeight.bold, color: _kTextPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _kBg,
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
                color: _noteCtrl.text.trim().isEmpty ? Colors.grey.shade300 : _kDanger,
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
