#!/usr/bin/env bash
# One verify for local runs and later CI (MW-037 / MW-021).
# From the repo root:
#   lazvault heavy --project moonwake -- game/tools/verify.sh
# Exit 0 only when import, every smoke, the type gate, gdformat and autoplay pass.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
GODOT="${GODOT:-godot}"

fail() {
	echo "VERIFY_FAIL: $*" >&2
	exit 1
}

run_logged() {
	local log="$1"
	shift
	set +e
	"$@" >"$log" 2>&1
	local rc=$?
	set -e
	cat "$log"
	return "$rc"
}

echo "VERIFY import"
"$GODOT" --headless --path "$ROOT" --import

smokes=(
	boot_smoke:BOOT_SMOKE_PASS
	raid_visibility_smoke:RAID_VIS_PASS
	combat_readability_smoke:COMBAT_READ_PASS
	kit_slots_smoke:KIT_SLOTS_PASS
	boss_phases_smoke:BOSS_PHASES_PASS
	boons_smoke:BOONS_SMOKE_PASS
	pacts_smoke:PACTS_SMOKE_PASS
)

for spec in "${smokes[@]}"; do
	scene="${spec%%:*}"
	marker="${spec##*:}"
	echo "VERIFY smoke $scene"
	log="$(mktemp)"
	if ! run_logged "$log" "$GODOT" --headless --path "$ROOT" --fixed-fps 60 "res://scenes/tests/${scene}.tscn"; then
		rm -f "$log"
		fail "$scene exited non-zero"
	fi
	if grep -q 'SCRIPT ERROR' "$log"; then
		rm -f "$log"
		fail "$scene printed SCRIPT ERROR"
	fi
	if ! grep -q "$marker" "$log"; then
		rm -f "$log"
		fail "$scene missing $marker"
	fi
	rm -f "$log"
done

echo "VERIFY type gate"
gate=0
while IFS= read -r f; do
	rel="${f#game/}"
	log="$(mktemp)"
	# --check-only exits non-zero on class_name / autoload "not declared" lines
	# it cannot see. Those are not the gate. Count only warning-as-error.
	"$GODOT" --headless --path "$ROOT" --check-only --script "res://$rel" >"$log" 2>&1 || true
	n="$(grep -c 'Warning treated as error' "$log" || true)"
	if [[ "$n" -gt 0 ]]; then
		grep 'Warning treated as error' "$log" || true
		gate=$((gate + n))
	fi
	rm -f "$log"
done < <(git -C "$REPO" ls-files '*.gd')
echo "TYPE_GATE=$gate"
if [[ "$gate" -ne 0 ]]; then
	fail "type gate is $gate, want 0"
fi

echo "VERIFY gdformat"
mapfile -t gds < <(git -C "$REPO" ls-files '*.gd' | sed 's|^game/||')
if [[ "${#gds[@]}" -eq 0 ]]; then
	fail "no GDScript files to format-check"
fi
(
	cd "$ROOT"
	gdformat --check "${gds[@]}"
)

echo "VERIFY autoplay"
log="$(mktemp)"
if ! run_logged "$log" "$GODOT" --headless --path "$ROOT" --fixed-fps 60 res://tests/autoplay/autoplay.tscn -- mode=kill sectors=all seed=1; then
	rm -f "$log"
	fail "autoplay exited non-zero"
fi
if grep -q 'SCRIPT ERROR' "$log"; then
	rm -f "$log"
	fail "autoplay printed SCRIPT ERROR"
fi
if ! grep -q 'AUTOPLAY_DONE' "$log"; then
	rm -f "$log"
	fail "autoplay missing AUTOPLAY_DONE"
fi
rm -f "$log"

echo "VERIFY_PASS"
