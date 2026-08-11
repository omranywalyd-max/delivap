import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  TwoPointRouteCard — يعرض:
//   1) المسافة بين موقع السائق الحالي وموقع الانطلاق
//   2) المسافة بين موقعي الانطلاق والوصول
//   + زر يفتح المسار في خرائط Google — سيارة (driving) للسيارة/هاربين/فورغو،
//     دراجة (two_wheeler) لسائق الدراجة النارية
// ══════════════════════════════════════════════════════════════════════════════
class TwoPointRouteCard extends StatefulWidget {
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final String vehicleType;

  const TwoPointRouteCard({
    super.key,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.vehicleType = '',
  });

  @override
  State<TwoPointRouteCard> createState() => _TwoPointRouteCardState();
}

class _TwoPointRouteCardState extends State<TwoPointRouteCard> {
  double? _driverLat;
  double? _driverLng;
  bool _loadingLocation = true;
  bool _locationUnavailable = false;

  bool get _hasFrom =>
      widget.fromLat != null &&
      widget.fromLng != null &&
      widget.fromLat != 0 &&
      widget.fromLng != 0;
  bool get _hasTo =>
      widget.toLat != null &&
      widget.toLng != null &&
      widget.toLat != 0 &&
      widget.toLng != 0;

  bool get _useDriving {
    final v = widget.vehicleType.toLowerCase();
    if (v.isEmpty || v == 'motorcycle') return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentPosition();
  }

  Future<void> _fetchCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _loadingLocation = false;
            _locationUnavailable = true;
          });
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loadingLocation = false;
            _locationUnavailable = true;
          });
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _driverLat = position.latitude;
        _driverLng = position.longitude;
        _loadingLocation = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationUnavailable = true;
        });
      }
    }
  }

  String _fmt(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  Future<void> _openRoute() async {
    final fromLat = widget.fromLat;
    final fromLng = widget.fromLng;
    final toLat = widget.toLat;
    final toLng = widget.toLng;
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      return;
    }
    final uri =
        'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLng'
        '&destination=$toLat,$toLng&travelmode=${_useDriving ? 'driving' : 'two_wheeler'}';
    await launchUrlString(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFrom || !_hasTo) return const SizedBox.shrink();

    final double fromToMeters = Geolocator.distanceBetween(
      widget.fromLat!,
      widget.fromLng!,
      widget.toLat!,
      widget.toLng!,
    );
    final double? driverFromMeters = (_driverLat != null && _driverLng != null)
        ? Geolocator.distanceBetween(
            _driverLat!,
            _driverLng!,
            widget.fromLat!,
            widget.fromLng!,
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryPale.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'المسافات',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Amiri',
                  color: kPrimaryDark,
                ),
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.location_circle_fill,
                  color: kPrimary, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          _distanceRow(
            icon: CupertinoIcons.person_fill,
            label: 'بعدك عن موقع الانطلاق',
            value: driverFromMeters != null
                ? _fmt(driverFromMeters)
                : (_loadingLocation
                    ? 'جاري تحديد موقعك…'
                    : (_locationUnavailable ? 'فعّل الموقع' : 'غير متاح')),
            color: driverFromMeters != null ? kSuccess : kTextGrey,
          ),
          Divider(height: 18, color: kPrimary.withOpacity(0.12)),
          _distanceRow(
            icon: Icons.alt_route_rounded,
            label: 'المسافة بين الانطلاق والوصول',
            value: _fmt(fromToMeters),
            color: kSuccess,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openRoute,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: Icon(
                _useDriving ? Icons.directions_car : Icons.motorcycle,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _useDriving ? 'فتح المسار بالسيارة' : 'فتح المسار بالدراجة',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _distanceRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 13,
              color: kTextDark,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: kPrimary, size: 15),
      ],
    );
  }
}
