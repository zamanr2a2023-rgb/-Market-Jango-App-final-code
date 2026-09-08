import 'dart:convert';

VendorIncomeResponse vendorIncomeResponseFromJson(String s) =>
    VendorIncomeResponse.fromJson(jsonDecode(s) as Map<String, dynamic>);

class VendorIncomeResponse {
  final String status;
  final VendorIncomeData data;

  VendorIncomeResponse({required this.status, required this.data});

  factory VendorIncomeResponse.fromJson(Map<String, dynamic> json) {
    final dataJson =
        json['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return VendorIncomeResponse(
      status: (json['status'] ?? '').toString(),
      data: VendorIncomeData.fromJson(dataJson),
    );
  }
}

class VendorIncomeData {
  /// API: "total_days": "7"
  final int totalDays;

  /// API: "total_revenue": 0
  final double totalRevenue;

  /// API: "total_orders": 0
  final int totalOrders;

  /// API: "total_clicks": 0
  final int totalClicks;

  /// API: "conversion_rate": 0
  final double conversionRate;

  /// STEP_03 optional debt KPIs when backend includes them.
  final double? debtSales;
  final double? outstandingDebt;
  final double? paidDebt;

  VendorIncomeData({
    required this.totalDays,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalClicks,
    required this.conversionRate,
    this.debtSales,
    this.outstandingDebt,
    this.paidDebt,
  });

  factory VendorIncomeData.fromJson(Map<String, dynamic> j) {
    double? opt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return VendorIncomeData(
      totalDays: _toInt(j['total_days']),
      totalRevenue: _toDouble(j['total_revenue']),
      totalOrders: _toInt(j['total_orders']),
      totalClicks: _toInt(j['total_clicks']),
      conversionRate: _toDouble(j['conversion_rate']),
      debtSales: opt(
        j['debt_sales'] ?? j['total_debt_sales'] ?? j['debt_revenue'],
      ),
      outstandingDebt: opt(
        j['outstanding_debt'] ?? j['debt_outstanding'] ?? j['remaining_debt'],
      ),
      paidDebt: opt(j['paid_debt'] ?? j['debt_paid'] ?? j['total_debt_paid']),
    );
  }
}

int _toInt(dynamic v) =>
    v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

double _toDouble(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
