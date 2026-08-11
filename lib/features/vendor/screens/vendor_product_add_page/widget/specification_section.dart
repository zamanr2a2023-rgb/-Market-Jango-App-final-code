import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';

/// Editable custom specs → API `specifications` (string map).
/// Example: material → 95  ⇒  {"material":"95"}.
class SpecificationSection extends ConsumerStatefulWidget {
  const SpecificationSection({super.key});

  @override
  ConsumerState<SpecificationSection> createState() =>
      _SpecificationSectionState();
}

class _SpecificationSectionState extends ConsumerState<SpecificationSection> {
  final _keyC = TextEditingController();
  final _valueC = TextEditingController();
  static const _lblColor = Color(0xFF436AA0);
  static const _hintColor = Color(0xFF95A6C4);

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(5.r),
        borderSide: BorderSide(color: AllColor.grey, width: 1.2),
      );

  @override
  void dispose() {
    _keyC.dispose();
    _valueC.dispose();
    super.dispose();
  }

  void _addPair() {
    final key = _keyC.text.trim();
    final value = _valueC.text.trim();
    if (key.isEmpty || value.isEmpty) return;
    final current =
        Map<String, String>.from(ref.read(productSpecificationProvider));
    current[key] = value;
    ref.read(productSpecificationProvider.notifier).state = current;
    _keyC.clear();
    _valueC.clear();
  }

  @override
  Widget build(BuildContext context) {
    final specs = ref.watch(productSpecificationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specification',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _lblColor,
          ),
        ),
        SizedBox(height: 6.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _keyC,
                decoration: InputDecoration(
                  hintText: 'Name (e.g. Cotton)',
                  hintStyle: TextStyle(fontSize: 13.sp, color: _hintColor),
                  fillColor: AllColor.white,
                  enabledBorder: _border(),
                  focusedBorder: _border(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _valueC,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Value (e.g. 95)',
                  hintStyle: TextStyle(fontSize: 13.sp, color: _hintColor),
                  fillColor: AllColor.white,
                  enabledBorder: _border(),
                  focusedBorder: _border(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                ),
                onSubmitted: (_) => _addPair(),
              ),
            ),
            SizedBox(width: 8.w),
            SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed: _addPair,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AllColor.loginButtomColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ),
          ],
        ),
        if (specs.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: specs.entries.map((e) {
              return Chip(
                label: Text(
                  '${e.key}: ${e.value}',
                  style: TextStyle(fontSize: 12.sp),
                ),
                deleteIcon: Icon(Icons.close, size: 16.sp),
                onDeleted: () {
                  final next = Map<String, String>.from(
                    ref.read(productSpecificationProvider),
                  );
                  next.remove(e.key);
                  ref.read(productSpecificationProvider.notifier).state = next;
                },
                backgroundColor: Colors.white,
                side: BorderSide(color: AllColor.grey),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
