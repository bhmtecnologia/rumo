class RequestReason {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RequestReason({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory RequestReason.fromJson(Map<String, dynamic> json) {
    return RequestReason(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
