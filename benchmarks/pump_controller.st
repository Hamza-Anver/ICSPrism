{external}
FUNCTION prism_bug_abort_if : DINT
VAR_INPUT
    should_abort : DINT;
    bug_id       : DINT;
END_VAR
END_FUNCTION

VAR_GLOBAL CONSTANT
    MODE_INIT  : SINT := 0;
    MODE_IDLE  : SINT := 1;
    MODE_ARMED : SINT := 2;
    MODE_RUN   : SINT := 3;
    MODE_FAULT : SINT := 4;
END_VAR

PROGRAM PLC_PRG
VAR_INPUT
    CmdArm    : BOOL := FALSE;
    CmdStart  : BOOL := FALSE;
    CmdReset  : BOOL := FALSE;
    Pressure  : INT := 0;
    Temp      : INT := 0;
END_VAR
VAR
    Controller : PumpController;
END_VAR

Controller(
    CmdArm := CmdArm,
    CmdStart := CmdStart,
    CmdReset := CmdReset,
    Pressure := Pressure,
    Temp := Temp
);

END_PROGRAM


FUNCTION_BLOCK PumpController
VAR_INPUT
    CmdArm    : BOOL;
    CmdStart  : BOOL;
    CmdReset  : BOOL;
    Pressure  : INT;
    Temp      : INT;
END_VAR
VAR
    Mode          : SINT := MODE_INIT;
    CycleCount    : INT := 0;
    PressureScore : INT := 0;
    ArmedCycles   : INT := 0;
    Offset        : INT := 0;
    Buffer        : ARRAY[0..7] OF INT;
    i             : INT;
END_VAR
VAR_OUTPUT
    Status        : SINT;
END_VAR

CycleCount := CycleCount + 1;

CASE Mode OF

    MODE_INIT:
        FOR i := 0 TO 7 DO
            Buffer[i] := 0;
        END_FOR;
        PressureScore := 0;
        ArmedCycles := 0;
        Offset := 0;
        Mode := MODE_IDLE;

    MODE_IDLE:

        IF CmdArm THEN
            Mode := MODE_ARMED;
            ArmedCycles := 0;
        END_IF;

    MODE_ARMED:
        ArmedCycles := ArmedCycles + 1;

        IF CmdStart AND ArmedCycles >= 3 THEN
            Mode := MODE_RUN;
        END_IF;

    MODE_RUN:
        IF Pressure > 70 THEN
            PressureScore := PressureScore + 1;
        END_IF;

        IF Temp > 50 AND Temp < 60 THEN
            Offset := Offset + 1;
        END_IF;

        IF PressureScore >= 4 THEN
            Buffer[0] := Buffer[0] + 1;
        END_IF;

        IF Buffer[0] > 2 THEN
            Buffer[1] := Buffer[1] + 1;
        END_IF;

        // Deliberate deep bug:
        // Requires entering RUN, then building enough history so Offset becomes large.
        // Input-only fuzzing with frequent resets should struggle more than stateful fuzzing.
        IF Buffer[1] > 1 THEN
            prism_bug_abort_if(1, 9001);
            Buffer[Offset] := 1234;
        END_IF;

        IF CmdReset THEN
            Mode := MODE_IDLE;
            PressureScore := 0;
            ArmedCycles := 0;
            Offset := 0;
        END_IF;

        IF Temp > 90 THEN
            Mode := MODE_FAULT;
        END_IF;

    MODE_FAULT:
        IF CmdReset THEN
            Mode := MODE_IDLE;
            PressureScore := 0;
            ArmedCycles := 0;
            Offset := 0;
        END_IF;

END_CASE;

Status := Mode;

END_FUNCTION_BLOCK