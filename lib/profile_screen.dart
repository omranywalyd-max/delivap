import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/Services/delivery_screen.dart';
import 'package:flutter_application_1/main_page.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'package:flutter_application_1/Services/socket_client.dart';
import 'package:flutter_application_1/Order/order_models.dart';
import 'package:flutter_application_1/notification_settings_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'user_local.dart';
import 'Sign in/auth_service.dart';

// -- Colors (??? ?????????) ----------------------------------------------------
const _kPrimary = Color(0xFF7D29C6);
const _kSecondary = Color(0xFF9232E8);
const _kBg = Color(0xFFF1F0F5);
const _kCard = Color(0xFFDCDAE6);
final _kNeumLight = Color(0xFFB8B1C8).withOpacity(0.6);
final _kNeumShadow = const Color(0xFFB8B1C8).withOpacity(0.6);
const _kText = Color(0xFF2D2A3A);
const _kSuccess = Color(0xFF27AE60); // ?? ????? ????? ??????

// ------------------------------------------------------------------------------
//  ProfileScreen
// ------------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _savedLocations = [];
  final Map<String, String> _driverNames = {};
  DateTime _lastRefresh = DateTime.now();

  // -- Animations -----------------------------------------------------------
  late AnimationController _headerCtrl, _cardsCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late List<Animation<Offset>> _cardSlides;
  late List<Animation<double>> _cardFades;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _cardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900));
    _cardSlides = List.generate(5, (i) {
      final start = (0.2 + i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.4),
        end: Offset.zero).animate(
        CurvedAnimation(
          parent: _cardsCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic)));
    });
    _cardFades = List.generate(5, (i) {
      final start = (0.2 + i * 0.12).clamp(0.0, 1.0);
      final end = (start + 0.3).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _cardsCtrl,
        curve: Interval(start, end, curve: Curves.easeOut));
    });

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsCtrl.forward();
    });

    SocketClient.init();
    SocketClient.on('user:updated', _onUserUpdated);
    _loadUser().then((_) => _lastRefresh = DateTime.now());
    _loadSavedLocations();
  }

  void _onUserUpdated(_) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final data = Map<String, dynamic>.from(await ApiClient.get('/api/users/$uid'));
        if (UserLocal.data != null) {
          UserLocal.data!.forEach((k, v) {
            if (v is String && v.toString().trim().isNotEmpty && (data[k] == null || data[k].toString().trim().isEmpty)) {
              data[k] = v;
            }
          });
        }
        if (mounted) setState(() => _userData = data);
      }
    } catch (e) {
      if (UserLocal.data != null && mounted) {
        setState(() => _userData = UserLocal.data);
      }
    }
    _loadDriverNames();
  }

  Future<void> _loadDriverNames() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _userData == null) return;
    final loyalty = _userData!['driverLoyalty'] as Map<String, dynamic>? ?? {};
    final freeDel = _userData!['driverFreeDelivery'] as Map<String, dynamic>? ?? {};
    final driverIds = {...loyalty.keys, ...freeDel.keys};
    if (driverIds.isEmpty) return;
    final toRemove = <String>[];
    for (final id in driverIds) {
      if (_driverNames.containsKey(id)) continue;
      try {
        final d = await ApiClient.get('/api/drivers/$id');
        if (d.isNotEmpty) {
          final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
          _driverNames[id] = name.isNotEmpty ? name : '????';
        } else {
          _driverNames[id] = '????';
        }
      } catch (_) {
        _driverNames[id] = '????';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedLocations() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final list = await ApiClient.getList('/api/saved-locations?userId=$uid');
        if (mounted) setState(() => _savedLocations = list.cast<Map<String, dynamic>>());
      }
    } catch (_) { /* ignored */ }
  }

  @override
  void dispose() {
    SocketClient.off('user:updated', _onUserUpdated);
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  // -- Neumorphic box --------------------------------------------------------
  BoxDecoration _neuDeco({bool inset = false, double radius = 20}) =>
      BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: inset
            ? [
                BoxShadow(
                  color: _kNeumShadow,
                  blurRadius: 8,
                  offset: const Offset(4, 4)),
                BoxShadow(
                  color: _kNeumLight,
                  blurRadius: 8,
                  offset: Offset(-4, -4)),
              ]
            : [
                BoxShadow(
                  color: _kNeumShadow,
                  blurRadius: 10,
                  offset: const Offset(4, 4)),
                BoxShadow(
                  color: _kNeumLight,
                  blurRadius: 10,
                  offset: Offset(-4, -4)),
              ]);

  BoxDecoration _cardGradientDeco({double radius = 20}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
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
    border: Border.all(color: _kPrimary.withOpacity(0.1)));

  Widget _card(Widget child, {double radius = 20, EdgeInsets? padding}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: _cardGradientDeco(radius: radius),
        child: child);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      extendBody: true,
      body: Stack(
        children: [
          statusBarGradient(context),
          SafeArea(
            bottom: false,
            child: user == null
                ? _notLoggedIn()
                : _userData == null
                    ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                    : _buildBody(user, _userData!)),
        ],
      ),
    );
  }

  Widget _buildBody(User user, Map<String, dynamic> data) {
    var firstName = data['firstName'] as String? ?? '';
    var lastName = data['lastName'] as String? ?? '';
    if (firstName.isEmpty && lastName.isEmpty && user.displayName != null && user.displayName!.isNotEmpty) {
      final parts = user.displayName!.split(' ');
      firstName = parts.first;
      lastName = parts.skip(1).join(' ');
    }
    final phone = data['phone'] as String? ?? '';
    final email = data['email'] as String? ?? user.email ?? '';
    final gender = data['gender'] as String? ?? '';
    final photoUrl = data['photoUrl'] as String? ?? '';

    final fullName = [
      firstName,
      lastName,
    ].where((s) => s.isNotEmpty).join(' ');

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUser();
        _loadSavedLocations();
        if (mounted) setState(() => _lastRefresh = DateTime.now());
      },
      color: const Color(0xFF7D29C6),
      child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // -- Header ----------------------------------------
        SliverToBoxAdapter(
          child: SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerFade,
              child: _buildHeader(
                context,
                fullName: fullName,
                email: email,
                gender: gender,
                photoUrl: photoUrl,
                user: user)))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _animCard(0, _buildDriversLoyaltyCard()),
              const SizedBox(height: 16),
              _animCard(1, _card(_buildInfoSection(phone: phone, email: email, gender: gender))),
              const SizedBox(height: 16),
              _animCard(2, _buildLocationsCard(user.uid)),
              const SizedBox(height: 16),
              _animCard(3, _buildActionsCard(context, user)),
              const SizedBox(height: 12),
              _buildLastRefresh(),
            ]))),
      ]));
  }

  Widget _animCard(int i, Widget child) => SlideTransition(
    position: _cardSlides[i],
    child: FadeTransition(opacity: _cardFades[i], child: child));

  // ----------------------------------------------------------------------
  //  ???? ?????? ???????? (?????? ????????) ?
  // ----------------------------------------------------------------------
  Widget _buildDriversLoyaltyCard() {
    final loyalty = _userData?['driverLoyalty'] as Map<String, dynamic>? ?? {};
    final freeDel = _userData?['driverFreeDelivery'] as Map<String, dynamic>? ?? {};
    final driverIds = {...loyalty.keys, ...freeDel.keys}.toList();
    final readyCount = freeDel.values.where((v) => v == true).length;

    // ???? ???? ??? ?? ???????? (??? ????? preview ????)
    int bestProgress = 0;
    for (final id in driverIds) {
      final c = (loyalty[id] as num?)?.toInt() ?? 0;
      if (freeDel[id] == true) {
        bestProgress = 5;
        break;
      }
      if (c > bestProgress) bestProgress = c;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriversLoyaltyPage(
              userData: _userData!,
              driverNames: _driverNames,
            )));
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimary, _kSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
          ]),
        child: Stack(
          children: [
            Positioned(
              top: -16,
              left: -16,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.chevron_left,
                    color: Colors.white.withOpacity(0.7), size: 16),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('?????? ????????',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri')),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle),
                          child: const Icon(CupertinoIcons.gift_fill,
                              color: Colors.white, size: 14)),
                      ]),
                    const SizedBox(height: 6),
                    Text(
                      readyCount > 0
                          ? '?? ???? $readyCount ?????? ?????? ?????'
                          : driverIds.isEmpty
                              ? '???? ???? ???? ?? ??????? ????????'
                              : '$bestProgress ?? 5 ?????? ?? ???? ????',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontFamily: 'Amiri')),
                    if (driverIds.isNotEmpty && readyCount == 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 140,
                        child: Row(
                          children: List.generate(5, (i) {
                            final active = i < bestProgress;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                height: 5,
                                decoration: BoxDecoration(
                                    color: active
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(4))));
                          }))),
                    ],
                  ]),
              ]),
          ])));
  }

  // -- Last refresh ----------------------------------------------------------
  Widget _buildLastRefresh() {
    final diff = DateTime.now().difference(_lastRefresh);
    String text;
    if (diff.inSeconds < 60) {
      text = '??? ?????: ??? ${diff.inSeconds} ?????';
    } else if (diff.inMinutes < 60) {
      text = '??? ?????: ??? ${diff.inMinutes} ?????';
    } else {
      text = '??? ?????: ??? ${diff.inHours} ????';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Text(text,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
            fontFamily: 'Amiri'))));
  }

  // -- Header --------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context, {
    required String fullName,
    required String email,
    required String gender,
    required String photoUrl,
    required User user,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8)),
        ]),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07)))),
          Positioned(
            bottom: -30,
            right: -10,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05)))),

          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  _slideRoute(EditProfileScreen(userId: user.uid))),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(
                    CupertinoIcons.pencil,
                    color: Colors.white,
                    size: 18))),

              const Spacer(),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : '????????',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontFamily: 'Amiri')),
                  if (gender.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        gender,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'Amiri'))),
                  ],
                ]),

              const SizedBox(width: 16),

              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    gender == '????'
                        ? 'assets/images/avatarf.png'
                        : 'assets/images/avatar.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover))),
            ]),
        ]));
  }

  // -- ??????? ?????? --------------------------------------------------------
  Widget _buildInfoSection({
    required String phone,
    required String email,
    required String gender,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _sectionTitle('??????? ??????', CupertinoIcons.person_fill),
        const SizedBox(height: 14),
        _infoRow(
          CupertinoIcons.phone_fill,
          '??? ??????',
          phone.isNotEmpty ? phone : '??? ????'),
        const _NeumDivider(),
        _infoRow(CupertinoIcons.mail_solid, '?????? ??????????', email),
        const _NeumDivider(),
        _infoRow(
          CupertinoIcons.person_2_fill,
          '?????',
          gender.isNotEmpty ? gender : '??? ????'),
      ]);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: _kText,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'Amiri')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _kBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kNeumShadow,
                      blurRadius: 5,
                      offset: const Offset(2, 2)),
                    BoxShadow(
                      color: _kNeumLight,
                      blurRadius: 5,
                      offset: Offset(-2, -2)),
                  ]),
                child: Icon(icon, color: _kPrimary, size: 14)),
            ]),
        ]));
  }

  Widget _buildLocationsCard(String uid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
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
        border: Border.all(color: _kPrimary.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _openLocationDialog(uid),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kSecondary]),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '????? ????',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.bold)),
                    ]))),
              _sectionTitle('?????? ????????', CupertinoIcons.location_fill),
            ]),
          const SizedBox(height: 14),
          if (_savedLocations.isEmpty)
            _emptyLocationsHint()
          else
            Column(
              children: _savedLocations.map((doc) {
                return _LocationTile(
                  label: doc['label'] ?? '',
                  data: doc,
                  address: doc['address'] ?? '',
                  onDelete: () => _deleteLocation(uid, doc['_id']),
                  onEdit: () => _openLocationDialog(
  uid,
  docId: doc['_id'],
  data: doc, // ? ??? ??? doc ???
));
              }).toList()),
        ]));
  }

  Future<void> _deleteLocation(String uid, String docId) async {
    await ApiClient.delete('/api/saved-locations/$docId');
    _loadSavedLocations();
  }

  Widget _emptyLocationsHint() => const Center(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        "?? ???? ????? ??????",
        style: TextStyle(fontFamily: 'Amiri', fontSize: 12, color: Colors.grey))));

 // ???? ?? ??? ?????? ???? ??? ???????? (data)
