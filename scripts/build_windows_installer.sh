#!/usr/bin/env bash
# Gera dist/SpoolIQ-Setup-<versão>.exe (Inno Setup) a partir do build release
# (flavor production). Roda no Git Bash do Windows / runner windows-latest.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build windows --release -t lib/main_production.dart

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+.*//')
iscc "//DAppVersion=${VERSION}" windows/installer.iss
