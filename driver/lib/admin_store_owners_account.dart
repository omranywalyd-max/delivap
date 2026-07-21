import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';

const Color _kBg = Color(0xFFE8E6F0);
const Color _kPrimary = Color(0xFF5B0094);
const Color _kTextGrey = Color(0xFF8A8A9A);

// ══════════════════════════════════════════════════════════════════════════════
//  الشاشة الرئيسية — قائمة الستايلات (template stores)
// ══════════════════════════════════════════════════════════════════════════════
class AdminStoreOwnersAccount extends StatefulWidget {
  const AdminStoreOwnersAccount({super.key});
  @override
  State<AdminStoreOwnersAccount> createState() => _AdminStoreOwnersAccountState();
}

class _AdminStoreOwnersAccountState extends State<AdminStoreOwnersAccount> {
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _ownerStores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stores = await ApiClient.getList('/api/stores');
      final all = stores.cast<Map<String, dynamic>>();
      if (mounted) setState(() {
        _templates = all.where((s) {
          final oid = s['ownerId'] as String? ?? '';
          return oid.isEmpty;
        }).toList();
        _ownerStores = all.where((s) {
          final oid = s['ownerId'] as String? ?? '';
          return oid.isNotEmpty;
        }).toList();
        for (final tpl in _templates) {
          final tid = tpl['_id'] as String?;
          if (tid == null) continue;
          final tplPct = (tpl['commissionPercent'] as num? ?? 0).toDouble();
          for (final store in _ownerStores) {
            if ((store['templateId'] as String? ?? '') != tid) continue;
            final storePct = (store['commissionPercent'] as num? ?? 0).toDouble();
            if (storePct == 0) store['commissionPercent'] = tplPct;
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('حسابات المحلات', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('لا توجد ستايلات', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _templates.length,
                  itemBuilder: (_, i) => _TemplateCard(
                    template: _templates[i],
                    count: _ownerStores.where((s) => (s['templateId'] ?? '') == (_templates[i]['_id'] ?? '')).length,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _StoresInStyleScreen(
                        styleName: '${_templates[i]['nom'] ?? ''}',
                        stores: _ownerStores.where((s) => (s['templateId'] ?? '') == (_templates[i]['_id'] ?? '')).toList(),
                        templateId: '${_templates[i]['_id'] ?? ''}',
                      ),
                    )),
                  ),
                ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final int count;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.count, required this.onTap});

  Color _color(int uiStyle) {
    const colors = [0xFFE53935, 0xFFFF8F00, 0xFF7B1FA2, 0xFF43A047, 0xFF00ACC1, 0xFF5C6BC0, 0xFFEF5350, 0xFF26A69A];
    return Color(colors[(uiStyle - 1) % colors.length]);
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = template['uiStyle'] ?? 1;
    final color = _color(uiStyle as int);
    final image = template['image'] as String? ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: ClipOval(
                child: image.isNotEmpty
                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.contain, memCacheWidth: 120)
                    : Icon(CupertinoIcons.building_2_fill, color: color, size: 28),
              ),
            ),
            const SizedBox(height: 10),
            Text('${template['nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('$count محلات', style: TextStyle(fontSize: 11, color: color, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  الشاشة الثانية — تصنيفات ستايل معين
// ══════════════════════════════════════════════════════════════════════════════
class _StoresInStyleScreen extends StatefulWidget {
  final String styleName;
  final List<Map<String, dynamic>> stores;
  final String templateId;
  const _StoresInStyleScreen({required this.styleName, required this.stores, required this.templateId});

  @override
  State<_StoresInStyleScreen> createState() => _StoresInStyleScreenState();
}

class _StoresInStyleScreenState extends State<_StoresInStyleScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/categories?templateId=${widget.templateId}');
      if (mounted) {
        final list = data.cast<Map<String, dynamic>>();
        list.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo(((b['order'] as num?) ?? 0)));
        setState(() { _categories = list; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _storeForCategory(Map<String, dynamic> cat) {
    final storeId = cat['storeId'] as String? ?? '';
    if (storeId.isEmpty) return null;
    try {
      return widget.stores.firstWhere((s) => s['_id'] == storeId);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get _items {
    final result = <Map<String, dynamic>>[];
    for (final cat in _categories) {
      final store = _storeForCategory(cat);
      if (store != null) {
        result.add({...cat, '_storeData': store});
      }
    }
    return result;
  }

  Future<void> _moveCategory(int oldIndex, int newIndex) async {
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    setState(() {});
    final orders = <Map<String, dynamic>>[];
    for (int i = 0; i < _categories.length; i++) {
      _categories[i]['order'] = i;
      orders.add({'id': _categories[i]['_id'], 'order': i});
    }
    try {
      await ApiClient.put('/api/categories/reorder', {'orders': orders});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final totalSum = widget.stores.fold<double>(0, (sum, s) => sum + ((s['totalEarnings'] as num? ?? 0).toDouble()));
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(widget.styleName, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('لا توجد تصنيفات', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.93,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _CategoryStoreCard(
                    item: items[i],
                    totalSum: totalSum,
                    canMoveUp: i > 0,
                    canMoveDown: i < items.length - 1,
                    onMoveUp: () => _moveCategory(i, i - 1),
                    onMoveDown: () => _moveCategory(i, i + 1),
                    onChanged: _load,
                  ),
                ),
    );
  }
}
// ══════════════════════════════════════════════════════════════════════════════
//  كارت التصنيف + المحل
// ══════════════════════════════════════════════════════════════════════════════

class _CategoryStoreCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final double totalSum;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onChanged;
  const _CategoryStoreCard({required this.item, required this.totalSum, this.canMoveUp = false, this.canMoveDown = false, this.onMoveUp, this.onMoveDown, this.onChanged});
  @override
  State<_CategoryStoreCard> createState() => _CategoryStoreCardState();
}

class _CategoryStoreCardState extends State<_CategoryStoreCard> {
  Color _color(int uiStyle) {
    const colors = [0xFFE53935, 0xFFFF8F00, 0xFF7B1FA2, 0xFF43A047, 0xFF00ACC1, 0xFF5C6BC0, 0xFFEF5350, 0xFF26A69A];
    return Color(colors[(uiStyle - 1) % colors.length]);
  }

  void _editCommission() {
    final store = widget.item['_storeData'] as Map<String, dynamic>? ?? {};
    final catPct = (widget.item['commissionPercent'] as num?)?.toDouble();
    final storePct = (store['commissionPercent'] as num? ?? 0).toDouble();
    final defaultPct = catPct != null ? catPct : storePct;
    final ctrl = TextEditingController(text: defaultPct.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE8E6F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل نسبة الخصم', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'نسبة الخصم (%)',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF5B0094)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B0094), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              try {
                final id = widget.item['_id'];
                await ApiClient.put('/api/categories/$id', {'commissionPercent': val, 'updatedAt': DateTime.now().toIso8601String()});
                if (mounted) {
                  widget.item['commissionPercent'] = val;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التعديل', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.red));
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white, fontFamily: 'Amiri')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catName = '${widget.item['nom'] ?? ''}'.trim();
    final catImage = widget.item['image'] as String? ?? '';
    final store = widget.item['_storeData'] as Map<String, dynamic>? ?? {};
    final cash = (widget.item['cash'] as num? ?? 0).toDouble();
    final catPct = (widget.item['commissionPercent'] as num?)?.toDouble();
    final storePct = (store['commissionPercent'] as num? ?? 0).toDouble();
    final pct = catPct != null ? catPct : storePct;
    final isCustom = catPct != null;
    final totalEarnings = (widget.item['totalEarnings'] ?? 0).toDouble();
    final deducted = pct > 0 ? cash * pct / 100 : 0;
    final uiStyle = (store['uiStyle'] as int?) ?? 1;
    final col = _color(uiStyle);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, _pageRoute(_CategoryDetailPage(
          category: widget.item,
          store: store,
        )));
        widget.onChanged?.call();
      },
      onLongPress: _editCommission,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.canMoveUp || widget.canMoveDown)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.canMoveUp)
                    GestureDetector(
                      onTap: widget.onMoveUp,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.keyboard_arrow_up, size: 16, color: _kPrimary),
                      ),
                    ),
                  const SizedBox(width: 6),
                  if (widget.canMoveDown)
                    GestureDetector(
                      onTap: widget.onMoveDown,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.keyboard_arrow_down, size: 16, color: _kPrimary),
                      ),
                    ),
                ],
              ),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: col.withOpacity(0.1),
                border: Border.all(color: col.withOpacity(0.3), width: 2),
              ),
              child: ClipOval(
                child: catImage.isNotEmpty
                    ? CachedNetworkImage(imageUrl: catImage, fit: BoxFit.contain, memCacheWidth: 120)
                    : Icon(CupertinoIcons.bag_fill, color: col, size: 28),
              ),
            ),
            const SizedBox(height: 10),
            Text(catName.isEmpty ? 'تصنيف' : catName,
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: col.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('الإجمالي:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                    Text('${totalEarnings.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 11, color: col, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('الحالي:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                    Text('${cash.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 11, color: const Color(0xFF00897B), fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('نسبة الخصم:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                    Text('$pct%', style: TextStyle(fontSize: 11, color: isCustom ? _kPrimary : col, fontFamily: 'Amiri', fontWeight: isCustom ? FontWeight.bold : FontWeight.normal)),
                  ]),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('يُخصم:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                    Text('${deducted.toStringAsFixed(0)} دج', style: const TextStyle(fontSize: 11, color: Color(0xFFE53E6A), fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                  builder: (_) => CategoryStatementSheet(category: widget.item));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(CupertinoIcons.doc_text, color: _kPrimary, size: 14),
                  const SizedBox(width: 6),
                  Text('كشف', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 12)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route _pageRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, c) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: a, child: c)),
  transitionDuration: const Duration(milliseconds: 300));



// ══════════════════════════════════════════════════════════════════════════════
//  صفحة تفاصيل القسم (المبلغ + استلام + كشف)
// ══════════════════════════════════════════════════════════════════════════════
class _CategoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> category;
  final Map<String, dynamic> store;
  const _CategoryDetailPage({required this.category, required this.store});

  @override
  State<_CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<_CategoryDetailPage> {
  late Map<String, dynamic> cat;
  bool _confirming = false;

  double get _cash => (cat['cash'] as num? ?? 0).toDouble();
  double get _totalEarnings => (cat['totalEarnings'] as num? ?? 0).toDouble();
  double get _catPct => (cat['commissionPercent'] as num?)?.toDouble() ?? 0;
  double get _storePct => (widget.store['commissionPercent'] as num? ?? 0).toDouble();
  double get _percent => _catPct > 0 ? _catPct : _storePct;
  double get _pendingCommission => _percent > 0 ? _cash * _percent / 100 : 0;

  @override
  void initState() {
    super.initState();
    cat = Map<String, dynamic>.from(widget.category);
  }

  Future<void> _collect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد استلام الأموال', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Text('هل تأكد استلام ${_pendingCommission.toStringAsFixed(0)} دج من قسم "${cat['nom'] ?? ''}"؟', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: _kPrimary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الاستلام', style: TextStyle(color: Colors.white, fontFamily: 'Amiri')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _confirming = true);
    try {
      final res = await ApiClient.post('/api/admin/category-settlements', {
        'categoryId': cat['_id'],
        'storeId': cat['storeId'],
        'amountCollected': _pendingCommission,
      });
      if (res.isEmpty) throw Exception('فشل حفظ الاستلام في السيرفر');
      final fresh = await ApiClient.get('/api/categories/${cat['_id']}');
      if (fresh.isNotEmpty) {
        cat = fresh;
      } else {
        cat['cash'] = 0;
        cat['lastCommissionResetEarnings'] = _totalEarnings;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاستلام', style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.green));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${cat['nom'] ?? ''}'.trim();
    final image = cat['image'] as String? ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(name.isEmpty ? 'قسم' : name, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_pendingCommission > 0)
            _confirming
                ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : TextButton.icon(
                    onPressed: _collect,
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                    label: const Text('استلام', style: TextStyle(color: Colors.white, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(image, width: double.infinity, height: 180, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: double.infinity, height: 120, color: _kPrimary.withOpacity(0.06), child: const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 40))),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _neuCard('${_cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', CupertinoIcons.money_dollar_circle_fill, const Color(0xFF00897B))),
            const SizedBox(width: 10),
            Expanded(child: _neuCard('${_totalEarnings.toStringAsFixed(0)} دج', 'الإجمالي', CupertinoIcons.chart_bar_fill, const Color(0xFF5B0094))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _neuCard('${_percent.toStringAsFixed(0)}%', 'نسبة الخصم', CupertinoIcons.percent, const Color(0xFFFF8F00))),
            const SizedBox(width: 10),
            Expanded(child: _neuCard('${_pendingCommission.toStringAsFixed(0)} دج', 'المبلغ المحصّل', CupertinoIcons.checkmark_seal_fill, const Color(0xFF43A047))),
          ]),
          const SizedBox(height: 20),
          // كشف الحساب
        ],
      ),
    );
  }

  Widget _neuCard(String value, String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.2), offset: const Offset(3,3), blurRadius: 8),
        BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-3,-3), blurRadius: 8),
      ],
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Amiri', color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, fontFamily: 'Amiri', color: Colors.grey.shade500)),
    ]),
  );

}

