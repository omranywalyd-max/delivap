import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'Services/api_client.dart';

const Color _kPrimary = Color(0xFF5B0094);
const Color _kBg = Color(0xFFE8E6F0);

class StoreAccountsScreen extends StatelessWidget {
  final String templateId;
  final String templateName;
  final int uiStyle;
  final Color storeColor;
  final String? imagePath;

  const StoreAccountsScreen({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.uiStyle,
    required this.storeColor,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(templateName, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      ),
      body: _StoreAccountsBody(
        templateId: templateId,
        uiStyle: uiStyle,
        storeColor: storeColor,
      ),
    );
  }
}

class _StoreAccountsBody extends StatefulWidget {
  final String templateId;
  final int uiStyle;
  final Color storeColor;
  const _StoreAccountsBody({required this.templateId, required this.uiStyle, required this.storeColor});

  @override
  State<_StoreAccountsBody> createState() => _StoreAccountsBodyState();
}

class _StoreAccountsBodyState extends State<_StoreAccountsBody> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ApiClient.getList('/api/stores');
      final filtered = all.where((s) {
        final ownerId = s['ownerId'] as String? ?? '';
        final tid = s['templateId'] as String? ?? '';
        return ownerId.isNotEmpty && tid == widget.templateId;
      }).toList();
      if (mounted) setState(() { _stores = filtered.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    if (_stores.isEmpty) return const Center(child: Text('لا توجد متاجر في هذا التصنيف', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey, fontSize: 15)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stores.length,
      itemBuilder: (_, i) => _StoreAccountCard(
        store: _stores[i],
        storeColor: widget.storeColor,
        onTap: () => _showStoreSheet(_stores[i]),
      ),
    );
  }

  void _showStoreSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreSettlementSheet(store: store),
    );
  }
}

class _StoreAccountCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final Color storeColor;
  final VoidCallback onTap;
  const _StoreAccountCard({required this.store, required this.storeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (store['nom'] as String? ?? '').trim();
    final cash = (store['cash'] as num? ?? 0).toDouble();
    final pct = (store['commissionPercent'] as num? ?? 0).toDouble();
    final pending = pct > 0 ? cash * pct / 100 : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: storeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.store_rounded, color: storeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name.isEmpty ? 'متجر' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
                  ),
                  Icon(CupertinoIcons.chevron_left, size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _chip('${cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', const Color(0xFF00897B))),
                  Expanded(child: _chip('${pct.toStringAsFixed(0)}%', 'نسبة الخصم', Colors.amber.shade700)),
                  Expanded(child: _chip('${pending.toStringAsFixed(0)} دج', 'المبلغ المخصوم', Colors.red.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );
}

class _StoreSettlementSheet extends StatefulWidget {
  final Map<String, dynamic> store;
  const _StoreSettlementSheet({required this.store});

  @override
  State<_StoreSettlementSheet> createState() => _StoreSettlementSheetState();
}

class _StoreSettlementSheetState extends State<_StoreSettlementSheet> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _confirming = false;

  Map<String, dynamic> get s => widget.store;
  double get _cash => (s['cash'] as num? ?? 0).toDouble();
  double get _pct => (s['commissionPercent'] as num? ?? 0).toDouble();
  double get _pending => _pct > 0 ? _cash * _pct / 100 : 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/admin/store-settlements/${s['_id']}');
      _list = data.cast<Map<String, dynamic>>();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _collect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد استلام الأموال', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Text('هل تأكد استلام ${_pending.toStringAsFixed(0)} دج من هذا المتجر؟', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
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
      await ApiClient.post('/api/admin/store-settlements', {
        'storeId': s['_id'],
        'amountCollected': _pending,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تسجيل الاستلام', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.green,
        ));
      }
      if (mounted) {
        setState(() { s['cash'] = 0; s['lastCommissionResetEarnings'] = (s['totalEarnings'] ?? 0).toDouble(); });
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtl) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('${s['nom'] ?? ''}', style: const TextStyle(fontSize: 14, fontFamily: 'Amiri', color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('كشف الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: _kPrimary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: _sumCell('${_cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', const Color(0xFF00897B))),
                    Expanded(child: _sumCell('${_pct.toStringAsFixed(0)}%', 'نسبة الخصم', Colors.amber.shade700)),
                    Expanded(child: _sumCell('${_pending.toStringAsFixed(0)} دج', 'المبلغ المخصوم', Colors.red.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_pending > 0)
                _confirming
                    ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)))
                    : GestureDetector(
                        onTap: _collect,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('استلام', textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Amiri', fontSize: 14)),
                        ),
                      ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_list.isEmpty)
                const Expanded(child: Center(child: Text('لا توجد تسجيلات بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey))))
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtl,
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s2 = _list[i];
                      final createdAt = s2['createdAt'] ?? '';
                      String dt = '';
                      if (createdAt is String) {
                        try { final d2 = DateTime.parse(createdAt); dt = '${d2.year}/${d2.month.toString().padLeft(2,'0')}/${d2.day.toString().padLeft(2,'0')} ${d2.hour.toString().padLeft(2,'0')}:${d2.minute.toString().padLeft(2,'0')}'; } catch (_) { dt = createdAt.substring(0, 16); }
                      }
                      final before = (s2['earningsBefore'] ?? 0).toDouble();
                      final after = (s2['earningsAfter'] ?? 0).toDouble();
                      final commAmt = (s2['commissionAmount'] ?? 0).toDouble();
                      final collected = (s2['amountCollected'] ?? 0).toDouble();
                      final cpct = (s2['commissionPercent'] ?? 0).toDouble();
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(dt, style: const TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey)),
                                  const Spacer(),
                                  Text('-${collected.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red, fontFamily: 'Amiri')),
                                ],
                              ),
                              const Divider(),
                              _row('الرصيد قبل', '${before.toStringAsFixed(0)} دج'),
                              _row('الرصيد بعد', '${after.toStringAsFixed(0)} دج'),
                              _row('نسبة العمولة', '$cpct%'),
                              _row('قيمة العمولة', '${commAmt.toStringAsFixed(0)} دج'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumCell(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color, fontFamily: 'Amiri')),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
        Text(value, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
