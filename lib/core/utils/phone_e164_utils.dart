import 'dart:convert';

/// Builds a clean E.164 phone string for API calls.
String toE164Phone({
  required String countryCode,
  required String nationalNumber,
}) {
  var cc = countryCode.replaceAll(RegExp(r'\D'), '');
  var nn = nationalNumber.replaceAll(RegExp(r'[^\d]'), '');

  if (cc.isEmpty || nn.isEmpty) return '';

  // User pasted full international number into the field.
  if (nn.startsWith('00$cc')) {
    nn = nn.substring(2 + cc.length);
  } else if (nn.startsWith('0$cc')) {
    nn = nn.substring(1 + cc.length);
  } else if (nn.startsWith(cc)) {
    nn = nn.substring(cc.length);
  }

  // Local leading zero (e.g. 0757… → 757…).
  if (nn.startsWith('0') && nn.length > 1) {
    nn = nn.substring(1);
  }

  return '+$cc$nn';
}

String parseApiErrorMessage(String body, int statusCode) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final message = decoded['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
  } catch (_) {}
  return 'HTTP $statusCode';
}
