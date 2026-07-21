// ════════════════════════════════════════════════════════════════════════════
//  admin_panel.dart
//  لوحة تحكم الأدمن الكاملة
//  تبويبات: تفعيل السائقين | تفعيل المحلات | حسابات المحلات | إدارة المحلات | الزبائن
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:dashbord/driver_active_orders.dart';
import 'package:dashbord/map_picker_screen.dart';
import 'package:dashbord/owner_products_manager.dart';
import 'package:dashbord/owner_project_orders.dart';
import 'package:dashbord/owner_project_deliveries.dart';
import 'package:dashbord/owner_store_orders.dart';
import 'package:dashbord/admin_store_owners_account.dart';
import 'package:dashbord/services/socket_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dashbord/services/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;

Future<String> _uploadImg(File file, String folder) async {
  try {
    return await ApiClient.upload(file);
  } catch (_) {
    return '';
  }
}

// ── ألوان محلية ──────────────────────────────────────────────────────────────
const Color _kBg = Color(0xFFE8E6F0);
const Color _kCard = Color(0xFFEEECF4);
const Color _kPrimary = Color(0xFF5B0094);
const Color _kShadow = Color(0xFFBEBEBE);

List<BoxShadow> _neu({double blur = 10, double offset = 4}) => [
  BoxShadow(
    color: _kShadow.withOpacity(0.65),
    blurRadius: blur,
    offset: Offset(offset, offset),
  ),
  const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-4, -4)),
];

// ══════════════════════════════════════════════════════════════════════════════
//  AdminDashboardMain — النافبار الرئيسي
// ══════════════════════════════════════════════════════════════════════════════
class AdminDashboardMain extends StatefulWidget {
  const AdminDashboardMain({super.key});
  @override
  State<AdminDashboardMain> createState() => _AdminDashboardMainState();
}

class _AdminDashboardMainState extends State<AdminDashboardMain> {
  int _idx = 0;
  int _reportCount = 0;

  final _pages = [
    _DriversActivationTab(),
    _StoresActivationTab(),
    const AdminStoreOwnersAccount(),
    _AdminStoresManagerTab(),
    _AdminCustomersTab(),
  ];

  @override
  void initState() {
    super.initState();
    _restoreToken();
    SocketClient().join('admin_room');
    SocketClient().on('new_report', (_) => _loadReportCount());
    _loadReportCount();
  }

  @override
  void dispose() {
    SocketClient().off('new_report');
    super.dispose();
  }

  Future<void> _loadReportCount() async {
    try {
      final r = await ApiClient.get('/api/admin/reports/count');
      if (mounted) setState(() => _reportCount = (r['count'] ?? 0) as int);
    } catch (_) {}
  }

  void _showReportsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdminReportsSheet(),
    );
  }

  Future<void> _restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('adminToken');
    if (token != null) ApiClient.setToken(token);
  }

  void _confirmLogout() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'تسجيل الخروج',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
      ),
      content: const Text(
        'هل تريد الخروج من لوحة التحكم؟',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Amiri'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء', style: TextStyle(color: _kPrimary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            ApiClient.setToken(null);
            await FirebaseAuth.instance.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            if (mounted) {
              Navigator.pop(ctx);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (r) => false);
            }
          },
          child: const Text(
            'خروج',
            style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
          ),
        ),
      ],
    ),
  );

  void _showAdminCleanupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدوات الصيانة', style: TextStyle(fontFamily: 'Amiri', fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _cleanupOption(ctx, 'حذف الطلبيات', 'يمسح كل الطلبيات بأنواعها', Icons.receipt_long, Colors.blue,
                '/api/admin/delete/orders', 'تم حذف الطلبيات',
              ),
              _cleanupOption(ctx, 'حذف الزبائن', 'يمسح كل حسابات الزبائن', Icons.people, Colors.indigo,
                '/api/admin/delete/customers', 'تم حذف الزبائن',
              ),
              _cleanupOption(ctx, 'حذف السائقين', 'يمسح كل حسابات السائقين', Icons.delivery_dining, Colors.teal,
                '/api/admin/delete/drivers', 'تم حذف السائقين',
              ),
              _cleanupOptionOrphan(ctx),
              const Divider(height: 24),
              _cleanupOption(ctx, 'حذف كل شيء', 'يمسح كل البيانات و الصور حرفياً', Icons.warning_amber_rounded, Colors.red,
                '/api/admin/delete/all', 'تم حذف كل شيء',
                isDanger: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cleanupOption(BuildContext ctx, String title, String subtitle, IconData icon, Color color, String endpoint, String doneMsg, {bool isDanger = false}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
      title: Text(title, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: isDanger ? Colors.red : null)),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Amiri', fontSize: 12)),
      onTap: () async {
        Navigator.pop(ctx);
        final confirm = await _confirmCleanup(context, title);
        if (confirm != true) return;
        final res = await ApiClient.post(endpoint, {});
        final deleted = res['deleted'] as int? ?? 0;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$doneMsg: $deleted', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.green,
          ));
        }
      },
    );
  }

  Widget _cleanupOptionOrphan(BuildContext ctx) {
    return FutureBuilder(
      future: ApiClient.get('/api/admin/orphan-images'),
      builder: (ctx2, snap) {
        final count = snap.data?['orphanCount'] as int? ?? 0;
        return ListTile(
          leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.15),
            child: Badge(
              isLabelVisible: count > 0,
              label: Text('$count', style: const TextStyle(fontSize: 10)),
              child: const Icon(Icons.image, color: Colors.orange),
            ),
          ),
          title: const Text('حذف الصور اليتيمة', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
          subtitle: Text(count == 0 ? 'لا توجد صور يتيمة' : 'عدد الصور اليتيمة: $count',
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 12)),
          onTap: () async {
            Navigator.pop(ctx);
            if (count == 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('لا توجد صور يتيمة للحذف', style: TextStyle(fontFamily: 'Amiri')),
                  backgroundColor: Colors.orange,
                ));
              }
              return;
            }
            final confirm = await _confirmCleanup(context, 'حذف الصور اليتيمة');
            if (confirm != true) return;
            final delRes = await ApiClient.delete('/api/admin/orphan-images');
            final deleted = delRes['deleted'] as int? ?? 0;
            final remaining = delRes['remaining'] as int? ?? 0;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('تم حذف $deleted صورة${remaining > 0 ? '، بقيت $remaining' : ''}',
                  style: const TextStyle(fontFamily: 'Amiri')),
                backgroundColor: deleted > 0 ? Colors.green : Colors.orange,
              ));
            }
          },
        );
      },
    );
  }

  Future<bool?> _confirmCleanup(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد؟ هذا الإجراء لا يمكن التراجع عنه!',
          textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: _kPrimary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontFamily: 'Amiri')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmLogout();
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'لوحة التحكم',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            // زر البلاغات مع عداد
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flag_rounded, color: Colors.white),
                    onPressed: () => _showReportsSheet(),
                    tooltip: 'البلاغات',
                  ),
                  if (_reportCount > 0)
                    Positioned(
                      right: 6,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_reportCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: _confirmLogout,
              onLongPress: _showAdminCleanupDialog,
              tooltip: 'خروج',
            ),
          ],
        ),
        body: _pages[_idx],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: _kBg,
            boxShadow: [
              BoxShadow(
                color: _kShadow.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _idx,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: _kPrimary,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 11,
            ),
            onTap: (i) => setState(() => _idx = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_badge_plus),
                label: 'السائقين',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.building_2_fill),
                label: 'المحلات',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.money_dollar_circle_fill),
                label: 'حسابات المحلات',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.settings),
                label: 'إدارة المحلات',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_2_fill),
                label: 'الزبائن',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  تبويب 1 — تفعيل السائقين الجدد
// ══════════════════════════════════════════════════════════════════════════════
class _DriversActivationTab extends StatefulWidget {
  const _DriversActivationTab();
  @override
  State<_DriversActivationTab> createState() => _DriversActivationTabState();
}

