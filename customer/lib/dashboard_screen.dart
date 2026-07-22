import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_1/products_list_screen.dart';
import 'package:flutter_application_1/Order/notification_helperr.dart';
import 'stores_view.dart';
import 'dashboard_search_bar.dart';
import 'dart:async';
import 'stores_widget.dart';
import 'cardd.dart';
import 'profile_screen.dart';
import 'store_accounts_screen.dart';
// ? ??????? ???? ??????? ?? delivery_screen
import 'package:flutter_application_1/Services/delivery_screen.dart';
import 'Services/api_client.dart';
import 'user_local.dart';

// ------------------------------------------------------------------------------
//  LocationProvider — ????? ?????? ??????? ???????
// ------------------------------------------------------------------------------
class LocationProvider extends ChangeNotifier {
  static final LocationProvider _instance = LocationProvider._();
  factory LocationProvider() => _instance;
  LocationProvider._();

  String? _label;
  String? _address;
  double? _lat;
  double? _lng;

  String? get label => _label;
  String? get address => _address;
  double? get lat => _lat;
  double? get lng => _lng;

  bool get hasLocation => _address != null && _address!.isNotEmpty;

  void setLocation({
    required String label,
    required String address,
    double? lat,
    double? lng,
  }) {
    _label = label;
    _address = address;
    _lat = lat;
    _lng = lng;
    notifyListeners();
  }

  void clear() {
    _label = null;
    _address = null;
    _lat = null;
    _lng = null;
    notifyListeners();
  }
}