void _openLocationDialog(String uid, {String? docId,    Map<String, dynamic>? data,}) {
  showDialog(
    context: context,
    builder: (_) => _LocationDialog(
      userId: uid,
      docId: docId,
      initialData: data , // ??? ?????? ????? ???
    ),
  );
}

  // -- ????????? -------------------------------------------------------------
  Widget _buildActionsCard(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: _cardGradientDeco(),
      child: Column(
        children: [
          _actionTile(
            icon: CupertinoIcons.pencil_circle_fill,
            label: '????? ?????????',
            color: _kPrimary,
            onTap: () => Navigator.push(
              context,
              _slideRoute(EditProfileScreen(userId: user.uid)))),
          const _NeumDivider(),
          _actionTile(
            icon: CupertinoIcons.bell_fill,
            label: '??????? ?????????',
            color: _kPrimary,
            onTap: () => Navigator.push(
              context,
              _slideRoute(const NotificationSettingsScreen()))),
          const _NeumDivider(),
          _actionTile(
            icon: CupertinoIcons.square_arrow_left_fill,
            label: '????? ??????',
            color: Colors.redAccent,
            onTap: () => _confirmSignOut(context)),
          const _NeumDivider(),
          _actionTile(
            icon: CupertinoIcons.delete_solid,
            label: '??? ??????',
            color: Colors.red,
            onTap: () => _confirmDeleteAccount(context)),
        ]));
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('??? ??????', style: TextStyle(fontFamily: 'Amiri')),
        content: const Text(
          '???? ??? ????? ????? ??????? ???????. ??? ??????? ?? ???? ??????? ???.',
          style: TextStyle(fontFamily: 'Amiri', fontSize: 13)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('?????', style: TextStyle(fontFamily: 'Amiri'))),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('???', style: TextStyle(fontFamily: 'Amiri'))),
        ]));
    if (confirmed != true) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await ApiClient.delete('/api/users/${user.uid}');
        await user.delete();
        UserLocal.clear();
      }
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?? ??? ?????? ?????', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.green));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (!mounted) return;
        await _reauthenticateAndDelete(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('???: ${AuthService.errorMessage(e.code)}', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('???: $e', style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reauthenticateAndDelete(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
    if (providers.contains('google.com')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('???? ????? ????? ?????? ?????? ?????', style: TextStyle(fontFamily: 'Amiri')),
          behavior: SnackBarBehavior.floating));
      try {
        await AuthService.reauthenticateWithGoogle();
        if (!mounted) return;
        await ApiClient.delete('/api/users/${user!.uid}');
        await user.delete();
        UserLocal.clear();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('?? ??? ?????? ?????', style: TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.green));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('??? ??????? ???? ??? ????', style: TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.red));
        }
      }
    } else {
      final passwordCtrl = TextEditingController();
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('????? ??????', style: TextStyle(fontFamily: 'Amiri')),
          content: Column(
            children: [
              const Text('???? ???? ???? ?????? ??? ??????', style: TextStyle(fontFamily: 'Amiri', fontSize: 13)),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: passwordCtrl,
                obscureText: true,
                placeholder: '???? ????',
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('?????', style: TextStyle(fontFamily: 'Amiri'))),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('?????', style: TextStyle(fontFamily: 'Amiri'))),
          ],
        ));
      if (ok != true) return;
      try {
        await AuthService.reauthenticateWithEmail(passwordCtrl.text);
        if (!mounted) return;
        await ApiClient.delete('/api/users/${user!.uid}');
        await user.delete();
        UserLocal.clear();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('?? ??? ?????? ?????', style: TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.green));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('???? ???? ??? ?????', style: TextStyle(fontFamily: 'Amiri')),
              backgroundColor: Colors.red));
        }
      } finally {
        passwordCtrl.dispose();
      }
    }
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              CupertinoIcons.chevron_left,
              color: Colors.grey.shade400,
              size: 16),
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'Amiri')),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18)),
              ]),
          ])));
  }

  void _confirmSignOut(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text(
          '????? ??????',
          style: TextStyle(fontFamily: 'Amiri')),
        content: const Text(
          '?? ???? ????? ?????? ?? ??????',
          style: TextStyle(fontFamily: 'Amiri')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('?????', style: TextStyle(fontFamily: 'Amiri'))),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              UserLocal.clear();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (_) => false);
              }
            },
            child: const Text('????', style: TextStyle(fontFamily: 'Amiri'))),
        ]));
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: _kText,
          fontFamily: 'Amiri')),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.1),
          shape: BoxShape.circle),
        child: Icon(icon, color: _kPrimary, size: 14)),
    ]);

  Widget _notLoggedIn() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kCard,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kNeumShadow,
                blurRadius: 12,
                offset: const Offset(5, 5)),
              BoxShadow(
                color: _kNeumLight,
                blurRadius: 12,
                offset: Offset(-5, -5)),
            ]),
          child: const Icon(CupertinoIcons.person, color: _kPrimary, size: 48)),
        const SizedBox(height: 20),
        const Text(
          '?? ???? ????',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kText,
            fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Text(
          '??? ????? ???? ????????',
          style: TextStyle(color: Colors.grey.shade500, fontFamily: 'Amiri')),
      ]));
}

