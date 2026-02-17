/// Corrida no formato da listagem (backoffice/central): inclui coordenadas para mapa e duração (SLA).
class RideListItem {
  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;
  final int estimatedPriceCents;
  final String formattedPrice;
  final DateTime? createdAt;

  const RideListItem({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    required this.estimatedPriceCents,
    required this.formattedPrice,
    this.createdAt,
  });

  factory RideListItem.fromJson(Map<String, dynamic> json) {
    return RideListItem(
      id: json['id'] as String,
      status: json['status'] as String,
      pickupAddress: (json['pickupAddress'] ?? json['pickup_address'] ?? '') as String,
      destinationAddress: (json['destinationAddress'] ?? json['destination_address'] ?? '') as String,
      pickupLat: _toDouble(json['pickupLat'] ?? json['pickup_lat']),
      pickupLng: _toDouble(json['pickupLng'] ?? json['pickup_lng']),
      destinationLat: _toDouble(json['destinationLat'] ?? json['destination_lat']),
      destinationLng: _toDouble(json['destinationLng'] ?? json['destination_lng']),
      estimatedDistanceKm: _toDouble(json['estimatedDistanceKm'] ?? json['estimated_distance_km']),
      estimatedDurationMin: json['estimatedDurationMin'] as int? ?? json['estimated_duration_min'] as int?,
      estimatedPriceCents: json['estimatedPriceCents'] as int? ?? json['estimated_price_cents'] as int? ?? 0,
      formattedPrice: (json['formattedPrice'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Tempo desde a criação (para SLA no backoffice).
  String get timeAgo {
    if (createdAt == null) return '—';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}
