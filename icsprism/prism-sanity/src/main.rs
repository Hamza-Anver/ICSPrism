use std::ffi::CStr;
use std::os::raw::c_char;

unsafe extern "C" {
    fn prism_alloc() -> *mut u8;
    fn prism_reset(instance: *mut u8);
    fn prism_free(instance: *mut u8);
    fn prism_run(instance: *mut u8, data: *const u8, len: usize);
    fn prism_step(instance: *mut u8);
    fn prism_get_state(instance: *const u8, out: *mut u8);
    fn prism_set_state(instance: *mut u8, state: *const u8, len: usize);
    fn prism_state_size() -> usize;
    fn prism_input_size() -> usize;
    fn prism_struct_size() -> usize;
    fn prism_field_count() -> u32;
    fn prism_field_name(idx: u32) -> *const c_char;
    fn prism_field_size(idx: u32) -> usize;
    fn prism_field_is_input(idx: u32) -> i32;
    fn prism_get_field(instance: *const u8, idx: u32, out: *mut u8) -> usize;
    fn prism_set_field(instance: *mut u8, idx: u32, data: *const u8, len: usize) -> i32;
}

type CheckResult<T> = Result<T, String>;

// Coverage hooks are required because generated harness libraries are linked
// from objects compiled with -fsanitize-coverage=trace-pc-guard.
#[unsafe(no_mangle)]
pub extern "C" fn __sanitizer_cov_trace_pc_guard_init(_start: *mut u32, _stop: *mut u32) {}

#[unsafe(no_mangle)]
pub extern "C" fn __sanitizer_cov_trace_pc_guard(_guard: *mut u32) {}

struct Instance(*mut u8);

impl Drop for Instance {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { prism_free(self.0) };
        }
    }
}

fn fail<T>(msg: impl Into<String>) -> CheckResult<T> {
    Err(msg.into())
}

fn require(condition: bool, msg: impl Into<String>) -> CheckResult<()> {
    if condition {
        Ok(())
    } else {
        fail(msg)
    }
}

fn field_name(idx: u32) -> CheckResult<String> {
    unsafe {
        let ptr = prism_field_name(idx);
        if ptr.is_null() {
            return fail(format!("prism_field_name({idx}) returned null"));
        }
        Ok(CStr::from_ptr(ptr).to_string_lossy().into_owned())
    }
}

fn find_field(name: &str) -> CheckResult<u32> {
    let count = unsafe { prism_field_count() };
    for idx in 0..count {
        if field_name(idx)? == name {
            return Ok(idx);
        }
    }
    fail(format!("field not found: {name}"))
}

fn set_field_bytes(instance: *mut u8, idx: u32, bytes: &[u8]) -> CheckResult<()> {
    let expected_size = unsafe { prism_field_size(idx) };
    require(
        expected_size == bytes.len(),
        format!(
            "field size mismatch at idx={idx}: expected {expected_size}, got {}",
            bytes.len()
        ),
    )?;
    let ok = unsafe { prism_set_field(instance, idx, bytes.as_ptr(), bytes.len()) };
    require(ok == 1, format!("prism_set_field failed at idx={idx}"))
}

fn set_field_i16(instance: *mut u8, idx: u32, value: i16) -> CheckResult<()> {
    set_field_bytes(instance, idx, &value.to_le_bytes())
}

fn set_field_bool(instance: *mut u8, idx: u32, value: bool) -> CheckResult<()> {
    set_field_bytes(instance, idx, &[u8::from(value)])
}

fn get_field_bytes(instance: *const u8, idx: u32) -> CheckResult<Vec<u8>> {
    let size = unsafe { prism_field_size(idx) };
    let mut buf = vec![0u8; size];
    let got = unsafe { prism_get_field(instance, idx, buf.as_mut_ptr()) };
    require(
        got == size,
        format!("prism_get_field size mismatch at idx={idx}: got {got}, expected {size}"),
    )?;
    Ok(buf)
}

fn get_field_i16(instance: *const u8, idx: u32) -> CheckResult<i16> {
    let bytes = get_field_bytes(instance, idx)?;
    require(bytes.len() == 2, format!("field idx={idx} is not i16-sized"))?;
    Ok(i16::from_le_bytes([bytes[0], bytes[1]]))
}

fn get_field_bool(instance: *const u8, idx: u32) -> CheckResult<bool> {
    let bytes = get_field_bytes(instance, idx)?;
    require(bytes.len() == 1, format!("field idx={idx} is not bool-sized"))?;
    Ok(bytes[0] != 0)
}