// ══════════════════════════════════════════════════════════════════════════════
//  كشف حساب القسم
// ══════════════════════════════════════════════════════════════════════════════
class CategoryStatementSheet extends StatefulWidget {
  final Map<String, dynamic> category;
  const CategoryStatementSheet({required this.category});

  @override
  State<CategoryStatementSheet> createState() => _CategoryStatementSheetState();
}

class _CategoryStatementSheetState extends State<CategoryStatementSheet> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  double _totalCollected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storeId = widget.category['storeId'] ?? '';
      final data = await ApiClient.getList('/api/admin/store-settlements/$storeId');
      _list = data.cast<Map<String, dynamic>>().where((s) => s['targetType'] == 'category' && s['targetName'] == (widget.category['nom'] ?? '')).toList();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      _totalCollected = _list.fold<double>(0, (s, e) => s + ((e['amountCollected'] ?? 0).toDouble()));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.35, maxChildSize: 0.9, expand: false,
      builder: (ctx, scrollCtl) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF0EEF5), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: [
            Text('كشف حساب "${widget.category['nom'] ?? ''}"', style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D2A3A))),
            const Spacer(),
            Text('المحصّل: ${_totalCollected.toStringAsFixed(0)} دج', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade700)),
          ])),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B0094)))
            : _list.isEmpty
              ? Center(child: Text('لا توجد عمليات استلام بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey.shade500)))
              : ListView.builder(controller: scrollCtl, padding: const EdgeInsets.all(16), itemCount: _list.length, itemBuilder: (_, i) {
                  final s = _list[i];
                  final amount = (s['amountCollected'] ?? 0).toDouble();
                  final pct = (s['commissionPercent'] ?? 0).toDouble();
                  final earningsBefore = (s['earningsBefore'] ?? 0).toDouble();
                  final earningsAfter = (s['earningsAfter'] ?? 0).toDouble();
                  String date = '';
                  try { final d = DateTime.parse(s['createdAt'] ?? ''); date = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; } catch (_) {}
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.15), offset: const Offset(2,2), blurRadius: 5)]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text('-${amount.toStringAsFixed(0)} دج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade700, fontFamily: 'Amiri'))),
                        const Spacer(),
                        Text(date, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 6),
                      _detailRow('النسبة', '$pct%'),
                      _detailRow('الأرباح قبل', '${earningsBefore.toStringAsFixed(0)} دج'),
                      _detailRow('الأرباح بعد', '${earningsAfter.toStringAsFixed(0)} دج'),
                    ]),
                  );
                })),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(value, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade700)),
      const SizedBox(width: 6),
      Text('$label:', style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade500)),
    ]),
  );
}


