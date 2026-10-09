#!/usr/bin/env bash
# Gera dist/SpoolIQ-Setup-<versão>.exe (Inno Setup) a partir do build release
# (flavor production). Roda no Git Bash do Windows / runner windows-latest.
set -euo pipefail
cd "$(dirname "$0")/.."

# SENTRY_DSN vazio = Sentry desligado (o app só inicializa com DSN).
flutter build windows --release -t lib/main_production.dart \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
iscc "//DAppVersion=${VERSION}" windows/installer.iss
