/// Área permitida (círculo lat/lng/radius) para origem ou destino.
class AllowedArea {
  final String id;
  final String type;
  final double lat;
  final double lng;
  final double radiusKm;
  final String? label;

  const AllowedArea({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    this.radiusKm = 5,
    this.label,
  });

  factory AllowedArea.fromJson(Map<String, dynamic> json) {
    return AllowedArea(
      id: json['id'] as String,
      type: json['type'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble() ?? 5,
      label: json['label'] as String?,
    );
  }
}

class CostCenter {
  final String id;
  final String unitId;
  final String? unitName;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool blocked;
  final int? monthlyLimitCents;
  final double? maxKm;
  final String? allowedTimeStart;
  final String? allowedTimeEnd;
  final List<AllowedArea> allowedAreas;

  const CostCenter({
    required this.id,
    required this.unitId,
    this.unitName,
    required this.name,
    this.createdAt,
    this.updatedAt,
    this.blocked = false,
    this.monthlyLimitCents,
    this.maxKm,
    this.allowedTimeStart,
    this.allowedTimeEnd,
    this.allowedAreas = const [],
  });

  factory CostCenter.fromJson(Map<String, dynamic> json) {
    final areas = json['allowedAreas'];
    return CostCenter(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      unitName: json['unitName'] as String?,
      name: json['name'] as String,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      blocked: json['blocked'] as bool? ?? false,
      monthlyLimitCents: json['monthlyLimitCents'] as int?,
      maxKm: json['maxKm'] != null ? (json['maxKm'] as num).toDouble() : null,
      allowedTimeStart: json['allowedTimeStart'] as String?,
      allowedTimeEnd: json['allowedTimeEnd'] as String?,
      allowedAreas: areas is List
          ? areas.map((e) => AllowedArea.fromJson(e as Map<String, dynamic>)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'name': name,
      };
}
