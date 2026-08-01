import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class BottomNavBar extends StatelessWidget {
  final Function(int) onTabChange;
  final int selectedIndex;

  const BottomNavBar({
    super.key,
    required this.onTabChange,
    required this.selectedIndex,
  });

  @override
Widget build(BuildContext context) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          // ✅ 1. تدرج ألوان من اليمين لليسار مع "لمعة" في الوسط
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              const Color(0xFF9232E8),
              const Color(0xFF7D29C6),
              const Color(0xFF6D22AC),
            ],
          ),

          borderRadius: BorderRadius.circular(30),
          
          // ✅ 2. إطار خفيف جداً أبيض يعطي تأثير "حافة الزجاج" (Glossy edge)
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),

          boxShadow: [
            // ✅ 3. ظل ملون متوهج (Glow) بدلاً من الظل الرمادي العادي
            BoxShadow(
              color: const Color(0xFF7D29C6).withOpacity(0.4),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
            // لمعة علوية خفيفة
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              offset: const Offset(-2, -2),
              blurRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: GNav(
          selectedIndex: selectedIndex,
          onTabChange: onTabChange,
          rippleColor: Colors.white.withOpacity(0.2),
          hoverColor: Colors.white.withOpacity(0.1),
          gap: 8,
          activeColor: Colors.white,
          iconSize: 22,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          duration: const Duration(milliseconds: 400),
          color: Colors.white.withOpacity(0.5),
          
          // ✅ خلفية التبويب المختار بلمعة بيضاء خفيفة
          tabBackgroundColor: Colors.white.withOpacity(0.15),

          tabs: [
            const GButton(icon: Icons.home_rounded, text: 'الرئيسية'),
            const GButton(icon: Icons.grid_view_rounded, text: 'الخدمـات'),
            const GButton(icon: Icons.shopping_bag_rounded, text: 'الطلبـيات'),
            const GButton(icon: Icons.person_rounded, text: 'الحسـاب'),
          ],
        ),
      ),
    ),
  );
}
}