// ------------------------------------------------------------------------------
//  ProfileMiniMenu
// ------------------------------------------------------------------------------
void showProfileMiniMenu(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    _showLoginRequiredDialog(context);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (_) => _ProfileMiniMenuSheet(userId: user.uid));
}

void _showLoginRequiredDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) => const SizedBox(),
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: anim1.value,
        child: Opacity(
          opacity: anim1.value,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: _kNeumShadow,
                      blurRadius: 20,
                      offset: const Offset(10, 10)),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 20,
                      offset: Offset(-10, -10)),
                  ]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _kBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kNeumShadow,
                            blurRadius: 10,
                            offset: const Offset(4, 4)),
                          const BoxShadow(
                            color: Colors.white,
                            blurRadius: 10,
                            offset: Offset(-4, -4)),
                        ]),
                      child: const Icon(
                        CupertinoIcons.person_crop_circle_badge_exclam,
                        color: _kPrimary,
                        size: 40)),
                    const SizedBox(height: 20),
                    const Text(
                      "????? ??????",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                        color: Colors.black87)),
                    const SizedBox(height: 12),
                    const Text(
                      "??? ???? ????? ?????? ????? ?????? ??? ?????? ????? ??????",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: 'Amiri',
                        height: 1.5)),
                    const SizedBox(height: 30),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainPage(initialIndex: 3)));
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_kPrimary, _kSecondary]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5)),
                          ]),
                        child: const Center(
                          child: Text(
                            "????",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Amiri'))))),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "??? ????",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w600))),
                  ]))))));
    });
}

