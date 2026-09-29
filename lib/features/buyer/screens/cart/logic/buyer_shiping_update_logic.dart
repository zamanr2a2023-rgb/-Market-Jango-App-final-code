// user_update_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:shared_preferences/shared_preferences.dart';

final userUpdateServiceProvider = Provider<UserUpdateService>(
  (ref) => UserUpdateService(ref),
);

class ShippingUpdatePayload {
  final String shipAddress;
  final String shipCity;
  final String? postcode;

  final String? shipState;
  final String? shipCountry;

  final String? shipName;
  final String? shipEmail;
  final String? shipPhone;

  final File? imageFile; // optional

  ShippingUpdatePayload({
    required this.shipAddress,
    required this.shipCity,
    this.postcode,
    this.shipState,
    this.shipCountry,
    this.shipName,
    this.shipEmail,
    this.shipPhone,
    this.imageFile,
  });
}

/// API spec: `^\+?[0-9\s\-]{7,20}$` (LAST EDITES transport contacts).
final _contactPhonePattern = RegExp(r'^\+?[0-9\s\-]{7,20}$');

bool isValidContactPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  return _contactPhonePattern.hasMatch(trimmed);
}

class SavedDeliveryContacts {
  const SavedDeliveryContacts({
    required this.pickupName,
    required this.pickupPhone,
    required this.dropName,
    required this.dropPhone,
  });

  final String pickupName;
  final String pickupPhone;
  final String dropName;
  final String dropPhone;
}

/// Keeps the last saved pickup/drop contacts. Cart GET often omits these fields.
final savedDeliveryContactsProvider =
    StateProvider<SavedDeliveryContacts?>((ref) => null);

const _pickupNameKey = 'buyer_pickup_contact_name';
const _pickupPhoneKey = 'buyer_pickup_contact_phone';
const _dropNameKey = 'buyer_drop_contact_name';
const _dropPhoneKey = 'buyer_drop_contact_phone';

Future<SavedDeliveryContacts?> loadSavedDeliveryContacts() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = SavedDeliveryContacts(
    pickupName: prefs.getString(_pickupNameKey) ?? '',
    pickupPhone: prefs.getString(_pickupPhoneKey) ?? '',
    dropName: prefs.getString(_dropNameKey) ?? '',
    dropPhone: prefs.getString(_dropPhoneKey) ?? '',
  );
  if (saved.pickupName.isEmpty &&
      saved.pickupPhone.isEmpty &&
      saved.dropName.isEmpty &&
      saved.dropPhone.isEmpty) {
    return null;
  }
  return saved;
}

Future<void> persistSavedDeliveryContacts(SavedDeliveryContacts saved) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pickupNameKey, saved.pickupName);
  await prefs.setString(_pickupPhoneKey, saved.pickupPhone);
  await prefs.setString(_dropNameKey, saved.dropName);
  await prefs.setString(_dropPhoneKey, saved.dropPhone);
}

String firstFilledContact(String? primary, String? fallback) {
  final a = primary?.trim() ?? '';
  if (a.isNotEmpty && a != 'null') return a;
  final b = fallback?.trim() ?? '';
  if (b.isNotEmpty && b != 'null') return b;
  return '';
}

({String pickupName, String pickupPhone, String dropName, String dropPhone})
    resolveDeliveryContacts({
  required String? pickupName,
  required String? pickupPhone,
  required String? dropName,
  required String? dropPhone,
  required String? shipName,
  required String? shipPhone,
  SavedDeliveryContacts? saved,
}) {
  return (
    pickupName: firstFilledContact(pickupName, saved?.pickupName),
    pickupPhone: firstFilledContact(pickupPhone, saved?.pickupPhone),
    dropName: firstFilledContact(
      firstFilledContact(dropName, shipName),
      saved?.dropName,
    ),
    dropPhone: firstFilledContact(
      firstFilledContact(dropPhone, shipPhone),
      saved?.dropPhone,
    ),
  );
}

class UserUpdateService {
  final Ref ref;
  UserUpdateService(this.ref);

  /// ✅ সাধারণ-উদ্দেশ্য ফাংশন: যেসব ফিল্ড দেবেন, কেবল সেগুলোই যাবে (multipart, image optional)
  static const Set<String> _allowedKeys = {
    'ship_address', 'ship_city', 'postcode', 'ship_zone', 'ship_state', 'ship_town', 'ship_country',
    'ship_name', 'ship_email', 'ship_phone', 'ship_location',
    'pickup_contact_name', 'pickup_contact_phone',
    'drop_contact_name', 'drop_contact_phone',
    'sign_post',
    // চাইলে প্রোফাইলের জেনেরিক ফিল্ডও
    'address', 'state', 'country', 'location', 'name', 'email', 'phone',
  };

  Future<void> updateUserFields({
    required Map<String, String> fields,
    File? imageFile,
    double? latitude,
    double? longitude,
  }) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) {
      throw Exception('Token not found');
    }

    // কেবল valid + non-empty keys পাঠাবো
    final clean = <String, String>{};
    fields.forEach((k, v) {
      final key = k.trim();
      final val = v.trim();
      if (val.isNotEmpty && _allowedKeys.contains(key)) {
        clean[key] = val;
      }
    });

    if (clean.isEmpty && imageFile == null && latitude == null && longitude == null) {
      throw Exception('No valid fields to update');
    }

    final uri = Uri.parse(BuyerAPIController.user_update);
    final req = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['token'] = token
      ..fields.addAll(clean);

    // Add latitude and longitude if provided
    if (latitude != null) {
      req.fields['ship_latitude'] = latitude.toString();
    }
    if (longitude != null) {
      req.fields['ship_longitude'] = longitude.toString();
    }

    if (imageFile != null) {
      req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.statusCode}');
    }
    final map = jsonDecode(body) as Map<String, dynamic>;
    if ('${map['status']}' != 'success') {
      throw Exception(map['message']?.toString() ?? 'Update failed');
    }
  }

  /// (আপনার আগে থাকা) শুধুই শিপিং-পেলোডে কাজ করা ফাংশন
  Future<void> updateShippingAddress(ShippingUpdatePayload p) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) {
      throw Exception('Token not found');
    }

    final uri = Uri.parse(BuyerAPIController.user_update);
    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    req.headers['token'] = token;

    req.fields['ship_address'] = p.shipAddress;
    req.fields['ship_city'] = p.shipCity;

    void addIf(String key, String? v) {
      if (v != null && v.trim().isNotEmpty) req.fields[key] = v.trim();
    }

    addIf('postcode', p.postcode);
    addIf('ship_state', p.shipState);
    addIf('ship_country', p.shipCountry);

    addIf('ship_name', p.shipName);
    addIf('ship_email', p.shipEmail);
    addIf('ship_phone', p.shipPhone);

    if (p.imageFile != null) {
      req.files.add(
        await http.MultipartFile.fromPath('image', p.imageFile!.path),
      );
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.statusCode}');
    }
    final map = jsonDecode(body) as Map<String, dynamic>;
    if ('${map['status']}' != 'success') {
      throw Exception(map['message']?.toString() ?? 'Update failed');
    }
  }
}

final cartUpdatingIdsProvider = StateProvider<Set<int>>((ref) => <int>{});
