#!/bin/sh
# Build APK do motorista (abre direto na tela do motorista, sem menu)
cd "$(dirname "$0")/.." && flutter build apk --flavor motorista -t lib/main_motorista.dart