// ------------------------------------------------------------------------------
//  DashboardScreen
// ------------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  String? selectedStoreId;

  List<dynamic>? _cachedStores;

  // -- Animation Controllers --------------------------------------------------
  late final AnimationController _headerController;
  late final AnimationController _searchController;
  late final AnimationController _bannerController;
  late final AnimationController _contentController;

  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _searchSlide;
  late final Animation<double> _searchFade;
  late final Animation<double> _bannerScale;
  late final Animation<double> _bannerFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _contentFade;

  // -- LocationProvider -------------------------------------------------------
  final _locationProvider = LocationProvider();

  // -- ? GlobalKey ??? _PromotionsBanner ??????? ??? Pull to Refresh ----------
  final GlobalKey<_PromotionsBannerState> _bannerKey =
      GlobalKey<_PromotionsBannerState>();

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playSequence();
    _loadStores();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialLocation();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserNotificationHelper.init(user.uid);
      }
    });
  }

  Future<void> _loadInitialLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final locations = await ApiClient.getList('/api/users/${user.uid}/saved-locations');
      if (locations.isNotEmpty && mounted) {
        final data = locations.first;
        if (data is! Map<String, dynamic>) return;
        _locationProvider.setLocation(
          label: data['label'] ?? '?????',
          address: data['address'] ?? '',
          lat: (data['lat'] as num?)?.toDouble(),
          lng: (data['lng'] as num?)?.toDouble());
        setState(() {});
      }
    } catch (_) { /* ignored */ }
  }

  // --------------------------------------------------------------------------
  //  ? Pull to Refresh — ????? ????? ?? ????????
  // --------------------------------------------------------------------------
  Future<void> _onRefresh() async {
    final user = FirebaseAuth.instance.currentUser;

    final futures = <Future>[];
    if (user != null) {
      futures.add(_fetchUserLocation(user));
    }
    futures.add(_bannerKey.currentState?._checkVersionAndLoad() ?? Future.value());
    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _cachedStores = null;
      });
      _loadStores();
    }
  }

  Future<void> _fetchUserLocation(User user) async {
    final locations = await ApiClient.getList('/api/users/${user.uid}/saved-locations');
    if (locations.isNotEmpty && mounted) {
      final data = locations.first;
      if (data is! Map<String, dynamic>) return;
      _locationProvider.setLocation(
        label: data['label'] ?? '?????',
        address: data['address'] ?? '',
        lat: (data['lat'] as num?)?.toDouble(),
        lng: (data['lng'] as num?)?.toDouble());
    }
  }

  Future<void> _loadStores() async {
    try {
      final stores = await ApiClient.getList('/api/stores');
      final filtered = stores
          .where((s) => s['ownerId'] == null)
          .toList();
      filtered.sort((a, b) => ((a['nm']?.toString()) ?? '')
          .compareTo((b['nm']?.toString()) ?? ''));
      if (mounted) {
        setState(() {
          _cachedStores = filtered;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedStores = [];
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  //  ? ??? ????? ?????? (????? ?? ?????)
  // --------------------------------------------------------------------------
  Future<void> _openLocationPicker({bool isAuto = false}) async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ???? ? ???? bottom sheet ??? ??????? ???????? + ?????
      _showLocationSheet();
    } else {
      // ?? ???? ? ???? ??????? ??????
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const MapPickerScreen()));
      if (result != null && mounted) {
        _locationProvider.setLocation(
          label: '?????',
          address: result['address'] ?? '',
          lat: result['lat'],
          lng: result['lng']);
        setState(() {});
      }
    }
  }

  // --------------------------------------------------------------------------
  //  ? Bottom Sheet — ??????? ????????
  // --------------------------------------------------------------------------
  void _showLocationSheet() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LocationBottomSheet(
        userId: user.uid,
        onLocationSelected: (label, address, lat, lng) {
          _locationProvider.setLocation(
            label: label,
            address: address,
            lat: lat,
            lng: lng);
          if (mounted) setState(() {});
        },
        onPickFromMap: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const MapPickerScreen()));
          if (result != null && mounted) {
            _locationProvider.setLocation(
              label: '???? ????',
              address: result['address'] ?? '',
              lat: result['lat'],
              lng: result['lng']);
            setState(() {});
          }
        }));
  }

  // -- Animations -------------------------------------------------------------
  void _setupAnimations() {
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550));
    _headerSlide = Tween<Offset>(begin: const Offset(-0.6, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic));
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut);

    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500));
    _searchSlide = Tween<Offset>(begin: const Offset(0, -0.8), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _searchController,
            curve: Curves.easeOutCubic));
    _searchFade = CurvedAnimation(
      parent: _searchController,
      curve: Curves.easeOut);

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _bannerScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.easeOutBack));
    _bannerFade = CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOut);

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic));
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut);
  }

  Future<void> _playSequence() async {
    if (!mounted || _headerController.isCompleted) return;
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || _searchController.isCompleted) return;
    _searchController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || _bannerController.isCompleted) return;
    _bannerController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted || _contentController.isCompleted) return;
    _contentController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _searchController.dispose();
    _bannerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void onStoreSelected(String storeId) {
    if (!mounted) return;
    if (selectedStoreId != storeId) {
      setState(() => selectedStoreId = storeId);
    }
  }

  // -- Neumorphic Container ---------------------------------------------------
  Widget _neumorphicContainer({
    required Widget child,
    Color? color,
    EdgeInsets? padding,
    double radius = 30.0,
  }) {
    // ? ?????? ????? ????? ???????
    final Color baseColor = color ?? const Color(0xFFF1F0F5);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6), // ?? ?????? ????
            blurRadius: 10,
            offset: const Offset(4, 4)),
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 10,
            offset: Offset(-4, -4)),
        ]),
      child: child);
  }

  // --------------------------------------------------------------------------
  //  BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final storesData = _cachedStores;
    if (storesData != null && storesData.isNotEmpty && selectedStoreId == null) {
      selectedStoreId = storesData.first['id'] ?? storesData.first['_id'];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '???? ??? ???? ??????',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Amiri')),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating));
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF1F0F5),
      body: Stack(
        children: [
          // --------------------------------------------------------------
          // ? ?????? ??????: ?????? ???????? ??? ???? ?????? ?????????
          // --------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              // ??? ?????? ????? ?????? ??????? ??????
              height: MediaQuery.of(context).padding.top,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Color.fromARGB(255, 143, 105, 143), // ?????? ????
                    Color.fromARGB(255, 167, 166, 167), // ?????? ?????
                    Color.fromARGB(255, 159, 123, 177), // ?????? ???? (?????)
                  ])))),

          // --------------------------------------------------------------
          // ? ?????? ???????: ????? ?????? ?????? (???? ?? ?????)
          // --------------------------------------------------------------
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF7D29C6),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // -- Sliver 1: ?????? + ?????? + ?????? --
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // -- AppBar ----------------
                        SlideTransition(
                          position: _headerSlide,
                          child: FadeTransition(
                            opacity: _headerFade,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => showProfileMiniMenu(context),
                                    child: _neumorphicContainer(
                                      child: const _UserAvatar())),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openLocationPicker(),
                                      child: _LocationChip(
                                        provider: _locationProvider))),
                                  ListenableBuilder(
                                    listenable: GlobalCart.provider,
                                    builder: (context, _) {
                                      int cartCount = GlobalCart.provider.count;
                                      final Color primaryPurple = const Color(
                                        0xFF7D29C6);

                                      return GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CartScreen())),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            _neumorphicContainer(
                                              padding: const EdgeInsets.all(11),
                                              child: Icon(
                                                CupertinoIcons.cart_fill,
                                                color: const Color(0xFF7D29C6),
                                                size: 24)),

                                            if (cartCount > 0)
                                              Positioned(
                                                right: -4,
                                                top: -4,
                                                child: TweenAnimationBuilder(
                                                  duration: const Duration(
                                                    milliseconds: 400),
                                                  tween: Tween<double>(
                                                    begin: 0,
                                                    end: 1),
                                                  builder:
                                                      (context, double val, child) {
                                                        return Transform.scale(
                                                          scale: val,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  4),
                                                            decoration: BoxDecoration(
                                                              gradient:
                                                                  LinearGradient(
                                                                    colors: [
                                                                      primaryPurple,
                                                                      const Color(
                                                                        0xFF9232E8),
                                                                    ]),
                                                              shape:
                                                                  BoxShape.circle,
                                                              border: Border.all(
                                                                color: const Color(
                                                                  0xFFB8B1C8).withOpacity(0.6),
                                                                width: 1.5),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color:
                                                                      const Color(
                                                                        0xFFB8B1C8).withOpacity(
                                                                        0.6),
                                                                  blurRadius: 6,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        3)),
                                                              ]),
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minWidth: 20,
                                                                  minHeight: 20),
                                                            child: Text(
                                                              '$cartCount',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize: 10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    fontFamily:
                                                                        'Cairo'),
                                                              textAlign:
                                                                  TextAlign.center)));
                                                      })),
                                          ]));
                                    }), // ?? ????? (???? ???? ?? ????)
                      ])))),

                        const SizedBox(height: 10),

                        // -- Search Bar --------------
                        SlideTransition(
                          position: _searchSlide,
                          child: FadeTransition(
                            opacity: _searchFade,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: DashboardSearchBar(stores: _cachedStores ?? [])))),

                        const SizedBox(height: 8),

                        // -- Banner --
                        SlideTransition(
                          position: _contentSlide,
                          child: FadeTransition(
                            opacity: _contentFade,
                            child: Column(
                              children: [
                                RepaintBoundary(
                                  child: ScaleTransition(
                                    scale: _bannerScale,
                                    child: FadeTransition(
                                      opacity: _bannerFade,
                                      child: _PromotionsBanner(key: _bannerKey)))),

                                const SizedBox(height: 13),
                              ]))),
                      ])),

                  // -- Sliver 2: StoresWidget (???? ??? ??????) --
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StoresHeaderDelegate(
                      child: Builder(
                        builder: (context) {
                          final docs = _cachedStores;

                          if (docs == null) {
                            return const Center(
                              child: CupertinoActivityIndicator());
                          }

                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                "?? ???? ??????? ??????",
                                style: TextStyle(fontFamily: 'Amiri')));
                          }

                          return StoresWidget(
                            stores: docs,
                            selectedStoreId: selectedStoreId,
                            onStoreSelected: onStoreSelected);
                        },
                      ),
                    ),
                  ),

                  // -- Sliver 3: StoresView --
                  if (_cachedStores != null && _cachedStores!.isNotEmpty && selectedStoreId != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 11, right: 1),
                        child: StoresView(
                          templateId: selectedStoreId!,
                          stores: _cachedStores!),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100)),
                ]))),
        ])));
  }
}

