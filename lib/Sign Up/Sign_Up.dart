// ══════════════════════════════════════════════════════════════════════════════
//  Sign_Up.dart
//  Flow: إنشاء حساب → رقم الهاتف (مع شرح) → الموقع → الداشبورد
//  ✅ بدون خانة الهاتف في إنشاء الحساب
//  ✅ شاشة الهاتف مع رسالة توعوية جميلة
//  ✅ شاشة الموقع: اسم + خريطة
//  ✅ ألوان متناسقة مع الداشبورد (بنفسجي بارد)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import '../Sign in/auth_service.dart';
import '../Order/order_models.dart';
import '../Services/delivery_screen.dart';
import '../user_local.dart';
import '../theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  STEP 1 — شاشة إنشاء الحساب (بدون رقم الهاتف)
// ══════════════════════════════════════════════════════════════════════════════
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _gender;
  bool _submitted = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConf = true;
  String? _error;

  late AnimationController _headerCtrl, _formCtrl, _btnCtrl;
  late Animation<Offset> _headerSlide, _formSlide, _btnSlide;
  late Animation<double> _headerFade, _formFade, _btnFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = _ac(600);
    _formCtrl = _ac(550);
    _btnCtrl = _ac(500);

    _headerSlide = _slide(_headerCtrl, const Offset(0, -0.5));
    _formSlide = _slide(_formCtrl, const Offset(0, 0.4));
    _btnSlide = _slide(_btnCtrl, const Offset(0, 0.5));
    _headerFade = _fade(_headerCtrl);
    _formFade = _fade(_formCtrl);
    _btnFade = _fade(_btnCtrl);

    _play();
  }

  AnimationController _ac(int ms) => AnimationController(
    vsync: this,
    duration: Duration(milliseconds: ms));

  Animation<Offset> _slide(AnimationController c, Offset begin) =>
      Tween<Offset>(
        begin: begin,
        end: Offset.zero).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));

  Animation<double> _fade(AnimationController c) => Tween<double>(
    begin: 0,
    end: 1).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  Future<void> _play() async {
    _headerCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    _formCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    _btnCtrl.forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _formCtrl.dispose();
    _btnCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── إنشاء الحساب بدون رقم الهاتف ────────────────────────────────────────
  Future<void> _register() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      setState(() => _error = 'يرجى اختيار الجنس');
      return;
    }
    setState(() => _isLoading = true);
    try {
      // نحفظ حساب Firebase Auth بدون رقم الهاتف (phone فارغ مؤقتاً)
      await AuthService.signUpWithEmail(
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        phone: '',
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        gender: _gender ?? '');
      UserLocal.data ??= {};
      UserLocal.data!['gender'] = _gender;
      UserLocal.data!['firstName'] = _firstCtrl.text.trim();
      UserLocal.data!['lastName'] = _lastCtrl.text.trim();
      UserLocal.data!['email'] = _emailCtrl.text.trim();
      if (!mounted) return;
      Navigator.pushReplacement(context, _pageRoute(const PhoneScreen()));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e.code));
    } catch (_) {
      setState(() => _error = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          statusBarGradient(context),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ── الهيدر ────────────────────────────────────────────────────
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _neuBackBtn(context),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'إنشاء حساب',
                                  style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 16,
                                    fontFamily: 'Amiri')),
                              ),
                            ),
                            const SizedBox(width: 44),
                          ]),
                        Image.asset(
                          'assets/logo.png',
                          width: 180,
                          height: 180,
                        ),
                      ]))),

                const SizedBox(height: 4),

                // ── الفورم ────────────────────────────────────────────────────
                SlideTransition(
                  position: _formSlide,
                  child: FadeTransition(
                    opacity: _formFade,
                    child: Column(
                      children: [
                        // الاسم واللقب
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                hint: 'الاسم الأول',
                                ctrl: _firstCtrl,
                                icon: CupertinoIcons.person,
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'مطلوب'
                                    : null)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _field(
                                hint: 'اللقب',
                                ctrl: _lastCtrl,
                                icon: CupertinoIcons.person_2,
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'مطلوب'
                                    : null)),
                          ]),
                        const SizedBox(height: 10),

                        // الجنس
                        _buildGenderSelector(),
                        const SizedBox(height: 10),

                        // الإيميل
                        _field(
                          hint: 'البريد الإلكتروني',
                          ctrl: _emailCtrl,
                          icon: CupertinoIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'بريد غير صحيح'
                              : null),
                        const SizedBox(height: 10),

                        // كلمة السر
                        _field(
                          hint: 'كلمة السر',
                          ctrl: _passCtrl,
                          icon: CupertinoIcons.lock,
                          obscure: _obscurePass,
                          validator: (v) => (v == null || v.length < 8)
                              ? 'كلمة السر أقل من 8 أحرف'
                              : null,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            child: Icon(
                              _obscurePass
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye,
                              color: AppTheme.textGrey,
                              size: 20))),
                        const SizedBox(height: 10),

                        // تأكيد كلمة السر
                        _field(
                          hint: 'تأكيد كلمة السر',
                          ctrl: _confirmCtrl,
                          icon: CupertinoIcons.lock_shield,
                          obscure: _obscureConf,
                          validator: (v) => v != _passCtrl.text
                              ? 'كلمتا السر غير متطابقتين'
                              : null,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscureConf = !_obscureConf),
                            child: Icon(
                              _obscureConf
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye,
                              color: AppTheme.textGrey,
                              size: 20))),
                      ]))),

                const SizedBox(height: 16),

                // ── الزر + الخطأ ──────────────────────────────────────────────
                SlideTransition(
                  position: _btnSlide,
                  child: FadeTransition(
                    opacity: _btnFade,
                    child: Column(
                      children: [
                        if (_error != null) ...[
                          _ErrorBox(msg: _error!),
                          const SizedBox(height: 14),
                        ],
                        _GradientButton(
                          label: 'إنشاء الحساب',
                          isLoading: _isLoading,
                          onTap: _isLoading ? null : _register),
                        const SizedBox(height: 30),
                      ]))),
              ]))))])
              
            );
          
  }

  // ── ويدجت الجنس ──────────────────────────────────────────────────────────
  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'الجنس',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textGrey,
            fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Row(
          children: ['أنثى', 'ذكر'].map((g) {
            final sel = _gender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: sel ? AppTheme.primary : AppTheme.background,
                      gradient: sel
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.primary, AppTheme.accent])
                          : null,
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.4),
                                blurRadius: 10,
                                offset: Offset(0, 4)),
                            ]
                          : [
                              BoxShadow(
                                color: AppTheme.neumShadow.withOpacity(0.6),
                                blurRadius: 10,
                                offset: Offset(4, 4)),
                              BoxShadow(
                                color: AppTheme.neumShadow.withOpacity(0.6),
                                blurRadius: 10,
                                offset: Offset(-4, -4)),
                            ],
                      border: Border.all(
                        color: sel ? Colors.white.withOpacity(0.3) : AppTheme.primary.withOpacity(0.1))),
                  child: Text(
                    g,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: sel ? Colors.white : AppTheme.textDark,
                      fontFamily: 'Amiri')))));
          }).toList()),
      ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STEP 2 — شاشة رقم الهاتف (مع الشرح التوعوي)
