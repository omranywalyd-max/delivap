import 'package:flutter/material.dart';
import '../theme.dart';

// ═══════════════════════════════════════════
//  ⚠️ Aliases للتوافق مع الملفات القديمة
// ═══════════════════════════════════════════
const kPrimaryColor = AppTheme.primary;
const kAccentColor = AppTheme.accent;
const kBgColor = AppTheme.background;
const kTextColor = AppTheme.textDark;
const kTextGrey = AppTheme.textGrey;
const kNeumLight = AppTheme.neumLight;
const kNeumShadow = AppTheme.neumShadow;
const kCardColor = AppTheme.cardColor;
const kSuccessColor = AppTheme.success;
const kDangerColor = AppTheme.danger;
const kWarningColor = AppTheme.warning;

// ═══════════════════════════════════════════
//  OrderStatus enum
// ═══════════════════════════════════════════

enum OrderStatus { pending, accepted, purchased, onway, delivered, cancelled }

// ═══════════════════════════════════════════
//  OrderItem
// ═══════════════════════════════════════════

class OrderItem {
  final String name;
  final String image;
  final double price;
  final double originalPrice;
  final String purchaseStatus;
  final String alternativeName;
  final double alternativePrice;
  final String alternativeStatus;
  int quantity;
  final int uiStyle;
  final String capacite;
  final String categoryName;
  final String templateName;
  final String storeName;
  final String storeId;
  final List<dynamic> sizes;
  final List<dynamic> extraImages;
  final List<dynamic> variants;

  OrderItem({
    required this.name,
    required this.price,
    required this.originalPrice,
    this.purchaseStatus = '',
    this.alternativeName = '',
    this.alternativePrice = 0,
    this.alternativeStatus = '',
    this.image = '',
    this.quantity = 1,
    this.uiStyle = 1,
    this.capacite = '',
    this.categoryName = '',
    this.templateName = '',
    this.storeName = '',
    this.storeId = '',
    this.sizes = const [],
    this.extraImages = const [],
    this.variants = const [],
  });
}

// ═══════════════════════════════════════════
//  Order
// ═══════════════════════════════════════════

class Order {
  final String id;
  final List<OrderItem> items;
  final double deliveryFee;
  final OrderStatus status;
  final String time;
  final String? magasinId;
  String address;
  final String? driverName;
  final bool customerConfirmed;

  final String? driverId;
  final double? driverLat;
  final double? driverLng;
  final double? userLat;
  final double? userLng;
  final Map<String, dynamic>? counterOffer;
  final bool isFreeDelivery;

  Order({
    required this.id,
    required this.items,
    required this.deliveryFee,
    required this.status,
    required this.time,
    required this.address,
    this.driverName,
    this.customerConfirmed = false,
    this.magasinId,
    this.driverId,
    this.driverLat,
    this.driverLng,
    this.userLat,
    this.userLng,
    this.counterOffer,
    this.isFreeDelivery = false,
  });

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  double get total => subtotal + deliveryFee;

  bool get canEdit =>
      status == OrderStatus.pending || status == OrderStatus.accepted;

  bool get canCancel => status == OrderStatus.pending;

  bool get isAccepted =>
      status == OrderStatus.accepted ||
      status == OrderStatus.purchased ||
      status == OrderStatus.onway;
}

// ═══════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════

OrderStatus statusFromString(String s) {
  switch (s.toLowerCase().trim()) {
    case 'accepted':
      return OrderStatus.accepted;
    case 'purchased':
      return OrderStatus.purchased;
    case 'on_way':
    case 'onway':
      return OrderStatus.onway;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.pending;
  }
}

Widget statusBarGradient(BuildContext context) => const SizedBox.shrink();
