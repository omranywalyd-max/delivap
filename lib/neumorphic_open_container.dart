// neumorphic_open_container.dart

import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

class NeumorphicOpenContainer extends StatelessWidget {
  // الودجت الذي سيتم عرضه في القائمة (البطاقة المغلقة)
  final Widget closedWidget;
  // الودجت الذي سيتم الانتقال إليه (الصفحة المفتوحة)
  final Widget openWidget;
  // الدالة التي يتم استدعاؤها عند الضغط (لأي إجراء إضافي إذا لزم الأمر)
  final VoidCallback? onTap;

  const NeumorphicOpenContainer({
    super.key,
    required this.closedWidget,
    required this.openWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      // نوع الانتقال الذي يعطي تأثير "الانبثاق" والتحول
      transitionType: ContainerTransitionType.fadeThrough,

      // الإعدادات الضرورية لضمان ظهور الظل النيومورفي للكارد المغلق
      closedElevation: 0.0,
      closedColor:
          Colors.transparent, // لجعل لون خلفية الـ OpenContainer شفافاً
      // الـ closedBuilder: يغلف الودجت المغلق الذي مررناه
      closedBuilder: (context, action) {
        return GestureDetector(
          onTap: () {
            // تنفيذ أي إجراء إضافي قبل الانتقال إذا تم تحديده
            if (onTap != null) {
              onTap!();
            }
            // تشغيل الـ OpenContainer action للانتقال
            action();
          },
          child: closedWidget,
        );
      },

      // الـ openBuilder: يفتح الصفحة الجديدة
      openBuilder: (context, action) {
        return openWidget;
      },
    );
  }
}
