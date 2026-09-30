#!/usr/bin/env bash
# Runs the security audit probes on a throwaway local Postgres. Never touches
# any Supabase project. Needs Postgres server binaries and psql (same as
# supabase/tests/run_local.sh).
#
# Usage: supabase/tests/security_audit/run_audit.sh [pre|post]
#   pre  = migrations WITHOUT the security hardening migration. Every P*
#          probe must show the weakness (weak=true), every C* control false.
#   post = all migrations. Probes listed in expected_fixed.txt must now be
#          false; the rest must still be true (they need real auth).
set -euo pipefail

MODE="${1:-pre}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT:-54331}"
RUN=""
if [ "$(id -u)" = "0" ]; then
  chown -R postgres "$WORK"
  RUN="runuser -u postgres --"
fi
PSQL="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -v ON_ERROR_STOP=1 -q -X"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null
$PSQL -d postgres -c "create database audit" >/dev/null
PSQL="$PSQL -d audit"

$PSQL -f "$ROOT/supabase/tests/local_stub.sql" >/dev/null
for f in "$ROOT"/supabase/migrations/*.sql; do
  if [ "$MODE" = "pre" ] && [[ "$f" == *security_hardening* ]]; then continue; fi
  $PSQL -f "$f" >/dev/null 2>&1 || { echo "migration failed: $f"; $PSQL -f "$f" 2>&1 | tail -5; exit 1; }
done
# No seed files on purpose: the audit uses only synthetic example.com people.

OUT="$($PSQL -tA -f "$HERE/probes.sql")"
echo "$OUT" | grep '^PROBE|' | awk -F'|' '{ printf "%-4s %-6s %s\n", $2, (($3=="t"||$3=="true")?"WEAK":"ok"), $4 }'

FIXED=""
if [ "$MODE" = "post" ] && [ -f "$HERE/expected_fixed.txt" ]; then
  FIXED="$(grep -v '^#' "$HERE/expected_fixed.txt" | tr '\n' ' ')"
fi

fail=0
while IFS='|' read -r tag id weak note; do
  [ "$tag" = "PROBE" ] || continue
  want=true
  case "$id" in C*) want=false ;; esac
  for f in $FIXED; do [ "$f" = "$id" ] && want=false; done
  if [ "$weak" != "t" ] && [ "$weak" != "true" ]; then got=false; else got=true; fi
  if [ "$got" != "$want" ]; then echo "UNEXPECTED $id: weak=$got, expected $want ($note)"; fail=1; fi
done < <(echo "$OUT" | grep '^PROBE|')
[ "$fail" = 0 ] || { echo "AUDIT RUN ($MODE): unexpected result"; exit 1; }
echo "AUDIT RUN ($MODE): every probe matches expectations"