// ------------------------------------------------------------------------------
//  _StoresHeaderDelegate — SliverPersistentHeader ????? StoresWidget
// ------------------------------------------------------------------------------
class _StoresHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  _StoresHeaderDelegate({required this.child, this.height = 120});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF1F0F5),
      child: child);
  }

  @override
  bool shouldRebuild(covariant _StoresHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

// ------------------------------------------------------------------------------
//  ? [????? 3] _LocationChip — ?????? ????? + ???? ?????
// ------------------------------------------------------------------------------
class _LocationChip extends StatelessWidget {
  final LocationProvider provider;

  const _LocationChip({required this.provider});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final hasLoc = provider.hasLocation;
        // ? ??????? ??????? ????????? ?? ???????? ??????
        final Color primaryPurple = const Color(0xFF7D29C6);
        final Color lavenderShadow = const Color(0xFFB8B1C8);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // ? ???? ????? ?????? ???? ????
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFFF1F0F5), const Color(0xFFE6E4F0)]),
              boxShadow: [
                BoxShadow(
                  color: lavenderShadow.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(4, 4)),
                BoxShadow(
                  color: const Color(0xFFB8B1C8).withOpacity(0.6),
                  blurRadius: 8,
                  offset: Offset(-4, -4)),
              ],
              // ? ???? ?????? ???? ???? ??? ??????
              border: Border.all(
                color: primaryPurple.withOpacity(0.1),
                width: 1)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // -- ? ?????? ?????? ?????? ???????? ?????? ------------------
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryPurple.withOpacity(0.08)),
                  child: Icon(
                    hasLoc
                        ? CupertinoIcons.location_solid
                        : CupertinoIcons.location,
                    // ? ????? ????? ?? ?????? ??? ???????? ???????
                    color: hasLoc
                        ? primaryPurple
                        : primaryPurple.withOpacity(0.5),
                    size: 16)),

                const SizedBox(width: 8),

                // -- ? ?????? ?????? ????? (????? ???? ??????) --------------
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasLoc) ...[
                        Text(
                          provider.label ?? '?????',
                          style: TextStyle(
                            fontSize: 10,
                            // ? ?????? ???? ???? (??? ????) ???? ?????
                            color: const Color(0xFF2D2A3A),
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Amiri')),
                        Text(
                          provider.address ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            // ? ????? ???? ????????
                            color: const Color(0xFF6E6B7B),
                            fontFamily: 'Amiri')),
                      ] else ...[
                        Text(
                          '??? ?????',
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryPurple.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Amiri')),
                      ],
                    ])),

                // -- ??? ?????? ???? ----------------------------------------
                Icon(
                  CupertinoIcons.chevron_down,
                  color: primaryPurple.withOpacity(0.4),
                  size: 12),
                const SizedBox(width: 8),
              ])));
      });
  }
}

