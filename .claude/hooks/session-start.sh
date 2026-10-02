#!/bin/bash
# Installs the Flutter SDK and project packages in Claude Code on the web
# sessions (the container is thrown away after every session, so this runs
# each time). Does nothing on a local machine.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.47.6"
FLUTTER_HOME="/opt/flutter"
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  curl -sSfL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf /tmp/flutter.tar.xz -C /opt
  rm -f /tmp/flutter.tar.xz
fi

# Flutter is a git checkout; git refuses it when owned by another user.
git config --global --add safe.directory "$FLUTTER_HOME" || true

export PATH="$FLUTTER_HOME/bin:$PATH"
export CI=true
flutter config --no-analytics >/dev/null 2>&1 || true

# pubspec.yaml lists .env as an asset; analyze and tests fail without it.
# It is gitignored, so make a placeholder from the example if it is missing.
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
fi

flutter pub get

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
