#!/usr/bin/env bash
# Gera dist/SpoolIQ-<versão>.dmg a partir do build release (flavor production).
#
# Uso: scripts/build_macos_dmg.sh [--skip-build]
#
# Assinatura opcional (sem as variáveis, o app sai com assinatura ad-hoc):
#   MACOS_SIGN_IDENTITY  "Developer ID Application: Nome (TEAMID)" (no keychain)
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD  notarização (app-specific password)
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="flutter"
command -v fvm >/dev/null 2>&1 && FLUTTER="fvm flutter"

if [[ "${1:-}" != "--skip-build" ]]; then
  # SENTRY_DSN vazio = Sentry desligado (o app só inicializa com DSN).
  $FLUTTER build macos --release --flavor production -t lib/main_production.dart \
    --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"
fi

APP="build/macos/Build/Products/Release-production/SpoolIQ.app"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
OUT="dist/SpoolIQ-${VERSION}.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

if [[ -n "${MACOS_SIGN_IDENTITY:-}" ]]; then
  # Hardened runtime + entitlements de release: exigências da notarização.
  codesign --force --deep --options runtime --timestamp \
    --entitlements macos/Runner/Release.entitlements \
    --sign "$MACOS_SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
fi

mkdir -p dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname "SpoolIQ" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null

if [[ -n "${MACOS_SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$OUT"
  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$OUT" --wait \
      --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"
    xcrun stapler staple "$OUT"
  fi
fi
echo "✓ $OUT ($(du -h "$OUT" | cut -f1))"
