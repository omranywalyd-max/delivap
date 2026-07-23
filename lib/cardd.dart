// ══════════════════════════════════════════════════════════════════════════════
//  cardd.dart  — السلة + تأكيد الطلبية
// ══════════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/saved_orders_screen.dart';
import 'user_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'products_list_screen.dart';
import 'Order/order_models.dart';
import 'Services/delivery_screen.dart';
import 'driver_selection_screen.dart';
import 'dashboard_screen.dart';
import 'Sign in/sign_in.dart';
import 'main_page.dart';

import 'stores_widget.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ألوان التطبيق
// ══════════════════════════════════════════════════════════════════════════════
const Color kPrimary = Color(0xFF7D29C6);
const Color kPrimaryDark = Color(0xFF6D22AC);
const Color kAccent = Color(0xFF9232E8);
const Color kBg = Color(0xFFF1F0F5);
const Color kCardColor = Color(0xFFDCDAE6);
const Color kSuccess = Color(0xFF27AE60);
final Color kNeumShadow = const Color(0xFFB8B1C8).withOpacity(0.6);

// ══════════════════════════════════════════════════════════════════════════════
//  FCMSender — إرسال الإشعارات من الزبون إلى السائق عبر السيرفر
// ══════════════════════════════════════════════════════════════════════════════

