import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// URL base da API.
///
/// **Produção (build para deploy):** em release (ex.: `flutter build web`), usa
/// [kApiBaseUrlProduction]. Assim o app no Render (https://rumo-ddno.onrender.com)
/// chama a API no Render (https://rumo-f09a.onrender.com) e não localhost:3001.
///
/// **Desenvolvimento:** em debug (`flutter run`) usa localhost (web) ou 10.0.2.2 (emulador).
///
/// Para sobrescrever em qualquer caso: `flutter run --dart-define=API_BASE_URL=...`
const String _kApiBaseUrlOverride = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

/// URL da API em produção (Render). Alterar aqui se o backend mudar de endereço.
const String kApiBaseUrlProduction = 'https://rumo-f09a.onrender.com/api';

const String kApiBaseUrlWeb = 'http://localhost:3001/api';
const String kApiBaseUrlMobile = 'http://10.0.2.2:3001/api';

String get kApiBaseUrl {
  if (_kApiBaseUrlOverride.isNotEmpty) {
    return _kApiBaseUrlOverride;
  }
  if (kReleaseMode) {
    return kApiBaseUrlProduction;
  }
  return kIsWeb ? kApiBaseUrlWeb : kApiBaseUrlMobile;
}
