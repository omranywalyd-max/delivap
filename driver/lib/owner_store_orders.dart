import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:dashbord/services/socket_client.dart';

const Color _kPrimary = Color(0xFF5B0094);
const Color _kBg = Color(0xFFE8E6F0);

class OwnerStoreOrdersPage extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String ownerId;
  const OwnerStoreOrdersPage({super.key, required this.storeId, required this.storeName, required this.ownerId});

  @override
  State<OwnerStoreOrdersPage> createState() => _OwnerStoreOrdersPageState();
}

class _OwnerStoreOrdersPageState extends State<OwnerStoreOrdersPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allOrders = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
    SocketClient().join('user_${widget.ownerId}');
    SocketClient().on('order:updated', _onOrderUpdated);
  }

  @override
  void dispose() {
    SocketClient().off('order:updated', _onOrderUpdated);
    try { SocketClient().leave('user_${widget.ownerId}'); } catch (_) {}
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onOrderUpdated(dynamic data) {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/orders/by-store-owner?storeId=${widget.storeId}&ownerId=${widget.ownerId}');
      if (mounted) setState(() { _allOrders = data.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _splitByCategory(List<Map<String, dynamic>> orders) {
    final result = <Map<String, dynamic>>[];
    for (final order in orders) {
      final allItems = (order['items'] as List? ?? []).where((item) {
        return (item is Map) && (item['storeId'] as String? ?? '') == widget.storeId;
      }).toList();
      if (allItems.isEmpty) {
        result.add({
          ...order,
          '_catId': '_none_',
          '_catName': 'أخرى',
          '_catItems': <Map<String, dynamic>>[],
          '_catTotal': 0.0,
        });
        continue;
      }
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final item in allItems) {
        final m = item as Map<String, dynamic>;
        final catId = (m['categorieId'] as String? ?? '').isNotEmpty
            ? m['categorieId'] as String
            : '_none_';
        grouped.putIfAbsent(catId, () => []).add(m);
      }
      for (final entry in grouped.entries) {
        final catId = entry.key;
        final catItems = entry.value;
        final catName = catId == '_none_' ? 'أخرى' : (catItems.first['categoryName'] as String? ?? 'قسم');
        final catTotal = catItems.fold<double>(0, (s, i) {
          final price = (i['finalPrice'] ?? i['price'] ?? i['prix'] ?? 0);
          final qty = (i['quantity'] ?? 1);
          return s + ((price is num ? price.toDouble() : 0) * (qty is num ? qty.toDouble() : 1));
        });
        result.add({
          ...order,
          '_catId': catId,
          '_catName': catName,
          '_catItems': catItems,
          '_catTotal': catTotal,
        });
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _ongoing => _splitByCategory(_allOrders.where((o) {
    final s = o['status'] as String? ?? '';
    return s == 'accepted' || s == 'purchased' || s == 'onway';
  }).toList());

  List<Map<String, dynamic>> get _completed => _splitByCategory(_allOrders.where((o) {
    final s = o['status'] as String? ?? '';
    return s == 'delivered' || s == 'cancelled';
  }).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, color: _kPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('طلبيات ${widget.storeName}', style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 16)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _kPrimary,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'جارية (${_ongoing.length})'),
            Tab(text: 'منتهية (${_completed.length})'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _kPrimary))
        : TabBarView(
            controller: _tabCtrl,
            children: [
              _buildList(_ongoing, 'لا توجد طلبيات جارية'),
              _buildList(_completed, 'لا توجد طلبيات منتهية'),
            ],
          ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> orders, String emptyMsg) {
    if (orders.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.doc_text, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(fontFamily: 'Amiri', color: Colors.grey.shade500, fontSize: 14)),
        ],
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(
        order: orders[i],
        storeId: widget.storeId,
        onTap: () => _showOrderDetail(orders[i]),
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order, storeId: widget.storeId, ownerId: widget.ownerId),
    );
  }
}

List<Map<String, dynamic>> _itemsForStore(List<dynamic> items, String storeId) {
  return items.where((item) {
    final itemStoreId = (item is Map ? (item['storeId'] as String? ?? '') : '');
    return itemStoreId == storeId;
  }).cast<Map<String, dynamic>>().toList();
}

// ═══════════════════  كارد الطلبية  ═══════════════════
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String storeId;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.storeId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catName = order['_catName'] as String? ?? 'قسم';
    final catItems = order['_catItems'] as List<dynamic>? ?? [];
    final catTotal = (order['_catTotal'] as num? ?? 0).toDouble();
    final itemCount = catItems.length;
    final userName = order['userName'] as String? ?? 'زبون';
    final status = order['status'] as String? ?? '';
    String statusLabel;
    Color statusColor;
    switch (status) {
      case 'accepted': statusLabel = 'تم القبول'; statusColor = Colors.blue; break;
      case 'purchased': statusLabel = 'تم الشراء'; statusColor = Colors.orange; break;
      case 'onway': statusLabel = 'في الطريق'; statusColor = Colors.amber.shade700; break;
      case 'delivered': statusLabel = 'تم التوصيل'; statusColor = Colors.green; break;
      default: statusLabel = status; statusColor = Colors.grey;
    }
    final createdAt = order['createdAt'] as String? ?? '';
    String dt = '';
    if (createdAt.isNotEmpty) {
      try { final d = DateTime.parse(createdAt); dt = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; } catch (_) { dt = createdAt.substring(0, 10); }
    }
    final driverName = order['driverName'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.3), offset: const Offset(3,3), blurRadius: 8),
            BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-3,-3), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: statusColor)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(catName, style: const TextStyle(fontSize: 11, fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(CupertinoIcons.person_fill, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(userName, style: TextStyle(fontSize: 13, fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: const Color(0xFF2D2A3A))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.clock, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dt, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade600)),
                const Spacer(),
                Text('$itemCount منتجات', style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (driverName.isNotEmpty) ...[
                  Icon(CupertinoIcons.car_fill, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(driverName, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade600)),
                  const Spacer(),
                ] else
                  const Spacer(),
                Text('${catTotal.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF00897B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════  تفاصيل الطلبية (المنتجات فقط)  ═══════════════════
class _OrderDetailSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final String storeId;
  final String ownerId;
  const _OrderDetailSheet({required this.order, required this.storeId, required this.ownerId});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final items = (widget.order['_catItems'] as List<dynamic>?) ?? [];
    final userName = widget.order['userName'] as String? ?? 'زبون';
    final catName = widget.order['_catName'] as String? ?? 'قسم';
    final catTotal = (widget.order['_catTotal'] as num? ?? 0).toDouble();
    final driverName = widget.order['driverName'] as String? ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0EEF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7D29C6), Color(0xFF5B0094)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(CupertinoIcons.bag_fill, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
                        Text(catName, style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: _kPrimary)),
                      ],
                    ),
                  ),
                  Text('${catTotal.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF00897B))),
                ],
              ),
            ),
            if (driverName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.car_fill, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(driverName, style: TextStyle(fontSize: 10, fontFamily: 'Amiri', color: Colors.grey.shade600)),
                  ],
                ),
              ),
            const Divider(height: 16, indent: 20, endIndent: 20),
            Expanded(
              child: ListView.separated(
                controller: scrollCtl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = items[i] as Map<String, dynamic>;
                    
                    // منطق المنتج الأصلي
                    final String name = item['name'] as String? ?? 'منتج';
                    final double price = (item['price'] ?? item['prix'] ?? 0).toDouble();
                    
                    // منطق المنتج البديل
                    final bool isReplaced = (item['alternativeStatus'] as String? ?? '') == 'accepted';
                    final String altName = item['alternativeName'] as String? ?? 'منتج بديل';
                    final double altPrice = ((item['alternativePrice'] as num?) ?? 0).toDouble();

                    final qty = (item['quantity'] ?? 1) is int ? (item['quantity'] as int) : (item['quantity'] as num).toInt();
                    final note = item['note'] as String? ?? '';
                    final image = item['image'] as String? ?? '';
                    final storeName = item['storeName'] as String? ?? '';
                    final capacite = item['capacite'] as String? ?? '';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.2), offset: const Offset(2,2), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // اسم المنتج الأصلي (مع خط في حال الاستبدال)
                          Text(
                            name,
                            style: TextStyle(
                              decoration: isReplaced ? TextDecoration.lineThrough : null,
                              color: isReplaced ? Colors.grey : const Color(0xFF2D2A3A),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                              fontSize: 14,
                            ),
                          ),
                          
                          // عرض المنتج البديل في حال تم الاستبدال
                          if (isReplaced) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(altName, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 13)),
                                  Text('${altPrice.toStringAsFixed(0)} دج', style: const TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        if (image.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: double.infinity,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _kPrimary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: _kPrimary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kPrimary))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
                                  if (storeName.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _kPrimary.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(storeName, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', fontWeight: FontWeight.w500, color: _kPrimary)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${price.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Amiri', color: Color(0xFF00897B))),
                          ],
                        ),
                        if (capacite.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(capacite, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.amber.shade800)),
                          ),
                        ],
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.doc_text, size: 14, color: Colors.blue.shade400),
                                const SizedBox(width: 4),
                                Expanded(child: Text(note, style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: Colors.blue.shade700))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
