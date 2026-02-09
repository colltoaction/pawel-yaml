#!/usr/bin/env bash
# Lexer chaos runner for quoted map key rules.
# Tests whether QMAP_KEY / SMAP_KEY rules are required or redundant.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

SCANNING_FILE="src/scanning.l"
BACKUP_FILE="$(mktemp)"

cleanup() {
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$SCANNING_FILE"
        rm -f "$BACKUP_FILE"
        make >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

cp "$SCANNING_FILE" "$BACKUP_FILE"

range_for_token() {
    local token="$1"
    local ret_line start_line end_line

    ret_line="$(rg -n "return ${token};" "$BACKUP_FILE" -m1 | cut -d: -f1 || true)"
    if [[ -z "$ret_line" ]]; then
        echo ""
        return 0
    fi

    start_line="$(
        awk -v ret="$ret_line" '
            NR <= ret { lines[NR] = $0 }
            END {
                for (i = ret; i >= 1; i--) {
                    if (lines[i] ~ /\{[[:space:]]*$/) {
                        print i
                        exit
                    }
                }
            }
        ' "$BACKUP_FILE"
    )"

    end_line="$(
        awk -v ret="$ret_line" '
            NR >= ret && /^[[:space:]]*}[[:space:]]*$/ {
                print NR
                exit
            }
        ' "$BACKUP_FILE"
    )"

    if [[ -n "$start_line" && -n "$end_line" ]]; then
        echo "$start_line $end_line"
    else
        echo ""
    fi
}

write_variant() {
    local drop_qmap="$1"
    local drop_smap="$2"
    local q_range s_range
    local q_s=0 q_e=-1 s_s=0 s_e=-1

    q_range="$(range_for_token "QMAP_KEY")"
    s_range="$(range_for_token "SMAP_KEY")"

    if [[ "$drop_qmap" == "1" && -n "$q_range" ]]; then
        read -r q_s q_e <<<"$q_range"
    fi
    if [[ "$drop_smap" == "1" && -n "$s_range" ]]; then
        read -r s_s s_e <<<"$s_range"
    fi

    awk -v q_s="$q_s" -v q_e="$q_e" -v s_s="$s_s" -v s_e="$s_e" '
        {
            if (q_e >= q_s && NR >= q_s && NR <= q_e) next
            if (s_e >= s_s && NR >= s_s && NR <= s_e) next
            print
        }
    ' "$BACKUP_FILE" > "$SCANNING_FILE"
}

probe_case() {
    local yaml_input="$1"
    if printf '%s\n' "$yaml_input" | ./build/bin/pawel-yaml >/dev/null 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
    fi
}

run_baseline_metrics() {
    local out total passed failed rate
    out="$(python3 run_baseline.py 2>/dev/null)"
    total="$(awk '/^Total Tests Found:/ {print $4}' <<<"$out")"
    passed="$(awk '/^Passed:/ {print $2}' <<<"$out")"
    failed="$(awk '/^Failed:/ {print $2}' <<<"$out")"
    rate="$(awk '/^Pass Rate:/ {print $3}' <<<"$out")"
    echo "${total}|${passed}|${failed}|${rate}"
}

run_variant() {
    local label="$1"
    local drop_qmap="$2"
    local drop_smap="$3"
    local metrics total passed failed rate
    local p_double p_single p_plain

    write_variant "$drop_qmap" "$drop_smap"
    if ! make clean >/dev/null 2>&1 || ! make >/dev/null 2>&1; then
        echo "${label}|MAKE_FAIL|MAKE_FAIL|MAKE_FAIL|MAKE_FAIL|MAKE_FAIL|MAKE_FAIL|MAKE_FAIL"
        return 0
    fi

    p_double="$(probe_case '"key": "value"')"
    p_single="$(probe_case "'key': 'value'")"
    p_plain="$(probe_case 'key: value')"

    metrics="$(run_baseline_metrics)"
    IFS='|' read -r total passed failed rate <<<"$metrics"
    echo "${label}|${p_double}|${p_single}|${p_plain}|${total}|${passed}|${failed}|${rate}"
}

echo "=== LEXING CHAOS ENGINEERING ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

baseline="$(run_variant "baseline" 0 0)"
no_qmap="$(run_variant "drop_qmap" 1 0)"
no_smap="$(run_variant "drop_smap" 0 1)"
drop_both="$(run_variant "drop_both" 1 1)"

printf "%s\n" "variant|double_key|single_key|plain_key|suite_total|suite_pass|suite_fail|suite_rate"
printf "%s\n" "$baseline"
printf "%s\n" "$no_qmap"
printf "%s\n" "$no_smap"
printf "%s\n" "$drop_both"