class _ProfileMiniMenuSheet extends StatefulWidget {
  final String userId;
  const _ProfileMiniMenuSheet({required this.userId});

  @override
  State<_ProfileMiniMenuSheet> createState() => _ProfileMiniMenuSheetState();
}

class _ProfileMiniMenuSheetState extends State<_ProfileMiniMenuSheet> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await ApiClient.get('/api/users/${widget.userId}');
      if (mounted) setState(() => _userData = data);
    } catch (_) { /* ignored */ }
  }

  @override
  Widget build(BuildContext context) {
    final data = _userData ?? {};
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final email =
        data['email'] as String? ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
    final gender = data['gender'] as String? ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((s) => s.isNotEmpty).join(' ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -5)),
        ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10))),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : '????????',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                          fontFamily: 'Amiri')),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontFamily: 'Amiri')),
                    ])),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kSecondary])),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      gender == '????'
                          ? 'assets/images/avatarf.png'
                          : 'assets/images/avatar.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover))),
              ])),

          const SizedBox(height: 20),

          Divider(
            height: 1,
            color: Colors.grey.shade300,
            indent: 20,
            endIndent: 20),

          _menuItem(
            context,
            icon: CupertinoIcons.person_fill,
            label: '??? ????????',
            color: _kPrimary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, _slideRoute(const ProfileScreen()));
            }),

          Divider(
            height: 1,
            color: Colors.grey.shade300,
            indent: 20,
            endIndent: 20),

          _menuItem(
            context,
            icon: CupertinoIcons.pencil_circle_fill,
            label: '????? ?????????',
            color: _kSecondary,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                _slideRoute(EditProfileScreen(userId: widget.userId)));
            }),

          Divider(
            height: 1,
            color: Colors.grey.shade300,
            indent: 20,
            endIndent: 20),

          _menuItem(
            context,
            icon: CupertinoIcons.square_arrow_left_fill,
            label: '????? ??????',
            color: Colors.redAccent,
            onTap: () async {
              Navigator.pop(context);
              UserLocal.clear();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (_) => false);
              }
            }),

          const SizedBox(height: 12),
        ]));
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              CupertinoIcons.chevron_left,
              color: Colors.grey.shade400,
              size: 16),
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'Amiri')),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18)),
              ]),
          ])));
  }
}

