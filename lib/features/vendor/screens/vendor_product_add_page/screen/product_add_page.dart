import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/widget/TupperTextAndBackButton.dart';
import 'package:market_jango/core/widget/global_save_botton.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/product_edit/logic/update_product_riverpod.dart';
import 'package:market_jango/features/vendor/screens/vendor_home/data/vendor_product_data.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/selecd_color_size_list.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/data/vendor_product_create_categories.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/logic/creat_product_provider.dart';

import '../../product_edit/data/product_attribute_data.dart';
import '../widget/generic_attribute_picker.dart';

class ProductAddPage extends ConsumerStatefulWidget {
   const ProductAddPage({super.key,});

  static final String routeName = "/productAddPage";

  @override
  ConsumerState<ProductAddPage> createState() => _ProductAddPageState();
}

class _ProductAddPageState extends ConsumerState<ProductAddPage> {
  @override
  void initState() {
    super.initState();
    // Clear attributes when entering the page and refresh attributes list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedAttributesProvider.notifier).state = {};
      // Refresh attributes to ensure we have the latest data
      ref.invalidate(productAttributesProvider);
    });
  }

  @override
  void dispose() {
    // Clear attributes and option-2 fields when leaving the page
    ref.read(selectedAttributesProvider.notifier).state = {};
    ref.read(saleTypeProvider.notifier).state = '';
    ref.read(termsAndConditionsProvider.notifier).state = '';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attributeAsync = ref.watch(productAttributesProvider);


    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: Column(
              children: [
                Tuppertextandbackbutton(
                  screenName: ref.t(BKeys.product_upload, fallback: 'Product Upload'),
                ),
                ProductBasicInfoSection(),
                SizedBox(height: 16.h),
              attributeAsync.when(
                data: (data) {
                  return GenericAttributePicker(
                    attributes: data.data,
                  );
                },
                loading: () => const Center(child: Text('Loading...')),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),

              SizedBox(height: 16.h),
              _TwoOptionSection(),
              SizedBox(height: 16.h),
                PriceAndImagesSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductBasicInfoSection extends ConsumerStatefulWidget {
  const ProductBasicInfoSection({super.key});

  @override
  ConsumerState<ProductBasicInfoSection> createState() =>
      _ProductBasicInfoSectionState();
}

class _ProductBasicInfoSectionState extends ConsumerState<ProductBasicInfoSection> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController(

  );

  int? selectedBusinessTypeId; // Will be set when business types load
  int? selectedCategoryId; // Will be set when categories load

  // colors tuned to the mock
  final _lblColor = const Color(0xFF436AA0); // label text

  final _hintText = const Color(0xFF95A6C4); // (optional) hint color

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(5.r),
    borderSide: BorderSide(color: AllColor.grey, width: 1.2),

  );

  @override
  Widget build(BuildContext context) {
   
    final ThemeData dropTheme = ThemeData(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );


    final categoryAsync = ref.watch(vendorProductCreateCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
            //'Product Title'
          ref.t(BKeys.product_title)
        , color: _lblColor),
        SizedBox(height: 6.h),
        TextFormField(
          onChanged: (value) {
            ref.read(productNameProvider.notifier).state = value;
          },
          controller: _titleC,
          style: TextStyle(fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: 'Enter Product Title',
            fillColor: AllColor.white,
            enabledBorder: _border(),
            focusedBorder: _border(),
          ),
        ),

        SizedBox(height: 16.h),

        /// Business Type + Category (from `GET /vendor/product-categories`)
        categoryAsync.when(
          data: (result) {
            if (result.categories.isEmpty) {
              return const Text('No categories available');
            }

            final businessTypes = result.businessTypes;

            // Keep the selected business type valid.
            int? validTypeId = selectedBusinessTypeId;
            if (businessTypes.isNotEmpty &&
                (validTypeId == null ||
                    !businessTypes.any((t) => t.id == validTypeId))) {
              validTypeId = businessTypes.first.id;
            }

            // Categories shown depend on the selected business type.
            final visibleCategories = validTypeId == null
                ? result.categories
                : result.categories
                    .where((c) => c.businessTypeId == validTypeId)
                    .toList();

            // Keep the selected category valid within the visible list.
            int? validCategoryId = selectedCategoryId;
            if (visibleCategories.isEmpty) {
              validCategoryId = null;
            } else if (validCategoryId == null ||
                !visibleCategories.any((c) => c.id == validCategoryId)) {
              validCategoryId = visibleCategories.first.id;
            }

            // Sync widget/provider state after build if defaults changed.
            if (validTypeId != selectedBusinessTypeId ||
                validCategoryId != selectedCategoryId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  selectedBusinessTypeId = validTypeId;
                  selectedCategoryId = validCategoryId;
                });
                ref.read(productCategoryProvider.notifier).state =
                    validCategoryId;
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (businessTypes.isNotEmpty) ...[
                  _Label('Business Type', color: _lblColor),
                  SizedBox(height: 6.h),
                  _DropdownShell(
                    dropTheme: dropTheme,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: validTypeId,
                      hint: Text('Select Business Type',
                          style:
                              TextStyle(fontSize: 15.sp, color: _hintText)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      style:
                          TextStyle(fontSize: 15.sp, color: Colors.black87),
                      items: businessTypes.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Text(t.name),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final firstCat = result.categories
                            .where((c) => c.businessTypeId == v)
                            .toList();
                        setState(() {
                          selectedBusinessTypeId = v;
                          selectedCategoryId =
                              firstCat.isEmpty ? null : firstCat.first.id;
                        });
                        ref.read(productCategoryProvider.notifier).state =
                            firstCat.isEmpty ? null : firstCat.first.id;
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
                _Label('Category', color: _lblColor),
                SizedBox(height: 6.h),
                if (visibleCategories.isEmpty)
                  const Text('No categories for this business type')
                else
                  _DropdownShell(
                    dropTheme: dropTheme,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: validCategoryId,
                      hint: Text('Select Category',
                          style:
                              TextStyle(fontSize: 15.sp, color: _hintText)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      style:
                          TextStyle(fontSize: 15.sp, color: Colors.black87),
                      items: visibleCategories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Text(c.name),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedCategoryId = v);
                        ref.read(productCategoryProvider.notifier).state = v;
                      },
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: Text('Loading...')),
          error: (err, _) => Center(
            child: Column(
              children: [
                Text('Error: $err'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(vendorProductCreateCategoriesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 16.h),

        _Label('Description', color: _lblColor),
        SizedBox(height: 6.h),
        TextFormField(
          onChanged: (value) {
            ref.read(productDescProvider.notifier).state = value;
          },
          controller: _descC,
          maxLines: 6,
          style: TextStyle(fontSize: 16.sp, height: 1.35),
          decoration: InputDecoration(
            hintText: 'Enter Product Description...',
            fillColor: AllColor.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(),
            hintStyle: TextStyle(color: _hintText),
          ),
        ),
      ],
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

/// Bordered white container used by the business type / category dropdowns.
class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.dropTheme, required this.child});
  final ThemeData dropTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
              color: Colors.black.withOpacity(0.06),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(child: child),
      ),
    );
  }
}

/// Sale type field (attributes are above; terms & conditions at bottom in orange box).
class _TwoOptionSection extends ConsumerStatefulWidget {
  const _TwoOptionSection();

  @override
  ConsumerState<_TwoOptionSection> createState() => _TwoOptionSectionState();
}

class _TwoOptionSectionState extends ConsumerState<_TwoOptionSection> {
  final _saleTypeC = TextEditingController();
  static const _lblColor = Color(0xFF436AA0);
  static const _hintColor = Color(0xFF95A6C4);

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(5.r),
        borderSide: BorderSide(color: AllColor.grey, width: 1.2),
      );

  @override
  void dispose() {
    _saleTypeC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale type',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _lblColor,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: _saleTypeC,
          onChanged: (v) =>
              ref.read(saleTypeProvider.notifier).state = v,
          decoration: InputDecoration(
            hintText: 'e.g. kg, piece, etc.',
            hintStyle: TextStyle(fontSize: 14.sp, color: _hintColor),
            fillColor: AllColor.white,
            enabledBorder: _border(),
            focusedBorder: _border(),
          ),
        ),
      ],
    );
  }
}

