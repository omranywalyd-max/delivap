import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';
import 'bottom_nav.dart';
import 'dashboard_screen.dart';
import 'Sign in/sign_in.dart';
import 'Sign Up/Sign_Up.dart';
import 'user_local.dart';
import 'Order/Order.dart';
import 'Services/Services.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

class MainPage extends StatefulWidget {
  final int initialIndex; 
  const MainPage({super.key, this.initialIndex = 0});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int currentIndex;
  String? _currentUid;
  bool _checkedMessages = false;
  bool _bannedHandled = false;
  bool _deactivatedHandled = false;
  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    SocketClient.init();
    SocketClient.on('user:updated', _onUserUpdated);
    SocketClient.on('user:deleted', _onUserDeleted);
  }

  void _onUserUpdated(data) {
    if (mounted && data is Map<String, dynamic> && data['uid'] == _currentUid) {
      setState(() {});
    }
  }

  void _onUserDeleted(data) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceLogout('تم حذف حسابك من قبل الإدارة');
      });
    }
  }

  Future<void> _forceLogout(String message) async {
    UserLocal.clearError();
    await FirebaseAuth.instance.signOut();
    await UserLocal.clear();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تم حذف الحساب', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Amiri')),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    SocketClient.off('user:updated', _onUserUpdated);
    SocketClient.off('user:deleted', _onUserDeleted);
    super.dispose();
  }

  Future<void> _refreshUserFromServer(String uid) async {
    try {
      await UserLocal.load(uid);
      if (mounted) {
        if (UserLocal.loadError == 'تم حذف حسابك') {
          _forceLogout(UserLocal.loadError!);
          return;
        }
        setState(() {});
      }
      SocketClient.join('user_$uid');
    } catch (e) {
    }
  }

  void _checkBanAndActive() {
    if (_currentUid == null) return;
    if (UserLocal.isIpBanned && !_bannedHandled) {
      _bannedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBannedDialog());
      return;
    }
    final data = UserLocal.data;
    if (data == null) return;

    if (data['isActive'] == null) return;

    final isBanned = data['isBanned'] == true;
    final isActive = data['isActive'] == true;

    if (isBanned && !_bannedHandled) {
      _bannedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBannedDialog());
      return;
    }

    if (!isActive && !_deactivatedHandled) {
      _deactivatedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDeactivatedDialog());
      return;
    }
  }

  void _showBannedDialog() {
    final isIpBan = UserLocal.isIpBanned;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isIpBan ? Icons.gpp_bad : Icons.block, color: isIpBan ? Colors.red : Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(isIpBan ? 'تم حظر جهازك' : 'تم حظر حسابك',
              style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Text(
          isIpBan
              ? 'عذراً، تم حظر جهازك بالكامل.\nلا يمكنك استخدام التطبيق.'
              : 'عذراً، تم حظر حسابك.\nلا يمكنك استخدام التطبيق حالياً.\nيمكنك التواصل مع الإدارة للمساعدة.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri', fontSize: 14, color: Colors.black87),
        ),
        actions: [
          if (!isIpBan)
            ElevatedButton(
              onPressed: () async {
                UserLocal.clearError();
                await FirebaseAuth.instance.signOut();
                await UserLocal.clear();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
            ),
          if (!isIpBan)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openChatAsDialog();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2A3A)),
              child: const Text('التحدث مع الادمن', style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
            ),
          if (isIpBan)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Amiri', color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  void _showDeactivatedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('حسابك غير مفعل', style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        content: const Text(
          'تم تعطيل حسابك. لا يمكنك استخدام خدمات التطبيق حالياً.\nيمكنك التواصل مع الإدارة عبر المحادثة المباشرة.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Amiri', fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              UserLocal.clearError();
              await FirebaseAuth.instance.signOut();
              await UserLocal.clear();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Amiri', color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openChatAsDialog();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2A3A)),
            child: const Text('محادثة الإدارة', style: TextStyle(fontFamily: 'Amiri', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openChatAsDialog() {
    if (_currentUid == null) return;
    final data = UserLocal.data;
    final name = data != null ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim() : null;
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: MessagesScreen(
            userId: _currentUid!,
            userName: name?.isNotEmpty == true ? name : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          _currentUid = null;
          return _signedOutLayout();
        }
        if (_currentUid != user.uid) {
          _currentUid = user.uid;
          _refreshUserFromServer(user.uid);
        }
        return _signedInLayout(user);
      },
    );
  }

  Widget _signedOutLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: [
          const DashboardScreen(),
          ServicesScreen(onNavigateToLogin: () => setState(() => currentIndex = 3)),
          const OrdersScreen(),
          const SignInScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: currentIndex,
        onTabChange: (index) => setState(() => currentIndex = index),
      ),
    );
  }

  Widget _signedInLayout(User user) {
    if (UserLocal.loadError == 'تم حذف حسابك') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _forceLogout(UserLocal.loadError!));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (UserLocal.isIpBanned) {
      _checkBanAndActive();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (UserLocal.loadError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const SizedBox(height: 8),
                  Text(
                  UserLocal.loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    UserLocal.clearError();
                    await FirebaseAuth.instance.signOut();
                    await UserLocal.clear();
                  },
                  child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Amiri')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = UserLocal.data;
    if (data == null || data.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _checkBanAndActive();

    final isBanned = data['isBanned'] == true;
    final isActive = data['isActive'] == true;

    String val(String key) => (data[key] ?? '').toString().trim();
    final gender = val('gender');
    final phone = val('phone');
    final location = val('location');

    if (isBanned || !isActive) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gender.isEmpty) return GenderScreen(uid: user.uid);
    if (phone.isEmpty) return const PhoneScreen();
    if (location.isEmpty) return const LocationScreen();
    return _fullAppLayout();
  }

  Widget _fullAppLayout() {
    if (!_checkedMessages && _currentUid != null) {
      _checkedMessages = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdminMessages());
    }
    return Scaffold(
      backgroundColor: Colors.grey[300],
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: [
          const DashboardScreen(),
          ServicesScreen(),
          const OrdersScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: currentIndex,
        onTabChange: (index) => setState(() => currentIndex = index),
      ),
    );
  }

  Future<void> _checkAdminMessages() async {
    if (_currentUid == null) return;
    try {
      final msgs = await ApiClient.getList('/api/users/$_currentUid/messages');
      if (!mounted || msgs.isEmpty) return;
      if (msgs.any((m) => m is Map && m['from'] == 'admin' && m['read'] == false)) {
        _openChatAsDialog();
      }
    } catch (_) {}
  }
}