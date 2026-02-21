#!/bin/sh
# Build APK do admin/central (abre direto na tela do backoffice, sem menu)
cd "$(dirname "$0")/.." && flutter build apk --flavor admin -t lib/main_admin.dart
