import 'package:shared_preferences/shared_preferences.dart';

const _keyDefaultCostCenterId = 'rumo_passenger_default_cost_center_id';
const _keyPushDriverAccepted = 'rumo_passenger_push_driver_accepted';
const _keyPushDriverArrived = 'rumo_passenger_push_driver_arrived';

/// Preferências locais do passageiro (centro de custo padrão, notificações).
class PassengerPreferencesService {
  static final PassengerPreferencesService _instance = PassengerPreferencesService._();
  factory PassengerPreferencesService() => _instance;

  PassengerPreferencesService._();

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// Centro de custo padrão para novas corridas (quando usuário tem vários).
  Future<String?> getDefaultCostCenterId() async {
    return (await _prefs).getString(_keyDefaultCostCenterId);
  }

  Future<void> setDefaultCostCenterId(String? id) async {
    final p = await _prefs;
    if (id == null) {
      await p.remove(_keyDefaultCostCenterId);
    } else {
      await p.setString(_keyDefaultCostCenterId, id);
    }
  }

  /// Notificação quando motorista aceita (default: true).
  Future<bool> getPushDriverAccepted() async {
    return (await _prefs).getBool(_keyPushDriverAccepted) ?? true;
  }

  Future<void> setPushDriverAccepted(bool value) async {
    await (await _prefs).setBool(_keyPushDriverAccepted, value);
  }

  /// Notificação quando motorista chega (default: true).
  Future<bool> getPushDriverArrived() async {
    return (await _prefs).getBool(_keyPushDriverArrived) ?? true;
  }

  Future<void> setPushDriverArrived(bool value) async {
    await (await _prefs).setBool(_keyPushDriverArrived, value);
  }
}