// ------------------------------------------------------------------------------
//  ? _LocationBottomSheet — ????? ??????? ????????
// ------------------------------------------------------------------------------
class _LocationBottomSheet extends StatefulWidget {
  final String userId;
  final Function(String label, String address, double? lat, double? lng)
  onLocationSelected;
  final VoidCallback onPickFromMap;

  const _LocationBottomSheet({
    required this.userId,
    required this.onLocationSelected,
    required this.onPickFromMap,
  });

  @override
  State<_LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<_LocationBottomSheet> {
  List<dynamic>? _locations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await ApiClient.getList('/api/users/${widget.userId}/saved-locations');
      if (mounted) {
        setState(() {
          _locations = locations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ? ????? ??????? ?????????
    final Color primaryPurple = const Color(0xFF7D29C6);
    final Color lavenderShadow = const Color(0xFFB8B1C8);
    final Color bgCool = const Color(0xFFF1F0F5);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: bgCool, // ? ????? ?????
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, -5)),
        ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: lavenderShadow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10))),

          // -- ??????? ---------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ? ?? ????? ?? ??????? (????? ??????)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPickFromMap();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryPurple, const Color(0xFF9232E8)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB8B1C8).withOpacity(0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                      ]),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.map, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          '?? ???????',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Amiri')),
                      ]))),

                // ????? ?????
                Row(
                  children: [
                    const Text(
                      '??????',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2A3A),
                        fontFamily: 'Amiri')),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.location_solid,
                      color: primaryPurple,
                      size: 18),
                  ]),
              ])),

          // ? ???? ?????? ???? ????
          Divider(
            height: 20,
            color: primaryPurple.withOpacity(0.1),
            thickness: 1),

          // -- ????? ??????? ----------------------------------------------
          Flexible(
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(30),
                    child: CupertinoActivityIndicator(color: primaryPurple))
                : _locations == null || _locations!.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.location_slash,
                              color: lavenderShadow.withOpacity(0.5),
                              size: 40),
                            const SizedBox(height: 10),
                            Text(
                              '???? ????? ??????',
                              style: TextStyle(
                                color: lavenderShadow,
                                fontFamily: 'Amiri',
                                fontSize: 14)),
                          ]))
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10),
                        itemCount: _locations!.length,
                        itemBuilder: (context, i) {
                          final item = _locations![i];
                          if (item is! Map<String, dynamic>) {
                            return const SizedBox.shrink();
                          }
                          final d = item;
                          final label = d['label'] ?? '????';
                          final address = d['address'] ?? '';
                          final lat = (d['lat'] as num?)?.toDouble();
                          final lng = (d['lng'] as num?)?.toDouble();

                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onLocationSelected(label, address, lat, lng);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgCool,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB8B1C8).withOpacity(0.6),
                                    blurRadius: 6,
                                    offset: const Offset(3, 3)),
                                  BoxShadow(
                                    color: const Color(0xFFB8B1C8).withOpacity(0.6),
                                    blurRadius: 6,
                                    offset: Offset(-3, -3)),
                                ]),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.chevron_left,
                                    color: primaryPurple.withOpacity(0.4),
                                    size: 14),
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
                                            color: Color(0xFF2D2A3A),
                                            fontFamily: 'Amiri')),
                                        const SizedBox(height: 2),
                                        Text(
                                          address,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6E6B7B),
                                            fontFamily: 'Amiri')),
                                      ])),
                                  const SizedBox(width: 12),
                                  // ? ?????? ?????? ???? ???? ???????
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: primaryPurple.withOpacity(0.08),
                                      shape: BoxShape.circle),
                                    child: Icon(
                                      CupertinoIcons.location_fill,
                                      color: primaryPurple,
                                        size: 16)),
                                ])));
                        },
                      )),

          const SizedBox(height: 16),
        ]));
  }
}

