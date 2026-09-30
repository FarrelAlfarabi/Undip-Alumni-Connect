#!/usr/bin/env bash
# Runs the security audit probes on a throwaway local Postgres. Never touches
# any Supabase project. Needs Postgres server binaries and psql (same as
# supabase/tests/run_local.sh).
#
# Usage: supabase/tests/security_audit/run_audit.sh [pre|post]
#   pre  = migrations WITHOUT the security migrations (*_security_*.sql).
#          Every P* probe must show the weakness, every C* control must not.
#   post = all migrations. Probes listed in expected_fixed.txt must now be
#          fixed; the rest must still show the weakness (they need real
#          Supabase Auth). Then the rollback script is applied (twice, to
#          prove it is idempotent) on a fresh copy and the weaknesses must
#          all be back.
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
PSQLBASE="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -v ON_ERROR_STOP=1 -q -X"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null

# run_db <dbname> <with security migrations: 0|1> <apply rollback: 0|1> <fixed list>
run_db() {
  local db="$1" withsec="$2" rollback="$3" fixed="$4"
  $PSQLBASE -d postgres -c "create database $db" >/dev/null
  local PSQL="$PSQLBASE -d $db"
  $PSQL -f "$ROOT/supabase/tests/local_stub.sql" >/dev/null
  for f in "$ROOT"/supabase/migrations/*.sql; do
    if [ "$withsec" = "0" ] && [[ "$f" == *_security_* ]]; then continue; fi
    $PSQL -f "$f" >/dev/null 2>&1 || { echo "migration failed: $f"; $PSQL -f "$f" 2>&1 | tail -5; exit 1; }
  done
  if [ "$rollback" = "1" ]; then
    $PSQL -f "$ROOT/supabase/rollback_security_hardening.sql" >/dev/null 2>&1 || { echo "rollback failed"; $PSQL -f "$ROOT/supabase/rollback_security_hardening.sql" 2>&1 | tail -5; exit 1; }
    $PSQL -f "$ROOT/supabase/rollback_security_hardening.sql" >/dev/null 2>&1 || { echo "rollback is not idempotent"; exit 1; }
  fi
  # No seed files on purpose: only synthetic example.com people.
  local OUT
  OUT="$($PSQL -tA -f "$HERE/probes.sql")"
  echo "$OUT" | grep '^PROBE|' | awk -F'|' '{ printf "%-4s %-6s %s\n", $2, (($3=="t"||$3=="true")?"WEAK":"ok"), $4 }'
  local fail=0 tag id weak note want got f
  while IFS='|' read -r tag id weak note; do
    [ "$tag" = "PROBE" ] || continue
    want=true
    case "$id" in C*) want=false ;; esac
    for f in $fixed; do [ "$f" = "$id" ] && want=false; done
    if [ "$weak" = "t" ] || [ "$weak" = "true" ]; then got=true; else got=false; fi
    if [ "$got" != "$want" ]; then echo "UNEXPECTED $id: weak=$got, expected $want ($note)"; fail=1; fi
  done < <(echo "$OUT" | grep '^PROBE|')
  [ "$fail" = 0 ] || { echo "AUDIT RUN ($MODE, db $db): unexpected result"; exit 1; }
}

if [ "$MODE" = "pre" ]; then
  run_db audit 0 0 ""
  echo "AUDIT RUN (pre): every probe matches expectations"
else
  FIXED="$(grep -v '^#' "$HERE/expected_fixed.txt" | tr '\n' ' ')"
  run_db audit 1 0 "$FIXED"
  echo "AUDIT RUN (post): fixed probes are fixed, the rest still need auth"
  echo "== rollback check (fresh database, rollback applied twice)"
  run_db audit_rb 1 1 "" >/dev/null
  echo "ROLLBACK CHECK: weaknesses are back after rollback, and the script is idempotent"
fi
