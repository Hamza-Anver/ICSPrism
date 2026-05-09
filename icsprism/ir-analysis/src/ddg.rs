use std::collections::HashMap;
use inkwell::module::Module;
use inkwell::values::{AnyValue, AsValueRef, InstructionOpcode};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

use crate::metadata::build_ssa_name_map;

// Note: GEP is GetElementPtr

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
    pub id: usize,
    pub function: String,
    pub basic_block: String,
    pub opcode: String,
    /// Raw LLVM IR text for this instruction.
    pub ir: String,
    /// SSA name defined by this instruction (e.g. "%5").
    pub defines: Option<String>,
    /// Raw pointer value used as unique key for def-use tracking.
    pub define_value_key: Option<u64>,
    /// Human variable name from debug metadata (e.g. "LANG").
    pub human_name: Option<String>,
    /// For Call nodes: the callee name. None for non-call instructions.
    pub callee: Option<String>,
    /// True if this is a GEP instruction with at least one non-constant index.
    /// This is a structural fact about the IR, not a vulnerability judgment.
    pub has_dynamic_index: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub from: usize,
    pub to: usize,
    /// "data_ssa"         — SSA def-use edge
    /// "data_memory"      — store → load through the same pointer
    /// "memory_overwrite" — store → store to the same pointer
    pub kind: String,
    pub symbol: String,
    pub value_key: Option<u64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DdgGraph {
    pub nodes: Vec<GraphNode>,
    pub edges: Vec<GraphEdge>,
}