// ------------------------------------------------------------------------------
//  _UserAvatar — ?????? UserLocal.data['gender'] ??????
// ------------------------------------------------------------------------------
class _UserAvatar extends StatefulWidget {
  const _UserAvatar();

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _avatar('assets/images/avatar.png');

    final gender = UserLocal.data?['gender'] as String? ?? '';
    return _avatar(
      gender == '????'
          ? 'assets/images/avatarf.png'
          : 'assets/images/avatar.png');
  }

  Widget _avatar(String assetPath) => Container(
    padding: const EdgeInsets.all(3.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF7D29C6), width: 0.07),
      gradient: LinearGradient(colors: [Colors.black, Colors.grey.shade800])),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(60),
      child: Image.asset(assetPath, width: 44, height: 44, fit: BoxFit.fill)));
}

// ------------------------------------------------------------------------------
//  _PromotionsBanner — ? [????? 1] ???? Scrollable ???? SingleChildScrollView
//  ? [????? 2] ????? GlobalKey ???? Pull to Refresh
// ------------------------------------------------------------------------------
class _PromotionsBanner extends StatefulWidget {
  // ? ????? key ?????? ??????? ???? ?? _DashboardScreenState
  const _PromotionsBanner({super.key});

  @override
  State<_PromotionsBanner> createState() => _PromotionsBannerState();
}

