use std::path::{Path, PathBuf};

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
    fn prism_state_size() -> usize;
    fn prism_input_size() -> usize;
    fn prism_struct_size() -> usize;
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

pub fn execute_testcase(config: &PrismFuzzConfig, data: &[u8], frame_size: usize) -> bool {
    let Some(instance) = Instance::new() else {
        return false;
    };

    if config.execution.per_testcase_reset {
        unsafe { prism_reset(instance.0) };
    }

    match config.execution.mode {
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
    }
}
