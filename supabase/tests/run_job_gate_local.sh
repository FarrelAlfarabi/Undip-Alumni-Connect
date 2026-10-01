#!/usr/bin/env bash
# Runs the job-posting gate SQL checks on a throwaway local Postgres.
# Never touches any Supabase project. Needs Postgres server binaries and psql.
# Usage: supabase/tests/run_job_gate_local.sh
#
# Separate from run_local.sh on purpose: the full migration chain does not
# replay from scratch (20260915061525 revokes on a function that a later file
# creates; the live database got it from a dashboard hotfix). Old migrations
# are therefore applied with errors tolerated, and the new one must apply
# cleanly, twice.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}"
WORK="$(mktemp -d)"
PORT="${PGPORT:-54330}"
RUN=""
if [ "$(id -u)" = "0" ]; then chown -R postgres "$WORK"; RUN="runuser -u postgres --"; fi
PSQL="$RUN $PGBIN/psql -h $WORK -p $PORT -U postgres -q -X"

cleanup() { $RUN "$PGBIN/pg_ctl" -D "$WORK/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT

$RUN "$PGBIN/initdb" -D "$WORK/data" -U postgres --auth=trust >/dev/null
$RUN "$PGBIN/pg_ctl" -D "$WORK/data" -o "-k $WORK -p $PORT -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null
$PSQL -d postgres -v ON_ERROR_STOP=1 -c "create database demo"
PSQL="$PSQL -d demo"

$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/tests/local_stub.sql"
NEW=20261001090000_job_posting_requires_subscriber.sql
for f in "$ROOT"/supabase/migrations/*.sql; do
  [ "$(basename "$f")" = "$NEW" ] && continue
  $PSQL -f "$f" >/dev/null 2>&1 || true
done
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/seed.sql" >/dev/null

echo "== new migration, applied twice"
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations/$NEW" >/dev/null
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations/$NEW" >/dev/null
echo "== job_posting_gate_test.sql"
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/tests/job_posting_gate_test.sql"
echo "== seed_job_posts.sql still loads as owner"
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/seed_job_posts.sql" >/dev/null
echo "== rollback twice, then re-apply"
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/rollback_job_posting_gate.sql" >/dev/null
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/rollback_job_posting_gate.sql" >/dev/null
$PSQL -v ON_ERROR_STOP=1 -f "$ROOT/supabase/migrations/$NEW" >/dev/null
echo "ALL JOB GATE CHECKS PASSED"
