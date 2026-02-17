class CostCenter {
  final String id;
  final String unitId;
  final String? unitName;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CostCenter({
    required this.id,
    required this.unitId,
    this.unitName,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory CostCenter.fromJson(Map<String, dynamic> json) {
    return CostCenter(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      unitName: json['unitName'] as String?,
      name: json['name'] as String,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'name': name,
      };
}