// ------------------------------------------------------------------------------
//  EditProfileScreen
// ------------------------------------------------------------------------------
class EditProfileScreen extends StatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _selectedGender;
  bool _loading = false;
  bool _loadingData = true;
  bool _passVisible = false;

  late AnimationController _pageCtrl;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiClient.get('/api/users/${widget.userId}');
      if (mounted) {
        setState(() {
          _firstCtrl.text = data['firstName'] as String? ?? '';
          _lastCtrl.text = data['lastName'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          _selectedGender = data['gender'] as String?;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty) {
      _snack('???? ????? ?????', error: true);
      return;
    }
    if (_passCtrl.text.isNotEmpty) {
      if (_passCtrl.text.length < 6) {
        _snack('???? ???? ??? ?? 6 ????', error: true);
        return;
      }
      if (_passCtrl.text != _confirmPassCtrl.text) {
        _snack('????? ???? ??? ?????????', error: true);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      await ApiClient.put('/api/users/${widget.userId}', {
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_selectedGender != null) 'gender': _selectedGender,
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(
          '${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}');
        if (_passCtrl.text.isNotEmpty) {
          await user.updatePassword(_passCtrl.text.trim());
        }
      }

      if (UserLocal.data != null) {
        UserLocal.data!['firstName'] = _firstCtrl.text.trim();
        UserLocal.data!['lastName'] = _lastCtrl.text.trim();
        UserLocal.data!['phone'] = _phoneCtrl.text.trim();
        UserLocal.data!['gender'] = _selectedGender;
      }

      _snack('? ?? ????? ?????');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('? ???: $e', error: true);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _kNeumShadow,
                      blurRadius: 6,
                      offset: const Offset(3, 3)),
                    BoxShadow(
                      color: _kNeumLight,
                      blurRadius: 6,
                      offset: Offset(-3, -3)),
                  ]),
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  color: _kPrimary,
                  size: 20))),
            title: const Text(
              '????? ?????????',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _kText,
                fontFamily: 'Amiri')),
            centerTitle: true),
          body: _loadingData
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _kPrimary,
                    strokeWidth: 2))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_kPrimary, _kSecondary])),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(42),
                            child: Image.asset(
                              _selectedGender == '????'
                                  ? 'assets/images/avatarf.png'
                                  : 'assets/images/avatar.png',
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover)))),
                      const SizedBox(height: 28),

                      _field(
                        controller: _firstCtrl,
                        label: '????? ?????',
                        icon: CupertinoIcons.person),
                      const SizedBox(height: 14),

                      _field(
                        controller: _lastCtrl,
                        label: '?????',
                        icon: CupertinoIcons.person_2),
                      const SizedBox(height: 14),

                      _field(
                        controller: _phoneCtrl,
                        label: '??? ??????',
                        icon: CupertinoIcons.phone,
                        keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),

                      _buildGenderSelector(),
                      const SizedBox(height: 14),

                      _field(
                        controller: _passCtrl,
                        label: '???? ?? ????? (???????)',
                        icon: CupertinoIcons.lock,
                        obscure: !_passVisible,
                        suffix: GestureDetector(
                          onTap: () =>
                              setState(() => _passVisible = !_passVisible),
                          child: Icon(
                            _passVisible
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            color: Colors.grey.shade500,
                            size: 18))),
                      const SizedBox(height: 14),

                      _field(
                        controller: _confirmPassCtrl,
                        label: '????? ???? ????',
                        icon: CupertinoIcons.lock_shield,
                        obscure: !_passVisible),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _loading ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _loading
                                    ? [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ]
                                    : [_kPrimary, _kSecondary],
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: (_loading ? Colors.grey : _kPrimary)
                                      .withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6)),
                              ]),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 26,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.2),
                                          Colors.transparent,
                                        ])))),
                                Center(
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                      : const Text(
                                          '??? ?????????',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Amiri'))),
                              ])))),
                      const SizedBox(height: 30),
                    ])))));
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kNeumShadow,
            blurRadius: 6,
            offset: const Offset(3, 3)),
          BoxShadow(color: _kNeumLight, blurRadius: 6, offset: Offset(-3, -3)),
        ]),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 14,
            color: _kText,
            fontFamily: 'Amiri'),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontFamily: 'Amiri'),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14),
            prefixIcon: suffix,
            suffixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: _kPrimary, size: 20))))));
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '?????',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontFamily: 'Amiri')),
        const SizedBox(height: 8),
        Row(
          children: ['????', '???'].map((g) {
            final isSelected = _selectedGender == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _kPrimary : _kCard,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _kPrimary.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                          ]
                        : [
                            BoxShadow(
                              color: _kNeumShadow,
                              blurRadius: 6,
                              offset: const Offset(3, 3)),
                            BoxShadow(
                              color: _kNeumLight,
                              blurRadius: 6,
                              offset: Offset(-3, -3)),
                          ]),
                  child: Text(
                    g,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.white : _kText,
                      fontFamily: 'Amiri')))));
          }).toList()),
      ]);
  }
}

// ------------------------------------------------------------------------------
//  _LocationDialog  ? ????? ????? ???????
// ------------------------------------------------------------------------------
class _LocationDialog extends StatefulWidget {
  final String userId;
  final String? docId;
  final String? initialLabel;
  final String? initialAddress;
    final Map<String, dynamic>? initialData; // ???? ????

  const _LocationDialog({
    required this.userId,
    this.docId,
    this.initialLabel,
    this.initialAddress,
        this.initialData,
  });

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late TextEditingController _labelCtrl;
  final _doorColorCtrl = TextEditingController();
  final _doorNumCtrl = TextEditingController();
  String _cityAr = '';
String _cityFr = '';

  String _mapAddress = '';
  double? _selectedLat;
  double? _selectedLng;

  String _housingType = '????';
  String _selectedFloor = '?????? ??????';
  File? _imageFile;
  String? _existingImageUrl;
  bool _saving = false;

  final List<String> _floors = [
    '?????? ??????',
    '?????? ?????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
    '?????? ??????',
  ];

