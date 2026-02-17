class Ride {
  final String id;
  final String status;
  final String? pickupAddress;
  final String? destinationAddress;
  final int? estimatedPriceCents;
  final String? formattedPrice;

  const Ride({
    required this.id,
    required this.status,
    this.pickupAddress,
    this.destinationAddress,
    this.estimatedPriceCents,
    this.formattedPrice,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as String,
      status: json['status'] as String,
      pickupAddress: json['pickupAddress'] as String?,
      destinationAddress: json['destinationAddress'] as String?,
      estimatedPriceCents: json['estimatedPriceCents'] as int?,
      formattedPrice: json['formattedPrice'] as String?,
    );
  }
}