fn run_checks() -> CheckResult<()> {
    println!("[prism-sanity] Starting harness sanity checks");

    let raw = unsafe { prism_alloc() };
    if raw.is_null() {
        return fail("prism_alloc returned null");
    }
    let instance = Instance(raw);

    unsafe { prism_reset(instance.0) };

    let field_count = unsafe { prism_field_count() };
    let input_size = unsafe { prism_input_size() };
    let state_size = unsafe { prism_state_size() };
    let struct_size = unsafe { prism_struct_size() };
    require(field_count > 0, "prism_field_count must be > 0")?;
    require(input_size >= 4, format!("prism_input_size too small: {input_size}"))?;
    require(state_size > 0, "prism_state_size must be > 0")?;
    require(struct_size > 0, "prism_struct_size must be > 0")?;

    let idx_delta = find_field("Delta")?;
    let idx_reset = find_field("Reset")?;
    let idx_enable = find_field("Enable")?;
    let idx_acc = find_field("Accumulator")?;
    let idx_cycle = find_field("CycleNum")?;
    let idx_edge = find_field("EdgeCount")?;
    let idx_armed = find_field("Armed")?;

    require(
        unsafe { prism_field_is_input(idx_delta) } == 1
            && unsafe { prism_field_is_input(idx_reset) } == 1
            && unsafe { prism_field_is_input(idx_enable) } == 1,
        "expected Delta/Reset/Enable to be input fields",
    )?;

    set_field_i16(instance.0, idx_delta, 4)?;
    set_field_bool(instance.0, idx_reset, false)?;
    set_field_bool(instance.0, idx_enable, true)?;

    unsafe {
        prism_step(instance.0);
        prism_step(instance.0);
        prism_step(instance.0);
    }

    let cycle = get_field_i16(instance.0, idx_cycle)?;
    let acc = get_field_i16(instance.0, idx_acc)?;
    let edge_count = get_field_i16(instance.0, idx_edge)?;
    let armed = get_field_bool(instance.0, idx_armed)?;
    require(cycle == 3, format!("scan cycle failed: CycleNum={cycle}, expected 3"))?;
    require(acc == 12, format!("accumulator failed: Accumulator={acc}, expected 12"))?;
    require(
        edge_count == 1,
        format!("edge tracking failed: EdgeCount={edge_count}, expected 1"),
    )?;
    require(armed, "Armed expected true after 3 cycles at Delta=4")?;

    let mut snapshot = vec![0u8; struct_size];
    unsafe { prism_get_state(instance.0, snapshot.as_mut_ptr()) };

    set_field_i16(instance.0, idx_delta, 1)?;
    unsafe { prism_step(instance.0) };
    let cycle_after_step = get_field_i16(instance.0, idx_cycle)?;
    require(
        cycle_after_step == 4,
        format!("step progression failed: CycleNum={cycle_after_step}, expected 4"),
    )?;

    unsafe { prism_set_state(instance.0, snapshot.as_ptr(), snapshot.len()) };
    let restored_cycle = get_field_i16(instance.0, idx_cycle)?;
    let restored_acc = get_field_i16(instance.0, idx_acc)?;
    require(
        restored_cycle == 3,
        format!("state restore failed for CycleNum: {restored_cycle}, expected 3"),
    )?;
    require(
        restored_acc == 12,
        format!("state restore failed for Accumulator: {restored_acc}, expected 12"),
    )?;

    unsafe { prism_reset(instance.0) };
    let run_input = [4u8, 0u8, 0u8, 1u8];
    unsafe { prism_run(instance.0, run_input.as_ptr(), run_input.len()) };
    let run_cycle = get_field_i16(instance.0, idx_cycle)?;
    let run_acc = get_field_i16(instance.0, idx_acc)?;
    require(
        run_cycle == 1,
        format!("prism_run cycle failed: CycleNum={run_cycle}, expected 1"),
    )?;
    require(
        run_acc == 4,
        format!("prism_run input mapping failed: Accumulator={run_acc}, expected 4"),
    )?;

    println!("[prism-sanity] PASS");
    println!(
        "[prism-sanity] fields={field_count} input_size={input_size} state_size={state_size} struct_size={struct_size}"
    );
    Ok(())
}

fn main() {
    if let Err(e) = run_checks() {
        eprintln!("[prism-sanity] FAIL: {e}");
        std::process::exit(1);
    }
}
