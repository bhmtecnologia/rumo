import 'package:flutter/foundation.dart' show kIsWeb;

/// Altere esta URL para a do seu backend. É a única que o app usa para a API.
///
/// Exemplos:
///   http://localhost:3001/api   (backend na mesma máquina, porta 3001)
///   http://10.0.2.2:3001/api   (emulador Android apontando para a máquina)
///   http://192.168.1.10:3001/api (celular físico; 192.168.1.10 = IP do seu PC)
const String kApiBaseUrlWeb = 'http://localhost:3001/api';
const String kApiBaseUrlMobile = 'http://10.0.2.2:3001/api';

String get kApiBaseUrl => kIsWeb ? kApiBaseUrlWeb : kApiBaseUrlMobile;
