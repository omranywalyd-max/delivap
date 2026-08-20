# مشكلة صور المحلات

## المشكلة
فاش تفتح التطبيق أول مرة صور المحلات ما تظهرش (يبان Icons.store_rounded). بعد pull-to-refresh تبان.

## السبب
Android عندو حد 6 اتصالات متزامنة لنفس السيرفر. المحلات 19 كلهم بائين فالشاشة (58px, ListView أفقي). 19 CachedNetworkImage يحاولو يتحملو ف نفس الوقت → 6 ينجحو 13 يطيحو timeout.

المنتجات تتحمل عادي راه غير 3-4 باينين فالشاشة (100px, ListView عمودي).

## الحل
كل صورة تبدأ تتحمل بعد تأخير (index × 200ms + 100ms) + sequential pre-cache فالخلفية.

## الكود الحالي (عندو المشكلة)
`lib/stores_widget.dart`:

```dart
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
```

## الكود الجديد (الحل)

- نضيفو `_StoreImage` (StatefulWidget مع staggered delay)
- نضيفو `_precacheAllSequential` (تحميل الصور فالخلفية واحد ورا الثاني)
- نمررو `index` لـ `_StoreItem`

`_StoreImage`:
```dart
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
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 200 + 100), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CupertinoActivityIndicator(radius: 10),
      );
    }
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
```

نضيفو فـ `_StoresWidgetState`:
```dart
void _precacheAllSequential() {
  final urls = widget.stores
      .map((s) => (s as Map<String, dynamic>)['image'] as String? ?? '')
      .where((u) => u.isNotEmpty)
      .toList();
  if (urls.isNotEmpty) {
    unawaited(_precacheOneByOne(urls));
  }
}

Future<void> _precacheOneByOne(List<String> urls) async {
  for (final url in urls) {
    try {
      final provider = CachedNetworkImageProvider(url);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<void>();
      final listener = ImageStreamListener(
        (_, __) { if (!completer.isCompleted) completer.complete(); },
        onError: (_, __) { if (!completer.isCompleted) completer.complete(); },
      );
      stream.addListener(listener);
      await completer.future.timeout(const Duration(seconds: 15));
      stream.removeListener(listener);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 150));
  }
}
```

ونضيفو `import 'dart:async';` فالتوب.

## كود السيرفر (upload.js)
`C:\server\routes\upload.js`:

```javascript
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');

const storage = multer.diskStorage({
  destination: './uploads/',
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${uuidv4()}${ext}`);
  }
});

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_SIZE = 25 * 1024 * 1024;

const fileFilter = (req, file, cb) => {
  if (ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`نوع الملف غير مسموح: ${file.mimetype}. الأنواع المسموحة: JPG, PNG, WebP, GIF`));
  }
};

const upload = multer({ storage, fileFilter, limits: { fileSize: MAX_SIZE } });

const MAX_WIDTH = 1200;
const QUALITY = 80;

router.post('/upload', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const base = process.env.BASE_URL || 'http://localhost:3000';
  const origPath = req.file.path;
  const origSize = req.file.size;
  try {
    const ext = path.extname(req.file.filename).toLowerCase();
    const isGif = ext === '.gif';
    if (!isGif) {
      const webpName = req.file.filename.replace(/\.[^.]+$/, '.webp');
      const webpPath = path.join(req.file.destination, webpName);
      const meta = await sharp(origPath).metadata();
      let pipeline = sharp(origPath).webp({ quality: QUALITY });
      if (meta.width && meta.width > MAX_WIDTH) {
        pipeline = pipeline.resize({ width: MAX_WIDTH, withoutEnlargement: true });
      }
      await pipeline.toFile(webpPath);
      fs.unlinkSync(origPath);
      const newSize = fs.statSync(webpPath).size;
      const ratio = Math.round((1 - newSize / origSize) * 100);
      console.log(`Compressed: ${origSize} -> ${newSize} (${ratio}% smaller)`);
      const url = `${base}/uploads/${webpName}`;
      return res.json({ url, filename: webpName, compressed: true, originalSize: origSize, newSize });
    }
    const url = `${base}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename, compressed: false });
  } catch (err) {
    console.error('Image compression error:', err.message);
    const url = `${base}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename, compressed: false });
  }
});

router.delete('/upload/:filename', (req, res) => {
  try {
    const filePath = path.join(__dirname, '..', 'uploads', req.params.filename);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      res.json({ deleted: true });
    } else {
      res.status(404).json({ error: 'الملف غير موجود' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
```
