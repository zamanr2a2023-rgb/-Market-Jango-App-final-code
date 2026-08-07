import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/generate_product_title_api.dart';

/// Button that calls AI generate-image and returns a local [File].
class AiGenerateImageButton extends StatefulWidget {
  const AiGenerateImageButton({
    super.key,
    required this.title,
    required this.description,
    required this.onImageGenerated,
    this.resolveTitle,
    this.resolveDescription,
    this.category,
    this.resolveCategory,
    this.productId,
    this.label = 'Generate image',
  });

  final String title;
  final String description;
  final String Function()? resolveTitle;
  final String Function()? resolveDescription;
  final String? category;
  final String Function()? resolveCategory;
  final int? productId;
  final String label;
  final ValueChanged<File> onImageGenerated;

  @override
  State<AiGenerateImageButton> createState() => _AiGenerateImageButtonState();
}

class _AiGenerateImageButtonState extends State<AiGenerateImageButton> {
  bool _loading = false;

  Future<void> _generate() async {
    if (_loading) return;
    final currentTitle =
        (widget.resolveTitle?.call() ?? widget.title).trim();
    if (currentTitle.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Validation Error',
        message: 'Please enter a product title first',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final file = await GenerateProductImageApi.generate(
        title: currentTitle,
        description:
            widget.resolveDescription?.call() ?? widget.description,
        category: widget.resolveCategory?.call() ?? widget.category,
        productId: widget.productId,
      );
      if (!mounted) return;
      widget.onImageGenerated(file);
      GlobalSnackbar.show(
        context,
        title: 'Success',
        message: 'Image generated',
      );
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _loading ? null : _generate,
        icon: _loading
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AllColor.loginButtomColor,
                ),
              )
            : Icon(
                Icons.auto_awesome,
                size: 18.sp,
                color: AllColor.loginButtomColor,
              ),
        label: Text(
          _loading ? 'Generating...' : widget.label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AllColor.loginButtomColor,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
