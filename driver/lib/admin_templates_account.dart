import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dashbord/services/api_client.dart';

const Color _kBg = Color(0xFFE8E6F0);
const Color _kPrimary = Color(0xFF5B0094);

class AdminTemplatesAccount extends StatefulWidget {
  const AdminTemplatesAccount({super.key});
  @override
  State<AdminTemplatesAccount> createState() => _AdminTemplatesAccountState();
}

class _AdminTemplatesAccountState extends State<AdminTemplatesAccount> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stores = await ApiClient.getList('/api/admin/stores');
      stores.removeWhere((s) => s['ownerId'] != null);
      if (mounted) setState(() { _stores = stores.cast<Map<String, dynamic>>(); _loading = false; });
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
        title: const Text('حسابات الستايلات', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? const Center(child: Text('لا يوجد ستايلات', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stores.length,
                  itemBuilder: (_, i) => _StoreTemplateCard(store: _stores[i], onChanged: _load),
                ),
    );
  }
}

class _StoreTemplateCard extends StatefulWidget {
  final Map<String, dynamic> store;
  final VoidCallback onChanged;
  const _StoreTemplateCard({required this.store, required this.onChanged});

  @override
  State<_StoreTemplateCard> createState() => _StoreTemplateCardState();
}

class _StoreTemplateCardState extends State<_StoreTemplateCard> {
  bool _confirming = false;

  Map<String, dynamic> get s => widget.store;
  double get _totalEarnings => (s['totalEarnings'] ?? 0).toDouble();
  double get _cash => (s['cash'] as num? ?? 0).toDouble();
  double get _percent => (s['commissionPercent'] as num? ?? 0).toDouble();
  double get _pendingCommission => _cash * _percent / 100;

