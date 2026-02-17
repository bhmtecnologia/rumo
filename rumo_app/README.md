# Rumo – App Flutter

Aplicação Rumo em Flutter, organizada em **três módulos**: Passageiro, Motorista e Backoffice. Utiliza o mesmo backend (Node/Express) da API Rumo.

## Estrutura de módulos

| Módulo       | Descrição |
|-------------|-----------|
| **Passageiro** | Pedir corrida: origem (GPS), destino (pesquisa/sugestões), mapa, estimativa e solicitação. |
| **Motorista**  | Em breve: corridas disponíveis, aceitar viagem, navegação. |
| **Backoffice** | Em breve: gestão de corridas, tarifas, relatórios. |

Ao abrir o app, o usuário escolhe o módulo na tela inicial (Passageiro, Motorista ou Backoffice) e entra no fluxo correspondente.

## Estrutura do código

```
lib/
├── main.dart                    # App e rota inicial
├── screens/
│   └── module_selector_screen.dart   # Escolha do módulo
├── core/                        # Compartilhado entre módulos
│   ├── config.dart              # URL da API
│   ├── models/                  # Estimate, Ride
│   ├── services/                # ApiService, Nominatim, OSRM
│   └── widgets/                 # RumoMap
└── modules/
    ├── passageiro/
    │   └── screens/             # PassageiroHome, RequestRide, TripChoice
    ├── motorista/
    │   └── screens/             # MotoristaHome (placeholder)
    └── backoffice/
        └── screens/             # BackofficeHome (placeholder)
```

## Requisitos

- Flutter SDK (3.10+)
- Backend Rumo rodando (porta 3001)

## Configurar a URL da API

Edite `lib/core/config.dart` e defina `kApiBaseUrl`:

- **Emulador Android:** `http://10.0.2.2:3001/api`
- **Simulador iOS:** `http://localhost:3001/api`
- **Dispositivo físico:** IP da sua máquina, ex: `http://192.168.1.10:3001/api`

## Rodar o app

```bash
cd rumo_app
flutter pub get
flutter run
```

## Permissões

- **Android:** `ACCESS_FINE_LOCATION` e `INTERNET` (AndroidManifest.xml).
- **iOS:** `NSLocationWhenInUseUsageDescription` (Info.plist).
