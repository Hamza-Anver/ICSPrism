{external}
FUNCTION prism_bug_abort_if : DINT
VAR_INPUT
    should_abort : DINT;
    bug_id       : DINT;
END_VAR
END_FUNCTION

// pipeline_controller — industrial pipeline fill process controller
//
// Bug: Buffer[FillHead] OOB write when FillHead >= 64 (Buffer is [0..63]).
//
// Why this benchmark is decisively harder for input-only fuzzing:
//
//   (1) FillHead is NEVER compared against 64 — it appears only as an array
//       index. trace-cmp has zero visibility into its growth toward 64.
//
//   (2) TWO-DIMENSIONAL ZONE DECAY with 8 zones:
//       FillHead [0,63] is split into 8 zones of 8. Each zone simultaneously
//       requires (PumpRate + ValvePos) AND PipeTemp to be in specific windows.
//       The windows are arranged so that NO fixed (PumpRate, ValvePos, PipeTemp)
//       triple satisfies all 8 zones — and several consecutive zone transitions
//       require coordinated simultaneous changes in multiple inputs.
//
//       Zone 0 [FH  0- 7]: PVsum [60,90]   PipeTemp [50,65]
//       Zone 1 [FH  8-15]: PVsum [80,110]  PipeTemp [62,77]   PVsum up, temp up
//       Zone 2 [FH 16-23]: PVsum [70,100]  PipeTemp [72,87]   PVsum back, temp up
//       Zone 3 [FH 24-31]: PVsum [55, 85]  PipeTemp [65,80]   PVsum down, temp down
//       Zone 4 [FH 32-39]: PVsum [95,125]  PipeTemp [55,70]   PVsum jumps (gap!)
//       Zone 5 [FH 40-47]: PVsum [65, 95]  PipeTemp [78,93]   PVsum down, temp jumps (gap!)
//       Zone 6 [FH 48-55]: PVsum [85,115]  PipeTemp [52,67]   PVsum up, temp folds back (gap!)
//       Zone 7 [FH 56-63]: PVsum [75,105]  PipeTemp [63,78]   PVsum down, temp up
//
//       Critical transitions with NO input overlap between zones:
//         3→4: PVsum must jump from ≤85 to ≥95 (9-unit gap)
//         4→5: PipeTemp must jump from ≤70 to ≥78 while PVsum drops
//         5→6: PipeTemp must drop from ≥78 to ≤67 (fold-back of ~20 units)
//
//   (3) 7 inputs (vs 4 in valve_sequencer) give the custom mutator a richer
//       space: for each zone, PumpRate AND ValvePos AND PipeTemp must be set
//       correctly — three bytes to coordinate, not one.
//
//   (4) Decay is -6 per bad cycle vs +1 advance per 4th qualifying cycle.
//       Random inputs decay FillHead rapidly; only sustained zone-correct
//       inputs allow growth. Without FillHead state signal, the fuzzer cannot
//       know which zone it is in or which transition is approaching.
//
//   (5) Two pre-fill phases (PRIME, FLOW) are guided by trace-cmp and add
//       ~80 cycles of required navigation before FILL begins.
//
// Phase path:
//   IDLE  → Cmd = 1
//   PRIME → PrimeScore >= 8   (every 3rd phase-cycle, combined sum, decay-2) ~30+ cycles
//   FLOW  → FluxScore >= 8    (combined PipeTemp+CoolantRate, halved/11cy)   ~50+ cycles
//   FILL  → FillHead reaches 64 (every 4th qualifying cycle, 8-zone 2D decay) ~300+ cycles
//
// Key variables for state signal: Phase, PrimeScore, FluxScore,
//   FlowAccum, PressAccum, TempAccum, FillHead.
// FillHead is the only one invisible to trace-cmp.
// (PVsum = PumpRate + ValvePos) zone requirements make the state signal
// especially valuable: the fuzzer must know FillHead to know which inputs
// to set, which trace-cmp cannot determine from TempIn comparisons alone.

VAR_GLOBAL CONSTANT
    PHASE_IDLE  : SINT := 0;
    PHASE_PRIME : SINT := 1;
    PHASE_FLOW  : SINT := 2;
    PHASE_FILL  : SINT := 3;
END_VAR

PROGRAM PLC_PRG
VAR_INPUT
    PumpRate    : INT  := 0;
    ValvePos    : INT  := 0;
    PipeTemp    : INT  := 0;
    BackPressure: INT  := 0;
    FeedConc    : INT  := 0;
    CoolantRate : INT  := 0;
    Cmd         : SINT := 0;
END_VAR
VAR
    Ctrl : PipelineCtrl;
