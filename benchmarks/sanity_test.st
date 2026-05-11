PROGRAM sanity_test
VAR_INPUT
    Delta  : INT;
    Reset  : BOOL;
    Enable : BOOL;
END_VAR
VAR
    Accumulator : INT;
    CycleNum    : INT;
    EdgeCount   : INT;
    PrevEnable  : BOOL;
    Armed       : BOOL;
END_VAR

CycleNum := CycleNum + 1;

IF Reset THEN
    Accumulator := 0;
    Armed := FALSE;
ELSE
    IF Enable THEN
        Accumulator := Accumulator + Delta;
    END_IF;

    IF Enable AND NOT PrevEnable THEN
        EdgeCount := EdgeCount + 1;
    END_IF;

    IF Accumulator >= 10 THEN
        Armed := TRUE;
    END_IF;
END_IF;

PrevEnable := Enable;
END_PROGRAM
