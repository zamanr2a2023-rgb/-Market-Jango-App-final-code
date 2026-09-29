import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:market_jango/features/auth/data/register_api_headers.dart';
import '../model/car_info_model.dart';

final driverRegisterProvider =
    StateNotifierProvider<DriverRegisterNotifier, AsyncValue<DriverRegisterModel?>>(
        (ref) => DriverRegisterNotifier());

class DriverRegisterNotifier extends StateNotifier<AsyncValue<DriverRegisterModel?>> {
  DriverRegisterNotifier() : super(const AsyncValue.data(null));

  Future<void> registerDriver({
    required String url,
    required String carName,
    required String numberPlate,
    required String price,
    required String transportType,
    required List<File> files,
    required String zone,
    required String stateName,
    required String town,
    String? routeId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final plate = numberPlate.trim();
      if (plate.isEmpty) throw 'Number plate is required';

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers
          .addAll(await registerMultipartHeaders(userType: 'driver'));

      request.fields['car_name'] = carName.trim();
      request.fields['number_plate'] = plate;
      request.fields['price'] = price.trim();
      request.fields['transport_type'] = transportType.trim();
      request.fields['zone'] = zone.trim();
      request.fields['state'] = stateName.trim();
      request.fields['town'] = town.trim();

      final route = routeId?.trim() ?? '';
      if (route.isNotEmpty) {
        request.fields['route_id'] = route;
      }

      for (var file in files) {
        final filename = file.path.split('/').last;
        final fileStream = await http.MultipartFile.fromPath(
          'files[]',
          file.path,
          filename: filename,
        );
        request.files.add(fileStream);
      }
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          json['status'] == 'success') {
        Logger().i('🚗 Driver Register Response: $body');
        final driver = DriverRegisterModel.fromJson(json['data']);
        state = AsyncValue.data(driver);
      } else {
        throw json['message'] ?? 'Driver registration failed';
      }
    } catch (e, st) {
      Logger().e('⛔ Driver Register Error: $e');
      state = AsyncValue.error(e, st);
    }
  }
}
