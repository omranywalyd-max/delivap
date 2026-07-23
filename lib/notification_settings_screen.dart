import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'driver_arrival_overlay.dart';
import 'user_local.dart';

const _kPrimary = Color(0xFF7D29C6);
const _kSecondary = Color(0xFF9232E8);
const _kBg = Color(0xFFF1F0F5);
const _kCard = Color(0xFFDCDAE6);
final _kNeumLight = Color(0xFFB8B1C8).withOpacity(0.6);
final _kNeumShadow = const Color(0xFFB8B1C8).withOpacity(0.6);
const _kText = Color(0xFF2D2A3A);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _disableSound = false;
  bool _disablePurchaseNotif = false;
  bool _enableDriverArrivalRing = false;
  bool _saving = false;

  static const _ringChannel = MethodChannel('com.deliv.customer/ringtone');

  @override
  void initState() {
    super.initState();
    final data = UserLocal.data;
    if (data != null && data['settings'] is Map) {
      final s = data['settings'] as Map;
      _disableSound = s['disableSound'] == true;
      _disablePurchaseNotif = s['disablePurchaseNotif'] == true;
      _enableDriverArrivalRing = s['enableDriverArrivalRing'] == true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = UserLocal.uid;
      if (uid == null) return;
      await ApiClient.put('/api/users/$uid', {
        'settings': {
          'disableSound': _disableSound,
          'disablePurchaseNotif': _disablePurchaseNotif,
          'enableDriverArrivalRing': _enableDriverArrivalRing,
        },
      });
      if (UserLocal.data != null) {
        UserLocal.data!['settings'] = {
          'disableSound': _disableSound,
          'disablePurchaseNotif': _disablePurchaseNotif,
          'enableDriverArrivalRing': _enableDriverArrivalRing,
        };
        UserLocal.save();
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الإعدادات', style: TextStyle(fontFamily: 'Amiri')),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e', style: const TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          title: const Text('إعدادات الإشعارات',
              style: TextStyle(fontFamily: 'Amiri')),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_right, color: _kPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildToggleCard(
                icon: CupertinoIcons.bell_slash_fill,
                title: 'إلغاء صوت الإشعارات',
                subtitle: 'إيقاف تشغيل الأصوات المخصصة للإشعارات',
                value: _disableSound,
                onChanged: (v) => setState(() {
                  _disableSound = v;
                  _save();
                }),
              ),
              const SizedBox(height: 16),
              _buildToggleCard(
                icon: CupertinoIcons.cart_badge_minus,
                title: 'إلغاء إشعارات تم شراء منتج',
                subtitle: 'إيقاف الإشعارات عند شراء السائق للمنتجات',
                value: _disablePurchaseNotif,
                onChanged: (v) => setState(() {
                  _disablePurchaseNotif = v;
                  _save();
                }),
              ),
              const SizedBox(height: 16),
              _buildToggleCard(
                icon: CupertinoIcons.alarm_fill,
                title: 'رنّة وصول السائق',
                subtitle: 'تشغيل رنة التلفون عندما يصل السائق',
                value: _enableDriverArrivalRing,
                onChanged: (v) async {
                  if (v) {
                    final hasPermission = await DriverArrivalOverlay.checkPermission();
                    if (!hasPermission) {
                      if (!mounted) return;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: _kNeumShadow, blurRadius: 12, offset: const Offset(4, 4)),
                                BoxShadow(color: _kNeumLight, blurRadius: 12, offset: const Offset(-4, -4)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(CupertinoIcons.bell_fill, color: _kPrimary, size: 36),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'رنّة وصول السائق',
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _kText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'عندما يصل السائق إلى موقع التوصيل، سيضغط على زر الرنّة في تطبيقه، وستظهر شاشة تنبيه كاملة على هاتفك مع رنّة الهاتف لتعلمك بوصوله.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 14,
                                    height: 1.8,
                                    color: _kText.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'يجب السماح للتطبيق بالظهور فوق التطبيقات الأخرى',
                                          style: TextStyle(
                                            fontFamily: 'Amiri',
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(ctx, false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'لاحقاً',
                                              style: TextStyle(
                                                fontFamily: 'Amiri',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(ctx, true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF7D29C6), Color(0xFF9232E8)],
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'تفعيل الآن',
                                              style: TextStyle(
                                                fontFamily: 'Amiri',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (confirm == true) {
                        await DriverArrivalOverlay.requestPermission();
                      } else {
                        return;
                      }
                    }
                  }
                  setState(() {
                    _enableDriverArrivalRing = v;
                    _save();
                  });
                },
              ),
              const SizedBox(height: 32),
              if (_saving)
                const CupertinoActivityIndicator(color: _kPrimary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _kNeumShadow,
              blurRadius: 10,
              offset: const Offset(4, 4)),
          BoxShadow(
              color: _kNeumLight,
              blurRadius: 10,
              offset: const Offset(-4, -4)),
        ],
        border: Border.all(color: _kPrimary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(icon, color: value ? _kPrimary : Colors.grey, size: 22),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _kText,
                              fontFamily: 'Amiri')),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: _kText.withOpacity(0.6),
                              fontFamily: 'Amiri')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: _kPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
