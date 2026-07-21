// ════════════════════════════════════════════════════════════════════════════
//  unified_login.dart
//  شاشة الدخول الموحدة — سائق | صاحب محل | أدمن
//  يستورد: admin_panel.dart  |  driver_app.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:dashbord/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_panel.dart';
import 'driver_app.dart';
import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;

// ══════════════════════════════════════════════════════════════════════════════
//  1. شاشة الدخول الموحدة
// ══════════════════════════════════════════════════════════════════════════════
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});
  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen>
    with SingleTickerProviderStateMixin {
  // 0 = اختيار نوع المستخدم، 1 = دخول صاحب محل
  int _step = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _goto(int step) {
    _animCtrl.reverse().then((_) {
      setState(() => _step = step);
      _animCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _step == 0 ? _buildChoice() : _buildOwnerLogin(),
        ),
      ),
    );
  }

  // ── صفحة الاختيار ──────────────────────────────────────────────────────────
  Widget _buildChoice() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // لوغو
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
              boxShadow: neuShadow(blur: 20, offset: 8),
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              size: 58,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Deliveryyy',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اختر نوع حسابك للمتابعة',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGrey,
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 50),

          // ── بطاقة السائق ──
          _roleCard(
            icon: CupertinoIcons.car_detailed,
            title: 'أنا سائق',
            subtitle: 'دخول أو إنشاء حساب سائق توصيل',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverSignInScreen()),
            ),
          ),
          const SizedBox(height: 20),

          // ── بطاقة صاحب المحل ──
          _roleCard(
            icon: CupertinoIcons.building_2_fill,
            title: 'أنا صاحب محل',
            subtitle: 'دخول أو إنشاء حساب تاجر',
            color: const Color(0xFF7B1FA2),
            onTap: () => _goto(1),
          ),
          const SizedBox(height: 40),

          // ── دخول الأدمن (خفي) ──
          GestureDetector(
            onLongPress: () => _showAdminDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(30),
                boxShadow: neuShadow(blur: 6, offset: 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    size: 14,
                    color: AppTheme.textGrey.withOpacity(0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'لوحة الإدارة',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey.withOpacity(0.6),
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: Offset(-4, -4),
            ),
          ],
          border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_left, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ── شاشة دخول صاحب المحل ──────────────────────────────────────────────────
  Widget _buildOwnerLogin() {
    return _OwnerLoginForm(onBack: () => _goto(0));
  }

  // ── دايالوغ الأدمن ──────────────────────────────────────────────────────
  void _showAdminDialog() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppTheme.primary),
            SizedBox(width: 10),
            Text(
              'دخول الأدمن',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(userCtrl, 'اسم المستخدم', Icons.person),
            const SizedBox(height: 12),
            _dialogField(passCtrl, 'كلمة السر', Icons.lock, isPass: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                final res = await ApiClient.post('/api/admin/login', {
                  'username': userCtrl.text,
                  'password': passCtrl.text,
                });
                if (res['success'] == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userRole', 'admin');
                  if (res['token'] != null) {
                    await prefs.setString('adminToken', res['token']);
                    ApiClient.setToken(res['token']);
                  }
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDashboardMain()),
                  );
                } else {
                  throw Exception('فشل تسجيل الدخول');
                }
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'بيانات خاطئة',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Amiri'),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'دخول',
              style: TextStyle(color: Colors.white, fontFamily: 'Amiri'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController c,
    String h,
    IconData icon, {
    bool isPass = false,
  }) => TextField(
    controller: c,
    obscureText: isPass,
    textAlign: TextAlign.right,
    style: const TextStyle(fontFamily: 'Amiri'),
    decoration: InputDecoration(
      hintText: h,
      hintStyle: const TextStyle(fontFamily: 'Amiri', color: AppTheme.textGrey),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
      filled: true,
      fillColor: AppTheme.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  2. فورم دخول صاحب المحل
// ══════════════════════════════════════════════════════════════════════════════
class _OwnerLoginForm extends StatefulWidget {
  final VoidCallback onBack;
  const _OwnerLoginForm({required this.onBack});

  @override
  State<_OwnerLoginForm> createState() => _OwnerLoginFormState();
}

class _OwnerLoginFormState extends State<_OwnerLoginForm> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  final user = _userCtrl.text.trim();
  final pass = _passCtrl.text.trim();
  if (user.isEmpty || pass.isEmpty) {
    setState(() => _error = 'يرجى ملء جميع الحقول');
    return;
  }
  setState(() {
    _loading = true;
    _error = null;
  });
  try {
    final response = await ApiClient.post('/api/owner-login', {
      'username': user,
      'password': pass,
    });

    if (response['success'] == true && response['user'] != null) {
      Map<String, dynamic> data = Map<String, dynamic>.from(response['user']);

      if (data['isActive'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', 'owner');
        await prefs.setString('ownerData', jsonEncode(data));
        if (response['token'] != null) {
          await prefs.setString('adminToken', response['token']);
          ApiClient.setToken(response['token']);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => OwnerDashboard(ownerData: data)),
          );
        }
      } else {
        setState(() => _error = 'حسابك بانتظار تفعيل الإدارة ⏳');
      }
    } else {
      setState(() => _error = 'اسم المستخدم أو كلمة السر خاطئة');
    }
  } catch (e) {
    debugPrint("Login Error: $e"); 
    setState(() => _error = 'حدث مشكل أثناء الدخول');
  }
  if (mounted) setState(() => _loading = false);
}
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // ── رأس الصفحة ──
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: neuShadow(blur: 8, offset: 3),
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_right,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'دخول صاحب المحل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
              const SizedBox(width: 42),
            ],
          ),
          const SizedBox(height: 50),

          // ── أيقونة ──
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
              boxShadow: neuShadow(blur: 18, offset: 7),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              size: 44,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 36),

          // ── حقول الدخول ──
          _neuField(_userCtrl, 'اسم المستخدم', CupertinoIcons.person),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(18),
              boxShadow: neuShadow(),
            ),
            child: TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Amiri', color: AppTheme.textDark),
              decoration: InputDecoration(
                hintText: 'كلمة السر',
                hintStyle: const TextStyle(
                  color: AppTheme.textGrey,
                  fontFamily: 'Amiri',
                ),
                prefixIcon: Icon(
                  CupertinoIcons.lock,
                  color: AppTheme.primary,
                  size: 20,
                ),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                    color: AppTheme.textGrey,
                    size: 18,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontFamily: 'Amiri',
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 30),

          // ── زر الدخول ──
          _loading
              ? const CircularProgressIndicator(color: AppTheme.primary)
              : _gradientButton('دخول', _login),

          const SizedBox(height: 20),

          // ── إنشاء حساب ──
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerRegisterScreen()),
            ),
            child: const Text(
              'ليس لديك حساب؟ سجّل الآن',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openPrivacyPolicy,
            child: const Text(
              'سياسة الخصوصية',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 12,
                color: AppTheme.textGrey,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy() {
    final url = 'https://walyyd.com/privacy-policy';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _neuField(TextEditingController c, String h, IconData icon) =>
      Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          boxShadow: neuShadow(),
        ),
        child: TextField(
          controller: c,
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Amiri', color: AppTheme.textDark),
          decoration: InputDecoration(
            hintText: h,
            hintStyle: const TextStyle(color: AppTheme.textGrey, fontFamily: 'Amiri'),
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      );

  Widget _gradientButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A0080), AppTheme.primary, AppTheme.accent],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Amiri',
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  3. شاشة إنشاء حساب صاحب المحل
// ══════════════════════════════════════════════════════════════════════════════
class OwnerRegisterScreen extends StatefulWidget {
  const OwnerRegisterScreen({super.key});
  @override
  State<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends State<OwnerRegisterScreen> {
  final _userCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedStoreId, _selectedStoreName;
  bool _loading = false;
  List<Map<String, dynamic>> _magasins = [];
  bool _loadingMagasins = true;

  @override
  void initState() {
    super.initState();
    _loadMagasins();
  }

  Future<void> _loadMagasins() async {
    try {
      final data = await ApiClient.getList('/api/stores?ownerId=null');
      if (mounted) {
        setState(() {
          _magasins = data.cast<Map<String, dynamic>>();
          _loadingMagasins = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMagasins = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_selectedStoreId == null ||
        _userCtrl.text.isEmpty ||
        _storeNameCtrl.text.isEmpty) {
      _snack('يرجى ملء جميع الحقول واختيار نوع النشاط');
      return;
    }

    setState(() => _loading = true);
    final username = _userCtrl.text.trim();

    try {
      final users = await ApiClient.getList('/api/users');
      final exists = users.any((u) {
        final doc = u as Map<String, dynamic>;
        return (doc['username'] as String? ?? '').toLowerCase() ==
            username.toLowerCase();
      });
      if (exists) {
        _snack('هذا الاسم موجود بالفعل ❌');
        if (mounted) setState(() => _loading = false);
        return;
      }

      await ApiClient.post('/api/users', {
        'username': username,
        'password': _passCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'storeName': _storeNameCtrl.text.trim(),
        'magasinId': _selectedStoreId,
        'templateName': _selectedStoreName,
        'isActive': false,
        'role': 'owner',
        'createdAt': DateTime.now().toIso8601String(),
      });

      _snack('تم إرسال الطلب، انتظر تفعيل الإدارة ✅');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('حدث خطأ أثناء التسجيل، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        m,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Amiri'),
      ),
      backgroundColor: AppTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'إنشاء حساب تاجر',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.background,
                shape: BoxShape.circle,
                boxShadow: neuShadow(blur: 14, offset: 6),
              ),
              child: const Icon(
                CupertinoIcons.house,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 28),

            // ── اختيار نوع المحل ──
            _loadingMagasins
                ? const LinearProgressIndicator(color: AppTheme.primary)
                : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
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
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-4, -4),
                      ),
                    ],
                    border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: 'نوع النشاط التجاري',
                        labelStyle: TextStyle(
                          fontFamily: 'Amiri',
                          color: AppTheme.textGrey,
                        ),
                      ),
                      isExpanded: true,
                      hint: const Text(
                        'اختر نوع نشاطك',
                        style: TextStyle(fontFamily: 'Amiri', color: AppTheme.textGrey),
                      ),
                      value: _selectedStoreId,
                      items: _magasins
                          .map(
                            (d) => DropdownMenuItem(
                              value: (d['_id'] ?? '') as String,
                              child: Text(
                                d['nom'] ?? '',
                                style: const TextStyle(fontFamily: 'Amiri'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        final doc = _magasins.firstWhere(
                          (d) => d['_id'] == v,
                        );
                        setState(() {
                          _selectedStoreId = v;
                          _selectedStoreName = doc['nom'];
                        });
                      },
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            _field(_storeNameCtrl, 'اسم المحل الخاص بك', CupertinoIcons.tag),
            const SizedBox(height: 16),
            _field(_userCtrl, 'اسم المستخدم', CupertinoIcons.person),
            const SizedBox(height: 16),
            _field(_passCtrl, 'كلمة السر', CupertinoIcons.lock),
            const SizedBox(height: 16),
            _field(
              _phoneCtrl,
              'رقم الهاتف',
              CupertinoIcons.phone,
              type: TextInputType.phone,
            ),
            const SizedBox(height: 36),

            _loading
                ? const CircularProgressIndicator(color: AppTheme.primary)
                : _submitBtn(),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.info_circle, color: AppTheme.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'بعد إرسال الطلب، يقوم المسؤول بمراجعته وتفعيل حسابك',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                      textAlign: TextAlign.right,
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

  Widget _field(
    TextEditingController c,
    String h,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) => Container(
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(18),
      boxShadow: neuShadow(),
    ),
    child: TextField(
      controller: c,
      keyboardType: type,
      textAlign: TextAlign.right,
      style: const TextStyle(fontFamily: 'Amiri', color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: const TextStyle(color: AppTheme.textGrey, fontFamily: 'Amiri'),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    ),
  );

  Widget _submitBtn() => GestureDetector(
    onTap: _register,
    child: Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A0080), AppTheme.primary, AppTheme.accent],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'إرسال طلب الانضمام',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Amiri',
          ),
        ),
      ),
    ),
  );
}

  // ══════════════════════════════════════════════════════════════════════════════
  //  4. لوحة تحكم صاحب المحل (تستورد من driver_app.dart أو UnifiedLoginScreen القديم)
  //     نضع هنا stub يشير لـ OwnerDashboard الموجود في driver_app.dart
  // ══════════════════════════════════════════════════════════════════════════════
  // OwnerDashboard معرّفة في ملف driver_app.dart وتُستورد منه

