int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _s(dynamic v) => v?.toString().trim() ?? '';

Map<String, dynamic>? _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Paginated list from `GET /api/driver/deliveries`.
class DriverAssignmentsPage {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final List<DriverAssignmentRow> items;

  const DriverAssignmentsPage({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.items,
  });

  static DriverAssignmentsPage parse(Map<String, dynamic>? j) {
    if (j == null) {
      return const DriverAssignmentsPage(
        currentPage: 1,
        lastPage: 1,
        perPage: 15,
        total: 0,
        items: [],
      );
    }
    final list = (j['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => DriverAssignmentRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return DriverAssignmentsPage(
      currentPage: _toInt(j['current_page'], d: 1),
      lastPage: _toInt(j['last_page'], d: 1),
      perPage: _toInt(j['per_page'], d: 15),
      total: _toInt(j['total']),
      items: list,
    );
  }
}

/// Pickup or drop-off place on a New Order card (`doc/details.md`).
class DriverAssignmentPlace {
  final String label;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  const DriverAssignmentPlace({
    required this.label,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory DriverAssignmentPlace.fromJson(
    Map<String, dynamic>? j, {
    required String fallbackLabel,
  }) {
    j ??= const {};
    return DriverAssignmentPlace(
      label: _s(j['label']).isEmpty ? fallbackLabel : _s(j['label']),
      name: _s(j['name']),
      address: _s(j['address']),
      latitude: _toDoubleOrNull(j['latitude']),
      longitude: _toDoubleOrNull(j['longitude']),
    );
  }

  bool get hasCoords => latitude != null && longitude != null;
}

class DriverAssignmentMetrics {
  final double? distanceKm;
  final int? estimatedTimeMinutes;
  final double? paymentAmount;
  final double? totalPay;
  final String paymentCurrency;
  final String paymentMethod;

  const DriverAssignmentMetrics({
    this.distanceKm,
    this.estimatedTimeMinutes,
    this.paymentAmount,
    this.totalPay,
    required this.paymentCurrency,
    required this.paymentMethod,
  });

  factory DriverAssignmentMetrics.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return DriverAssignmentMetrics(
      distanceKm: _toDoubleOrNull(j['distance_km']),
      estimatedTimeMinutes: _toIntOrNull(j['estimated_time_minutes']),
      paymentAmount: _toDoubleOrNull(j['payment_amount']),
      totalPay: _toDoubleOrNull(j['total_pay']),
      paymentCurrency: _s(j['payment_currency']),
      paymentMethod: _s(j['payment_method']),
    );
  }

  String get distanceLabel {
    if (distanceKm == null) return '—';
    final v = distanceKm!;
    final n = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '$n km';
  }

  String get etaLabel {
    if (estimatedTimeMinutes == null) return '—';
    return '$estimatedTimeMinutes mins';
  }

  String get paymentLabel {
    final amount = paymentAmount;
    if (amount == null) return '—';
    final formatted = amount.toStringAsFixed(2);
    switch (paymentCurrency.toUpperCase()) {
      case 'PHP':
        return '₱$formatted';
      case 'USD':
        return '\$$formatted';
      case 'KES':
        return 'KSh $formatted';
      case 'EUR':
        return '€$formatted';
      case '':
        return formatted;
      default:
        return '$formatted $paymentCurrency';
    }
  }
}

class DriverAssignmentProduct {
  final int id;
  final String name;
  final int qty;
  final String? image;

  const DriverAssignmentProduct({
    required this.id,
    required this.name,
    required this.qty,
    this.image,
  });

  factory DriverAssignmentProduct.fromJson(Map<String, dynamic> j) {
    return DriverAssignmentProduct(
      id: _toInt(j['id']),
      name: _s(j['name']),
      qty: _toInt(j['qty'] ?? j['quantity'], d: 1),
      image: _s(j['image']).isEmpty ? null : _s(j['image']),
    );
  }
}

class DriverAssignmentPackage {
  final String title;
  final String? subtitle;
  final int itemCount;
  final int quantity;
  final List<DriverAssignmentProduct> products;

  const DriverAssignmentPackage({
    required this.title,
    this.subtitle,
    required this.itemCount,
    required this.quantity,
    required this.products,
  });

  factory DriverAssignmentPackage.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    final products = (j['products'] as List? ?? [])
        .whereType<Map>()
        .map((e) => DriverAssignmentProduct.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final qty = _toInt(j['quantity'] ?? j['item_count']);
    return DriverAssignmentPackage(
      title: _s(j['title']),
      subtitle: _s(j['subtitle']).isEmpty ? null : _s(j['subtitle']),
      itemCount: _toInt(j['item_count'], d: qty),
      quantity: qty,
      products: products,
    );
  }

  String get itemCountLabel {
    final n = itemCount > 0 ? itemCount : quantity;
    if (n <= 0) return '';
    return n == 1 ? '1 Item' : '$n Items';
  }
}

class DriverAssignmentVendor {
  final int? id;
  final String businessName;
  final String contactName;
  final String phone;

  const DriverAssignmentVendor({
    this.id,
    required this.businessName,
    required this.contactName,
    required this.phone,
  });

  factory DriverAssignmentVendor.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return DriverAssignmentVendor(
      id: _toIntOrNull(j['id']),
      businessName: _s(j['business_name']),
      contactName: _s(j['contact_name']),
      phone: _s(j['phone']),
    );
  }

  bool get isEmpty =>
      businessName.isEmpty && contactName.isEmpty && phone.isEmpty;
}

class DriverAssignmentBuyer {
  final String name;
  final String phone;
  final String? email;

  const DriverAssignmentBuyer({
    required this.name,
    required this.phone,
    this.email,
  });