   @override
  void initState() {
    super.initState();
    // ? ??? ????? ??? ?? ???????? ??????? ??? ?? ?????? ?? ????? Update
    if (widget.initialData != null) {
      _labelCtrl = TextEditingController(text: widget.initialData!['label']);
      _mapAddress = widget.initialData!['address'] ?? '';
      _selectedLat = widget.initialData!['lat'];
      _selectedLng = widget.initialData!['lng'];
      _cityAr = widget.initialData!['cityNameAr'] ?? '';
      _cityFr = widget.initialData!['cityNameFr'] ?? '';
      _doorNumCtrl.text = widget.initialData!['doorNumber'] ?? '';
      _doorColorCtrl.text = widget.initialData!['doorColor'] ?? '';
      _housingType = widget.initialData!['housingType'] ?? '????';
      _selectedFloor = widget.initialData!['floor'] ?? '?????? ??????';
      if (_selectedFloor == '????') _selectedFloor = '?????? ??????';
      for (final f in ['?????', '??????', '??????', '??????', '??????', '??????', '??????', '??????', '??????', '??????']) {
        if (_selectedFloor == f) _selectedFloor = '?????? $f';
      }
      _existingImageUrl = widget.initialData!['locationImage'] as String?;
    } else {
      _labelCtrl = TextEditingController();
    }
  }

