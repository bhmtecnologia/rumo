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
    String? costCenterId,
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
    if (costCenterId != null) body['cost_center_id'] = costCenterId;

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
    await _check401(res);
    if (res.statusCode == 403) {
      throw Exception(errorMessage(null, res, 'Solicitação não permitida pelas restrições do centro de custo.'));
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
    String? costCenterId,
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
    if (costCenterId != null) body['cost_center_id'] = costCenterId;

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
    await _check401(res);
    if (res.statusCode == 403) {
      throw Exception(errorMessage(null, res, 'Solicitação não permitida pelas restrições do centro de custo.'));
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(errorMessage(null, res, 'Erro ao solicitar corrida'));
    }
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Motorista: retorna status online e posição atual.
  Future<Map<String, dynamic>> getDriverStatus() async {
    final res = await http.get(Uri.parse('$_base/driver/status'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao consultar status'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Motorista: ficar online/offline; opcional enviar lat/lng.
  Future<void> updateDriverStatus({
    required bool isOnline,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{'isOnline': isOnline};
    if (lat != null && lng != null) {
      body['lat'] = lat;
      body['lng'] = lng;
    }
    final res = await http.patch(
      Uri.parse('$_base/driver/status'),
      headers: _headers,
      body: jsonEncode(body),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar status'));
  }

  /// Motorista: registra token FCM para push de nova corrida.
  Future<void> registerFcmToken(String token) async {
    final res = await http.post(
      Uri.parse('$_base/driver/fcm-token'),
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao registrar notificações'));
  }

  /// Passageiro: registra token FCM para push quando motorista aceita.
  Future<void> registerPassengerFcmToken(String token) async {
    final res = await http.post(
      Uri.parse('$_base/passenger/fcm-token'),
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao registrar notificações'));
  }

  /// Lista corridas. Motorista: [available] true = só status requested; false/omitido = minhas corridas.
  Future<List<RideListItem>> listRides({bool? available}) async {
    var uri = Uri.parse('$_base/rides');
    if (available == true) uri = uri.replace(queryParameters: {'available': '1'});
    final res = await http.get(uri, headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar corridas'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map((e) => RideListItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Detalhe da corrida (para polling e telas de acompanhamento).
  Future<Ride> getRide(String id) async {
    final res = await http.get(Uri.parse('$_base/rides/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode == 404) throw Exception('Corrida não encontrada.');
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao buscar corrida'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Motorista aceita a corrida.
  Future<Ride> acceptRide(String id, {String? vehiclePlate}) async {
    final res = await http.patch(
      Uri.parse('$_base/rides/$id/accept'),
      headers: _headers,
      body: jsonEncode({if (vehiclePlate != null && vehiclePlate.isNotEmpty) 'vehiclePlate': vehiclePlate}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao aceitar corrida'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Motorista registra chegada na origem.
  Future<Ride> markRideArrived(String id) async {
    final res = await http.patch(Uri.parse('$_base/rides/$id/arrived'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao registrar chegada'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Motorista inicia a viagem.
  Future<Ride> startRide(String id) async {
    final res = await http.patch(Uri.parse('$_base/rides/$id/start'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao iniciar corrida'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Motorista finaliza a viagem (valor efetivo obrigatório).
  Future<Ride> completeRide(String id, {required int actualPriceCents, double? actualDistanceKm, int? actualDurationMin}) async {
    final res = await http.patch(
      Uri.parse('$_base/rides/$id/complete'),
      headers: _headers,
      body: jsonEncode({
        'actualPriceCents': actualPriceCents,
        if (actualDistanceKm != null) 'actualDistanceKm': actualDistanceKm,
        if (actualDurationMin != null) 'actualDurationMin': actualDurationMin,
      }),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao finalizar corrida'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Cancelar corrida (solicitante ou motorista).
  Future<Ride> cancelRide(String id, {String? reason}) async {
    final res = await http.patch(
      Uri.parse('$_base/rides/$id/cancel'),
      headers: _headers,
      body: jsonEncode({if (reason != null && reason.isNotEmpty) 'reason': reason}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao cancelar corrida'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Avaliar corrida (1 a 5). Apenas solicitante, corrida concluída.
  Future<Ride> rateRide(String id, int rating) async {
    final res = await http.post(
      Uri.parse('$_base/rides/$id/rate'),
      headers: _headers,
      body: jsonEncode({'rating': rating}),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao avaliar'));
    return Ride.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Recibo da corrida (apenas corridas finalizadas).
  Future<Map<String, dynamic>> getRideReceipt(String id) async {
    final res = await http.get(Uri.parse('$_base/rides/$id/receipt'), headers: _headers);
    await _check401(res);
    if (res.statusCode == 404) throw Exception('Corrida não encontrada.');
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao buscar recibo'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Lista mensagens da corrida (comunicação usuário–motorista).
  Future<List<Map<String, dynamic>>> getRideMessages(String id) async {
    final res = await http.get(Uri.parse('$_base/rides/$id/messages'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao listar mensagens'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return List<Map<String, dynamic>>.from(data.map((e) => e as Map<String, dynamic>));
  }

  /// Envia mensagem na corrida (solicitante ou motorista).
  Future<Map<String, dynamic>> sendRideMessage(String id, String text) async {
    final res = await http.post(
      Uri.parse('$_base/rides/$id/messages'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao enviar mensagem'));
    return jsonDecode(res.body) as Map<String, dynamic>;
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

  Future<CostCenter> getCostCenter(String id) async {
    final res = await http.get(Uri.parse('$_base/cost-centers/$id'), headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao buscar centro de custo'));
    return CostCenter.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CostCenter> updateCostCenter(
    String id, {
    String? name,
    String? unitId,
    bool? blocked,
    int? monthlyLimitCents,
    double? maxKm,
    String? allowedTimeStart,
    String? allowedTimeEnd,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (unitId != null) body['unitId'] = unitId;
    if (blocked != null) body['blocked'] = blocked;
    if (monthlyLimitCents != null) body['monthlyLimitCents'] = monthlyLimitCents;
    if (maxKm != null) body['maxKm'] = maxKm;
    if (allowedTimeStart != null) body['allowedTimeStart'] = allowedTimeStart;
    if (allowedTimeEnd != null) body['allowedTimeEnd'] = allowedTimeEnd;
    if (body.isEmpty) throw Exception('Nenhum campo para atualizar');
    final res = await http.patch(
      Uri.parse('$_base/cost-centers/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao atualizar centro de custo'));
    return CostCenter.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> addCostCenterArea(
    String costCenterId, {
    required String type,
    required double lat,
    required double lng,
    double radiusKm = 5,
    String? label,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/cost-centers/$costCenterId/areas'),
      headers: _headers,
      body: jsonEncode({
        'type': type,
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        if (label != null) 'label': label,
      }),
    );
    await _check401(res);
    if (res.statusCode != 201) throw Exception(errorMessage(null, res, 'Erro ao adicionar área'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteCostCenterArea(String costCenterId, String areaId) async {
    final res = await http.delete(
      Uri.parse('$_base/cost-centers/$costCenterId/areas/$areaId'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode != 204) throw Exception(errorMessage(null, res, 'Erro ao excluir área'));
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

  // --- Reports (Fase 5) ---
  Future<List<Map<String, dynamic>>> getReportsRides({
    DateTime? from,
    DateTime? to,
    String? costCenterId,
    String? unitId,
  }) async {
    var uri = Uri.parse('$_base/reports/rides');
    final q = <String, String>{};
    if (from != null) q['from'] = from.toIso8601String();
    if (to != null) q['to'] = to.toIso8601String();
    if (costCenterId != null) q['costCenterId'] = costCenterId;
    if (unitId != null) q['unitId'] = unitId;
    if (q.isNotEmpty) uri = uri.replace(queryParameters: q);
    final res = await http.get(uri, headers: _headers);
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao gerar relatório de corridas'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return List<Map<String, dynamic>>.from(data.map((e) => e as Map<String, dynamic>));
  }

  Future<List<Map<String, dynamic>>> getReportsCadastrais(String type) async {
    final res = await http.get(
      Uri.parse('$_base/reports/cadastrais').replace(queryParameters: {'type': type}),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode != 200) throw Exception(errorMessage(null, res, 'Erro ao gerar relatório cadastral'));
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return List<Map<String, dynamic>>.from(data.map((e) => e as Map<String, dynamic>));
  }
}
