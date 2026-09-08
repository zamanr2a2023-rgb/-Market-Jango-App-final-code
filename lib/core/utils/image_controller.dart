import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

/// 1) Custom Cache config: TTL + max objects
class AppImageCache {
  static final CacheManager instance = CacheManager(
    Config(
      'my_app_images_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
      repo: JsonCacheInfoRepository(databaseName: 'my_app_images'),
      fileService: HttpFileService(),
    ),
  );
}

/// 2) Helper: logical px -> real px (DPR অনুযায়ী)
int? _cachePx(BuildContext context, double? logical) {
  if (logical == null) return null;
  if (!logical.isFinite) return null;
  final dpr = MediaQuery.of(context).devicePixelRatio;
  return (logical * dpr).round();
}

bool _isUsableNetworkImage(String url) {
  final u = url.trim();
  if (u.isEmpty) return false;
  if (!(u.startsWith('http://') || u.startsWith('https://'))) return false;
  // Flutter Android decoder often fails on these demo placeholders.
  if (u.contains('placehold.co')) return false;
  return true;
}

Widget _imageFallback({
  required double? width,
  required double? height,
}) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey.shade200,
    alignment: Alignment.center,
    child: Icon(
      Icons.image_outlined,
      size: height != null && height.isFinite && height < 100
          ? height * 0.4
          : 32,
      color: Colors.grey.shade400,
    ),
  );
}

/// 3) Smart widget: cache আছে কিনা দেখে তবে shimmer দেখায়
class FirstTimeShimmerImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const FirstTimeShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<FirstTimeShimmerImage> createState() => _FirstTimeShimmerImageState();
}

class _FirstTimeShimmerImageState extends State<FirstTimeShimmerImage> {
  late Future<bool> _isCachedFuture;

  Future<bool> _isCached(String url) async {
    try {
      final fileInfo = await AppImageCache.instance.getFileFromCache(url);
      return fileInfo != null && await fileInfo.file.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _isCachedFuture = _isCached(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant FirstTimeShimmerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _isCachedFuture = _isCached(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.zero;
    final url = widget.imageUrl.trim();

    if (!_isUsableNetworkImage(url)) {
      return ClipRRect(
        borderRadius: radius,
        child: _imageFallback(width: widget.width, height: widget.height),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<bool>(
        future: _isCachedFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            return _imageFallback(width: widget.width, height: widget.height);
          }
          final cached = snap.data == true;

          return CachedNetworkImage(
            imageUrl: url,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            cacheManager: AppImageCache.instance,
            placeholder: cached
                ? null
                : (context, _) => Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: widget.width,
                        height: widget.height,
                        color: Colors.white,
                      ),
                    ),
            fadeInDuration: cached
                ? Duration.zero
                : const Duration(milliseconds: 300),
            memCacheWidth: _cachePx(context, widget.width),
            memCacheHeight: _cachePx(context, widget.height),
            errorWidget: (context, _, __) => _imageFallback(
              width: widget.width,
              height: widget.height,
            ),
          );
        },
      ),
    );
  }
}
