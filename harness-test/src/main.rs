// harness-test/src/main.rs

#[link(name = "harness_test", kind = "dylib")]
unsafe extern "C" {
    unsafe fn HarnessTest(instance: *mut u8);
    unsafe fn Counter(instance: *mut u8);
}

// ---------------------------------------------------------------------------
// Offsets from harness_test_layout.json — HarnessTest struct (72 bytes total)
// ---------------------------------------------------------------------------
const STRUCT_BYTES    : usize = 72;

const OFFSET_A        : usize = 0;   // i16
const OFFSET_B        : usize = 2;   // i16
const OFFSET_FLAG     : usize = 4;   // i8
const OFFSET_INDEX    : usize = 6;   // i16
const OFFSET_SUM      : usize = 8;   // i16
// offset 10: 2 bytes padding (i32 aligns to 4)
const OFFSET_PRODUCT  : usize = 12;  // i32
const OFFSET_BUF      : usize = 16;  // [16 x i16] = 32 bytes
const OFFSET_C        : usize = 48;  // Counter instance = 16 bytes
const OFFSET_CYCLENUM : usize = 64;  // i16

// Counter sub-fields — offsets within HarnessTest (OFFSET_C + field offset)
// Counter layout: { ptr@0, i16@8, i8@10, i16@12, i16@14 } = 16 bytes
const OFFSET_C_VTABLE     : usize = OFFSET_C + 0;  // ptr  — do not touch
const OFFSET_C_INCREMENT  : usize = OFFSET_C + 8;  // i16
const OFFSET_C_RESET      : usize = OFFSET_C + 10; // i8
const OFFSET_C_VALUE      : usize = OFFSET_C + 12; // i16
const OFFSET_C_TOTALCALLS : usize = OFFSET_C + 14; // i16

// ---------------------------------------------------------------------------
// Byte-level accessors
// ---------------------------------------------------------------------------

fn read_i8(mem: &[u8], offset: usize) -> i8 {
    mem[offset] as i8
}

fn read_i16(mem: &[u8], offset: usize) -> i16 {
    i16::from_le_bytes([mem[offset], mem[offset + 1]])
}

fn read_i32(mem: &[u8], offset: usize) -> i32 {
    i32::from_le_bytes([
        mem[offset],
        mem[offset + 1],
        mem[offset + 2],
        mem[offset + 3],
    ])
}

fn write_i8(mem: &mut [u8], offset: usize, value: i8) {
    mem[offset] = value as u8;
}

