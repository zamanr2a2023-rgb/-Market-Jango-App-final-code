import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/core/utils/product_image_downloader.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';

class CustomNewProduct extends StatefulWidget {
  const CustomNewProduct({
    super.key,
    this.width = 100,
    required this.height,
    this.imageHeight = 157,
    required this.productPrices,
    required this.productName,
    this.checking = false,
    this.onTap,
    this.isHighlighted = false,
    this.showDownloadButton = true,
    this.showAddToCartButton = false,
    this.onAddToCart,
    this.image =
        "https://t4.ftcdn.net/jpg/05/98/45/79/360_F_598457961_hojY3MEjPaYBgdUkfaWO6mPNuHce6WFv.jpg",
    this.viewCount,
  });

  final double width;
  final double height;
  final double imageHeight;
  final String productPrices;
  final String productName;
  final String image;
  final int? viewCount;
  final bool checking;
  final bool isHighlighted;
  final bool showDownloadButton;
  final bool showAddToCartButton;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  @override
  State<CustomNewProduct> createState() => _CustomNewProductState();
}

class _CustomNewProductState extends State<CustomNewProduct> {
  bool _downloading = false;

  Future<void> _downloadImage() async {
    if (_downloading) return;
    final url = widget.image.trim();
    if (url.isEmpty ||
        !(url.startsWith('http://') ||
            url.startsWith('https://') ||
            url.startsWith('data:image'))) {
      GlobalSnackbar.show(
        context,
        title: 'Download failed',
        message: 'Image not available',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _downloading = true);
    try {
      final result = await ProductImageDownloader.downloadAll([url]);
      if (!mounted) return;
      if (result.noneSaved) {
        GlobalSnackbar.show(
          context,
          title: 'Download failed',
          message: 'Could not save image',
          type: CustomSnackType.error,
        );
      } else {
        GlobalSnackbar.show(
          context,
          title: 'Downloaded',
          message: 'Photo saved to gallery',
          type: CustomSnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Download failed',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AllColor.loginButtomColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
          margin: EdgeInsets.symmetric(horizontal: 5.w),
          width: widget.width.w,
          height: widget.height.h,
          decoration: BoxDecoration(
            color: AllColor.white,
            borderRadius:
                BorderRadius.circular(widget.isHighlighted ? 12.r : 7.r),
            border: widget.isHighlighted
                ? Border.all(color: accent, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.isHighlighted
                    ? accent.withValues(alpha: 0.22)
                    : AllColor.black.withOpacity(0.06),
                blurRadius: widget.isHighlighted ? 14.r : 18.r,
                spreadRadius: 0,
                offset: Offset(0, widget.isHighlighted ? 6.h : 10),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                child: InkWell(
                  onTap: widget.onTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      widget.isHighlighted ? 10.r : 8.r,
                    ),
                    child: FirstTimeShimmerImage(
                      imageUrl: widget.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (widget.isHighlighted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withValues(alpha: 0.08),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.06),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.isHighlighted)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 11.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.viewCount != null)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          size: 12.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          widget.viewCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.showDownloadButton)
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _downloading ? null : _downloadImage,
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        width: 30.r,
                        height: 30.r,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _downloading
                            ? SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accent,
                                ),
                              )
                            : Icon(
                                Icons.download_rounded,
                                size: 16.sp,
                                color: AllColor.black,
                              ),
                      ),
                    ),
                  ),
                ),
              if (widget.showAddToCartButton && widget.onAddToCart != null)
                Positioned(
                  bottom: 6.h,
                  right: 6.w,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onAddToCart,
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        width: 32.r,
                        height: 32.r,
                        decoration: BoxDecoration(
                          color: AllColor.loginButtomColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 16.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 10.h, left: 15.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 3.h),
              Text(
                widget.productName.length < 12
                    ? widget.productName
                    : "${widget.productName.substring(0, 12)}...",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: widget.isHighlighted ? accent : AllColor.black,
                      fontWeight: widget.isHighlighted
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Text(
                widget.productPrices.length < 12
                    ? widget.productPrices
                    : "${widget.productPrices.substring(0, 12)}...",
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontSize: 18.sp,
                      color: widget.isHighlighted ? accent : AllColor.black,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
