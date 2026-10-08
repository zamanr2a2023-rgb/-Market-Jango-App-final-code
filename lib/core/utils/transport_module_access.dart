/// POLISH — buyer + transport same login (`modules.transport`, transports row).
library;

bool _isTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

/// Reads `modules.transport` from stored login / refreshed user JSON.
bool? modulesTransportFlag(Map<String, dynamic>? userJson) {
  if (userJson == null) return null;
  final modules = userJson['modules'];
  if (modules is! Map) return null;
  final raw = modules['transport'];
  if (raw == null) return null;
  return _isTruthy(raw);
}

/// Whether the current session may use shipment / transport-wallet APIs.
bool canUseTransportModule(Map<String, dynamic>? userJson) {
  if (userJson == null) return false;

  final userType =
      (userJson['user_type'] ?? userJson['userType'])?.toString().trim().toLowerCase() ??
          '';
  if (userType == 'transport') return true;

  final modulesFlag = modulesTransportFlag(userJson);
  if (modulesFlag == true) return true;

  final transport = userJson['transport'];
  if (transport is Map) {
    final id = transport['id'];
    final parsedId = id is num ? id.toInt() : int.tryParse(id?.toString() ?? '');
    if (parsedId != null && parsedId > 0) return true;
  }

  if (userType == 'buyer' && modulesFlag == false) return false;

  final transports = userJson['transports'];
  if (transports is List && transports.isNotEmpty) return true;
  if (transports is Map && transports.isNotEmpty) return true;

  return false;
}

/// Buyer who can enable transport (buyer account, module not yet active).
bool buyerMayEnableTransport(Map<String, dynamic>? userJson) {
  if (userJson == null) return false;
  final userType =
      (userJson['user_type'] ?? userJson['userType'])?.toString().trim().toLowerCase() ??
          '';
  if (userType != 'buyer') return false;
  return !canUseTransportModule(userJson);
}