// ══════════════════════════════════════════════════════════════════════════════
class PhoneScreen extends StatefulWidget {
  const PhoneScreen();
  @override
  State<PhoneScreen> createState() => PhoneScreenState();
}

class PhoneScreenState extends State<PhoneScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) {
      setState(() => _error = 'أدخل رقم هاتف صحيح (9 أرقام على الأقل)');
      return;
    }
    if (!RegExp(r'^(05|06|07)').hasMatch(phone)) {
      setState(() => _error = 'الرقم يجب أن يبدأ بـ 05 أو 06 أو 07');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('لم يتم العثور على الحساب');
      await ApiClient.put('/api/users/$uid', {'phone': phone});
      UserLocal.data ??= {};
      UserLocal.data!['phone'] = phone;
      await UserLocal.save();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LocationScreen()),
      );
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ، حاول مرة أخرى';
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // ── أيقونة + عنوان ────────────────────────────────────
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neumShadow.withOpacity(0.7),
                          blurRadius: 14,
                          offset: const Offset(5, 5)),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 14,
                          offset: Offset(-5, -5)),
                      ]),
                    child: const Icon(
                      CupertinoIcons.phone_fill,
                      color: AppTheme.primary,
                      size: 40)),
                  const SizedBox(height: 24),

                  Text(
                    'أدخل رقم هاتفك',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 12),

                  // ── بطاقة الشرح التوعوي ───────────────────────────────
                  _InfoCard(),
                  const SizedBox(height: 28),

                  // ── خانة الرقم ────────────────────────────────────────
                  _NeuField(
                    ctrl: _phoneCtrl,
                    hint: '05XXXXXXXX / 06XXXXXXXX / 07XXXXXXXX',
                    icon: CupertinoIcons.phone,
                    keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),

                  Text(
                    'أدخل رقمًا شغّالًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    _ErrorBox(msg: _error!),
                    const SizedBox(height: 16),
                  ],

                  _GradientButton(
                    label: 'تأكيد الرقم والمتابعة',
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _savePhone),
                  const SizedBox(height: 20),

                  // تخطي (مع تحذير)
                  const SizedBox(height: 30),
                ])))),
          ) ],
        ),
      ),
    );
  }
}

