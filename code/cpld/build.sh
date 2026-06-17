#!/bin/sh -e
TOOLS=~/atf15xx_yosys
cd "$(dirname "$0")"

# ── Synthesis ──────────────────────────────────────────────
printf "Synthesising... "
$TOOLS/run_yosys.sh cpld > /tmp/cpld_yosys.log 2>&1 || {
    echo "SYNTHESIS FAILED"; cat /tmp/cpld_yosys.log; exit 1
}
echo "done."

# ── Fitter ─────────────────────────────────────────────────
# Cascade logic and foldback prevent cross-block fanin overflow
# (ATF1508AS limit: 40 unique inputs per block).
printf "Fitting... "
$TOOLS/run_fitter.sh cpld \
  -strategy Cascade_Logic ON \
  -strategy Foldback_Logic ON \
  -strategy Preassignment KEEP > /tmp/cpld_fitter.log 2>&1 || true

if ! grep -q "Design FITS" cpld.fit 2>/dev/null; then
    echo "FITTER FAILED — design does not fit."; tail -20 /tmp/cpld_fitter.log; exit 1
fi
MC=$(awk '/Total Macro cells used/{print $5}' cpld.fit)
echo "done.  Fitter completed — ${MC} MCs used."

# ── Pin assignment check ────────────────────────────────────
# Compares //PIN: constraints in cpld.v against the PLCC84 placement
# section of cpld.fit to verify the fitter honoured all preassignments.
printf "Checking pin assignments... "
PIN_RESULT=$(awk '
NR==FNR {
    idx = index($0, "//PIN: ")
    if (idx > 0) {
        rest = substr($0, idx + 7)
        n = split(rest, a, /[[:space:]]*:[[:space:]]*/)
        if (n >= 2) {
            sig = a[1]; gsub(/[[:space:]]/, "", sig)
            pin = a[2]; gsub(/[^0-9]/, "", pin)
            if (sig ~ /^[A-Za-z]/ && length(pin) > 0 && pin+0 > 0)
                expected[sig] = pin+0
        }
    }
    next
}
/^PLCC84 Pin\/Node Placement:/ { in_sec=1; next }
in_sec && /^Pin / {
    sig = $4; sub(/;.*/, "", sig); actual[sig] = $2+0
}
END {
    pass=0; fail=0
    for (s in expected) {
        if (actual[s] == expected[s]) { pass++ }
        else {
            printf "  MISMATCH: %-14s expected %2d, got %s\n", s, expected[s],
                (s in actual ? actual[s] : "not_found")
            fail++
        }
    }
    printf "RESULT %d %d\n", pass, fail
}
' cpld.v cpld.fit)

PIN_PASS=$(echo "$PIN_RESULT" | awk '/^RESULT/{print $2}')
PIN_FAIL=$(echo "$PIN_RESULT" | awk '/^RESULT/{print $3}')

if [ "${PIN_FAIL:-0}" -eq 0 ]; then
    echo "all ${PIN_PASS} assignments respected."
else
    echo "${PIN_FAIL} MISMATCHES."
    echo "$PIN_RESULT" | grep "^  MISMATCH:"
    exit 1
fi

# ── Simulation ─────────────────────────────────────────────
printf "Running testbench... "
iverilog -DSIMULATION -o tb_cpld tb_cpld.v cpld.v 2>/tmp/cpld_tb.log || {
    echo "COMPILE FAILED"; cat /tmp/cpld_tb.log; exit 1
}

TB_OUT=$(vvp tb_cpld 2>&1)
PASSED=$(echo "$TB_OUT" | sed -n 's/.*Results: \([0-9]*\) passed.*/\1/p')
FAILED=$(echo "$TB_OUT" | sed -n 's/.*passed, \([0-9]*\) failed.*/\1/p')
TOTAL=$(( ${PASSED:-0} + ${FAILED:-0} ))

if [ "${FAILED:-0}" -eq 0 ] && [ "${PASSED:-0}" -gt 0 ]; then
    echo "${PASSED}/${TOTAL} tests passed."
else
    echo "FAILURES DETECTED."
    echo "$TB_OUT" | grep "^FAIL"
    printf "(%s/%s tests passed)\n" "${PASSED:-0}" "$TOTAL"
    exit 1
fi