class PriceAndImagesSection extends ConsumerStatefulWidget{
  const PriceAndImagesSection({super.key,});


  @override
  ConsumerState<PriceAndImagesSection> createState() => _PriceAndImagesSectionState();
}

class _PriceAndImagesSectionState extends ConsumerState<PriceAndImagesSection> {


  @override
  void dispose() {
    _termsC.dispose();
    _currentC.dispose();
    _previousC.dispose();
    _stockC.dispose();
    _weightC.dispose();
    _lengthC.dispose();
    _widthC.dispose();
    _heightC.dispose();
    _barcodeC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    const borderBlue = Color(0xFFBFD5F1);
    const labelBlue = Color(0xFF2B6CB0);
    const hintColor = Color(0xFF95A6C4);
    final createState = ref.watch(createProductProvider);

    bool loading = createState.isLoading;
    final selectedAttributes = ref.read(selectedAttributesProvider);

    ref.listen<AsyncValue<String>>(createProductProvider, (prev, next) {
      next.when(
        data: (msg) {
          if (msg.contains('success')) {
            // Invalidate product list provider to refresh the list
            ref.invalidate(productNotifierProvider);
            ref.invalidate(updateProductProvider);
            // success হলেই নেভিগেট + টোস্ট
            context.pop();
            GlobalSnackbar.show(context, title: "Success", message: "Product Created Successfully");
          }
        },
        error: (err, _) {
          GlobalSnackbar.show(context, title: "Error", message: err.toString());
        },
        loading: () {},
      );
    });


    OutlineInputBorder border([Color c = borderBlue]) => OutlineInputBorder(
      borderSide: BorderSide(color: c, width: 1.2),
      borderRadius: BorderRadius.circular(8.r),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prices row — always entered and stored as UGX (ledger currency).
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
                child: _Labeled(
                  label: 'Current price (UGX)',
                  labelColor: labelBlue,
                  child: TextField(
                    controller: _currentC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Current Price (UGX)',
                      enabledBorder: border(),
                      focusedBorder: border(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: _Labeled(
                  label: 'Previous price (UGX)',
                  labelColor: labelBlue,
                  child: TextField(
                    controller: _previousC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Previous Price (UGX)',
                      enabledBorder: border(),
                      focusedBorder: border(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Stock and Weight row
          Row(
            children: [
              Expanded(
                child: _Labeled(
                  label: 'Stock',
                  labelColor: labelBlue,
                  child: TextField(
                    controller: _stockC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'Enter Stock Quantity',
                      enabledBorder: border(),
                      focusedBorder: border(),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: _Labeled(
                  label: 'Weight',
                  labelColor: labelBlue,
                  child: TextField(
                    controller: _weightC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      fillColor: AllColor.white,
                      hintText: 'e.g. 1.5',
                      enabledBorder: border(),
                      focusedBorder: border(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Weight unit
          _Labeled(
            label: 'Weight unit',
            labelColor: labelBlue,
            child: _UnitDropdown(
              value: _weightUnit,
              items: const ['kg', 'g', 'lb'],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _weightUnit = v);
              },
              border: border(),
            ),
          ),
          SizedBox(height: 16.h),
          // Dimensions (length / width / height)
          Text(
            'Dimensions',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: labelBlue,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lengthC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    fillColor: AllColor.white,
                    hintText: 'Length',
                    enabledBorder: border(),
                    focusedBorder: border(),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: _widthC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    fillColor: AllColor.white,
                    hintText: 'Width',
                    enabledBorder: border(),
                    focusedBorder: border(),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: _heightC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    fillColor: AllColor.white,
                    hintText: 'Height',
                    enabledBorder: border(),
                    focusedBorder: border(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _Labeled(
            label: 'Dimension unit',
            labelColor: labelBlue,
            child: _UnitDropdown(
              value: _dimensionUnit,
              items: const ['cm', 'm', 'in'],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _dimensionUnit = v);
              },
              border: border(),
            ),
          ),
          SizedBox(height: 16.h),
          _Labeled(
            label: 'Barcode (optional)',
            labelColor: labelBlue,
            child: TextField(
              controller: _barcodeC,
              decoration: InputDecoration(
                fillColor: AllColor.white,
                hintText: 'Custom barcode',
                enabledBorder: border(),
                focusedBorder: border(),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Cover image
          _Labeled(
            label: 'Cover Image',
            labelColor: labelBlue,
            child: _UploadCard(text: 'Upload Image', onTap: _askImageSource),
          ),
          SizedBox(height: 10.h),

          // Single preview
          if (_cover != null)  _SectionTitle('Uploaded Preview', labelBlue),
          SizedBox(height: 8.h),
          if (_cover != null)    SizedBox(
            height: 64.w,
            child: Align(
              alignment: Alignment.centerLeft,
              child:  _PreviewTile(file: _cover, size: 64.w),
            ),
          ),
          SizedBox(height: 18.h),

          // Gallery images
       _Labeled(
            label: 'Gallery Images',
            labelColor: labelBlue,
            child: _UploadCard(
              text: 'Upload Multiple Images',
              onTap: _pickGallery,
            ),
          ),
          SizedBox(height: 10.h),

          if (_gallery.isNotEmpty)   _SectionTitle('Uploaded Preview', labelBlue),
          SizedBox(height: 8.h),

          // Grid of previews (show empty placeholders if none)
        Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: List.generate(_gallery.length, (i) {
              final file = i < _gallery.length ? _gallery[i] : null;
              return _PreviewTile(file: file, size: 64.w);
            }),
          ),
          SizedBox(height: 20.h),

          // Terms & conditions - last position, orange box
          Text(
            'Terms & conditions',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: labelBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.shade200, width: 1.2),
            ),
            child: TextField(
              controller: _termsC,
              onChanged: (v) =>
                  ref.read(termsAndConditionsProvider.notifier).state = v,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter terms and conditions (optional)',
                hintStyle: TextStyle(fontSize: 14.sp, color: hintColor),
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
                bottonName:loading? "Creating....": "Create a Product",
                onPressed: () {
                  // Validate prices
                  if (_currentC.text.trim().isEmpty || _previousC.text.trim().isEmpty) {
                    GlobalSnackbar.show(
                      context,
                      title: "Validation Error",
                      message: "Please enter the prices",
                      type: CustomSnackType.error,
                    );
                    return;
                  }
                  
                  // Validate cover image
                  if (_cover == null) {
                    GlobalSnackbar.show(
                      context,
                      title: "Validation Error",
                      message: "Please upload a cover image",
                      type: CustomSnackType.error,
                    );
                    return;
                  }

                  // API requires at least 1 additional image in files[]
                  if (_gallery.isEmpty) {
                    GlobalSnackbar.show(
                      context,
                      title: "Validation Error",
                      message: "Please upload at least one gallery image",
                      type: CustomSnackType.error,
                    );
                    return;
                  }
                  
                  final createAsync = ref.read(createProductProvider.notifier);
                  final name = ref.watch(productNameProvider);
                  final desc = ref.watch(productDescProvider);
                  final categoryId = ref.watch(productCategoryProvider);
                  final saleType = ref.watch(saleTypeProvider);
                  final termsAndConditions = ref.watch(termsAndConditionsProvider);
                  createAsync.createProduct(
                    name: name,
                    description: desc,
                    regularPrice: _previousC.text,
                    sellPrice: _currentC.text,
                    categoryId: categoryId ?? 1,
                    attributes: selectedAttributes,
                    stock: _stockC.text,
                    weight: _weightC.text,
                    weightUnit: _weightUnit,
                    length: _lengthC.text,
                    width: _widthC.text,
                    height: _heightC.text,
                    dimensionUnit: _dimensionUnit,
                    barcode: _barcodeC.text,
                    saleType: saleType,
                    termsAndConditions: termsAndConditions,
                    image: File(_cover!.path),
                    files: _gallery.map((x) => File(x.path)).toList(),
                  );
                  // final state = ref.read(createProductProvider);
                  // state.when(
                  //     data: (msg) {
                  //       if (msg.contains('success')) {
                  //         context.push(VendorHomeScreen.routeName);
                  //         GlobalSnackbar.show(context, title: "Success", message: "Product Created Successfully") ;
                  //
                  //       }
                  //     },
                  //     error: (err, _) {
                  //       GlobalSnackbar.show(context, title: "Error", message: "Something went wrong") ;
                  //     },
                  //     loading: ()   {},
                  //     // => const Center(child: CircularProgressIndicator()),
                  // );
                }
              )
           
        ],
      ),
    );
  }
  final _currentC = TextEditingController();
  final _previousC = TextEditingController();
  final _stockC = TextEditingController();
  final _weightC = TextEditingController();
  final _lengthC = TextEditingController();
  final _widthC = TextEditingController();
  final _heightC = TextEditingController();
  final _barcodeC = TextEditingController();
  final _termsC = TextEditingController();
  String _weightUnit = 'kg';
  String _dimensionUnit = 'cm';

  final _picker = ImagePicker();

  XFile? _cover;
  final List<XFile> _gallery = [];

  Future<void> _pickCover(source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (x != null) setState(() => _cover = x);
  }

  Future<void> _pickGallery() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85);
    if (xs.isNotEmpty) {
      setState(
            () => _gallery
          ..clear()
          ..addAll(xs.take(8)),
      ); // cap to 8 for neat grid
    }
  }
  void _askImageSource() {
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

                  _pickCover(ImageSource.camera) ;

                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickCover(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.border,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final OutlineInputBorder border;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        fillColor: AllColor.white,
        enabledBorder: border,
        focusedBorder: border,
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

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.child,
    this.labelColor = const Color(0xFF2B6CB0),
  });
  final String label;
  final Widget child;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        SizedBox(height: 6.h),
        child,
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFFDFE7F1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF606F85),
                ),
              ),
            ),
            Icon(
              Icons.cloud_upload_outlined,
              color: const Color(0xFF94A3B8),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.file, required this.size});
  final XFile? file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFFCBD5E1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: file == null
          ? const SizedBox.shrink()
          : Image.file(File(file!.path), fit: BoxFit.cover),
    );
  }
}

Widget _SectionTitle(String t, Color c) => Text(
  t,
  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: c),
);