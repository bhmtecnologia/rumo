import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rumo_app/core/config.dart';
import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/models/estimate.dart';
import 'package:rumo_app/core/models/request_reason.dart';
import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/models/unit.dart';
import 'package:rumo_app/core/models/user_list_item.dart';
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

  Future<void> _check401(http.Response res) async {
    if (res.statusCode == 401) {
      await AuthService().logout();
      AuthService.onUnauthorized?.call();
      throw Exception('Sessão expirada. Faça login novamente.');
    }
  }

  // --- Units (Fase 2) ---
  Future<List<Unit>> listUnits() async {
    final res = await http.get(Uri.parse('$_base/units'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar unidades'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map((e) => Unit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Unit> createUnit(String name) async {
    final res = await http.post(
      Uri.parse('$_base/units'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao criar unidade'));
    return Unit.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Unit> updateUnit(String id, String name) async {
    final res = await http.patch(
      Uri.parse('$_base/units/$id'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar unidade'));
    return Unit.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteUnit(String id) async {
    final res = await http.delete(Uri.parse('$_base/units/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 204) throw Exception(errorMessage(null, res, 'Erro ao excluir unidade'));
  }

  // --- Cost centers (Fase 2) ---
  Future<List<CostCenter>> listCostCenters({String? unitId}) async {
    var uri = Uri.parse('$_base/cost-centers');
    if (unitId != null) uri = uri.replace(queryParameters: {'unitId': unitId});
    final res = await http.get(uri, headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar centros de custo'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map((e) => CostCenter.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CostCenter> createCostCenter(String unitId, String name) async {
    final res = await http.post(
      Uri.parse('$_base/cost-centers'),
      headers: _headers,
      body: jsonEncode({'unitId': unitId, 'name': name}),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao criar centro de custo'));
    return CostCenter.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CostCenter> updateCostCenter(String id, String name, {String? unitId}) async {
    final body = <String, dynamic>{'name': name};
    if (unitId != null) body['unitId'] = unitId;
    final res = await http.patch(
      Uri.parse('$_base/cost-centers/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar centro de custo'));
    return CostCenter.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCostCenter(String id) async {
    final res = await http.delete(Uri.parse('$_base/cost-centers/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 204) throw Exception(errorMessage(null, res, 'Erro ao excluir centro de custo'));
  }

  // --- Request reasons (Fase 2) ---
  Future<List<RequestReason>> listRequestReasons() async {
    final res = await http.get(Uri.parse('$_base/request-reasons'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar motivos'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map((e) => RequestReason.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RequestReason> createRequestReason(String name) async {
    final res = await http.post(
      Uri.parse('$_base/request-reasons'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao criar motivo'));
    return RequestReason.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<RequestReason> updateRequestReason(String id, String name) async {
    final res = await http.patch(
      Uri.parse('$_base/request-reasons/$id'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar motivo'));
    return RequestReason.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteRequestReason(String id) async {
    final res = await http.delete(Uri.parse('$_base/request-reasons/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 204) throw Exception(errorMessage(null, res, 'Erro ao excluir motivo'));
  }

  // --- Users (Fase 2) ---
  Future<List<UserListItem>> listUsers() async {
    final res = await http.get(Uri.parse('$_base/users'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar usuários'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map((e) => UserListItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserListItem> getUser(String id) async {
    final res = await http.get(Uri.parse('$_base/users/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao buscar usuário'));
    return UserListItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserListItem> createUser({
    required String email,
    required String password,
    required String name,
    required String profile,
    List<String>? costCenterIds,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'name': name,
      'profile': profile,
    };
    if (costCenterIds != null) body['costCenterIds'] = costCenterIds;
    final res = await http.post(
      Uri.parse('$_base/users'),
      headers: _headers,
      body: jsonEncode(body),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao cadastrar usuário'));
    return UserListItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserListItem> updateUser(
    String id, {
    String? name,
    String? profile,
    List<String>? costCenterIds,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profile != null) body['profile'] = profile;
    if (costCenterIds != null) body['costCenterIds'] = costCenterIds;
    if (password != null && password.isNotEmpty) body['password'] = password;
    final res = await http.patch(
      Uri.parse('$_base/users/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar usuário'));
    return UserListItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
