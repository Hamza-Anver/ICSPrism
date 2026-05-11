use std::{
    collections::HashMap,
    ffi::CStr,
    fs,
    io::Write,
    os::raw::c_char,
    path::{Path, PathBuf},
    sync::OnceLock,
    time::{Duration, SystemTime},
};

use serde::Deserialize;

#[derive(Debug, Clone, Copy, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum ExecutionMode {
    #[default]
    SingleCycle,
    ScanSequence,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct ExecutionConfig {
    pub mode: ExecutionMode,
    pub cycles: usize,
    pub warmup_cycles: usize,
    pub max_cycles: usize,
    pub per_testcase_reset: bool,
    pub timeout_ms: u64,
}

impl Default for ExecutionConfig {
    fn default() -> Self {
        Self {
            mode: ExecutionMode::SingleCycle,
            cycles: 1,
            warmup_cycles: 0,
            max_cycles: 64,
            per_testcase_reset: true,
            timeout_ms: 5_000,
        }
    }
}

#[derive(Debug, Clone, Deserialize, Default)]
#[serde(default)]
pub struct PrismFuzzConfig {
    pub execution: ExecutionConfig,
}

#[derive(Debug, Clone)]
pub struct LoadedConfig {
    pub source: Option<PathBuf>,
    pub config: PrismFuzzConfig,
}

impl LoadedConfig {
    pub fn source_label(&self) -> String {
        match &self.source {
            Some(p) => p.display().to_string(),
            None => "<defaults>".to_string(),
        }
    }
}

pub fn load_config(cli_config_path: Option<&Path>) -> Result<LoadedConfig, String> {
    let source = match cli_config_path {
        Some(path) => Some(path.to_path_buf()),
        None => {
            let default = PathBuf::from("prism-fuzz.toml");
            if default.exists() {
                Some(default)
            } else {
                None
            }
        }
    };

    match source {
        Some(path) => {
            let raw = std::fs::read_to_string(&path)
                .map_err(|e| format!("Cannot read config {}: {e}", path.display()))?;
            let config = toml::from_str::<PrismFuzzConfig>(&raw)
                .map_err(|e| format!("Cannot parse config {}: {e}", path.display()))?;
            Ok(LoadedConfig {
                source: Some(path),
                config,
            })
        }
        None => Ok(LoadedConfig {
            source: None,
            config: PrismFuzzConfig::default(),
        }),
    }
}

pub fn effective_cycles(config: &PrismFuzzConfig) -> usize {
    config
        .execution
        .cycles
        .max(1)
        .min(config.execution.max_cycles.max(1))
}

pub fn required_input_len(config: &PrismFuzzConfig, input_size: usize) -> usize {
    match config.execution.mode {
        ExecutionMode::SingleCycle => input_size,
        ExecutionMode::ScanSequence => input_size.saturating_mul(effective_cycles(config)),
    }
}

#[derive(Debug, Clone, Copy)]
pub struct HarnessDimensions {
    pub input_size: usize,
    pub state_size: usize,
    pub struct_size: usize,
}

unsafe extern "C" {
    fn prism_alloc() -> *mut u8;
    fn prism_reset(instance: *mut u8);
    fn prism_free(instance: *mut u8);
    fn prism_run(instance: *mut u8, data: *const u8, len: usize);
    fn prism_step(instance: *mut u8);
    fn prism_get_state(instance: *const u8, out: *mut u8);
    fn prism_state_size() -> usize;
    fn prism_input_size() -> usize;
    fn prism_struct_size() -> usize;
    fn prism_program_name() -> *const c_char;
    fn prism_field_count() -> u32;
    fn prism_field_name(idx: u32) -> *const c_char;
    fn prism_field_size(idx: u32) -> usize;
    fn prism_field_is_input(idx: u32) -> i32;
    fn prism_get_field(instance: *const u8, idx: u32, out: *mut u8) -> usize;
}

pub fn harness_dimensions() -> HarnessDimensions {
    HarnessDimensions {
        input_size: unsafe { prism_input_size() },
        state_size: unsafe { prism_state_size() },
        struct_size: unsafe { prism_struct_size() },
    }
}

struct Instance(*mut u8);

impl Instance {
    fn new() -> Option<Self> {
        let ptr = unsafe { prism_alloc() };
        if ptr.is_null() { None } else { Some(Self(ptr)) }
    }
}

impl Drop for Instance {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { prism_free(self.0) };
        }
    }
}

fn heartbeat_path(tag: &str) -> PathBuf {
    let safe_tag: String = tag
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect();
    PathBuf::from(format!("/tmp/{}_state_heartbeat.txt", safe_tag))
}

