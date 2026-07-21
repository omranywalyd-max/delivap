    import 'dart:async';
    import 'dart:math' as math;
    import 'dart:ui' as ui;
    import 'package:flutter/material.dart';
    import 'package:flutter/cupertino.dart';
    import 'package:flutter/services.dart';
    import 'package:geolocator/geolocator.dart';
    import 'package:google_maps_flutter/google_maps_flutter.dart';
    import 'package:url_launcher/url_launcher.dart';

    // ══════════════════════════════════════════════════════════════════════════════
    //  🎨  Design System — Purple Luxury Palette
    // ══════════════════════════════════════════════════════════════════════════════
    class AppColors {
      // Core Purple Spectrum
      static const Color deepViolet    = Color(0xFF3D0068);
      static const Color richPurple    = Color(0xFF3D0066);
      static const Color primary       = Color(0xFF9C27B0); 
      static const Color vibrant       = Color(0xFF7B52CC);
      static const Color soft          = Color(0xFFAB5FE0);
      static const Color blush         = Color(0xFFD4A8F0);
      static const Color lavender      = Color(0xFFF0E6FF);
      static const Color frosted       = Color(0xFFFAF5FF);

      // Accent — Electric Violet
      static const Color neonAccent    = Color(0xFFBD4FF5);
      static const Color glowAccent    = Color(0xFF9D1FE8);

      // Semantic
      static const Color success       = Color(0xFF00C48C);
      static const Color successLight  = Color(0xFFE6FBF4);
      static const Color danger        = Color(0xFFFF5C5C);
      static const Color dangerLight   = Color(0xFFFFF0F0);
      static const Color warning       = Color(0xFFFFB547);

      // Neutrals
      static const Color textPrimary   = Color(0xFF1A0033);
      static const Color textSecondary = Color(0xFF7A5A9A);
      static const Color textMuted     = Color(0xFFB0A0C0);
      static const Color divider       = Color(0xFFEBDEFF);
      static const Color surface       = Color(0xFFFFFFFF);
      static const Color surfaceAlt    = Color(0xFFF8F2FF);

      // Gradients
      static const LinearGradient headerGradient = LinearGradient(
        colors: [Color(0xFF9C27B0), richPurple, primary, vibrant],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);

      static const LinearGradient cardGradient = LinearGradient(
        colors: [Color(0xFF2D0050), primary],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter);

      static const LinearGradient shimmerGradient = LinearGradient(
        colors: [lavender, Color(0xFFE8D5FF), lavender],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight);
    }

    class AppShadows {
      static List<BoxShadow> get purple => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: -4),
        BoxShadow(
          color: AppColors.neonAccent.withOpacity(0.15),
          blurRadius: 40,
          offset: const Offset(0, 20),
          spreadRadius: -8),
      ];

      static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.18),
          blurRadius: 30,
          offset: const Offset(0, 12),
          spreadRadius: -6),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2)),
      ];

      static List<BoxShadow> get subtle => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4)),
      ];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  DriverRouteMapScreen
    // ══════════════════════════════════════════════════════════════════════════════
    class DriverRouteMapScreen extends StatefulWidget {
      final List<Map<String, dynamic>> activeOrders;

      const DriverRouteMapScreen({super.key, required this.activeOrders});

      @override
      State<DriverRouteMapScreen> createState() => _DriverRouteMapScreenState();
    }

    class _DriverRouteMapScreenState extends State<DriverRouteMapScreen>
        with TickerProviderStateMixin {

      // ── Google Map ─────────────────────────────────────────────────────────────
      final Completer<GoogleMapController> _mapController = Completer();
      Set<Marker>   _markers   = {};
      Set<Polyline> _polylines = {};
      List<LatLng>  _traveledPath = [];
      late Map<_StoreKey, String> _allStoresForMarkers;
      Map<_StoreKey, Map<String, List<Map<String, dynamic>>>> _fullGrouped = {};

      // ── Location ───────────────────────────────────────────────────────────────
      StreamSubscription<Position>? _positionStream;
      LatLng? _currentLatLng;

      // ── Data ───────────────────────────────────────────────────────────────────
      late Map<_StoreKey, Map<String, List<Map<String, dynamic>>>> _grouped;
      late Map<_StoreKey, String> _storeNames;
      List<Map<String, dynamic>> _customerData = [];
      List<_StoreKey> _orderedStoreKeys = [];
      List<LatLng>    _fullSequence     = [];
      final List<Color> legColors = [
    AppColors.neonAccent, 
    Colors.orangeAccent,  
    Colors.cyanAccent,    
    Colors.greenAccent,   
    Colors.yellowAccent,  
    Colors.pinkAccent,    
  ];

      // ── Selected Store ──────────────────────────────────────────────────────────
      _StoreKey? _selectedKey;
      LatLng?    _selectedLatLng;
      double     _currentZoom = 17;
      Offset?    _cardScreenOffset;

      // ── Visible Map Bounds ─────────────────────────────────────────────────────
      LatLngBounds? _visibleBounds;

      // ── Bottom Stats Panel ──────────────────────────────────────────────────────
      bool _statsExpanded = false;

      // ── Animations ─────────────────────────────────────────────────────────────
      late AnimationController _cardAnim;
      late Animation<double>   _cardScale;
      late Animation<double>   _cardFade;
      late AnimationController _headerAnim;
      late Animation<Offset>   _headerSlide;
      late Animation<double>   _headerFade;
      late AnimationController _pulseAnim;
      late Animation<double>   _pulse;

      // ── Map Style ──────────────────────────────────────────────────────────────
      static const String _mapStyle = '''[
        {"featureType":"all","elementType":"geometry","stylers":[{"color":"#F8F2FF"}]},
        {"featureType":"road","elementType":"geometry","stylers":[{"color":"#EAD9FF"}]},
        {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#D4B8F0"}]},
        {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#C09AE8"}]},
        {"featureType":"water","elementType":"geometry","stylers":[{"color":"#DDD0FF"}]},
        {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#F0E6FF"}]},
        {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#E8D8FF"}]},
        {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#E4D4FF"}]},
        {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#FAF5FF"}]},
        {"elementType":"labels.text.fill","stylers":[{"color":"#6B3FA0"}]},
        {"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"},{"weight":3}]}
      ]''';

      static const LatLng _defaultCenter = LatLng(35.6969, -0.6331);

      @override
      void initState() {
        super.initState();

        // Card animation — spring bounce
        _cardAnim = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420));
        _cardScale = CurvedAnimation(parent: _cardAnim, curve: Curves.elasticOut);
        _cardFade  = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);

        // Header slide-in
        _headerAnim = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600));
        _headerSlide = Tween<Offset>(
          begin: const Offset(0, -1.2),
          end: Offset.zero).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutQuint));
        _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeIn);

        // Pulse for driver marker
        _pulseAnim = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
        _pulse = Tween<double>(begin: 0.85, end: 1.15)
            .animate(CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut));

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _groupOrdersByStore();
          debugPrint('📊 _grouped.length = ${_grouped.length}, _customerData.length = ${_customerData.length}');
          await _buildCustomMarkers();
          _headerAnim.forward();
          // جلب الموقع فوراً — لا ننتظر الـ Stream
          _initializeFirstLocation();
          _startTracking();
        });
      }

      @override
      void didUpdateWidget(covariant DriverRouteMapScreen old) {
        super.didUpdateWidget(old);
        _groupOrdersByStore();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _buildCustomMarkers();
          _forceRedrawRoute();
        });
      }

      @override
      void dispose() {
        _positionStream?.cancel();
        _cardAnim.dispose();
        _headerAnim.dispose();
        _pulseAnim.dispose();
        super.dispose();
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Live Tracking
      // ══════════════════════════════════════════════════════════════════════════
      void _startTracking() {
      const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);

      void onPosition(Position p) async {
        if (!mounted) return;
        final newPos = LatLng(p.latitude, p.longitude);

        final bool firstFix = _currentLatLng == null;
        setState(() => _currentLatLng = newPos);

        if (firstFix) {
          _calculateInitialOrder(newPos);
          _calculateCompleteSequence(newPos);
          debugPrint('📌 أول GPS: _fullSequence.length = ${_fullSequence.length}');
          _getRoadDirection();
          if (mounted) {
            final ctrl = await _mapController.future;
            ctrl.animateCamera(CameraUpdate.newLatLngZoom(newPos, 14));
          }
          return;
        }

        _getRoadDirection();
      }

      void onError(Object e) {
        debugPrint('⚠️ GPS error: $e');
      }

      void onDone() {
        debugPrint('🔄 GPS stream closed — إعادة الاشتراك...');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startTracking();
        });
      }

      _positionStream = Geolocator.getPositionStream(locationSettings: settings)
          .listen(onPosition, onError: onError, onDone: onDone, cancelOnError: false);
    }

      // ══════════════════════════════════════════════════════════════════════════
      //  First Location — جلب الموقع فور فتح الصفحة
      // ══════════════════════════════════════════════════════════════════════════
      Future<void> _initializeFirstLocation() async {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));

          final startPos = LatLng(position.latitude, position.longitude);

          if (mounted) {
            setState(() => _currentLatLng = startPos);

            _calculateInitialOrder(startPos);
            _calculateCompleteSequence(startPos);
            _getRoadDirection();

            final ctrl = await _mapController.future;
            ctrl.animateCamera(CameraUpdate.newLatLngZoom(startPos, 14));
          }
        } catch (e) {
          debugPrint("⚠️ فشل جلب الموقع الأولي: $e");
          _forceRedrawRoute();
        }
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Polyline Drawing — Multi-Color Segments
      // ══════════════════════════════════════════════════════════════════════════
      // ══════════════════════════════════════════════════════════════════════════
    //  Polyline Drawing — ألوان مختلفة لكل مقطع + حل مشكلة الاختفاء
    // ══════════════════════════════════════════════════════════════════════════
    // 👈 دالة رسم الخطوط - تم تعديلها لتكون ثابتة ولا تختفي
    void _getRoadDirection() {
    final LatLng? start = _currentLatLng;
    if (start == null) return; // ما نرسمو حتى خط بدون موقع السائق
    if (_fullSequence.isEmpty) {
      _calculateInitialOrder(start);
      _calculateCompleteSequence(start);
      if (_fullSequence.isEmpty) {
        if (mounted) setState(() => _polylines = {});
        return;
      }
    }

    List<LatLng> remaining = _getRemainingSequence();
    if (remaining.length < 2) {
      if (mounted) setState(() => _polylines = {});
      return;
    }

    final List<LatLng> routePoints = [remaining[0]];
    for (int j = 1; j < remaining.length; j++) {
      final pos = remaining[j];

      _StoreKey? sk;
      for (final key in _storeNames.keys) {
        if (_samePoint(pos, LatLng(key.lat, key.lng))) { sk = key; break; }
      }

      if (sk != null) {
        final active = _grouped[sk]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
        if (active == 0) continue;
      } else {
        String? custName;
        for (final c in _customerData) {
          if (_samePoint(pos, c['latlng'] as LatLng)) {
            custName = c['name'] as String;
            break;
          }
        }
        if (custName != null && _isCustomerComplete(custName)) continue;
      }

      if (routePoints.length > 1) {
        final dist = Geolocator.distanceBetween(
          routePoints.last.latitude, routePoints.last.longitude,
          pos.latitude, pos.longitude);
        if (dist < 30) continue;
      }
      routePoints.add(pos);
    }

    if (routePoints.length < 2) {
      if (mounted) setState(() => _polylines = {});
      return;
    }

    final Set<Polyline> polys = {};
    for (int i = 0; i < routePoints.length - 1; i++) {
      if (routePoints[i] == routePoints[i + 1]) continue;
      polys.add(Polyline(
        polylineId: PolylineId('seg_$i'),
        points: [routePoints[i], routePoints[i + 1]],
        color: legColors[i % legColors.length],
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap));
    }

    if (mounted) setState(() => _polylines = polys);
  }

  LatLng _firstStoreOrFallback() {
    if (_storeNames.isNotEmpty) {
      final key = _storeNames.keys.first;
      return LatLng(key.lat, key.lng);
    }
    return const LatLng(36.7372, 3.0863);
  }

  void _forceRedrawRoute() async {
      HapticFeedback.mediumImpact();
      try {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)));
        } catch (_) {}
        if (pos != null) {
          final newPos = LatLng(pos.latitude, pos.longitude);
          setState(() => _currentLatLng = newPos);
        }
      } catch (_) {}
      final start = _currentLatLng;
      if (start == null) {
        // ما عندناش GPS، نحاول مرة أخرى
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
          final newPos = LatLng(pos.latitude, pos.longitude);
          setState(() => _currentLatLng = newPos);
          _calculateInitialOrder(newPos);
          _calculateCompleteSequence(newPos);
          _getRoadDirection();
          return;
        } catch (_) {}
        // احتياطي: ارسم المسار بين المحلات فقط
        if (_storeNames.isNotEmpty) {
          final firstStore = _storeNames.keys.first;
          final fallbackPos = LatLng(firstStore.lat, firstStore.lng);
          _calculateInitialOrder(fallbackPos);
          _calculateCompleteSequence(fallbackPos);
          _getRoadDirection();
        }
        return;
      }
      _calculateInitialOrder(start);
      _calculateCompleteSequence(start);
      _getRoadDirection();
    }
    List<LatLng> _getRemainingSequence() {
      if (_fullSequence.isEmpty) return [];
      final LatLng? start = _currentLatLng;
      if (start == null) return [];

      int bestIdx = 0;
      double bestDist = double.infinity;
      for (int i = 0; i < _fullSequence.length; i++) {
        final d = Geolocator.distanceBetween(
          start.latitude, start.longitude,
          _fullSequence[i].latitude, _fullSequence[i].longitude);
        if (d < bestDist) {
          if (i + 1 < _fullSequence.length) {
            final nextD = Geolocator.distanceBetween(
              start.latitude, start.longitude,
              _fullSequence[i + 1].latitude, _fullSequence[i + 1].longitude);
            if (nextD > d) {
              bestDist = d;
              bestIdx = i;
            }
          } else {
            bestDist = d;
            bestIdx = i;
          }
        }
      }

      List<LatLng> points = [start];
      for (int j = bestIdx; j < _fullSequence.length; j++) {
        final pos = _fullSequence[j];
        if (pos == points.last) continue;

        _StoreKey? sk;
        for (final key in _storeNames.keys) {
          if (_samePoint(pos, LatLng(key.lat, key.lng))) { sk = key; break; }
        }

        if (sk != null) {
          final active = _grouped[sk]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
          if (active == 0) continue;
        } else {
          String? cname;
          for (final c in _customerData) {
            if (_samePoint(pos, c['latlng'] as LatLng)) {
              cname = c['name'] as String;
              break;
            }
          }
          if (cname != null && _isCustomerComplete(cname)) continue;
        }

        points.add(pos);
      }
      return points;
    }

      

      // ══════════════════════════════════════════════════════════════════════════
      //  Route Calculation
      // ══════════════════════════════════════════════════════════════════════════
      void _calculateInitialOrder(LatLng start) {
        List<_StoreKey> rem = _grouped.keys.toList();
        _orderedStoreKeys = [];
        LatLng ref = start;
        while (rem.isNotEmpty) {
          final n = _findNearestStore(ref, rem);
          if (n != null) {
            _orderedStoreKeys.add(n);
            ref = LatLng(n.lat, n.lng);
            rem.remove(n);
          }
        }
      }

      void _calculateCompleteSequence(LatLng start) {
        _fullSequence = [start];

        final List<_StoreKey> remStores = _grouped.keys.toList();
        final List<Map<String, dynamic>> remCusts =
            _customerData.map((c) => Map<String, dynamic>.from(c)).toList();

        // خريطة: كل زبون → المحلات اللي يحتاجها
        final Map<String, Set<_StoreKey>> reqStores = {};
        for (final entry in _grouped.entries) {
          for (final cName in entry.value.keys) {
            reqStores.putIfAbsent(cName, () => {});
            reqStores[cName]!.add(entry.key);
          }
        }

        // ── المرحلة 1: ترتيب المحلات (أقرب جار) ──────────────────────────
        LatLng ref = start;
        final List<_StoreKey> storeOrder = [];
        final List<_StoreKey> unvisitedStores = List.from(remStores);
        while (unvisitedStores.isNotEmpty) {
          _StoreKey? best;
          int bestIdx = -1;
          double bestD = double.infinity;
          for (int i = 0; i < unvisitedStores.length; i++) {
            final s = unvisitedStores[i];
            final d = Geolocator.distanceBetween(
                ref.latitude, ref.longitude, s.lat, s.lng);
            if (d < bestD) { bestD = d; best = s; bestIdx = i; }
          }
          if (best == null) break;
          storeOrder.add(best);
          ref = LatLng(best.lat, best.lng);
          unvisitedStores.removeAt(bestIdx);
        }

        // ── تحسين 2-opt على ترتيب المحلات فقط ──────────────────────────
        _twoOpt(storeOrder, start);

        // ── المرحلة 2: بناء المسار الكامل (محلات + زبائن) ──────────────
        _fullSequence = [start];
        for (final s in storeOrder) {
          _fullSequence.add(LatLng(s.lat, s.lng));
        }

        // ── إدراج الزبائن في أفضل موقع ──────────────────────────────────
        final List<Map<String, dynamic>> pendingCusts =
            _customerData.map((c) => Map<String, dynamic>.from(c)).toList();

        pendingCusts.sort((a, b) {
          final da = Geolocator.distanceBetween(start.latitude, start.longitude,
              (a['latlng'] as LatLng).latitude, (a['latlng'] as LatLng).longitude);
          final db = Geolocator.distanceBetween(start.latitude, start.longitude,
              (b['latlng'] as LatLng).latitude, (b['latlng'] as LatLng).longitude);
          return da.compareTo(db);
        });

        for (final cust in pendingCusts) {
          final name = cust['name'] as String;
          final custPos = cust['latlng'] as LatLng;
          final required = reqStores[name] ?? {};

          int lastReqStoreIdx = 0;
          for (int i = 1; i < _fullSequence.length; i++) {
            final pos = _fullSequence[i];
            for (final sk in required) {
              if (_samePoint(pos, LatLng(sk.lat, sk.lng))) {
                if (i > lastReqStoreIdx) lastReqStoreIdx = i;
              }
            }
          }

          int bestPos = lastReqStoreIdx + 1;
          double bestIncrease = double.infinity;

          for (int p = lastReqStoreIdx + 1; p <= _fullSequence.length; p++) {
            final prev = p > 0 ? _fullSequence[p - 1] : null;
            final next = p < _fullSequence.length ? _fullSequence[p] : null;

            double beforeDist = 0;
            if (prev != null && next != null) {
              beforeDist = Geolocator.distanceBetween(
                  prev.latitude, prev.longitude,
                  next.latitude, next.longitude);
            }

            double afterDist = 0;
            if (prev != null) {
              afterDist += Geolocator.distanceBetween(
                  prev.latitude, prev.longitude,
                  custPos.latitude, custPos.longitude);
            }
            if (next != null) {
              afterDist += Geolocator.distanceBetween(
                  custPos.latitude, custPos.longitude,
                  next.latitude, next.longitude);
            }

            final increase = afterDist - beforeDist;
            if (increase < bestIncrease) {
              bestIncrease = increase;
              bestPos = p;
            }
          }

          _fullSequence.insert(bestPos, custPos);
        }

        // ── المرحلة 3: تحسين 2-opt على المسار الكامل ────────────────────
        _optimizeFullRoute(start, reqStores);
      }

      // ── 2-opt على المسار الكامل مع احترام الشرط ────────────────────────
      void _optimizeFullRoute(LatLng start, Map<String, Set<_StoreKey>> reqStores) {
        if (_fullSequence.length < 5) return;

        // بناء مصفوفة نوع كل نقطة في المسار
        final List<bool> isStore = List.filled(_fullSequence.length, false);
        final List<String?> custName = List.filled(_fullSequence.length, null);

        for (int i = 1; i < _fullSequence.length; i++) {
          final pos = _fullSequence[i];
          for (final key in _storeNames.keys) {
            if (_samePoint(pos, LatLng(key.lat, key.lng))) {
              isStore[i] = true;
              break;
            }
          }
          if (!isStore[i]) {
            for (final c in _customerData) {
              if (_samePoint(pos, c['latlng'] as LatLng)) {
                custName[i] = c['name'] as String;
                break;
              }
            }
          }
        }

        // التحقق من إمكانية عكس المقطع دون كسر الشرط
        bool canReverse(int i, int j) {
          // نبني الترتيب المقلوب ونتحقق من كل زبون
          final reversedTypes = <bool>[];  // true = محل
          final reversedNames = <String?>[];
          for (int k = j; k >= i; k--) {
            reversedTypes.add(isStore[k]);
            reversedNames.add(custName[k]);
          }

          for (int ri = 0; ri < reversedTypes.length; ri++) {
            if (!reversedTypes[ri] && reversedNames[ri] != null) {
              final required = reqStores[reversedNames[ri]!] ?? {};
              for (int rj = ri + 1; rj < reversedTypes.length; rj++) {
                if (reversedTypes[rj]) {
                  for (final key in _storeNames.keys) {
                    if (_samePoint(_fullSequence[j - rj], LatLng(key.lat, key.lng))) {
                      if (required.contains(key)) return false;
                    }
                  }
                }
              }
            }
          }
          return true;
        }

        double distBetween(int a, int b) => Geolocator.distanceBetween(
            _fullSequence[a].latitude, _fullSequence[a].longitude,
            _fullSequence[b].latitude, _fullSequence[b].longitude);

        bool improved = true;
        int iter = 0;
        while (improved && iter < 50) {
          improved = false;
          iter++;
          for (int i = 1; i < _fullSequence.length - 2; i++) {
            for (int j = i + 2; j < _fullSequence.length - 1; j++) {
              if (!canReverse(i, j)) continue;

              final curDist = distBetween(i - 1, i) + distBetween(j, j + 1);
              final newDist = distBetween(i - 1, j) + distBetween(i, j + 1);

              if (newDist < curDist) {
                for (int k = 0; k < (j - i + 1) ~/ 2; k++) {
                  final tmp = _fullSequence[i + k];
                  _fullSequence[i + k] = _fullSequence[j - k];
                  _fullSequence[j - k] = tmp;
                }
                improved = true;
              }
            }
          }
        }
      }

      // ── 2-opt على قائمة من المحلات ────────────────────────────────────
      void _twoOpt(List<_StoreKey> route, LatLng start) {
        if (route.length < 3) return;
        bool improved = true;
        int iter = 0;
        while (improved && iter < 50) {
          improved = false;
          iter++;
          for (int i = 0; i < route.length - 2; i++) {
            for (int j = i + 2; j < route.length - 1; j++) {
              final a = (i == 0) ? start : LatLng(route[i - 1].lat, route[i - 1].lng);
              final b = LatLng(route[i].lat, route[i].lng);
              final c = LatLng(route[j].lat, route[j].lng);
              final d = (j + 1 < route.length)
                  ? LatLng(route[j + 1].lat, route[j + 1].lng)
                  : LatLng(route[j].lat, route[j].lng);

              final curDist = Geolocator.distanceBetween(
                      a.latitude, a.longitude, b.latitude, b.longitude) +
                  Geolocator.distanceBetween(
                      c.latitude, c.longitude, d.latitude, d.longitude);
              final newDist = Geolocator.distanceBetween(
                      a.latitude, a.longitude, c.latitude, c.longitude) +
                  Geolocator.distanceBetween(
                      b.latitude, b.longitude, d.latitude, d.longitude);

              if (newDist < curDist) {
                for (int k = 0; k < (j - i + 1) ~/ 2; k++) {
                  final tmp = route[i + k];
                  route[i + k] = route[j - k];
                  route[j - k] = tmp;
                }
                improved = true;
              }
            }
          }
        }
      }

      // ── تحقق إذا الزبون كمل كل مشترياته ──────────────────────────────────
      bool _isCustomerComplete(String name) {
        for (final entry in _grouped.entries) {
          final items = entry.value[name];
          if (items != null && items.isNotEmpty) return false;
        }
        return true;
      }

      bool _samePoint(LatLng a, LatLng b) {
        return (a.latitude - b.latitude).abs() < 0.00001 &&
               (a.longitude - b.longitude).abs() < 0.00001;
      }

      _StoreKey? _findNearestStore(LatLng cur, List<_StoreKey> list) {
        _StoreKey? nearest; double minD = double.infinity;
        for (final s in list) {
          final d = Geolocator.distanceBetween(cur.latitude, cur.longitude, s.lat, s.lng);
          if (d < minD) { minD = d; nearest = s; }
        }
        return nearest;
      }

      LatLng? _findNearestLatLng(LatLng cur, List<LatLng> list) {
        LatLng? nearest; double minD = double.infinity;
        for (final l in list) {
          final d = Geolocator.distanceBetween(cur.latitude, cur.longitude, l.latitude, l.longitude);
          if (d < minD) { minD = d; nearest = l; }
        }
        return nearest;
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Data Grouping
      // ══════════════════════════════════════════════════════════════════════════
  void _groupOrdersByStore() {
    final Map<_StoreKey, Map<String, List<Map<String, dynamic>>>> activeGroups = {};
    final Map<_StoreKey, Map<String, List<Map<String, dynamic>>>> allItemsGroups = {};
    final Map<_StoreKey, String> allNames = {};
    final List<Map<String, dynamic>> custs = [];

    for (final data in widget.activeOrders) {
      final bool isProject = data.containsKey('projectId');

      if (isProject) {
        final String status = data['status'] ?? '';
        final double? storeLat = (data['storeLat'] as num?)?.toDouble();
        final double? storeLng = (data['storeLng'] as num?)?.toDouble();
        final storeName = data['storeName'] as String? ?? 'محل';
        final customerName = data['customerName'] as String? ?? 'زبون';

        if (storeLat != null && storeLng != null) {
          final key = _StoreKey(storeLat, storeLng);
          allNames[key] = storeName;

          final dummyItem = <String, dynamic>{
            'name': 'مشروع',
            'storeName': storeName,
            'storeLat': storeLat,
            'storeLng': storeLng,
            'purchaseStatus': status == 'delivered' ? 'purchased' : '',
            'quantity': 1,
            'price': 0,
          };

          allItemsGroups.putIfAbsent(key, () => {});
          allItemsGroups[key]!.putIfAbsent(customerName, () => []);
          allItemsGroups[key]![customerName]!.add(dummyItem);

          if (status != 'delivered') {
            activeGroups.putIfAbsent(key, () => {});
            activeGroups[key]!.putIfAbsent(customerName, () => []);
            activeGroups[key]![customerName]!.add(dummyItem);
          }
        }

        final double? cLat = (data['customerLat'] as num?)?.toDouble();
        final double? cLng = (data['customerLng'] as num?)?.toDouble();
        if (cLat != null && cLng != null) {
          custs.add({'name': customerName, 'latlng': LatLng(cLat, cLng)});
        }
      } else if (data.containsKey('transportType')) {
        final userName = data['userName'] as String? ?? 'زبون';
        final fromLat = (data['fromLat'] as num?)?.toDouble();
        final fromLng = (data['fromLng'] as num?)?.toDouble();
        final toLat = (data['toLat'] as num?)?.toDouble();
        final toLng = (data['toLng'] as num?)?.toDouble();
        final transportType = data['transportType'] as String? ?? 'نقل';

        if (fromLat != null && fromLng != null) {
          final key = _StoreKey(fromLat, fromLng);
          allNames[key] = 'استلام: $transportType';
          final dummyItem = <String, dynamic>{
            'name': transportType,
            'storeName': 'استلام',
            'storeLat': fromLat,
            'storeLng': fromLng,
            'purchaseStatus': '',
            'quantity': 1,
            'price': 0,
          };
          allItemsGroups.putIfAbsent(key, () => {});
          allItemsGroups[key]!.putIfAbsent(userName, () => []);
          allItemsGroups[key]![userName]!.add(dummyItem);
          activeGroups.putIfAbsent(key, () => {});
          activeGroups[key]!.putIfAbsent(userName, () => []);
          activeGroups[key]![userName]!.add(dummyItem);
        }

        if (toLat != null && toLng != null) {
          custs.add({'name': userName, 'latlng': LatLng(toLat, toLng)});
        }
      } else if (data.containsKey('serviceType')) {
        final userName = data['userName'] as String? ?? 'زبون';
        final fromLat = (data['fromLat'] as num?)?.toDouble();
        final fromLng = (data['fromLng'] as num?)?.toDouble();
        final toLat = (data['toLat'] as num?)?.toDouble();
        final toLng = (data['toLng'] as num?)?.toDouble();
        final serviceType = data['serviceType'] as String? ?? 'توصيل';

        if (fromLat != null && fromLng != null) {
          final key = _StoreKey(fromLat, fromLng);
          allNames[key] = 'استلام: $serviceType';
          final dummyItem = <String, dynamic>{
            'name': serviceType,
            'storeName': 'استلام',
            'storeLat': fromLat,
            'storeLng': fromLng,
            'purchaseStatus': '',
            'quantity': 1,
            'price': 0,
          };
          allItemsGroups.putIfAbsent(key, () => {});
          allItemsGroups[key]!.putIfAbsent(userName, () => []);
          allItemsGroups[key]![userName]!.add(dummyItem);
          activeGroups.putIfAbsent(key, () => {});
          activeGroups[key]!.putIfAbsent(userName, () => []);
          activeGroups[key]![userName]!.add(dummyItem);
        }

        if (toLat != null && toLng != null) {
          custs.add({'name': userName, 'latlng': LatLng(toLat, toLng)});
        }
      } else {
        final items = data['items'] as List? ?? [];
        final customer = data['userName'] as String? ?? 'زبون';

        for (final raw in items) {
          final item = raw as Map<String, dynamic>;
          double? lat = (item['storeLat'] as num?)?.toDouble();
          double? lng = (item['storeLng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          final key = _StoreKey(lat, lng);
          allNames[key] = item['storeName'] as String? ?? 'محل';

          allItemsGroups.putIfAbsent(key, () => {});
          allItemsGroups[key]!.putIfAbsent(customer, () => []);
          allItemsGroups[key]![customer]!.add(item);

          final pStatus = item['purchaseStatus'] as String? ?? '';
          if (pStatus != 'purchased' && pStatus != 'unavailable') {
            activeGroups.putIfAbsent(key, () => {});
            activeGroups[key]!.putIfAbsent(customer, () => []);
            activeGroups[key]![customer]!.add(item);
          }
        }

        if (data['userLat'] != null && data['userLng'] != null) {
          custs.add({
            'name': customer,
            'latlng': LatLng(data['userLat'] as double, data['userLng'] as double),
          });
        }
      }
    }

    setState(() {
      _grouped = activeGroups;
      _fullGrouped = allItemsGroups;
      _storeNames = allNames;
      _customerData = custs;
    });
  }
      // ══════════════════════════════════════════════════════════════════════════
      //  Custom Markers — Refined Purple Design
      // ══════════════════════════════════════════════════════════════════════════
    Future<void> _buildCustomMarkers() async {
    final Set<Marker> markers = {};

    int storeIndex = 0;
    // ندور على كل المحلات اللي سجلناها في allNames
    for (final key in _storeNames.keys) {
      final name = _storeNames[key] ?? 'محل';
      
      // نحسب شحال كاين من منتج "مازال ماشريناهش" في هذا المحل
      final activeItems = _grouped[key]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
      
      // إذا كان activeItems == 0، يعني المحل "تم قضيان كل شيء منه"
      final bool isFinished = activeItems == 0;

      final icon = await _createStoreMarker(
        label: isFinished ? "✓" : activeItems.toString(), // علامة صح إذا كملنا
        storeName: name,
        index: storeIndex,
        isFinished: isFinished, // نمرر حالة الاكتمال لتغيير اللون إذا أردت
      );

      markers.add(Marker(
    markerId: MarkerId('store_${key.lat}_${key.lng}'),
    position: LatLng(key.lat, key.lng),
    icon: icon,
    anchor: const Offset(0.5, 1.0),
    onTap: () { // حذفنا شرط if (!isFinished)
      HapticFeedback.heavyImpact();
      _selectStore(key, LatLng(key.lat, key.lng)); // سيعمل دائماً الآن
    }));
      storeIndex++;
    }

        for (final cust in _customerData) {
          final custName = cust['name'] as String;
          final bool complete = _isCustomerComplete(custName);
          if (complete) continue;
          markers.add(Marker(
            markerId: MarkerId('cust_${custName}_${(cust['latlng'] as LatLng).latitude}'),
            position: cust['latlng'] as LatLng,
            icon: await _createCustomerMarker(custName, isComplete: false),
            anchor: const Offset(0.5, 1.0),
            infoWindow: InfoWindow(title: 'زبون: $custName')));
        }

        if (mounted) setState(() => _markers = markers);
        if (markers.isNotEmpty) _fitCamera(markers);
      }

      // ── Store Marker — Glass-morphism purple pill ──────────────────────────────
    Future<BitmapDescriptor> _createStoreMarker({
    required String label,
    required String storeName,
    required int index,
    bool isFinished = false, // مضافة لاستقبال حالة المحل
  }) async {
    const double w = 240, h = 130;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));

    // تحديد الألوان بناءً على الحالة
    final List<Color> colors = isFinished 
        ? [Colors.grey, Colors.blueGrey] // لون باهت للمحل المكتمل
        : [Color(0xFF2A004A), Color(0xFF5B00A0), Color(0xFF8B30C9)];
    final Color accentColor = isFinished ? Colors.blueGrey : AppColors.neonAccent;

    // 1. التوهج الخلفي (Glow)
    canvas.drawCircle(Offset(w / 2, (h - 30) / 2), 70, Paint()
        ..color = accentColor.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

    // 2. جسم الكارد (تعديل: استخدام الألوان الديناميكية)
    final bodyRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h - 30), const Radius.circular(25));
    canvas.drawRRect(bodyRect, Paint()
        ..shader = LinearGradient(
          colors: colors, // استخدام القائمة المعرفة أعلاه
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight).createShader(Rect.fromLTWH(0, 0, w, h - 30)));

    // 3. المثلث السفلي (تعديل: استخدامه بلون مناسب)
    final tri = Path()..moveTo(w / 2 - 20, h - 30)..lineTo(w / 2 + 20, h - 30)..lineTo(w / 2, h - 5)..close();
    canvas.drawPath(tri, Paint()..color = colors.last);

    // 4. رقم المرحلة
    _drawText(canvas, "${index + 1}", const Offset(20, 20), 14, Colors.white.withOpacity(0.5));

    // 5. أيقونة العربة (تغييرها لصح إذا كملنا)
    _drawText(canvas, isFinished ? '✅' : '🛒', const Offset(30, (h - 30) / 2), 25, Colors.white);

    // 6. اسم المحل
    final trimmed = storeName.length > 12 ? '${storeName.substring(0, 11)}…' : storeName;
    _drawText(canvas, trimmed, Offset(w / 2 + 10, (h - 30) / 2), 22, Colors.white, bold: true);

    // 7. دائرة عدد المنتجات (التاج)
    canvas.drawCircle(Offset(w - 30, 30), 20, Paint()..color = Colors.white);
    _drawText(canvas, label, Offset(w - 30, 30), 18, isFinished ? Colors.grey : AppColors.primary, bold: true);

    final pic = rec.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

      // ── Customer Marker — Elegant drop pin ─────────────────────────────────────
      Future<BitmapDescriptor> _createCustomerMarker(String name, {bool isComplete = false}) async {
        const double w = 250, h = 150;
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));

        // الألوان: حامق إذا كامل، باهت إذا لسّه
        final List<Color> colors = isComplete
            ? [const Color(0xFFB71C1C), const Color(0xFFEF5350), const Color(0xFFFF8A80)]
            : [const Color(0xFF9E9E9E), const Color(0xFFCFCFCF), const Color(0xFFE0E0E0)];
        final Color accentColor = isComplete ? const Color(0xFFFF5C5C) : const Color(0xFFBDBDBD);

        // Glow
        canvas.drawCircle(
          Offset(w / 2, (h - 28) / 2),
          45,
          Paint()
            ..color = accentColor.withOpacity(isComplete ? 0.2 : 0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

        // Body
        final bodyRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h - 26),
          const Radius.circular(20));
        canvas.drawRRect(
          bodyRect,
          Paint()
            ..shader = LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight).createShader(Rect.fromLTWH(0, 0, w, h - 26)));

        // Shimmer highlight
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 2, 152, 16),
            const Radius.circular(10)),
          Paint()..color = Colors.white.withOpacity(isComplete ? 0.15 : 0.08));

        // Border
        canvas.drawRRect(
          bodyRect,
          Paint()
            ..color = Colors.white.withOpacity(isComplete ? 0.3 : 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);

        // Pointer
        final tri = Path()
          ..moveTo(w / 2 - 12, h - 26)
          ..lineTo(w / 2 + 12, h - 26)
          ..lineTo(w / 2, h - 2)
          ..close();
        canvas.drawPath(tri,
            Paint()..color = colors.last);

        // Person icon + name
        _drawText(canvas, isComplete ? '✅' : '👤', const Offset(20, 20), 13, Colors.white);
        _drawText(canvas, 'الزبون', Offset(w / 2, 20), 25,
            Colors.white.withOpacity(isComplete ? 0.9 : 0.5));
        _drawText(canvas, name, Offset(w / 2, (h - 26) / 2 + 8), 25, Colors.white,
            bold: isComplete);

        final pic  = rec.endRecording();
        final img  = await pic.toImage(w.toInt(), h.toInt());
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
      }

      void _drawText(
        Canvas canvas,
        String text,
        Offset center,
        double fontSize,
        Color color, {
        bool bold = false,
      }) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          textDirection: TextDirection.rtl)..layout();
        painter.paint(
          canvas,
          Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Camera
      // ══════════════════════════════════════════════════════════════════════════
      Future<void> _fitCamera(Set<Marker> markers) async {
        if (markers.isEmpty) return;
        double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
        for (final m in markers) {
          minLat = math.min(minLat, m.position.latitude);
          maxLat = math.max(maxLat, m.position.latitude);
          minLng = math.min(minLng, m.position.longitude);
          maxLng = math.max(maxLng, m.position.longitude);
        }
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.003, minLng - 0.003),
            northeast: LatLng(maxLat + 0.003, maxLng + 0.003)),
          24));
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Card Positioning
      // ══════════════════════════════════════════════════════════════════════════
      Future<void> _recalcCardOffset(LatLng pos) async {
        if (!_mapController.isCompleted) return;
        final ctrl  = await _mapController.future;
        final point = await ctrl.getScreenCoordinate(pos);
        final ratio = MediaQuery.of(context).devicePixelRatio;
        if (mounted) {
          setState(() => _cardScreenOffset = Offset(
            point.x / ratio,
            point.y / ratio));
        }
      }

      Future<void> _selectStore(_StoreKey key, LatLng pos) async {
        setState(() {
          _selectedKey      = key;
          _selectedLatLng   = pos;
          _cardScreenOffset = null;
        });
        _cardAnim.forward(from: 0);
        await _recalcCardOffset(pos);
      }

      void _deselectStore() {
        _cardAnim.reverse().then((_) {
          if (mounted) {
            setState(() {
              _selectedKey      = null;
              _selectedLatLng   = null;
              _cardScreenOffset = null;
            });
          }
        });
      }

      // ══════════════════════════════════════════════════════════════════════════
      //  Build
      // ══════════════════════════════════════════════════════════════════════════
      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: AppColors.deepViolet,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Animated Header ──────────────────────────────────────────────
                SlideTransition(
                  position: _headerSlide,
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: _buildHeader())),

                // ── Map + Overlays ───────────────────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      _buildMap(),
                      if (_selectedKey != null && _cardScreenOffset != null)
                        _buildFloatingCard(),
                      _buildLegend(),
                      _buildStatsBar(),
                    ])),
              ])));
      }

      // ── Header — Deep purple glass bar ─────────────────────────────────────────
      Widget _buildHeader() {
        final int totalItems = _grouped.values
            .expand((m) => m.values)
            .expand((l) => l)
            .length;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0033), Color(0xFF3D0066), Color(0xFF6200B3), Color(0xFF8B2FC9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.purple,
            border: Border.all(
              color: AppColors.neonAccent.withOpacity(0.3),
              width: 1)),
          child: Row(
            children: [
              // Back button
              _HeaderIconButton(
                icon: CupertinoIcons.arrow_left,
                onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              // Redraw route button
              _HeaderIconButton(
                icon: Icons.route_rounded,
                onTap: () => _forceRedrawRoute()),
              const SizedBox(width: 10),

              // Title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'خريطة مسار التوصيل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Amiri',
                        letterSpacing: 0.2)),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _HeaderChip(
                          icon: CupertinoIcons.cart_fill,
                          label: '$totalItems منتج',
                          color: AppColors.neonAccent),
                        const SizedBox(width: 5),
                        _HeaderChip(
                          icon: CupertinoIcons.bag_fill,
                          label: '${_grouped.length} محل',
                          color: AppColors.blush),
                        const SizedBox(width: 5),
                        _HeaderChip(
                          icon: CupertinoIcons.person_2_fill,
                          label: '${widget.activeOrders.length} طلبية',
                          color: AppColors.soft),
                      ]),
                  ])),
            ]));
      }

      // ── Map ─────────────────────────────────────────────────────────────────────
      Widget _buildMap() {
        final LatLng initialTarget = _storeNames.isNotEmpty
            ? LatLng(_storeNames.keys.first.lat, _storeNames.keys.first.lng)
            : _defaultCenter;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
              tilt: 45),
            style: _mapStyle,
            onMapCreated: (ctrl) {
              _mapController.complete(ctrl);
            },
            markers:   _markers,
            polylines: _polylines,
            onTap:     (_) => _deselectStore(),
            onCameraMove: (pos) => _currentZoom = pos.zoom,
            onCameraIdle: () async {
              if (_selectedKey != null && _selectedLatLng != null) {
                _recalcCardOffset(_selectedLatLng!);
              }
              try {
                final ctrl = await _mapController.future;
                final bounds = await ctrl.getVisibleRegion();
                if (mounted) setState(() => _visibleBounds = bounds);
              } catch (_) {}
            },
            myLocationEnabled:       true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled:     false,
            mapToolbarEnabled:       false,
            compassEnabled:          true,
            mapType:                 MapType.normal,
            buildingsEnabled:        true,
            padding: const EdgeInsets.only(bottom: 150, top: 50)));
      }

      // ── Floating Store Card ─────────────────────────────────────────────────────
      Widget _buildFloatingCard() {
        final key        = _selectedKey!;
        final customers = _fullGrouped[key] ?? {}; 
        final storeName  = _storeNames[key] ?? 'محل';
        final totalItems = customers.values.fold<int>(0, (s, l) => s + l.length);
        final offset     = _cardScreenOffset!;

        final double zoom   = (_currentZoom / 17.0).clamp(0.7, 1.4);
        final double cw     = 290.0 * zoom;
        final double ch     = 370.0 * zoom;
        final Size   screen = MediaQuery.of(context).size;

        double left = (offset.dx - cw / 2).clamp(8.0, screen.width  - cw - 8);
        double top  = (offset.dy - ch - 12).clamp(8.0, screen.height - ch - 8);

        return Positioned(
          left: left, top: top,
          child: ScaleTransition(
            scale: _cardScale,
            child: FadeTransition(
              opacity: _cardFade,
              child: SizedBox(
                width: cw, height: ch,
                child: _StoreCard(
                  storeName:  storeName,
                  customers:  customers,
                  totalItems: totalItems,
                  lat:        key.lat,
                  lng:        key.lng,
                  onClose:    _deselectStore)))));
      }

      // ── Legend — Compact glass pill ─────────────────────────────────────────────
    Widget _buildLegend() {
      List<_LegendItem> items = [];
      for (int i = 1; i < _fullSequence.length; i++) {
        final pos = _fullSequence[i];

        if (_visibleBounds != null && !_visibleBounds!.contains(pos)) continue;

        String? storeName;
        _StoreKey? matchedKey;
        for (final key in _storeNames.keys) {
          if (_samePoint(pos, LatLng(key.lat, key.lng))) {
            storeName = _storeNames[key];
            matchedKey = key;
            break;
          }
        }
        if (storeName != null) {
          final active = _grouped[matchedKey]?.values.fold<int>(0, (s, l) => s + l.length) ?? 0;
          if (active == 0) continue;
          items.add(_LegendItem(name: storeName, isStore: true));
          continue;
        }
        for (final cust in _customerData) {
          final custPos = cust['latlng'] as LatLng;
          if (_samePoint(pos, custPos)) {
            final custName = cust['name'] as String;
            if (_isCustomerComplete(custName)) continue;
            items.add(_LegendItem(name: custName, isStore: false));
            break;
          }
        }
      }

      return Positioned(
        bottom: 80,
        left: 12, 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 160, // العرض
              // 👈 وضع حد أقصى للارتفاع (مثلاً 250) لكي لا يغطي الشاشة
              constraints: const BoxConstraints(maxHeight: 250), 
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.deepViolet.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neonAccent.withOpacity(0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, 
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. العنوان
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "دليل المسار",
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Amiri')),
                      if (_visibleBounds != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          "(${items.length})",
                          style: TextStyle(color: AppColors.neonAccent, fontSize: 10, fontFamily: 'Amiri')),
                      ],
                    ]),
                  const SizedBox(height: 8),
                  
                  // 2. الجزء القابل للتمرير (أسماء المحطات)
                  Flexible( // 👈 استعملنا Flexible ليسمح بالتقلص والتمدد
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(), // سكرول مرن
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < items.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      items[i].name,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: items[i].isStore ? Colors.white : Colors.white70,
                                        fontSize: 10,
                                        fontFamily: 'Amiri',
                                        fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 4),
                                  Text(
                                    items[i].isStore ? "محل" : "زبون",
                                    style: TextStyle(
                                      color: items[i].isStore ? AppColors.primary : AppColors.neonAccent,
                                      fontSize: 9,
                                      fontFamily: 'Amiri')),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 12, height: 4,
                                    decoration: BoxDecoration(
                                      color: legColors[(i + 1) % legColors.length],
                                      borderRadius: BorderRadius.circular(2))),
                                ])),
                        ]))),
                  
                  // 3. الجزء الثابت السفلي (المفتاح العام)
                  const Divider(color: Colors.white10, height: 12),
                  _buildStaticLegendRow(color: Colors.red, label: 'موقع زبون', isDot: true),
                  const SizedBox(height: 4),
                  _buildStaticLegendRow(color: AppColors.primary, label: 'محل تسوق', isDot: true),
                  const SizedBox(height: 4),
                  _buildStaticLegendRow(color: AppColors.neonAccent, label: 'موقع استلام', isDot: true),
                  const SizedBox(height: 4),
                  _buildStaticLegendRow(color: AppColors.success, label: 'موقع توصيل', isDot: true),
                  const SizedBox(height: 4),
                  _buildStaticLegendRow(color: Colors.orangeAccent, label: 'قطاع المسار', isDot: false),
                ])))));
    }

    // Widget مساعد للأيقونات الثابتة بجهة اليمين
    Widget _buildStaticLegendRow({required Color color, required String label, bool isDot = false}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Amiri')),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: isDot ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isDot ? null : BorderRadius.circular(3))),
        ]);
    }
      // ── Stats bar — bottom overlay ──────────────────────────────────────────────
      Widget _buildStatsBar() {
        final int totalItems = _grouped.values
            .expand((m) => m.values)
            .expand((l) => l)
            .length;

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0033), Color(0xFF3D0066)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: AppShadows.purple,
              border: Border.all(
                color: AppColors.neonAccent.withOpacity(0.2),
                width: 1)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: CupertinoIcons.bag_fill,
                  value: '${_grouped.length}',
                  label: 'محل',
                  color: AppColors.soft),
                _StatDivider(),
                _StatItem(
                  icon: CupertinoIcons.cart_fill,
                  value: '$totalItems',
                  label: 'منتج',
                  color: AppColors.neonAccent),
                _StatDivider(),
                _StatItem(
                  icon: CupertinoIcons.person_2_fill,
                  value: '${widget.activeOrders.length}',
                  label: 'طلبية',
                  color: AppColors.blush),
                _StatDivider(),
                _StatItem(
                  icon: CupertinoIcons.location_fill,
                  value: _currentLatLng != null ? 'نشط' : 'انتظار',
                  label: 'الموقع',
                  color: _currentLatLng != null ? AppColors.success : AppColors.warning),
              ])));
      }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  Small Reusable Widgets
    // ══════════════════════════════════════════════════════════════════════════════

    class _HeaderIconButton extends StatelessWidget {
      final IconData icon;
      final VoidCallback onTap;
      const _HeaderIconButton({required this.icon, required this.onTap});

      @override
      Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
          child: Icon(icon, color: Colors.white, size: 15)));
    }

    class _HeaderChip extends StatelessWidget {
      final IconData icon;
      final String label;
      final Color color;
      const _HeaderChip({required this.icon, required this.label, required this.color});

      @override
      Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35), width: 0.8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 9),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w700)),
          ]));
    }

    class _LegendRow extends StatelessWidget {
      final Color  color;
      final String label;
      final bool   isLine;
      final bool   isDot;
      const _LegendRow({
        required this.color,
        required this.label,
        this.isLine = false,
        this.isDot  = false,
      });

      @override
      Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: isLine
                ? Container(height: 3, decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)))
                : isDot
                    ? Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                    : const SizedBox.shrink()),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'Amiri',
              color: Colors.white,
              fontWeight: FontWeight.w600)),
        ]);
    }

    class _StatItem extends StatelessWidget {
      final IconData icon;
      final String   value;
      final String   label;
      final Color    color;
      const _StatItem({required this.icon, required this.value, required this.label, required this.color});

      @override
      Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 11),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.w800)),
            ]),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontFamily: 'Amiri')),
        ]);
    }

    class _StatDivider extends StatelessWidget {
      @override
      Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: Colors.white.withOpacity(0.1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  _StoreCard — Premium purple glass card
    // ══════════════════════════════════════════════════════════════════════════════
    class _StoreCard extends StatelessWidget {
      final String storeName;
      final Map<String, List<Map<String, dynamic>>> customers;
      final int totalItems;
      final double lat;
      final double lng;
      final VoidCallback onClose;

      const _StoreCard({
        required this.storeName,
        required this.customers,
        required this.totalItems,
        required this.lat,
        required this.lng,
        required this.onClose,
      });

      @override
      Widget build(BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)]),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFB8B1C8).withOpacity(0.6),
                blurRadius: 10,
                offset: Offset(4, 4)),
              BoxShadow(
                color: Colors.white,
                blurRadius: 10,
                offset: Offset(-4, -4)),
            ],
            border: Border.all(color: Color(0xFF5B0094).withOpacity(0.1))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Card Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0033), Color(0xFF3D0066), Color(0xFF6200B3), Color(0xFF8B2FC9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(21))),
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 10))),
                    const SizedBox(width: 6),

                    // Item count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.neonAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonAccent.withOpacity(0.4), width: 1)),
                      child: Text(
                        '$totalItems منتج',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w700))),

                    const Spacer(),

                    // Navigate button
                    GestureDetector(
                      onTap: () => _openNav(lat, lng),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.success.withOpacity(0.5), width: 1)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ملاحة',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontFamily: 'Amiri',
                                fontWeight: FontWeight.w700)),
                            SizedBox(width: 3),
                            Icon(Icons.navigation_rounded, color: AppColors.success, size: 12),
                          ]))),
                    const SizedBox(width: 8),

                    // Store name
                    Text(
                      storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Amiri')),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.bag_fill, color: Colors.white, size: 11)),
                  ])),

              // ── Customer List ────────────────────────────────────────────────
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: customers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _CustomerSection(
                    customerName: customers.keys.elementAt(i),
                    items:        customers.values.elementAt(i),
                    colorIndex:   i))),
              const SizedBox(height: 6),
            ]));
      }

      Future<void> _openNav(double lat, double lng) async {
        final String intent  = 'google.navigation:q=$lat,$lng&mode=l';
        final String webUrl  = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two_wheeler';
        try {
          if (await canLaunchUrl(Uri.parse(intent))) {
            await launchUrl(Uri.parse(intent));
          } else {
            await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          debugPrint('Nav error: $e');
        }
      }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  _CustomerSection — Purple-tinted with accent stripe
    // ══════════════════════════════════════════════════════════════════════════════
    class _CustomerSection extends StatelessWidget {
      final String customerName;
      final List<Map<String, dynamic>> items;
      final int colorIndex;

      // Purple accent spectrum — monochromatic but distinguishable
      static const List<Color> _accents = [
        AppColors.primary,
        AppColors.vibrant,
        AppColors.soft,
        AppColors.glowAccent,
        AppColors.neonAccent,
        AppColors.richPurple,
      ];

      const _CustomerSection({
        required this.customerName,
        required this.items,
        required this.colorIndex,
      });

      Color get _color => _accents[colorIndex % _accents.length];

      @override
      Widget build(BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: _color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _color.withOpacity(0.15), width: 1.2)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent stripe
                Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_color, _color.withOpacity(0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14)))),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Customer header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Item count badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _color.withOpacity(0.25), width: 1)),
                              child: Text(
                                '${items.length} منتج',
                                style: TextStyle(
                                  color: _color,
                                  fontSize: 8,
                                  fontFamily: 'Amiri',
                                  fontWeight: FontWeight.w700))),

                            // Customer name
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  customerName,
                                  style: TextStyle(
                                    color: _color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Amiri')),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _color.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                  child: Icon(
                                    CupertinoIcons.person_fill,
                                    color: _color,
                                    size: 9)),
                              ]),
                          ]),
                        const SizedBox(height: 7),

                        // Items list
                        ...items.map((item) => _ItemRow(item: item)),
                      ]))),
              ])));
      }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  _ItemRow — Clean status-aware row
    // ══════════════════════════════════════════════════════════════════════════════
    class _ItemRow extends StatelessWidget {
    final Map<String, dynamic> item;
    const _ItemRow({required this.item});

    @override
    Widget build(BuildContext context) {
      final name        = item['name']            as String? ?? 'منتج';
      final qty         = item['quantity']         as int?    ?? 1;
      final pStatus     = item['purchaseStatus']   as String? ?? '';
      final price       = (item['finalPrice'] ?? item['price'] ?? item['prix'] ?? 0) as num;
      
      // استخراج الحجم (Size) - يدعم مفتاح 'size' أو 'itemSize'
      final size        = item['capacite'] as String? ?? item['itemSize'] as String? ?? '';

      final bool purchased   = pStatus == 'purchased';
      final bool unavailable = pStatus == 'unavailable';

      return Padding(
        padding: const EdgeInsets.only(bottom: 8), // زيادة المسافة قليلاً
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. الجهة اليسرى: السعر والحالة
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (purchased)
                  _StatusBadge(
                    label: '${price.toInt()} DA',
                    color: AppColors.success,
                    bg: AppColors.successLight)
                else if (unavailable)
                  _StatusBadge(
                    label: 'غير متوفر',
                    color: AppColors.danger,
                    bg: AppColors.dangerLight)
                else
                  _StatusBadge(
                    label: 'انتظار',
                    color: AppColors.warning,
                    bg: AppColors.warning.withOpacity(0.1)),
                const SizedBox(width: 5),
                Icon(
                  purchased
                      ? CupertinoIcons.checkmark_circle_fill
                      : unavailable
                          ? CupertinoIcons.xmark_circle_fill
                          : CupertinoIcons.clock_fill,
                  color: purchased
                      ? AppColors.success
                      : unavailable
                          ? AppColors.danger
                          : AppColors.warning,
                  size: 11),
              ]),

            // 2. الجهة اليمنى: اسم المنتج + الحجم + الكمية
            Expanded( // استخدام Expanded لمنع تجاوز النص للعرض
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // الحجم (Size) يظهر فقط إذا كان موجوداً
                  if (size.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.soft.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.soft.withOpacity(0.3), width: 0.5)),
                      child: Text(
                        size,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: AppColors.soft,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri'))),
                    const SizedBox(width: 4),
                  ],

                  // الكمية (Quantity)
                  if (qty > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 0.5)),
                      child: Text(
                        '×$qty',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w800))),
                    const SizedBox(width: 6),
                  ],

                  // اسم المنتج
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Amiri',
                        color: unavailable ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: unavailable ? TextDecoration.lineThrough : TextDecoration.none))),
                ])),
          ]));
    }
  }

    class _StatusBadge extends StatelessWidget {
      final String label;
      final Color  color;
      final Color  bg;
      const _StatusBadge({required this.label, required this.color, required this.bg});

      @override
      Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontFamily: 'Amiri',
            fontWeight: FontWeight.w700)));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  _StoreKey
    // ══════════════════════════════════════════════════════════════════════════════
    class _StoreKey {
      final double lat;
      final double lng;
      const _StoreKey(this.lat, this.lng);

      @override
      bool operator ==(Object o) =>
          o is _StoreKey &&
          _r(o.lat) == _r(lat) &&
          _r(o.lng) == _r(lng);

      @override
      int get hashCode => Object.hash(_r(lat), _r(lng));

      double _r(double v) => (v * 100000).round() / 100000;
    }

    class _LegendItem {
      final String name;
      final bool isStore;
      const _LegendItem({required this.name, required this.isStore});
    }

    // ══════════════════════════════════════════════════════════════════════════════
    //  buildMapRouteButton — Entry point button
    // ══════════════════════════════════════════════════════════════════════════════
    Widget buildMapRouteButton({
      required BuildContext context,
      required List<Map<String, dynamic>> activeOrders,
    }) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) =>
                  DriverRouteMapScreen(activeOrders: activeOrders),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child)),
              transitionDuration: const Duration(milliseconds: 380)));
        },
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepViolet, AppColors.primary, AppColors.vibrant],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
                spreadRadius: -2),
              BoxShadow(
                color: AppColors.neonAccent.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4),
            ],
            border: Border.all(
              color: AppColors.neonAccent.withOpacity(0.3),
              width: 1)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text(
                'خريطة المسار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Amiri',
                  letterSpacing: 0.3)),
            ])));
    }