pub struct DdgOutputPaths {
    pub json_path: PathBuf,
    pub dot_path: PathBuf,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub fn build_and_write_ddg(
    module: &Module<'_>,
    ir_text: &str,
    function_filter: Option<&str>,
    out_prefix: &Path,
) -> Result<DdgOutputPaths, std::io::Error> {
    let graph = build_ddg(module, ir_text, function_filter);
    let json_path = out_prefix.with_extension("json");
    let dot_path  = out_prefix.with_extension("dot");
    std::fs::write(&json_path, graph_to_json(&graph))?;
    std::fs::write(&dot_path,  graph_to_dot(&graph))?;
    Ok(DdgOutputPaths { json_path, dot_path })
}

pub fn build_ddg(
    module: &Module<'_>,
    ir_text: &str,
    function_filter: Option<&str>,
) -> DdgGraph {
    let mut graph = DdgGraph::default();
    let ssa_names = build_ssa_name_map(ir_text);

    let mut next_id: usize = 0;
    let mut def_by_value: HashMap<u64, usize> = HashMap::new();
    let mut last_store: HashMap<u64, usize> = HashMap::new();

    for function in module.get_functions() {
        let func_name = match function.get_name().to_str() {
            Ok(n) => n.to_string(),
            Err(_) => continue,
        };

        // Skip LLVM intrinsics — these are compiler-generated bookkeeping,
        // not user-defined logic. This is a structural filter, not an opinion
        // about what is interesting.
        if func_name.starts_with("llvm.") {
            continue;
        }

        if let Some(filter) = function_filter {
            if func_name != filter {
                continue;
            }
        }

        for bb in function.get_basic_blocks() {
            let bb_name = bb
                .get_name()
                .to_str()
                .unwrap_or("?")
                .to_string();

            let mut cursor = bb.get_first_instruction();
            while let Some(inst) = cursor {
                let ir     = inst.print_to_string().to_string();
                let opcode = inst.get_opcode();
                let op_str = format!("{:?}", opcode);
                let defines = parse_ssa_def(&ir);

                let define_key: Option<u64> = if inst.get_name().is_some() {
                    Some(inst.as_value_ref() as usize as u64)
                } else {
                    None
                };

                let human_name = defines
                    .as_ref()
                    .and_then(|ssa| ssa_names.get(ssa).cloned());

                let callee = extract_callee(opcode, &inst, &ir);
                let has_dynamic_index = is_dynamic_gep(opcode, &inst);

                let node_id = next_id;
                next_id += 1;

                graph.nodes.push(GraphNode {
                    id: node_id,
                    function: func_name.clone(),
                    basic_block: bb_name.clone(),
                    opcode: op_str,
                    ir: ir.clone(),
                    defines: defines.clone(),
                    define_value_key: define_key,
                    human_name,
                    callee,
                    has_dynamic_index,
                });

                // SSA def-use edges
                for i in 0..inst.get_num_operands() {
                    let Some(operand) = inst.get_operand(i) else { continue };
                    let Some(val) = operand.value() else { continue };
                    let key = val.as_value_ref() as usize as u64;
                    if let Some(&src) = def_by_value.get(&key) {
                        graph.edges.push(GraphEdge {
                            from: src,
                            to: node_id,
                            kind: "data_ssa".to_string(),
                            symbol: val_symbol(operand),
                            value_key: Some(key),
                        });
                    }
                }

                // Memory edges
                if let Some((ptr_key, ptr_sym)) = memory_pointer_key(opcode, &inst) {
                    match opcode {
                        InstructionOpcode::Load => {
                            if let Some(&src) = last_store.get(&ptr_key) {
                                graph.edges.push(GraphEdge {
                                    from: src,
                                    to: node_id,
                                    kind: "data_memory".to_string(),
                                    symbol: ptr_sym,
                                    value_key: Some(ptr_key),
                                });
                            }
                        }
                        InstructionOpcode::Store => {
                            if let Some(&prev) = last_store.get(&ptr_key) {
                                graph.edges.push(GraphEdge {
                                    from: prev,
                                    to: node_id,
                                    kind: "memory_overwrite".to_string(),
                                    symbol: ptr_sym.clone(),
                                    value_key: Some(ptr_key),
                                });
                            }
                            last_store.insert(ptr_key, node_id);
                        }
                        _ => {}
                    }
                }

                if let Some(key) = define_key {
                    def_by_value.insert(key, node_id);
                }

                cursor = inst.get_next_instruction();
            }
        }
    }

    graph
}

// ---------------------------------------------------------------------------
// Instruction-level helpers
// ---------------------------------------------------------------------------

fn parse_ssa_def(ir: &str) -> Option<String> {
    let t = ir.trim_start();
    if !t.starts_with('%') {
        return None;
    }
    let eq = t.find('=')?;
    let lhs = t[..eq].trim();
    if lhs[1..].chars().all(|c| c.is_alphanumeric() || c == '_' || c == '.') {
        Some(lhs.to_string())
    } else {
        None
    }
}

fn memory_pointer_key(
    opcode: InstructionOpcode,
    inst: &inkwell::values::InstructionValue<'_>,
) -> Option<(u64, String)> {
    let idx = match opcode {
        InstructionOpcode::Load  => 0,
        InstructionOpcode::Store => 1,
        _ => return None,
    };
    let operand = inst.get_operand(idx)?;
    let val = operand.value()?;
    let key = val.as_value_ref() as usize as u64;
    Some((key, val_symbol(operand)))
}

fn val_symbol(operand: inkwell::values::Operand<'_>) -> String {
    if let Some(v) = operand.value() {
        let name = v.get_name().to_str().unwrap_or("");
        if !name.is_empty() {
            return format!("%{}", name);
        }
        return v.print_to_string().to_string();
    }
    "<bb>".to_string()
}

/// Extract the callee name from a Call instruction.
/// Returns None for non-call instructions.
/// The name is a raw fact — the caller decides if it is interesting.
fn extract_callee(
    opcode: InstructionOpcode,
    inst: &inkwell::values::InstructionValue<'_>,
    ir: &str,
) -> Option<String> {
    if opcode != InstructionOpcode::Call {
        return None;
    }
    // Try inkwell operand API first
    let n = inst.get_num_operands();
    let from_operand = (n > 0)
        .then(|| inst.get_operand(n - 1))
        .flatten()
        .and_then(|op| op.value())
        .map(|v| v.get_name().to_str().unwrap_or("").to_string())
        .filter(|s| !s.is_empty());

    if from_operand.is_some() {
        return from_operand;
    }

    // Fallback: parse @name from the raw IR text
    // e.g.: "  call void @SysMemCpy(ptr %0, ptr %1, i64 16)"
    let at = ir.find('@')?;
    let rest = &ir[at + 1..];
    let end = rest
        .find(|c: char| c == '(' || c == ' ' || c == '\n')
        .unwrap_or(rest.len());
    let name = rest[..end].trim_matches('"').to_string();
    if name.is_empty() { None } else { Some(name) }
}

/// True if a GEP instruction has at least one non-constant index operand.
fn is_dynamic_gep(
    opcode: InstructionOpcode,
    inst: &inkwell::values::InstructionValue<'_>,
) -> bool {
    if opcode != InstructionOpcode::GetElementPtr {
        return false;
    }
    for i in 1..inst.get_num_operands() {
        let Some(op) = inst.get_operand(i) else { continue };
        let Some(val) = op.value() else { continue };
        let printed = val.print_to_string().to_string();
        if printed.trim_start().starts_with('%') {
            return true;
        }
    }
    false
}

// ---------------------------------------------------------------------------
// Serialisation
// ---------------------------------------------------------------------------

fn graph_to_json(g: &DdgGraph) -> String {
    serde_json::to_string_pretty(g)
        .unwrap_or_else(|e| format!("{{\"error\":\"{}\"}}", e))
}

fn graph_to_dot(g: &DdgGraph) -> String {
    use std::fmt::Write;
    let mut out = String::new();
    let _ = writeln!(out, "digraph DDG {{");
    let _ = writeln!(out, "  rankdir=LR;");
    let _ = writeln!(out, "  node [shape=box fontsize=9];");

    for n in &g.nodes {
        let display = n.human_name
            .as_deref()
            .or(n.defines.as_deref())
            .unwrap_or("");
        let tag = if n.has_dynamic_index { " [dyn-idx]" } else { "" };
        let label = format!("{}\\n{}\\n{}{}", n.id, n.opcode, display, tag);
        let _ = writeln!(out, "  n{} [label=\"{}\"];", n.id, dot_esc(&label));
    }

    for e in &g.edges {
        let style = match e.kind.as_str() {
            "data_memory"      => " style=dashed",
            "memory_overwrite" => " style=dotted color=red",
            _                  => "",
        };
        let _ = writeln!(
            out,
            "  n{} -> n{} [label=\"{}\"{style}];",
            e.from, e.to,
            dot_esc(&e.kind)
        );
    }

    let _ = writeln!(out, "}}");
    out
}

fn dot_esc(s: &str) -> String {
    s.replace('\\', "\\\\")
     .replace('"', "\\\"")
     .replace('\n', "\\n")
}