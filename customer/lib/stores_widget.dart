// ══════════════════════════════════════════════════════════════════════════════
//  stores_widget.dart — نسخة متناسقة مع الستايل البنفسجي البارد
// ══════════════════════════════════════════════════════════════════════════════

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  StoreColorCache — كاش ألوان المحلات
// ══════════════════════════════════════════════════════════════════════════════
class StoreColorCache {
  static final Map<String, Color> _colors = {};
  static const int _maxEntries = 50;

  static Color? get(String storeId) => _colors[storeId];
  static void set(String storeId, Color color) {
    if (_colors.length >= _maxEntries) {
      _colors.remove(_colors.keys.first);
    }
    _colors[storeId] = color;
  }
  static bool has(String storeId) => _colors.containsKey(storeId);

  static Color fromHex(String hex) {
    final h = hex.replaceAll('#', '').trim();
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    } else if (h.length == 8) {
      return Color(int.parse(h, radix: 16));
    }
    return const Color(0xFF7D29C6); // fallback بنفسجي
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  StoresWidget — قائمة المحلات الأفقية
// ══════════════════════════════════════════════════════════════════════════════
class StoresWidget extends StatefulWidget {
  final List<dynamic> stores;
  final String? selectedStoreId;
  final Function(String) onStoreSelected;

  const StoresWidget({
    super.key,
    required this.stores,
    required this.selectedStoreId,
    required this.onStoreSelected,
  });

  @override
  State<StoresWidget> createState() => _StoresWidgetState();
}

class _StoresWidgetState extends State<StoresWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  static final Map<String, _StoreItemData> _storeDataCache = {};
  static const int _maxStoreCache = 50;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _staggerController.forward();
    _cacheColors();
  }

  @override
  void didUpdateWidget(covariant StoresWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stores.isNotEmpty && oldWidget.stores.isEmpty) {
      _staggerController.forward(from: 0.0);
      _cacheColors();
    }
  }

 void _cacheColors() {
  const Color fixedPurple = Color(0xFF7D29C6); // اللون البنفسجي الموحد
  
  for (final store in widget.stores) {
    final d = store as Map<String, dynamic>;
    final storeId = d['_id'] as String? ?? d['id'] as String? ?? '';
    
    StoreColorCache.set(storeId, fixedPurple);

    if (_storeDataCache.length >= _maxStoreCache) {
      _storeDataCache.remove(_storeDataCache.keys.first);
    }
    _storeDataCache[storeId] = _StoreItemData(
      name: d['nom'] as String? ?? '',
      imagePath: d['image'] as String? ?? '',
      color: fixedPurple,
    );
  }
}

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stores.isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: widget.stores.length,
          cacheExtent: 1500,
          itemBuilder: (context, index) {
            final store = widget.stores[index] as Map<String, dynamic>;
            final String storeId = store['_id'] as String? ?? store['id'] as String? ?? '';
            final bool isSelected = widget.selectedStoreId == storeId;

            final data = _storeDataCache[storeId];
            final String name = data?.name ?? '';
            final String imagePath = data?.imagePath ?? '';
            final Color storeColor = data?.color ?? const Color(0xFF7D29C6);

            final double start = (index * 0.04).clamp(0.0, 0.8);
            final double end = (start + 0.35).clamp(0.0, 1.0);

            return RepaintBoundary(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _staggerController,
                  curve: Interval(start, end, curve: Curves.easeOut),
                ),
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _staggerController,
                          curve: Interval(
                            start,
                            end,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _StoreItem(
                      name: name,
                      imagePath: imagePath,
                      isSelected: isSelected,
                      storeColor: storeColor,
                      onTap: () => widget.onStoreSelected(storeId),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoreItemData {
  final String name;
  final String imagePath;
  final Color color;
  const _StoreItemData({
    required this.name,
    required this.imagePath,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  _StoreItem — النسخة المعدلة (لون الحلقة من الفايربيز + نص أسود)
// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════
//  _StoreItem — النسخة المعدلة (لون الحلقة بنفسجي دائماً + نص أسود)
// ══════════════════════════════════════════════════════════════════════════════
class _StoreItem extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool isSelected;
  final Color storeColor; // هذا سيبقى بنفسجياً دائماً الآن
  final VoidCallback onTap;

  const _StoreItem({
    super.key,
    required this.name,
    required this.imagePath,
    required this.isSelected,
    required this.storeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ اللون البنفسجي الأساسي للتطبيق
    const Color fixedPurple = Color(0xFF7D29C6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── الحلقة البنفسجية المثبتة ──────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  // ✅ تم تثبيت اللون هنا: بنفسجي عند الاختيار، ورمادي باهت عند عدمه
                  color: isSelected
                      ? fixedPurple
                      : const Color(0xFFB8B1C8).withOpacity(0.3),
                  width: isSelected ? 3.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: fixedPurple.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.transparent,
                  child: imagePath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imagePath,
                          fit: BoxFit.contain,
                          memCacheWidth: 120,
                          placeholder: (_, __) => const Center(
                            child: CupertinoActivityIndicator(radius: 10),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.store_rounded,
                            size: 24,
                            color: Color(0xFFB8B1C8),
                          ),
                        )
                      : const Icon(
                          Icons.store_rounded,
                          size: 24,
                          color: Color(0xFFB8B1C8),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── اسم المحل باللون الأسود ─────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.black54,
                fontSize: 10.5,
                fontFamily: 'Amiri',
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
              child: Text(name, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
