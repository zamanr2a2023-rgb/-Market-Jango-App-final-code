import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/generate_product_title_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';

/// Generates description using the same Keywords from the title section.
class AiGenerateDescriptionSection extends ConsumerStatefulWidget {
  const AiGenerateDescriptionSection({
    super.key,
    required this.title,
    required this.onDescriptionGenerated,
    this.resolveTitle,
    this.category,
    this.resolveCategory,
    this.productId,
    this.labelColor = const Color(0xFF436AA0),
  });

  final String title;
  final String Function()? resolveTitle;
  final String? category;
  final String Function()? resolveCategory;
  final ValueChanged<String> onDescriptionGenerated;
  final int? productId;
  final Color labelColor;

  @override
  ConsumerState<AiGenerateDescriptionSection> createState() =>
      _AiGenerateDescriptionSectionState();
}

class _AiGenerateDescriptionSectionState
    extends ConsumerState<AiGenerateDescriptionSection> {
  bool _loading = false;

  List<String> _featuresFromKeywords(String raw) {
    final parts = raw
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts;
    final single = raw.trim();
    return single.isEmpty ? <String>[] : <String>[single];
  }

  Future<void> _generate() async {
    if (_loading) return;

    final currentTitle =
        (widget.resolveTitle?.call() ?? widget.title).trim();
    if (currentTitle.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Validation Error',
        message: 'Please enter or generate a product title first',
        type: CustomSnackType.error,
      );
      return;
    }

    final keywords = ref.read(productKeywordsProvider).trim();
    final features = _featuresFromKeywords(keywords);
    if (features.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Validation Error',
        message: 'Please enter keywords under Product Title first',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await GenerateProductDescriptionApi.generate(
        title: currentTitle,
        keyFeatures: features,
        category: widget.resolveCategory?.call() ?? widget.category,
        productId: widget.productId,
      );
      if (!mounted) return;
      widget.onDescriptionGenerated(result.description);
      GlobalSnackbar.show(
        context,
        title: 'Success',
        message: 'Description generated',
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
          _loading ? 'Generating...' : 'Generate description',
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