fn should_emit_heartbeat(tag: &str, interval_secs: u64) -> bool {
    let path = heartbeat_path(tag);
    let now = SystemTime::now();
    let interval = Duration::from_secs(interval_secs.max(1));

    if let Ok(meta) = fs::metadata(&path) {
        if let Ok(modified) = meta.modified() {
            if now
                .duration_since(modified)
                .map(|d| d < interval)
                .unwrap_or(false)
            {
                return false;
            }
        }
    }

    if let Ok(mut file) = fs::File::create(path) {
        let _ = writeln!(file, "{:?}", now);
    }
    true
}

fn bytes_to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push_str(&format!("{b:02x}"));
    }
    out
}

#[derive(Debug, Clone, Deserialize)]
struct LayoutField {
    name: Option<String>,
    llvm_type: String,
    byte_size: u64,
    byte_offset: u64,
}

#[derive(Debug, Clone, Deserialize)]
struct ProgramLayout {
    struct_name: String,
    fields: Vec<LayoutField>,
}

#[derive(Debug, Clone)]
struct HeartbeatLayout {
    by_struct: HashMap<String, ProgramLayout>,
}

#[derive(Debug, Clone)]
struct StateLeaf {
    name: String,
    llvm_type: String,
    offset: usize,
    size: usize,
}

static HEARTBEAT_LAYOUT: OnceLock<Option<HeartbeatLayout>> = OnceLock::new();

fn parse_struct_ref(llvm_type: &str) -> Option<String> {
    let t = llvm_type.trim();
    if !t.starts_with('%') {
        return None;
    }
    let end = t.find(|c: char| c == ' ' || c == '=').unwrap_or(t.len());
    let raw = t[1..end].trim();
    if raw.is_empty() {
        None
    } else {
        Some(raw.to_string())
    }
}

fn discover_layout_path() -> Option<PathBuf> {
    if let Ok(path) = std::env::var("PRISM_HEARTBEAT_LAYOUT") {
        let p = PathBuf::from(path);
        if p.exists() {
            return Some(p);
        }
    }
    if let (Ok(dir), Ok(name)) = (std::env::var("PRISM_LIB_DIR"), std::env::var("PRISM_LIB_NAME")) {
        let p = PathBuf::from(dir).join(format!("{name}_layout.json"));
        if p.exists() {
            return Some(p);
        }
    }
    None
}

fn load_heartbeat_layout() -> Option<HeartbeatLayout> {
    let path = discover_layout_path()?;
    let raw = fs::read_to_string(path).ok()?;
    let layouts: Vec<ProgramLayout> = serde_json::from_str(&raw).ok()?;
    let mut by_struct = HashMap::new();
    for l in layouts {
        by_struct.insert(l.struct_name.clone(), l);
    }
    Some(HeartbeatLayout { by_struct })
}

fn heartbeat_layout() -> Option<&'static HeartbeatLayout> {
    HEARTBEAT_LAYOUT
        .get_or_init(load_heartbeat_layout)
        .as_ref()
}

fn harness_program_name() -> Option<String> {
    let ptr = unsafe { prism_program_name() };
    if ptr.is_null() {
        return None;
    }
    Some(unsafe { CStr::from_ptr(ptr) }.to_string_lossy().into_owned())
}

fn top_level_input_flags() -> HashMap<String, bool> {
    let mut out = HashMap::new();
    let count = unsafe { prism_field_count() };
    for idx in 0..count {
        let name_ptr = unsafe { prism_field_name(idx) };
        if name_ptr.is_null() {
            continue;
        }
        let name = unsafe { CStr::from_ptr(name_ptr) }
            .to_string_lossy()
            .into_owned();
        out.insert(name, unsafe { prism_field_is_input(idx) } == 1);
    }
    out
}

fn collect_state_leaves(
    layout: &HeartbeatLayout,
    struct_name: &str,
    prefix: &str,
    base_offset: usize,
    leaves: &mut Vec<StateLeaf>,
) {
    let Some(program) = layout.by_struct.get(struct_name) else {
        return;
    };
    for field in &program.fields {
        let Some(name) = field.name.as_deref() else {
            continue;
        };
        if name == "__vtable" {
            continue;
        }
        let full_name = if prefix.is_empty() {
            name.to_string()
        } else {
            format!("{prefix}.{name}")
        };
        let offset = base_offset.saturating_add(field.byte_offset as usize);
        let size = field.byte_size as usize;
        if let Some(nested) = parse_struct_ref(&field.llvm_type) {
            if layout.by_struct.contains_key(&nested) {
                collect_state_leaves(layout, &nested, &full_name, offset, leaves);
                continue;
            }
        }
        leaves.push(StateLeaf {
            name: full_name,
            llvm_type: field.llvm_type.clone(),
            offset,
            size,
        });
    }
}

