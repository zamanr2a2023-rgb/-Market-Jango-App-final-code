import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/vendor/screens/product_edit/model/product_attribute_response_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';

class GenericAttributePicker extends ConsumerStatefulWidget {
  const GenericAttributePicker({super.key, required this.attributes});

  final List<VendorProductAttribute> attributes;

  @override
  ConsumerState<GenericAttributePicker> createState() =>
      _GenericAttributePickerState();
}

class _GenericAttributePickerState
    extends ConsumerState<GenericAttributePicker> {
  void _addAttribute(String attrName) {
    final current =
        Map<String, List<String>>.from(ref.read(selectedAttributesProvider));
    if (current.containsKey(attrName)) return;
    current[attrName] = [];
    ref.read(selectedAttributesProvider.notifier).state = current;
  }

  void _removeAttribute(String attrName) {
    final current =
        Map<String, List<String>>.from(ref.read(selectedAttributesProvider));
    current.remove(attrName);
    ref.read(selectedAttributesProvider.notifier).state = current;
  }

  @override
  Widget build(BuildContext context) {
    final selectedAttributes = ref.watch(selectedAttributesProvider);
    final selectedAttrNames = selectedAttributes.keys.toSet();
    final availableAttributes = widget.attributes
        .where((attr) => !selectedAttrNames.contains(attr.name.toLowerCase()))
        .toList();
    final selectedAttrList = selectedAttributes.entries.toList();

    if (selectedAttrList.isEmpty) {
      return _AttributeDropdown(
        availableAttributes: availableAttributes,
        onSelected: _addAttribute,
      );
    }

    // Pair selected attributes into rows of 2 (supports more than two).
    final rows = <List<MapEntry<String, List<String>>>>[];
    for (var i = 0; i < selectedAttrList.length; i += 2) {
      rows.add(
        selectedAttrList.sublist(
          i,
          i + 2 > selectedAttrList.length ? selectedAttrList.length : i + 2,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardHeader(
                          label: _getAttributeDisplayName(row[i].key),
                          onRemove: () => _removeAttribute(row[i].key),
                        ),
                        SizedBox(height: 10.h),
                        _AttributeValuePicker(
                          attributeName: row[i].key,
                          selectedValues: row[i].value,
                          attributes: widget.attributes,
                        ),
                      ],
                    ),
                  ),
                ],
                // Keep layout balanced when odd count on last row.
                if (row.length == 1) ...[
                  SizedBox(width: 14.w),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),
        ],
        if (availableAttributes.isNotEmpty)
          _AttributeDropdown(
            availableAttributes: availableAttributes,
            hintText: 'Add another attribute',
            onSelected: _addAttribute,
          ),
      ],
    );
  }

  String _getAttributeDisplayName(String key) {
    final attr = widget.attributes.firstWhere(
      (a) => a.name.toLowerCase() == key,
      orElse: () => VendorProductAttribute(
        id: 0,
        name: key,
        vendorId: 0,
        attributeValues: [],
      ),
    );
    return 'Select ${attr.name}';
  }
}

/// Dropdown widget for selecting an attribute
class _AttributeDropdown extends StatelessWidget {
  const _AttributeDropdown({
    required this.availableAttributes,
    required this.onSelected,
    this.hintText = 'Select Attribute',
  });

  final List<VendorProductAttribute> availableAttributes;
  final ValueChanged<String> onSelected;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final ThemeData dropTheme = ThemeData(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

    return Theme(
      data: dropTheme,
      child: Container(
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: AllColor.white,
          borderRadius: BorderRadius.circular(5.r),
          border: Border.all(color: AllColor.grey),
          boxShadow: [
            BoxShadow(
              blurRadius: 14.r,
              offset: Offset(0, 6.h),
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: null,
            hint: Text(
              hintText,
              style: TextStyle(fontSize: 15.sp, color: Colors.grey),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            style: TextStyle(fontSize: 15.sp, color: Colors.black87),
            items: availableAttributes.map((attr) {
              return DropdownMenuItem(
                value: attr.name.toLowerCase(),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Text(attr.name),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Widget to display and select attribute values
class _AttributeValuePicker extends ConsumerWidget {
  const _AttributeValuePicker({
    required this.attributeName,
    required this.selectedValues,
    required this.attributes,
  });

  final String attributeName;
  final List<String> selectedValues;
  final List<VendorProductAttribute> attributes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attr = attributes.firstWhere(
      (a) => a.name.toLowerCase() == attributeName,
      orElse: () => VendorProductAttribute(
        id: 0,
        name: attributeName,
        vendorId: 0,
        attributeValues: [],
      ),
    );
    final availableValues = attr.attributeValues.map((v) => v.name).toList();

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: availableValues.map((value) {
        final isSelected = selectedValues.contains(value);
        return GestureDetector(
          onTap: () {
            final selectedAttributes = ref.read(selectedAttributesProvider);
            final current = Map<String, List<String>>.from(selectedAttributes);
            final currentValues = List<String>.from(
              current[attributeName] ?? [],
            );

            if (isSelected) {
              currentValues.remove(value);
            } else {
              currentValues.add(value);
            }

            if (currentValues.isEmpty) {
              current.remove(attributeName);
            } else {
              current[attributeName] = currentValues;
            }

            ref.read(selectedAttributesProvider.notifier).state = current;
          },
          child: _ValueChip(label: value, selected: isSelected),
        );
      }).toList(),
    );
  }
}

/// Header box (same design as color/size)
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.label, this.onRemove});
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.only(left: 14.w, right: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF444444),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18.sp, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

/// Value Chip (same design as color/size chips)
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A7CFF) : const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A7CFF).withValues(alpha: 0.35),
                    blurRadius: 10.r,
                    offset: Offset(0, 3.h),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF4A7CFF),
          ),
        ),
      ),
    );
  }
}
