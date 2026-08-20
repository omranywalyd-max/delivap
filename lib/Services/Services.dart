// ══════════════════════════════════════════════════════════════════════════════
//  Services.dart — شاشة الخدمات المعاد تصميمها كاملاً
// ══════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/user_local.dart';
import 'delivery_screen.dart';
import '../theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ServicesScreen
// ══════════════════════════════════════════════════════════════════════════════
class ServicesScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLogin;
  ServicesScreen({super.key, this.onNavigateToLogin});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _requireAuth(VoidCallback action) {
    if (UserLocal.uid == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
          content: const Text('لازم تكون مسجل دخولك', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri', fontSize: 15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('رجوع', style: TextStyle(fontFamily: 'Amiri')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigateToLogin?.call();
              },
              child: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Amiri')),
            ),
          ],
        ),
      );
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true, 
      // إذا كنت تريد أن يمتد خلف الـ AppBar العلوي أيضاً، أضف السطر التالي:
      // extendBodyBehindAppBar: true, 

      body: Stack(
        children: [
          statusBarGradient(context),
          SafeArea(
            bottom: false, 
            child: FadeTransition(
              opacity: _pageFade,
              child: SlideTransition(
                position: _pageSlide,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([

                          // ── قسم الشحن والتوصيل ──────────────────────────
                         // ── قسم الشحن والتوصيل ──────────────────────────
_SectionTitle(title: 'شحن وتوصيل الطلبيات', icon: CupertinoIcons.cube_box_fill),
const SizedBox(height: 14),

_ServiceCard(
  index: 0,
  title: 'توصيل الطلبيات',
  subtitle: 'نوصل طلبيتك لباب دارك بسرعة وأمان',
  icon: CupertinoIcons.cube_box_fill,
  accentColor: AppTheme.primary,
  onTap: () => _requireAuth(() => Navigator.push(context, _slideRoute(
    const ServiceOrderScreen(serviceType: ServiceType.delivery, title: 'توصيل الطلبيات'))))),

const SizedBox(height: 14),

_ServiceCard(
  index: 1,
  title: 'إحضار الطلبيات',
  subtitle: 'نجيب طلبيتك من أي مكان لباب دارك',
  icon: CupertinoIcons.bag_fill,
  accentColor: const Color(0xFF283593),
  onTap: () => _requireAuth(() => Navigator.push(context, _slideRoute(
    const ServiceOrderScreen(serviceType: ServiceType.pickup, title: 'إحضار الطلبيات'))))),
                          const SizedBox(height: 30),

                          // ── قسم التنقل ──────────────────────────────────
                          _SectionTitle(title: 'خدمات التنقل', icon: CupertinoIcons.car_fill),
                          const SizedBox(height: 14),

                          _TransportCard(
                            index: 2,
                            title: 'طلب سيارة أجرة',
                            subtitle: 'اطلب تاكسي قريب منك في ثوانٍ',
                            icon: CupertinoIcons.car_fill,
                            accentColor: const Color(0xFFE65100),
                            onTap: () => _requireAuth(() => Navigator.push(context, _slideRoute(
                              const TransportOrderScreen(
                                serviceType: TransportType.taxi,
                                title: 'طلب سيارة أجرة'))))),

                          const SizedBox(height: 14),

                          _TransportCard(
                            index: 3,
                            title: 'طلب هاربين',
                            subtitle: 'لنقل الأثاث و الأجهزة',
                            icon: CupertinoIcons.bus,
                            accentColor: const Color(0xFF00695C),
                            onTap: () => _requireAuth(() => Navigator.push(context, _slideRoute(
                              const TransportOrderScreen(
                                serviceType: TransportType.minibus,
                                title: 'طلب هاربين'))))),

                          const SizedBox(height: 14),

                          _TransportCard(
                            index: 4,
                            title: 'طلب فورغو',
                            subtitle: 'لنقل الأثاث والبضائع الثقيلة',
                            icon: CupertinoIcons.cube_box,
                            accentColor: const Color(0xFF4527A0),
                            onTap: () => _requireAuth(() => Navigator.push(context, _slideRoute(
                              const TransportOrderScreen(
                                serviceType: TransportType.truck,
                                title: 'طلب فورغو'))))),

                          const SizedBox(height: 10),
                        ]))),
                  ]))))]),
        
      );
    
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'الخدمات',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                      fontFamily: 'Amiri')),
                  Container(
                    width: 55,
                    height: 3.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]))),
                ]),
            ]),
          const SizedBox(height: 8),
          Text(
            'اختر الخدمة التي تحتاجها',
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey, fontFamily: 'Amiri'),
            textAlign: TextAlign.right),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _SectionTitle
// ══════════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
            fontFamily: 'Amiri')),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.primary, size: 16)),
      ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ServiceCard — بطاقة توصيل / إحضار
// ══════════════════════════════════════════════════════════════════════════════
class _ServiceCard extends StatefulWidget {
  final int index;
  final String title, subtitle;
  final IconData icon;
  final Color accentColor; // اللون الذي سيميز الأيقونة
  final VoidCallback onTap;

  const _ServiceCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 130),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neumShadow.withOpacity(0.6),
                    blurRadius: 10,
                    offset: Offset(4, 4)),
                  BoxShadow(
                    color: const Color(0xFFD8D7DE),
                    blurRadius: 10,
                    offset: Offset(-4, -4)),
                ],
                border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(CupertinoIcons.chevron_left, color: widget.accentColor, size: 14)),

                    Expanded( 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.title,
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold,
                                color: AppTheme.textDark, fontFamily: 'Amiri')),
                            const SizedBox(height: 3),
                            Text(widget.subtitle,
                              style: const TextStyle(
                                fontSize: 11, color: AppTheme.textGrey, fontFamily: 'Amiri'),
                              textAlign: TextAlign.right),
                          ]))),

                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.accentColor, widget.accentColor.withOpacity(0.7)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.3),
                            blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Icon(widget.icon, color: Colors.white, size: 24)),
                  ])))))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _TransportCard — بطاقة التنقل (تاكسي / هارباني / فورغو)
// ══════════════════════════════════════════════════════════════════════════════
class _TransportCard extends StatefulWidget {
  final int index;
  final String title, subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _TransportCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_TransportCard> createState() => _TransportCardState();
}

class _TransportCardState extends State<_TransportCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 90), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 130),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neumShadow.withOpacity(0.6),
                    blurRadius: 10,
                    offset: Offset(4, 4)),
                  BoxShadow(
                    color: const Color(0xFFD8D7DE),
                    blurRadius: 10,
                    offset: Offset(-4, -4)),
                ],
                border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(CupertinoIcons.chevron_left, color: widget.accentColor, size: 14)),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold,
                              color: AppTheme.textDark, fontFamily: 'Amiri')),
                          const SizedBox(height: 3),
                          Text(widget.subtitle,
                            style: const TextStyle(
                              fontSize: 11, color: AppTheme.textGrey, fontFamily: 'Amiri'),
                            textAlign: TextAlign.right),
                        ]))),

                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.accentColor, widget.accentColor.withOpacity(0.7)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.4),
                          blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Icon(widget.icon, color: Colors.white, size: 24)),
                ]))))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Route helper
// ══════════════════════════════════════════════════════════════════════════════
Route _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child)),
  transitionDuration: const Duration(milliseconds: 350));