  Future<String> _uploadToCloudinary(File file) async {
    try {
      final result = await ApiClient.upload(file);
      return result;
    } catch (e) {
      return "";
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty || _mapAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "???? ????? ?????? ??????? ?? ???????",
            style: TextStyle(fontFamily: 'Amiri'),
            textAlign: TextAlign.center),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16)));
      return;
    }

    setState(() => _saving = true);
    try {
      String imageUrl = _existingImageUrl ?? "";
      if (_imageFile != null) {
        if (_existingImageUrl != null && _existingImageUrl!.contains('/uploads/')) {
          final oldFile = _existingImageUrl!.split('/').last;
          ApiClient.deleteUpload(oldFile);
        }
        imageUrl = await _uploadToCloudinary(_imageFile!);
        if (imageUrl.isEmpty) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("??? ??? ??????? ???? ?? ???????",
                style: TextStyle(fontFamily: 'Amiri'),
                textAlign: TextAlign.center),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      final data = {
        'label': _labelCtrl.text.trim(),
        'address': _mapAddress,
        'lat': _selectedLat,
        'lng': _selectedLng,
        'cityNameAr': _cityAr,
        'cityNameFr': _cityFr,
        'housingType': _housingType,
        'floor': _housingType == '???' ? _selectedFloor : '????',
        'doorColor': _doorColorCtrl.text.trim(),
        'doorNumber': _doorNumCtrl.text.trim(),
        'locationImage': imageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.docId != null) {
        await ApiClient.put('/api/saved-locations/${widget.docId}', data);
      } else {
        await ApiClient.post('/api/saved-locations', {
          ...data,
          'createdAt': DateTime.now().toIso8601String(),
          'userId': widget.userId,
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$e",
            style: const TextStyle(fontFamily: 'Amiri'),
            textAlign: TextAlign.center),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10)),
          ]),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // -- ??????? ----------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kNeumShadow,
                            blurRadius: 6,
                            offset: const Offset(3, 3)),
                          BoxShadow(
                            color: _kNeumLight,
                            blurRadius: 6,
                            offset: const Offset(-3, -3)),
                        ]),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: _kPrimary,
                        size: 16))),
                  Row(
                    children: [
                      Text(
                        widget.docId != null
                            ? '????? ??????'
                            : '????? ???? ????',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          color: _kText)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _kPrimary.withOpacity(0.1),
                          shape: BoxShape.circle),
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: _kPrimary,
                          size: 14)),
                    ]),
                ]),

              const SizedBox(height: 24),

              // -- ??? ?????? -------------------------------------------
              _sectionLabel('??? ??????', CupertinoIcons.tag_fill),
              const SizedBox(height: 8),
              _styledField(
                _labelCtrl,
                '????: ?????? ?????...',
                CupertinoIcons.tag),

              const SizedBox(height: 20),

              // -- ?????? ???????? --------------------------------------
              _sectionLabel('?????? ????????', CupertinoIcons.map_fill),
              const SizedBox(height: 8),
              GestureDetector(
                // ???? ?? ??? ????? ???? GestureDetector ????? ???????? ?? ??? profile_screen.dart
                onTap: () async {
  final res = await Navigator.push<Map<String, dynamic>>(
    context, MaterialPageRoute(builder: (_) => const MapPickerScreen()));
  if (res != null) {
    setState(() {
      _mapAddress = res['address'];
      _selectedLat = res['lat'];
      _selectedLng = res['lng'];
      // ? ???? ?? MapPickerScreen ????cityNameAr ? cityNameFr
      _cityAr = res['cityNameAr'] ?? ''; 
      _cityFr = res['cityNameFr'] ?? '';
    });
  }
},
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _mapAddress.isEmpty
                          ? _kPrimary.withOpacity(0.2)
                          : _kSuccess.withOpacity(0.5),
                      width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _kNeumShadow,
                        blurRadius: 5,
                        offset: const Offset(3, 3)),
                      BoxShadow(
                        color: _kNeumLight,
                        blurRadius: 5,
                        offset: const Offset(-3, -3)),
                    ]),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _mapAddress.isEmpty
                              ? CupertinoIcons.map_pin
                              : Icons.check_circle_rounded,
                          key: ValueKey(_mapAddress.isEmpty),
                          color: _mapAddress.isEmpty ? _kPrimary : _kSuccess,
                          size: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mapAddress.isEmpty
                              ? '???? ?????? ????? ??? ???????'
                              : _mapAddress,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Amiri',
                            color: _mapAddress.isEmpty
                                ? Colors.grey.shade500
                                : _kText,
                            fontWeight: _mapAddress.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w500))),
                    ]))),

              const SizedBox(height: 20),

              // -- ???? -------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '?????? ?????',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontFamily: 'Amiri'))),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, height: 1)),
                ]),

              const SizedBox(height: 16),

              // -- ??? ????? --------------------------------------------
              _sectionLabel('??? ?????', CupertinoIcons.house_fill),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _housingCard('???', CupertinoIcons.building_2_fill)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _housingCard('????', CupertinoIcons.house_fill)),
                ]),

              // -- ?????? (???? ??? ?????) ------------------------------
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _housingType == '???'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 16),
                          _sectionLabel(
                            '??? ??????',
                            CupertinoIcons.layers_fill),
                          const SizedBox(height: 8),
                          _styledDropdown(),
                        ])
                    : const SizedBox.shrink()),

              const SizedBox(height: 16),

              // -- ??? ????? + ??? ????? ---------------------------------
              _sectionLabel('??????? ?????', CupertinoIcons.lock_fill),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _styledField(
                      _doorNumCtrl,
                      '??? ?????',
                      CupertinoIcons.number)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _styledField(
                      _doorColorCtrl,
                      '??? ?????',
                      Icons.color_lens_outlined)),
                ]),

              const SizedBox(height: 16),

              // -- ???? ????? -------------------------------------------
              _sectionLabel(
                '???? ????? ?? ?????? (???????)',
                Icons.camera_alt_outlined),
              const SizedBox(height: 8),
              _imagePickerBox(),

              const SizedBox(height: 28),

              // -- ?? ????? ---------------------------------------------
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _saving
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [_kPrimary, _kSecondary]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_saving ? Colors.grey : _kPrimary).withOpacity(
                          0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                    ]),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_alt,
                                color: Colors.white,
                                size: 18),
                              const SizedBox(width: 8),
                              Text(
                                widget.docId != null
                                    ? '????? ??????'
                                    : '??? ??????',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFamily: 'Amiri')),
                            ])))),
            ]))));
  }

  // -- Helpers ??? Dialog ----------------------------------------------------

  Widget _sectionLabel(String text, IconData icon) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kText,
          fontFamily: 'Amiri')),
      const SizedBox(width: 6),
      Icon(icon, color: _kPrimary, size: 14),
    ]);

  Widget _styledField(TextEditingController ctrl, String hint, IconData icon) =>
      Container(
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kNeumShadow,
              blurRadius: 5,
              offset: const Offset(3, 3)),
            BoxShadow(
              color: _kNeumLight,
              blurRadius: 5,
              offset: const Offset(-3, -3)),
          ]),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Amiri',
              color: _kText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                fontFamily: 'Amiri',
                color: Colors.grey.shade400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(icon, color: _kPrimary, size: 16))))));

  Widget _housingCard(String type, IconData icon) {
    final bool selected = _housingType == type;
    return GestureDetector(
      onTap: () => setState(() => _housingType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : _kBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5)),
                ]
              : [
                  BoxShadow(
                    color: _kNeumShadow,
                    blurRadius: 6,
                    offset: const Offset(3, 3)),
                  BoxShadow(
                    color: _kNeumLight,
                    blurRadius: 6,
                    offset: const Offset(-3, -3)),
                ],
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent)),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : _kPrimary, size: 26),
            const SizedBox(height: 6),
            Text(
              type,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                color: selected ? Colors.white : _kText)),
          ])));
  }

  Widget _styledDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: _kBg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: _kNeumShadow,
          blurRadius: 5,
          offset: const Offset(3, 3)),
        BoxShadow(
          color: _kNeumLight,
          blurRadius: 5,
          offset: const Offset(-3, -3)),
      ]),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedFloor,
        isExpanded: true,
        icon: const Icon(
          CupertinoIcons.chevron_down,
          color: _kPrimary,
          size: 14),
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'Amiri',
          color: _kText),
        items: _floors
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(
                  f,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'Amiri', fontSize: 13))))
            .toList(),
        onChanged: (v) => setState(() => _selectedFloor = v!))));

  Widget _imagePickerBox() => GestureDetector(
    onTap: _pickImage,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _imageFile != null || _existingImageUrl != null
              ? _kSuccess.withOpacity(0.4)
              : _kPrimary.withOpacity(0.15),
          width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kNeumShadow,
            blurRadius: 6,
            offset: const Offset(3, 3)),
          BoxShadow(
            color: _kNeumLight,
            blurRadius: 6,
            offset: const Offset(-3, -3)),
        ]),
      child: _imageFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(_imageFile!, fit: BoxFit.cover, cacheWidth: 300))
          : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CachedNetworkImage(
                    imageUrl: _existingImageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    placeholder: (_, __) => Container(
                      color: _kBg,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: _kBg,
                      child: const Icon(Icons.broken_image, color: _kPrimary),
                    ),
                  ))
              : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle),
                  child: const Icon(
                    Icons.image_outlined,
                    color: _kPrimary,
                    size: 22)),
                const SizedBox(height: 8),
                const Text(
                  '???? ??????? ???? ?????',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Amiri',
                    color: Colors.grey)),
              ])));
}

// ------------------------------------------------------------------------------
//  _LocationTile
// ------------------------------------------------------------------------------
class _LocationTile extends StatelessWidget {
  final String label, address;
  final VoidCallback onDelete, onEdit;
  final Map<String, dynamic> data;