  Future<void> _collect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد استلام الأموال', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Text('هل تأكد استلام ${_pendingCommission.toInt()} دج من هذا الستايل؟', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
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
        'amountCollected': _pendingCommission,
        'targetType': 'template',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاستلام بنجاح', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.green));
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _showStatement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _TemplateStatementSheet(store: s, storeId: s['_id']),
    );
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(store: s, storeName: '${s['name'] ?? ''}'),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        final id = s['_id'];
        await ApiClient.deleteImageUrl(s['image'] ?? '');
        await ApiClient.delete('/api/admin/stores/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حذف الستايل بنجاح', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.green,
          ));
        }
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ في الحذف: $e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red,
          ));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = '${s['name'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showStatement,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                  child: const Text('كشف', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                ),
              ),
              const SizedBox(width: 6),
              if (_pendingCommission > 0)
                _confirming
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
                    : GestureDetector(
                        onTap: _collect,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.3))),
                          child: const Text('استلام', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                        ),
                      ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _confirmDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: const Text('حذف', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                ),
              ),
              const Spacer(),
              Text(name.isEmpty ? 'ستايل' : name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D2A3A), fontFamily: 'Amiri')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoChip('${_totalEarnings.toInt()} دج', 'الإجمالي', const Color(0xFF5B0094))),
              Expanded(child: _infoChip('${_cash.toInt()} دج', 'الموجود', Colors.blue.shade700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _infoChip('${_percent.toInt()}%', 'نسبة الخصم', Colors.amber.shade700)),
              Expanded(child: _infoChip('${_pendingCommission.toInt()} دج', 'الأرباح المستحقة', Colors.green.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );
}

class _TemplateStatementSheet extends StatefulWidget {
  final Map<String, dynamic> store;
  final String? storeId;
  const _TemplateStatementSheet({required this.store, required this.storeId});

  @override
  State<_TemplateStatementSheet> createState() => _TemplateStatementSheetState();
}

class _TemplateStatementSheetState extends State<_TemplateStatementSheet> {
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
      final data = await ApiClient.getList('/api/admin/store-settlements/${widget.storeId}');
      final list = data.cast<Map<String, dynamic>>();
      list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      _totalCollected = list.fold<double>(0, (s, e) => s + ((e['amountCollected'] ?? 0).toDouble()));
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.store;
    final cash = (st['cash'] as num? ?? 0).toDouble();
    final pct = (st['commissionPercent'] as num? ?? 0).toDouble();
    final pending = cash * pct / 100;
    final totalEarnings = (st['totalEarnings'] as num? ?? 0).toDouble();
    final name = '${st['nom'] ?? ''}'.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7D29C6), Color(0xFF5B0094)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0xFFB8B1C8), offset: Offset(3,3), blurRadius: 8), BoxShadow(color: Colors.white, offset: Offset(-2,-2), blurRadius: 6)],
                    ),
                    child: const Icon(CupertinoIcons.bag_fill, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name.isEmpty ? 'المحل' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
                  ),
                  const Text('كشف الحساب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: _kPrimary)),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _neuCard('${totalEarnings.toInt()} دج', 'الإجمالي', CupertinoIcons.money_dollar_circle_fill, const Color(0xFF5B0094))),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('${cash.toInt()} دج', 'الرصيد الحالي', CupertinoIcons.bag_fill, const Color(0xFF00897B))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _neuCard('${pct.toInt()}%', 'نسبة الخصم', CupertinoIcons.percent, Colors.amber.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('${pending.toInt()} دج', 'المستحق', CupertinoIcons.clock, Colors.red.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_totalCollected > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.checkmark_shield_fill, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text('إجمالي المسحوبات: ${_totalCollected.toInt()} دج', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF7D29C6))))
            else if (_list.isEmpty)
              Expanded(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.doc_text, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('لا توجد تسجيلات بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey.shade500, fontSize: 13)),
                ],
              )))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  controller: scrollCtl,
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = _list[i];
                    final createdAt = s['createdAt'] ?? '';
                    String dt = '';
                    if (createdAt is String) {
                      try { final d = DateTime.parse(createdAt); dt = '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; } catch (_) { dt = createdAt.substring(0, 16); }
                    }
                    final after = (s['earningsAfter'] ?? 0).toDouble();
                    final commAmt = (s['commissionAmount'] ?? 0).toDouble();
                    final collected = (s['amountCollected'] ?? 0).toDouble();
                    final cpct = (s['commissionPercent'] ?? 0).toDouble();
                    return Container(
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
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Icon(CupertinoIcons.clock, size: 14, color: Colors.blue.shade400),
                              ),
                              const SizedBox(width: 8),
                              Text(dt, style: TextStyle(fontSize: 12, fontFamily: 'Amiri', color: Colors.grey.shade600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('-${collected.toInt()} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red, fontFamily: 'Amiri')),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              _infoChip('الرصيد بعد', '${after.toInt()} دج', const Color(0xFF00897B)),
                              const SizedBox(width: 8),
                              _infoChip('نسبة الخصم', '${cpct.toInt()}%', Colors.amber.shade700),
                              const SizedBox(width: 8),
                              _infoChip('قيمة الخصم', '${commAmt.toInt()} دج', Colors.red.shade600),
                            ],
                          ),
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

  Widget _neuCard(String value, String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.25), offset: const Offset(3,3), blurRadius: 7),
        BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-3,-3), blurRadius: 7),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color, fontFamily: 'Amiri')),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontFamily: 'Amiri')),
      ],
    ),
  );

  Widget _infoChip(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
          Text(label, style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontFamily: 'Amiri')),
        ],
      ),
    ),
  );
}

class _DeleteConfirmDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final String storeName;
  const _DeleteConfirmDialog({required this.store, required this.storeName});

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  int _seconds = 5;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _seconds--;
        if (_seconds <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('تأكيد الحذف', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
      content: Text(
        'هل أنت متأكد من حذف "${widget.storeName}" نهائياً؟\n\nسيتم حذف جميع منتجاته وصوره.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Amiri', fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(color: _kPrimary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _seconds > 0 ? Colors.grey : Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _seconds > 0 ? null : () => Navigator.pop(context, true),
          child: Text(
            _seconds > 0 ? '$_seconds' : 'نعم، احذف',
            style: const TextStyle(color: Colors.white, fontFamily: 'Amiri'),
          ),
        ),
      ],
    );
  }
}