// ── بطاقة الشرح التوعوي ──────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary.withOpacity(0.08), AppTheme.accent.withOpacity(0.06)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15), width: 1.5)),
      child: Column(
        children: [
          // مراحل
          _InfoStep(
            icon: CupertinoIcons.phone_fill,
            color: const Color(0xFF4CAF50),
            title: 'المرة الأولى فقط',
            desc: 'أدخل رقمك لمرة واحدة فقط'),
          const SizedBox(height: 12),
          _InfoStep(
            icon: CupertinoIcons.shield_fill,
            color: AppTheme.primary,
            title: 'الرقم لا يختفي',
            desc: 'إذا أردت إخفاء رقمك تواصل مع المدير'),
          const SizedBox(height: 12),
          _InfoStep(
            icon: CupertinoIcons.eye_slash_fill,
            color: const Color(0xFFFF6D00),
            title: 'خصوصيتك مضمونة',
            desc: 'اكتب رقمًا شغلًا باش ترد على السائق أول طلبية'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: AppTheme.primary,
                  size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'الرقم المتخفى يحمي خصوصيتك في الطلبيات القادمة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Amiri'))),
              ])),
        ]));
  }
}

class _InfoStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _InfoStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  fontFamily: 'Amiri')),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGrey,
                  fontFamily: 'Amiri')),
            ])),
      ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STEP 3 — شاشة الموقع
// ══════════════════════════════════════════════════════════════════════════════
class LocationScreen extends StatefulWidget {
  const LocationScreen();
  @override
  State<LocationScreen> createState() => LocationScreenState();
}

class LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  final _labelCtrl = TextEditingController();
  String _selectedAddress = '';
  double? _selectedLat;
  double? _selectedLng;
  bool _isLoading = false;
  String? _error;
    String _cityAr = '';