  factory DriverAssignmentBuyer.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    final email = _s(j['email']);
    return DriverAssignmentBuyer(
      name: _s(j['name']),
      phone: _s(j['phone']),
      email: email.isEmpty ? null : email,
    );
  }

  bool get isEmpty => name.isEmpty && phone.isEmpty;
}

class DriverAssignmentActions {
  final bool canAccept;
  final bool canReject;

  const DriverAssignmentActions({
    required this.canAccept,
    required this.canReject,
  });

  factory DriverAssignmentActions.fromJson(
    Map<String, dynamic>? j, {
    required String status,
  }) {
    j ??= const {};
    final pending = status == 'pending';
    return DriverAssignmentActions(
      canAccept: j.containsKey('can_accept')
          ? _toBool(j['can_accept'])
          : pending,
      canReject: j.containsKey('can_reject')
          ? _toBool(j['can_reject'])
          : pending,
    );
  }
}

class DriverLatestLocation {
  final double? latitude;
  final double? longitude;
  final double? heading;
  final double? speed;
  final String? recordedAt;

  const DriverLatestLocation({
    this.latitude,
    this.longitude,
    this.heading,
    this.speed,
    this.recordedAt,
  });

  factory DriverLatestLocation.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const DriverLatestLocation();
    }
    final at = _s(j['recorded_at']);
    return DriverLatestLocation(
      latitude: _toDoubleOrNull(j['latitude']),
      longitude: _toDoubleOrNull(j['longitude']),
      heading: _toDoubleOrNull(j['heading']),
      speed: _toDoubleOrNull(j['speed']),
      recordedAt: at.isEmpty ? null : at,
    );
  }
}

/// One row in the deliveries list / detail payload (`doc/details.md`).
class DriverAssignmentRow {
  final int id;
  final String status;
  final String orderNumber;
  final bool isNew;
  final String badge;
  final String assignmentSource;
  final String sourceColorKey;
  final int acceptTimeoutSeconds;
  final int? invoiceItemId;
  final DriverAssignmentPlace pickup;
  final DriverAssignmentPlace dropoff;
  final DriverAssignmentMetrics metrics;
  final DriverAssignmentPackage package;
  final DriverAssignmentVendor vendor;
  final DriverAssignmentBuyer buyer;
  final DriverAssignmentActions actions;
  final DriverLatestLocation? latestLocation;
  final Map<String, dynamic> raw;

  DriverAssignmentRow({
    required this.id,
    required this.status,
    required this.orderNumber,
    required this.isNew,
    required this.badge,
    required this.assignmentSource,
    required this.sourceColorKey,
    required this.acceptTimeoutSeconds,
    this.invoiceItemId,
    required this.pickup,
    required this.dropoff,
    required this.metrics,
    required this.package,
    required this.vendor,
    required this.buyer,
    required this.actions,
    this.latestLocation,
    required this.raw,
  });

  factory DriverAssignmentRow.fromJson(Map<String, dynamic> j) {
    final status = _s(j['status']).toLowerCase();
    final id = _toInt(j['assignment_id'] ?? j['id']);
    final orderNumber = _s(j['order_number']);
    final loc = _map(j['latest_location']);
    return DriverAssignmentRow(
      id: id,
      status: status,
      orderNumber: orderNumber,
      isNew: _toBool(j['is_new']),
      badge: _s(j['badge']),
      assignmentSource: _s(j['assignment_source']),
      sourceColorKey: _s(j['source_color_key']).isEmpty
          ? 'other'
          : _s(j['source_color_key']),
      acceptTimeoutSeconds: _toInt(j['accept_timeout_seconds'], d: 30),
      invoiceItemId: _toIntOrNull(j['invoice_item_id']),
      pickup: DriverAssignmentPlace.fromJson(
        _map(j['pickup']),
        fallbackLabel: 'From (Pickup)',
      ),
      dropoff: DriverAssignmentPlace.fromJson(
        _map(j['dropoff']),
        fallbackLabel: 'To (Drop-off)',
      ),
      metrics: DriverAssignmentMetrics.fromJson(_map(j['metrics'])),
      package: DriverAssignmentPackage.fromJson(_map(j['package'])),
      vendor: DriverAssignmentVendor.fromJson(_map(j['vendor'])),
      buyer: DriverAssignmentBuyer.fromJson(_map(j['buyer'])),
      actions: DriverAssignmentActions.fromJson(
        _map(j['actions']),
        status: status,
      ),
      latestLocation: loc == null ? null : DriverLatestLocation.fromJson(loc),
      raw: Map<String, dynamic>.from(j),
    );
  }

  String get displayOrderNumber {
    if (orderNumber.isNotEmpty) {
      return orderNumber.startsWith('#') ? orderNumber : '#$orderNumber';
    }
    return '#$id';
  }

  bool get showNewBadge {
    if (status != 'pending') return false;
    if (isNew) return true;
    return badge.toUpperCase() == 'NEW';
  }

  String get statusLabel {
    if (showNewBadge) {
      return badge.isNotEmpty ? badge : 'New';
    }
    if (badge.isNotEmpty && status == 'pending') return badge;
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_transit':
        return 'In transit';
      case 'delivered':
        return 'Delivered';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  String get displaySubtitle {
    final from = pickup.name.isNotEmpty ? pickup.name : pickup.address;
    final to = dropoff.name.isNotEmpty ? dropoff.name : dropoff.address;
    if (from.isNotEmpty || to.isNotEmpty) {
      return '${from.isNotEmpty ? from : "—"} → ${to.isNotEmpty ? to : "—"}';
    }
    return 'Assignment #$id';
  }
}
