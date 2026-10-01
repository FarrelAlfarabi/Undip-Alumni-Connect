#!/usr/bin/env bash
# Refuses to continue unless SUPABASE_URL is https and SUPABASE_ANON_KEY is a
# PUBLISHABLE key. The key is bundled into the public web build (assets/.env),
# so a service-role or secret key here would be handed to every visitor.
#
# Accepts: `sb_publishable_...`, or a legacy JWT whose role claim is `anon`.
# Rejects: `sb_secret_...`, JWTs with any other role (e.g. service_role),
# anything else. Never prints the key.
set -euo pipefail

url="${SUPABASE_URL:-}"
key="${SUPABASE_ANON_KEY:-}"

fail() { echo "ERROR: $1" >&2; exit 1; }

case "$url" in
  https://?*) ;;
  *) fail "SUPABASE_URL must start with https://" ;;
esac

[ -n "$key" ] || fail "SUPABASE_ANON_KEY is empty"

case "$key" in
  sb_publishable_?*) exit 0 ;;
  sb_secret_*) fail "SUPABASE_ANON_KEY looks like a SECRET key (sb_secret_). Use the publishable/anon key. Never ship a secret key in the web build." ;;
esac

IFS='.' read -r header payload sig extra <<<"$key"
if [ -z "${payload:-}" ] || [ -z "${sig:-}" ] || [ -n "${extra:-}" ]; then
  fail "SUPABASE_ANON_KEY is not a publishable key or a JWT. Use the publishable/anon key."
fi

# base64url -> base64, add padding, decode.
b64="$(printf '%s' "$payload" | tr '_-' '/+')"
case $(( ${#b64} % 4 )) in
  2) b64="${b64}==" ;;
  3) b64="${b64}=" ;;
esac
json="$(printf '%s' "$b64" | base64 -d 2>/dev/null || true)"
[ -n "$json" ] || fail "SUPABASE_ANON_KEY is not a valid JWT."

role="$(printf '%s' "$json" | grep -o '"role"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')"
case "$role" in
  anon) exit 0 ;;
  service_role) fail "SUPABASE_ANON_KEY is a service_role key. That key bypasses all security and must never be in the web build. Use the anon/publishable key." ;;
  *) fail "SUPABASE_ANON_KEY has role '${role:-none}', expected 'anon'." ;;
esac
