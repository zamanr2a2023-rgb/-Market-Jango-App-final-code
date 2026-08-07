import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/generate_product_title_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';

/// Toggle button + keywords field that fills [onTitleGenerated] via AI API.
class AiGenerateTitleSection extends ConsumerStatefulWidget {
  const AiGenerateTitleSection({
    super.key,
    required this.onTitleGenerated,
    this.productId,
    this.labelColor = const Color(0xFF436AA0),
  });

  final ValueChanged<String> onTitleGenerated;
  final int? productId;
  final Color labelColor;

  @override
  ConsumerState<AiGenerateTitleSection> createState() =>
      _AiGenerateTitleSectionState();
}

class _AiGenerateTitleSectionState
    extends ConsumerState<AiGenerateTitleSection> {
  late final TextEditingController _keywordsC;
  bool _showKeywords = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _keywordsC = TextEditingController(
      text: ref.read(productKeywordsProvider),
    );
  }

  @override
  void dispose() {
    _keywordsC.dispose();
    super.dispose();
  }

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(5.r),
        borderSide: BorderSide(color: AllColor.grey, width: 1.2),
      );

  void _syncKeywords(String value) {
    ref.read(productKeywordsProvider.notifier).state = value.trim();
  }

  Future<void> _generate() async {
    if (_loading) return;
    final keywords = _keywordsC.text.trim();
    if (keywords.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Validation Error',
        message: 'Please enter keywords',
        type: CustomSnackType.error,
      );
      return;
    }

    _syncKeywords(keywords);
    setState(() => _loading = true);
    try {
      final title = await GenerateProductTitleApi.generate(
        keywords: keywords,
        productId: widget.productId,
      );
      if (!mounted) return;
      widget.onTitleGenerated(title);
      GlobalSnackbar.show(
        context,
        title: 'Success',
        message: 'Title generated',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _showKeywords = !_showKeywords),
            icon: Icon(
              _showKeywords ? Icons.close : Icons.auto_awesome,
              size: 18.sp,
              color: AllColor.loginButtomColor,
            ),
            label: Text(
              _showKeywords ? 'Hide keywords' : 'Generate title',
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
        ),
        if (_showKeywords) ...[
          SizedBox(height: 6.h),
          Text(
            'Keywords',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: widget.labelColor,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _keywordsC,
                  textInputAction: TextInputAction.done,
                  onChanged: _syncKeywords,
                  onFieldSubmitted: (_) => _generate(),
                  style: TextStyle(fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter product keywords',
                    fillColor: AllColor.white,
                    enabledBorder: _border(),
                    focusedBorder: _border(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _loading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AllColor.loginButtomColor,
                    foregroundColor: AllColor.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Go',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}
