import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int memCacheWidth;
  final int memCacheHeight;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth = 320,
    this.memCacheHeight = 320,
    this.borderRadius,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _placeholder();
    }
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => fallback ?? _placeholder(),
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: const Center(
        child: CupertinoActivityIndicator(radius: 10),
      ),
    );
  }
}

const int _batchSize = 10;

Future<void> precacheImages(List<String> urls) async {
  final valid = urls.where((u) => u.isNotEmpty).toList();
  for (var i = 0; i < valid.length; i += _batchSize) {
    final batch = valid.sublist(i, (i + _batchSize).clamp(0, valid.length));
    await Future.wait(batch.map(_precacheOne));
  }
}

Future<void> _precacheOne(String url) async {
  try {
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<void>();
    final listener = ImageStreamListener(
      (_, __) { if (!completer.isCompleted) completer.complete(); },
      onError: (_, __) { if (!completer.isCompleted) completer.complete(); },
    );
    stream.addListener(listener);
    await completer.future.timeout(const Duration(seconds: 10));
    stream.removeListener(listener);
  } catch (_) {}
}
