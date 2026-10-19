#!/bin/bash
# Installs the pinned Flutter SDK once per container, then runs `flutter pub get`.
# Use it as the cloud environment's setup script, or run it by hand:
#   bash scripts/setup_flutter.sh && export PATH="$HOME/flutter/bin:$PATH"
# Keep FLUTTER_VERSION equal to .github/workflows/flutter-ci.yml.
set -euo pipefail

FLUTTER_VERSION="3.47.4"
FLUTTER_DIR="${HOME}/flutter"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "${FLUTTER_VERSION}" "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

cd "$(dirname "$0")/.."
[ -f .env ] || cp .env.example .env
flutter pub get
