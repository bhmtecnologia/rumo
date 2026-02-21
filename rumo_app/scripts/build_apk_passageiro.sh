#!/bin/sh
# Build APK do passageiro (abre direto na tela do passageiro, sem menu)
cd "$(dirname "$0")/.." && flutter build apk --flavor passageiro -t lib/main_passageiro.dart
