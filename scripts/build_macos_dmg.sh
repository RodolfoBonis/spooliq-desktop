#!/usr/bin/env bash
# Gera dist/SpoolIQ-<versão>.dmg a partir do build release (flavor production).
#
# Uso: scripts/build_macos_dmg.sh [--skip-build]
#
# O app sai com assinatura ad-hoc. Para distribuir fora da sua máquina sem
# alerta do Gatekeeper, assine com um "Developer ID Application" e notarize:
#   codesign --deep --force --options runtime --sign "Developer ID Application: …" SpoolIQ.app
#   xcrun notarytool submit dist/SpoolIQ-x.y.z.dmg --keychain-profile <perfil> --wait
#   xcrun stapler staple dist/SpoolIQ-x.y.z.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="flutter"
command -v fvm >/dev/null 2>&1 && FLUTTER="fvm flutter"

if [[ "${1:-}" != "--skip-build" ]]; then
  $FLUTTER build macos --release --flavor production -t lib/main_production.dart
fi

APP="build/macos/Build/Products/Release-production/SpoolIQ.app"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
OUT="dist/SpoolIQ-${VERSION}.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname "SpoolIQ" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
echo "✓ $OUT ($(du -h "$OUT" | cut -f1))"
