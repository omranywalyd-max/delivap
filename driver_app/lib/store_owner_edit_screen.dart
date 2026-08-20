import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dashbord/services/api_client.dart';

const Color _kPrimary = Color(0xFF5B0094);
const Color _kBg = Color(0xFFE8E6F0);

class StoreOwnerEditScreen extends StatefulWidget {
  final Map<String, dynamic> ownerData;
  const StoreOwnerEditScreen({super.key, required this.ownerData});

  @override
  State<StoreOwnerEditScreen> createState() => _StoreOwnerEditScreenState();
}

class _StoreOwnerEditScreenState extends State<StoreOwnerEditScreen> {
  late TextEditingController _usernameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _storeNameCtrl;
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  bool _fetching = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.ownerData['username'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.ownerData['phone'] ?? '');
    _storeNameCtrl = TextEditingController(text: widget.ownerData['storeName'] ?? '');
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final uid = widget.ownerData['uid'] as String?;
      final id = widget.ownerData['_id'] as String?;
      final targetId = uid ?? id;
      if (targetId == null) return;
      final fresh = await ApiClient.get('/api/users/$targetId');
      if (fresh.isNotEmpty && mounted) {
        setState(() {
          _usernameCtrl.text = fresh['username'] ?? _usernameCtrl.text;
          _phoneCtrl.text = fresh['phone'] ?? _phoneCtrl.text;
          _storeNameCtrl.text = fresh['storeName'] ?? _storeNameCtrl.text;
          _fetching = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _fetching = false);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _storeNameCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String title, String msg, Color color) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold)),
        content: Padding(padding: const EdgeInsets.only(top: 10), child: Text(msg, style: const TextStyle(fontFamily: 'Amiri', fontSize: 14))),
        actions: [
          CupertinoDialogAction(child: Text("حسناً", style: TextStyle(fontFamily: 'Amiri', color: color)), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final storeName = _storeNameCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (username.isEmpty) {
      _showMsg("تنبيه", "يرجى إدخال اسم المستخدم", Colors.red);
      return;
    }
    if (storeName.isEmpty) {
      _showMsg("تنبيه", "يرجى إدخال اسم المحل", Colors.red);
      return;
    }
    if (phone.isEmpty || phone.length < 9) {
      _showMsg("تنبيه", "يرجى إدخال رقم هاتف صحيح", Colors.red);
      return;
    }
    if (newPass.isNotEmpty && newPass.length < 6) {
      _showMsg("تنبيه", "كلمة السر يجب أن تكون 6 أحرف على الأقل", Colors.red);
      return;
    }
    if (newPass != confirmPass) {
      _showMsg("تنبيه", "كلمتا السر غير متطابقتين", Colors.red);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = widget.ownerData['uid'] as String?;
      final id = widget.ownerData['_id'] as String?;
      final targetId = uid ?? id;
      if (targetId == null) {
        _showMsg("خطأ", "خطأ في بيانات الحساب", Colors.red);
        return;
      }

      final oldUsername = (widget.ownerData['username'] ?? '').toString().toLowerCase();
      if (username.toLowerCase() != oldUsername) {
        final users = await ApiClient.getList('/api/users');
        final exists = users.any((u) {
          final doc = u as Map<String, dynamic>;
          return (doc['username'] as String? ?? '').toLowerCase() == username.toLowerCase();
        });
        if (exists) {
          _showMsg("تنبيه", "اسم المستخدم \"$username\" محجوز بالفعل", Colors.red);
          return;
        }
      }

      final updateData = <String, dynamic>{
        'username': username,
        'phone': phone,
        'storeName': storeName,
      };
      if (newPass.isNotEmpty) {
        updateData['password'] = newPass;
      }
      await ApiClient.put('/api/users/$targetId', updateData);

      final prefs = await SharedPreferences.getInstance();
      final freshData = await ApiClient.get('/api/users/$targetId');
      if (freshData.isNotEmpty) {
        await prefs.setString('ownerData', jsonEncode(freshData));
      }

      if (mounted) {
        _showMsg("تم", "تم حفظ التعديلات بنجاح", Colors.green);
      }
    } catch (e) {
      _showMsg("خطأ", "حدث خطأ: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, color: _kPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تعديل الحساب', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 16)),
      ),
      body: _fetching
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _sectionTitle('اسم المستخدم'),
            _inputField(_usernameCtrl, 'اسم المستخدم', CupertinoIcons.person),
            const SizedBox(height: 20),
            _sectionTitle('اسم المحل'),
            _inputField(_storeNameCtrl, 'اسم المحل', CupertinoIcons.building_2_fill),
            const SizedBox(height: 20),
            _sectionTitle('رقم الهاتف'),
            _inputField(_phoneCtrl, 'رقم الهاتف', CupertinoIcons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _sectionTitle('كلمة السر الجديدة'),
            _inputField(_newPassCtrl, 'كلمة السر الجديدة', CupertinoIcons.lock, obscure: _obscureNew, suffix: GestureDetector(
              onTap: () => setState(() => _obscureNew = !_obscureNew),
              child: Icon(_obscureNew ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: Colors.grey, size: 18),
            )),
            const SizedBox(height: 12),
            _inputField(_confirmPassCtrl, 'تأكيد كلمة السر', CupertinoIcons.lock_fill, obscure: _obscureConfirm, suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(_obscureConfirm ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: Colors.grey, size: 18),
            )),
            const SizedBox(height: 10),
            Text('اتركها فارغة إذا لا تريد تغيير كلمة السر', style: TextStyle(fontSize: 11, fontFamily: 'Amiri', color: Colors.grey.shade500)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontFamily: 'Amiri', fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: _kPrimary, fontSize: 13)),
  );

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyboardType, bool obscure = false, Widget? suffix}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.3), offset: const Offset(2,2), blurRadius: 6)],
    ),
    child: TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Amiri', color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: _kPrimary, size: 18),
        suffixIcon: suffix,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}
