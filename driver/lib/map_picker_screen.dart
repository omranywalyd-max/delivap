import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'driver_app.dart';
import 'theme.dart' hide kPrimary, kPrimaryDark, kAccent, kTextDark, kTextGrey, kDanger, kSuccess, kWarning, kInfo, kNeumShadow;

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapCtrl;
  final _searchCtrl = TextEditingController();

  LatLng _selectedLatLng = const LatLng(36.7372, 3.0863);
  String _selectedAddress = '';
  bool _loadingLocation = true;
  bool _loadingAddress = false;
  
  // المتغيرات التي سيتم تخزينها
  String _cityAr = '';
  String _cityFr = '';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();

      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _loadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء السماح بتحديد الموقع من الإعدادات'), backgroundColor: kDanger),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final ll = LatLng(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _selectedLatLng = ll;
          _loadingLocation = false;
        });
        _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: ll, zoom: 16)),
        );
        await _reverseGeocode(ll);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تأكد من تشغيل الـ GPS والإنترنت'), backgroundColor: kWarning),
        );
      }
    }
  }

  // ─── الدالة المسؤولة عن جلب الأسماء (تماما مثل ملف التسليم) ───
  Future<void> _reverseGeocode(LatLng ll) async {
    if (!mounted) return;
    setState(() => _loadingAddress = true);
    try {
      // 1. طلب الاسم بالعربية من Nominatim
      final urlAr = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=ar';
      final respAr = await http.get(Uri.parse(urlAr), headers: {'User-Agent': 'walyyid-app'});

      // 2. طلب الاسم بالفرنسية
      final urlFr = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=fr';
      final respFr = await http.get(Uri.parse(urlFr), headers: {'User-Agent': 'walyyid-app'});

      if (respAr.statusCode == 200 && respFr.statusCode == 200) {
        final jsonAr = jsonDecode(respAr.body);
        final jsonFr = jsonDecode(respFr.body);
        
        final addrAr = jsonAr['address'];
        final addrFr = jsonFr['address'];

        // محاولة جلب اسم البلدية أو المدينة من عدة مفاتيح محتملة
        String cityAr = addrAr['city'] ?? addrAr['town'] ?? addrAr['village'] ?? addrAr['municipality'] ?? addrAr['county'] ?? '';
        String cityFr = addrFr['city'] ?? addrFr['town'] ?? addrFr['village'] ?? addrFr['municipality'] ?? addrFr['county'] ?? '';

        setState(() {
          // تنظيف الأسماء واختيار الجزء الأول فقط
          _cityAr = cityAr.split(RegExp(r'[،,]')).first.trim();
          _cityFr = cityFr.split(RegExp(r'[،,]')).first.trim();
          
          // العرض في الواجهة: نفضل العربية، إذا لم توجد نأخذ الفرنسية، إذا لم توجد نأخذ العنوان الكامل
          if (_cityAr.isNotEmpty) {
            _selectedAddress = _cityAr;
          } else if (_cityFr.isNotEmpty) {
            _selectedAddress = _cityFr;
          } else {
            _selectedAddress = 'موقع محدد';
          }
        });
      }
    } catch (e) {
      if (mounted) _selectedAddress = 'خطأ في تحديد العنوان';
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _searchPlace(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      List<Location> locations = await locationFromAddress(q);
      if (mounted && locations.isNotEmpty) {
        final ll = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() => _selectedLatLng = ll);
        _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: ll, zoom: 15)),
        );
        await _reverseGeocode(ll);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المكان غير موجود")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 15),
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
            onTap: (ll) {
              setState(() => _selectedLatLng = ll);
              _reverseGeocode(ll);
            },
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // شريط البحث
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 45, height: 45,
                      decoration: neuBox(radius: 12),
                      child: const Icon(CupertinoIcons.chevron_right, color: kPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: neuBox(radius: 15),
                      child: TextField(
                        controller: _searchCtrl,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        onSubmitted: _searchPlace,
                        style: const TextStyle(fontSize: 14, fontFamily: 'Amiri'),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مكان...',
                          hintStyle: const TextStyle(color: kTextGrey, fontSize: 12),
                          prefixIcon: IconButton(
                            icon: const Icon(CupertinoIcons.search, color: kPrimary),
                            onPressed: () => _searchPlace(_searchCtrl.text),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // زر موقعي (GPS)
          Positioned(
            bottom: 240,
            left: 20,
            child: GestureDetector(
              onTap: _getUserLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(CupertinoIcons.location_fill, color: kPrimary, size: 22),
              ),
            ),
          ),

          // اللوحة السفلية
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Color(0xFFB8B1C8).withOpacity(0.6), blurRadius: 10, offset: Offset(0, -5)),
                  BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(0, 5)),
                ],
                border: Border.all(color: kPrimary.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('الموقع المختار', style: TextStyle(fontSize: 12, color: kTextGrey, fontFamily: 'Amiri')),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF1F0F5), Color(0xFFE6E4F0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFB8B1C8).withOpacity(0.6),
                          blurRadius: 10,
                          offset: Offset(4, 4),
                        ),
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 10,
                          offset: Offset(-4, -4),
                        ),
                      ],
                      border: Border.all(color: kPrimary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        if (_loadingAddress) const CupertinoActivityIndicator(radius: 8)
                        else const Icon(CupertinoIcons.map_pin_ellipse, color: kPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedAddress.isEmpty ? 'اختر موقعاً من الخريطة' : _selectedAddress,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Amiri'),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: "تأكيد الموقع",
                    onTap: _selectedAddress.isEmpty || _loadingAddress
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'address': _selectedAddress,
                              'cityNameAr': _cityAr.isNotEmpty ? _cityAr : _selectedAddress,
                              'cityNameFr': _cityFr.isNotEmpty ? _cityFr : _cityAr,
                              'lat': _selectedLatLng.latitude,
                              'lng': _selectedLatLng.longitude,
                            });
                          },
                  ),
                ],
              ),
            ),
          ),

          if (_loadingLocation)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: kPrimary),
                    SizedBox(height: 15),
                    Text('جاري تحديد الموقع...', style: TextStyle(color: Colors.white, fontFamily: 'Amiri')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}