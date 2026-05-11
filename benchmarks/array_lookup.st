PROGRAM array_lookup
VAR
    (* Inputs — these are what the fuzzer mutates *)
    index       : INT;      (* array index — dynamic GEP when used to access table *)
    selector    : INT;      (* selects which lookup table to use *)
    bias        : INT;      (* added to the looked-up value *)

    (* Outputs / state *)
    result      : INT;
    safe_result : INT;
    out_a       : INT;
    out_b       : INT;
END_VAR

VAR_TEMP
    table_a     : ARRAY[0..7] OF INT := [10, 20, 30, 40, 50, 60, 70, 80];
    table_b     : ARRAY[0..7] OF INT := [1,  3,  5,  7,  9, 11, 13, 15];
    clamped     : INT;
END_VAR

    (* --- unsafe path: index used directly, dynamic GEP --- *)
    result := table_a[index] + bias;

    (* --- second dynamic GEP on a different table --- *)
    out_a := table_b[index];

    (* --- selector-driven dynamic GEP: two tables, runtime choice --- *)
    IF selector >= 0 AND selector < 8 THEN
        out_b := table_a[selector] + table_b[selector];
    ELSE
        out_b := 0;
    END_IF;

    (* --- safe path: clamped index, should still emit a GEP but
         the analyser may or may not mark it dynamic depending on
         whether it can prove the clamp — useful to compare --- *)
    IF index >= 0 AND index < 8 THEN
        clamped := index;
    ELSE
        clamped := 0;
    END_IF;
    safe_result := table_a[clamped];

END_PROGRAM