class FCMSender {
  // ── 1. إشعار طلبية جديدة ───────────────────────────────────────────────────
  static Future<bool> sendToDriver({
    required String driverId,
    required String orderId,
    required String customerName,
    required String address,
    required double total,
    required double deliveryFee,
    required int itemsCount,
  }) async {
    try {
      await ApiClient.post('/api/notify-driver', {
        'driverId': driverId,
        'title': '🔔 طلبية جديدة وصلت!',
        'body':
            '$customerName — $address\n$itemsCount منتج · ${total.toInt()} DA',
        'data': {'type': 'new_order', 'orderId': orderId},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── 2. إشعار قبول السعر المضاد ─────────────────────────────────────
  static Future<bool> sendCounterAccepted({
    required String driverId,
    required String orderId,
    required double price,
    String serviceType = '',
    String customerName = 'الزبون',
  }) async {
    try {
      final priceStr = price == price.roundToDouble()
          ? price.toInt().toString()
          : price.toStringAsFixed(2);
      final title = _serviceTitle(serviceType);
      await ApiClient.post('/api/notify-driver', {
        'driverId': driverId,
        'title': '💰 $title',
        'body': '$customerName قبل السعر الجديد: $priceStr DZD',
        'data': {'type': 'counter_accepted', 'orderId': orderId},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── 3. إشعار رفض السعر المضاد ─────────────────────────────────────
  static Future<bool> sendCounterRejected({
    required String driverId,
    required String orderId,
    String serviceType = '',
    String customerName = 'الزبون',
  }) async {
    try {
      final title = _serviceTitle(serviceType);
      await ApiClient.post('/api/notify-driver', {
        'driverId': driverId,
        'title': '❌ $title',
        'body': '$customerName رفض عرض السعر المقترح.',
        'data': {'type': 'counter_rejected', 'orderId': orderId},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static String _serviceTitle(String serviceType) {
    switch (serviceType) {
      case 'delivery':
        return 'توصيل الطلبيات';
      case 'pickup':
        return 'إحضار طلبية';
      default:
        return serviceType.isNotEmpty ? serviceType : 'عرض السعر';
    }
  }

  // ── 4. إشعار إلغاء الطلب ─────────────────────────────────────────────
  static Future<bool> sendCancellation({
    required String driverId,
    required String orderId,
    required String reason,
  }) async {
    try {
      await ApiClient.post('/api/notify-driver', {
        'driverId': driverId,
        'title': '❌ تم إلغاء الطلبية',
        'body': reason.isNotEmpty
            ? 'سبب الإلغاء: $reason'
            : 'قام الزبون بإلغاء الطلبية.',
        'data': {'type': 'order_cancelled', 'orderId': orderId},
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DeliveryPricingService
// ══════════════════════════════════════════════════════════════════════════════
class DeliveryPricingService {
  static Future<Map<String, dynamic>?> fetchForCity({
    required String cityNameAr,
    required String cityNameFr,
    required double distanceKm,
    int categoriesCount = 1,
    int totalQty = 1,
  }) async {
    try {
      var cfgData = await ApiClient.get('/api/wilaya-configs/$cityNameAr');
      if (cfgData == null || cfgData.isEmpty) {
        cfgData = await ApiClient.get('/api/wilaya-configs/$cityNameFr');
      }
      if (cfgData != null && cfgData.isNotEmpty) {
        return _calcFromConfig(
          cfgData,
          distanceKm,
          cityNameAr,
          categoriesCount,
          totalQty,
        );
      }
      final driversList = await ApiClient.getList('/api/drivers?isOnline=true');
      for (final d in driversList) {
        if (d['cityNameAr'] == cityNameAr ||
            d['cityNameFr'] == cityNameFr ||
            d['cityName'] == cityNameAr) {
          if (d['deliveryConfig'] != null) {
            return _calcFromConfig(
              d['deliveryConfig'],
              distanceKm,
              cityNameAr,
              categoriesCount,
              totalQty,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getCitiesWithDrivers() async {
    try {
      final drivers = await ApiClient.getList('/api/drivers?isOnline=true');
      final seen = <String>{};
      final cities = <Map<String, dynamic>>[];
      for (final d in drivers) {
        final ar = (d['cityNameAr'] ?? d['cityName'] ?? '').toString();
        final fr = (d['cityNameFr'] ?? '').toString();
        if (ar.isNotEmpty && seen.add(ar)) {
          final lat = (d['lat'] as num?)?.toDouble();
          final lng = (d['lng'] as num?)?.toDouble();
          cities.add({'ar': ar, 'fr': fr, 'lat': lat, 'lng': lng});
        }
      }
      return cities;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableCities() async {
    try {
      final configs = await ApiClient.getList('/api/wilaya-configs');
      if (configs == null || configs.isEmpty) return [];
      final cities = <Map<String, dynamic>>[];
      for (final cfg in configs) {
        if (cfg is Map) {
          final nameAr = (cfg['cityNameAr'] ?? cfg['cityName'] ?? '').toString();
          final nameFr = (cfg['cityNameFr'] ?? '').toString();
          final lat = (cfg['cityLat'] as num?)?.toDouble();
          final lng = (cfg['cityLng'] as num?)?.toDouble();
          if (nameAr.isNotEmpty) {
            cities.add({'ar': nameAr, 'fr': nameFr, 'lat': lat, 'lng': lng});
          }
        }
      }
      return cities;
    } catch (_) {
      return [];
    }
  }

  /// ترجع أقرب 5 مدن عندها تسعيرة إلى موقع المستخدم
  static List<Map<String, dynamic>> findNearestCities(
    List<Map<String, dynamic>> cities,
    double userLat,
    double userLng,
  ) {
    final withDist = <Map<String, dynamic>>[];
    for (final city in cities) {
      final lat = city['lat'] as double?;
      final lng = city['lng'] as double?;
      if (lat == null || lng == null) continue;
      final dist = calcDistance(userLat, userLng, lat, lng);
      withDist.add({...city, 'distance': dist});
    }
    withDist.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return withDist.take(5).toList();
  }

  /// تظهر ديالوغ بأقرب 5 مدن عندها تسعيرة للمستخدم ليست اندار مدينتو
  static Future<Map<String, dynamic>?> pickNearbyCity(
    BuildContext context, {
    required double userLat,
    required double userLng,
    required String currentCityAr,
  }) async {
    final allCities = await getAvailableCities();
    if (allCities.isEmpty) return null;
    if (allCities.any((c) => c['ar'] == currentCityAr)) return null;
    if (!context.mounted) return null;

    final nearest = findNearestCities(allCities, userLat, userLng);
    if (nearest.isEmpty) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'لا يوجد سائق في مدينتك',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF2D2A3A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اختر أقرب مدينة متوفرة من القائمة',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: nearest.length,
            itemBuilder: (_, i) {
              final city = nearest[i];
              final dist = (city['distance'] as double);
              final distStr = dist < 1
                  ? '${(dist * 1000).toInt()} م'
                  : '${dist.toStringAsFixed(1)} كم';
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, city),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF5F0FA), Color(0xFFEDE4F5)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6D22AC).withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.location_city,
                          color: Color(0xFF6D22AC),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            city['ar'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2A3A),
                            ),
                          ),
                          Text(
                            'يبعد $distStr',
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D22AC).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'اختيار',
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 12,
                            color: Color(0xFF6D22AC),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Amiri', color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _calcFromConfig(
    Map<String, dynamic> cfg,
    double distanceKm,
    String cityName,
    int categoriesCount,
    int totalQty,
  ) {
    final basePrice = (cfg['basePrice'] as num? ?? 150).toDouble();
    final baseDist = (cfg['baseDist'] as num? ?? 5).toDouble();
    final extraDistPrice = (cfg['extraDistPrice'] as num? ?? 15).toDouble();
    final baseCats = (cfg['baseCats'] as num? ?? 1).toInt();
    final extraCatPrice = (cfg['extraCatPrice'] as num? ?? 0).toDouble();
    final baseQty = (cfg['baseQty'] as num? ?? 5).toInt();
    final extraQtyPrice = (cfg['extraQtyPrice'] as num? ?? 0).toDouble();

    final extraKm = max(0.0, distanceKm - baseDist).ceilToDouble();
    final extraCharge = extraKm * extraDistPrice;
    final extraCats = max(0, categoriesCount - baseCats);
    final extraCatsCharge = extraCats * extraCatPrice;
    final extraQty = max(0, totalQty - baseQty);
    final extraQtyCharge = extraQty * extraQtyPrice;
    final total = basePrice + extraCharge + extraCatsCharge + extraQtyCharge;

    return {
      'cityName': cityName,
      'deliveryFee': total,
      'basePrice': basePrice,
      'baseDist': baseDist,
      'extraDistPrice': extraDistPrice,
      'extraKm': extraKm,
      'extraCharge': extraCharge,
      'distanceKm': distanceKm,
      'baseCats': baseCats,
      'extraCatPrice': extraCatPrice,
      'categoriesCount': categoriesCount,
      'extraCatsCount': extraCats,
      'extraCatsCharge': extraCatsCharge,
      'baseQty': baseQty,
      'extraQtyPrice': extraQtyPrice,
      'totalQty': totalQty,
      'extraQtyCount': extraQty,
      'extraQtyCharge': extraQtyCharge,
      'isDefault': false,
    };
  }

  static double calcDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static Future<bool> hasDriversInCity(String cityAr, String cityFr) async {
    try {
      final drivers = await ApiClient.getList('/api/drivers?isOnline=true');
      for (final d in drivers) {
        if (d['cityNameAr'] == cityAr ||
            d['cityNameFr'] == cityFr ||
            d['cityName'] == cityAr)
          return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, String>> getCityNamesFromCoords(
    double lat,
    double lng,
  ) async {
    Map<String, String> results = {'ar': '', 'fr': ''};
    try {
      final urlAr =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar';
      final respAr = await http.get(
        Uri.parse(urlAr),
        headers: {'User-Agent': 'walyyid-user-app/1.0'},
      );
      final urlFr =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=fr';
      final respFr = await http.get(
        Uri.parse(urlFr),
        headers: {'User-Agent': 'walyyid-user-app/1.0'},
      );

      if (respAr.statusCode == 200 && respFr.statusCode == 200) {
        final jsonAr =
            jsonDecode(respAr.body)['address'] as Map<String, dynamic>;
        final jsonFr =
            jsonDecode(respFr.body)['address'] as Map<String, dynamic>;
        String cityAr =
            jsonAr['city'] ??
            jsonAr['town'] ??
            jsonAr['village'] ??
            jsonAr['locality'] ??
            '';
        String cityFr =
            jsonFr['city'] ??
            jsonFr['town'] ??
            jsonFr['village'] ??
            jsonFr['locality'] ??
            '';
        results['ar'] = cityAr.split(RegExp(r'[،,]')).first.trim();
        results['fr'] = cityFr.split(RegExp(r'[،,]')).first.trim();
      }
    } catch (e) {
    }
    return results;
  }

  static double calcDistanceToFarthestStore(double userLat, double userLng) {
    try {
      final items = GlobalCart.provider.items;
      if (items.isEmpty) return 2.0;

      double maxDist = 0.0;
      final seen = <String>{};
      for (final item in items) {
        final lat = item.storeLat;
        final lng = item.storeLng;
        final key = item.storeId;
        if (lat != null && lat != 0 && lng != null && lng != 0 && key.isNotEmpty && seen.add(key)) {
          final d = calcDistance(lat, lng, userLat, userLng);
          if (d > maxDist) maxDist = d;
        }
      }
      return maxDist > 0 ? maxDist : 2.0;
    } catch (_) {}
    return 2.0;
  }
}

int _countUniqueStores() {
  final items = GlobalCart.provider.items;
  final storeIds = <String>{};
  for (final item in items) {
    if (item.storeId.isNotEmpty) {
      storeIds.add(item.storeId);
    } else {
      final parts = item.productId.split('_');
      if (parts.length > 1) storeIds.add(parts.first);
    }
  }
  return storeIds.isEmpty ? 1 : storeIds.length;
}

int _countTotalQty() {
  final items = GlobalCart.provider.items;
  return items.fold(0, (sum, item) => sum + item.quantity);
}

class _ColorCacheEntry {
  final Color color;
  final DateTime time;
  _ColorCacheEntry(this.color) : time = DateTime.now();
  bool get isExpired => DateTime.now().difference(time).inMinutes > 10;
}

class _ItemColorCache {
  static final Map<String, _ColorCacheEntry> _cache = {};
  static const int _maxEntries = 50;

  static void _set(String storeId, Color color) {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[storeId] = _ColorCacheEntry(color);
  }

  static Future<Color> getColor(String storeId) async {
    final entry = _cache[storeId];
    if (entry != null && !entry.isExpired) return entry.color;
    final cached = StoreColorCache.get(storeId);
    if (cached != null) {
      _set(storeId, cached);
      return cached;
    }
    try {
      final doc = await ApiClient.get('/api/stores/$storeId');
      if (doc != null && doc.isNotEmpty) {
        final hex = doc['primaryColor'] as String?;
        if (hex != null && hex.isNotEmpty) {
          final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
          _set(storeId, color);
          return color;
        }
      }
    } catch (_) {}
    return kPrimary;
  }
}

String formatPrice(double price) => "${price.toInt()} DA";

//  CartScreen — ✅ يحسب التوصيل تلقائياً من LocationProvider
// ══════════════════════════════════════════════════════════════════════════════
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<String, Color> _colorsMap = {};
  Map<String, dynamic>? _precomputedPricing;
  bool _loadingPrecomputed = false;
  bool _showPriceDetails = true;
  String _precomputedCityName = '';

  @override
  void initState() {
    super.initState();
    _preloadColors();
    _autoComputeDeliveryFromLocation();
  }

  Future<void> _autoComputeDeliveryFromLocation() async {
    final locationProvider = LocationProvider();
    if (!locationProvider.hasLocation) return;
    if (mounted) setState(() => _loadingPrecomputed = true);
    try {
      final cityNames = await DeliveryPricingService.getCityNamesFromCoords(
        locationProvider.lat!,
        locationProvider.lng!,
      );
      final cAr = cityNames['ar']!;
      final cFr = cityNames['fr']!;
      final distKm = await DeliveryPricingService.calcDistanceToFarthestStore(
        locationProvider.lat!,
        locationProvider.lng!,
      );
      Map<String, dynamic>? pickedNearby;
      var pricing = await DeliveryPricingService.fetchForCity(
        cityNameAr: cAr,
        cityNameFr: cFr,
        distanceKm: distKm,
        categoriesCount: _countUniqueStores(),
        totalQty: _countTotalQty(),
      );
      if (pricing == null && mounted) {
        pickedNearby = await DeliveryPricingService.pickNearbyCity(
          context,
          userLat: locationProvider.lat!,
          userLng: locationProvider.lng!,
          currentCityAr: cAr,
        );
        if (pickedNearby != null && mounted) {
          pricing = await DeliveryPricingService.fetchForCity(
            cityNameAr: pickedNearby['ar']!,
            cityNameFr: pickedNearby['fr']!,
            distanceKm: distKm,
            categoriesCount: _countUniqueStores(),
            totalQty: _countTotalQty(),
          );
        }
      }
      if (mounted) {
        setState(() {
          _precomputedPricing = pricing;
          _precomputedCityName = (pickedNearby != null) ? pickedNearby['ar'] as String : cAr;
          _loadingPrecomputed = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _precomputedPricing = null;
          _loadingPrecomputed = false;
        });
    }
  }

  Future<void> _onTapNoPricing() async {
    final locationProvider = LocationProvider();
    if (!locationProvider.hasLocation) return;
    final cityNames = await DeliveryPricingService.getCityNamesFromCoords(
      locationProvider.lat!,
      locationProvider.lng!,
    );
    if (!mounted) return;
    final picked = await DeliveryPricingService.pickNearbyCity(
      context,
      userLat: locationProvider.lat!,
      userLng: locationProvider.lng!,
      currentCityAr: cityNames['ar']!,
    );
    if (picked != null && mounted) {
      final distKm = await DeliveryPricingService.calcDistanceToFarthestStore(
        locationProvider.lat!,
        locationProvider.lng!,
      );
      setState(() => _loadingPrecomputed = true);
      final pricing = await DeliveryPricingService.fetchForCity(
        cityNameAr: picked['ar']!,
        cityNameFr: picked['fr']!,
        distanceKm: distKm,
        categoriesCount: _countUniqueStores(),
        totalQty: _countTotalQty(),
      );
      if (mounted) {
        setState(() {
          _precomputedPricing = pricing;
          _precomputedCityName = picked['ar'] as String? ?? '';
          _loadingPrecomputed = false;
        });
      }
    }
  }

  Widget _buildStoreGroup(String storeKey, List<Product> products) {
    final Color storeColor = _colorForItem(products.first);
    final p = products.first;
    final String headerName = p.categoryName.isNotEmpty
        ? (p.categoryName == 'عرض خاص' && p.templateName.isNotEmpty
            ? '${p.categoryName} — ${p.templateName}'
            : p.categoryName)
        : p.storeName.isNotEmpty && p.templateName.isNotEmpty
        ? '${p.storeName} — ${p.templateName}'
        : p.storeName.isNotEmpty
        ? p.storeName
        : p.templateName.isNotEmpty
        ? p.templateName
        : storeKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F0FA), Color(0xFFEDE4F5)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
            color: const Color(0xFFD8D7DE),
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: storeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  headerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: storeColor,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
          // عرض المنتجات ككاردات داخل الإطار
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: products
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _neumorphicCartItem(
                        item,
                      ), // استخدام الكارد الذي أرسلته أنت
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _preloadColors() async {
    final items = GlobalCart.provider.items;
    final storeIds = items.map((p) => _extractStoreId(p)).toSet();
    for (final sid in storeIds) {
      if (sid.isEmpty) continue;
      final color = await _ItemColorCache.getColor(sid);
      if (mounted) setState(() => _colorsMap[sid] = color);
    }
  }

  String _extractStoreId(Product item) {
    if (item.storeId.isNotEmpty) return item.storeId;
    final parts = item.productId.split('_');
    if (parts.length > 1) return parts.first;
    return '';
  }

  Color _colorForItem(Product item) {
    final sid = _extractStoreId(item);
    return _colorsMap[sid] ?? kPrimary;
  }

  Widget _neumorphicBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: kNeumShadow,
              blurRadius: 8,
              offset: const Offset(3, 3),
            ),
            BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 8,
              offset: const Offset(-3, -3),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: kPrimary,
          size: 22,
        ),
      ),
    );
  }

  void _showCheckoutSheet(double subtotal) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }
    if (_isProjectStyle) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _ProjectCheckoutSheet(onConfirmed: () => setState(() {})),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        subtotal: subtotal,
        initialPricing: _precomputedPricing,
        initialCityName: _precomputedCityName,
        onConfirmed: () => setState(() {}),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kBg, Color(0xFFE6E4F0)],
            ),
            boxShadow: [
              BoxShadow(
                color: kNeumShadow,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryDark, kPrimary],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.lock_fill,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'سجّل دخولك أولاً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2A3A),
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'تحتاج تسجيل الدخول\nباش تقدر تأكد الطلبية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontFamily: 'Amiri',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 3)),
                    (_) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [kPrimaryDark, kPrimary, kAccent],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'لاحقاً',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontFamily: 'Amiri',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveTemplateButton() {
    return GestureDetector(
      onTap: () => _showSaveNameDialog(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFF5F0FA), Color(0xFFEDE4F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: kPrimary.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: kNeumShadow.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(3, 3),
            ),
            BoxShadow(
              color: const Color(0xFFB8B1C8).withOpacity(0.6),
              blurRadius: 6,
              offset: const Offset(-3, -3),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.bookmark, color: kPrimary, size: 20),
            SizedBox(width: 8),
            Text(
              "حفظ هذه الطلبية للمرة القادمة",
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveNameDialog() {
    final items = GlobalCart.provider.items;
    if (items.isEmpty) return;
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F0FA), Color(0xFFEDE4F5)],
            ),
            boxShadow: [
              BoxShadow(
                color: kNeumShadow,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.bookmark_fill,
                  color: kPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "حفظ الطلبية",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2A3A),
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "اختر اسماً لهذه الطلبية لتجدها\nبسهولة في المحفوظات لاحقاً",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'Amiri',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: kNeumShadow.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  autofocus: true,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 14,
                    color: kPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "مثال: عشاء العائلة، طلب المحل...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontFamily: 'Amiri',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                    prefixIcon: const Icon(
                      CupertinoIcons.pen,
                      color: kPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: kNeumShadow.withOpacity(0.5),
                              blurRadius: 6,
                              offset: const Offset(3, 3),
                            ),
                            const BoxShadow(
                              color: Colors.white,
                              blurRadius: 6,
                              offset: Offset(-3, -3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (controller.text.trim().isEmpty) return;
                        await _saveToFirebase(controller.text.trim());
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "تم حفظ الطلبية في المحفوظات ✅",
                              textAlign: TextAlign.right,
                              style: TextStyle(fontFamily: 'Amiri'),
                            ),
                            backgroundColor: kPrimary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kPrimaryDark, kPrimary],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            "حفظ الآن",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Amiri',
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
  }

  Future<void> _saveToFirebase(String templateName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final itemsData = GlobalCart.provider.items
        .map(
          (p) => {
            'productId': p.productId,
            'name': p.displayName,
            'selectedModelName': p.selectedModelName,
            'price': p.price,
            'image': p.imagePath,
            'quantity': p.quantity,
            'capacite': p.capacite,
            'uiStyle': p.uiStyle,
            'templateName': p.templateName,
            'storeName': p.storeName,
            'storeId': p.storeId,
            'storeLat': p.storeLat,
            'storeLng': p.storeLng,
            'sizes': p.sizes,
            'extraImages': p.extraImages,
            'variants': p.variants,
          },
        )
        .toList();
    await ApiClient.post('/api/users/${user.uid}/saved-templates', {
      'templateName': templateName,
      'items': itemsData,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: GlobalCart.provider,
        builder: (context, _) {
          final items = GlobalCart.provider.items;
          final subtotal = GlobalCart.provider.total;
          _preloadColors();

          return Scaffold(
                backgroundColor: kBg,
                appBar: AppBar(
                  centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Color(0xFF7D29C6),
                  statusBarIconBrightness: Brightness.light,
                ),
                automaticallyImplyLeading: false,
                leading: _neumorphicBackButton(),
                title: const Text(
                  "السلة",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2A3A),
                    fontFamily: 'Amiri',
                  ),
                ),
                actions: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${items.length} منتج",
                        style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Amiri',
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedOrdersScreen(),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: kNeumShadow.withOpacity(0.5),
                            blurRadius: 5,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: const Color(0xFFB8B1C8).withOpacity(0.6),
                            blurRadius: 5,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.bookmark_fill,
                        color: kPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: SafeArea(
                bottom: false,
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: kBg,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: kNeumShadow.withOpacity(0.6),
                                    blurRadius: 14,
                                    offset: const Offset(5, 5),
                                  ),
                                  BoxShadow(
                                    color: const Color(
                                      0xFFB8B1C8,
                                    ).withOpacity(0.6),
                                    blurRadius: 14,
                                    offset: const Offset(-5, -5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                CupertinoIcons.cart,
                                size: 50,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "السلة فارغة حالياً",
                              style: TextStyle(
                                color: Color(0xFF6E6B7B),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final Map<String, List<Product>> groupedItems =
                                    {};
                                for (var item in items) {
                                  String key = item.categoryName.isNotEmpty
                                      ? item.categoryName
                                      : item.storeId.isNotEmpty
                                      ? item.storeId
                                      : item.storeName;
                                  groupedItems
                                      .putIfAbsent(key, () => [])
                                      .add(item);
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: groupedItems.length,
                                  itemBuilder: (context, index) {
                                    String storeKey = groupedItems.keys
                                        .elementAt(index);
                                    List<Product> products =
                                        groupedItems[storeKey]!;
                                    return _buildStoreGroup(storeKey, products);
                                  },
                                );
                              },
                            ),
                          ),
                          _buildSummary(subtotal),
                        ],
                      ),
              ),
            );
    },
  );
}

  bool get _isProjectStyle =>
      GlobalCart.provider.items.isNotEmpty &&
      GlobalCart.provider.items.every((p) => p.uiStyle == 6 || p.uiStyle == 7);

  Widget _buildSummary(double subtotal) {
    final deliveryFee = (_precomputedPricing?['deliveryFee'] as double?) ?? 0;
    final total = _isProjectStyle ? subtotal : subtotal + deliveryFee;
    final cityName = _precomputedPricing?['cityName'] as String? ?? '';
    final distKm = _precomputedPricing?['distanceKm'] as double? ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
            color: const Color(0xFFD8D7DE),
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Column(
        children: [
          // رأس الشيت قابل للنقر للطي/الفتح
          GestureDetector(
            onTap: () => setState(() => _showPriceDetails = !_showPriceDetails),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _showPriceDetails ? Icons.expand_more : Icons.chevron_left,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                  const Spacer(),
                  Text(
                    "تفاصيل السعر",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _showPriceDetails
                ? Column(
                    children: [
                      _buildPriceRow(
                        "سعر المنتجات",
                        "${subtotal.toInt()} DA",
                        const Color(0xFF2D2A3A),
                      ),
                      const SizedBox(height: 8),
                      if (_isProjectStyle)
                        _buildPriceRow(
                          "التوصيل",
                          "يحدد لاحقاً",
                          Colors.grey,
                          fontSize: 12,
                        )
                      else
                        _buildDeliveryRow(deliveryFee, cityName, distKm),
                      const SizedBox(height: 8),
                      if (!_isProjectStyle)
                        _buildPriceRow(
                          "الإجمالي المتوقع",
                          "${total.toInt()} DA",
                          kPrimary,
                          isBold: true,
                          fontSize: 15,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Colors.grey.shade300,
                          thickness: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!_isProjectStyle) _saveTemplateButton(),
                    ],
                  )
                : const SizedBox(),
          ),
          _checkoutButton(total, subtotal, deliveryFee, cityName, distKm),
        ],
      ),
    );
  }

  Widget _buildDeliveryRow(double fee, String cityName, double distKm) {
    if (_loadingPrecomputed) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 80,
            height: 14,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(kPrimary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const Text(
            "سعر التوصيل",
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontFamily: 'Amiri',
            ),
          ),
        ],
      );
    }
    final hasRealPricing = _precomputedPricing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            hasRealPricing
                ? Text(
                    "${fee.toInt()} DA",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                      fontFamily: 'Amiri',
                    ),
                  )
                : GestureDetector(
                    onTap: _onTapNoPricing,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "لا يوجد سائق في مدينتك",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D22AC),
                            fontFamily: 'Amiri',
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_back_ios_new,
                          size: 12,
                          color: Color(0xFF6D22AC),
                        ),
                      ],
                    ),
                  ),
            const Text(
              "سعر التوصيل",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontFamily: 'Amiri',
              ),
            ),
          ],
        ),
        if (!hasRealPricing)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'اضغط لاختيار مدينة قريبة منك',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'Amiri',
              ),
              textAlign: TextAlign.right,
            ),
          ),
        if (hasRealPricing && cityName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '$cityName · ${distKm.toStringAsFixed(1)} كم',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'Amiri',
              ),
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
            fontFamily: 'Amiri',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black54,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  ✅ كارد السلة المعدل — يعرض المشروبات
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _neumorphicCartItem(Product item) {
    final Color itemColor = _colorForItem(item);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
            color: const Color(0xFFD8D7DE),
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // 1. أزرار التحكم (زائد/ناقص/حذف)
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: kNeumShadow.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quantityButton(
                      icon: Icons.add,
                      accentColor: itemColor,
                      onTap: () {
                        GlobalCart.provider.updateQuantity(item, item.quantity + 1);
                      },
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${item.quantity}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: itemColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _quantityButton(
                      icon: Icons.remove,
                      accentColor: itemColor,
                      onTap: () {
                        if (item.quantity > 1) {
                          GlobalCart.provider.updateQuantity(item, item.quantity - 1);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => GlobalCart.provider.toggle(item),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: Colors.redAccent,
                  size: 16,
                ),
              ),
            ],
          ),

          const Spacer(),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2A3A),
                    fontFamily: 'Amiri',
                  ),
                  textAlign: TextAlign.right,
                ),
                if (item.capacite.isNotEmpty)
                  Text(
                    'الحجم: ${item.capacite}',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Amiri',
                    ),
                  ),

                Text("${item.price.toInt()} DA"),

                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showNoteDialog(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9232E8).withOpacity(0.5),
                          const Color(0xFF7D29C6).withOpacity(0.5),
                          const Color(0xFF6D22AC).withOpacity(0.5),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.text_bubble_fill,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'أضف ملاحظة',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Amiri',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // 3. صورة المنتج (أقصى اليمين)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: _buildCartImage(item.imagePath),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(Product item) {
    final ctrl = TextEditingController(text: item.note);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'ملاحظة المنتج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                  color: Color(0xFF2D2A3A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6D22AC),
                      Color(0xFF7D29C6),
                      Color(0xFF9232E8),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.pencil,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withOpacity(0.1)),
            ),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6E6B7B),
                fontFamily: 'Amiri',
              ),
              decoration: const InputDecoration(
                hintText: 'أكتب ملاحظة للمنتج...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB8B1C8),
                  fontFamily: 'Amiri',
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                GlobalCart.provider.updateNote(item, ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text(
                'حفظ',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7D29C6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ويدجيت عرض المشروبات في السلة

  Widget _buildCartImage(String path) {
    if (path.isEmpty)
      return const Center(
        child: Icon(CupertinoIcons.photo, color: Colors.grey),
      );
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.contain,
        memCacheWidth: 140,
        placeholder: (_, __) =>
            const Center(child: CupertinoActivityIndicator(radius: 8)),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(CupertinoIcons.photo, color: Colors.grey)),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9232E8), Color(0xFF7D29C6), Color(0xFF6D22AC)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7D29C6).withOpacity(0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }

  Widget _checkoutButton(
    double total,
    double subtotal,
    double deliveryFee,
    String cityName,
    double distKm,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _loadingPrecomputed ? null : () => _showCheckoutSheet(subtotal),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: _loadingPrecomputed ? null : const LinearGradient(
                colors: [kPrimaryDark, kPrimary, kAccent],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              color: _loadingPrecomputed ? Colors.grey.shade300 : null,
              boxShadow: _loadingPrecomputed ? [] : [
                BoxShadow(
                  color: kPrimary.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: _loadingPrecomputed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.grey.shade500,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "جاري حساب سعر التوصيل...",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.checkmark_shield,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isProjectStyle ? "تقديم طلب المشروع" : "تأكيد الطلب",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Amiri',
                              ),
                            ),
                          ],
                        ),
                ),
                Positioned(
                  left: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      "${total.toInt()} DA",
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _CheckoutSheet — تأكيد الطلبية مع نظام الوفاء + التسعيرة الموحدة
// ══════════════════════════════════════════════════════════════════════════════
class _CheckoutSheet extends StatefulWidget {
  final double subtotal;
  final VoidCallback onConfirmed;
  final Map<String, dynamic>? initialPricing;
  final String initialCityName;

  const _CheckoutSheet({
    required this.subtotal,
    required this.onConfirmed,
    this.initialPricing,
    this.initialCityName = '',
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  List<Map<String, dynamic>> _savedLocations = [];
  bool _loadingLocations = true;
  int _selectedLocationIndex = -1;
  bool _useMap = false;
  String _mapAddress = '';
  double? _selectedLat;
  double? _selectedLng;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isLoading = false;
  String _selectedCityAr = '';
  String _selectedCityFr = '';

  Map<String, dynamic>? _pricingInfo;
  bool _loadingPricing = false;
  String _userCityName = '';

  bool _hasFreeDelivery = false;

  bool? _driversAvailable;
  List<Map<String, dynamic>> _alternateCities = [];
  bool _loadingAltCities = false;

  @override
  void initState() {
    super.initState();
    _pricingInfo = widget.initialPricing;
    _userCityName = widget.initialCityName;
    _loadLocations();
    _loadLoyaltyData();
    final lp = LocationProvider();
    if (lp.hasLocation) {
      DeliveryPricingService.getCityNamesFromCoords(lp.lat!, lp.lng!).then((
        names,
      ) {
        _checkDriversForCity(names['ar']!, names['fr']!);
      });
    }
  }

  Future<void> _checkDriversForCity(
    String cityNameAr,
    String cityNameFr,
  ) async {
    final hasDrivers = await DeliveryPricingService.hasDriversInCity(
      cityNameAr,
      cityNameFr,
    );
    if (mounted) setState(() => _driversAvailable = hasDrivers);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLoyaltyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await ApiClient.get('/api/users/${user.uid}');
      if (mounted) {
        setState(() {
          _hasFreeDelivery = doc?['hasFreeDelivery'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final locations = await ApiClient.getList(
        '/api/users/${user.uid}/saved-locations',
      );
      if (mounted) {
        setState(() {
          _savedLocations = locations
              .map(
                (doc) => {
                  'id': doc['_id'] ?? '',
                  'label': doc['label'] as String? ?? '',
                  'address': doc['address'] as String? ?? '',
                  'lat': doc['lat'],
                  'lng': doc['lng'],
                  'cityNameAr': doc['cityNameAr'] as String? ?? '',
                  'cityNameFr': doc['cityNameFr'] as String? ?? '',
                  'icon': _iconFromType(doc['type'] as String? ?? 'other'),
                  'doorNumber': doc['doorNumber'] as String? ?? '',
                  'doorColor': doc['doorColor'] as String? ?? '',
                  'locationImage': doc['locationImage'] as String? ?? '',
                  'housingType': doc['housingType'] as String? ?? '',
                  'floor': doc['floor'] as String? ?? '',
                },
              )
              .where((loc) => (loc['label'] as String).isNotEmpty)
              .toList();
          _loadingLocations = false;
        });
        _autoSelectLocationFromProvider();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  void _autoSelectLocationFromProvider() {
    final provider = LocationProvider();
    if (!provider.hasLocation || _savedLocations.isEmpty) return;
    for (int i = 0; i < _savedLocations.length; i++) {
      if (_savedLocations[i]['address'] == provider.address) {
        setState(() {
          _selectedLocationIndex = i;
          _useMap = false;
        });
        return;
      }
    }
    if (_selectedLocationIndex == -1 && _savedLocations.isNotEmpty) {
      final firstLat = (_savedLocations[0]['lat'] as num?)?.toDouble();
      final firstLng = (_savedLocations[0]['lng'] as num?)?.toDouble();
      if (firstLat != null &&
          firstLng != null &&
          provider.lat != null &&
          provider.lng != null) {
        final dist = DeliveryPricingService.calcDistance(
          firstLat,
          firstLng,
          provider.lat!,
          provider.lng!,
        );
        if (dist < 0.5) setState(() => _selectedLocationIndex = 0);
      }
    }
  }

  IconData _iconFromType(String type) {
    switch (type) {
      case 'home':
        return CupertinoIcons.house_fill;
      case 'work':
        return CupertinoIcons.briefcase_fill;
      default:
        return CupertinoIcons.location_fill;
    }
  }

  String get _finalAddress {
    if (_useMap) return _mapAddress;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return _savedLocations[_selectedLocationIndex]['address'] as String;
    return '';
  }

  double? get _finalLat {
    if (_useMap) return _selectedLat;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return (_savedLocations[_selectedLocationIndex]['lat'] as num?)
          ?.toDouble();
    return null;
  }

  double? get _finalLng {
    if (_useMap) return _selectedLng;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return (_savedLocations[_selectedLocationIndex]['lng'] as num?)
          ?.toDouble();
    return null;
  }

  double get _currentDeliveryFee {
    if (_hasFreeDelivery) return 0;
    return (_pricingInfo?['deliveryFee'] as double?) ?? 0;
  }

  bool get _isProjectOrder =>
      GlobalCart.provider.items.isNotEmpty &&
      GlobalCart.provider.items.every((p) => p.uiStyle == 6 || p.uiStyle == 7);

  bool get _canConfirm =>
      _finalAddress.isNotEmpty &&
      !_isLoading &&
      !_loadingPricing &&
      _pricingInfo != null &&
      (_isProjectOrder ||
          _driversAvailable == true ||
          _driversAvailable == null);

  Future<void> _fetchPricingForLocation(double userLat, double userLng) async {
    setState(() => _loadingPricing = true);
    try {
      final cityNames = await DeliveryPricingService.getCityNamesFromCoords(
        userLat,
        userLng,
      );
      String cAr = cityNames['ar']!;
      String cFr = cityNames['fr']!;
      _userCityName = cAr;
      _selectedCityAr = cAr;
      _selectedCityFr = cFr;
      final hasDrivers = await DeliveryPricingService.hasDriversInCity(
        cAr,
        cFr,
      );
      if (mounted)
        setState(() {
          _driversAvailable = hasDrivers;
          if (hasDrivers) _alternateCities = [];
        });
      if (!hasDrivers) _loadAlternateCities();
      final distKm = await DeliveryPricingService.calcDistanceToFarthestStore(
        userLat,
        userLng,
      );
      var pricing = await DeliveryPricingService.fetchForCity(
        cityNameAr: cAr,
        cityNameFr: cFr,
        distanceKm: distKm,
        categoriesCount: _countUniqueStores(),
        totalQty: _countTotalQty(),
      );
      if (pricing == null && mounted) {
        final picked = await DeliveryPricingService.pickNearbyCity(
          context,
          userLat: userLat,
          userLng: userLng,
          currentCityAr: cAr,
        );
        if (picked != null && mounted) {
          cAr = picked['ar']!;
          cFr = picked['fr']!;
          _selectedCityAr = cAr;
          _selectedCityFr = cFr;
          pricing = await DeliveryPricingService.fetchForCity(
            cityNameAr: cAr,
            cityNameFr: cFr,
            distanceKm: distKm,
            categoriesCount: _countUniqueStores(),
            totalQty: _countTotalQty(),
          );
        }
      }
      if (mounted)
        setState(() {
          _pricingInfo = pricing;
          _loadingPricing = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _pricingInfo = null;
          _loadingPricing = false;
        });
    }
  }

  Future<void> _loadAlternateCities() async {
    if (_loadingAltCities) return;
    setState(() => _loadingAltCities = true);
    try {
      final all = await DeliveryPricingService.getCitiesWithDrivers();
      final filtered = all.where((c) => c['ar'] != _selectedCityAr).toList();
      final userLat = _finalLat;
      final userLng = _finalLng;
      for (final c in filtered) {
        final clat = c['lat'] as double?;
        final clng = c['lng'] as double?;
        if (userLat != null &&
            userLng != null &&
            clat != null &&
            clng != null) {
          c['dist'] = DeliveryPricingService.calcDistance(
            userLat,
            userLng,
            clat,
            clng,
          );
        } else {
          c['dist'] = null;
        }
      }
      filtered.sort((a, b) {
        final da = a['dist'] as double? ?? double.infinity;
        final db = b['dist'] as double? ?? double.infinity;
        return da.compareTo(db);
      });
      if (mounted) setState(() => _alternateCities = filtered.take(7).toList());
    } catch (_) {}
    if (mounted) setState(() => _loadingAltCities = false);
  }

  void _showAlternateCitiesSheet() {
    if (_alternateCities.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'مناطق متوفر فيها سائقين',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2A3A),
              ),
            ),
            const SizedBox(height: 16),
            ..._alternateCities.map((city) {
              final dist = city['dist'] as double?;
              final distText = dist != null
                  ? (dist < 1
                        ? '${(dist * 1000).toStringAsFixed(0)} m'
                        : '${dist.toStringAsFixed(1)} كم')
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _selectAlternateCity(city['ar']!, city['fr']!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: kNeumShadow.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_fill,
                          color: kPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            city['ar'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (distText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              distText,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAlternateCity(String cityAr, String cityFr) async {
    final lat = _finalLat;
    final lng = _finalLng;
    if (lat == null || lng == null) return;
    setState(() {
      _selectedCityAr = cityAr;
      _selectedCityFr = cityFr;
      _driversAvailable = true;
      _pricingInfo = null;
    });
    final distKm = await DeliveryPricingService.calcDistanceToFarthestStore(
      lat,
      lng,
    );
    final pricing = await DeliveryPricingService.fetchForCity(
      cityNameAr: cityAr,
      cityNameFr: cityFr,
      distanceKm: distKm,
      categoriesCount: _countUniqueStores(),
      totalQty: _countTotalQty(),
    );
    if (mounted)
      setState(() {
        _pricingInfo = pricing;
        _alternateCities = [];
      });
  }

  void _showPricingDetails() {
    if (_pricingInfo == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PricingDetailsSheet(pricingInfo: _pricingInfo!),
    );
  }

  Future<void> _confirm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> selectedLocExtraData = {};
      if (!_useMap && _selectedLocationIndex >= 0) {
        selectedLocExtraData = _savedLocations[_selectedLocationIndex];
      }
      Map<String, dynamic> userData = {};
      if (UserLocal.uid == user.uid && UserLocal.data != null) {
        userData = UserLocal.data!;
      } else {
        final doc = await ApiClient.get('/api/users/${user.uid}');
        userData = doc ?? {};
        UserLocal.data = userData;
        UserLocal.uid = user.uid;
      }

      final String apiName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final String userName = apiName.isNotEmpty
          ? apiName
          : (FirebaseAuth.instance.currentUser?.displayName ?? 'زبون');
      final String userPhone = userData['phone'] as String? ?? '';
      final bool isUserVerified = userData['isVerified'] ?? false;

      final itemsData = GlobalCart.provider.items
          .map(
            (p) => {
              'productId': p.productId,
              'name': p.name,
              'selectedModelName': p.selectedModelName,
              'prix': p.price,
              'quantity': p.quantity,
              'image': p.imagePath,
              'capacite': p.capacite,
              'totalItem': p.price * p.quantity,
              'templateName': p.templateName ?? 'نشاط عام',
              'categoryName': p.categoryName,
              'categorieId': p.categoryId,
              'storeName': p.storeName,
              'storeId': p.storeId,
              'storeLat': p.storeLat,
              'storeLng': p.storeLng,
              'uiStyle': p.uiStyle,
              'sizes': p.sizes,
              'extraImages': p.extraImages,
              'variants': p.variants,
              'purchaseStatus': '',
              'note': p.note ?? '',
            },
          )
          .toList();

      final bool isStyle6 = itemsData.any((item) => item['uiStyle'] == 6);

      if (isStyle6) {
        final firstItem = itemsData.first;
        final description = firstItem['name'] ?? '';
        final note = _noteCtrl.text.trim();
        final fullDescription = note.isNotEmpty
            ? '$description\nملاحظة: $note'
            : description;

        final projectResult = await ApiClient.post('/api/projects', {
          'name': userName.isNotEmpty ? userName : 'زبون',
          'phone': userPhone,
          'description': fullDescription,
          'capacite': firstItem['capacite'] ?? '',
          'location': _finalAddress,
          'userLat': _finalLat,
          'userLng': _finalLng,
          'storeId': firstItem['storeId'] ?? '',
          'storeName': firstItem['storeName'] ?? '',
          'storeLat': firstItem['storeLat'],
          'storeLng': firstItem['storeLng'],
          'userId': user.uid,
          'userEmail': user.email ?? '',
          'imageUrl': firstItem['image'] ?? '',
          'productPrice': widget.subtotal,
          'quantity': firstItem['quantity'] ?? 1,
          'productId': firstItem['productId'] ?? '',
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        });
        if (projectResult['_id'] == null) throw Exception('لم يتم حفظ الطلبية');

      widget.onConfirmed();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال طلب المشروع إلى صاحب المتجر بنجاح!'),
            backgroundColor: Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final double deliveryFee = _currentDeliveryFee;
      final double total = widget.subtotal + deliveryFee;

      final double? firstStoreLat = itemsData.isNotEmpty
          ? itemsData.first['storeLat'] as double?
          : null;
      final double? firstStoreLng = itemsData.isNotEmpty
          ? itemsData.first['storeLng'] as double?
          : null;

      final orderData = {
        'userId': user.uid,
        'userName': userName.isNotEmpty ? userName : 'زبون',
        'userPhone': userPhone,
        'userPhotoUrl': userData['photoUrl'] ?? '',
        'userVerified': isUserVerified,
        'magasinId': itemsData.isNotEmpty ? itemsData.first['storeId'] : '',
        'items': itemsData,
        'subtotal': widget.subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'address': _finalAddress,
        'userLat': _finalLat,
        'userLng': _finalLng,
        'storeLat': firstStoreLat,
        'storeLng': firstStoreLng,
        'doorNumber': selectedLocExtraData['doorNumber'] ?? '',
        'doorColor': selectedLocExtraData['doorColor'] ?? '',
        'locationImage': selectedLocExtraData['locationImage'] ?? '',
        'housingType': selectedLocExtraData['housingType'] ?? '',
        'floor': selectedLocExtraData['floor'] ?? '',
        'userCityName': _selectedCityAr,
        'userCityNameFr': _selectedCityFr,
        'driverNote': _noteCtrl.text.trim(),
        'isFreeDelivery': _hasFreeDelivery,
        'pricingDetails': _pricingInfo,
      };

      widget.onConfirmed();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverSelectionScreen(orderData: orderData),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = _currentDeliveryFee;
    final total = widget.subtotal + deliveryFee;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryDark, kPrimary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    formatPrice(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
                const Text(
                  "تأكيد الطلبية",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2A3A),
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "موقع التوصيل",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2A3A),
                  fontFamily: 'Amiri',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLocations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: kPrimary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_savedLocations.isEmpty)
              _buildNoLocationsHint()
            else
              ..._savedLocations.asMap().entries.map((e) {
                final i = e.key;
                final loc = e.value;
                final isSelected = !_useMap && _selectedLocationIndex == i;
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedLocationIndex = i;
                      _useMap = false;
                      _selectedCityAr = loc['cityNameAr'] ?? '';
                      _selectedCityFr = loc['cityNameFr'] ?? '';
                      _userCityName = _selectedCityAr;
                    });
                    final lat = (loc['lat'] as num?)?.toDouble();
                    final lng = (loc['lng'] as num?)?.toDouble();
                    if (lat != null && lng != null) {
                      if (_selectedCityAr.isEmpty) {
                        await _fetchPricingForLocation(lat, lng);
                      } else {
                        _checkDriversForCity(_selectedCityAr, _selectedCityFr);
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimary.withOpacity(0.15) : kBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? kPrimary
                            : kNeumShadow.withOpacity(0.3),
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: kNeumShadow.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(3, 3),
                              ),
                              BoxShadow(
                                color: const Color(0xFFB8B1C8).withOpacity(0.6),
                                blurRadius: 6,
                                offset: const Offset(-3, -3),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? kPrimary : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? kPrimary
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  loc['label'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? kPrimary
                                        : const Color(0xFF2D2A3A),
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                                Text(
                                  loc['address'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? kPrimary.withOpacity(0.8)
                                        : Colors.black45,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          loc['icon'] as IconData,
                          color: isSelected
                              ? kPrimary
                              : const Color(0xFF6E6B7B),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              }),

            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                );
                if (result != null && mounted) {
                  setState(() {
                    _useMap = true;
                    _selectedLocationIndex = -1;
                    if (result is Map) {
                      _mapAddress = result['address'].toString();
                      _selectedLat = double.tryParse(result['lat'].toString());
                      _selectedLng = double.tryParse(result['lng'].toString());
                    } else {
                      _mapAddress = result.toString();
                    }
                  });
                  if (_selectedLat != null && _selectedLng != null) {
                    await _fetchPricingForLocation(
                      _selectedLat!,
                      _selectedLng!,
                    );
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _useMap ? kPrimary : kBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _useMap ? kPrimary : kNeumShadow.withOpacity(0.3),
                    width: _useMap ? 2 : 1.2,
                  ),
                  boxShadow: _useMap
                      ? [
                          BoxShadow(
                            color: kPrimary.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: kNeumShadow.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(3, 3),
                          ),
                          BoxShadow(
                            color: const Color(0xFFB8B1C8).withOpacity(0.6),
                            blurRadius: 6,
                            offset: const Offset(-3, -3),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _useMap ? Colors.white : Colors.transparent,
                        border: Border.all(
                          color: _useMap ? Colors.white : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: _useMap
                          ? const Icon(Icons.check, size: 14, color: kPrimary)
                          : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "تحديد من الخريطة",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _useMap
                                    ? Colors.white
                                    : const Color(0xFF2D2A3A),
                                fontFamily: 'Amiri',
                              ),
                            ),
                            Text(
                              _useMap && _mapAddress.isNotEmpty
                                  ? _mapAddress
                                  : "اضغط لفتح الخريطة",
                              style: TextStyle(
                                fontSize: 11,
                                color: _useMap
                                    ? Colors.white70
                                    : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.map_fill,
                      color: _useMap ? Colors.white : kPrimary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            if (_loadingPricing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CupertinoActivityIndicator(color: kPrimary),
                ),
              )
            else if (_pricingInfo != null)
              _buildPricingCard(),

            if (_driversAvailable == false && !_isProjectOrder)
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            'نعتذر، لا يوجد سائقون متاحون في منطقتك حالياً',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontFamily: 'Amiri',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.exclamationmark_circle_fill,
                          color: Colors.red,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingAltCities)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: CupertinoActivityIndicator(color: kPrimary),
                      ),
                    )
                  else if (_alternateCities.isNotEmpty)
                    GestureDetector(
                      onTap: _showAlternateCitiesSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPrimary.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: kPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'رؤية سائقين من مناطق قريبة (${_alternateCities.length})',
                              style: const TextStyle(
                                color: kPrimary,
                                fontSize: 13,
                                fontFamily: 'Amiri',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              CupertinoIcons.chevron_left,
                              color: kPrimary.withOpacity(0.6),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "ملاحظة للسائق",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2A3A),
                  fontFamily: 'Amiri',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kNeumShadow.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: const Color(0xFFB8B1C8).withOpacity(0.6),
                    blurRadius: 6,
                    offset: const Offset(-3, -3),
                  ),
                ],
              ),
              child: TextField(
                controller: _noteCtrl,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: "مثال: الباب الأزرق، الطابق الثاني...",
                  hintStyle: TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                    fontFamily: 'Amiri',
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.text_bubble,
                    color: kPrimary,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap:
                    (_canConfirm &&
                        (_isProjectOrder || _driversAvailable != false))
                    ? _confirm
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient:
                        (_canConfirm &&
                            (_isProjectOrder || _driversAvailable != false))
                        ? const LinearGradient(
                            colors: [kPrimaryDark, kPrimary, kAccent],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          )
                        : null,
                    color:
                        (_canConfirm &&
                            (_isProjectOrder || _driversAvailable != false))
                        ? null
                        : Colors.grey.shade300,
                    boxShadow:
                        (_canConfirm &&
                            (_isProjectOrder || _driversAvailable != false))
                        ? [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: (_isLoading || _loadingPricing)
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.grey.shade500,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_shield,
                                color:
                                    (_canConfirm &&
                                        (_isProjectOrder ||
                                            _driversAvailable != false))
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isProjectOrder
                                    ? "إرسال طلب المشروع"
                                    : _loadingPricing
                                    ? "جاري حساب سعر التوصيل..."
                                    : _driversAvailable == false
                                    ? "لا يوجد سائقون في منطقتك"
                                    : _canConfirm
                                    ? "تأكيد الطلبية"
                                    : "اختر موقع التوصيل",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri',
                                  color:
                                      (_canConfirm &&
                                          (_isProjectOrder ||
                                              _driversAvailable != false))
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    final fee = _currentDeliveryFee;
    final info = _pricingInfo;
    final extraCats = (info?['extraCatsCount'] as int? ?? 0);
    final extraCatsCharge = (info?['extraCatsCharge'] as double? ?? 0.0);
    final hasMultiStore = extraCats > 0;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (info != null && !_hasFreeDelivery)
                GestureDetector(
                  onTap: _showPricingDetails,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.info,
                      color: kPrimary,
                      size: 16,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_hasFreeDelivery)
                          const Text(
                            'مجاني 🎁',
                            style: TextStyle(
                              color: kSuccess,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Amiri',
                            ),
                          )
                        else
                          Text(
                            '${fee.toInt()} DA',
                            style: const TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: 'Amiri',
                            ),
                          ),
                        const SizedBox(width: 6),
                        const Text(
                          'سعر التوصيل:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2D2A3A),
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (info != null && info['cityName'] != null)
                      Text(
                        'مدينة: ${info['cityName']} · ${(info['distanceKm'] as double).toStringAsFixed(1)} كم',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.car_fill, color: kPrimary, size: 22),
            ],
          ),
          if (hasMultiStore && !_hasFreeDelivery) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '+${extraCatsCharge.toInt()} DA',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Amiri',
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'رسوم $extraCats محل إضافي',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2D2A3A),
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.shopping_cart,
                        color: kPrimary,
                        size: 13,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoLocationsHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBg, Color(0xFFE6E4F0)],
        ),
        boxShadow: [
          BoxShadow(color: kNeumShadow, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
        border: Border.all(color: kPrimary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'مكاش مواقع محفوظة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Amiri',
                    color: Color(0xFF2D2A3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'استخدم الخريطة لتحديد موقعك',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Amiri',
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.location_slash,
              color: kPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _ProjectCheckoutSheet — فورم طلب مشروع (style 6)
// ══════════════════════════════════════════════════════════════════════════════
class _ProjectCheckoutSheet extends StatefulWidget {
  final VoidCallback onConfirmed;
  const _ProjectCheckoutSheet({required this.onConfirmed});

  @override
  State<_ProjectCheckoutSheet> createState() => _ProjectCheckoutSheetState();
}

class _ProjectCheckoutSheetState extends State<_ProjectCheckoutSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<Map<String, dynamic>> _savedLocations = [];
  bool _loadingLocations = true;
  int _selectedLocationIndex = -1;
  bool _useMap = false;
  String _mapAddress = '';
  double? _selectedLat;
  double? _selectedLng;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLocations();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (UserLocal.uid == user.uid && UserLocal.data != null) {
        _nameCtrl.text =
            '${UserLocal.data!['firstName'] ?? ''} ${UserLocal.data!['lastName'] ?? ''}'
                .trim();
        _phoneCtrl.text = UserLocal.data!['phone'] as String? ?? '';
      } else {
        final doc = await ApiClient.get('/api/users/${user.uid}');
        final data = doc ?? {};
        UserLocal.data = data;
        UserLocal.uid = user.uid;
        _nameCtrl.text = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
            .trim();
        _phoneCtrl.text = data['phone'] as String? ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingLocations = false);
      return;
    }
    try {
      final locations = await ApiClient.getList(
        '/api/users/${user.uid}/saved-locations',
      );
      if (mounted) {
        setState(() {
          _savedLocations = locations
              .map(
                (doc) => {
                  'id': doc['_id'] ?? '',
                  'label': doc['label'] as String? ?? '',
                  'address': doc['address'] as String? ?? '',
                  'lat': doc['lat'],
                  'lng': doc['lng'],
                  'cityNameAr': doc['cityNameAr'] as String? ?? '',
                  'cityNameFr': doc['cityNameFr'] as String? ?? '',
                  'doorNumber': doc['doorNumber'] as String? ?? '',
                  'doorColor': doc['doorColor'] as String? ?? '',
                  'locationImage': doc['locationImage'] as String? ?? '',
                  'housingType': doc['housingType'] as String? ?? '',
                  'floor': doc['floor'] as String? ?? '',
                },
              )
              .where((loc) => (loc['label'] as String).isNotEmpty)
              .toList();
          _loadingLocations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  String get _finalAddress {
    if (_useMap) return _mapAddress;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return _savedLocations[_selectedLocationIndex]['address'] as String;
    return '';
  }

  double? get _finalLat {
    if (_useMap) return _selectedLat;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return (_savedLocations[_selectedLocationIndex]['lat'] as num?)
          ?.toDouble();
    return null;
  }

  double? get _finalLng {
    if (_useMap) return _selectedLng;
    if (_selectedLocationIndex >= 0 &&
        _selectedLocationIndex < _savedLocations.length)
      return (_savedLocations[_selectedLocationIndex]['lng'] as num?)
          ?.toDouble();
    return null;
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف')),
      );
      return;
    }
    if (_finalAddress.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار موقع التوصيل')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final firstItem = GlobalCart.provider.items.first;
      final storeName = firstItem.storeName;
      final productName = firstItem.name;
      final note = _noteCtrl.text.trim();
      final fullDesc = note.isNotEmpty
          ? '$productName\nملاحظة: $note'
          : productName;

      await ApiClient.post('/api/projects', {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'description': fullDesc,
        'location': _finalAddress,
        'userLat': _finalLat,
        'userLng': _finalLng,
        'storeId': firstItem.storeId,
        'storeName': storeName,
        'storeLat': firstItem.storeLat,
        'storeLng': firstItem.storeLng,
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'imageUrl': firstItem.imagePath,
        'productPrice': firstItem.price * firstItem.quantity,
        'quantity': firstItem.quantity,
        'productId': firstItem.productId,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      GlobalCart.provider.clear();
      widget.onConfirmed();
      if (!mounted) return;
      Navigator.pop(context);
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text(
            'تم إرسال طلبك',
            style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'انتظر اتصالاً من عند $storeName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 14),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text(
                'حسناً',
                style: TextStyle(fontFamily: 'Amiri', color: Color(0xFF7D29C6)),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimaryDark, kPrimary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    GlobalCart.provider.items.first.storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
                const Text(
                  "طلب مشروع",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2A3A),
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildField(_nameCtrl, 'الاسم واللقب', CupertinoIcons.person_fill),
            const SizedBox(height: 14),
            _buildField(
              _phoneCtrl,
              'رقم الهاتف',
              CupertinoIcons.phone_fill,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _buildNoteField(),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "موقع التوصيل",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2A3A),
                  fontFamily: 'Amiri',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingLocations)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: kPrimary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_savedLocations.isEmpty && !_useMap)
              _buildNoLocationsHint()
            else
              ..._savedLocations.asMap().entries.map((e) {
                final i = e.key;
                final loc = e.value;
                final isSelected = !_useMap && _selectedLocationIndex == i;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedLocationIndex = i;
                    _useMap = false;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? kPrimary.withOpacity(0.15) : kBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? kPrimary
                            : kNeumShadow.withOpacity(0.3),
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: kNeumShadow,
                                blurRadius: 6,
                                offset: const Offset(3, 3),
                              ),
                              BoxShadow(
                                color: const Color(0xFFD8D7DE),
                                blurRadius: 6,
                                offset: const Offset(-3, -3),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          color: isSelected ? kPrimary : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                loc['label'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? kPrimary
                                      : const Color(0xFF2D2A3A),
                                  fontSize: 13,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                              if ((loc['address'] ?? '').isNotEmpty)
                                Text(
                                  loc['address'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontFamily: 'Amiri',
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            if (!_useMap)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _useMap = true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: kPrimary.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.map_pin_ellipse,
                          color: kPrimary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "تحديد من الخريطة",
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              _buildMapAddress(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _isLoading ? null : _submit,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [kPrimaryDark, kPrimary, kAccent],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                    color: _isLoading ? Colors.grey.shade300 : null,
                    boxShadow: _isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.paperplane_fill,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "إرسال الطلب",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNeumShadow.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontSize: 13,
            fontFamily: 'Amiri',
          ),
          prefixIcon: Icon(icon, color: kPrimary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNeumShadow.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: const Color(0xFFB8B1C8).withOpacity(0.6),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: TextField(
        controller: _noteCtrl,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ملاحظة للطلب (اختياري)',
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontSize: 13,
            fontFamily: 'Amiri',
          ),
          prefixIcon: const Icon(
            CupertinoIcons.pencil,
            color: kPrimary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocationsHint() {
    return GestureDetector(
      onTap: () => setState(() => _useMap = true),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimary.withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.map_pin_ellipse, color: kPrimary, size: 22),
            SizedBox(width: 10),
            Text(
              "اختر موقع التوصيل من الخريطة",
              style: TextStyle(
                fontFamily: 'Amiri',
                color: kPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAddress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            "العنوان من الخريطة",
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: kPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _mapAddress.isNotEmpty ? _mapAddress : 'لم يتم تحديد موقع بعد',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 12,
              color: _mapAddress.isNotEmpty ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPickerScreen()),
              );
              if (result != null && mounted) {
                setState(() {
                  _mapAddress = result['address'] ?? '';
                  _selectedLat = result['lat'] as double?;
                  _selectedLng = result['lng'] as double?;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryDark, kPrimary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.map, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "فتح الخريطة",
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _useMap = false),
            child: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "إلغاء",
                style: TextStyle(
                  fontFamily: 'Amiri',
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _PricingDetailsSheet — شرح تفاصيل حساب التوصيل
// ══════════════════════════════════════════════════════════════════════════════
class _PricingDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> pricingInfo;
  const _PricingDetailsSheet({required this.pricingInfo});

  @override
  Widget build(BuildContext context) {
    final basePrice = (pricingInfo['basePrice'] as double? ?? 0);
    final baseDist = (pricingInfo['baseDist'] as double? ?? 5);
    final extraKm = (pricingInfo['extraKm'] as double? ?? 0);
    final extraDistPrice = (pricingInfo['extraDistPrice'] as double? ?? 15);
    final extraCharge = (pricingInfo['extraCharge'] as double? ?? 0);
    final deliveryFee = (pricingInfo['deliveryFee'] as double? ?? 0);
    final distKm = (pricingInfo['distanceKm'] as double? ?? 0);
    final cityName = pricingInfo['cityName'] as String? ?? '';
    final categoriesCount = (pricingInfo['categoriesCount'] as int? ?? 1);
    final baseCats = (pricingInfo['baseCats'] as int? ?? 1);
    final extraCats = (pricingInfo['extraCatsCount'] as int? ?? 0);
    final extraCatPrice = (pricingInfo['extraCatPrice'] as double? ?? 0);
    final extraCatsCharge = (pricingInfo['extraCatsCharge'] as double? ?? 0);
    final baseQty = (pricingInfo['baseQty'] as int? ?? 5);
    final extraQty = (pricingInfo['extraQtyCount'] as int? ?? 0);
    final extraQtyPrice = (pricingInfo['extraQtyPrice'] as double? ?? 0);
    final extraQtyCharge = (pricingInfo['extraQtyCharge'] as double? ?? 0);
    final totalQty = (pricingInfo['totalQty'] as int? ?? 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'تفاصيل حساب التوصيل',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.money_dollar_circle_fill,
                color: kPrimary,
                size: 20,
              ),
            ],
          ),
          if (cityName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  cityName,
                  style: const TextStyle(
                    color: kPrimary,
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'مدينة التوصيل:',
                  style: TextStyle(
                    color: Colors.black45,
                    fontFamily: 'Amiri',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _row(
            'الحزمة الأساسية',
            '${basePrice.toInt()} DA',
            sub:
                'تشمل أول ${baseDist.toInt()} كم و$baseCats محل و$baseQty منتج',
          ),
          if (extraKm > 0)
            _row(
              'مسافة إضافية × ${extraKm.toStringAsFixed(1)} كم',
              '${extraCharge.toInt()} DA',
              sub: '${extraDistPrice.toInt()} DA لكل كم إضافي',
            ),
          if (extraCats > 0)
            _row(
              'محلات إضافية × $extraCats',
              '${extraCatsCharge.toInt()} DA',
              sub:
                  '${extraCatPrice.toInt()} DA لكل محل إضافي (لديك $categoriesCount محلات)',
            ),
          if (extraQty > 0)
            _row(
              'منتجات إضافية × $extraQty',
              '${extraQtyCharge.toInt()} DA',
              sub:
                  '${extraQtyPrice.toInt()} DA لكل منتج إضافي (المجموع $totalQty)',
            ),
          const Divider(height: 20),
          _row(
            'المسافة الإجمالية',
            '${distKm.toStringAsFixed(1)} كم',
            isBold: false,
          ),
          _row(
            'سعر التوصيل الإجمالي',
            '${deliveryFee.toInt()} DA',
            isBold: true,
            color: kPrimary,
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    String? sub,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'Amiri',
              color:
                  color ?? (isBold ? const Color(0xFF2D2A3A) : Colors.black54),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 14 : 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Amiri',
                  color: color ?? const Color(0xFF2D2A3A),
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                    fontFamily: 'Amiri',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
