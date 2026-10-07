#!/usr/bin/env bash
# Applies EVERY migration, in timestamp order, to an empty throwaway Postgres
# and stops at the first error. Then applies the beta ones (20261003 and later)
# a second time (they must be idempotent), loads seed.sql, and runs the live
# checks. The oldest migrations are one-shot and are not re-run.
# This is what a fresh Supabase project or branch database would do.
# Never touches any Supabase project. Needs initdb, pg_ctl and psql.
# Usage: supabase/tests/run_fresh_chain.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT:-54341}"
RUN=""
if [ "$(id -u)" = "0" ]; then chown -R postgres "$WORK"; RUN="runuser -u postgres --"; fi
PSQL="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -q -X -v ON_ERROR_STOP=1"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null
$PSQL -d postgres -c "create database fresh"
PSQL="$PSQL -d fresh"

$PSQL -f "$ROOT/supabase/tests/local_stub.sql"

shopt -s nullglob
MIGS=("$ROOT"/supabase/migrations/*.sql)
echo "== ${#MIGS[@]} migrations, in order, first error stops the run"
for f in "${MIGS[@]}"; do
  if ! $PSQL -f "$f" >/dev/null 2>"$WORK/err.txt"; then
    echo "FAIL: $(basename "$f")"; cat "$WORK/err.txt"; exit 1
  fi
done
echo "== second pass over the beta migrations (20261003 and later must be idempotent)"
for f in "${MIGS[@]}"; do
  case "$(basename "$f")" in 2026100[3-9]*|202610[1-3]*) ;; *) continue ;; esac
  if ! $PSQL -f "$f" >/dev/null 2>"$WORK/err.txt"; then
    echo "FAIL (second pass): $(basename "$f")"; cat "$WORK/err.txt"; exit 1
  fi
done
echo "== seed.sql"
$PSQL -f "$ROOT/supabase/seed.sql" >/dev/null
echo "== live checks: every line must be ok"
checks="$($PSQL -tA -F'|' -f "$ROOT/supabase/checks/live_db_checks.sql")"
if echo "$checks" | grep -q '|f|'; then echo "$checks" | grep '|f|'; echo "FAIL: live checks flag the fresh database"; exit 1; fi
echo "FRESH CHAIN OK"
