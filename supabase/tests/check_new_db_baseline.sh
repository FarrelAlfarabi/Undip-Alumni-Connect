#!/usr/bin/env bash
# Checks that supabase/deploy/repair_history_new.sh marks exactly the migration
# files up to its cutoff as applied (no file missing, none invented).
set -euo pipefail
cd "$(dirname "$0")/../.."
S=supabase/deploy/repair_history_new.sh
CUT=$(grep -oE '^CUTOFF=[0-9]{14}' "$S" | cut -d= -f2)
want=$(ls supabase/migrations | grep -oE '^[0-9]{14}' | awk -v c="$CUT" '$1<=c' | sort)
have=$(sed -n '/^BASELINE=(/,/^)/p' "$S" | grep -oE '[0-9]{14}' | sort)
[ "$want" = "$have" ] || { echo "Baseline list differs from migration files up to $CUT"; diff <(echo "$want") <(echo "$have") || true; exit 1; }
echo "baseline ok: $(echo "$have" | wc -l) versions up to $CUT"
