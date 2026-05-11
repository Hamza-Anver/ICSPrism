{external}
FUNCTION prism_bug_abort_if : DINT
VAR_INPUT
    should_abort : DINT;
    bug_id       : DINT;
END_VAR
END_FUNCTION

PROGRAM abort_oracle
VAR_INPUT
    Trigger : BOOL;
    Value   : INT;
END_VAR
VAR
    Accumulator : DINT;
END_VAR

Accumulator := Accumulator + Value;

IF Trigger THEN
    prism_bug_abort_if(1, 9001);
END_IF;
END_PROGRAM
