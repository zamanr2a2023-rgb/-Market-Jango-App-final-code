class VendorPromotion {
  final int id;
  final String title;
  final String content;
  final String? image;
  final String zone;
  final String status;
  final int? vendorId;
  final String? createdAt;

  const VendorPromotion({
    required this.id,
    required this.title,
    this.content = '',
    this.image,
    this.zone = '',
    this.status = '',
    this.vendorId,
    this.createdAt,
  });

  factory VendorPromotion.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return VendorPromotion(
      id: toInt(j['id']),
      title: j['title']?.toString() ?? j['name']?.toString() ?? '',
      content: j['content']?.toString() ??
          j['text']?.toString() ??
          j['description']?.toString() ??
          '',
      image: j['image']?.toString(),
      zone: j['zone']?.toString() ?? j['ship_zone']?.toString() ?? '',
      status: j['status']?.toString() ??
          j['approval_status']?.toString() ??
          '',
      vendorId: toInt(j['vendor_id']) > 0 ? toInt(j['vendor_id']) : null,
      createdAt: j['created_at']?.toString(),
    );
  }

  bool get isPending {
    final s = status.toLowerCase();
    return s.isEmpty ||
        s == 'pending' ||
        s == 'awaiting' ||
        s == 'submitted' ||
        s == '0';
  }

  bool get isApproved {
    final s = status.toLowerCase();
    return s == 'approved' || s == 'active' || s == '1';
  }
}