String _cityFr = '';

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()));
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result['address'] ?? '';
        _selectedLat = result['lat'];
        _selectedLng = result['lng'];

      _cityAr = result['cityNameAr'] ?? ''; 
      _cityFr = result['cityNameFr'] ?? '';
      });
    }
  }

  String _cleanCityName(String address) {
    if (address.isEmpty) return address;
    return address.split(",").first.trim();
  }

  Future<void> _saveLocation() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'أدخل اسمًا للموقع (مثال: منزل، عمل...)');
      return;
    }
    if (_selectedAddress.isEmpty) {
      setState(() => _error = 'يرجى تحديد موقعك من الخريطة');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('الحساب غير موجود');
      final cityValue = _cityAr.isNotEmpty ? _cityAr : _cleanCityName(_selectedAddress);
      await ApiClient.put('/api/users/$uid', {
        'location': cityValue,
        'cityName': cityValue,
      });
      await ApiClient.post('/api/users/$uid/saved-locations', {
        'label': label,
        'address': _cleanCityName(_selectedAddress),
        'lat': _selectedLat,
        'lng': _selectedLng,
        'type': 'other',
        'cityNameAr': _cityAr,
        'cityNameFr': _cityFr,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      UserLocal.data ??= {};
      UserLocal.data!['location'] = cityValue;
      UserLocal.data!['cityName'] = cityValue;
      await UserLocal.save();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ أثناء الحفظ';
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            statusBarGradient(context),
            SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // ── أيقونة + عنوان
                    Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neumShadow.withOpacity(0.7),
                          blurRadius: 14,
                          offset: const Offset(5, 5)),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 14,
                          offset: Offset(-5, -5)),
                      ]),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                      child: const Icon(
                        CupertinoIcons.location_fill,
                        color: Colors.white,
                        size: 30))),
                  const SizedBox(height: 20),

                  Text(
                    'أين تريد التوصيل؟',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 6),
                  Text(
                    'خزّن موقعك الآن لتأكيد طلبياتك بسرعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 28),

                  // ── اسم الموقع ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'اسم الموقع *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textGrey,
                        fontFamily: 'Amiri'))),
                  const SizedBox(height: 8),
                  _NeuField(
                    ctrl: _labelCtrl,
                    hint: 'مثال: منزل، عمل، بيت عمي...',
                    icon: CupertinoIcons.tag),
                  const SizedBox(height: 8),
                  // اقتراحات سريعة
                  _QuickLabels(
                    onSelect: (label) {
                      _labelCtrl.text = label;
                      setState(() {});
                    }),
                  const SizedBox(height: 20),

                  // ── زر الخريطة ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'الموقع على الخريطة *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textGrey,
                        fontFamily: 'Amiri'))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickLocation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.background, Color(0xFFE6E4F0)]),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neumShadow.withOpacity(0.6),
                            blurRadius: 10,
                            offset: Offset(4, 4)),
                          const BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-4, -4)),
                        ],
                        border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
                      child: Row(
                        children: [
                          Icon(
                            _selectedAddress.isNotEmpty
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.map_pin_ellipse,
                            color: _selectedAddress.isNotEmpty
                                ? const Color(0xFF4CAF50)
                                : AppTheme.primary,
                            size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedAddress.isEmpty
                                  ? 'اضغط لتحديد موقعك على الخريطة'
                                  : _selectedAddress,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedAddress.isEmpty
                                    ? AppTheme.textGrey
                                    : AppTheme.textDark,
                                fontFamily: 'Amiri',
                                fontWeight: _selectedAddress.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.normal))),
                          if (_selectedAddress.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              'تغيير',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontFamily: 'Amiri',
                                fontWeight: FontWeight.bold)),
                          ],
                        ]))),

                  const SizedBox(height: 28),

                  if (_error != null) ...[
                    _ErrorBox(msg: _error!),
                    const SizedBox(height: 14),
                  ],

                  _GradientButton(
                    label: 'حفظ الموقع والبدء',
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _saveLocation,
                    icon: CupertinoIcons.location_fill),

                  const SizedBox(height: 16),

                  // تخطي
                  const SizedBox(height: 40),
                ])))),
           )],
        ),
      ),
    );
  }
}

// ── اقتراحات اسم الموقع ────────────────────────────────────────────────────
class _QuickLabels extends StatelessWidget {
  final Function(String) onSelect;
  const _QuickLabels({required this.onSelect});

