class Ride {
  final String id;
  final String status;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final int? estimatedPriceCents;
  final String? formattedPrice;
  final double? estimatedDistanceKm;
  final int? estimatedDurationMin;
  final String? driverUserId;
  final String? driverName;
  final String? vehiclePlate;
  final DateTime? acceptedAt;
  final DateTime? driverArrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? actualPriceCents;
  final double? actualDistanceKm;
  final int? actualDurationMin;
  final int? rating;
  final String? cancelReason;
  final String? requestedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Ride({
    required this.id,
    required this.status,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.estimatedPriceCents,
    this.formattedPrice,
    this.estimatedDistanceKm,
    this.estimatedDurationMin,
    this.driverUserId,
    this.driverName,
    this.vehiclePlate,
    this.acceptedAt,
    this.driverArrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.actualPriceCents,
    this.actualDistanceKm,
    this.actualDurationMin,
    this.rating,
    this.cancelReason,
    this.requestedByUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as String,
      status: json['status'] as String,
      pickupAddress: json['pickupAddress'] as String?,
      destinationAddress: json['destinationAddress'] as String?,
      pickupLat: _toDouble(json['pickupLat']),
      pickupLng: _toDouble(json['pickupLng']),
      destinationLat: _toDouble(json['destinationLat']),
      destinationLng: _toDouble(json['destinationLng']),
      estimatedPriceCents: json['estimatedPriceCents'] as int?,
      formattedPrice: json['formattedPrice'] as String?,
      estimatedDistanceKm: _toDouble(json['estimatedDistanceKm']),
      estimatedDurationMin: json['estimatedDurationMin'] as int?,
      driverUserId: json['driverUserId'] as String?,
      driverName: json['driverName'] as String?,
      vehiclePlate: json['vehiclePlate'] as String?,
      acceptedAt: _parseDate(json['acceptedAt']),
      driverArrivedAt: _parseDate(json['driverArrivedAt']),
      startedAt: _parseDate(json['startedAt']),
      completedAt: _parseDate(json['completedAt']),
      cancelledAt: _parseDate(json['cancelledAt']),
      actualPriceCents: json['actualPriceCents'] as int?,
      actualDistanceKm: _toDouble(json['actualDistanceKm']),
      actualDurationMin: json['actualDurationMin'] as int?,
      rating: json['rating'] as int?,
      cancelReason: json['cancelReason'] as String?,
      requestedByUserId: json['requestedByUserId'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  bool get isFinished => status == 'completed' || status == 'cancelled';
  bool get isRequested => status == 'requested';
  bool get isAccepted => status == 'accepted';
  bool get isDriverArrived => status == 'driver_arrived';
  bool get isInProgress => status == 'in_progress';
}
