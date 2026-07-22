import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Sign Up/Sign_Up.dart';
import '../Sign in/auth_service.dart';
import '../Order/order_models.dart';
import '../Services/api_client.dart';
import '../user_local.dart';
import '../theme.dart';
import '../main_page.dart';

// ------------------------------------------------------------------------------
//  ???? ?????? ????? (???? ?????)
// ------------------------------------------------------------------------------
class GenderScreen extends StatefulWidget {
  final String uid;
  const GenderScreen({required this.uid});

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen>
    with SingleTickerProviderStateMixin {
  String? _selected;
  bool _loading = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    try {
      await ApiClient.put('/api/users/${widget.uid}', {'gender': _selected});
      UserLocal.data ??= {};
      UserLocal.data!['gender'] = _selected;
      await UserLocal.save();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneScreen()),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '??? ???? ???? ??? ????',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Amiri'),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                    // ??????
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
                            offset: const Offset(5, 5),
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            blurRadius: 14,
                            offset: Offset(-5, -5),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_crop_circle,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
          const SizedBox(height: 14),
                    const Text(
                      '???? ????',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                        fontFamily: 'Amiri',
                      ),
                    ),
          const SizedBox(height: 10),

                    const Text(
                      '?????? ????? ??? ????? ?????',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ????? ?????
                    Row(
                      children: ['???', '????'].map((g) {
                        final sel = _selected == g;
                        final isM = g == '???';
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: sel ? AppTheme.primary : null,
                                gradient: sel
                                    ? null
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [AppTheme.background, Color(0xFFE6E4F0)],
                                      ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withOpacity(0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: AppTheme.neumShadow.withOpacity(0.6),
                                          blurRadius: 10,
                                          offset: const Offset(4, 4),
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 10,
                                          offset: const Offset(-4, -4),
                                        ),
                                      ],
                                border: sel
                                    ? null
                                    : Border.all(
                                        color: AppTheme.primary.withOpacity(0.1),
                                      ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    isM
                                        ? CupertinoIcons.person_fill
                                        : CupertinoIcons
                                              .person_crop_circle_fill_badge_checkmark,
                                    color: sel ? Colors.white : AppTheme.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    g,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: sel ? Colors.white : AppTheme.textDark,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    // ?? ???????
                    GestureDetector(
                      onTap: (_selected == null || _loading) ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: _selected == null
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [AppTheme.primary, AppTheme.accent],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                          boxShadow: _selected != null
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  '????? ?????????',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
           )],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  SignInScreen
// ------------------------------------------------------------------------------
class SignInScreen extends StatefulWidget {
  final bool standaloneMode;
  const SignInScreen({super.key, this.standaloneMode = false});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController, _formController;
  late Animation<Offset> _titleSlide, _formSlide;
  late Animation<double> _titleFade, _formFade;

  @override
  void initState() {
    super.initState();
    // ?? ??????? listener ??? — MainPage ??? StreamBuilder<User?>
    // ?????? ??? ????? ???? ProfileGate ??? ????? ??????

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _titleSlide = _slide(_headerController, const Offset(0, -0.6));
    _formSlide = _slide(_formController, const Offset(0, 0.4));
    _titleFade = _fade(_headerController);
    _formFade = _fade(_formController);

    _playSequence();
  }

  Animation<Offset> _slide(AnimationController c, Offset begin) =>
      Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));

  Animation<double> _fade(AnimationController c) => Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  Future<void> _playSequence() async {
    if (!mounted) return;
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _formController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _formController.dispose();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    if (widget.standaloneMode) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 3)),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          statusBarGradient(context),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 10),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formFade,
                          child: _SignForm(onSuccess: _goHome),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _openPrivacyPolicy(context),
                    child: const Text(
                      '????? ????????',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 12,
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  void _openPrivacyPolicy(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final url = locale == 'ar'
        ? 'https://delivap.com/privacy/privacy-policy-ar.html'
        : 'https://delivap.com/privacy/privacy-policy.html';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ------------------------------------------------------------------------------
//  _SignForm
// ------------------------------------------------------------------------------
class _SignForm extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SignForm({required this.onSuccess});

  @override
  State<_SignForm> createState() => _SignFormState();
}

class _SignFormState extends State<_SignForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _submitted = false;
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      // ? ProfileGate ????? ?????? (???? ???????? ?? Firestore ?????)
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e.code));
    } catch (_) {
      setState(() => _error = '??? ??? ??? ?????');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _field({required Widget child, bool err = false}) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.symmetric(vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: err
              ? Colors.redAccent.withOpacity(0.35)
              : AppTheme.neumShadow.withOpacity(0.6),
          offset: const Offset(4, 4),
          blurRadius: 8,
        ),
        BoxShadow(
          color: err
              ? Colors.redAccent.withOpacity(0.15)
              : AppTheme.neumShadow.withOpacity(0.6),
          offset: const Offset(-4, -4),
          blurRadius: 8,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: child,
    ),

  );
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          FormField<String>(
            validator: (v) =>
                (v == null || !v.contains('@')) ? '?????? ??? ????' : null,
            builder: (s) => _field(
              err: s.hasError && (_submitted || !s.isValid),
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.right,
                textDirection: TextDirection.ltr,
                onChanged: (v) => s.didChange(v),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  hintText: '?????? ??????????',
                  hintStyle: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.mail,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  errorStyle: TextStyle(height: 0, fontSize: 0),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FormField<String>(
            validator: (v) =>
                (v == null || v.length < 6) ? '???? ???? ?????' : null,
            builder: (s) => _field(
              err: s.hasError && (_submitted || !s.isValid),
              child: TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                textAlign: TextAlign.right,
                onChanged: (v) => s.didChange(v),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: '???? ????',
                  hintStyle: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                  prefixIcon: const Icon(
                    CupertinoIcons.lock,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                      color: AppTheme.textGrey,
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              onTap: () => _showForgotPassword(context),
              child: const Text(
                '???? ???? ?????',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            _ErrorBox(message: _error!),
            const SizedBox(height: 12),
          ],
          _GradientButton(
            label: '????? ??????',
            isLoading: _isLoading,
            onTap: _isLoading ? null : _signIn,
          ),
          const SizedBox(height: 30),
          _SocialSection(onSuccess: widget.onSuccess),
        ],
      ),
    );
  }

  void _showForgotPassword(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '???? ???? ?????',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '???? ????? ?????? ?? ???? ????? ???????',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neumShadow.withOpacity(0.6),
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: AppTheme.neumShadow.withOpacity(0.6),
                    offset: const Offset(-3, -3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: ctrl,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: '?????? ??????????',
                  hintStyle: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.mail,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('?????', style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (!ctrl.text.contains('@')) return;
              try {
                await AuthService.sendPasswordReset(ctrl.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Text(
                        '?? ????? ?????? ?',
                        textAlign: TextAlign.right,
                      ),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (_) { /* ignored */ }
            },
            child: const Text('?????', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------
//  _SocialSection
// ------------------------------------------------------------------------------
class _SocialSection extends StatefulWidget {
  final VoidCallback onSuccess;
  const _SocialSection({required this.onSuccess});

  @override
  State<_SocialSection> createState() => _SocialSectionState();
}

class _SocialSectionState extends State<_SocialSection> {
  bool _googleLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e.code));
    } catch (e) {
      if (!e.toString().toLowerCase().contains('cancel')) {
        setState(() => _error = '??? ????? ?????? ?? Google');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (_error != null) ...[
          _ErrorBox(message: _error!),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              iconPath: 'assets/icons/google.png',
              isLoading: _googleLoading,
              onTap: _googleLoading ? null : _signInWithGoogle,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _NoAccountText(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ------------------------------------------------------------------------------
//  Shared Widgets
// ------------------------------------------------------------------------------
class _SocialButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback? onTap;
  final bool isLoading;
  const _SocialButton({
    required this.iconPath,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: AppTheme.background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.neumShadow.withOpacity(0.6),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: AppTheme.neumShadow.withOpacity(0.6),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            )
          : Image.asset(iconPath, fit: BoxFit.contain),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  const _GradientButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isLoading
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : const [
                  Color(0xFF9232E8),
                  Color(0xFF7D29C6),
                  Color(0xFF6D22AC),
                ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D29C6).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.redAccent.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_circle,
          color: Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _NoAccountText extends StatelessWidget {
  const _NoAccountText();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        ),
        child: const Text(
          '????? ????',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const Text(
        '  ??? ???? ?????',
        style: TextStyle(fontSize: 15, color: AppTheme.textGrey),
      ),
    ],
  );
}
