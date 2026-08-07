import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/core/widget/global_save_botton.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/product_edit/data/product_attribute_data.dart';
import 'package:market_jango/features/vendor/screens/product_edit/logic/delete_image_riverpod.dart';
import 'package:market_jango/features/vendor/screens/product_edit/logic/update_product_riverpod.dart';
import 'package:market_jango/features/vendor/screens/vendor_home/data/vendor_product_data.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/vendor_product_create_categories.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/widget/ai_generate_description_section.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/widget/ai_generate_image_button.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/widget/ai_generate_title_section.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/widget/generic_attribute_picker.dart';

import '../../../widgets/custom_back_button.dart';
import '../../vendor_home/model/vendor_product_model.dart';

class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, required this.product});

  final VendorProduct product;

  static const String routeName = '/vendor_product_edit';

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  int? _selectedBusinessTypeId;
  int? _selectedCategoryId;
  List<File> _newFiles = [];
  String _weightUnit = 'kg';
  String _dimensionUnit = 'cm';

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(vendorProductCreateCategoriesProvider);
    final attributeAsync = ref.watch(productAttributesProvider);
    final saving = ref.watch(updateProductProvider).isLoading;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 439.h,
                      width: double.maxFinite,
                      child: mainImage != null
                          ? Image.file(mainImage!, fit: BoxFit.cover)
                          : FirstTimeShimmerImage(
                              imageUrl: widget.product.image,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      bottom: 15,
                      right: 15,
                      child: GestureDetector(
                        onTap: () {
                          _askImageSource(isMain: true);
                        },
                        child: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(top: 50, left: 30, child: CustomBackButton()),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 15.h),
                  // ProductEditScreen এর ভিতরে
                  ProductImageCarousel(
                    product: widget.product,
                    onLocalAddedChanged: (files) {
                      setState(() => _newFiles = files);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AiGenerateImageButton(
                      productId: widget.product.id,
                      title: nameController.text,
                      description: descriptionController.text,
                      category: widget.product.categoryName,
                      resolveTitle: () => nameController.text,
                      resolveDescription: () => descriptionController.text,
                      label: 'Generate cover image',
                      onImageGenerated: (file) {
                        setState(() => mainImage = file);
                      },
                    ),
                  ),
                  SizedBox(height: 10.h),

                  /// Business Type + Category (from `GET /vendor/product-categories`)
                  categoryAsync.when(
                    data: (result) {
                      if (result.categories.isEmpty) {
                        return const Text('No categories available');
                      }

                      final businessTypes = result.businessTypes;

                      // Prefer the product's existing category when initializing.
                      final productCategory = result.categories
                          .where(
                            (c) =>
                                c.id == widget.product.categoryId ||
                                c.name == widget.product.categoryName,
                          )
                          .toList();

                      int? validTypeId = _selectedBusinessTypeId;
                      if (validTypeId == null && productCategory.isNotEmpty) {
                        validTypeId = productCategory.first.businessTypeId;
                      }
                      if (businessTypes.isNotEmpty &&
                          (validTypeId == null ||
                              !businessTypes.any((t) => t.id == validTypeId))) {
                        validTypeId = businessTypes.first.id;
                      }

                      final visibleCategories = validTypeId == null
                          ? result.categories
                          : result.categories
                              .where((c) => c.businessTypeId == validTypeId)
                              .toList();

                      int? validCategoryId = _selectedCategoryId;
                      if (validCategoryId == null &&
                          productCategory.isNotEmpty &&
                          visibleCategories
                              .any((c) => c.id == productCategory.first.id)) {
                        validCategoryId = productCategory.first.id;
                      }
                      if (visibleCategories.isEmpty) {
                        validCategoryId = null;
                      } else if (validCategoryId == null ||
                          !visibleCategories
                              .any((c) => c.id == validCategoryId)) {
                        validCategoryId = visibleCategories.first.id;
                      }

                      if (validTypeId != _selectedBusinessTypeId ||
                          validCategoryId != _selectedCategoryId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selectedBusinessTypeId = validTypeId;
                            _selectedCategoryId = validCategoryId;
                          });
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (businessTypes.isNotEmpty) ...[
                            _Label('Business Type',
                                color: const Color(0xFF436AA0)),
                            SizedBox(height: 6.h),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: validTypeId,
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                              ),
                              hint: const Text('Select Business Type'),
                              items: businessTypes.map((t) {
                                return DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(t.name),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                final firstCat = result.categories
                                    .where((c) => c.businessTypeId == v)
                                    .toList();
                                setState(() {
                                  _selectedBusinessTypeId = v;
                                  _selectedCategoryId = firstCat.isEmpty
                                      ? null
                                      : firstCat.first.id;
                                });
                              },
                            ),
                            SizedBox(height: 12.h),
                          ],
                          _Label('Category', color: const Color(0xFF436AA0)),
                          SizedBox(height: 6.h),
                          if (visibleCategories.isEmpty)
                            const Text('No categories for this business type')
                          else
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: validCategoryId,
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                filled: true,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                              ),
                              hint: const Text('Select Category'),
                              items: visibleCategories.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.name),
                                );
                              }).toList(),
                              onChanged: (id) {
                                setState(() => _selectedCategoryId = id);
                              },
                            ),
                        ],
                      );
                    },
                    loading: () => const Text('Loading...'),
                    error: (e, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Error: $e'),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            vendorProductCreateCategoriesProvider,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /// Product Name
                  _Label(
                    ref.t(BKeys.product_title),
                    color: const Color(0xFF436AA0),
                  ),
                  AiGenerateTitleSection(
                    productId: widget.product.id,
                    onTitleGenerated: (title) {
                      final clipped = title.length > kProductNameMaxLength
                          ? title.substring(0, kProductNameMaxLength).trimRight()
                          : title;
                      nameController.text = clipped;
                      nameController.selection = TextSelection.fromPosition(
                        TextPosition(offset: nameController.text.length),
                      );
                    },
                  ),
                  TextFormField(
                    controller: nameController,
                    maxLength: kProductNameMaxLength,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Enter Product Title',
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Max $kProductNameMaxLength characters',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AllColor.black54,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),

                  /// Description
                  _Label(
                    'Description',
                    color: const Color(0xFF436AA0),
                  ),
                  AiGenerateDescriptionSection(
                    productId: widget.product.id,
                    title: nameController.text,
                    resolveTitle: () => nameController.text,
                    category: widget.product.categoryName,
                    onDescriptionGenerated: (desc) {
                      setState(() {
                        descriptionController.text = desc;
                        descriptionController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset: descriptionController.text.length),
                        );
                      });
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Enter Product Description...',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),

                  /// Attributes Dropdown
                  attributeAsync.when(
                    data: (data) {
                      return GenericAttributePicker(attributes: data.data);
                    },
                    loading: () => const Center(child: Text('Loading...')),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),

                  SizedBox(height: 15.h),

                  /// Sale type
                  _Label('Sale type', color: const Color(0xFF436AA0)),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: saleTypeController,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'e.g. kg, piece, etc.',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),

                  /// Prices — always entered and stored as UGX (ledger currency).
                  Text(
                    'Prices must be entered in UGX. Your display currency does not change the submitted amount.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AllColor.black54,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Current price (UGX)',
                                color: const Color(0xFF2B6CB0)),
                            SizedBox(height: 6.h),
                            TextFormField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                hintText: 'Current Price (UGX)',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Previous price (UGX)',
                                color: const Color(0xFF2B6CB0)),
                            SizedBox(height: 6.h),
                            TextFormField(
                              controller: regularPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                hintText: 'Previous Price (UGX)',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  /// Stock and Weight row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Stock', color: const Color(0xFF2B6CB0)),
                            SizedBox(height: 6.h),
                            TextFormField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                hintText: 'Enter Stock Quantity',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label('Weight', color: const Color(0xFF2B6CB0)),
                            SizedBox(height: 6.h),
                            TextFormField(
                              controller: weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                fillColor: AllColor.white,
                                hintText: 'e.g. 1.5',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AllColor.grey,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  _Label('Weight unit', color: const Color(0xFF2B6CB0)),
                  SizedBox(height: 6.h),
                  _EditUnitDropdown(
                    value: _weightUnit,
                    items: const ['kg', 'g', 'lb'],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _weightUnit = v);
                    },
                  ),
                  SizedBox(height: 10.h),

                  _Label('Dimensions', color: const Color(0xFF2B6CB0)),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: lengthController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            fillColor: AllColor.white,
                            hintText: 'Length',
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextFormField(
                          controller: widthController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            fillColor: AllColor.white,
                            hintText: 'Width',
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: TextFormField(
                          controller: heightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            fillColor: AllColor.white,
                            hintText: 'Height',
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AllColor.grey,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),

                  _Label('Dimension unit', color: const Color(0xFF2B6CB0)),
                  SizedBox(height: 6.h),
                  _EditUnitDropdown(
                    value: _dimensionUnit,
                    items: const ['cm', 'm', 'in'],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _dimensionUnit = v);
                    },
                  ),
                  SizedBox(height: 10.h),

                  _Label('Barcode (optional)', color: const Color(0xFF2B6CB0)),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: barcodeController,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Custom barcode',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AllColor.grey,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 15.h),

                  _Label('Terms & conditions', color: const Color(0xFF2B6CB0)),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                          color: Colors.orange.shade200, width: 1.2),
                    ),
                    child: TextField(
                      controller: termsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter terms and conditions (optional)',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF95A6C4),
                        ),
                        fillColor: Colors.transparent,
                        filled: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  GlobalSaveBotton(
                    bottonName: saving ? 'Saving...' : 'Save',
                    onPressed: saving
                        ? null
                        : () async {
                            String? nn(String s) =>
                                s.trim().isEmpty ? null : s.trim();

                            final title = nameController.text.trim();
                            if (title.isEmpty) {
                              GlobalSnackbar.show(
                                context,
                                title: 'Validation Error',
                                message: 'Please enter a product title',
                                type: CustomSnackType.error,
                              );
                              return;
                            }
                            if (title.length > kProductNameMaxLength) {
                              GlobalSnackbar.show(
                                context,
                                title: 'Validation Error',
                                message:
                                    'Product title must be $kProductNameMaxLength characters or less',
                                type: CustomSnackType.error,
                              );
                              return;
                            }

                            await ref
                                .read(updateProductProvider.notifier)
                                .updateProduct(
                                  id: widget.product.id,
                                  name: title,
                                  description:
                                      nn(descriptionController.text),
                                  regularPrice:
                                      nn(regularPriceController.text),
                                  sellPrice: nn(priceController.text),
                                  categoryId: _selectedCategoryId,
                                  attributes: ref
                                          .read(selectedAttributesProvider)
                                          .isEmpty
                                      ? null
                                      : ref.read(
                                          selectedAttributesProvider),
                                  stock: nn(stockController.text),
                                  weight: nn(weightController.text),
                                  weightUnit: _weightUnit,
                                  length: nn(lengthController.text),
                                  width: nn(widthController.text),
                                  height: nn(heightController.text),
                                  dimensionUnit: _dimensionUnit,
                                  saleType: nn(saleTypeController.text),
                                  termsAndConditions:
                                      nn(termsController.text),
                                  barcode: nn(barcodeController.text),
                                  image: mainImage,
                                  newFiles: _newFiles,
                                );

                            final res = ref.read(updateProductProvider);
                            res.when(
                              data: (_) {
                                ref.invalidate(productNotifierProvider);
                                ref.invalidate(updateProductProvider);
                                context.pop();
                                GlobalSnackbar.show(
                                  context,
                                  title: "Success",
                                  message: "Product updated successfully",
                                );
                              },
                              loading: () {},
                              error: (e, _) {
                                GlobalSnackbar.show(
                                  context,
                                  title: "Error",
                                  message: e.toString(),
                                  type: CustomSnackType.error,
                                );
                              },
                            );
                          },
                  ),
                  SizedBox(height: 15.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  File? mainImage;
  List<File> extraImages = [];

  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController regularPriceController;
  late TextEditingController stockController;
  late TextEditingController weightController;
  late TextEditingController lengthController;
  late TextEditingController widthController;
  late TextEditingController heightController;
  late TextEditingController saleTypeController;
  late TextEditingController termsController;
  late TextEditingController barcodeController;

  final ThemeData dropTheme = ThemeData(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );

  @override
  void initState() {
    nameController = TextEditingController(text: widget.product.name);
    descriptionController = TextEditingController(
      text: widget.product.description,
    );
    priceController = TextEditingController(
      text: widget.product.sellPrice.toString(),
    );
    regularPriceController = TextEditingController(
      text: widget.product.regularPrice.toString(),
    );
    stockController = TextEditingController(
      text: widget.product.stock?.toString() ?? '',
    );
    weightController = TextEditingController(
      text: widget.product.weight ?? '',
    );
    lengthController = TextEditingController(
      text: widget.product.length ?? '',
    );
    widthController = TextEditingController(
      text: widget.product.width ?? '',
    );
    heightController = TextEditingController(
      text: widget.product.height ?? '',
    );
    saleTypeController = TextEditingController(
      text: widget.product.saleType ?? '',
    );
    termsController = TextEditingController(
      text: widget.product.termsAndConditions ?? '',
    );
    barcodeController = TextEditingController(
      text: widget.product.barcode ?? '',
    );
    _weightUnit = widget.product.weightUnit;
    _dimensionUnit = widget.product.dimensionUnit;
    _selectedCategoryId = widget.product.categoryId > 0
        ? widget.product.categoryId
        : null;
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh providers to ensure fresh data on first load
      ref.invalidate(productAttributesProvider);
      ref.invalidate(vendorProductCreateCategoriesProvider);

      // Parse attributes from JSON string if available
      Map<String, List<String>> parsedAttributes = {};
      if (widget.product.attributes != null &&
          widget.product.attributes!.isNotEmpty) {
        try {
          final decoded = jsonDecode(widget.product.attributes!);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (value is List) {
                parsedAttributes[key.toString()] = value
                    .map((e) => e.toString())
                    .toList();
              }
            });
          }
        } catch (e) {
          // If parsing fails, fall back to color/size
          if (widget.product.colors.isNotEmpty) {
            parsedAttributes['color'] = widget.product.colors;
          }
          if (widget.product.sizes.isNotEmpty) {
            parsedAttributes['size'] = widget.product.sizes;
          }
        }
      } else {
        // Fallback to color/size if attributes is null
        if (widget.product.colors.isNotEmpty) {
          parsedAttributes['color'] = widget.product.colors;
        }
        if (widget.product.sizes.isNotEmpty) {
          parsedAttributes['size'] = widget.product.sizes;
        }
      }
      // Ensure color/size from top-level API fields are present
      if (!parsedAttributes.containsKey('color') &&
          widget.product.colors.isNotEmpty) {
        parsedAttributes['color'] = widget.product.colors;
      }
      if (!parsedAttributes.containsKey('size') &&
          !parsedAttributes.containsKey('measurement') &&
          widget.product.sizes.isNotEmpty) {
        parsedAttributes['size'] = widget.product.sizes;
      }
      ref.read(selectedAttributesProvider.notifier).state = parsedAttributes;
    });
  }

  Future<void> pickMainImage(source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xFile != null) {
      setState(() => mainImage = File(xFile.path));
    }
  }

  Future<void> pickExtraImage(source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xFile != null) {
      setState(() => extraImages.add(File(xFile.path)));
    }
  }

  void _askImageSource({required bool isMain}) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  isMain
                      ? pickMainImage(ImageSource.camera)
                      : pickExtraImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  isMain
                      ? pickMainImage(ImageSource.gallery)
                      : pickExtraImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ref.invalidate(selectedAttributesProvider);
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    regularPriceController.dispose();
    stockController.dispose();
    weightController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    saleTypeController.dispose();
    termsController.dispose();
    barcodeController.dispose();
    super.dispose();
  }
}

