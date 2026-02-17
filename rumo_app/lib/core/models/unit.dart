class Unit {
  final String id;
  final String name;
  final int costCenterCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Unit({
    required this.id,
    required this.name,
    this.costCenterCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      name: json['name'] as String,
      costCenterCount: (json['costCenterCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'costCenterCount': costCenterCount,
      };
}