fn flatten_state_from_layout() -> Option<Vec<StateLeaf>> {
    let layout = heartbeat_layout()?;
    let program_name = harness_program_name()?;
    let top = layout.by_struct.get(&program_name)?;
    let input_flags = top_level_input_flags();
    let mut leaves = Vec::new();

    for field in &top.fields {
        let Some(name) = field.name.as_deref() else {
            continue;
        };
        if name == "__vtable" || input_flags.get(name).copied().unwrap_or(false) {
            continue;
        }
        let offset = field.byte_offset as usize;
        if let Some(nested) = parse_struct_ref(&field.llvm_type) {
            if layout.by_struct.contains_key(&nested) {
                collect_state_leaves(layout, &nested, name, offset, &mut leaves);
                continue;
            }
        }
        leaves.push(StateLeaf {
            name: name.to_string(),
            llvm_type: field.llvm_type.clone(),
            offset,
            size: field.byte_size as usize,
        });
    }

    Some(leaves)
}

fn bytes_to_i16_words_le(bytes: &[u8]) -> Option<String> {
    if !bytes.len().is_multiple_of(2) || bytes.is_empty() {
        return None;
    }
    let mut parts = Vec::with_capacity(bytes.len() / 2);
    for chunk in bytes.chunks_exact(2) {
        let v = i16::from_le_bytes([chunk[0], chunk[1]]);
        parts.push(v.to_string());
    }
    Some(parts.join(","))
}

fn describe_field_value(bytes: &[u8]) -> String {
    match bytes.len() {
        1 => {
            let u = bytes[0];
            let i = i8::from_le_bytes([u]);
            format!("u8={u} i8={i} hex=0x{}", bytes_to_hex(bytes))
        }
        2 => {
            let u = u16::from_le_bytes([bytes[0], bytes[1]]);
            let i = i16::from_le_bytes([bytes[0], bytes[1]]);
            format!("u16={u} i16={i} hex=0x{}", bytes_to_hex(bytes))
        }
        4 => {
            let u = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
            let i = i32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
            format!("u32={u} i32={i} hex=0x{}", bytes_to_hex(bytes))
        }
        _ => {
            let hex = bytes_to_hex(bytes);
            if let Some(words) = bytes_to_i16_words_le(bytes) {
                format!("hex=0x{hex} i16=[{words}]")
            } else {
                format!("hex=0x{hex}")
            }
        }
    }
}

fn parse_array_type(llvm_type: &str) -> Option<(usize, String)> {
    let t = llvm_type.trim();
    if !(t.starts_with('[') && t.ends_with(']')) {
        return None;
    }
    let inner = &t[1..t.len() - 1];
    let sep = inner.find(" x ")?;
    let count = inner[..sep].trim().parse::<usize>().ok()?;
    let elem = inner[sep + 3..].trim().to_string();
    Some((count, elem))
}

fn describe_typed_value(llvm_type: &str, bytes: &[u8]) -> String {
    match llvm_type.trim() {
        "i8" => {
            if bytes.len() == 1 {
                let u = bytes[0];
                let i = i8::from_le_bytes([u]);
                format!("i8={i} u8={u} hex=0x{}", bytes_to_hex(bytes))
            } else {
                describe_field_value(bytes)
            }
        }
        "i16" => {
            if bytes.len() == 2 {
                let v = i16::from_le_bytes([bytes[0], bytes[1]]);
                format!("i16={v} hex=0x{}", bytes_to_hex(bytes))
            } else {
                describe_field_value(bytes)
            }
        }
        "i32" => {
            if bytes.len() == 4 {
                let v = i32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
                format!("i32={v} hex=0x{}", bytes_to_hex(bytes))
            } else {
                describe_field_value(bytes)
            }
        }
        "i64" => {
            if bytes.len() == 8 {
                let v = i64::from_le_bytes([
                    bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                ]);
                format!("i64={v} hex=0x{}", bytes_to_hex(bytes))
            } else {
                describe_field_value(bytes)
            }
        }
        _ => {
            if let Some((count, elem)) = parse_array_type(llvm_type) {
                match elem.as_str() {
                    "i16" if bytes.len() == count * 2 => {
                        let vals = bytes
                            .chunks_exact(2)
                            .map(|c| i16::from_le_bytes([c[0], c[1]]).to_string())
                            .collect::<Vec<_>>()
                            .join(",");
                        format!("[{vals}] hex=0x{}", bytes_to_hex(bytes))
                    }
                    "i8" if bytes.len() == count => {
                        let vals = bytes
                            .iter()
                            .map(|b| i8::from_le_bytes([*b]).to_string())
                            .collect::<Vec<_>>()
                            .join(",");
                        format!("[{vals}] hex=0x{}", bytes_to_hex(bytes))
                    }
                    _ => describe_field_value(bytes),
                }
            } else {
                describe_field_value(bytes)
            }
        }
    }
}

