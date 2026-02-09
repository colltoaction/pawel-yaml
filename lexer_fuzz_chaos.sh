#!/usr/bin/env bash
# Chaos fuzzing harness for lexer/parser boundary behavior.
# Modes:
#   fuzz   - generate random inputs and execute parser
#   replay - re-run existing .yaml cases from CASE_DIR/REPLAY_PATH

set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

PARSER="./build/bin/pawel-yaml"
MODE="${MODE:-fuzz}"
ITERATIONS="${ITERATIONS:-300}"
TIMEOUT_SEC="${TIMEOUT_SEC:-2}"
FAIL_ON_TIMEOUT="${FAIL_ON_TIMEOUT:-0}"
FAIL_ON_AMBIGUOUS="${FAIL_ON_AMBIGUOUS:-0}"
REQUIRE_REPLAY_CASES="${REQUIRE_REPLAY_CASES:-0}"
CLEAR_CASES="${CLEAR_CASES:-0}"
SEED="${SEED:-1337}"
LOG_DIR="build/log"
CASE_DIR="$LOG_DIR/lexer_fuzz_cases"
REPLAY_PATH="${REPLAY_PATH:-$CASE_DIR}"
SIG_LOG="$LOG_DIR/lexer_fuzz_signatures.log"
RUN_LOG="$LOG_DIR/lexer_fuzz_run.log"

if [[ "${1:-}" == "replay" ]]; then
    MODE="replay"
    shift
elif [[ "${1:-}" == "fuzz" ]]; then
    MODE="fuzz"
    shift
fi

if [[ "$MODE" == "fuzz" && -n "${1:-}" ]]; then
    SEED="$1"
    shift
fi

if [[ "$MODE" == "replay" && -n "${1:-}" ]]; then
    REPLAY_PATH="$1"
    shift
fi

mkdir -p "$LOG_DIR" "$CASE_DIR"
: > "$SIG_LOG"
: > "$RUN_LOG"

if [[ "$CLEAR_CASES" == "1" ]]; then
    rm -f "$CASE_DIR"/timeout_*.yaml "$CASE_DIR"/timeout_*.err "$CASE_DIR"/crash_*.yaml "$CASE_DIR"/crash_*.err
fi

if [[ ! -x "$PARSER" ]]; then
    echo "Building parser binary..."
    if ! make build/bin/pawel-yaml >/dev/null 2>&1; then
        echo "ERROR: failed to build parser"
        exit 1
    fi
fi

SUITE_ROOT=""
if [[ -d "build/lib/yaml-test-suite" ]]; then
    SUITE_ROOT="build/lib/yaml-test-suite"
elif [[ -d ".agent/lib/yaml-test-suite" ]]; then
    SUITE_ROOT=".agent/lib/yaml-test-suite"
fi

RANDOM="$SEED"

TOKENS=(
    "!" "!!str" "!!!bad" "&a" "*a" ":" "?" "-" "," "{" "}" "[" "]"
    "---" "..." "|-" ">+" "%YAML 1.2" "\"unterminated" "'unterminated"
    "#comment" "  " "\t" $'\xE2\x90\xA3'
)

random_token() {
    local idx=$((RANDOM % ${#TOKENS[@]}))
    printf '%s' "${TOKENS[$idx]}"
}

random_printable_blob() {
    local len=$((1 + (RANDOM % 220)))
    tr -dc '\11\12\15\40-\176' < /dev/urandom 2>/dev/null | head -c "$len"
}

token_salad() {
    local lines=$((1 + (RANDOM % 12)))
    local i j parts out=""
    for ((i=0; i<lines; i++)); do
        parts=$((1 + (RANDOM % 6)))
        for ((j=0; j<parts; j++)); do
            out+="$(random_token)"
            if (( j + 1 < parts )); then
                out+=" "
            fi
        done
        out+=$'\n'
    done
    printf '%s' "$out"
}

suite_mutation() {
    if [[ -z "$SUITE_ROOT" ]]; then
        token_salad
        return
    fi

    local pick_id input mutate_mode
    pick_id="$(ls "$SUITE_ROOT/src"/*.yaml 2>/dev/null | shuf -n 1 | xargs -r basename | sed 's/\.yaml$//')"
    if [[ -z "$pick_id" ]]; then
        token_salad
        return
    fi

    input="$(python3 extract_test_yaml.py "$pick_id" "$SUITE_ROOT" 2>/dev/null || true)"
    if [[ -z "$input" ]]; then
        token_salad
        return
    fi

    mutate_mode=$((RANDOM % 4))
    case "$mutate_mode" in
        0) printf '%s\n%s\n' "$(random_token)" "$input" ;;
        1) printf '%s\n%s\n' "$input" "$(random_token)" ;;
        2) printf '%s\n%s\n' "$input" "$(token_salad)" ;;
        3) printf '%s\n%s\n%s\n' "$(random_token)" "$input" "$(random_token)" ;;
    esac
}