class _DriversActivationTabState extends State<_DriversActivationTab> {
  bool _showPending = true;
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic> _globalConfig = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getList('/api/drivers'),
        ApiClient.get('/api/config'),
      ]);
      if (!mounted) return;
      final list = (results[0] as List).cast<Map<String, dynamic>>();
      if (_showPending) {
        list.retainWhere((d) => d['isActive'] != true);
      }
      setState(() {
        _drivers = list;
        _globalConfig = results[1] is Map<String, dynamic>
            ? results[1] as Map<String, dynamic>
            : {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleFilter(bool pending) {
    setState(() => _showPending = pending);
    _loadDrivers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _kPrimary,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _tabToggleBtn(
                      'بانتظار التفعيل',
                      _showPending,
                      () => _toggleFilter(true),
                    ),
                    _tabToggleBtn(
                      'جميع السائقين',
                      !_showPending,
                      () => _toggleFilter(false),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final changed = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const _VehicleCommissionSheet(),
                        );
                        if (changed == true && mounted) _loadDrivers();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.car_detailed,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showCommissionOverview(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.money_dollar_circle_fill,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const FittedBox(
                      child: Text(
                        'السائقون',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _drivers.isEmpty
              ? _emptyState(
                  icon: CupertinoIcons.person_2,
                  msg: _showPending
                      ? 'لا يوجد سائقون بانتظار التفعيل'
                      : 'لا يوجد سائقون مسجلون',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drivers.length,
                  itemBuilder: (_, i) => _driverCard(_drivers[i]),
                ),
        ),
      ],
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final String id = d['_id'] ?? '';
    final bool isActive = d['isActive'] == true;
    final bool canSetPricing = d['canSetPricing'] == true;

    final String name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    final String city = d['cityName'] ?? 'غير محدد';
    final String phone = d['phone'] ?? '';
    final String email = d['email'] ?? '';
    final String vehicleType = (d['vehicleType'] as String? ?? '').replaceAll(' ', '_');
    final bool isMotorcycle = vehicleType == 'motorcycle';

    return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4),
            ),
            const BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4),
            ),
          ],
          border: isActive
              ? null
              : Border.all(color: _kPrimary.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // أيقونة الحذف
                  GestureDetector(
                    onTap: () => _confirmDelete(d, context, _loadDrivers),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.trash,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // بيانات السائق
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        name.isEmpty ? 'سائق جديد' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Amiri',
                          color: Color(0xFF2D2A3A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            city,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontFamily: 'Amiri',
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.location_solid,
                            size: 11,
                            color: _kPrimary,
                          ),
                        ],
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'Amiri',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // أفاتار
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kPrimary, _kPrimary.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.car_detailed,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  // زر منح التسعيرة - فقط لسائقي الدراجات النارية
                  if (isMotorcycle)
                    Expanded(
                      child: GestureDetector(
                      onTap: () {
                        final newCanSetPricing = !canSetPricing;
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _kBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(
                              newCanSetPricing ? 'منح صلاحية التسعيرة' : 'إلغاء صلاحية التسعيرة',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              newCanSetPricing
                                  ? 'هل تريد منح السائق صلاحية تحديد التسعيرة؟'
                                  : 'هل تريد إلغاء صلاحية تحديد التسعيرة من السائق؟',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Amiri'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: newCanSetPricing ? Colors.green : Colors.orange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  newCanSetPricing ? 'نعم، منح' : 'نعم، إلغاء',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Amiri'),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  final r = await ApiClient.put('/api/admin/drivers/$id', {
                                    'canSetPricing': newCanSetPricing,
                                  });
                                  if (r.containsKey('error')) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(r['error'], style: const TextStyle(fontFamily: 'Amiri')),
                                        backgroundColor: Colors.red.shade700,
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    }
                                    return;
                                  }
                                  _loadDrivers();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          // يتبدل اللون حسب الحالة (أخضر إذا منحت، أمبر إذا لم تمنح)
                          color: canSetPricing
                              ? Colors.green.withOpacity(0.12)
                              : Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canSetPricing
                                ? Colors.green
                                : Colors.amber.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canSetPricing
                                  ? CupertinoIcons.checkmark_shield_fill
                                  : CupertinoIcons.money_dollar_circle,
                              color: canSetPricing
                                  ? Colors.green
                                  : Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              canSetPricing
                                  ? 'تم منح التسعيرة'
                                  : 'منح التسعيرة',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 12,
                                color: canSetPricing
                                    ? Colors.green
                                    : Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isMotorcycle) const SizedBox(width: 10),
                  // زر التفعيل / الإلغاء
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final newIsActive = !isActive;
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: _kBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(
                              newIsActive ? 'تفعيل السائق' : 'تعطيل السائق',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              newIsActive
                                  ? 'هل تريد تفعيل هذا السائق؟'
                                  : 'هل تريد تعطيل هذا السائق؟',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Amiri'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: newIsActive ? Colors.green : Colors.orange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  newIsActive ? 'نعم، تفعيل' : 'نعم، تعطيل',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Amiri'),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await ApiClient.put('/api/admin/drivers/$id', {
                                    'isActive': newIsActive,
                                  });
                                  _loadDrivers();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.orange.withOpacity(0.12)
                              : Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive
                                  ? CupertinoIcons.xmark_circle
                                  : CupertinoIcons.checkmark_circle,
                              color: isActive ? Colors.orange : Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive ? 'إلغاء التفعيل' : 'تفعيل الحساب',
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 12,
                                color: isActive ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _earningsRow(d, _globalConfig),
              const SizedBox(height: 8),
              _photoUploadToggle(d, id, isActive),
            ],
          ),
        ),
      );
  }

  Widget _photoUploadToggle(Map<String, dynamic> d, String id, bool isActive) {
    final canUpload = d['canUploadPhoto'] == true;
    return GestureDetector(
      onTap: isActive
          ? () {
              final newCanUpload = !canUpload;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _kBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    newCanUpload ? 'منح صلاحية رفع الصور' : 'إلغاء صلاحية رفع الصور',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    newCanUpload
                        ? 'هل تريد منح السائق صلاحية رفع الصور؟'
                        : 'هل تريد إلغاء صلاحية رفع الصور من السائق؟',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Amiri'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: newCanUpload ? Colors.green : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        newCanUpload ? 'نعم، منح' : 'نعم، إلغاء',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Amiri'),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final r = await ApiClient.put('/api/admin/drivers/$id', {
                            'canUploadPhoto': newCanUpload,
                          });
                          if (r.containsKey('error')) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(r['error'], style: const TextStyle(fontFamily: 'Amiri')),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                            return;
                          }
                          _loadDrivers();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                newCanUpload ? '✅ تم تفعيل تغيير الصورة' : '✅ تم إلغاء صلاحية تغيير الصورة',
                                style: const TextStyle(fontFamily: 'Amiri'),
                              ),
                              backgroundColor: newCanUpload ? Colors.green.shade700 : Colors.orange.shade700,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: canUpload
              ? Colors.green.withOpacity(0.12)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canUpload ? Colors.green : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canUpload ? Icons.check_circle : Icons.add_a_photo,
              color: canUpload ? Colors.green : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              canUpload ? 'تغيير الصورة مفعل' : 'تفعيل تغيير الصورة',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 12,
                color: canUpload ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _earningsRow(Map<String, dynamic> d, Map<String, dynamic> globalConfig) {
  final totalEarnings = (d['totalEarnings'] ?? 0).toDouble();
  final p = (d['commissionPercent'] as num? ?? 0).toDouble();
  final percent = p > 0
      ? p
      : () {
          final vType = (d['vehicleType'] as String? ?? '').replaceAll(
            ' ',
            '_',
          );
          final key = 'commission_$vType';
          return (globalConfig[key] as num? ??
                  globalConfig['defaultCommissionPercent'] as num? ??
                  0)
              .toDouble();
        }();
  final cash = (d['cash'] as num? ?? 0).toDouble();
  final pending = cash * percent / 100;
  return Row(
    children: [
      Expanded(
        child: _miniChip(
          '${((d['cash'] as num? ?? 0).toDouble()).toStringAsFixed(0)} دج',
          'الموجود',
          const Color(0xFF00897B),
        ),
      ),
      Expanded(
        child: _miniChip(
          '${percent.toStringAsFixed(0)}%',
          'نسبة الخصم',
          Colors.amber.shade700,
        ),
      ),
      Expanded(
        child: _miniChip(
          '${pending.toStringAsFixed(0)} دج',
          'المستحق',
          pending > 0 ? Colors.green.shade700 : Colors.grey,
        ),
      ),
    ],
  );
}

Widget _miniChip(String value, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: color,
            fontFamily: 'Amiri',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    ),
  );
}

void _showPricingSheet(Map<String, dynamic> d, BuildContext context) {
  final Map<String, dynamic> currentPricing = Map<String, dynamic>.from(
    d['pricing'] ?? {},
  );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _PricingSheet(driverData: d, currentPricing: currentPricing),
  );
}

void _confirmDelete(Map<String, dynamic> d, BuildContext context, VoidCallback loadDrivers) => showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: _kBg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text(
      'حذف السائق',
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
    ),
    content: const Text(
      'هل تريد حذف هذا السائق نهائياً؟',
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Amiri'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('إلغاء'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'نعم، احذف',
          style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
        ),
        onPressed: () async {
          try {
            await ApiClient.delete('/api/admin/drivers/${d['_id']}');
            if (context.mounted) {
              Navigator.pop(ctx);
              loadDrivers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم حذف السائق بنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Amiri'),
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل الحذف: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      
        
      ),
    ],
  ),
);

Widget _tabToggleBtn(String label, bool active, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: active ? _kPrimary : Colors.white.withOpacity(0.8),
          ),
        ),
      ),
    );

