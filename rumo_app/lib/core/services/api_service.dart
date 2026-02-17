import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rumo_app/core/config.dart';
import 'package:rumo_app/core/models/estimate.dart';
import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  ApiService._();

  String get _base => kApiBaseUrl;

  Map<String, String> get _headers {
    final token = AuthService().token;
    final map = <String, String>{'Content-Type': 'application/json'};
    if (token != null) map['Authorization'] = 'Bearer $token';
    return map;
  }

  /// Mensagem de erro a partir da resposta ou exceção (rede/conexão).
  static String errorMessage(dynamic err, [http.Response? res, String fallback = 'Erro na requisição']) {
    if (res != null && res.body.isNotEmpty) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final msg = data?['error'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      } catch (_) {}
    }
    final s = err?.toString() ?? '';
    if (s.contains('Connection refused') || s.contains('Failed host lookup') || s.contains('SocketException')) {
      return 'Não foi possível conectar ao servidor. Verifique se o backend está rodando em $kApiBaseUrl';
    }
    if (s.contains('Connection timed out') || s.contains('TimeoutException')) {
      return 'Tempo esgotado. Verifique se o backend está acessível.';
    }
    return fallback;
  }

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

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$_base/rides/estimate'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw Exception(errorMessage(e, null, 'Erro ao calcular preço'));
    }
    if (res.statusCode == 401) {
      await AuthService().logout();
      AuthService.onUnauthorized?.call();
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (res.statusCode != 200) {
      throw Exception(errorMessage(null, res, 'Erro ao calcular preço'));
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

    http.Response res;
    try {
      res = await http.post(
        Uri.parse('$_base/rides'),
        headers: _headers,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw Exception(errorMessage(e, null, 'Erro ao solicitar corrida'));
    }
    if (res.statusCode == 401) {
      await AuthService().logout();
      AuthService.onUnauthorized?.call();
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(errorMessage(null, res, 'Erro ao solicitar corrida'));
    }
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Lista corridas (para backoffice/central).
  Future<List<RideListItem>> listRides() async {
    http.Response res;
    try {
      res = await http.get(Uri.parse('$_base/rides'), headers: _headers);
    } catch (e) {
      throw Exception(errorMessage(e, null, 'Erro ao listar corridas'));
    }
    if (res.statusCode == 401) {
      await AuthService().logout();
      AuthService.onUnauthorized?.call();
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (res.statusCode != 200) {
      throw Exception(errorMessage(null, res, 'Erro ao listar corridas'));
    }
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data
        .map((e) => RideListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