END_VAR

Ctrl(
    PumpRate     := PumpRate,
    ValvePos     := ValvePos,
    PipeTemp     := PipeTemp,
    BackPressure := BackPressure,
    FeedConc     := FeedConc,
    CoolantRate  := CoolantRate,
    Cmd          := Cmd
);

END_PROGRAM


FUNCTION_BLOCK PipelineCtrl
VAR_INPUT
    PumpRate    : INT;
    ValvePos    : INT;
    PipeTemp    : INT;
    BackPressure: INT;
    FeedConc    : INT;
    CoolantRate : INT;
    Cmd         : SINT;
END_VAR
VAR_OUTPUT
    Status      : SINT;
END_VAR
VAR
    Phase        : SINT := PHASE_IDLE;
    CycleCount   : INT  := 0;
    // PRIME phase
    PrimeCycles  : INT  := 0;
    PrimeScore   : INT  := 0;
    // FLOW phase
    FluxScore    : INT  := 0;
    FluxSum      : INT  := 0;
    // FILL phase accumulators
    FlowAccum    : INT  := 0;
    PressAccum   : INT  := 0;
    TempAccum    : INT  := 0;
    PhaseCounter : INT  := 0;
    // Hidden OOB counter — NEVER compared against 64, only used as array index
    FillHead     : INT  := 0;
    // OOB write target
    Buffer       : ARRAY[0..63] OF INT;
    PVsum        : INT  := 0;
    i            : INT;
END_VAR

CycleCount := CycleCount + 1;

