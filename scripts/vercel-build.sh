#!/usr/bin/env bash
# Vercel build step for this Flutter web app.
#
# Vercel's build image has no Flutter SDK, so this fetches it fresh on
# every build (shallow clone, stable channel), then builds the same way
# `flutter build web --release` does locally.
#
# The Supabase URL/anon key are never committed (see .gitignore) — this
# script writes .env from Vercel's own Environment Variables at build
# time instead. Set SUPABASE_URL and SUPABASE_ANON_KEY under the Vercel
# project's Settings > Environment Variables (Production and Preview)
# before this will build successfully.
set -euo pipefail

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set as Vercel" >&2
  echo "project Environment Variables (Settings > Environment Variables)." >&2
  echo "See .env.example for what these should look like." >&2
  exit 1
fi

# Refuse to build with anything but a publishable key (it is bundled into the
# public web build). See scripts/check_supabase_env.sh.
bash "$(dirname "$0")/check_supabase_env.sh"

if [ ! -d flutter ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable
fi
export PATH="$PATH:$(pwd)/flutter/bin"

cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
EOF

flutter pub get
# Vercel PREVIEW builds turn the lock screen on for web so it can be tried in
# a browser. Production builds never do (web has no real secure storage).
EXTRA_DEFINES=""
if [ "${VERCEL_ENV:-}" = "preview" ]; then
  EXTRA_DEFINES="--dart-define=WEB_LOCK_TEST=true"
fi
flutter build web --release $EXTRA_DEFINES

# CanvasKit loads from Google's CDN by default (see flutter_bootstrap.js'
# buildConfig) — the bundled canvaskit/ folder is an unused local fallback
# that's ~90% of the build's size. Dropping it doesn't change behavior.
rm -rf build/web/canvaskit build/web/assets/NOTICES