generate_case() {
    local mode=$((RANDOM % 3))
    case "$mode" in
        0) random_printable_blob ;;
        1) token_salad ;;
        2) suite_mutation ;;
    esac
}

timeouts=0
crashes=0
accepted=0
rejected=0
ambiguous=0
replayed=0

run_case_file() {
    local case_file="$1"
    local case_label="$2"
    local save_failures="$3"
    local err_file status sig

    err_file="$(mktemp)"
    timeout "${TIMEOUT_SEC}s" "$PARSER" < "$case_file" >/dev/null 2>"$err_file"
    status=$?
    sig="$(head -n 1 "$err_file" | tr -d '\r')"
    [[ -z "$sig" ]] && sig="<no-stderr>"
    echo "$sig" >> "$SIG_LOG"

    if rg -q "syntax is ambiguous" "$err_file"; then
        ((ambiguous++))
    fi

    if [[ "$status" -eq 124 ]]; then
        ((timeouts++))
        if [[ "$save_failures" == "1" ]]; then
            cp "$case_file" "$CASE_DIR/timeout_${case_label}.yaml"
            cp "$err_file" "$CASE_DIR/timeout_${case_label}.err"
        fi
    elif [[ "$status" -ge 128 ]]; then
        ((crashes++))
        if [[ "$save_failures" == "1" ]]; then
            cp "$case_file" "$CASE_DIR/crash_${case_label}.yaml"
            cp "$err_file" "$CASE_DIR/crash_${case_label}.err"
        fi
    elif [[ "$status" -eq 0 ]]; then
        ((accepted++))
    else
        ((rejected++))
    fi

    rm -f "$err_file"
}

echo "=== LEXER CHAOS FUZZ ===" | tee -a "$RUN_LOG"
echo "mode=$MODE timeout=${TIMEOUT_SEC}s" | tee -a "$RUN_LOG"
if [[ "$MODE" == "fuzz" ]]; then
    echo "seed=$SEED iterations=$ITERATIONS" | tee -a "$RUN_LOG"
else
    echo "replay_path=$REPLAY_PATH" | tee -a "$RUN_LOG"
fi
echo "" | tee -a "$RUN_LOG"

if [[ "$MODE" == "replay" ]]; then
    shopt -s nullglob
    replay_files=()
    if [[ -d "$REPLAY_PATH" ]]; then
        replay_files=("$REPLAY_PATH"/*.yaml)
    else
        replay_files=($REPLAY_PATH)
    fi
    shopt -u nullglob

    if [[ "${#replay_files[@]}" -eq 0 ]]; then
        echo "No replay cases found: $REPLAY_PATH" | tee -a "$RUN_LOG"
        if [[ "$REQUIRE_REPLAY_CASES" == "1" ]]; then
            exit 1
        fi
        exit 0
    fi

    for case_file in "${replay_files[@]}"; do
        base="$(basename "$case_file" .yaml)"
        ((replayed++))
        run_case_file "$case_file" "$base" "0"
    done
else
    for ((i=1; i<=ITERATIONS; i++)); do
        input="$(generate_case)"
        case_file="$(mktemp)"
        printf '%s\n' "$input" > "$case_file"
        run_case_file "$case_file" "$i" "1"
        rm -f "$case_file"
    done
fi

echo "Summary:" | tee -a "$RUN_LOG"
if [[ "$MODE" == "replay" ]]; then
    echo "  replayed=$replayed" | tee -a "$RUN_LOG"
fi
echo "  accepted=$accepted" | tee -a "$RUN_LOG"
echo "  rejected=$rejected" | tee -a "$RUN_LOG"
echo "  timeouts=$timeouts" | tee -a "$RUN_LOG"
echo "  crashes=$crashes" | tee -a "$RUN_LOG"
echo "  ambiguous=$ambiguous" | tee -a "$RUN_LOG"
echo "" | tee -a "$RUN_LOG"
echo "Top error signatures:" | tee -a "$RUN_LOG"
sort "$SIG_LOG" | uniq -c | sort -nr | head -n 15 | tee -a "$RUN_LOG"
echo "" | tee -a "$RUN_LOG"
echo "Saved cases: $CASE_DIR" | tee -a "$RUN_LOG"
echo "Run log: $RUN_LOG" | tee -a "$RUN_LOG"

if [[ "$crashes" -gt 0 ]]; then
    exit 1
fi

if [[ "$FAIL_ON_TIMEOUT" == "1" && "$timeouts" -gt 0 ]]; then
    exit 1
fi

if [[ "$FAIL_ON_AMBIGUOUS" == "1" && "$ambiguous" -gt 0 ]]; then
    exit 1
fi

exit 0