class _PromotionsBannerState extends State<_PromotionsBanner> {
  static List<Map<String, dynamic>> _cachedPromos =
      []; // ????? ?? String ??? Map
  static int _cachedVersion = -1;

  late final PageController _pageController;
  Timer? _timer;
  bool _loading = false;

  final Map<int, double> _pageHeights = {};
  int _currentPage = 0;

  int get _safeInitialPage =>
      _cachedPromos.isEmpty ? 5000 : _cachedPromos.length * 500;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.9,
      initialPage: _safeInitialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cachedPromos.isNotEmpty && mounted) _startTimer();
    });
    _pageController.addListener(() {
      if (!_pageController.hasClients) return;
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
    _checkVersionAndLoad();
  }

  void _onHeightComputed(int realIndex, double height) {
    _pageHeights[realIndex] = height;
    if (mounted && _currentPage % _cachedPromos.length == realIndex) {
      setState(() {});
    }
  }

  Future<void> _checkVersionAndLoad() async {
    // ??? ???? ??????? ?????? ???? ???? ???????
    if (mounted && _cachedPromos.isEmpty) {
      setState(() => _loading = true);
    }

    // ???? ?????? ???? ?????? ???? ??? ??????
    await _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    try {
      final promotions = await ApiClient.getList('/api/promotions');
      final List<Map<String, dynamic>> filteredPromos = [];
      final now = DateTime.now();

      for (var data in promotions) {
        if (data is! Map<String, dynamic>) continue;
        final bool isDeleted = data['isDeleted'] ?? false;
        final String? deletedAtStr = data['deletedAt'] as String?;

        // ???? ????? ??????? ??? 72 ????
        if (isDeleted && deletedAtStr != null) {
          final deletedAt = DateTime.tryParse(deletedAtStr);
          if (deletedAt != null) {
            final int hoursPassed = now.difference(deletedAt).inHours;
            if (hoursPassed >= 72) {
              continue;
            }
          }
        }

        // ????? ????? ???????
        filteredPromos.add(data);
      }

      // 2. ????? ????? ???????? ???????
      _cachedPromos = filteredPromos;

      if (mounted) {
        setState(() {
          _loading = false;
        });
        // ??? ??????? ???????? ??? ??? ???? ???? ?? ???
        if (_cachedPromos.isNotEmpty) _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_cachedPromos.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageController.page?.round() ?? _safeInitialPage) + 1;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 170,
        child: Center(child: CupertinoActivityIndicator()));
    }

    if (_cachedPromos.isEmpty) {
      return SizedBox(
        height: 130,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6E5E5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8B1C8).withOpacity(0.6),
                blurRadius: 10,
                offset: const Offset(4, 4)),
              BoxShadow(
                color: const Color(0xFFB8B1C8).withOpacity(0.6),
                blurRadius: 10,
                offset: Offset(-4, -4)),
            ]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.tag, color: Colors.grey.shade400, size: 32),
              const SizedBox(width: 12),
              Text(
                '???? ???? ??????',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Amiri')),
            ])));
    }

    // ? Banner ?????? ???? ??? — ?? ?????? ?? ??????? ???????
    final realCurrent = _currentPage % _cachedPromos.length;
    final currentHeight = _pageHeights[realCurrent] ?? 170;
    return SizedBox(
      height: currentHeight,
      child: PageView.builder(
        clipBehavior: Clip.none,
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final realIndex = index % _cachedPromos.length;
          return _BannerItem(
            index: realIndex,
            promoData: _cachedPromos[realIndex],
            onHeightComputed: _onHeightComputed);
        }));
  }
}

