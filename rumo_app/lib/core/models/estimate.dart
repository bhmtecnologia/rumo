class Estimate {
  final double distanceKm;
  final int durationMin;
  final int estimatedPriceCents;
  final String formattedPrice;

  const Estimate({
    required this.distanceKm,
    required this.durationMin,
    required this.estimatedPriceCents,
    required this.formattedPrice,
  });

  factory Estimate.fromJson(Map<String, dynamic> json) {
    return Estimate(
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMin: json['durationMin'] as int,
      estimatedPriceCents: json['estimatedPriceCents'] as int,
      formattedPrice: json['formattedPrice'] as String,
    );
  }
}
