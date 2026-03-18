#!/usr/bin/env bash
set -euo pipefail

echo "==> dart format"
dart format --set-exit-if-changed .

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test
