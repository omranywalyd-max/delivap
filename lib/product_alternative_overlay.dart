import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Services/api_client.dart';
import 'user_local.dart';

class ProductAlternativeOverlay extends StatefulWidget {
  final String orderId;
  final String driverName;
  final String productName;
  final double productPrice;
  final String alternativeName;
  final double alternativePrice;
  final VoidCallback onRefresh;

  const ProductAlternativeOverlay({
    super.key,
    required this.orderId,
    required this.driverName,
    required this.productName,
    required this.productPrice,
    required this.alternativeName,
    required this.alternativePrice,
    required this.onRefresh,
  });

  @override
  State<ProductAlternativeOverlay> createState() => _ProductAlternativeOverlayState();
}

class _ProductAlternativeOverlayState extends State<ProductAlternativeOverlay> {
  Timer? _timer;
  int _remainingSeconds = 120;
  bool _loading = false;
  bool _responded = false;

  static const _kPrimary = Color(0xFF7D29C6);
  static const _kSecondary = Color(0xFF9232E8);
  static const _kCard = Color(0xFFDCDAE6);
  static const _kText = Color(0xFF2D2A3A);
  static final _kNeumLight = Color(0xFFB8B1C8).withOpacity(0.6);
  static final _kNeumShadow = Color(0xFFB8B1C8).withOpacity(0.6);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _autoReject();
        }
      });
    });
  }

  Future<void> _autoReject() async {
    if (_responded) return;
    _responded = true;
    await _respond(false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _respond(bool accepted) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final uid = UserLocal.uid;
      if (uid == null) return;

      final orderData = await ApiClient.get('/api/orders/${widget.orderId}');
      final List items = List.from(orderData['items'] as List? ?? []);
      final idx = items.indexWhere(
        (i) => i['name'] == widget.productName && i['purchaseStatus'] == 'unavailable',
      );
      if (idx == -1) return;

      if (accepted) {
        items[idx]['alternativeStatus'] = 'accepted';
        items[idx]['purchaseStatus'] = 'purchased';
        items[idx]['finalPrice'] = items[idx]['alternativePrice'];
      } else {
        items[idx]['alternativeStatus'] = 'rejected';
      }

      double newSubtotal = items.fold(0.0, (sum, item) {
        final ps = item['purchaseStatus'] as String? ?? '';
        if (ps == 'unavailable') return sum;
        final p = (item['finalPrice'] ?? item['price'] ?? item['prix'] ?? 0.0) as num;
        final q = (item['quantity'] ?? 1) as int;
        return sum + p.toDouble() * q;
      });

      await ApiClient.put('/api/orders/${widget.orderId}', {
        'items': items,
        'subtotal': newSubtotal,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      widget.onRefresh();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final timerColor = _remainingSeconds <= 30 ? Colors.red : Colors.orange;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: _kNeumShadow, blurRadius: 16, offset: const Offset(4, 4)),
              BoxShadow(color: _kNeumLight, blurRadius: 16, offset: const Offset(-4, -4)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag, color: _kPrimary, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'لم يجد "${widget.productName}" بسعر ${widget.productPrice.toInt()} DZD',
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 13,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'راهم ارسلك منتج بديل',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.photo, color: Colors.grey, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.alternativeName,
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _kText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.alternativePrice.toInt()} DZD',
                                style: const TextStyle(
                                  fontFamily: 'Amiri',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: timerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: timerColor),
                      const SizedBox(width: 6),
                      Text(
                        '$minutes:$seconds',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
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
                        onTap: _loading || _responded ? null : () async {
                          _responded = true;
                          await _respond(true);
                          if (mounted) Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9232E8), Color(0xFF7D29C6)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _kPrimary.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    'قبول',
                                    style: TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _loading || _responded ? null : () async {
                          _responded = true;
                          await _respond(false);
                          if (mounted) Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFC62828)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    'رفض',
                                    style: TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 16,
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
      ),
    );
  }
}

class ProductAlternativeOverlayHelper {
  static bool get isEnabled => true;

  static void show({
    required BuildContext context,
    required String orderId,
    required String driverName,
    required String productName,
    required double productPrice,
    required String alternativeName,
    required double alternativePrice,
    required VoidCallback onRefresh,
  }) {
    if (!isEnabled) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductAlternativeOverlay(
        orderId: orderId,
        driverName: driverName,
        productName: productName,
        productPrice: productPrice,
        alternativeName: alternativeName,
        alternativePrice: alternativePrice,
        onRefresh: onRefresh,
      ),
    );
  }
}