fn dump_state_variables(instance: *const u8, tag: &str) {
    if let Some(leaves) = flatten_state_from_layout() {
        let struct_size = unsafe { prism_struct_size() };
        let mut snapshot = vec![0u8; struct_size];
        unsafe { prism_get_state(instance, snapshot.as_mut_ptr()) };
        println!("[{tag}] state heartbeat:");
        for leaf in leaves {
            let start = leaf.offset;
            let end = start.saturating_add(leaf.size);
            if end > snapshot.len() || leaf.size == 0 {
                continue;
            }
            let bytes = &snapshot[start..end];
            println!(
                "[{tag}]   {} ({}B @ {}) = {}",
                leaf.name,
                leaf.size,
                leaf.offset,
                describe_typed_value(&leaf.llvm_type, bytes)
            );
        }
        return;
    }

    let field_count = unsafe { prism_field_count() };
    println!("[{tag}] state heartbeat:");
    for idx in 0..field_count {
        let is_input = unsafe { prism_field_is_input(idx) };
        if is_input == 1 {
            continue;
        }

        let name_ptr = unsafe { prism_field_name(idx) };
        if name_ptr.is_null() {
            continue;
        }
        let name = unsafe { CStr::from_ptr(name_ptr) }
            .to_string_lossy()
            .into_owned();
        if name == "__vtable" {
            continue;
        }

        let size = unsafe { prism_field_size(idx) };
        if size == 0 {
            println!("[{tag}]   {name} = <empty>");
            continue;
        }

        let mut buf = vec![0u8; size];
        let got = unsafe { prism_get_field(instance, idx, buf.as_mut_ptr()) };
        if got != size {
            println!("[{tag}]   {name} = <read-error got={got} expected={size}>");
            continue;
        }
        println!(
            "[{tag}]   {name} ({}B) = {}",
            size,
            describe_field_value(&buf)
        );
    }
}

fn execute_testcase_inner(
    config: &PrismFuzzConfig,
    data: &[u8],
    frame_size: usize,
    heartbeat: Option<(&str, u64)>,
) -> bool {
    let Some(instance) = Instance::new() else {
        return false;
    };

    if config.execution.per_testcase_reset {
        unsafe { prism_reset(instance.0) };
    }

    let executed = match config.execution.mode {
        ExecutionMode::SingleCycle => {
            if data.len() < frame_size {
                return false;
            }
            unsafe { prism_run(instance.0, data.as_ptr(), frame_size) };
            true
        }
        ExecutionMode::ScanSequence => {
            let cycles = effective_cycles(config);
            let warmup = config
                .execution
                .warmup_cycles
                .min(config.execution.max_cycles);
            let needed = frame_size.saturating_mul(cycles);
            if data.len() < needed {
                return false;
            }

            for _ in 0..warmup {
                unsafe { prism_step(instance.0) };
            }

            for cycle in 0..cycles {
                let start = cycle * frame_size;
                let end = start + frame_size;
                let frame = &data[start..end];
                unsafe { prism_run(instance.0, frame.as_ptr(), frame.len()) };
            }
            true
        }
    };

    if executed {
        if let Some((tag, interval_secs)) = heartbeat {
            if should_emit_heartbeat(tag, interval_secs) {
                dump_state_variables(instance.0, tag);
            }
        }
    }
    executed
}

pub fn execute_testcase(config: &PrismFuzzConfig, data: &[u8], frame_size: usize) -> bool {
    execute_testcase_inner(config, data, frame_size, None)
}

pub fn execute_testcase_with_heartbeat(
    config: &PrismFuzzConfig,
    data: &[u8],
    frame_size: usize,
    heartbeat_tag: &str,
    interval_secs: u64,
) -> bool {
    execute_testcase_inner(
        config,
        data,
        frame_size,
        Some((heartbeat_tag, interval_secs)),
    )
}
