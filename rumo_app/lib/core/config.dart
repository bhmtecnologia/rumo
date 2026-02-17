import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuração da API do backend Rumo.
/// Web: localhost. Emulador Android: 10.0.2.2. Dispositivo físico: IP da máquina.
String get kApiBaseUrl {
  if (kIsWeb) return 'http://localhost:3001/api';
  return 'http://10.0.2.2:3001/api';
}