class _BannerItem extends StatefulWidget {
  final int index;
  final Map<String, dynamic> promoData;
  final void Function(int index, double height) onHeightComputed;
  const _BannerItem({required this.index, required this.promoData, required this.onHeightComputed});

  @override
  State<_BannerItem> createState() => _BannerItemState();
}

class _BannerItemState extends State<_BannerItem> {
  Size? _imageSize;
  bool _reportSent = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(_BannerItem old) {
    super.didUpdateWidget(old);
    if (widget.promoData['image'] != old.promoData['image']) {
      _imageSize = null;
      _reportSent = false;
      _loadImageSize();
    }
  }

  void _loadImageSize() {
    final url = widget.promoData['image'] ?? '';
    if (url.isEmpty) return;
    final ImageStream stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    stream.addListener(ImageStreamListener(
      (ImageInfo info, bool sync) {
        if (!mounted) return;
        final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
        setState(() => _imageSize = size);
      },
      onError: (_, __) {},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.promoData['isActive'] ?? true;
    final bool isDeleted = widget.promoData['isDeleted'] ?? false;
    final bool isStopped = !isActive && !isDeleted;
    final Color kPrimary = const Color(0xFF7D29C6);

    final containerWidth = MediaQuery.of(context).size.width * 0.9 - 16;
    final computedHeight = _imageSize != null
        ? containerWidth / (_imageSize!.width / _imageSize!.height)
        : 170.0;

    if (_imageSize != null && !_reportSent) {
      _reportSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onHeightComputed(widget.index, computedHeight);
      });
    }

    return GestureDetector(
      onTap: () {
        if (!isActive || isDeleted) return;
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('???? ????? ??? ???? ?????? ?????',
                textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Amiri')),
            backgroundColor: const Color(0xFF7D29C6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          return;
        }
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _OfferDetailSheet(promo: widget.promoData));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7D29C6).withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7D29C6).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4)),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 2)),
          ]),
        child: Stack(
          children: [
            // -- 1. ???? ????? --
            Positioned.fill(
              child: Opacity(
                opacity: (!isActive || isDeleted) ? 0.45 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: widget.promoData['image'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFDDDDDD),
                      child: const Center(child: CupertinoActivityIndicator())),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFE0E0E0),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          color: Colors.grey,
                          size: 32))))))),



            // -- 3. ????? "?????" --
            if (isDeleted)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.8),
                      width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10),
                    ]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "?????",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFamily: 'Amiri')),
                      Text(
                        "???? ????? ??????? ???? 3 ????",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                          fontFamily: 'Amiri')),
                    ]))),

            // -- 3. ????? "?????" --
            if (isStopped)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.8),
                      width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10),
                    ]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "?????",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          fontFamily: 'Amiri')),
                      Text(
                        "????? ??? ????? ??????",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                          fontFamily: 'Amiri')),
                    ]))),

          ])));
  }
}

class _OfferDetailSheet extends StatefulWidget {
  final Map<String, dynamic> promo;
  const _OfferDetailSheet({required this.promo});
  @override
  State<_OfferDetailSheet> createState() => _OfferDetailSheetState();
}

class _OfferDetailSheetState extends State<_OfferDetailSheet> {
  int _quantity = 1;
  int _uiStyle = 1;
  bool _loadingStyle = true;

  @override
  void initState() {
    super.initState();
    _loadStoreStyle();
  }

