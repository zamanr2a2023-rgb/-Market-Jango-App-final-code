import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/auth_api.dart';

class BusinessTypeItem {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String? imagePath;

  const BusinessTypeItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.imagePath,
  });

  factory BusinessTypeItem.fromJson(Map<String, dynamic> j) {
    return BusinessTypeItem(
      id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      name: j['name']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      imagePath: j['image_path']?.toString(),
    );
  }
}

/// `GET /api/business-type` — list of business types for Create Store.
final businessTypesProvider =
    FutureProvider.autoDispose<List<BusinessTypeItem>>((ref) async {
  final response = await http.get(
    Uri.parse(AuthAPIController.business_type),
    headers: const {'Accept': 'application/json'},
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch business types (${response.statusCode})');
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Invalid response');
  }

  final data = decoded['data'];
  if (data is! List) {
    throw Exception('Invalid data format');
  }

  final items = <BusinessTypeItem>[];
  for (final e in data) {
    if (e is Map<String, dynamic>) {
      final item = BusinessTypeItem.fromJson(e);
      if (item.name.isNotEmpty) items.add(item);
    } else if (e is String && e.trim().isNotEmpty) {
      // Backward compatibility if API returns plain strings.
      items.add(
        BusinessTypeItem(
          id: 0,
          name: e.trim(),
          slug: e.trim().toLowerCase().replaceAll(' ', '-'),
          description: '',
        ),
      );
    }
  }
  return items;
});
