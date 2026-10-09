#!/usr/bin/env bash
# Gera dist/SpoolIQ-Setup-<versão>.exe (Inno Setup) a partir do build release
# (flavor production). Roda no Git Bash do Windows / runner windows-latest.
set -euo pipefail
cd "$(dirname "$0")/.."

# SENTRY_DSN vazio = Sentry desligado (o app só inicializa com DSN).
flutter build windows --release -t lib/main_production.dart \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"

# Assinatura opcional: WINDOWS_CERT_PFX (caminho do .pfx) + WINDOWS_CERT_PASSWORD.
sign() {
  [[ -n "${WINDOWS_CERT_PFX:-}" ]] || return 0
  signtool sign //f "$WINDOWS_CERT_PFX" //p "$WINDOWS_CERT_PASSWORD" \
    //fd sha256 //tr http://timestamp.digicert.com //td sha256 "$1"
}

sign build/windows/x64/runner/Release/SpoolIQ.exe

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
iscc "//DAppVersion=${VERSION}" windows/installer.iss
sign "dist/SpoolIQ-Setup-${VERSION}.exe"
