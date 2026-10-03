#!/usr/bin/env bash
# Local SQL checks for the closed beta migrations (20261003* and later).
# Runs on a throwaway Postgres. Never touches any Supabase project.
# Needs Postgres server binaries (initdb, pg_ctl) and psql.
# Usage: supabase/tests/run_beta_local.sh
#
# What it does:
#   1. Builds a stand-in database: local_stub.sql, the old migrations (errors
#      tolerated: the old chain does not replay from scratch, see the audit),
#      seed.sql and seed_marketplace.sql.
#   2. Applies every beta migration, TWICE, and any error stops the run.
#   3. Runs every supabase/tests/beta/NN_*.sql (as the anon role where it
#      matters). Each file runs inside a transaction that is rolled back.
#   4. Rolls every beta migration back (newest first, twice), then applies them
#      all again, and runs the tests once more.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT:-54331}"
RUN=""
if [ "$(id -u)" = "0" ]; then chown -R postgres "$WORK"; RUN="runuser -u postgres --"; fi
PSQL="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -q -X"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null
$PSQL -d postgres -v ON_ERROR_STOP=1 -c "create database demo"
PSQL="$PSQL -d demo"

echo "== stub, old migrations (errors tolerated), seeds"
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/tests/local_stub.sql"
for f in "$ROOT"/supabase/migrations/2026091*.sql "$ROOT"/supabase/migrations/2026092*.sql "$ROOT"/supabase/migrations/2026093*.sql "$ROOT"/supabase/migrations/20261001*.sql; do
  $PSQL -f "$f" >/dev/null 2>&1 || true
done
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/seed.sql" >/dev/null
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/seed_marketplace.sql" >/dev/null

shopt -s nullglob
MIGS=("$ROOT"/supabase/migrations/2026100[3-9]*.sql "$ROOT"/supabase/migrations/202610[1-3]*.sql)

apply_all() {
  for f in "${MIGS[@]}"; do
    $PSQL -v ON_ERROR_STOP=1 -f "$f" >/dev/null
  done
}
echo "== beta migrations: ${#MIGS[@]} file(s), applied twice"
apply_all
apply_all

run_tests() {
  $PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/tests/beta/_helpers.sql" >/dev/null
  for t in "$ROOT"/supabase/tests/beta/[0-9]*.sql; do
    echo "== $(basename "$t")"
    $PSQL -v ON_ERROR_STOP=1 -f "$t"
  done
  $PSQL -v ON_ERROR_STOP=1 -c "set client_min_messages = warning; drop schema if exists jt cascade" >/dev/null
}
run_tests

echo "== rollbacks, newest first, each twice"
for ((i=${#MIGS[@]}-1; i>=0; i--)); do
  name="$(basename "${MIGS[$i]}" .sql)"
  name="${name#*_}"
  rb="$ROOT/supabase/rollback_${name}.sql"
  [ -f "$rb" ] || { echo "FAIL: missing rollback script supabase/rollback_${name}.sql"; exit 1; }
  $PSQL -v ON_ERROR_STOP=1 -f "$rb" >/dev/null
  $PSQL -v ON_ERROR_STOP=1 -f "$rb" >/dev/null
done
profiles="$($PSQL -tA -c "select count(*) from alumni_profiles")"
[ "$profiles" -gt 0 ] || { echo "FAIL: rollback lost profiles"; exit 1; }
echo "profiles still there after rollback: $profiles"
echo "== re-apply after rollback, tests again"
apply_all
run_tests
echo "ALL BETA SQL CHECKS PASSED"