  const _LocationTile({
    required this.label,
    required this.address,
    required this.onDelete,
    required this.onEdit,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kNeumShadow,
            blurRadius: 8,
            offset: const Offset(4, 4)),
          BoxShadow(
            color: _kNeumLight,
            blurRadius: 8,
            offset: const Offset(-4, -4)),
        ]),
      child: Row(
        children: [
          _circleBtn(Icons.delete_outline, Colors.redAccent, onDelete),
          const SizedBox(width: 8),
          _circleBtn(Icons.edit_location_alt_outlined, Colors.blue, onEdit),
          const Spacer(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri')),
                Text(
                  "${data['housingType']} - ${data['floor']}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kPrimary,
                    fontFamily: 'Amiri')),
                Text(
                  "??? ${data['doorColor']} ??? ${data['doorNumber']}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontFamily: 'Amiri')),
              ])),
          const SizedBox(width: 12),
          const Icon(CupertinoIcons.location_solid, color: _kPrimary, size: 20),
        ]));
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)));
}

// ------------------------------------------------------------------------------
//  Helpers
// ------------------------------------------------------------------------------
class _NeumDivider extends StatelessWidget {
  const _NeumDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Colors.grey.shade300, indent: 0, endIndent: 0);
}

Route _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child)),
  transitionDuration: const Duration(milliseconds: 350));

// ------------------------------------------------------------------------------
//  DriversLoyaltyPage — ???? ???? ?????? ??? ???? (?????? ????????) ?
// ------------------------------------------------------------------------------
class DriversLoyaltyPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, String> driverNames;
  const DriversLoyaltyPage({
    super.key,
    required this.userData,
    required this.driverNames,
  });

  @override
  Widget build(BuildContext context) {
    final loyalty = userData['driverLoyalty'] as Map<String, dynamic>? ?? {};
    final freeDel = userData['driverFreeDelivery'] as Map<String, dynamic>? ?? {};
    final driverIds = {...loyalty.keys, ...freeDel.keys}.toList();
    final readyCount = freeDel.values.where((v) => v == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F0F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F0F5),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB8B1C8).withOpacity(0.55),
                  blurRadius: 6,
                  offset: const Offset(3, 3)),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 6,
                  offset: const Offset(-3, -3)),
              ]),
            child: const Icon(CupertinoIcons.chevron_right, color: Color(0xFF2D2A3A)),
          ),
        ),
        title: const Text(
          '?????? ????????',
          style: TextStyle(
            color: Color(0xFF2D2A3A),
            fontFamily: 'Amiri',
            fontWeight: FontWeight.bold))),
      body: driverIds.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _headerBanner(readyCount),
                const SizedBox(height: 16),
                ...driverIds.map((id) => _driverCard(id, loyalty, freeDel)),
              ]),
    );
  }

  // -- Header ?????? ?????? ---------------------------------------------
  Widget _headerBanner(int readyCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7D29C6), Color(0xFF9232E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7D29C6).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6)),
        ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle),
            child: const Icon(CupertinoIcons.gift_fill, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  readyCount > 0
                      ? '???? $readyCount ?????? ?????? ??'
                      : '?? 5 ?????? = ?????? ??????',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri')),
                const SizedBox(height: 4),
                Text(
                  '???? ?? ??? ?????? ??? ???? ???? ????',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontFamily: 'Amiri')),
              ])),
        ]));
  }

  // -- Empty state --------------------------------------------------------
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0F5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8B1C8).withOpacity(0.6),
                    blurRadius: 12,
                    offset: const Offset(5, 5)),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 12,
                    offset: const Offset(-5, -5)),
                ]),
              child: const Icon(CupertinoIcons.gift, color: Color(0xFF7D29C6), size: 44)),
            const SizedBox(height: 20),
            const Text(
              '?? ???? ???? ???',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2A3A),
                fontFamily: 'Amiri')),
            const SizedBox(height: 8),
            Text(
              '?? 5 ?????? ?????? ?? ??? ?????? ????? ?????? ??????',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontFamily: 'Amiri',
                height: 1.5)),
          ])));
  }

  // -- ???? ?? ???? ------------------------------------------------------
  Widget _driverCard(
    String id,
    Map<String, dynamic> loyalty,
    Map<String, dynamic> freeDel,
  ) {
    final count = (loyalty[id] as num?)?.toInt() ?? 0;
    final hasFree = freeDel[id] == true;
    final name = driverNames[id] ?? '????';
    final progress = count.clamp(0, 5);
    final initial = name.isNotEmpty ? name[0] : '?';
    final accent = hasFree ? const Color(0xFF27AE60) : const Color(0xFF7D29C6);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(2, 2)),
        ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              if (hasFree)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    '?? ????',
                    style: TextStyle(
                      color: Color(0xFF27AE60),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')))
              else
                Text(
                  '${5 - progress} ?????? ??????',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'Amiri')),
              const Spacer(),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: Color(0xFF2D2A3A))),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF7D29C6), Color(0xFF9232E8)])),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')))),
            ]),
          const SizedBox(height: 14),
          // ???? ?????? ???????
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(height: 10, color: const Color(0xFFDCDAE6)),
                FractionallySizedBox(
                  widthFactor: hasFree ? 1.0 : progress / 5,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasFree
                            ? [const Color(0xFF27AE60), const Color(0xFF6FCF97)]
                            : [const Color(0xFF7D29C6), const Color(0xFF9232E8)]))),
                ),
              ])),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (j) {
              final active = j < progress || hasFree;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 30,
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withOpacity(0.12)
                        : const Color(0xFFF1F0F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? accent : Colors.transparent,
                      width: 1.2)),
                  child: Icon(
                    j == 4 ? CupertinoIcons.gift_fill : CupertinoIcons.checkmark_alt,
                    color: active ? accent : Colors.grey.shade400,
                    size: 15)));
            })),
        ]));
  }
}