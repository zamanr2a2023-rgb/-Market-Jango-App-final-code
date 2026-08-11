import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/format_api_money.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/core/widget/custom_new_product.dart';
import 'package:market_jango/features/buyer/screens/buyer_vendor_profile/model/buyer_vendor_category_model.dart';
import 'package:market_jango/features/buyer/screens/product/product_details.dart';

class VendorBusinessType {
  final int id;
  final String name;
  final int productCount;

  const VendorBusinessType({
    required this.id,
    required this.name,
    this.productCount = 0,
  });

  factory VendorBusinessType.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return VendorBusinessType(
      id: asInt(j['id']),
      name: j['name']?.toString() ?? '',
      productCount: asInt(j['product_count']),
    );
  }
}

class _VendorCategoryChip {
  final int id;
  final String name;

  const _VendorCategoryChip({required this.id, required this.name});
}

final vendorPublicBusinessTypesProvider =
    FutureProvider.autoDispose.family<List<VendorBusinessType>, int>((
      ref,
      vendorId,
    ) async {
  if (vendorId <= 0) return const [];
  final token = await ref.watch(authTokenProvider.future);
  if (token == null || token.isEmpty) return const [];

  final res = await http.get(
    Uri.parse(BuyerAPIController.vendorPublicBusinessTypes(vendorId)),
    headers: {'Accept': 'application/json', 'token': token},
  );
  if (res.statusCode != 200) return const [];

  final body = jsonDecode(res.body);
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is! Map) return const [];
  final list = data['business_types'];
  if (list is! List) return const [];

  return list
      .whereType<Map>()
      .map((e) => VendorBusinessType.fromJson(Map<String, dynamic>.from(e)))
      .where((t) => t.id > 0 && t.name.trim().isNotEmpty)
      .toList();
});

Future<List<VcpProduct>> fetchVendorProducts({
  required String token,
  required int vendorId,
  int? businessTypeId,
}) async {
  final out = <VcpProduct>[];
  var page = 1;
  var lastPage = 1;

  while (page <= lastPage && page <= 10) {
    final url = BuyerAPIController.productVendor(
      vendorId,
      page: page,
      businessTypeId: businessTypeId,
    );
    final res = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json', 'token': token},
    );
    if (res.statusCode != 200) {
      throw Exception('Vendor products failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    if (body is! Map) break;
    final data = body['data'];
    if (data is! Map) break;
    final productsBlock = data['products'];
    if (productsBlock is! Map) break;

    lastPage = () {
      final v = productsBlock['last_page'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 1;
    }();

    final list = productsBlock['data'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          try {
            out.add(VcpProduct.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
    }
    page++;
  }

  return out;
}

/// Business type → category → products (no search bar).
class VendorProfileProductSearch extends ConsumerStatefulWidget {
  const VendorProfileProductSearch({super.key, required this.vendorId});

  final int vendorId;

  @override
  ConsumerState<VendorProfileProductSearch> createState() =>
      _VendorProfileProductSearchState();
}

class _VendorProfileProductSearchState
    extends ConsumerState<VendorProfileProductSearch> {
  int? _businessTypeId;
  int? _categoryId;
  List<VcpProduct> _typeProducts = const [];
  AsyncValue<List<VcpProduct>> _typeLoad = const AsyncData([]);

  Future<void> _loadForBusinessType(int? typeId) async {
    if (typeId == null) {
      setState(() {
        _businessTypeId = null;
        _categoryId = null;
        _typeProducts = const [];
        _typeLoad = const AsyncData([]);
      });
      return;
    }

    setState(() {
      _businessTypeId = typeId;
      _categoryId = null;
      _typeLoad = const AsyncLoading();
    });

    try {
      final token = await ref.read(authTokenProvider.future);
      if (token == null || token.isEmpty) throw Exception('Token not found');
      final list = await fetchVendorProducts(
        token: token,
        vendorId: widget.vendorId,
        businessTypeId: typeId,
      );
      if (!mounted) return;
      setState(() {
        _typeProducts = list;
        _typeLoad = AsyncData(list);
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _typeLoad = AsyncError(e, st));
    }
  }

  List<_VendorCategoryChip> get _categories {
    final map = <int, String>{};
    for (final p in _typeProducts) {
      if (p.categoryId <= 0) continue;
      final name = p.categoryName.trim().isNotEmpty
          ? p.categoryName.trim()
          : 'Category ${p.categoryId}';
      map.putIfAbsent(p.categoryId, () => name);
    }
    final chips = map.entries
        .map((e) => _VendorCategoryChip(id: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return chips;
  }

  List<VcpProduct> get _visibleProducts {
    if (_categoryId == null) return const [];
    return _typeProducts.where((p) => p.categoryId == _categoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(
      vendorPublicBusinessTypesProvider(widget.vendorId),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Business type',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8.h),
          typesAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Text(
              e.toString(),
              style: TextStyle(fontSize: 12.sp, color: Colors.red),
            ),
            data: (types) {
              if (types.isEmpty) {
                return Text(
                  'No business types',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                );
              }
              return Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: types.map((t) {
                  final selected = _businessTypeId == t.id;
                  final label = t.productCount > 0
                      ? '${t.name} (${t.productCount})'
                      : t.name;
                  return _Chip(
                    label: label,
                    selected: selected,
                    onTap: () => _loadForBusinessType(selected ? null : t.id),
                  );
                }).toList(),
              );
            },
          ),

          if (_businessTypeId != null) ...[
            SizedBox(height: 14.h),
            Text(
              'Category',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            _typeLoad.when(
              loading: () => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Text(
                e.toString(),
                style: TextStyle(fontSize: 12.sp, color: Colors.red),
              ),
              data: (_) {
                final cats = _categories;
                if (cats.isEmpty) {
                  return Text(
                    'No categories for this business type',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  );
                }
                return Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: cats.map((c) {
                    final selected = _categoryId == c.id;
                    return _Chip(
                      label: c.name,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _categoryId = selected ? null : c.id;
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],

          if (_categoryId != null) ...[
            SizedBox(height: 14.h),
            Text(
              'Products',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            _buildProductsGrid(_visibleProducts),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<VcpProduct> products) {
    if (products.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Text(
          'No products in this category',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 0.60,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return GestureDetector(
          onTap: () => context.push(ProductDetails.routeName, extra: p.id),
          child: CustomNewProduct(
            width: 162.w,
            height: 175.h,
            productName: p.name,
            productPrices: formatProductPriceLabel(
              sellPriceDisplay: p.sellPriceDisplay,
              sellPrice: p.sellPrice,
              displayCurrency: p.displayCurrency,
              currency: p.currency,
            ),
            image: p.image,
            imageHeight: 175,
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AllColor.loginButtomColor : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AllColor.loginButtomColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
