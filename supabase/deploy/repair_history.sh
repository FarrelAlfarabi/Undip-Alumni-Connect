#!/usr/bin/env bash
# One-time fix of the live migration history (checked 1 Nov 2026).
#
# Many migrations were run by hand in the SQL Editor, so the live history
# table did not list them, and older entries use other version numbers than
# the files in supabase/migrations. Without this fix `supabase db push` would
# try to run every file again on the live database.
#
# What it does (history table only, no schema change):
#  1. Removes the 26 live entries whose version has no file in the repo.
#     Their changes stay live; most match a repo file with another number.
#     Two have no repo file (admin_passphrase_optional, connector_probe_noop).
#  2. Marks every repo file up to 20261030200000 as applied. Older files were
#     matched by name, newer ones by their tables, columns and functions on
#     the live schema (1 Nov 2026).
#
# Exception: 20261013120000_real_login is marked applied but is NOT live
# (no app_settings, login_required, login_email_known). It belongs to the
# real-login cutover, which needs Farrel's OK. To apply it later, add a NEW
# migration file with a new number that holds its SQL.
#
# Safe to run more than once. Needs SUPABASE_DB_URL.
set -euo pipefail

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL is not set}"
SB="${SUPABASE_BIN:-supabase}"

REMOTE_ONLY=(
  20260914092033 20260915014032 20260915015540 20260915061110
  20260915062855 20260915071212 20260915124751 20260916014734
  20260916084644 20260916101528 20260916102113 20260922081708
  20261001052636 20261001053102 20261001075002 20261002074938
  20261007021422 20261007021431 20261007062343 20261007062351
  20261007062527 20261007095523 20261012024451 20261019054528
  20261019054829 20261019105307
)

REPO_APPLIED=(
  20260914050000 20260915030000 20260915031500 20260915061525
  20260915061544 20260915071412 20260915120000 20260916090000
  20260917080000 20260917100000 20260917110000 20260918090000
  20260918100000 20260918110000 20260922024915 20260922025148
  20260922030054 20260922030315 20260922120000 20260930052418
  20260930052438 20260930052502 20260930052511 20260930090000
  20260930090100 20260930090200 20260930090300 20260930100000
  20260930100100 20261001090000 20261003090000 20261003100000
  20261003110000 20261003120000 20261003130000 20261003140000
  20261003150000 20261003160000 20261003170000 20261005090000
  20261005100000 20261007090000 20261007120000 20261012090000
  20261013090000 20261013120000 20261016090000 20261018090000
  20261018100000 20261018110000 20261018120000 20261019100000
  20261019110000 20261019120000 20261030100000 20261030140000
  20261030150000 20261030160000 20261030160100 20261030170000
  20261030200000
)

"$SB" migration repair --db-url "$SUPABASE_DB_URL" --status reverted "${REMOTE_ONLY[@]}" --yes
"$SB" migration repair --db-url "$SUPABASE_DB_URL" --status applied "${REPO_APPLIED[@]}" --yes
