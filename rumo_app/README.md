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

Edite **só** o arquivo `lib/core/config.dart`:

- **`kApiBaseUrlWeb`** – usada quando você roda no Chrome (ex: `http://localhost:3001/api`).
- **`kApiBaseUrlMobile`** – usada no emulador Android (ex: `http://10.0.2.2:3001/api`).

A API do backend deve estar rodando nessa mesma URL (ex: `npm run dev` no `backend/` sobe na porta 3001).

**Importante:** quando você roda `flutter run -d chrome`, o navegador abre em uma porta aleatória (ex: 12345). Essa é a porta do **app**, não da API. A API é sempre a que está em `config.dart` (ex: 3001).

## Rodar o app

```bash
cd rumo_app
flutter pub get
flutter run
```

## Permissões

- **Android:** `ACCESS_FINE_LOCATION` e `INTERNET` (AndroidManifest.xml).
- **iOS:** `NSLocationWhenInUseUsageDescription` (Info.plist).
