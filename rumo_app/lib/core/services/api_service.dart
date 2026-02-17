import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rumo_app/core/config.dart';
import 'package:rumo_app/core/models/estimate.dart';
import 'package:rumo_app/core/models/ride.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  ApiService._();

  String get _base => kApiBaseUrl;

  Future<Estimate> getEstimate({
    required String pickupAddress,
    required String destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final body = <String, dynamic>{
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
    };
    if (pickupLat != null && pickupLng != null) {
      body['pickupLat'] = pickupLat;
      body['pickupLng'] = pickupLng;
    }
    if (destinationLat != null && destinationLng != null) {
      body['destinationLat'] = destinationLat;
      body['destinationLng'] = destinationLng;
    }

    final res = await http.post(
      Uri.parse('$_base/rides/estimate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? 'Erro ao calcular preço');
    }
    return Estimate.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Ride> createRide({
    required String pickupAddress,
    required String destinationAddress,
    required int estimatedPriceCents,
    required double estimatedDistanceKm,
    required int estimatedDurationMin,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final body = <String, dynamic>{
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'estimatedPriceCents': estimatedPriceCents,
      'estimatedDistanceKm': estimatedDistanceKm,
      'estimatedDurationMin': estimatedDurationMin,
    };
    if (pickupLat != null && pickupLng != null) {
      body['pickupLat'] = pickupLat;
      body['pickupLng'] = pickupLng;
    }
    if (destinationLat != null && destinationLng != null) {
      body['destinationLat'] = destinationLat;
      body['destinationLng'] = destinationLng;
    }

    final res = await http.post(
      Uri.parse('$_base/rides'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? 'Erro ao solicitar corrida');
    }
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
