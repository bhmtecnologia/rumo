# Push e som para motorista – nova corrida

Quando uma corrida é criada (passageiro solicita), o motorista online recebe:
- **Push notification** no celular
- **Som** de alerta (incluindo com app em background)

## Configuração

### 1. Firebase Console

1. Crie um projeto em [Firebase Console](https://console.firebase.google.com/).
2. Adicione um app **Android** com package name `com.rumo.motorista`.
3. Baixe `google-services.json` e coloque em `rumo_app/android/app/`.
4. Em **Project Settings** → **Service accounts**, gere uma chave (JSON) da service account. Salve o arquivo em local seguro.

### 2. Backend

No `.env` do backend:

```env
# Caminho para o JSON da service account (ex.: ./firebase-service-account.json)
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

Se não configurar, o push fica desabilitado (o resto do app continua funcionando).

### 3. Flutter (motorista)

O app motorista já está configurado. Após adicionar `google-services.json`, rode:

```bash
cd rumo_app
flutter build apk --flavor motorista -t lib/main_motorista.dart
```

Ou use `flutterfire configure` para configurar o Firebase automaticamente.

## Fluxo

1. Motorista faz login no app **Rumo Parceiro** e fica **online**.
2. O app registra o token FCM no backend.
3. Passageiro solicita corrida (app Rumo ou backoffice).
4. Backend envia push para todos os motoristas **online**.
5. Motorista recebe notificação com som (foreground ou background).
6. Ao tocar na notificação, o app abre na tela de corridas.