CASE Phase OF

    PHASE_IDLE:
        IF Cmd = 1 THEN
            FOR i := 0 TO 63 DO
                Buffer[i] := 0;
            END_FOR;
            PrimeCycles  := 0;
            PrimeScore   := 0;
            FluxScore    := 0;
            FlowAccum    := 0;
            PressAccum   := 0;
            TempAccum    := 0;
            PhaseCounter := 0;
            FillHead     := 0;
            PVsum        := 0;
            Phase        := PHASE_PRIME;
        END_IF;

    PHASE_PRIME:
        // Combined PumpRate+BackPressure sum forces simultaneous tuning of
        // two inputs. trace-cmp sees the sum, not individual contributions.
        // Only every 3rd phase-cycle counts; decay-2 forces sustained inputs.
        PrimeCycles := PrimeCycles + 1;
        PVsum := PumpRate + BackPressure;

        IF PrimeCycles MOD 3 = 0 THEN
            IF PVsum >= 80 AND PVsum <= 160 AND ValvePos >= 15 AND ValvePos <= 60 THEN
                PrimeScore := PrimeScore + 1;
            ELSE
                IF PrimeScore > 1 THEN
                    PrimeScore := PrimeScore - 2;
                ELSE
                    PrimeScore := 0;
                END_IF;
            END_IF;
        END_IF;

        IF PrimeScore >= 8 THEN
            Phase := PHASE_FLOW;
        END_IF;

    PHASE_FLOW:
        // Combined PipeTemp + CoolantRate sum partially hides which input is
        // responsible. Halved every 11 global cycles — forces sustained inputs.
        FluxSum := PipeTemp + CoolantRate;

        IF FluxSum >= 80 AND FluxSum <= 160 AND FeedConc >= 20 AND FeedConc <= 70 THEN
            FluxScore := FluxScore + 1;
        ELSE
            IF FluxScore > 1 THEN
                FluxScore := FluxScore - 2;
            ELSE
                FluxScore := 0;
            END_IF;
        END_IF;

        IF CycleCount MOD 11 = 0 AND FluxScore > 0 THEN
            FluxScore := FluxScore / 2;
        END_IF;

        IF FluxScore >= 8 THEN
            Phase := PHASE_FILL;
        END_IF;

    PHASE_FILL:
        PhaseCounter := PhaseCounter + 1;

        // Three accumulator channels — all visible to trace-cmp, which guides
        // the fuzzer into FILL and maintains channel health.

        IF PumpRate >= 40 AND PumpRate <= 90 THEN
            FlowAccum := FlowAccum + 1;
        ELSE
            IF FlowAccum > 1 THEN
                FlowAccum := FlowAccum - 2;
            ELSE
                FlowAccum := 0;
            END_IF;
        END_IF;

        IF BackPressure >= 30 AND BackPressure <= 80 THEN
            PressAccum := PressAccum + 1;
        ELSE
            IF PressAccum > 0 THEN
                PressAccum := PressAccum - 1;
            END_IF;
        END_IF;

        // TempAccum window [50,100] — all zone PipeTemp windows are subsets
        // of this range, so zone requirements always keep TempAccum healthy.
        IF PipeTemp >= 50 AND PipeTemp <= 100 THEN
            TempAccum := TempAccum + 1;
        ELSE
            IF TempAccum > 1 THEN
                TempAccum := TempAccum - 2;
            ELSE
                TempAccum := 0;
            END_IF;
        END_IF;

        // FillHead advances every 4th qualifying cycle.
        // FillHead is NEVER compared against 64 — only appears as array index.
        IF FlowAccum > 6 AND PressAccum > 5 AND TempAccum > 6 THEN
            IF PhaseCounter MOD 4 = 0 THEN
                FillHead := FillHead + 1;
            END_IF;
        END_IF;

        // TWO-DIMENSIONAL ZONE DECAY — the decisive state-signal barrier:
        //
        // FillHead [0,63] is partitioned into 8 zones of 8. Each zone requires
        // BOTH (PumpRate + ValvePos) AND PipeTemp to be in specific windows.
        // These two conditions must be met simultaneously every cycle or FillHead
        // decays by 6 — erasing up to 6 accumulated advances in one bad cycle.
        //
        // Critical transitions (no overlap between adjacent zones):
        //   3→4: PVsum must jump from ≤85 to ≥95 — 9-unit gap, must coordinate
        //         PumpRate AND ValvePos inputs at exactly the right cycle
        //   4→5: PipeTemp must jump ≥8 units while PVsum drops ≥30 units
        //   5→6: PipeTemp must drop ≥11 units (fold-back)
        //
        // trace-cmp instruments PVsum and PipeTemp comparisons but the required
        // windows change with FillHead (state, not input). An input-only fuzzer
        // receives conflicting gradients: e.g., PVsum should be high for zone 4
        // but low for zones 0, 2, 3, 5. Only the key-state signal on FillHead
        // reveals which zone is currently active.
        //
        // A custom mutator with FillHead signal can look up the current zone and
        // set PumpRate, ValvePos, AND PipeTemp precisely — three bytes at once.
        PVsum := PumpRate + ValvePos;

        IF FillHead < 8 THEN
            // Zone 0: PVsum [60,90], PipeTemp [50,65]
            IF PVsum < 60 OR PVsum > 90 OR PipeTemp < 50 OR PipeTemp > 65 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 16 THEN
            // Zone 1: PVsum [80,110], PipeTemp [62,77]
            IF PVsum < 80 OR PVsum > 110 OR PipeTemp < 62 OR PipeTemp > 77 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 24 THEN
            // Zone 2: PVsum [70,100], PipeTemp [72,87]
            IF PVsum < 70 OR PVsum > 100 OR PipeTemp < 72 OR PipeTemp > 87 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 32 THEN
            // Zone 3: PVsum [55,85], PipeTemp [65,80]
            IF PVsum < 55 OR PVsum > 85 OR PipeTemp < 65 OR PipeTemp > 80 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 40 THEN
            // Zone 4: PVsum [95,125], PipeTemp [55,70]
            // *** GAP from zone 3: PVsum must jump from ≤85 to ≥95 ***
            IF PVsum < 95 OR PVsum > 125 OR PipeTemp < 55 OR PipeTemp > 70 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 48 THEN
            // Zone 5: PVsum [65,95], PipeTemp [78,93]
            // *** GAP from zone 4: PipeTemp must jump from ≤70 to ≥78 ***
            IF PVsum < 65 OR PVsum > 95 OR PipeTemp < 78 OR PipeTemp > 93 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSIF FillHead < 56 THEN
            // Zone 6: PVsum [85,115], PipeTemp [52,67]
            // *** GAP from zone 5: PipeTemp must drop from ≥78 to ≤67 ***
            IF PVsum < 85 OR PVsum > 115 OR PipeTemp < 52 OR PipeTemp > 67 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        ELSE
            // Zone 7: PVsum [75,105], PipeTemp [63,78]
            IF PVsum < 75 OR PVsum > 105 OR PipeTemp < 63 OR PipeTemp > 78 THEN
                IF FillHead > 5 THEN
                    FillHead := FillHead - 6;
                ELSE
                    FillHead := 0;
                END_IF;
            END_IF;
        END_IF;

        // OOB write: Buffer is [0..63] (64 elements).
        // FillHead >= 64 writes out of bounds.
        // FillHead appears ONLY here — no comparison against 64 anywhere.
        Buffer[FillHead] := CycleCount;
        IF FillHead > 63 THEN
            prism_bug_abort_if(1, 9001);
        END_IF;

END_CASE;

Status := Phase;

END_FUNCTION_BLOCK
