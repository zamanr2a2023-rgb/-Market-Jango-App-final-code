// lib/features/vendor/screens/product_edit/logic/update_product_provider.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/image_check_before_post.dart';
import 'package:market_jango/features/vendor/screens/vendor_product_add_page/logic/creat_product_provider.dart';
import 'package:path/path.dart' as p;

final updateProductProvider =
    StateNotifierProvider<UpdateProductNotifier, AsyncValue<void>>(
      (ref) => UpdateProductNotifier(ref),
    );

class UpdateProductNotifier extends StateNotifier<AsyncValue<void>> {
  UpdateProductNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<bool> updateProduct({
    required int id,
    String? name,
    String? description,
    String? regularPrice, // regular_price
    String? sellPrice, // sell_price
    int? categoryId,
    Map<String, List<String>>? attributes,
    Map<String, String> specification = const {},
    String? stock,
    String? weight,
    String? weightUnit,
    String? length,
    String? width,
    String? height,
    String? dimensionUnit,
    String? saleType,
    String? termsAndConditions,
    String? barcode,
    File? image, // main image
    List<File>? newFiles, // files[]
  }) async {
    try {
      state = const AsyncLoading();

      final token = await AuthLocalStorage().getToken();
      final uri = Uri.parse(VendorAPIController.product_update(id));

      final req = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        req.headers['token'] = token;
      }
      req.headers['Accept'] = 'application/json';

      void addField(String key, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          req.fields[key] = value.trim();
        }
      }

      addField('name', name);
      addField('description', description);
      addField('regular_price', regularPrice);
      addField('sell_price', sellPrice);

      if (categoryId != null) req.fields['category_id'] = '$categoryId';
      addField('stock', stock);
      addField('weight', weight);
      addField('weight_unit', weightUnit);
      addField('length', length);
      addField('width', width);
      addField('height', height);
      if ((length?.trim().isNotEmpty ?? false) ||
          (width?.trim().isNotEmpty ?? false) ||
          (height?.trim().isNotEmpty ?? false)) {
        addField(
          'dimension_unit',
          (dimensionUnit == null || dimensionUnit.trim().isEmpty)
              ? 'cm'
              : dimensionUnit,
        );
      }
      addField('sale_type', saleType);
      addField('terms_and_conditions', termsAndConditions);
      addField('barcode', barcode);

      final split = CreateProductNotifier.splitAttributes(attributes ?? {});
      if (split.color != null && split.color!.isNotEmpty) {
        req.fields['color'] = jsonEncode(split.color);
      }
      if (split.measurement != null && split.measurement!.isNotEmpty) {
        req.fields['measurement'] = jsonEncode(split.measurement);
      }

      // Select Attribute → `attributes` e.g. {"brand":["apple"]}
      if (split.attributes.isNotEmpty) {
        req.fields['attributes'] = jsonEncode(split.attributes);
      }

      // Specification section → `specifications` e.g. {"material":"cotton"}
      final specsOut = <String, String>{};
      specification.forEach((k, v) {
        final key = k.trim();
        final val = v.trim();
        if (key.isEmpty || val.isEmpty) return;
        specsOut[key] = val;
      });
      if (specsOut.isNotEmpty) {
        req.fields['specifications'] = jsonEncode(specsOut);
      }

      if (image != null) {
        final coverCompressed = await ImageManager.compressFile(image);
        req.files.add(
          await http.MultipartFile.fromPath(
            'image',
            coverCompressed.path,
            filename: p.basename(coverCompressed.path),
          ),
        );
      }

      final toCompress = newFiles ?? const <File>[];
      if (toCompress.isNotEmpty) {
        final galleryCompressed = await ImageManager.compressAll(toCompress);
        for (final f in galleryCompressed) {
          req.files.add(
            await http.MultipartFile.fromPath(
              'files[]',
              f.path,
              filename: p.basename(f.path),
            ),
          );
        }
      }

      final res = await req.send();
      final body = await res.stream.bytesToString();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        state = const AsyncData(null);
        return true;
      } else {
        state = AsyncError(
          'Failed: ${res.statusCode} $body',
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
