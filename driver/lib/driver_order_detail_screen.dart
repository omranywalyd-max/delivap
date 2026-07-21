import 'dart:async';
import 'package:dashbord/services/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dashbord/services/api_client.dart';
import 'driver_route_map_screen.dart';
import 'driver_app.dart';
import 'fcm_helper.dart';

import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;

// ══════════════════════════════════════════════════════════════════════════════
//  DriverOrderDetailScreen
// ══════════════════════════════════════════════════════════════════════════════
class DriverOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doc;
  final List<Map<String, dynamic>> allOrderDocs;

  const DriverOrderDetailScreen({
    super.key,
    required this.doc,
    required this.allOrderDocs,
  });

  @override
  State<DriverOrderDetailScreen> createState() =>
      _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  static final Map<String, DateTime> _lastRingTimes = {};
  static const Duration _ringCooldown = Duration(seconds: 30);

  bool _loading = false;
  Map<String, dynamic>? _orderData;
  Timer? _refreshTimer;
  Timer? _cooldownTimer;

  bool get _isProjectDelivery =>
      widget.doc.containsKey('projectId');
  bool get _isTransport =>
      widget.doc.containsKey('transportType');
  bool get _isService =>
      widget.doc.containsKey('serviceType');

  String get _apiPrefix {
    if (_isProjectDelivery) return '/api/project-deliveries';
    if (_isTransport) return '/api/transport-orders';
    if (_isService) return '/api/service-orders';
    return '/api/orders';
  }

  late final void Function(dynamic) _onSocketEvent;

  @override
  void initState() {
    super.initState();
    _orderData = Map<String, dynamic>.from(widget.doc);
    _loadOrder();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrder());
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _onSocketEvent = (data) {
      if (mounted && data['_id'] == widget.doc['_id']) _loadOrder();
    };
    if (_isProjectDelivery) {
      SocketClient().on('project_delivery:updated', _onSocketEvent);
    } else if (_isTransport) {
      SocketClient().on('transport:updated', _onSocketEvent);
    } else if (_isService) {
      SocketClient().on('service:updated', _onSocketEvent);
    } else {
      SocketClient().on('order:updated', _onSocketEvent);
    }
  }

  Future<void> _loadOrder() async {
    try {
      final data = await ApiClient.get('$_apiPrefix/${widget.doc['_id']}');
      if (data.isNotEmpty && mounted) setState(() => _orderData = data);
    } catch (e) {
      debugPrint("Error loading order: $e");
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _cooldownTimer?.cancel();
    if (_isProjectDelivery) {
      SocketClient().off('project_delivery:updated', _onSocketEvent);
    } else if (_isTransport) {
      SocketClient().off('transport:updated', _onSocketEvent);
    } else if (_isService) {
      SocketClient().off('service:updated', _onSocketEvent);
    } else {
      SocketClient().off('order:updated', _onSocketEvent);
    }
    super.dispose();
  }

  int _ringRemainingSeconds(String orderId) {
    final lastRing = _lastRingTimes[orderId];
    if (lastRing == null) return 0;
    final elapsed = DateTime.now().difference(lastRing);
    final remaining = _ringCooldown - elapsed;
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  منطق التحديثات
  // ══════════════════════════════════════════════════════════════════════════


Future<void> _updateItemStatus(
    Map<String, dynamic> data, int index, String status, double newPrice,
    {String? alternativeName, double? alternativePrice}) async {
  final userId = data['userId'] as String?;
  final List items = List.from(data['items'] as List? ?? []);
  final String itemName = items[index]['name'] ?? 'منتج';
  final double oldPrice = ((items[index]['price'] ?? items[index]['prix'] ?? 0.0) as num).toDouble();

  items[index]['purchaseStatus'] = status;
  if (status == 'purchased') {
    items[index]['finalPrice'] = newPrice;
    items[index].remove('alternativeName');
    items[index].remove('alternativePrice');
    items[index].remove('alternativeStatus');
  } else if (status == '') {
    items[index].remove('finalPrice');
    items[index].remove('alternativeName');
    items[index].remove('alternativePrice');
    items[index].remove('alternativeStatus');
  } else if (status == 'unavailable') {
    items[index].remove('finalPrice');
    if (alternativeName != null) {
      items[index]['alternativeName'] = alternativeName;
      items[index]['alternativePrice'] = alternativePrice ?? 0;
      items[index]['alternativeStatus'] = 'pending';
    } else {
      items[index].remove('alternativeName');
      items[index].remove('alternativePrice');
      items[index].remove('alternativeStatus');
    }
  }

  double newSubtotal = items.fold(0.0, (sum, item) {
    if (item['purchaseStatus'] == 'purchased') {
      final p = (item['finalPrice'] ?? item['price'] ?? item['prix'] ?? 0.0) as num;
      final q = (item['quantity'] ?? 1) as int;
      return sum + p.toDouble() * q;
    }
    return sum;
  });

  // تحديث UI فوراً
  final updatedData = Map<String, dynamic>.from(data);
  updatedData['items'] = items;
  updatedData['subtotal'] = newSubtotal;
  if (mounted) setState(() => _orderData = updatedData);

  ApiClient.put('$_apiPrefix/${widget.doc['_id']}', {
    'items': items,
    'subtotal': newSubtotal,
    'updatedAt': DateTime.now().toIso8601String(),
  });
  if (userId != null) {
    String title, body;
    if (status == 'purchased') {
      title = '🛍️ تحديث في الطلبية';
      body = (newPrice != oldPrice)
          ? 'تم شراء "$itemName" بسعر جديد: ${newPrice.toInt()} DA'
          : 'تم شراء "$itemName" ✓';
    } else if (alternativeName != null) {
      title = '❌ منتج غير متوفر - بديل مقترح';
      body = 'منتج "$itemName" غير متوفر. البديل المقترح: $alternativeName بسعر ${(alternativePrice ?? 0).toInt()} DA';
    } else {
      title = '❌ منتج غير متوفر';
      body = 'للأسف، "$itemName" غير متوفر حالياً.';
    }
    FCMHelper.sendToUser(userId: userId, title: title, body: body,
      data: {'orderId': widget.doc['_id'], 'type': status == 'purchased' ? 'purchased' : 'unavailable'});
  }
}

void _suggestAlternative(Map<String, dynamic> data, int index) {
  final String itemName = (data['items'] as List? ?? [])[index]['name'] ?? 'منتج';
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('المنتج "$itemName" غير متوفر', style: const TextStyle(fontFamily: 'Amiri', fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اقترح بديلاً للزبون:', style: TextStyle(fontFamily: 'Amiri', fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج البديل',
                labelStyle: TextStyle(fontFamily: 'Amiri'),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر (DZD)',
                labelStyle: TextStyle(fontFamily: 'Amiri'),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateItemStatus(data, index, 'unavailable', 0);
            },
            child: const Text('بدون بديل', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim());
              if (name.isEmpty || price == null) return;
              Navigator.pop(ctx);
              _updateItemStatus(data, index, 'unavailable', 0,
                  alternativeName: name, alternativePrice: price);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('إرسال البديل', style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

bool _isAllItemsHandled(List items) {
    return items.isNotEmpty &&
        items.every((item) {
          final s = item['purchaseStatus'] as String? ?? '';
          final alt = item['alternativeStatus'] as String? ?? '';
          if (alt == 'pending') return false;
          return s == 'purchased' || s == 'unavailable';
        });
  }

  void _autoRejectAlternative(Map<String, dynamic> data, int index) {
    final List items = List.from(data['items'] as List? ?? []);
    final String itemName = items[index]['name'] ?? 'منتج';
    items[index]['alternativeStatus'] = 'rejected';
    items[index].remove('alternativeName');
    items[index].remove('alternativePrice');

    final updatedData = Map<String, dynamic>.from(data);
    updatedData['items'] = items;
    if (mounted) setState(() => _orderData = updatedData);

    ApiClient.put('$_apiPrefix/${widget.doc['_id']}', {
      'items': items,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final userId = data['userId'] as String?;
    if (userId != null) {
      FCMHelper.sendToUser(
        userId: userId,
        title: '⏰ انتهى وقت البديل',
        body: 'انتهت المهلة لبديل "$itemName"، تم رفض البديل تلقائياً.',
        data: {'orderId': widget.doc['_id'], 'type': 'unavailable'},
      );
    }
  }

  Future<void> _manualConfirmPurchase(Map<String, dynamic> data) async {
    HapticFeedback.heavyImpact();
    final userId = data['userId'] as String?;
    final updated = Map<String, dynamic>.from(data);
    updated['status'] = 'purchased';
    if (mounted) setState(() => _orderData = updated);
    ApiClient.put('$_apiPrefix/${widget.doc['_id']}', {
      'status': 'purchased',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (userId != null) {
      FCMHelper.sendToUser(userId: userId,
        title: '🛍️ تم شراء جميع المنتجات',
        body: 'السائق انتهى من الشراء وهو في الطريق إليك.',
        data: {'orderId': widget.doc['_id'], 'type': 'purchased'},
      );
    }
  }

  Future<void> _updateStatus(String newStatus, Map<String, dynamic> data) async {
    HapticFeedback.mediumImpact();
    final updated = Map<String, dynamic>.from(data);
    updated['status'] = newStatus;
    if (mounted) setState(() => _orderData = updated);
    ApiClient.put('$_apiPrefix/${widget.doc['_id']}', {'status': newStatus});
  }
Future<void> _finishOrder(Map<String, dynamic> data) async {
  HapticFeedback.heavyImpact();
  final String orderId = widget.doc['_id'];
  final String? userId = data['userId'];
  final double deliveryFee = (data['deliveryFee'] ?? 0).toDouble();

  // إغلاق الشاشة فوراً
  if (mounted) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم توصيل الطلب بنجاح!'), backgroundColor: Colors.green),
    );
  }

  ApiClient.put('$_apiPrefix/$orderId', {
    'status': 'delivered',
    'driverConfirmed': true,
    'updatedAt': DateTime.now().toIso8601String(),
  });
  DriverService.incrementDeliveryStats(earnings: deliveryFee);
}



  void _openCustomerMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _openStoreMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD الرئيسي
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final data = _orderData;
    if (data == null) {
      return const Scaffold(
        backgroundColor: kBgMain,
        body: Center(child: CupertinoActivityIndicator(color: kPrimary)),
      );
    }

    final status = data['status'] as String? ?? 'accepted';

    final isProject = _isProjectDelivery;
    final isTransport = _isTransport;
    final isService = _isService;
    final items = data['items'] as List? ?? [];
    final name = isProject
        ? (data['customerName'] as String? ?? 'زبون')
        : (data['userName'] as String? ?? 'زبون');
    final phone = isProject
        ? (data['customerPhone'] as String? ?? '')
        : (data['userPhone'] as String? ?? '');
    final bool verified = data['userVerified'] as bool? ?? false;
    final bool phoneHidden = data['phoneHidden'] as bool? ?? false;
    final double deliveryFee = isProject
        ? (data['deliveryPrice'] as num? ?? 0).toDouble()
        : (data['deliveryFee'] as num? ?? 0).toDouble();
    final bool allHandled = _isAllItemsHandled(items);
    final statusInfo = _getStatusInfo(status);

    final Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      String sName = item['storeName'] ?? '';
      String tName = item['templateName'] ?? '';
      String cName = item['categoryName'] ?? '';
      String groupTitle = cName.isNotEmpty && tName.isNotEmpty
          ? '$cName — $tName'
          : sName.isNotEmpty && tName.isNotEmpty
              ? '$sName — $tName'
              : sName.isNotEmpty
                  ? sName
                  : 'منتجات عامة';
      groupedIndices.putIfAbsent(groupTitle, () => []).add(i);
    }

    final double purchasedSubtotal = items.fold(0.0, (sum, item) {
      if ((item['purchaseStatus'] as String? ?? '') == 'purchased') {
        final p = (item['finalPrice'] ?? item['price'] ?? item['prix'] ?? 0) as num;
        final q = (item['quantity'] ?? 1) as int;
        return sum + p.toDouble() * q;
      }
      return sum;
    });

    return Scaffold(
      backgroundColor: kBgMain,
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.chevron_right,
                color: Colors.white, size: 18),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Amiri',
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (statusInfo['color'] as Color).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusInfo['icon'] as IconData,
                          color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        statusInfo['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (phone.isNotEmpty && !phoneHidden)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _callPhone(phone);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kGreenMid,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.phone_fill,
                    color: Colors.white, size: 18),
              ),
            ),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
    final List<Map<String, dynamic>> freshDocs = widget.allOrderDocs.map((doc) {
      if (doc['_id'] == data['_id']) {
        return data;
      }
      return doc;
    }).toList();

                   Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverRouteMapScreen(
          activeOrders: freshDocs,
        ),
      ),
    );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.map_rounded, color: kPrimary, size: 16),
                  SizedBox(width: 5),
                  Text(
                    'المسار',
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: isProject
          ? _buildProjectBody(data)
          : isTransport
              ? _buildTransportBody(data)
              : isService
                  ? _buildServiceBody(data)
                  : _buildRegularBody(
                      data, items, groupedIndices, status, allHandled,
                      purchasedSubtotal, deliveryFee, name, phone, verified, phoneHidden),
    );
  }

  Widget _buildRegularBody(
    Map<String, dynamic> data,
    List items,
    Map<String, List<int>> groupedIndices,
    String status,
    bool allHandled,
    double purchasedSubtotal,
    double deliveryFee,
    String name,
    String phone,
    bool verified,
    bool phoneHidden,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      child: Column(
        children: [
          _buildCustomerCard(data, name, phone, verified, phoneHidden: phoneHidden),
          const SizedBox(height: 12),
          _buildDeliveryLocationCard(data),
          const SizedBox(height: 12),
          ...groupedIndices.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStoreGroupCard(
                    entry.key, entry.value, items, status, data),
              )),
          if (data['driverNote'] != null && (data['driverNote'] as String).isNotEmpty)
            _buildNoteCard(data['driverNote'] as String),
          const SizedBox(height: 12),
          if (allHandled) ...[
            _buildSummaryCard(purchasedSubtotal, deliveryFee),
            const SizedBox(height: 12),
          ],
          _buildActionButtons(status, data, items, allHandled),
        ],
      ),
    );
  }

  Widget _buildTransportBody(Map<String, dynamic> data) {
    final userName = data['userName'] ?? '';
    final userPhone = data['userPhone'] ?? '';
    final userVerified = data['userVerified'] as bool? ?? false;
    final phoneHidden = data['phoneHidden'] as bool? ?? false;
    final transportType = data['transportType'] as String? ?? '';
    final note = data['note'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final toAddr = data['toAddress'] as String? ?? '';
    final price = (data['price'] ?? 0).toDouble();
    final fromLat = (data['fromLat'] as num?)?.toDouble();
    final fromLng = (data['fromLng'] as num?)?.toDouble();
    final toLat = (data['toLat'] as num?)?.toDouble();
    final toLng = (data['toLng'] as num?)?.toDouble();
    final parcelImage = data['parcelImageUrl'] as String? ?? '';
    final fromImage = data['fromImage'] as String? ?? '';
    final toImage = data['toImage'] as String? ?? '';
    final status = data['status'] as String? ?? 'accepted';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      child: Column(
        children: [
          _buildCustomerCard(data, userName, userPhone, userVerified, phoneHidden: phoneHidden),
          const SizedBox(height: 12),
          _neumorphicCard(
            title: 'نوع النقل',
            icon: CupertinoIcons.car_detailed,
            child: Column(children: [
              _infoRow(CupertinoIcons.rectangle_stack_fill, 'النوع',
                  transportType == 'delivery' ? 'توصيل' : 'نقل'),
              if (note.isNotEmpty)
                _infoRow(CupertinoIcons.text_bubble_fill, 'ملاحظة', note),
            ]),
          ),
          const SizedBox(height: 10),
          if (parcelImage.isNotEmpty) _imageCard(parcelImage, 'صورة الطرد'),
          if (parcelImage.isNotEmpty) const SizedBox(height: 10),
          if (fromAddr.isNotEmpty)
            _buildLocationCard('موقع الانطلاق', fromAddr, fromLat, fromLng,
                image: fromImage),
          if (fromAddr.isNotEmpty) const SizedBox(height: 10),
          if (toAddr.isNotEmpty)
            _buildLocationCard('موقع الوصول', toAddr, toLat, toLng,
                image: toImage),
          if (toAddr.isNotEmpty) const SizedBox(height: 12),
          _buildTransportSummaryCard(price),
          const SizedBox(height: 12),
          _buildTransportActionButtons(status, data),
        ],
      ),
    );
  }

  Widget _buildServiceBody(Map<String, dynamic> data) {
    final userName = data['userName'] ?? '';
    final userPhone = data['userPhone'] ?? '';
    final userVerified = data['userVerified'] as bool? ?? false;
    final phoneHidden = data['phoneHidden'] as bool? ?? false;
    final serviceType = data['serviceType'] as String? ?? '';
    final note = data['note'] as String? ?? '';
    final orderName = data['orderName'] as String? ?? '';
    final fromAddr = data['fromAddress'] as String? ?? '';
    final toAddr = data['toAddress'] as String? ?? '';
    final price = (data['price'] ?? 0).toDouble();
    final fromLat = (data['fromLat'] as num?)?.toDouble();
    final fromLng = (data['fromLng'] as num?)?.toDouble();
    final toLat = (data['toLat'] as num?)?.toDouble();
    final toLng = (data['toLng'] as num?)?.toDouble();
    final parcelImage = data['parcelImageUrl'] as String? ?? '';
    final status = data['status'] as String? ?? 'accepted';

    final typeLabel = serviceType == 'delivery' ? 'توصيل' : 'إحضار';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      child: Column(
        children: [
          _buildCustomerCard(data, userName, userPhone, userVerified, phoneHidden: phoneHidden),
          const SizedBox(height: 12),
          _neumorphicCard(
            title: 'طلب خدمة',
            icon: CupertinoIcons.wrench_fill,
            child: Column(children: [
              _infoRow(CupertinoIcons.rectangle_stack_fill, 'النوع', typeLabel),
              if (orderName.isNotEmpty)
                _infoRow(CupertinoIcons.doc_text_fill, 'الطلب', orderName),
              if (note.isNotEmpty)
                _infoRow(CupertinoIcons.text_bubble_fill, 'ملاحظة', note),
            ]),
          ),
          const SizedBox(height: 10),
          if (parcelImage.isNotEmpty) _imageCard(parcelImage, 'صورة الطرد'),
          if (parcelImage.isNotEmpty) const SizedBox(height: 10),
          if (fromAddr.isNotEmpty)
            _buildLocationCard('موقع الانطلاق', fromAddr, fromLat, fromLng),
          if (fromAddr.isNotEmpty) const SizedBox(height: 10),
          if (toAddr.isNotEmpty)
            _buildLocationCard('موقع الوصول', toAddr, toLat, toLng),
          if (toAddr.isNotEmpty) const SizedBox(height: 12),
          _buildTransportSummaryCard(price),
          const SizedBox(height: 12),
          _buildServiceActionButtons(status, data),
        ],
      ),
    );
  }

  Widget _buildProjectBody(Map<String, dynamic> data) {
    final storeName = data['storeName'] ?? '';
    final description = data['description'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final deliveryPrice = (data['deliveryPrice'] ?? 0).toDouble();
    final productPrice = (data['productPrice'] ?? 0).toDouble();
    final totalPrice = (data['totalPrice'] ?? 0).toDouble();
    final address = data['customerAddress'] ?? '';
    final storeAddress = data['storeAddress'] ?? '';
    final double? cLat = (data['customerLat'] as num?)?.toDouble();
    final double? cLng = (data['customerLng'] as num?)?.toDouble();
    final double? sLat = (data['storeLat'] as num?)?.toDouble();
    final double? sLng = (data['storeLng'] as num?)?.toDouble();
    final status = data['status'] as String? ?? 'accepted';
    final customerName = data['customerName'] as String? ?? 'زبون';
    final customerPhone = data['customerPhone'] as String? ?? '';
    final bool customerVerified = data['customerVerified'] as bool? ?? false;
    final bool customerPhoneHidden = data['phoneHidden'] as bool? ?? false;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
      child: Column(
        children: [
          _buildCustomerCard(data, customerName, customerPhone, customerVerified, phoneHidden: customerPhoneHidden),
          const SizedBox(height: 12),
          _projectInfoCard(CupertinoIcons.building_2_fill, 'المتجر', storeName),
          const SizedBox(height: 10),
          _projectInfoCard(CupertinoIcons.doc_text_fill, 'الوصف', description),
          const SizedBox(height: 10),
          if (data['capacite'] != null && (data['capacite'] as String).isNotEmpty)
            _projectInfoCard(CupertinoIcons.resize, 'الحجم', data['capacite'] as String),
          if (imageUrl.isNotEmpty) Container(
            width: double.infinity, height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
          ),
          if (imageUrl.isNotEmpty) const SizedBox(height: 12),
          _projectLocationCard('موقع التوصيل', address, cLat, cLng),
          const SizedBox(height: 10),
          if (storeAddress.isNotEmpty || (sLat != null && sLat != 0))
            _projectLocationCard('موقع المتجر', storeAddress, sLat, sLng),
          const SizedBox(height: 12),
          _buildProjectSummaryCard(deliveryPrice, productPrice, totalPrice),
          const SizedBox(height: 12),
          _buildProjectActionButtons(status, data),
        ],
      ),
    );
  }

  Widget _projectInfoCard(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, textAlign: TextAlign.end,
                style: const TextStyle(fontFamily: 'Amiri', color: kTextDark, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontFamily: 'Amiri', color: kTextMid, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _projectLocationCard(String title, String address, double? lat, double? lng) {
    final hasCoords = (lat != null && lat != 0 && lng != null && lng != 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Amiri', color: kTextDark)),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.location_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(CupertinoIcons.map_pin_ellipse, size: 13, color: kAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(address.isNotEmpty ? address : 'لا يوجد عنوان',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: address.isNotEmpty ? kTextDark : kTextLight)),
              ),
              const SizedBox(width: 6),
              const Text('العنوان:', style: TextStyle(fontSize: 12, color: kTextMid, fontFamily: 'Amiri')),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openCustomerMap(lat, lng),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight], begin: Alignment.centerRight, end: Alignment.centerLeft),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('فتح في الخريطة', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                    SizedBox(width: 6),
                    Icon(Icons.map_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(double deliveryPrice, double productPrice, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('ملخص الطلبية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Amiri', color: kTextDark)),
              SizedBox(width: 6),
              Icon(CupertinoIcons.doc_text_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          _summaryRow('المنتج', '${productPrice.toInt()} DA', kTextDark),
          const SizedBox(height: 6),
          _summaryRow('التوصيل', '${deliveryPrice.toInt()} DA', kTextMid),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: kPrimary.withOpacity(0.12), height: 1),
          ),
          _summaryRow('الإجمالي', '${totalPrice.toInt()} DA', kPrimary, bold: true, fontSize: 16),
        ],
      ),
    );
  }

  Widget _buildProjectActionButtons(String status, Map<String, dynamic> data) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(color: kPrimary));
    }

    if (status == 'accepted') {
      return Column(
        children: [
          _outlineButton(
            label: 'راني قريب نوصل',
            icon: CupertinoIcons.car_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () {
              final ownerId = data['storeOwnerId'] as String?;
              if (ownerId != null) {
                FCMHelper.sendToUser(
                  userId: ownerId,
                  title: '🚗 السائق راه قريب يوصل',
                  body: 'السائق راه قريب يوصل لصاحبة المشروع',
                  data: {'deliveryId': widget.doc['_id']},
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار صاحبة المشروع', style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _outlineButton(
            label: 'اخرج اخرج',
            icon: CupertinoIcons.location_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () async {
              final ownerId = data['storeOwnerId'] as String?;
              if (ownerId != null) {
                final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                FCMHelper.sendToUser(
                  userId: ownerId,
                  title: '📍 السائق في موقع التوصيل',
                  body: 'السائق وصل، اخرج لاستلام الطلبية.',
                  data: {
                    'deliveryId': widget.doc['_id'],
                    'sound': 'okhrej',
                    'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                    'driverPhoto': '${dData['photoUrl'] ?? ''}',
                  },
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار صاحبة المشروع', style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _greenGradientButton(
            label: 'تم الوصول',
            icon: CupertinoIcons.checkmark_seal_fill,
            onTap: () {
              final ownerId = data['storeOwnerId'] as String?;
              if (ownerId != null) {
                FCMHelper.sendToUser(
                  userId: ownerId,
                  title: '📍 السائق وصل إلى المحل',
                  body: 'السائق وصل، تم استلام الطلبية.',
                  data: {'deliveryId': widget.doc['_id']},
                );
              }
              _updateProjectStatus('picked_up', data);
            },
          ),
        ],
      );
    }

    if (status == 'picked_up') {
      return _primaryGradientButton(
        label: 'في الطريق إلى موقع الزبون',
        icon: CupertinoIcons.car_fill,
        onTap: () {
          final userId = data['userId'] as String?;
          if (userId != null) {
            FCMHelper.sendToUser(
              userId: userId,
              title: '🚗 السائق في الطريق إليك',
              body: 'السائق قبض الطلبية من صاحبة المشروع وهو في الطريق إليك.',
              data: {'deliveryId': widget.doc['_id'], 'type': 'in_transit'},
            );
          }
          _updateProjectStatus('in_transit', data);
        },
      );
    }

    if (status == 'in_transit') {
      return Column(
        children: [
          _outlineButton(
            label: 'راني قريب نوصل',
            icon: CupertinoIcons.car_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () {
              final userId = data['userId'] as String?;
              if (userId != null) {
                FCMHelper.sendToUser(
                  userId: userId,
                  title: '🚗 السائق راه قريب يوصل',
                  body: 'السائق راه قريب يوصل، وجّد روحك',
                  data: {'deliveryId': widget.doc['_id']},
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار الزبون أنك قريب', style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _outlineButton(
            label: 'اخرج اخرج',
            icon: CupertinoIcons.location_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () async {
              final userId = data['userId'] as String?;
              if (userId != null) {
                final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                FCMHelper.sendToUser(
                  userId: userId,
                  title: '📍 السائق في موقع التوصيل',
                  body: 'السائق وصل إلى عنوانك، اخرج لاستلام طلبيتك',
                  data: {
                    'deliveryId': widget.doc['_id'],
                    'sound': 'okhrej',
                    'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                    'driverPhoto': '${dData['photoUrl'] ?? ''}',
                  },
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار الزبون بوصولك', style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _greenGradientButton(
            label: 'تم التسليم',
            icon: CupertinoIcons.checkmark_shield_fill,
            onTap: () => _finishProjectDelivery(data),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _updateProjectStatus(String newStatus, Map<String, dynamic> data) async {
    HapticFeedback.mediumImpact();
    // تحديث UI فوراً
    final updated = Map<String, dynamic>.from(data);
    updated['status'] = newStatus;
    if (mounted) setState(() => _orderData = updated);
    // إرسال للسيرفر (الـ FCM يبعثه السيرفر)
    ApiClient.put('$_apiPrefix/${widget.doc['_id']}', {'status': newStatus});
  }

  Future<void> _finishProjectDelivery(Map<String, dynamic> data) async {
    HapticFeedback.heavyImpact();
    final String deliveryId = widget.doc['_id'];
    final String? storeId = data['storeId'];
    final double deliveryPrice = (data['deliveryPrice'] ?? 0).toDouble();
    final double productPrice = (data['productPrice'] ?? 0).toDouble();
    final double totalPrice = (data['totalPrice'] ?? deliveryPrice + productPrice).toDouble();

    // 1. كل API calls قبل pop
    await ApiClient.put('$_apiPrefix/$deliveryId', {
      'status': 'delivered',
      'updatedAt': DateTime.now().toIso8601String(),
    });
    DriverService.incrementDeliveryStats(earnings: deliveryPrice);

    final String? projectId = data['projectId'];
    if (projectId != null && projectId.isNotEmpty) {
      try {
        await ApiClient.put('/api/projects/$projectId', {
          'status': 'delivered',
          'deliveredAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        debugPrint('فشل تحديث حالة المشروع $projectId');
      }
    }

    if (storeId != null && storeId.isNotEmpty) {
      try {
        final storeData = await ApiClient.get('/api/stores/$storeId');
        final currentCash = (storeData['cash'] as num?)?.toDouble() ?? 0;
        final currentEarnings = (storeData['totalEarnings'] as num?)?.toDouble() ?? 0;
        await ApiClient.put('/api/stores/$storeId', {
          'cash': currentCash + totalPrice,
          'totalEarnings': currentEarnings + totalPrice,
        });
        try {
          final categories = await ApiClient.getList('/api/categories?storeId=$storeId');
          for (final cat in categories) {
            if (cat is Map) {
              final catId = cat['_id'] as String? ?? cat['id'] as String?;
              if (catId != null && catId.isNotEmpty) {
                final catCash = (cat['cash'] as num?)?.toDouble() ?? 0;
                final catEarnings = (cat['totalEarnings'] as num?)?.toDouble() ?? 0;
                await ApiClient.put('/api/categories/$catId', {
                  'cash': catCash + totalPrice,
                  'totalEarnings': catEarnings + totalPrice,
                });
              }
            }
          }
        } catch (_) {
          debugPrint('فشل تحديث رصيد الفئات للمتجر $storeId');
        }
      } catch (_) {
        debugPrint('فشل تحديث رصيد المحل للتوصيلية $deliveryId');
      }
    }

    // 2. بعد كل API calls نخرج من الشاشة
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توصيل الطلب بنجاح!'), backgroundColor: Colors.green),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  كارت نيومورفيك عام
  // ══════════════════════════════════════════════════════════════════════════
  Widget _neumorphicCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                      color: kTextDark)),
              const SizedBox(width: 6),
              Icon(icon, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _imageCard(String imageUrl, String label) {
    return Container(
      width: double.infinity,
      decoration: _cardDecor(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'Amiri', color: kTextLight)),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.photo_camera, color: kAccent, size: 13),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageFullscreen(imageUrl),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(String title, String address, double? lat,
      double? lng,
      {String? image}) {
    final hasCoords = lat != null && lng != null && lat != 0 && lng != 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                      color: kTextDark)),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.location_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          _infoRow(CupertinoIcons.map_pin_ellipse, 'العنوان', address),
          if (image != null && image.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageFullscreen(image),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text('عرض الصورة',
                      style: TextStyle(
                          color: kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          decoration: TextDecoration.underline)),
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.photo_camera, color: kPrimary, size: 18),
                ],
              ),
            ),
          ],
          if (hasCoords) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openCustomerMap(lat, lng),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kPrimary, kPrimaryLight],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('فتح في الخريطة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                    SizedBox(width: 6),
                    Icon(Icons.map_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransportSummaryCard(double price) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('ملخص الطلبية',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                      color: kTextDark)),
              SizedBox(width: 6),
              Icon(CupertinoIcons.doc_text_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          _summaryRow('قيمة النقل', '${price.toInt()} DA', kTextDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: kPrimary.withOpacity(0.12), height: 1),
          ),
          _summaryRow('الإجمالي', '${price.toInt()} DA', kPrimary,
              bold: true, fontSize: 16),
        ],
      ),
    );
  }

  Widget _buildTransportActionButtons(
      String status, Map<String, dynamic> data) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(color: kPrimary));
    }

    if (status == 'accepted') {
      return _primaryGradientButton(
        label: 'باشر التوصيل',
        icon: CupertinoIcons.play_fill,
        onTap: () => _updateStatus('onway', data),
      );
    }

    if (status == 'onway') {
      return Column(
        children: [
          _outlineButton(
            label: 'راني قريب نوصل',
            icon: CupertinoIcons.car_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () {
              final uid = data['userId'] as String?;
              if (uid != null) {
                FCMHelper.sendToUser(
                  userId: uid,
                  title: '🚗 السائق راه قريب يوصل',
                  body: 'السائق راه قريب يوصل، وجّد روحك',
                  data: {'orderId': widget.doc['_id']},
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار الزبون أنك قريب',
                      style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _outlineButton(
            label: 'اخرج اخرج',
            icon: CupertinoIcons.location_fill,
            color: kPrimary,
            bg: kPrimaryPale,
            border: kPrimary,
            onTap: () async {
              final uid = data['userId'] as String?;
              if (uid != null) {
                final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
                FCMHelper.sendToUser(
                  userId: uid,
                  title: '📍 السائق في موقع التوصيل',
                  body: 'السائق وصل إلى عنوانك، اخرج لاستلام طلبيتك',
                  data: {
                    'orderId': widget.doc['_id'],
                    'sound': 'okhrej',
                    'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                    'driverPhoto': '${dData['photoUrl'] ?? ''}',
                  },
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إشعار الزبون بوصولك',
                      style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _greenGradientButton(
            label: 'تم التوصيل',
            icon: CupertinoIcons.checkmark_shield_fill,
            onTap: () => _finishOrder(data),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildServiceActionButtons(
      String status, Map<String, dynamic> data) {
    return _buildTransportActionButtons(status, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  بطاقة معلومات الزبون
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCustomerCard(
      Map<String, dynamic> data, String name, String phone, bool verified, {bool phoneHidden = false}) {
    final userGender = data['userGender'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Row(
        children: [
          // شارة التوثيق + الهاتف
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: verified
                      ? const Color(0xFF1877F2).withOpacity(0.08)
                      : kRedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: verified
                        ? const Color(0xFF1877F2).withOpacity(0.25)
                        : kRed.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      verified ? Icons.verified : Icons.warning_rounded,
                      color: verified ? const Color(0xFF1877F2) : kRed,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      verified ? 'حساب موثق' : 'غير موثق',
                      style: TextStyle(
                        color: verified ? const Color(0xFF1877F2) : kRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty && !phoneHidden) ...[ 
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('تم نسخ الرقم 📋',
                            style: TextStyle(fontFamily: 'Amiri')),
                        backgroundColor: kPrimary,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.doc_on_clipboard,
                          color: kPrimary.withOpacity(0.5), size: 12),
                      const SizedBox(width: 4),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 12,
                              color: kTextMid,
                              fontFamily: 'Amiri')),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
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
              const SizedBox(height: 2),
              const Text(
                'الزبون',
                style: TextStyle(
                    fontSize: 11, color: kTextLight, fontFamily: 'Amiri'),
              ),
            ],
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: Image.asset(
              userGender == 'female' ? 'assets/images/avatarf.png' : 'assets/images/avatar.png',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.person_fill,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  بطاقة موقع التسليم
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDeliveryLocationCard(Map<String, dynamic> data) {
    final address     = data['address']       as String? ?? '';
    final doorNumber  = data['doorNumber']    as String? ?? '';
    final doorColor   = data['doorColor']     as String? ?? '';
    final floor       = data['floor']         as String? ?? '';
    final housingType = data['housingType']   as String? ?? '';
    final locationImg = data['locationImage'] as String? ?? '';
    final double? lat = (data['userLat'] as num?)?.toDouble();
    final double? lng = (data['userLng'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // عنوان القسم
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                "موقع تسليم الطلبــية",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Amiri',
                    color: kTextDark),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.location_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),

          // التفاصيل
          if (address.isNotEmpty)
            _infoRow(CupertinoIcons.map_pin_ellipse, 'العنوان', address),
          if (housingType.isNotEmpty)
            _infoRow(CupertinoIcons.house_fill, 'نوع السكن', housingType),
          if (floor.isNotEmpty)
            _infoRow(CupertinoIcons.layers_alt_fill, 'الطابق', floor),
          if (doorNumber.isNotEmpty)
            _infoRow(CupertinoIcons.number, 'رقم الباب', doorNumber),
          if (doorColor.isNotEmpty)
            _infoRow(Icons.color_lens_outlined, 'لون الباب', doorColor),

          // صورة الموقع
          // استبدال كود عرض الصورة القديم بهذا النص القابل للضغط
if (locationImg.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: GestureDetector(
      onTap: () => _showImageFullscreen(locationImg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          Text(
            'عرض صورة الموقع',
            style: TextStyle(
              color: kPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              decoration: TextDecoration.underline, // السطر تحت الكلمة
            ),
          ),
          SizedBox(width: 8),
          Icon(CupertinoIcons.photo_camera, color: kPrimary, size: 18),
        ],
      ),
    ),
  ),
          // زر الخريطة
          if (lat != null && lng != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openCustomerMap(lat, lng),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryLight],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('فتح في الخريطة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                    SizedBox(width: 6),
                    Icon(Icons.map_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],

          // زر رنين الزبون
          if (lat != null && lng != null) ...[
            const SizedBox(height: 10),
            Builder(builder: (ctx) {
              final orderId = data['_id']?.toString() ?? '';
              final remaining = _ringRemainingSeconds(orderId);
              final inCooldown = remaining > 0;
              return GestureDetector(
                onTap: inCooldown ? null : () async {
                  final userId = data['userId'] as String?;
                  if (userId == null) return;
                  _lastRingTimes[orderId] = DateTime.now();
                  final dData = await ApiClient.get('/api/drivers/${FirebaseAuth.instance.currentUser?.uid}').catchError((_) => <String, dynamic>{});
                  if (!ctx.mounted) return;
                  FCMHelper.sendToUser(
                    userId: userId,
                    title: '🔔 رنين من السائق',
                    body: 'السائق يتصل بك، اخرج لاستلام طلبيتك',
                    data: {
                      'orderId': data['_id'] ?? '',
                      'sound': 'ring',
                      'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                      'driverPhoto': '${dData['photoUrl'] ?? ''}',
                    },
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('🔔 تم إشعار الزبون!', style: TextStyle(fontFamily: 'Amiri')),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: inCooldown ? Colors.grey.shade400 : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (inCooldown)
                        Text('${remaining}s ',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri'))
                      else
                        const Text('رنين الزبون',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri')),
                      const SizedBox(width: 6),
                      Icon(inCooldown ? CupertinoIcons.timer : CupertinoIcons.bell_fill, color: inCooldown ? Colors.white70 : Colors.white, size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                    fontFamily: 'Amiri'),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 6),
          Text('$label:',
              style: const TextStyle(
                  fontSize: 12, color: kTextMid, fontFamily: 'Amiri')),
          const SizedBox(width: 5),
          Icon(icon, size: 13, color: kAccent),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  بطاقة مجموعة محل
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStoreGroupCard(String groupTitle, List<int> indices, List items,
      String status, Map<String, dynamic> data) {
    final firstItem = items[indices.first] as Map<String, dynamic>;
    debugPrint('_buildStoreGroupCard: item keys=${firstItem.keys}');
    debugPrint('_buildStoreGroupCard: storeLat=${firstItem['storeLat']} storeLng=${firstItem['storeLng']}');
    double? storeLat = (firstItem['storeLat'] as num?)?.toDouble();
    double? storeLng = (firstItem['storeLng'] as num?)?.toDouble();
    final bool hasLocation = storeLat != null && storeLng != null;
    final bool isEditable = status == 'accepted';

    return Container(
      decoration: _cardDecor(),
      child: Column(
        children: [
          // ترويسة المحل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimaryPale,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: const Border(bottom: BorderSide(color: kDivider)),
            ),
            child: Row(
              children: [
                // زر موقع المحل
                GestureDetector(
                  onTap: hasLocation
                      ? () => _openStoreMap(storeLat, storeLng)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasLocation
                          ? kPrimary.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasLocation
                            ? kPrimary.withOpacity(0.3)
                            : kBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12,
                            color: hasLocation ? kPrimary : kTextLight),
                        const SizedBox(width: 4),
                        Text(
                          hasLocation ? 'موقع المحل' : 'لا يوجد موقع',
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Amiri',
                              color: hasLocation ? kPrimary : kTextLight,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // اسم المحل
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      groupTitle,
                      style: const TextStyle(
                          color: kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri'),
                    ),
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.building_2_fill,
                        color: kPrimary, size: 14),
                  ],
                ),
              ],
            ),
          ),

          // المنتجات
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: indices.map((originalIndex) {
                final item = items[originalIndex] as Map<String, dynamic>;
                return _DetailProductTile(
                  key: ValueKey('$originalIndex-${item['purchaseStatus']}-${item['alternativeStatus']}'),
                  item: item,
                  isEditable: isEditable,
                  onPurchased: (price) =>
                      _updateItemStatus(data, originalIndex, 'purchased', price),
                  onUnavailable: () =>
                      _suggestAlternative(data, originalIndex),
                  onReset: () => _updateItemStatus(
                      data,
                      originalIndex,
                      '',
                      ((item['price'] ?? item['prix'] ?? 0) as num).toDouble()),
                  onAutoRejectAlternative: () =>
                      _autoRejectAlternative(data, originalIndex),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ملخص المبالغ
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryCard(double subtotal, double deliveryFee) {
    final bool isFree = deliveryFee == 0;
    final double total = subtotal + deliveryFee;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('ملخص الطلبية',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                      color: kTextDark)),
              SizedBox(width: 6),
              Icon(CupertinoIcons.doc_text_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          _summaryRow('المنتجات', '${subtotal.toInt()} DA', kTextDark),
          const SizedBox(height: 6),
          _summaryRow(
            'التوصيل',
            isFree ? 'مجاني 🎁' : '${deliveryFee.toInt()} DA',
            isFree ? Colors.orange : kTextMid,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: kPrimary.withOpacity(0.12), height: 1),
          ),
          _summaryRow(
            'الإجمالي',
            '${total.toInt()} DA',
            kPrimary,
            bold: true,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor,
      {bool bold = false, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: valueColor,
                fontFamily: 'Amiri')),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: kTextMid, fontFamily: 'Amiri')),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  بطاقة الملاحظة العامة
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildNoteCard(String note) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text('ملاحظة الطلب',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Amiri',
                      color: kTextDark)),
              SizedBox(width: 6),
              Icon(CupertinoIcons.text_bubble_fill, color: kAccent, size: 15),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 10),
          Text(
            note,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Amiri',
              color: kTextDark,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════  ═════
  //  أزرار الإجراءات
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActionButtons(
    String status, Map<String, dynamic> data, List items, bool allHandled) {
  if (_loading) {
    return const Center(child: CupertinoActivityIndicator(color: kPrimary));
  }

  if (status == 'accepted' && allHandled) {
    return _greenGradientButton(
      label: ' تأكيد شراء جميع المنتجات',
      icon: CupertinoIcons.cart_fill,
      onTap: () => _manualConfirmPurchase(data),
    );
  }

  if (status == 'purchased') {
    return _primaryGradientButton(
      label: 'في الطريق للزبون ',
      icon: CupertinoIcons.car_fill,
      onTap: () => _updateStatus('onway', data),
    );
  }

  if (status == 'onway') {
    return Column(
      children: [
        _outlineButton(
          label: 'راني قريب نوصل',
          icon: CupertinoIcons.car_fill,
          color: kPrimary,
          bg: kPrimaryPale,
          border: kPrimary,
          onTap: () {
            final userId = data['userId'] as String?;
            if (userId != null) {
              FCMHelper.sendToUser(userId: userId,
                title: '🚗 السائق راه قريب يوصل',
                body: 'السائق راه قريب يوصل، وجّد روحك',
                data: {'orderId': widget.doc['_id']},
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إشعار الزبون أنك قريب', style: TextStyle(fontFamily: 'Amiri')),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _outlineButton(
          label: 'اخرج اخرج',
          icon: CupertinoIcons.location_fill,
          color: kPrimary,
          bg: kPrimaryPale,
          border: kPrimary,
          onTap: () async {
            HapticFeedback.mediumImpact();
            final userId = data['userId'] as String?;
            if (userId != null) {
              final dData = await ApiClient.get('/api/drivers/${DriverService.uid}').catchError((_) => <String, dynamic>{});
              FCMHelper.sendToUser(userId: userId,
                title: '📍 السائق في موقع التوصيل',
                body: 'السائق وصل إلى عنوانك، اخرج لاستلام طلبيتك',
                data: {
                  'orderId': widget.doc['_id'],
                  'sound': 'okhrej',
                  'driverName': '${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}'.trim(),
                  'driverPhoto': '${dData['photoUrl'] ?? ''}',
                },
              );
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إشعار الزبون بوصولك', style: TextStyle(fontFamily: 'Amiri')),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _greenGradientButton(
          label: 'تم التسليم بنجاح ',
          icon: CupertinoIcons.checkmark_shield_fill,
          onTap: () => _finishOrder(data),
        ),
      ],
    );
  }

  return const SizedBox.shrink();
}

  Widget _primaryGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A007A), kPrimaryLight],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Amiri')),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _greenGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), kGreenMid],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kGreen.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Amiri')),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Amiri')),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  // ── مساعدات ──
  BoxDecoration _cardDecor() => BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      );

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'accepted':
        return {'color': kPrimary, 'label': 'في الطريق للمحل', 'icon': CupertinoIcons.bag_fill};
      case 'purchased':
        return {'color': kGreen, 'label': 'تم الشراء', 'icon': CupertinoIcons.checkmark_seal_fill};
      case 'onway_to_store':
        return {'color': kWarning, 'label': 'في الطريق للمتجر', 'icon': CupertinoIcons.car_fill};
      case 'picked_up':
        return {'color': kGreen, 'label': 'تم الاستلام من المتجر', 'icon': CupertinoIcons.checkmark_seal_fill};
      case 'onway':
        return {'color': kPrimaryLight, 'label': 'في الطريق للزبون', 'icon': CupertinoIcons.car_fill};
      default:
        return {'color': kPrimary, 'label': 'جارية', 'icon': CupertinoIcons.clock_fill};
    }
  }

  void _showImageFullscreen(String url) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.95), // خلفية سوداء داكنة
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // عرض الصورة
          Center(
            child: InteractiveViewer( // يسمح بعمل زووم بالأصابع
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // زر الرجوع في الأعلى
          Positioned(
            top: 50,
            left: 20, // جهة اليسار للرجوع
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.arrow_left, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ══════════════════════════════════════════════════════════════════════════════
//  _DetailProductTile — بلاطة المنتج داخل صفحة التفاصيل
// ══════════════════════════════════════════════════════════════════════════════
class _DetailProductTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isEditable;
  final Function(double) onPurchased;
  final VoidCallback onUnavailable;
  final VoidCallback onReset;
  final VoidCallback? onAutoRejectAlternative;

  const _DetailProductTile({
    super.key,
    required this.item,
    required this.isEditable,
    required this.onPurchased,
    required this.onUnavailable,
    required this.onReset,
    this.onAutoRejectAlternative,
  });

  @override
  State<_DetailProductTile> createState() => _DetailProductTileState();
}

class _DetailProductTileState extends State<_DetailProductTile> {
  late TextEditingController _priceCtrl;
  Timer? _altTimer;
  int _remainingSeconds = 120;

  @override
  void initState() {
    super.initState();
    final price =
        (widget.item['finalPrice'] ?? widget.item['price'] ?? widget.item['prix'] ?? 0).toDouble();
    _priceCtrl = TextEditingController(text: price.toInt().toString());
    _startAltTimerIfNeeded();
  }

  void _startAltTimerIfNeeded() {
    final altStatus = widget.item['alternativeStatus'] as String? ?? '';
    if (altStatus == 'pending') {
      _remainingSeconds = 120;
      _altTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds <= 1) {
          t.cancel();
          widget.onAutoRejectAlternative?.call();
          return;
        }
        if (mounted) setState(() => _remainingSeconds--);
      });
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _altTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DetailProductTile old) {
    super.didUpdateWidget(old);
    if (old.item['finalPrice'] != widget.item['finalPrice'] ||
        old.item['price'] != widget.item['price'] ||
        old.item['prix'] != widget.item['prix']) {
      final price =
          (widget.item['finalPrice'] ?? widget.item['price'] ?? widget.item['prix'] ?? 0).toDouble();
      _priceCtrl.text = price.toInt().toString();
    }
    final oldAlt = old.item['alternativeStatus'] as String? ?? '';
    final newAlt = widget.item['alternativeStatus'] as String? ?? '';
    if (oldAlt != newAlt) {
      _altTimer?.cancel();
      if (newAlt == 'pending') {
        _remainingSeconds = 120;
        _altTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_remainingSeconds <= 1) {
            t.cancel();
            widget.onAutoRejectAlternative?.call();
            return;
          }
          if (mounted) setState(() => _remainingSeconds--);
        });
      }
    }
  }

  void _showFullscreen(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Hero(
                  tag: 'detail-product-$url',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.arrow_left,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog(String note) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'ملاحظة المنتج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: kTextDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.text_bubble_fill,
                    color: kPrimary, size: 14),
              ),
            ],
          ),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Amiri',
                color: kTextDark,
                height: 1.6,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'حسناً',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetailDialog(
      String name, String image, int qty, double price,
      String capacite, String size, String weight,
      String category, String template, String note) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    color: kTextDark,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.bag_fill,
                    color: kPrimary, size: 14),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (image.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: image,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _detailRow('الكمية', '$qty'),
                _detailRow('السعر', '${price.toInt()} DA'),
                if (capacite.isNotEmpty) _detailRow('السعة', capacite, textDirection: TextDirection.ltr),
                if (size.isNotEmpty) _detailRow('المقاس', size),
                if (weight.isNotEmpty) _detailRow('الوزن', weight),
                if (category.isNotEmpty) _detailRow('التصنيف', category),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: kDivider),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'ملاحظة المنتج',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(CupertinoIcons.text_bubble_fill,
                          color: kWarning, size: 14),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kWarning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kWarning.withOpacity(0.2)),
                    ),
                    child: Text(
                      note,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Amiri',
                        color: kTextDark,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'حسناً',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {TextDirection? textDirection}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value,
            textDirection: textDirection,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Amiri',
              color: kTextDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Amiri',
              color: kTextGrey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pStatus   = widget.item['purchaseStatus'] as String? ?? '';
    final altStatus = widget.item['alternativeStatus'] as String? ?? '';
    final bool isAltAccepted  = altStatus == 'accepted';
    final bool isAltPending   = altStatus == 'pending';

    final name     = widget.item[isAltAccepted ? 'alternativeName' : 'name'] as String? ?? '';
    final qty      = widget.item['quantity']       as int?    ?? 1;
    final image    = widget.item['image']          as String? ?? '';
    final capacite = widget.item['capacite']       as String? ?? '';
    final size     = widget.item['size']           as String? ?? '';
    final weight   = widget.item['weight']         as String? ?? '';
    final category = widget.item['categoryName']   as String? ?? '';
    final template = widget.item['templateName']   as String? ?? '';
    final priceNum = (widget.item['finalPrice'] ?? widget.item['price'] ?? widget.item['prix'] ?? 0) as num;

    Color cardBg     = Colors.white;
    Color cardBorder = kBorder;
    if (isAltPending) {
      cardBg     = const Color(0xFFFFF8E1);
      cardBorder = Colors.orange.withOpacity(0.3);
    } else if (pStatus == 'purchased' || isAltAccepted) {
      cardBg     = kGreenBg;
      cardBorder = kGreenMid.withOpacity(0.35);
    } else if (pStatus == 'unavailable') {
      cardBg     = kRedBg;
      cardBorder = kRed.withOpacity(0.25);
    }

    final note = widget.item['note'] as String? ?? '';
    final bool hasNote = note.isNotEmpty;

    return GestureDetector(
      onTap: () => _showProductDetailDialog(name, image, qty, priceNum.toDouble(),
          capacite, size, weight, category, template, note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① السعر + أزرار التحكم
            Column(
              children: [
                _buildPriceBox(pStatus, priceNum.toDouble()),
                const SizedBox(height: 8),
                _buildControls(pStatus),
              ],
            ),

            const SizedBox(width: 12),

            // ② معلومات المنتج
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                      color: kTextDark,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (isAltAccepted)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kGreenMid.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'البديل مقبول ✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Amiri',
                          color: kGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isAltPending)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'بانتظار رد الزبون',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Amiri',
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _tag('الكمية: $qty', kPrimary, kPrimaryPale),
                      if (capacite.isNotEmpty)
                        _tag(capacite, kPrimary, kPrimaryPale, textDirection: TextDirection.ltr),
                      if (size.isNotEmpty)
                        _tag('المقاس: $size', kPrimaryLight, kPrimaryPale),
                      if (weight.isNotEmpty)
                        _tag('الوزن: $weight', kTextMid, const Color(0xFFF0EDF8)),
                      if (hasNote)
                        GestureDetector(
                          onTap: () => _showNoteDialog(note),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kPrimaryPale,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kPrimary.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  note.length > 10
                                      ? 'ملاحظة: ${note.substring(0, 10)}...'
                                      : 'ملاحظة: $note',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Amiri',
                                    color: kPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.text_bubble_fill,
                                    color: kPrimary, size: 12),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ③ الصورة
            _buildImage(image, pStatus),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, Color bg, {TextDirection? textDirection}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        textDirection: textDirection,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
          fontFamily: 'Amiri',
        ),
      ),
    );
  }

  Widget _buildImage(String image, String pStatus) {
    Widget imgWidget = image.isNotEmpty
        ? GestureDetector(
            onTap: () => _showFullscreen(image),
            child: Hero(
              tag: 'detail-product-$image',
              child: CachedNetworkImage(
                imageUrl: image,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: kPrimaryPale,
                  child: const CupertinoActivityIndicator(
                      radius: 8, color: kPrimary),
                ),
                errorWidget: (_, __, ___) => const Icon(
                    CupertinoIcons.photo, color: kTextLight, size: 22),
              ),
            ),
          )
        : Container(
            width: 64,
            height: 64,
            color: kPrimaryPale,
            child: const Icon(CupertinoIcons.photo,
                color: kTextLight, size: 22),
          );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imgWidget,
        ),
        if (pStatus == 'purchased')
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: kGreenMid.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.checkmark_alt,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        if (pStatus == 'unavailable')
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: kRed.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.xmark,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceBox(String pStatus, double price) {
    final altStatus = widget.item['alternativeStatus'] as String? ?? '';
    if (altStatus == 'pending') {
      final int minutes = _remainingSeconds ~/ 60;
      final int seconds = _remainingSeconds % 60;
      return Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri'),
              textAlign: TextAlign.center,
            ),
            const Text(
              'بانتظار الزبون',
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Amiri'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (pStatus == 'purchased' || pStatus == 'unavailable') {
      final color = pStatus == 'purchased' ? kGreen : kRed;
      final bg    = pStatus == 'purchased' ? kGreenBg : kRedBg;
      return Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(
            pStatus == 'purchased' ? '${price.toInt()} DA' : 'غير متوفر',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: kPrimaryPale,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withOpacity(0.22)),
      ),
      child: TextField(
        controller: _priceCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: kPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri'),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: InputBorder.none,
          suffixText: 'DA',
          suffixStyle: TextStyle(fontSize: 10, color: kPrimary),
        ),
      ),
    );
  }

  Widget _buildControls(String pStatus) {
    final altStatus = widget.item['alternativeStatus'] as String? ?? '';
    if (altStatus == 'pending') return const SizedBox.shrink();

    if (pStatus.isNotEmpty && widget.isEditable) {
      return GestureDetector(
        onTap: widget.onReset,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kPrimaryPale,
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: const Icon(Icons.refresh_rounded, size: 18, color: kTextMid),
        ),
      );
    }

    if (pStatus.isNotEmpty && !widget.isEditable) {
      return const SizedBox.shrink();
    }

    if (!widget.isEditable) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onUnavailable,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kRedBg,
              shape: BoxShape.circle,
              border: Border.all(color: kRed.withOpacity(0.2)),
            ),
            child: const Icon(CupertinoIcons.xmark, color: kRed, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final newPrice = double.tryParse(_priceCtrl.text) ??
                ((widget.item['price'] ?? widget.item['prix'] ?? 0) as num).toDouble();
            widget.onPurchased(newPrice);
          },
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kGreenBg,
              shape: BoxShape.circle,
              border: Border.all(color: kGreen.withOpacity(0.2)),
            ),
            child: const Icon(CupertinoIcons.checkmark_alt,
                color: kGreen, size: 16),
          ),
        ),
      ],
    );
  }
}