import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> _authToken() async {
  final token = await AuthLocalStorage().getToken();
  if (token == null || token.isEmpty) {
    throw Exception('Token not found');
  }
  return token;
}

Map<String, dynamic> _decodeMap(http.Response response) {
  dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    throw Exception(
      response.body.trim().isEmpty
          ? 'Invalid AI response (${response.statusCode})'
          : response.body,
    );
  }

  String messageFrom(dynamic body) {
    if (body is Map) {
      final msg = body['message'] ?? body['error'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString().trim();
      }
    }
    return 'AI request failed (${response.statusCode})';
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(messageFrom(decoded));
  }

  if (decoded is! Map) {
    throw Exception('Invalid API response');
  }

  final map = Map<String, dynamic>.from(decoded);
  if (map['success'] == false) {
    throw Exception(messageFrom(map));
  }
  return map;
}

/// `POST /api/vendor/ai/product/generate-title`
class GenerateProductTitleApi {
  GenerateProductTitleApi._();

  static Future<String> generate({
    required String keywords,
    int? productId,
  }) async {
    final trimmed = keywords.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please enter keywords');
    }

    final token = await _authToken();
    final uri = Uri.parse(VendorAPIController.generateProductTitle);
    final body = <String, dynamic>{
      'keywords': trimmed,
      if (productId != null && productId > 0) 'product_id': productId,
    };

    final response = await http.post(
      uri,
      headers: {
        'token': token,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final decoded = _decodeMap(response);
    final data = decoded['data'];
    final title = data is Map
        ? data['title']?.toString()
        : decoded['title']?.toString();

    if (title == null || title.trim().isEmpty) {
      throw Exception('No title returned');
    }
    return title.trim();
  }
}

class GeneratedProductDescription {
  final String description;
  final String shortDescription;

  const GeneratedProductDescription({
    required this.description,
    required this.shortDescription,
  });
}

/// `POST /api/vendor/ai/product/generate-description`
class GenerateProductDescriptionApi {
  GenerateProductDescriptionApi._();

  static Future<GeneratedProductDescription> generate({
    required String title,
    required List<String> keyFeatures,
    String? category,
    int? productId,
    String language = 'english',
    String tone = 'professional',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw Exception('Please enter a product title first');
    }

    final features = keyFeatures
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (features.isEmpty) {
      throw Exception('Please enter key features');
    }

    final token = await _authToken();
    final uri = Uri.parse(VendorAPIController.generateProductDescription);
    final body = <String, dynamic>{
      'title': cleanTitle,
      'key_features': features,
      'language': language,
      'tone': tone,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (productId != null && productId > 0) 'product_id': productId,
    };

    final response = await http.post(
      uri,
      headers: {
        'token': token,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final decoded = _decodeMap(response);
    final data = decoded['data'];
    if (data is! Map) {
      throw Exception('No description returned');
    }

    final description = data['description']?.toString().trim() ?? '';
    final shortDescription =
        data['short_description']?.toString().trim() ?? '';

    if (description.isEmpty && shortDescription.isEmpty) {
      throw Exception('No description returned');
    }

    return GeneratedProductDescription(
      description: description.isNotEmpty ? description : shortDescription,
      shortDescription: shortDescription,
    );
  }
}

/// `POST /api/vendor/ai/product/generate-image`
class GenerateProductImageApi {
  GenerateProductImageApi._();

  static Future<File> generate({
    required String title,
    required String description,
    String? category,
    int? productId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw Exception('Please enter a product title first');
    }

    final token = await _authToken();
    final uri = Uri.parse(VendorAPIController.generateProductImage);
    final body = <String, dynamic>{
      'title': cleanTitle,
      'description': description.trim().isEmpty
          ? cleanTitle
          : description.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (productId != null && productId > 0) 'product_id': productId,
    };

    final response = await http
        .post(
          uri,
          headers: {
            'token': token,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    final decoded = _decodeMap(response);
    final data = decoded['data'];
    final imageUrl = data is Map ? data['image_url']?.toString() : null;
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception('No image URL returned');
    }

    final imgRes = await http
        .get(Uri.parse(imageUrl.trim()))
        .timeout(const Duration(seconds: 60));
    if (imgRes.statusCode < 200 || imgRes.statusCode >= 300) {
      throw Exception('Failed to download generated image');
    }

    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(
      tempDir.path,
      'ai_product_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final file = File(outPath);
    await file.writeAsBytes(imgRes.bodyBytes);
    return file;
  }
}