  Future<void> _loadStoreStyle() async {
    final storeId = widget.promo['storeId'] as String?;
    if (storeId == null || storeId.isEmpty) {
      if (mounted) setState(() => _loadingStyle = false);
      return;
    }
    try {
      final store = await ApiClient.get('/api/stores/$storeId');
      if (mounted) {
        setState(() {
          _uiStyle = (store['uiStyle'] as num?)?.toInt() ?? 1;
          _loadingStyle = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStyle = false);
    }
  }

  void _addToCart() {
    final rawLat = (widget.promo['storeLat'] as num?)?.toDouble();
    final rawLng = (widget.promo['storeLng'] as num?)?.toDouble();
    final product = Product(
      productId: widget.promo['_id'] ?? widget.promo['productId'] ?? 'promo_${DateTime.now().millisecondsSinceEpoch}',
      name: widget.promo['title'] ?? '??? ???',
      price: (widget.promo['price'] as num?)?.toDouble() ?? 0.0,
      imagePath: widget.promo['image'] ?? '',
      capacite: widget.promo['capacite'] ?? '',
      priceAffiche: "${(widget.promo['price'] as num?)?.toInt() ?? 0} DA",
      description: widget.promo['description'] ?? '',
      storeId: widget.promo['storeId'] ?? '',
      storeName: widget.promo['storeName'] ?? '??? ???',
      templateName: widget.promo['templateName'] ?? '',
      storeLat: (rawLat != null && rawLat != 0) ? rawLat : null,
      storeLng: (rawLng != null && rawLng != 0) ? rawLng : null,
      categoryName: widget.promo['categoryName'] ?? '??? ???',
      quantity: _quantity,
      uiStyle: _uiStyle,
      models: [],
      toppings: []);

    if (!GlobalCart.provider.toggle(product)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GlobalCart.provider.lastError ?? '?? ???? ????? ?????',
            textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri')),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    GlobalCart.cartKey.currentState?.runCartAnimation(GlobalCart.provider.count.toString());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promo;
    final price = (p['price'] as num?)?.toInt() ?? 0;
    final isProject = _uiStyle == 6;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F0F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                memCacheWidth: 400,
                imageUrl: p['image'] ?? '',
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFFDDDDDD),
                  child: const Center(child: CupertinoActivityIndicator())),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: const Color(0xFFE0E0E0),
                  child: const Icon(CupertinoIcons.photo, color: Colors.grey, size: 40)))),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(p['storeName'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFF7D29C6),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                    fontSize: 13)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7D29C6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(p['categoryName'] ?? p['templateName'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 10,
                      color: Color(0xFF7D29C6))),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(p['title'] ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
                color: Color(0xFF2D2A3A))),
            const SizedBox(height: 10),

            if ((p['description'] as String?)?.isNotEmpty == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.4), blurRadius: 8, offset: const Offset(3, 3)),
                    const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
                  ]),
                child: Text(p['description'] ?? '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF4A4560))),
              ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _quantityBtn(CupertinoIcons.add, () => setState(() => _quantity++)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFB8B1C8).withOpacity(0.4), blurRadius: 5, offset: const Offset(2, 2)),
                          const BoxShadow(color: Colors.white, blurRadius: 5, offset: Offset(-2, -2)),
                        ]),
                      child: Text("$_quantity",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    _quantityBtn(CupertinoIcons.minus, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                  ],
                ),
                Text("$price DA",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7D29C6))),
              ],
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _loadingStyle ? null : _addToCart,
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7D29C6), Color(0xFF9B4DE0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7D29C6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                  ]),
                child: Center(
                  child: _loadingStyle
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isProject ? CupertinoIcons.doc_text : CupertinoIcons.shopping_cart,
                            color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isProject ? '????? ??? ??? ???????' : '????? ??? ?????',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Amiri')),
                        ]))),
            ),
          ])));
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0F5),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(4, 4)),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: Offset(-4, -4)),
        ]),
      child: Icon(icon, color: const Color(0xFF7D29C6), size: 20)));
}
