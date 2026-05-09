FUNCTION_BLOCK Counter
VAR_INPUT
    Increment : INT;
    Reset     : BOOL;
END_VAR
VAR
    Value     : INT;
    TotalCalls: INT;
END_VAR

TotalCalls := TotalCalls + 1;
IF Reset THEN
    Value := 0;
ELSE
    Value := Value + Increment;
END_IF
END_FUNCTION_BLOCK


PROGRAM HarnessTest
VAR_INPUT
    A        : INT;       (* i16 scalar input           *)
    B        : INT;       (* i16 scalar input           *)
    Flag     : BOOL;      (* i8  boolean input          *)
    Index    : INT;       (* i16 used as array index    *)
END_VAR
VAR
    Sum      : INT;       (* A + B each cycle           *)
    Product  : DINT;      (* A * B, wider type          *)
    Buf      : ARRAY[0..15] OF INT;  (* 16-element buffer *)
    C        : Counter;   (* nested function block      *)
    CycleNum : INT;       (* increments every scan      *)
END_VAR

(* Simple deterministic behavior easy to verify *)
CycleNum := CycleNum + 1;
Sum      := A + B;
Product  := A * B;

(* Bounded array write — safe when 0 <= Index <= 15 *)
IF Index >= 0 OR Index <= 15 THEN
    Buf[Index] := Sum;
END_IF

(* Drive the nested counter *)
C(Increment := A, Reset := Flag);

END_PROGRAM