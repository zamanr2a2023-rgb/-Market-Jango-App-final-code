import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedColorsProvider = StateProvider<List<String>>((ref) => []);
final selectedSizesProvider = StateProvider<List<String>>((ref) => []);
final selectedAttributesProvider = StateProvider<Map<String, List<String>>>((ref) => {});
final productNameProvider = StateProvider<String>((ref) => '');
/// Backend `name` max length for product create/update.
const int kProductNameMaxLength = 50;
final productDescProvider = StateProvider<String>((ref) => '');
final productCategoryProvider = StateProvider<int?>((ref) => null);
final productCategoryNameProvider = StateProvider<String>((ref) => '');
/// Shared AI keywords from title section — reused for description `key_features`.
final productKeywordsProvider = StateProvider<String>((ref) => '');
final saleTypeProvider = StateProvider<String>((ref) => '');
final termsAndConditionsProvider = StateProvider<String>((ref) => '');
/// Custom product specs for `specifications` JSON, e.g. {"material":"cotton"}.
final productSpecificationProvider =
    StateProvider<Map<String, String>>((ref) => {});