fn write_i16(mem: &mut [u8], offset: usize, value: i16) {
    mem[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
}

// Read one element from Buf — index is the ST array index (0..=15)
fn read_buf(mem: &[u8], index: usize) -> i16 {
    assert!(index < 16, "Buf index out of range");
    read_i16(mem, OFFSET_BUF + index * 2)
}

// ---------------------------------------------------------------------------
// Call the ST program for one scan cycle
// ---------------------------------------------------------------------------

fn run_cycle(instance: &mut Vec<u8>) {
    unsafe { HarnessTest(instance.as_mut_ptr()); }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn set_inputs(mem: &mut [u8], a: i16, b: i16, flag: bool, index: i16) {
    write_i16(mem, OFFSET_A,     a);
    write_i16(mem, OFFSET_B,     b);
    write_i8 (mem, OFFSET_FLAG,  flag as i8);
    write_i16(mem, OFFSET_INDEX, index);
}

fn print_state(mem: &[u8], label: &str) {
    let buf: Vec<i16> = (0..16).map(|i| read_buf(mem, i)).collect();
    println!("--- {} ---", label);
    println!("  Inputs : A={} B={} Flag={} Index={}",
        read_i16(mem, OFFSET_A),
        read_i16(mem, OFFSET_B),
        read_i8(mem, OFFSET_FLAG),
        read_i16(mem, OFFSET_INDEX),
    );
    println!("  Outputs: Sum={} Product={} CycleNum={}",
        read_i16(mem, OFFSET_SUM),
        read_i32(mem, OFFSET_PRODUCT),
        read_i16(mem, OFFSET_CYCLENUM),
    );
    println!("  Buf    : {:?}", buf);
    println!("  Counter: Value={} TotalCalls={}",
        read_i16(mem, OFFSET_C_VALUE),
        read_i16(mem, OFFSET_C_TOTALCALLS),
    );
}

fn assert_eq_i16(mem: &[u8], offset: usize, expected: i16, label: &str) {
    let got = read_i16(mem, offset);
    assert_eq!(
        got, expected,
        "{}: expected {} got {}",
        label, expected, got
    );
}

fn assert_eq_i32(mem: &[u8], offset: usize, expected: i32, label: &str) {
    let got = read_i32(mem, offset);
    assert_eq!(
        got, expected,
        "{}: expected {} got {}",
        label, expected, got
    );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn test_single_cycle() {
    println!("\n=== Test 1: single cycle A=3 B=4 Flag=false Index=2 ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    set_inputs(&mut inst, 3, 4, false, 2);
    run_cycle(&mut inst);
    print_state(&inst, "after cycle 1");

    // Sum = A + B = 7
    assert_eq_i16(&inst, OFFSET_SUM,     7,  "Sum");
    // Product = A * B = 12
    assert_eq_i32(&inst, OFFSET_PRODUCT, 12, "Product");
    // Buf[2] = Sum = 7
    assert_eq_i16(&inst, OFFSET_BUF + 2 * 2, 7, "Buf[2]");
    // CycleNum increments each scan
    assert_eq_i16(&inst, OFFSET_CYCLENUM, 1, "CycleNum");
    // Counter.TotalCalls incremented once
    assert_eq_i16(&inst, OFFSET_C_TOTALCALLS, 1, "C.TotalCalls");
    // Counter.Value = 0 + Increment(=A=3) = 3
    assert_eq_i16(&inst, OFFSET_C_VALUE, 3, "C.Value");

    println!("Test 1 PASSED");
}

fn test_state_accumulates_across_cycles() {
    println!("\n=== Test 2: state accumulates across cycles ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    // Cycle 1: A=1, B=2, Index=0
    set_inputs(&mut inst, 1, 2, false, 0);
    run_cycle(&mut inst);

    // Cycle 2: same inputs
    run_cycle(&mut inst);

    print_state(&inst, "after cycle 2");

    // CycleNum must be 2
    assert_eq_i16(&inst, OFFSET_CYCLENUM, 2, "CycleNum after 2 cycles");
    // Counter.TotalCalls must be 2
    assert_eq_i16(&inst, OFFSET_C_TOTALCALLS, 2, "C.TotalCalls after 2 cycles");
    // Counter.Value = 1 + 1 = 2 (incremented by A=1 each cycle, no reset)
    assert_eq_i16(&inst, OFFSET_C_VALUE, 2, "C.Value after 2 cycles");
    // Sum is still 3 (A+B doesn't accumulate, recomputed each cycle)
    assert_eq_i16(&inst, OFFSET_SUM, 3, "Sum");

    println!("Test 2 PASSED");
}

fn test_changing_inputs() {
    println!("\n=== Test 3: changing inputs across cycles ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    // Cycle 1: A=5, B=5, Index=5
    set_inputs(&mut inst, 5, 5, false, 5);
    run_cycle(&mut inst);

    // Cycle 2: A=10, B=2, Index=7
    set_inputs(&mut inst, 10, 2, false, 7);
    run_cycle(&mut inst);

    print_state(&inst, "after cycle 2");

    // Sum = 10 + 2 = 12 (latest cycle)
    assert_eq_i16(&inst, OFFSET_SUM, 12, "Sum");
    // Product = 10 * 2 = 20
    assert_eq_i32(&inst, OFFSET_PRODUCT, 20, "Product");
    // Buf[5] was written in cycle 1 with Sum=10, still 10
    assert_eq_i16(&inst, OFFSET_BUF + 5 * 2, 10, "Buf[5] from cycle 1");
    // Buf[7] written in cycle 2 with Sum=12
    assert_eq_i16(&inst, OFFSET_BUF + 7 * 2, 12, "Buf[7] from cycle 2");

    println!("Test 3 PASSED");
}

fn test_flag_resets_counter() {
    println!("\n=== Test 4: Flag resets Counter.Value ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    // Cycle 1: build up Counter.Value
    set_inputs(&mut inst, 5, 0, false, 0);
    run_cycle(&mut inst);
    assert_eq_i16(&inst, OFFSET_C_VALUE, 5, "C.Value after increment");

    // Cycle 2: send Reset=true
    set_inputs(&mut inst, 5, 0, true, 0);
    run_cycle(&mut inst);

    print_state(&inst, "after reset cycle");

    // Counter.Value must be 0 after Reset=true
    assert_eq_i16(&inst, OFFSET_C_VALUE, 0, "C.Value after reset");
    // TotalCalls still incremented even on reset
    assert_eq_i16(&inst, OFFSET_C_TOTALCALLS, 2, "C.TotalCalls");

    println!("Test 4 PASSED");
}

fn test_buf_independence() {
    println!("\n=== Test 5: Buf elements are independent ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    // Write to every Buf slot via Index cycling
    for i in 0i16..16 {
        set_inputs(&mut inst, i, 0, false, i);
        run_cycle(&mut inst);
    }

    print_state(&inst, "after 16 cycles");

    // Buf[i] should equal Sum at the time it was written = i + 0 = i
    for i in 0usize..16 {
        let expected = i as i16;
        let got = read_buf(&inst, i);
        assert_eq!(got, expected, "Buf[{}]: expected {} got {}", i, expected, got);
    }

    println!("Test 5 PASSED");
}

fn test_nested_counter_offset() {
    println!("\n=== Test 6: direct byte access to nested Counter fields ===");
    let mut inst = vec![0u8; STRUCT_BYTES];

    // Verify the vtable pointer slot is at OFFSET_C and is zeroed
    // (we never touch it — just confirm the offset arithmetic is right
    //  by checking the bytes around it are what we expect after a cycle)
    set_inputs(&mut inst, 7, 3, false, 0);
    run_cycle(&mut inst);

    // C.Increment mirrors A (the ST code passes A as Increment)
    // After the call, C's internal Increment field holds whatever
    // the ST runtime last wrote — verify C.Value = 7 (A)
    assert_eq_i16(&inst, OFFSET_C_VALUE, 7, "C.Value = A");

    // Manually read C.TotalCalls at its absolute offset
    let total_calls_raw = read_i16(&inst, OFFSET_C_TOTALCALLS);
    assert_eq!(total_calls_raw, 1, "C.TotalCalls raw read");

    println!("Test 6 PASSED");
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() {
    println!("Harness verification — HarnessTest ({} bytes)", STRUCT_BYTES);
    println!("Offsets: A={} B={} Flag={} Index={} Sum={} Product={} Buf={} C={} CycleNum={}",
        OFFSET_A, OFFSET_B, OFFSET_FLAG, OFFSET_INDEX,
        OFFSET_SUM, OFFSET_PRODUCT, OFFSET_BUF, OFFSET_C, OFFSET_CYCLENUM
    );

    test_single_cycle();
    test_state_accumulates_across_cycles();
    test_changing_inputs();
    test_flag_resets_counter();
    test_buf_independence();
    test_nested_counter_offset();

    println!("\n=== All tests passed ===");
    println!("Field mapping verified. Harness is correct.");
}