/// `GET /api/vendor-dashboard/analytics` — profit KPIs (Section 2.5).
class VendorDashboardAnalytics {
  final double? totalProfit;
  final double? totalRevenue;
  final int? totalOrders;

  const VendorDashboardAnalytics({
    this.totalProfit,
    this.totalRevenue,
    this.totalOrders,
  });

  factory VendorDashboardAnalytics.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic>
        ? data
        : (data is Map
            ? Map<String, dynamic>.from(data)
            : Map<String, dynamic>.from(json));

    return VendorDashboardAnalytics(
      totalProfit: _firstDouble(map, const [
        'total_profit',
        'profit',
        'net_profit',
      ]),
      totalRevenue: _firstDouble(map, const [
        'total_revenue',
        'revenue',
      ]),
      totalOrders: _firstInt(map, const [
        'total_orders',
        'orders',
      ]),
    );
  }
}

double? _firstDouble(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (!j.containsKey(k) || j[k] == null) continue;
    final v = j[k];
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
  return null;
}

int? _firstInt(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (!j.containsKey(k) || j[k] == null) continue;
    final v = j[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
  return null;
}
