#!/usr/bin/env bash
# Runs the marketplace SQL/RLS tests on a throwaway local Postgres.
# Never touches any Supabase project. Needs Postgres server binaries
# (initdb, pg_ctl) and psql. Usage: supabase/tests/run_local.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT:-54329}"
RUN=""
if [ "$(id -u)" = "0" ]; then
  # Postgres refuses to run as root.
  chown -R postgres "$WORK"
  RUN="runuser -u postgres --"
fi
PSQL="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -v ON_ERROR_STOP=1 -q -X"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null

$PSQL -d postgres -c "create database demo" 
PSQL="$PSQL -d demo"

echo "== stub + existing migrations + seed.sql"
$PSQL -f "$ROOT/supabase/tests/local_stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  $PSQL -f "$f" >/dev/null
done
$PSQL -f "$ROOT/supabase/seed.sql" >/dev/null

echo "== re-run marketplace migrations (idempotency)"
for f in "$ROOT"/supabase/migrations/2026093009*.sql; do
  $PSQL -f "$f" >/dev/null
done

echo "== seed_marketplace.sql twice"
$PSQL -f "$ROOT/supabase/seed_marketplace.sql"
count() { $PSQL -tA -c "select (select count(*) from marketplace_listings) || '/' || (select count(*) from marketplace_admins)"; }
first="$(count)"
$PSQL -f "$ROOT/supabase/seed_marketplace.sql"
second="$(count)"
echo "listings/admins after run 1: $first, after run 2: $second"
[ "$first" = "$second" ] || { echo "FAIL: seed is not idempotent"; exit 1; }
[ "$first" = "12/1" ] || { echo "FAIL: expected 12/1, got $first"; exit 1; }

echo "== marketplace_rls_test.sql"
$PSQL -f "$ROOT/supabase/tests/marketplace_rls_test.sql"
echo "== rollback removes only marketplace objects, and a re-apply works"
before="$($PSQL -tA -c "select count(*) from pg_policies where schemaname in ('public','storage') and policyname not like 'marketplace_%'")"
$PSQL -f "$ROOT/supabase/rollback_marketplace.sql" >/dev/null
$PSQL -f "$ROOT/supabase/rollback_marketplace.sql" >/dev/null   # twice = still fine
left="$($PSQL -tA -c "select (select count(*) from information_schema.tables where table_schema='public' and table_name like 'marketplace%') + (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'marketplace%') + (select count(*) from storage.buckets where id='marketplace') + (select count(*) from pg_policies where policyname like 'marketplace_%')")"
after="$($PSQL -tA -c "select count(*) from pg_policies where schemaname in ('public','storage') and policyname not like 'marketplace_%'")"
profiles="$($PSQL -tA -c "select count(*) from alumni_profiles")"
echo "marketplace objects left: $left; other policies before/after: $before/$after; profiles: $profiles"
[ "$left" = "0" ] || { echo "FAIL: rollback left marketplace objects"; exit 1; }
[ "$before" = "$after" ] || { echo "FAIL: rollback changed non-marketplace policies"; exit 1; }
for f in "$ROOT"/supabase/migrations/2026093009*.sql; do $PSQL -f "$f" >/dev/null; done
$PSQL -f "$ROOT/supabase/seed_marketplace.sql"
echo "ALL SQL CHECKS PASSED"
