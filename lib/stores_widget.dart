import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    return const Color(0xFF7D29C6);
  }
}

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
    const Color fixedPurple = Color(0xFF7D29C6);

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
                      index: index,
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

class _StoreItem extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool isSelected;
  final Color storeColor;
  final int index;
  final VoidCallback onTap;

  const _StoreItem({
    super.key,
    required this.name,
    required this.imagePath,
    required this.isSelected,
    required this.storeColor,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
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
                      ? _StoreImage(url: imagePath, index: index)
                      : const Icon(
                          Icons.store_rounded,
                          size: 24,
                          color: Color(0xFFB8B1C8),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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

/// Global semaphore limiting how many store-image loads run at once,
/// regardless of network speed. This is the ONLY throttling mechanism —
/// no guessed delays. Any image that fails (slow/dropped connection)
/// retries with backoff instead of giving up.
class _ImageLoadGate {
  static const int _maxConcurrent = 4; // stays under Android's 6-connection cap
  static int _active = 0;
  static final List<Completer<void>> _waiters = [];

  static Future<void> acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  static void release() {
    _active--;
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      _active++;
      next.complete();
    }
  }
}

class _StoreImage extends StatefulWidget {
  final String url;
  final int index;

  const _StoreImage({
    super.key,
    required this.url,
    required this.index,
  });

  @override
  State<_StoreImage> createState() => _StoreImageState();
}

class _StoreImageState extends State<_StoreImage> {
  bool _ready = false;
  bool _failed = false; // shown WHILE still retrying — never a permanent dead end

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Keeps retrying in the background for as long as this widget is mounted
  // (i.e. as long as it's visible in the list). Never gives up permanently —
  // no fixed attempt cap, so the user is never stuck needing a manual
  // pull-to-refresh just to get one stubborn image to load.
  Future<void> _load() async {
    int attempt = 0;
    while (mounted) {
      attempt++;
      // acquire/release around EACH attempt (not the whole retry loop) so a
      // slow-to-fail image doesn't hog a slot other images are waiting on
      await _ImageLoadGate.acquire();
      bool ok;
      try {
        ok = await _tryLoadOnce(attempt);
      } finally {
        _ImageLoadGate.release();
      }

      if (ok) {
        if (mounted) setState(() {
          _ready = true;
          _failed = false;
        });
        return;
      }

      if (mounted) setState(() => _failed = true);
      final backoffMs = (800 * attempt).clamp(800, 8000);
      await Future.delayed(Duration(milliseconds: backoffMs));
    }
  }

  Future<bool> _tryLoadOnce(int attempt) async {
    try {
      final provider = CachedNetworkImageProvider(widget.url);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<bool>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) {
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (_, __) {
          if (!completer.isCompleted) completer.complete(false);
        },
      );
      stream.addListener(listener);
      // timeout grows with each retry (slow network gets more slack) but
      // is capped so a stuck connection can't block a slot indefinitely
      final timeoutSecs = (10 + attempt * 5).clamp(10, 30);
      final result = await completer.future
          .timeout(Duration(seconds: timeoutSecs), onTimeout: () => false);
      stream.removeListener(listener);
      return result;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // _failed just means "a retry is pending in the background" — _load()
    // keeps looping regardless, so this is never a permanent dead end
    if (_failed || !_ready) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CupertinoActivityIndicator(radius: 10),
      );
    }
    // by now the image is guaranteed to already be in CachedNetworkImage's
    // cache, so this resolves instantly with no extra network request
    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      width: 42,
      height: 42,
      memCacheWidth: 120,
      placeholder: (_, __) => const SizedBox(
        width: 24,
        height: 24,
        child: CupertinoActivityIndicator(radius: 10),
      ),
      errorWidget: (_, __, ___) => const Icon(
        Icons.store_rounded,
        size: 24,
        color: Color(0xFFB8B1C8),
      ),
    );
  }
}