class ProductImageCarousel extends ConsumerStatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.product,
    this.onLocalAddedChanged, // parent-এ লোকাল ফাইলের লিস্ট দিতে চাইলে
  });

  final VendorProduct product;
  final ValueChanged<List<File>>? onLocalAddedChanged;

  @override
  ConsumerState<ProductImageCarousel> createState() =>
      _ProductImageCarouselState();
}

class _ProductImageCarouselState extends ConsumerState<ProductImageCarousel> {
  final ImagePicker _picker = ImagePicker();

  int? _deletingId; // কোন টাইল স্পিন করবে
  final Set<int> _removedIds =
      <int>{}; // সার্ভার ইমেজ যেগুলো মুছে গেছে (UI থেকে লুকানো)
  final List<File> _localAdded = <File>[];

  Future<void> _askImageSource() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndAdd(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndAdd(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndAdd(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 85);
    if (x == null) return;
    if (!mounted) return;
    setState(() => _localAdded.add(File(x.path)));
    widget.onLocalAddedChanged?.call(List<File>.from(_localAdded));
  }

  @override
  Widget build(BuildContext context) {
    // সার্ভারের ইমেজ (যেগুলো মুছে ফেলিনি)
    final serverImages = widget.product.images
        .where((e) => !_removedIds.contains(e.id))
        .toList();

    final asyncDel = ref.watch(deleteProductImageProvider);

    return SizedBox(
      height: 86.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        // সার্ভার + লোকাল + শেষে Add বক্স
        itemCount: serverImages.length + _localAdded.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          // --- Add new image box (last item)
          final lastIndex = serverImages.length + _localAdded.length;
          if (index == lastIndex) {
            return _AddBox(onTap: _askImageSource);
          }

          // --- কোন স্লটে আছি? (server / local)
          if (index < serverImages.length) {
            final img = serverImages[index];
            final imageUrl = img.imagePath.isNotEmpty
                ? img.imagePath
                : widget.product.image;
            final spinning = _deletingId == img.id && asyncDel.isLoading;

            return _ImageTile(
              size: 76.w,
              overlay: spinning
                  ? const Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white),
                    )
                  : const Icon(Icons.clear, color: Colors.white),
              onTap: spinning
                  ? null
                  : () async {
                      setState(() => _deletingId = img.id);
                      final ok = await ref
                          .read(deleteProductImageProvider.notifier)
                          .deleteById(img.id);
                      if (!mounted) return;
                      setState(() => _deletingId = null);

                      if (ok) {
                        setState(() => _removedIds.add(img.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image deleted')),
                        );
                        // চাইলে এখানেই রিফেচ করতে পারেন:
                        // ref.invalidate(yourImagesFetchProvider(widget.product.id));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to delete image'),
                          ),
                        );
                      }
                    },
              child: FirstTimeShimmerImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),
            );
          } else {
            // Local added tile
            final localIdx = index - serverImages.length;
            final file = _localAdded[localIdx];

            return _ImageTile(
              size: 76.w,
              overlay: const Icon(Icons.clear, color: Colors.white),
              onTap: () {
                setState(() => _localAdded.removeAt(localIdx));
                widget.onLocalAddedChanged?.call(List<File>.from(_localAdded));
              },
              child: Image.file(file, fit: BoxFit.cover),
            );
          }
        },
      ),
    );
  }
}

class _AddBox extends StatelessWidget {
  const _AddBox({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76.w,
        width: 76.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6.r,
              offset: Offset(0, 3.h),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          Icons.add_a_photo_outlined,
          color: Colors.blueAccent,
          size: 24.sp,
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.child,
    required this.overlay,
    required this.onTap,
    required this.size,
  });

  final Widget child;
  final Widget overlay; // spinner or ❌
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: size,
          width: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6.r,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: child,
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    shape: BoxShape.circle,
                  ),
                  child: overlay,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditUnitDropdown extends StatelessWidget {
  const _EditUnitDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        fillColor: AllColor.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AllColor.grey, width: 1.2),
          borderRadius: BorderRadius.circular(5.r),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AllColor.grey, width: 1.2),
          borderRadius: BorderRadius.circular(5.r),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