void _showCommissionOverview(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CommissionOverviewSheet(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── ورقة منح التسعيرة للسائق ────────────────────────────────────────────────
class _PricingSheet extends StatefulWidget {
  final Map<String, dynamic> driverData;
  final Map<String, dynamic> currentPricing;
  const _PricingSheet({required this.driverData, required this.currentPricing});
  @override
  State<_PricingSheet> createState() => _PricingSheetState();
}

class _PricingSheetState extends State<_PricingSheet> {
  final _baseCtrl = TextEditingController();
  final _perKmCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _baseCtrl.text = (widget.currentPricing['baseFare'] ?? '').toString();
    _perKmCtrl.text = (widget.currentPricing['perKm'] ?? '').toString();
    _minCtrl.text = (widget.currentPricing['minFare'] ?? '').toString();
    _commissionCtrl.text = (widget.driverData['commissionPercent'] ?? '')
        .toString();
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _perKmCtrl.dispose();
    _minCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await ApiClient.put('/api/admin/drivers/${widget.driverData['_id']}', {
      'pricing': {
        'baseFare': double.tryParse(_baseCtrl.text) ?? 0,
        'perKm': double.tryParse(_perKmCtrl.text) ?? 0,
        'minFare': double.tryParse(_minCtrl.text) ?? 0,
      },
      'hasSetPricing': true,
      'commissionPercent': double.tryParse(_commissionCtrl.text) ?? 0,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driverData;
    final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'إعداد التسعيرة — $name',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: Color(0xFF2D2A3A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'مدينة: ${d['cityName'] ?? 'غير محدد'}',
            style: const TextStyle(
              fontSize: 13,
              color: _kPrimary,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 22),
          _pField(
            _baseCtrl,
            'الأجرة الأساسية (دج)',
            CupertinoIcons.money_dollar,
          ),
          const SizedBox(height: 14),
          _pField(_perKmCtrl, 'السعر لكل كيلومتر (دج)', CupertinoIcons.map),
          const SizedBox(height: 14),
          _pField(
            _minCtrl,
            'الحد الأدنى للأجرة (دج)',
            CupertinoIcons.arrow_down_circle,
          ),
          const SizedBox(height: 14),
          _pField(_commissionCtrl, 'نسبة الخصم (%)', CupertinoIcons.percent),
          const SizedBox(height: 26),
          _loading
              ? const CircularProgressIndicator(color: _kPrimary)
              : GestureDetector(
                  onTap: _save,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4A0080),
                          _kPrimary,
                          Color(0xFF9C27B0),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'حفظ التسعيرة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _pField(TextEditingController c, String h, IconData icon) => Container(
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _neu(blur: 8, offset: 3),
    ),
    child: TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      style: const TextStyle(fontFamily: 'Amiri', color: Color(0xFF2D2A3A)),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontFamily: 'Amiri',
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _kPrimary, size: 19),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  تبويب 2 — تفعيل أصحاب المحلات الجدد
// ══════════════════════════════════════════════════════════════════════════════
class _StoresActivationTab extends StatefulWidget {
  const _StoresActivationTab();
  @override
  State<_StoresActivationTab> createState() => _StoresActivationTabState();
}

class _StoresActivationTabState extends State<_StoresActivationTab> {
  bool _showPending = true;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      // 1. جلب البيانات الخام من السيرفر
      final list = await ApiClient.getList('/api/users');

      // 2. هاد السطر هو المهم: اطبع البيانات باش نشوفوها في الكونسول
      debugPrint("-----------------------------------------");
      debugPrint("DEBUG: RAW USERS DATA: $list");
      debugPrint("-----------------------------------------");

      if (!mounted) return;

      // 3. التصفية (Filter)
      final filtered = list.where((u) {
        // نزيدو برينت هنا باش نشوفو كل مستخدم واش هو الـ role تاعه
        debugPrint(
          "User: ${u['username']}, Role: ${u['role']}, Active: ${u['isActive']}",
        );

        final bool isOwner =
            u['role'] == 'owner'; // لازم نتأكد أن الـ role راه يجي 'owner'
        final active = u['isActive'] == true;
        return isOwner && (_showPending ? !active : active);
      }).toList();

      setState(() {
        _users = filtered.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint("DEBUG ERROR: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleFilter(bool pending) {
    setState(() => _showPending = pending);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _kPrimary,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _toggleBtn(
                      'بانتظار التفعيل',
                      _showPending,
                      () => _toggleFilter(true),
                    ),
                    _toggleBtn(
                      'المفعّلون',
                      !_showPending,
                      () => _toggleFilter(false),
                    ),
                  ],
                ),
              ),
              const Text(
                'أصحاب المحلات',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : _users.isEmpty
              ? _emptyState(
                  icon: CupertinoIcons.building_2_fill,
                  msg: _showPending
                      ? 'لا يوجد طلبات انضمام جديدة'
                      : 'لا يوجد مستخدمون مفعّلون',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _ownerCard(_users[i]),
                ),
        ),
      ],
    );
  }

  Widget _ownerCard(Map<String, dynamic> d) {
    final String id = d['_id'] ?? '';
    final bool isActive = d['isActive'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: isActive ? null : Border.all(color: _kPrimary.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // زر التفعيل/إلغاء
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _kBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      isActive ? 'إلغاء تفعيل التاجر' : 'تفعيل التاجر',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      isActive
                          ? 'هل أنت متأكد من إلغاء تفعيل هذا التاجر؟'
                          : 'هل أنت متأكد من تفعيل هذا التاجر؟ سيتم إنشاء محل جديد إذا لم يكن لديه محل.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء',
                            style: TextStyle(fontFamily: 'Amiri')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          isActive ? 'إلغاء التفعيل' : 'تفعيل',
                          style: TextStyle(
                              fontFamily: 'Amiri',
                              color: isActive ? Colors.orange : Colors.green),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  // إظهار لودينج
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  if (isActive) {
                    // 🛑 إلغاء التفعيل: نرجع الحالة false فقط
                    await ApiClient.put('/api/users/$id', {'isActive': false});
                  } else {
                    // ✅ التفعيل الذكي:
                    final userDetail = await ApiClient.get('/api/users/$id');
                    final currentIdInUser = userDetail['magasinId'];

                    // نتحقق إذا كان المحل الحالي هو "قالب" (Template) أو "محل حقيقي"
                    final storeInfo = await ApiClient.get(
                      '/api/stores/$currentIdInUser',
                    );

                    if (storeInfo['ownerId'] == null ||
                        storeInfo['ownerId'] == "") {
                      // 1. إنشاء محل جديد خاص بهذا التاجر من القالب
                      final newStore = await ApiClient.post('/api/admin/stores', {
                        'nom': d['storeName'] ?? 'محل جديد',
                        'image': storeInfo['image'] ?? '',
                        'primaryColor': storeInfo['primaryColor'] ?? '#5B0094',
                        'uiStyle': storeInfo['uiStyle'] ?? 1,
                        'showDistance': storeInfo['showDistance'] ?? false,
                        'stylePizza': storeInfo['stylePizza'] ?? false,
                        'allowMultipleCategories':
                            storeInfo['allowMultipleCategories'] ?? false,
                        'ownerId': id,
                        'templateId': currentIdInUser,
                        'nm': storeInfo['nm'] ?? 1,
                        'commissionPercent': storeInfo['commissionPercent'] ?? 0,
                      });

                      // 2. ربط التاجر بالمحل الجديد وتفعيله
                      await ApiClient.put('/api/users/$id', {
                        'isActive': true,
                        'magasinId': newStore['_id'],
                      });
                    } else {
                      // المحل موجود أصلاً، فقط نفعل الحساب
                      await ApiClient.put('/api/users/$id', {'isActive': true});
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context); // إغلاق اللودينج
                    _loadUsers(); // تحديث القائمة
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? Colors.orange : Colors.green,
                  ),
                ),
                child: Text(
                  isActive ? 'إلغاء' : 'تفعيل',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.orange : Colors.green,
                  ),
                ),
              ),
            ),
            // زر الحذف
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _kBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'تأكيد الحذف',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Amiri'),
                    ),
                    content: const Text(
                      'هل أنت متأكد من حذف هذا المحل مع جميع منتجاته وصوره؟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Amiri', fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء',
                            style: TextStyle(fontFamily: 'Amiri')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف',
                            style: TextStyle(
                                fontFamily: 'Amiri', color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final storeId = d['magasinId'] as String? ?? '';
                  if (storeId.isNotEmpty) {
                    // حذف صورة المحل
                    final storeInfo =
                        await ApiClient.get('/api/stores/$storeId');
                    await ApiClient.deleteImageUrl(
                        storeInfo['image'] ?? '');

                    // حذف الأقسام مع صورها
                    final cats =
                        await ApiClient.getList(
                            '/api/categories?storeId=$storeId');
                    for (final cat in cats) {
                      final c = cat as Map<String, dynamic>;
                      await ApiClient.deleteImageUrl(c['image'] ?? '');
                      await ApiClient.delete(
                          '/api/categories/${c['_id']}');
                    }

                    // حذف المنتجات مع صورها
                    final products =
                        await ApiClient.getList(
                            '/api/products?storeId=$storeId');
                    for (final prod in products) {
                      final p = prod as Map<String, dynamic>;
                      await ApiClient.deleteImageUrl(p['image'] ?? '');
                      if (p['extraImages'] is List) {
                        await ApiClient.deleteImageUrls(
                            List<String>.from(p['extraImages']));
                      }
                      await ApiClient.delete(
                          '/api/products/${p['_id']}');
                    }

                    // حذف المشروبات مع صورها
                    final drinks =
                        await ApiClient.getList(
                            '/api/drinks?storeId=$storeId');
                    for (final drk in drinks) {
                      final d2 = drk as Map<String, dynamic>;
                      await ApiClient.deleteImageUrl(d2['image'] ?? '');
                      await ApiClient.delete(
                          '/api/drinks/${d2['_id']}');
                    }

                    // حذف المشاريع مع صورها
                    final projects =
                        await ApiClient.getList(
                            '/api/projects?storeId=$storeId');
                    for (final proj in projects) {
                      final p2 = proj as Map<String, dynamic>;
                      await ApiClient.deleteImageUrl(
                          p2['imageUrl'] ?? '');
                      if (p2['extraImages'] is List) {
                        await ApiClient.deleteImageUrls(
                            List<String>.from(p2['extraImages']));
                      }
                      await ApiClient.delete(
                          '/api/projects/${p2['_id']}');
                    }

                    // حذف المحل
                    await ApiClient.delete(
                        '/api/admin/stores/$storeId');
                  }

                  // حذف صورة المستخدم والحساب
                  await ApiClient.deleteImageUrl(
                      d['photoUrl'] ?? '');
                  await ApiClient.delete('/api/users/$id');

                  if (mounted) Navigator.pop(context);
                  _loadUsers();
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("خطأ في الحذف: $e")));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Spacer(),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'مفعّل' : 'بانتظار',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 10,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      d['username'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Amiri',
                        color: Color(0xFF2D2A3A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  d['storeName'] ?? 'بدون اسم محل',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kPrimary,
                    fontFamily: 'Amiri',
                  ),
                ),
                Text(
                  d['phone'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_kPrimary, _kPrimary.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? _kPrimary : Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  تبويب 3 — إدارة المحلات (إضافة / تعديل / حذف)
// ══════════════════════════════════════════════════════════════════════════════
class _AdminStoresManagerTab extends StatefulWidget {
  const _AdminStoresManagerTab();
  @override
  State<_AdminStoresManagerTab> createState() => _AdminStoresManagerTabState();
}

class _AdminStoresManagerTabState extends State<_AdminStoresManagerTab> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);
    try {
      final all = await ApiClient.getList('/api/stores');
      if (!mounted) return;
      setState(() {
        _stores = all.cast<Map<String, dynamic>>().where((s) {
          final ownerId = s['ownerId'] as String? ?? '';
          return ownerId.isEmpty;
        }).toList();
        _stores.sort(
          (a, b) => ((a['nm'] ?? 0) as num).compareTo((b['nm'] ?? 0) as num),
        );
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        onPressed: () => _openSheet(context).then((_) => _loadStores()),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'إضافة محل',
          style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _stores.isEmpty
          ? _emptyState(
              icon: CupertinoIcons.building_2_fill,
              msg: 'لا يوجد محلات مضافة',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _stores.length,
              itemBuilder: (_, i) => _storeCard(_stores[i]),
            ),
    );
  }

  Widget _storeCard(Map<String, dynamic> d) {
    final String id = d['_id'] ?? '';
    Color storeCol;
    try {
      storeCol = Color(
        int.parse((d['primaryColor'] as String).replaceAll('#', '0xFF')),
      );
    } catch (_) {
      storeCol = _kPrimary;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(4, 4),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _openSheet(context, doc: d).then((_) => _loadStores()),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: storeCol.withOpacity(0.15),
            border: Border.all(color: storeCol.withOpacity(0.4)),
          ),
          child: (d['image'] ?? '').isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: CachedNetworkImage(
                    memCacheWidth: 150,
                    imageUrl: d['image'],
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(CupertinoIcons.building_2_fill, color: storeCol, size: 24),
        ),
        title: Text(
          d['nom'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          'Style ${d['uiStyle']} • ترتيب ${d['nm']}',
          style: const TextStyle(fontSize: 11, fontFamily: 'Amiri'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () =>
                  _openSheet(context, doc: d).then((_) => _loadStores()),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.pencil,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _kBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'حذف المحل',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'هل أنت متأكد من حذف هذا المحل نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Amiri', fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('حذف',
                            style: TextStyle(fontFamily: 'Amiri', color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await ApiClient.deleteImageUrl(d['image'] ?? '');
                await ApiClient.delete('/api/admin/stores/$id');
                _loadStores();
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(
    BuildContext context, {
    Map<String, dynamic>? doc,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoreEditorSheet(doc: doc),
    );
  }
}

// ── ورقة إضافة/تعديل المحل ───────────────────────────────────────────────────
class _StoreEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? doc;
  const _StoreEditorSheet({this.doc});
  @override
  State<_StoreEditorSheet> createState() => _StoreEditorSheetState();
}

class _StoreEditorSheetState extends State<_StoreEditorSheet> {
  final _nomCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  int _selectedUI = 1;
  bool _stylePizza = false;
  bool _allowMultiple = false;
  bool _showDistance = false;
  Color _pickerColor = _kPrimary;
  File? _imgFile;
  String _existingImg = '';
  bool _loading = false;

  List<String> labels = [
    'سوبرماركت',
    'مطعم',
    'باتيسري',
    'خضر وفواكه',
    'كوسميتيك',
    'مشاريع',
    'صيديلة',
    'منتجات صور',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nomCtrl.text = d['nom'] ?? '';
      _orderCtrl.text = d['nm']?.toString() ?? '1';
      _selectedUI = d['uiStyle'] ?? 1;
      _stylePizza = d['stylePizza'] ?? false;
      _allowMultiple = d['allowMultipleCategories'] ?? false;
      _showDistance = d['showDistance'] ?? false;
      _commissionCtrl.text = (d['commissionPercent'] ?? '').toString();
      _existingImg = d['image'] ?? '';
      try {
        _pickerColor = Color(
          int.parse((d['primaryColor'] as String).replaceAll('#', '0xFF')),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _orderCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _pickColor() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'اختر لون المحل',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
      ),
      content: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children:
            [
                  Colors.red,
                  Colors.pink,
                  Colors.purple,
                  Colors.deepPurple,
                  Colors.indigo,
                  Colors.blue,
                  Colors.lightBlue,
                  Colors.cyan,
                  Colors.teal,
                  Colors.green,
                  Colors.lightGreen,
                  Colors.lime,
                  Colors.amber,
                  Colors.orange,
                  Colors.deepOrange,
                  Colors.brown,
                  Colors.grey,
                  Colors.blueGrey,
                  const Color(0xFF5B0094),
                  Colors.black,
                ]
                .map(
                  (c) => GestureDetector(
                    onTap: () {
                      setState(() => _pickerColor = c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _pickerColor == c
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    ),
  );

  Future<void> _save() async {
    if (_nomCtrl.text.isEmpty || _orderCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    String url = _existingImg;
    if (_imgFile != null) {
      url = await _uploadImg(_imgFile!, 'magasins');
      if (url.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل رفع الصورة', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _loading = false);
        return;
      }
    }
    final data = {
      'nom': _nomCtrl.text.trim(),
      'nm': int.tryParse(_orderCtrl.text.trim()) ?? 1,
      'uiStyle': _selectedUI,
      'stylePizza': _stylePizza,
      'allowMultipleCategories': _allowMultiple,
      'showDistance': _showDistance,
      'commissionPercent': double.tryParse(_commissionCtrl.text.trim()) ?? 0,
      'primaryColor':
          '#${_pickerColor.value.toRadixString(16).substring(2).toUpperCase()}',
      'image': url,
      'ownerId': null,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    try {
      if (widget.doc == null) {
        await ApiClient.post('/api/admin/stores', {
          ...data,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await ApiClient.put('/api/admin/stores/${widget.doc!['_id']}', data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ المحل: $e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _loading = false);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 22,
        right: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.doc == null ? 'إضافة محل جديد' : 'تعديل المحل',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                color: Color(0xFF2D2A3A),
              ),
            ),
            const SizedBox(height: 20),

            // صورة المحل
            GestureDetector(
              onTap: () async {
                final p = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (p != null) setState(() => _imgFile = File(p.path));
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _pickerColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _pickerColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _imgFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.file(_imgFile!, fit: BoxFit.cover),
                      )
                    : (_existingImg.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: CachedNetworkImage(
                                memCacheWidth: 150,
                                imageUrl: _existingImg,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.add_circled,
                              size: 32,
                              color: Colors.grey,
                            )),
              ),
            ),
            const SizedBox(height: 20),

            _field(_nomCtrl, 'اسم المحل', CupertinoIcons.building_2_fill),
            const SizedBox(height: 12),
            _field(
              _orderCtrl,
              'الترتيب (رقم)',
              CupertinoIcons.sort_up,
              isNum: true,
            ),
            const SizedBox(height: 18),

            // ستايل العرض
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'ستايل عرض المحل',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2D2A3A),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // استعمل GridView مباشرة بلا Row
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3, // يخرجولك 3 في كل سطر
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1, // باش يجي المربع متناسق
              children: [1, 2, 3, 4, 5, 6, 7, 8].map((n) {
                final selected = _selectedUI == n;
                return GestureDetector(
                  onTap: () => setState(() => _selectedUI = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? _pickerColor : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _pickerColor : Colors.grey.shade300,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _pickerColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$n',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          labels[n - 1],
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 10,
                            color: selected
                                ? Colors.white70
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // اللون
            GestureDetector(
              onTap: _pickColor,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _pickerColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                    ),
                    const Text(
                      'لون هوية المحل',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14,
                        color: Color(0xFF2D2A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              title: const Text(
                'نظام البيتزا',
                style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
              ),
              value: _stylePizza,
              activeColor: _pickerColor,
              onChanged: (v) => setState(() => _stylePizza = v),
            ),
            SwitchListTile(
              title: const Text(
                'السماح بتعدد الأقسام',
                style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
              ),
              value: _allowMultiple,
              activeColor: _pickerColor,
              onChanged: (v) => setState(() => _allowMultiple = v),
            ),
            SwitchListTile(
              title: const Text(
                'إظهار المسافة للزبون',
                style: TextStyle(fontFamily: 'Amiri', fontSize: 13),
              ),
              value: _showDistance,
              activeColor: _pickerColor,
              onChanged: (v) => setState(() => _showDistance = v),
            ),

            const SizedBox(height: 16),
            _field(
              _commissionCtrl,
              'نسبة الخصم (%)',
              CupertinoIcons.percent,
              isNum: true,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator(color: _kPrimary)
                : GestureDetector(
                    onTap: _save,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _pickerColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _pickerColor.withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'حفظ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String h,
    IconData icon, {
    bool isNum = false,
  }) => Container(
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: _neu(blur: 8, offset: 3),
    ),
    child: TextField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      textAlign: TextAlign.right,
      style: const TextStyle(fontFamily: 'Amiri', color: Color(0xFF2D2A3A)),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: const TextStyle(
          color: Colors.grey,
          fontFamily: 'Amiri',
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _pickerColor, size: 19),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    ),
  );
}

// ── ويدجت الحالة الفارغة ─────────────────────────────────────────────────────
Widget _emptyState({required IconData icon, required String msg}) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: _kBg,
          shape: BoxShape.circle,
          boxShadow: _neu(blur: 14, offset: 6),
        ),
        child: Icon(icon, size: 50, color: Colors.grey.shade400),
      ),
      const SizedBox(height: 22),
      Text(
        msg,
        style: const TextStyle(
          fontFamily: 'Amiri',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D2A3A),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'ستظهر البيانات هنا عند الإضافة',
        style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Colors.grey),
      ),
    ],
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
//  لوحة تحكم صاحب المحل (OwnerDashboard)
//  تُستورد من هذا الملف أو من driver_app.dart — الكود هنا مكتفٍ بذاته
// ══════════════════════════════════════════════════════════════════════════════
class OwnerDashboard extends StatefulWidget {
  final Map<String, dynamic> ownerData;
  const OwnerDashboard({super.key, required this.ownerData});
  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  Map<String, dynamic> _storeData = {};
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  bool _orphansFixAttempted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initFcm();
    final ownerId = widget.ownerData['uid'] as String?;
    if (ownerId != null) {
      SocketClient().join('user_$ownerId');
      SocketClient().on('order:created', _onOwnerOrderCreated);
    }
  }

  void _onOwnerOrderCreated(_) {
    _loadData();
  }

  Future<void> _initFcm() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final ownerId = widget.ownerData['uid'] as String?;
        final ownerDbId = widget.ownerData['_id'] as String?;
        if (ownerId != null) {
          await ApiClient.post('/api/notify-token', {
            'uid': ownerId,
            'fcmToken': fcmToken,
            'role': 'owner',
          });
        }
        if (ownerDbId != null && ownerDbId != ownerId) {
          await ApiClient.post('/api/notify-token', {
            'uid': ownerDbId,
            'fcmToken': fcmToken,
            'role': 'owner',
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    final ownerId = widget.ownerData['uid'] as String?;
    if (ownerId != null) {
      SocketClient().off('order:created', _onOwnerOrderCreated);
      SocketClient().leave('user_$ownerId');
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final storeId = widget.ownerData['magasinId'] ?? '';
      final ownerId = widget.ownerData['uid'] as String? ?? '';
      final storeFuture = ApiClient.get('/api/stores/$storeId');
      final catsFuture = ApiClient.getList('/api/categories?storeId=$storeId&ownerId=$ownerId');
      final results = await Future.wait([storeFuture, catsFuture]);
      if (!mounted) return;
      final storeData = results[0] as Map<String, dynamic>;
      final storePct = (storeData['commissionPercent'] as num? ?? 0).toDouble();
      if (storePct == 0) {
        final tid = storeData['templateId'] as String?;
        if (tid != null && tid.isNotEmpty) {
          try {
            final tpl = await ApiClient.get('/api/stores/$tid');
            final tplPct = (tpl['commissionPercent'] as num? ?? 0).toDouble();
            storeData['commissionPercent'] = tplPct;
          } catch (_) {}
        }
      }
      final cats = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() {
        _storeData = storeData;
        _categories = cats;
        _loading = false;
      });
      // إصلاح تلقائي مرة واحدة فقط للأقسام القديمة (ownerId: null)
      if (!_orphansFixAttempted && storeId.isNotEmpty && ownerId.isNotEmpty && cats.isEmpty) {
        _orphansFixAttempted = true;
        try {
          final fixResult = await ApiClient.post('/api/categories/fix-orphans', {
            'storeId': storeId,
            'ownerId': ownerId,
          });
          if ((fixResult['fixed'] ?? 0) > 0 && mounted) {
            // إعادة تحميل بدون fix-orphans مرة أخرى
            final freshCats = await ApiClient.getList('/api/categories?storeId=$storeId&ownerId=$ownerId');
            if (mounted) setState(() => _categories = freshCats.cast<Map<String, dynamic>>());
          }
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "تسجيل الخروج",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "هل تريد تسجيل الخروج من لوحة التحكم؟",
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(color: _kPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              ApiClient.setToken(null);
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(ctx);
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (r) => false);
            },
            child: const Text("خروج", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCatSheet(String storeId, Map<String, dynamic>? doc) async {
    final ownerId = widget.ownerData['uid'] as String?;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryEditorSheet(
        storeId: storeId,
        doc: doc,
        nextOrder: _categories.length,
        ownerId: ownerId,
      ),
    );
  }

  Widget _buildBottomAddButton(String storeId) {
    // ✅ التعديل هنا: زدنا .then((_) => _loadData())
    return GestureDetector(
      onTap: () => _showCatSheet(storeId, null).then((_) => _loadData()),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E24AA), Color(0xFF5B0094)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B0094).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.plus_circle_fill,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              "إضافة قسم لمحلّك",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _neuBox({required Widget child, EdgeInsets? padding}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0xFFB8B1C8),
          offset: Offset(4, 4),
          blurRadius: 10,
        ),
        BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 10),
      ],
    ),
    child: child,
  );

  Widget _buildFinCard(String storeId) {
    final cash = (_storeData['cash'] as num? ?? 0).toDouble();
    final pct = (_storeData['commissionPercent'] as num? ?? 0).toDouble();
    final pendingComm = cash * pct / 100;
    final total = (_storeData['totalEarnings'] as num? ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB8B1C8), offset: Offset(4,4), blurRadius: 10),
          BoxShadow(color: Colors.white, offset: Offset(-4,-4), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF5B0094).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(CupertinoIcons.money_dollar_circle_fill, color: Color(0xFF5B0094), size: 20),
              ),
              const Spacer(),
              Text('المالية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _chip('${cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', const Color(0xFF00897B))),
            Expanded(child: _chip('$pct%', 'نسبة الخصم', Colors.amber.shade700)),
            Expanded(child: _chip('${pendingComm.toStringAsFixed(0)} دج', 'المبلغ لي يتخصم', Colors.red.shade600)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _chip('${total.toStringAsFixed(0)} دج', 'الإجمالي', const Color(0xFF5B0094))),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerStatementPage(storeId: storeId, storeData: _storeData),
                  ),
                );
              },
              icon: const Icon(CupertinoIcons.doc_text, color: Color(0xFF5B0094), size: 16),
              label: const Text('كشف الحساب', style: TextStyle(fontFamily: 'Amiri', color: Color(0xFF5B0094), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );

  Future<void> _collectOwnerCash(String storeId, double cash, double pendingComm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد استلام الأموال', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Text('هل تأكد استلام $pendingComm دج؟', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 13)),
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
    try {
      await ApiClient.post('/api/admin/store-settlements', {
        'storeId': storeId,
        'amountCollected': pendingComm,
      });
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاستلام', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Amiri')), backgroundColor: Colors.red));
    }
  }

  void _showStatementSheet(String storeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _OwnerStatementSheet(storeId: storeId, storeData: _storeData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String storeId = widget.ownerData['magasinId'] ?? '';
    final Color storeColor = Color(
      int.parse(
        (_storeData['primaryColor'] ?? '#5B0094').replaceAll('#', '0xFF'),
      ),
    );
    final bool isPizza = _storeData['stylePizza'] ?? false;
    final bool allowMultiple = _storeData['allowMultipleCategories'] ?? false;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _storeData['nom'] ?? 'لوحة التحكم',
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
            color: _kPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (allowMultiple || _categories.isEmpty)
          ? _buildBottomAddButton(storeId)
          : null,
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                if (isPizza || _storeData['uiStyle'] == 3)
                  _actionBtn(
                    'المشروبات',
                    Icons.local_drink,
                    storeColor,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerDrinksPage(storeId: storeId),
                      ),
                    ),
                  ),
                _actionBtn(
                  'المفضلات',
                  Icons.favorite_border,
                  storeColor,
                  () => _showFavoritesManagerSheet(storeId),
                ),
                _actionBtn(
                  'إدارة العروض',
                  Icons.local_offer,
                  storeColor,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerOffersPage(
                        storeId: storeId,
                        storeName: _storeData['nom'] ?? '',
                      ),
                    ),
                  ),
                ),
                if ((_storeData['uiStyle'] ?? 1) != 6)
                  _actionBtn(
                    'طلبياتي',
                    CupertinoIcons.doc_text,
                    storeColor,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerStoreOrdersPage(
                          storeId: storeId,
                          storeName: _storeData['nom'] ?? '',
                          ownerId: widget.ownerData['uid'] as String? ?? '',
                        ),
                      ),
                    ),
                  ),
                if ((_storeData['uiStyle'] ?? 1) == 6) ...[
                  _actionBtn(
                    'طلبات المشاريع',
                    CupertinoIcons.doc_text,
                    storeColor,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerProjectOrdersPage(
                          storeId: storeId,
                          storeName: _storeData['nom'] ?? '',
                          ownerId: widget.ownerData['uid'] as String? ?? '',
                        ),
                      ),
                    ),
                  ),

                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "أقسام المحل",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'Amiri',
              ),
            ),
          ),
          Expanded(
            child: _categories.isEmpty
                ? _emptyState(
                    icon: CupertinoIcons.square_list,
                    msg: "لا توجد أقسام مضافة بعد",
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      var cat = _categories[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OwnerProductsPage(
                              storeId: storeId,
                              catId: cat['_id'],
                              catName: cat['nom'],
                              isPizza: isPizza,
                              uiStyle: _storeData['uiStyle'] ?? 1,
                            ),
                          ),
                        ),
                        child: _neuBox(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: cat['image'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat['nom'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showCatSheet(
                                      storeId,
                                      cat,
                                    ).then((_) => _loadData()),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: _kBg,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          title: const Text(
                                            'حذف القسم',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
                                          ),
                                          content: const Text(
                                            'هل أنت متأكد من حذف هذا القسم وجميع منتجاته؟',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontFamily: 'Amiri', fontSize: 14),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('حذف',
                                                  style: TextStyle(fontFamily: 'Amiri', color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true) return;
                                      await ApiClient.deleteImageUrl(cat['image'] ?? '');
                                      await ApiClient.delete(
                                        '/api/categories/${cat['_id']}',
                                      );
                                      _loadData();
                                    },
                                ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFavoritesManagerSheet(String storeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FavoritesManagerSheet(storeId: storeId),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _neu(blur: 8, offset: 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Amiri',
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── ورقة إضافة/تعديل قسم ─────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
//  3. إضافة القسم (الكارد) - نسخة "إظهار الموقع حسب إعدادات المحل"
// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
//  إضافة القسم (الكارد) - النسخة النهائية المصححة والموحدة
// ══════════════════════════════════════════════════════════════════════════════
class CategoryEditorSheet extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? doc;
  final int nextOrder;
  final String? ownerId;
  const CategoryEditorSheet({super.key, required this.storeId, this.doc, this.nextOrder = 0, this.ownerId});

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  final _nameCtrl = TextEditingController();
  File? _imgFile;
  String _existingImg = "";
  bool _loading = false;

  String _address = "تحديد الموقع من الخريطة";
  double? _lat, _lng;

  bool _showDistance = false;
  String? _templateId;

  @override
  void initState() {
    super.initState();
    _loadStore();
    if (widget.doc != null) {
      final d = widget.doc!;
      _nameCtrl.text = d['nom'] ?? '';
      _existingImg = d['image'] ?? '';
      _address = d['address'] ?? "تحديد الموقع من الخريطة";
      _lat = d['lat'];
      _lng = d['lng'];
    }
  }

  Future<void> _loadStore() async {
    try {
      final store = await ApiClient.get('/api/stores/${widget.storeId}');
      if (!mounted) return;
      setState(() {
        _showDistance = store['showDistance'] ?? false;
        _templateId = store['templateId'];
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(
          "تنبيه",
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            msg,
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "حسناً",
              style: TextStyle(fontFamily: 'Amiri', color: _kPrimary),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_nameCtrl.text.trim().isEmpty) {
      _showError("يرجى إدخال اسم القسم أولاً");
      return;
    }
    if (_imgFile == null && _existingImg == "") {
      _showError("يرجى اختيار صورة للقسم");
      return;
    }
    if (_showDistance) {
      if (_lat == null || _lng == null || _address.contains("تحديد الموقع")) {
        _showError("تحديد الموقع على الخريطة إلزامي لهذا المحل");
        return;
      }
    }
    setState(() => _loading = true);
    try {
      String url = _existingImg;
      if (_imgFile != null) url = await _uploadImg(_imgFile!, 'categories');

      final data = {
        'nom': _nameCtrl.text.trim(),
        'image': url,
        'storeId': widget.storeId,
        'templateId': _templateId,
        'updatedAt': DateTime.now().toIso8601String(),
        'ownerId': widget.ownerId ?? FirebaseAuth.instance.currentUser?.uid,
        if (_showDistance) 'address': _address,
        if (_showDistance) 'lat': _lat,
        if (_showDistance) 'lng': _lng,
      };

      if (widget.doc == null) {
        final created = await ApiClient.post('/api/categories', {
          ...data,
          'order': widget.nextOrder,
          'createdAt': DateTime.now().toIso8601String(),
        });
        final newId = created['_id'];
        if (newId != null) {
          await ApiClient.put('/api/categories/$newId', {'categorieId': newId});
        }
      } else {
        await ApiClient.put('/api/categories/${widget.doc!['_id']}', data);
      }
      Navigator.pop(context);
    } catch (_) {
      _showError("حدث خطأ أثناء الحفظ، حاول مجدداً");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _localNeuBox({required Widget child, EdgeInsets? padding}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 10,
              offset: Offset(4, 4),
            ),
            const BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4),
            ),
          ],
        ),
        child: child,
      );

  Widget _localNeuButton(String txt, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: _neu(),
        ),
        child: Center(
          child: Text(
            txt,
            style: const TextStyle(
              color: _kPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
            ),
          ),
        ),
      ),
    ),
  );

  Widget _localInputBox(TextEditingController c, String h) => Container(
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(15),
      boxShadow: _neu(),
    ),
    child: TextField(
      controller: c,
      textAlign: TextAlign.right,
      style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
      decoration: InputDecoration(
        hintText: h,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(15),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 25,
        right: 25,
        bottom: MediaQuery.of(context).viewInsets.bottom + 30,
      ),
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              widget.doc == null ? "إضافة كارد جديد" : "تعديل الكارد",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamily: 'Amiri',
              ),
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: () async {
                final p = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (p != null) setState(() => _imgFile = File(p.path));
              },
              child: _localNeuBox(
                padding: const EdgeInsets.all(5),
                child: SizedBox(
                  height: 90,
                  width: 90,
                  child: _imgFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_imgFile!, fit: BoxFit.cover),
                        )
                      : (_existingImg != ""
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: CachedNetworkImage(
                                  memCacheWidth: 150,
                                  imageUrl: _existingImg,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo,
                                color: _kPrimary,
                                size: 30,
                              )),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _localInputBox(_nameCtrl, "اسم الكارد"),
            const SizedBox(height: 15),
            if (_showDistance) ...[
              GestureDetector(
                onTap: () async {
                  final res = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                  );
                  if (res != null) {
                    String rawAddr = res['address'] ?? "";
                    if (rawAddr.contains('،') || rawAddr.contains(',')) {
                      String sep = rawAddr.contains('،') ? '،' : ',';
                      rawAddr = rawAddr.split(sep).first.trim();
                    }
                    setState(() {
                      _address = rawAddr;
                      _lat = res['lat'];
                      _lng = res['lng'];
                    });
                  }
                },
                child: _localNeuBox(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _address,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Amiri',
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
            const SizedBox(height: 15),
            _loading
                ? const CircularProgressIndicator()
                : _localNeuButton("حفظ البيانات", _save),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  لوحة أرباح الإدارة من السائقين
// ══════════════════════════════════════════════════════════════════════════════
//  لوحة أرباح الإدارة من السائقين
// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
//  _VehicleCommissionSheet — إدارة نسب العمولة حسب نوع المركبة
// ══════════════════════════════════════════════════════════════════════════════
class _VehicleCommissionSheet extends StatefulWidget {
  const _VehicleCommissionSheet();
  @override
  State<_VehicleCommissionSheet> createState() =>
      _VehicleCommissionSheetState();
}

class _VehicleCommissionSheetState extends State<_VehicleCommissionSheet> {
  final List<String> _vehicleTypes = ['motorcycle', 'car', 'minibus', 'truck'];
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final v in _vehicleTypes) {
      _controllers[v] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.get('/api/config');
      if (!mounted) return;
      for (final v in _vehicleTypes) {
        final key = 'commission_${v.replaceAll(' ', '_')}';
        final val = (data[key] ?? data['defaultCommissionPercent'] ?? 0)
            .toDouble();
        _controllers[v]!.text = val.toStringAsFixed(0);
      }
    } catch (_) {}
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{};
      for (final v in _vehicleTypes) {
        final key = 'commission_${v.replaceAll(' ', '_')}';
        update[key] = double.tryParse(_controllers[v]!.text.trim()) ?? 0;
      }
      await ApiClient.put('/api/admin/config', update);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم حفظ نسب العمولة',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'نسبة العمولة حسب نوع المركبة',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: Color(0xFF2D2A3A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'النسبة المئوية (%) التي تخصمها الإدارة من كل توصيلة',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _vehicleTypes.map((v) {
                final icon = _vehicleIcon(v);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _controllers[v],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            suffixText: '%',
                            suffixStyle: const TextStyle(
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(icon, color: _kPrimary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri',
                            color: Color(0xFF2D2A3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'حفظ النسب',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(String v) {
    if (v.contains('motorcycle')) return Icons.moped;
    if (v.contains('car')) return CupertinoIcons.car_fill;
    if (v.contains('minibus')) return Icons.airport_shuttle;
    if (v.contains('truck')) return CupertinoIcons.cube_box;
    return CupertinoIcons.car_detailed;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  تبويب 4 — إدارة الزبائن
// ══════════════════════════════════════════════════════════════════════════════
class _AdminCustomersTab extends StatefulWidget {
  const _AdminCustomersTab();
  @override
  State<_AdminCustomersTab> createState() => _AdminCustomersTabState();
}

class _AdminCustomersTabState extends State<_AdminCustomersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _replies = [];
  int _replyCount = 0;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    SocketClient().on('new_admin_message', (_) => _loadUsers());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    SocketClient().off('new_admin_message');
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getList('/api/admin/users'),
        ApiClient.getList('/api/admin/users/messages'),
      ]);
      if (!mounted) return;
      final list = results[0].cast<Map<String, dynamic>>();
      final replies = results[1].cast<Map<String, dynamic>>();
      setState(() {
        _users = list
            .where((u) => u['role'] == 'user')
            .cast<Map<String, dynamic>>()
            .toList();
        _replies = replies;
        _replyCount = replies.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(
    String id,
    String name,
    bool currentlyActive,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          currentlyActive ? 'إلغاء تفعيل الحساب' : 'تفعيل الحساب',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          currentlyActive
              ? 'هل تريد إلغاء تفعيل حساب "$name"؟\nلن يتمكن من استخدام التطبيق.'
              : 'هل تريد تفعيل حساب "$name"؟',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyActive ? Colors.orange : Colors.green,
            ),
            child: Text(
              currentlyActive ? 'إلغاء التفعيل' : 'تفعيل',
              style: const TextStyle(fontFamily: 'Amiri', color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.put('/api/admin/users/toggle-active/$id', {});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyActive ? 'تم إلغاء التفعيل' : 'تم التفعيل',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleBan(String id, String name, bool currentlyBanned) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          currentlyBanned ? 'إلغاء حظر الحساب' : 'حظر الحساب',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          currentlyBanned
              ? 'هل تريد إلغاء حظر "$name"؟'
              : 'هل تريد حظر "$name"؟\nسيتم حظر IP جهازه بالكامل ولن يتمكن من التسجيل مرة أخرى.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyBanned ? Colors.grey : Colors.red,
            ),
            child: Text(
              currentlyBanned ? 'إلغاء الحظر' : 'حظر',
              style: const TextStyle(fontFamily: 'Amiri', color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.put('/api/admin/users/toggle-ban/$id', {});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyBanned ? 'تم إلغاء الحظر' : 'تم الحظر',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : (u['phone'] ?? 'زبون');
    final userId = u['uid'] ?? u['_id'] ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف الحساب نهائياً',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل تريد حذف حساب "$displayName" نهائياً؟\n\nسيتم حذف:\n• معلومات الحساب\n• جميع الطلبيات\n• المواقع المحفوظة\n• الإشعارات والرسائل\n• تقارير البلاغات\n\nلا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'نعم، احذف نهائياً',
              style: TextStyle(fontFamily: 'Amiri', color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.deleteImageUrl(u['photoUrl'] ?? '');
      await ApiClient.delete('/api/admin/users/$userId');
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حذف الحساب وجميع بياناته',
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePhoneHidden(Map<String, dynamic> u, bool currentlyHidden) async {
    final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : (u['phone'] ?? 'زبون');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          currentlyHidden ? 'إظهار رقم الهاتف' : 'إخفاء رقم الهاتف',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          currentlyHidden
              ? 'هل تريد إظهار رقم "$displayName" للسائقين؟'
              : 'هل تريد إخفاء رقم "$displayName" عن السائقين؟',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Amiri')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyHidden ? Colors.orange : Colors.grey,
            ),
            child: Text(
              currentlyHidden ? 'إظهار' : 'إخفاء',
              style: const TextStyle(fontFamily: 'Amiri', color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.put('/api/admin/users/${u['uid']}/toggle-phone', {});
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyHidden ? 'تم إظهار الرقم' : 'تم إخفاء الرقم',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCustomerChat(Map<String, dynamic> user) {
    final userId = user['uid'] ?? user['_id'] ?? '';
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : (user['phone'] ?? 'زبون');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminChatSheet(
        userId: userId,
        userName: displayName,
      ),
    );
  }

  void _showRepliesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildRepliesSheet(),
    );
  }

  Widget _buildRepliesSheet() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _replies) {
      final uid = r['userId'] ?? '';
      grouped.putIfAbsent(uid, () => []);
      grouped[uid]!.add(r);
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'ردود الزبائن',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _kPrimary,
              ),
            ),
          ),
          Expanded(
            child: _replies.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد ردود',
                      style: TextStyle(fontFamily: 'Amiri', color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: grouped.entries.map((e) {
                      final uid = e.key;
                      final u = _users.firstWhere(
                        (u) => (u['_id'] == uid || u['uid'] == uid),
                        orElse: () => <String, dynamic>{},
                      );
                      final userName = e.value.first['userName'] ?? 'زبون';
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showCustomerChat(
                            u.isNotEmpty
                                ? u
                                : {'uid': uid, 'firstName': userName},
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Amiri',
                                      color: Color(0xFF2D2A3A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chat_rounded,
                                    size: 14,
                                    color: _kPrimary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...e.value
                                  .take(3)
                                  .map(
                                    (m) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        m['text'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Amiri',
                                          color: Colors.black54,
                                        ),
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchCtrl.text.isEmpty
        ? _users
        : _users.where((u) {
            final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                .trim();
            return name.contains(_searchCtrl.text) ||
                (u['phone'] ?? '').toString().contains(_searchCtrl.text);
          }).toList();

    // تجميع الزبائن حسب المدينة
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final u in filtered) {
      final city = (u['cityName'] as String?)?.isNotEmpty == true
          ? u['cityName'] as String
          : (u['cityNameAr'] as String?)?.isNotEmpty == true
              ? u['cityNameAr'] as String
              : (u['location'] as String?)?.isNotEmpty == true
                  ? u['location'] as String
                  : 'غير محدد';
      grouped.putIfAbsent(city, () => []).add(u);
    }
    final cityEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (_selectedCity != null) {
      return _buildCityUsers(cityEntries);
    }

    return Column(
      children: [
        Container(
          color: _kPrimary,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'إدارة الزبائن',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _loadUsers,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _searchCtrl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Amiri',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'بحث عن زبون...',
                    hintStyle: TextStyle(
                      color: Colors.white60,
                      fontFamily: 'Amiri',
                      fontSize: 12,
                    ),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.white70, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kPrimary))
              : filtered.isEmpty
              ? const Center(
                  child: Text(
                    'لا يوجد زبائن',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cityEntries.length,
                  itemBuilder: (_, i) {
                    final city = cityEntries[i].key;
                    final users = cityEntries[i].value;
                    final activeCount = users.where((u) => u['isActive'] == true).length;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCity = city),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _kPrimary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.location_city, color: _kPrimary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    city,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF2D2A3A),
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${users.length} زبون · $activeCount مفعل',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(CupertinoIcons.chevron_left, color: Colors.grey.shade400, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCityUsers(List<MapEntry<String, List<Map<String, dynamic>>>> cityEntries) {
    final cityEntry = cityEntries.firstWhere(
      (e) => e.key == _selectedCity,
      orElse: () => MapEntry(_selectedCity!, []),
    );
    final users = cityEntry.value;

    return Column(
      children: [
        Container(
          color: _kPrimary,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedCity = null),
                    child: const Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCity!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadUsers,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${users.length} زبون',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontFamily: 'Amiri'),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const Center(child: Text('لا يوجد زبائن في هذه المدينة', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
                    final displayName = name.isNotEmpty ? name : (u['phone'] ?? 'زبون');
                    final isActive = u['isActive'] == true;
                    final isBanned = u['isBanned'] == true;
                    final phoneHidden = u['phoneHidden'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                            Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF2D2A3A),
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    u['phone'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _kPrimary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person, color: _kPrimary, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _btnAction(
                                label: isActive ? 'إلغاء التفعيل' : 'تفعيل',
                                color: isActive ? Colors.orange : Colors.green,
                                onTap: () => _toggleActive(u['_id'] ?? '', displayName, isActive),
                              ),
                              _btnAction(
                                label: isBanned ? 'إلغاء حظر' : 'حظر',
                                color: isBanned ? Colors.grey : Colors.red,
                                onTap: () => _toggleBan(u['_id'] ?? '', displayName, isBanned),
                              ),
                              _btnAction(
                                label: phoneHidden ? 'إظهار الرقم' : 'إخفاء الرقم',
                                color: phoneHidden ? Colors.orange : Colors.grey,
                                onTap: () => _togglePhoneHidden(u, phoneHidden),
                              ),
                              _btnAction(
                                label: 'محادثة',
                                color: _kPrimary,
                                onTap: () => _showCustomerChat(u),
                              ),
                              _btnAction(
                                label: 'حذف',
                                color: Colors.red,
                                onTap: () => _deleteUser(u),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (isActive) _miniChip('مفعل', Colors.green)
                              else _miniChip('غير مفعل', Colors.grey),
                              const SizedBox(width: 6),
                              if (isBanned) _miniChip('محظور', Colors.red),
                              if (phoneHidden) ...[
                                const SizedBox(width: 6),
                                _miniChip('الرقم مخفي', Colors.orange),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _btnAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Amiri',
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  شات الأدمن مع زبون معين
// ══════════════════════════════════════════════════════════════════════════════
class _AdminChatSheet extends StatefulWidget {
  final String userId;
  final String userName;
  const _AdminChatSheet({required this.userId, required this.userName});
  @override
  State<_AdminChatSheet> createState() => _AdminChatSheetState();
}

class _AdminChatSheetState extends State<_AdminChatSheet> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    SocketClient().on('new_admin_message', _onNewMessage);
  }

  void _onNewMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['userId'] == widget.userId) {
      _messages.add(data.cast<String, dynamic>());
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    SocketClient().off('new_admin_message', _onNewMessage);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ApiClient.getList(
        '/api/admin/users/${widget.userId}/messages',
      );
      if (!mounted) return;
      setState(() {
        _messages = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/admin/users/${widget.userId}/send-message', {
        'text': text,
      });
      _msgCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _kPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'المحادثة مع ${widget.userName}',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimary),
                    )
                  : _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد رسائل بعد',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final text = m['text'] ?? '';
                        final fromAdmin = m['from'] == 'admin';
                        final time = m['createdAt'] ?? '';
                        final date = time is String && time.isNotEmpty
                            ? DateTime.tryParse(time)
                            : null;
                        final formatted = date != null
                            ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}  ${date.day}/${date.month}'
                            : '';
                        return Align(
                          alignment: fromAdmin
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: fromAdmin
                                  ? const Color(0xFF2D2A3A)
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: fromAdmin
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                                bottomRight: fromAdmin
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: fromAdmin
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.end,
                              children: [
                                Text(
                                  fromAdmin ? 'الإدارة' : widget.userName,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 10,
                                    color: fromAdmin
                                        ? Colors.white70
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 14,
                                    color: fromAdmin
                                        ? Colors.white
                                        : const Color(0xFF2D2A3A),
                                  ),
                                  textAlign: fromAdmin
                                      ? TextAlign.left
                                      : TextAlign.right,
                                ),
                                if (formatted.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      formatted,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: fromAdmin
                                            ? Colors.white38
                                            : Colors.grey.shade400,
                                        fontFamily: 'Amiri',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                        minLines: 1,
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          hintStyle: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F0),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
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
}

// ══════════════════════════════════════════════════════════════════════════════
//  نافذة البلاغات (التقارير) للأدمن
// ══════════════════════════════════════════════════════════════════════════════
class _AdminReportsSheet extends StatefulWidget {
  const _AdminReportsSheet();
  @override
  State<_AdminReportsSheet> createState() => _AdminReportsSheetState();
}

class _AdminReportsSheetState extends State<_AdminReportsSheet> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.getList(
        '/api/admin/reports?status=$_filter',
      );
      if (!mounted) return;
      setState(() {
        _reports = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveReport(String id) async {
    try {
      await ApiClient.put('/api/admin/reports/$id/status', {
        'status': 'resolved',
      });
      _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'البلاغات',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _kPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _filterChip('معلقة', 'pending'),
                const SizedBox(width: 8),
                _filterChip('تمت المعالجة', 'resolved'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  )
                : _reports.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد بلاغات',
                      style: TextStyle(fontFamily: 'Amiri', color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) {
                      final r = _reports[i];
                      final type = r['type'] ?? 'driver_report';
                      String typeLabel;
                      Color typeColor;
                      String reporterName;
                      String targetName;
                      String note;

                      if (type == 'comment_report') {
                        typeLabel = 'بلاغ على تعليق';
                        typeColor = Colors.red;
                        reporterName = r['userName'] ?? 'مبلغ';
                        targetName = r['commentAuthorName'] ?? 'كاتب التعليق';
                        note = r['note'] ?? r['reason'] ?? '';
                      } else if (type == 'customer_report_owner') {
                        typeLabel = 'زبون ← تاجر';
                        typeColor = Colors.purple;
                        reporterName = r['userName'] ?? 'زبون';
                        targetName = r['ownerName'] ?? 'تاجر';
                        note = r['note'] ?? r['reason'] ?? '';
                      } else {
                        typeLabel = type == 'driver_report'
                            ? 'سائق ← زبون'
                            : 'زبون ← سائق';
                        typeColor = type == 'driver_report'
                            ? Colors.orange
                            : Colors.blue;
                        reporterName = type == 'driver_report'
                            ? (r['driverName'] ?? 'سائق')
                            : (r['userName'] ?? 'زبون');
                        targetName = type == 'driver_report'
                            ? (r['userName'] ?? 'زبون')
                            : (r['driverName'] ?? 'سائق');
                        note = r['note'] ?? r['reason'] ?? '';
                      }

                      final driverName = r['driverName'] as String?;
                      final commentText = r['commentText'] as String?;
                      final ts = r['createdAt'];
                      final time = ts != null
                          ? intl.DateFormat(
                              'yyyy/MM/dd HH:mm',
                            ).format(DateTime.parse('$ts'))
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (r['status'] == 'pending')
                                  GestureDetector(
                                    onTap: () => _resolveReport(r['_id']),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'معالجة',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Amiri',
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 10,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (type == 'comment_report') ...[
                              if (driverName != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'السائق: $driverName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Amiri',
                                      color: _kPrimary,
                                    ),
                                  ),
                                ),
                              if (commentText != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    commentText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Amiri',
                                      color: Color(0xFF2D2A3A),
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                            ],
                            Text(
                              'من: $reporterName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Amiri',
                                color: Color(0xFF2D2A3A),
                              ),
                            ),
                            Text(
                              'على: $targetName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Amiri',
                                color: Colors.grey,
                              ),
                            ),
                            if (r['orderId'] != null)
                              Text(
                                'الطلب: ${r['orderId']}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Amiri',
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _kBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Amiri',
                                  color: Color(0xFF2D2A3A),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            if (time.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _loadReports();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _kPrimary,
            fontSize: 12,
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CommissionOverviewSheet — عرض أرباح الإدارة مع تجميع حسب المركبة
// ══════════════════════════════════════════════════════════════════════════════
class _CommissionOverviewSheet extends StatefulWidget {
  const _CommissionOverviewSheet();
  @override
  State<_CommissionOverviewSheet> createState() =>
      _CommissionOverviewSheetState();
}

class _CommissionOverviewSheetState extends State<_CommissionOverviewSheet> {
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic> _globalConfig = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getList('/api/drivers'),
        ApiClient.get('/api/config'),
      ]);
      if (!mounted) return;
      setState(() {
        _drivers = (results[0] as List).cast<Map<String, dynamic>>();
        _globalConfig = (results[1] as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'أرباح الإدارة من السائقين',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: Color(0xFF2D2A3A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اضغط على "استلام" لتأكيد تحصيل الأموال وإعادة الحساب',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  )
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final d in _drivers) {
      final vType = d['vehicleType'] as String? ?? 'غير محدد';
      grouped.putIfAbsent(vType, () => []).add(d);
    }
    final types = grouped.keys.toList();
    final labelOrder = ['motorcycle', 'car', 'minibus', 'truck'];
    types.sort((a, b) {
      final ai = labelOrder.indexOf(a);
      final bi = labelOrder.indexOf(b);
      if (ai == -1 && bi == -1) return a.compareTo(b);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: types.length,
      itemBuilder: (_, i) {
        final type = types[i];
        final driverDocs = grouped[type]!;
        final sumEarnings = driverDocs.fold<double>(
          0,
          (s, d) => s + (d['totalEarnings'] ?? 0).toDouble(),
        );
        final sumPending = driverDocs.fold<double>(0, (s, d) {
          final p = (d['commissionPercent'] as num? ?? 0).toDouble();
          final percent = p > 0
              ? p
              : () {
                  final vType = (d['vehicleType'] as String? ?? '').replaceAll(
                    ' ',
                    '_',
                  );
                  final key = 'commission_$vType';
                  return (_globalConfig[key] as num? ??
                          _globalConfig['defaultCommissionPercent'] as num? ??
                          0)
                      .toDouble();
                }();
          final cash = (d['cash'] ?? 0).toDouble();
          return s + cash * percent / 100;
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${driverDocs.length} سائق',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kPrimary,
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Amiri',
                      color: Color(0xFF2D2A3A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.car_detailed, color: _kPrimary, size: 16),
                ],
              ),
            ),
            ...driverDocs.map(
              (doc) => _CommissionDriverCard(
                doc: doc,
                globalConfig: _globalConfig,
                onCollected: _load,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'المستحق: ${sumPending.toStringAsFixed(0)} دج',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الإجمالي: ${sumEarnings.toStringAsFixed(0)} دج',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kPrimary,
                      fontFamily: 'Amiri',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CommissionDriverCard extends StatefulWidget {
  final Map<String, dynamic> doc;
  final Map<String, dynamic> globalConfig;
  final VoidCallback onCollected;
  const _CommissionDriverCard({
    required this.doc,
    required this.globalConfig,
    required this.onCollected,
  });

  @override
  State<_CommissionDriverCard> createState() => _CommissionDriverCardState();
}

class _CommissionDriverCardState extends State<_CommissionDriverCard> {
  bool _confirming = false;

  Map<String, dynamic> get d => widget.doc;

  double get _percent {
    final p = (d['commissionPercent'] as num? ?? 0).toDouble();
    if (p > 0) return p;
    final vType = (d['vehicleType'] as String? ?? '').replaceAll(' ', '_');
    final key = 'commission_$vType';
    return (widget.globalConfig[key] as num? ??
            widget.globalConfig['defaultCommissionPercent'] as num? ??
            0)
        .toDouble();
  }

  double get _totalEarnings => (d['totalEarnings'] ?? 0).toDouble();
  double get _cash => (d['cash'] as num? ?? 0).toDouble();
  double get _pendingCommission => _percent > 0 ? _cash * _percent / 100 : 0;

  Future<void> _confirmCollect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تأكيد استلام الأموال',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
        ),
          content: Text(
            'هل تأكد استلام ${_pendingCommission.toStringAsFixed(0)} دج من هذا السائق؟',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Amiri', fontSize: 13),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: _kPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'تأكيد الاستلام',
              style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _confirming = true);
    try {
      await ApiClient.post('/api/admin/settlements', {
        'driverId': d['_id'],
        'amountCollected': _pendingCommission,
        'paymentMethod': 'cash',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تسجيل الاستلام بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onCollected();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ: $e',
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    final city = d['cityName'] ?? 'غير محدد';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_confirming)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kPrimary,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _DriverStatementSheet(driverId: d['_id'], driverData: d),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'كشف الحساب',
                          style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri'),
                        ),
                      ),
                    ),
                    if (_pendingCommission > 0) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _confirmCollect,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'استلام',
                            style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri'),
                          ),
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
                    name.isEmpty ? 'سائق' : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF2D2A3A),
                      fontFamily: 'Amiri',
                    ),
                  ),
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _infoChip(
                  '${_cash.toStringAsFixed(0)} دج',
                  'الموجود',
                  Colors.blue.shade700,
                ),
              ),
              Expanded(
                child: _infoChip(
                  '${_percent.toStringAsFixed(0)}%',
                  'نسبة الخصم',
                  Colors.amber.shade700,
                ),
              ),
              Expanded(
                child: _infoChip(
                  '${_pendingCommission.toStringAsFixed(0)} دج',
                  'الأرباح المستحقة',
                  Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: color,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontFamily: 'Amiri',
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  كشف حساب السائق
// ══════════════════════════════════════════════════════════════════════════════
class _DriverStatementSheet extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;
  const _DriverStatementSheet({required this.driverId, required this.driverData});

  @override
  State<_DriverStatementSheet> createState() => _DriverStatementSheetState();
}

class _DriverStatementSheetState extends State<_DriverStatementSheet> {
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
      final data = await ApiClient.getList('/api/admin/settlements/${widget.driverId}');
      _list = data.cast<Map<String, dynamic>>();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      _totalCollected = _list.fold<double>(0, (s, e) => s + ((e['amountCollected'] ?? 0).toDouble()));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driverData;
    final cash = (d['cash'] as num? ?? 0).toDouble();
    final pct = (d['commissionPercent'] as num? ?? 0).toDouble();
    final pending = pct > 0 ? cash * pct / 100 : 0;
    final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    final city = d['cityName'] as String? ?? '';
    final vehicle = d['vehicleType'] as String? ?? '';

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
            // drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
            ),
            // driver info header
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
                    child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'سائق' : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF2D2A3A))),
                        if (city.isNotEmpty || vehicle.isNotEmpty)
                          Text([city, vehicle].where((s) => s.isNotEmpty).join(' · '), style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'Amiri')),
                      ],
                    ),
                  ),
                  const Text('كشف الحساب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF7D29C6))),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 12),
            // summary cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _neuCard('${cash.toStringAsFixed(0)} دج', 'الرصيد الحالي', CupertinoIcons.money_dollar_circle_fill, const Color(0xFF00897B))),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('$pct%', 'نسبة الخصم', CupertinoIcons.percent, Colors.amber.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('${pending.toStringAsFixed(0)} دج', 'المستحق', CupertinoIcons.clock, Colors.red.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // total collected
            if (_totalCollected > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.checkmark_shield_fill, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text('إجمالي المسحوبات: ${_totalCollected.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // list
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
                      try { final d2 = DateTime.parse(createdAt); dt = '${d2.year}/${d2.month.toString().padLeft(2,'0')}/${d2.day.toString().padLeft(2,'0')}  ${d2.hour.toString().padLeft(2,'0')}:${d2.minute.toString().padLeft(2,'0')}'; } catch (_) { dt = createdAt.substring(0, 16); }
                    }
                    final cashAt = (s['cashAtSettlement'] ?? 0).toDouble();
                    final cpct = (s['commissionPercent'] ?? 0).toDouble();
                    final commAmt = (s['commissionAmount'] ?? 0).toDouble();
                    final discountVal = (s['discount'] ?? 0).toDouble();
                    final collected = (s['amountCollected'] ?? 0).toDouble();
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
                                child: Text('-${collected.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red, fontFamily: 'Amiri')),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              _infoChip('الرصيد قبل الخصم', '${cashAt.toStringAsFixed(0)} دج', const Color(0xFF00897B)),
                              const SizedBox(width: 8),
                              _infoChip('نسبة الخصم', '$cpct%', Colors.amber.shade700),
                              const SizedBox(width: 8),
                              _infoChip('قيمة الخصم', '${commAmt.toStringAsFixed(0)} دج', Colors.red.shade600),
                              if (discountVal > 0) ...[
                                const SizedBox(width: 8),
                                _infoChip('خصم إضافي', '${discountVal.toStringAsFixed(0)} دج', Colors.purple.shade600),
                              ],
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

// ══════════════════════════════════════════════════════════════════════════════
//  كشف الحساب لصاحب المحل
// ══════════════════════════════════════════════════════════════════════════════
class _OwnerStatementSheet extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;
  const _OwnerStatementSheet({required this.storeId, required this.storeData});

  @override
  State<_OwnerStatementSheet> createState() => _OwnerStatementSheetState();
}

class _OwnerStatementSheetState extends State<_OwnerStatementSheet> {
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
      _list = data.cast<Map<String, dynamic>>();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
      _totalCollected = _list.fold<double>(0, (s, e) => s + ((e['amountCollected'] ?? 0).toDouble()));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.storeData;
    final cash = (st['cash'] as num? ?? 0).toDouble();
    final pct = (st['commissionPercent'] as num? ?? 0).toDouble();
    final pending = cash * pct / 100;
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
                  const Text('كشف الحساب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri', color: Color(0xFF7D29C6))),
                ],
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _neuCard('${cash.toStringAsFixed(0)} دج', 'الرصيد الحالي', CupertinoIcons.money_dollar_circle_fill, const Color(0xFF00897B))),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('$pct%', 'نسبة الخصم', CupertinoIcons.percent, Colors.amber.shade700)),
                  const SizedBox(width: 10),
                  Expanded(child: _neuCard('${pending.toStringAsFixed(0)} دج', 'المستحق', CupertinoIcons.clock, Colors.red.shade600)),
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
                    Text('إجمالي المسحوبات: ${_totalCollected.toStringAsFixed(0)} دج', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
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
                                child: Text('-${collected.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red, fontFamily: 'Amiri')),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              _infoChip('الرصيد بعد', '${after.toStringAsFixed(0)} دج', const Color(0xFF00897B)),
                              const SizedBox(width: 8),
                              _infoChip('نسبة الخصم', '$cpct%', Colors.amber.shade700),
                              const SizedBox(width: 8),
                              _infoChip('قيمة الخصم', '${commAmt.toStringAsFixed(0)} دج', Colors.red.shade600),
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

// ══════════════════════════════════════════════════════════════════════════════
//  صفحة كشف الحساب كاملة (للتاجر)
// ══════════════════════════════════════════════════════════════════════════════

class OwnerStatementPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;
  const OwnerStatementPage({super.key, required this.storeId, required this.storeData});

  @override
  State<OwnerStatementPage> createState() => _OwnerStatementPageState();
}

class _OwnerStatementPageState extends State<OwnerStatementPage> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.getList('/api/admin/store-settlements/${widget.storeId}');
      _list = data.cast<Map<String, dynamic>>();
      _list.sort((a, b) => ((a['createdAt'] as String?) ?? '').compareTo((b['createdAt'] as String?) ?? ''));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.storeData;
    final cash = (st['cash'] as num? ?? 0).toDouble();
    final pct = (st['commissionPercent'] as num? ?? 0).toDouble();
    final pending = cash * pct / 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F0F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('كشف الحساب', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Color(0xFF5B0094))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5B0094)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── ملخص المبالغ ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFB8B1C8), offset: Offset(4,4), blurRadius: 12),
                  BoxShadow(color: Colors.white, offset: Offset(-4,-4), blurRadius: 12),
                ],
              ),
              child: Row(
                children: [
                  Expanded(child: _sumCell('${cash.toStringAsFixed(0)} دج', 'المبلغ الحالي', const Color(0xFF00897B))),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  Expanded(child: _sumCell('$pct%', 'نسبة الخصم', Colors.amber.shade700)),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  Expanded(child: _sumCell('${pending.toStringAsFixed(0)} دج', 'المبلغ المخصوم', Colors.red.shade600)),
                ],
              ),
            ),
          ),
          // ── قائمة الكشوفات ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(child: Text('لا توجد تسجيلات بعد', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = _list[i];
                          final createdAt = s['createdAt'] ?? '';
                          String dt = '';
                          if (createdAt is String) {
                            try {
                              final d = DateTime.parse(createdAt);
                              dt = '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
                            } catch (_) {
                              dt = createdAt.substring(0, 16);
                            }
                          }
                          final amt = (s['commissionAmount'] ?? 0).toDouble();
                          final cpct = (s['commissionPercent'] ?? 0).toDouble();
                          final collected = (s['amountCollected'] ?? 0).toDouble();
                          final after = (s['earningsAfter'] ?? 0).toDouble();

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(color: Color(0xFFB8B1C8), offset: Offset(3,3), blurRadius: 8),
                                BoxShadow(color: Colors.white, offset: Offset(-3,-3), blurRadius: 8),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(CupertinoIcons.clock, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(dt, style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade600)),
                                    const Spacer(),
                                    Text('-${collected.toStringAsFixed(0)} دج', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red, fontFamily: 'Amiri')),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    _infoChip('المبلغ الحالي', '${after.toStringAsFixed(0)} دج', const Color(0xFF00897B)),
                                    const SizedBox(width: 8),
                                    _infoChip('نسبة الخصم', '$cpct%', Colors.amber.shade700),
                                    const SizedBox(width: 8),
                                    _infoChip('المبلغ المخصوم', '${amt.toStringAsFixed(0)} دج', Colors.red.shade600),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sumCell(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color, fontFamily: 'Amiri')),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Amiri')),
    ],
  );

  Widget _infoChip(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color, fontFamily: 'Amiri')),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontFamily: 'Amiri')),
        ],
      ),
    ),
  );
}
