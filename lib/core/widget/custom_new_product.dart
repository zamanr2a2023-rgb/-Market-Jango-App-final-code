import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/image_controller.dart';

class CustomNewProduct extends StatelessWidget {
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
  final int? viewCount; // number of views

  final bool checking;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AllColor.loginButtomColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
          margin: EdgeInsets.symmetric(horizontal: 5.w),
          width: width.w,
          height: height.h,
          decoration: BoxDecoration(
            color: AllColor.white,
            borderRadius: BorderRadius.circular(isHighlighted ? 12.r : 7.r),
            border: isHighlighted
                ? Border.all(color: accent, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? accent.withValues(alpha: 0.22)
                    : AllColor.black.withOpacity(0.06),
                blurRadius: isHighlighted ? 14.r : 18.r,
                spreadRadius: 0,
                offset: Offset(0, isHighlighted ? 6.h : 10),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(isHighlighted ? 10.r : 8.r),
                  child: SizedBox.expand(
                    child: FirstTimeShimmerImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (isHighlighted)
                  Positioned.fill(
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
                if (isHighlighted)
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
                // View count overlay - always show if viewCount is not null
                if (viewCount != null)
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
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
                            viewCount.toString(),
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
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 10.h, left: 15.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 3.h),
              Text(
                productName.length < 12
                    ? productName
                    : "${productName.substring(0, 12)}...",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: isHighlighted ? accent : AllColor.black,
                      fontWeight:
                          isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 10.h),
              Text(
                productPrices.length < 12
                    ? productPrices
                    : "${productPrices.substring(0, 12)}...",
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontSize: 18.sp,
                      color: isHighlighted ? accent : AllColor.black,
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