  static const _labels = ['🏠 منزل', '💼 عمل', '🏫 دراسة', '👨‍👩‍👧 عائلة'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.map((label) {
        return GestureDetector(
          onTap: () => onSelect(label.substring(2).trim()),
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neumShadow.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(2, 2)),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 4,
                  offset: Offset(-2, -2)),
              ]),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textDark,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w600))));
      }).toList());
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── حقل إدخال نيومورفيك ───────────────────────────────────────────────────
class _NeuField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final bool hasError;

  const _NeuField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: hasError
            ? [
                BoxShadow(
                  color: AppTheme.error.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(3, 3)),
                BoxShadow(
                  color: AppTheme.error.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(-3, -3)),
              ]
            : [
                BoxShadow(
                  color: AppTheme.neumShadow.withOpacity(0.6),
                  blurRadius: 8,
                  offset: const Offset(3, 3)),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 8,
                  offset: Offset(-3, -3)),
              ]),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textDark,
          fontFamily: 'Amiri'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.textGrey,
            fontSize: 13,
            fontFamily: 'Amiri'),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16))));
  }
}

// ── حقل فورم نيومورفيك ────────────────────────────────────────────────────
Widget _field({
  required String hint,
  required TextEditingController ctrl,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
  bool obscure = false,
  Widget? suffix,
  String? Function(String?)? validator,
}) {
  return StatefulBuilder(
    builder: (context, setInner) {
      bool _obs = obscure;
      return FormField<String>(
        validator: validator,
        initialValue: ctrl.text,
        builder: (state) {
          final showRed = state.hasError;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: showRed
                      ? [
                          BoxShadow(
                            color: AppTheme.error.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(3, 3)),
                          BoxShadow(
                            color: AppTheme.error.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(-3, -3)),
                        ]
                      : [
                          BoxShadow(
                            color: AppTheme.neumShadow.withOpacity(0.6),
                            blurRadius: 10,
                            offset: const Offset(4, 4)),
                          BoxShadow(
                            color: AppTheme.neumShadow.withOpacity(0.6),
                            blurRadius: 10,
                            offset: const Offset(-4, -4)),
                        ]),
                child: TextFormField(
                  controller: ctrl,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: state.didChange,
                  validator: validator,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textDark,
                    fontFamily: 'Amiri'),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 13,
                      fontFamily: 'Amiri'),
                    prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
                    suffixIcon: suffix,
                    border: InputBorder.none,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16)))),
              if (showRed)
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 10),
                  child: Text(
                    state.errorText ?? '',
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 11,
                      fontFamily: 'Amiri'))),
            ]);
        });
    });
}

// ── زر التدرج ─────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  final IconData? icon;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [const Color(0xFF6D22AC), AppTheme.primary, AppTheme.accent],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft),
          boxShadow: [
            BoxShadow(
              color: (isLoading ? Colors.grey : AppTheme.primary).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
          ]),
        child: Stack(
          children: [
            // لمعة علوية
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.22),
                      Colors.transparent,
                    ])))),
            Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                      ])),
          ])));
  }
}

// ── صندوق الخطأ ───────────────────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: AppTheme.error,
            size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
                fontFamily: 'Amiri'))),
        ]));
  }
}


// ── زر الرجوع نيومورفيك ───────────────────────────────────────────────────
  Widget _neuBackBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neumShadow.withOpacity(0.6),
              blurRadius: 8,
              offset: const Offset(4, 4)),
            BoxShadow(
              color: AppTheme.neumShadow.withOpacity(0.6),
              blurRadius: 8,
              offset: const Offset(-4, -4)),
          ]),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: AppTheme.primary,
          size: 18)));
  }

// ── انتقال صفحة سلس ──────────────────────────────────────────────────────
Route _pageRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child)),
  transitionDuration: const Duration(milliseconds: 350));
