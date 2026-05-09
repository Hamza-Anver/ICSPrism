use inkwell::module::Module;
use inkwell::values::AnyValue;
use inkwell::values::InstructionOpcode;
use inkwell::values::Operand;
use inkwell::values::AsValueRef;
use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct GraphNode {
    pub id: usize,
    pub function: String,
    pub basic_block: String,
    pub opcode: String,
    pub ir: String,
    pub defines: Option<String>,
    pub define_value_key: Option<u64>,
    pub human_name: Option<String>,
}

#[derive(Debug, Clone)]
pub struct GraphEdge {
    pub from: usize,
    pub to: usize,
    pub kind: String,
    pub symbol: String,
    pub value_key: Option<u64>,
}

#[derive(Debug, Clone, Default)]
pub struct DdgGraph {
    pub nodes: Vec<GraphNode>,
    pub edges: Vec<GraphEdge>,
}

#[derive(Debug, Clone)]
pub struct DdgOutputPaths {
    pub json_path: PathBuf,
    pub dot_path: PathBuf,
}

pub fn build_and_write_ddg(
    module: &Module<'_>,
    ir_text: &str,
    function_filter: Option<&str>,
    out_prefix: &Path,
) -> Result<DdgOutputPaths, std::io::Error> {
    let graph = build_ddg(module, ir_text, function_filter);

    let json_path = out_prefix.with_extension("json");
    let dot_path = out_prefix.with_extension("dot");

    std::fs::write(&json_path, graph_to_json(&graph))?;
    std::fs::write(&dot_path, graph_to_dot(&graph))?;

    Ok(DdgOutputPaths { json_path, dot_path })
}

pub fn build_ddg(module: &Module<'_>, ir_text: &str, function_filter: Option<&str>) -> DdgGraph {
    let mut graph = DdgGraph::default();

    let dbg_names = extract_dbg_value_aliases(ir_text);

    let mut next_node_id = 0usize;
    let mut last_def_by_value: HashMap<u64, usize> = HashMap::new();
    let mut last_store_by_pointer: HashMap<u64, usize> = HashMap::new();

    for function in module.get_functions() {
        let function_name = function.get_name().to_str().unwrap_or("unnamed_function").to_string();

        if function_name.starts_with("llvm.") {
            continue;
        }

        if let Some(filter) = function_filter {
            if function_name != filter {
                continue;
            }
        }

        for basic_block in function.get_basic_blocks() {
            let basic_block_name = basic_block
                .get_name()
                .to_str()
                .unwrap_or("unnamed_block")
                .to_string();

            let mut cursor = basic_block.get_first_instruction();
            while let Some(inst) = cursor {
                let ir = inst.print_to_string().to_string();
                let opcode = format!("{:?}", inst.get_opcode());
                let defines = parse_definition_ssa(&ir);
                let define_value_key = if inst.get_name().is_some() {
                    Some(inst.as_value_ref() as usize as u64)
                } else {
                    None
                };

                let human_name = defines
                    .as_ref()
                    .and_then(|ssa| dbg_names.get(ssa).cloned());

                let node_id = next_node_id;
                next_node_id += 1;

                graph.nodes.push(GraphNode {
                    id: node_id,
                    function: function_name.clone(),
                    basic_block: basic_block_name.clone(),
                    opcode,
                    ir: ir.clone(),
                    defines: defines.clone(),
                    define_value_key,
                    human_name,
                });

                for i in 0..inst.get_num_operands() {
                    let Some(operand) = inst.get_operand(i) else {
                        continue;
                    };

                    let Some(value) = operand.value() else {
                        continue;
                    };

                    let operand_key = value.as_value_ref() as usize as u64;
                    if let Some(def_node_id) = last_def_by_value.get(&operand_key) {
                        let symbol = value_symbol(operand);
                        graph.edges.push(GraphEdge {
                            from: *def_node_id,
                            to: node_id,
                            kind: "data_ssa".to_string(),
                            symbol,
                            value_key: Some(operand_key),
                        });
                    }
                }

                if let Some((pointer_key, pointer_symbol)) = pointer_operand_key(inst.get_opcode(), &inst) {
                    if inst.get_opcode() == InstructionOpcode::Load {
                        if let Some(store_node_id) = last_store_by_pointer.get(&pointer_key) {
                            graph.edges.push(GraphEdge {
                                from: *store_node_id,
                                to: node_id,
                                kind: "data_memory".to_string(),
                                symbol: pointer_symbol,
                                value_key: Some(pointer_key),
                            });
                        }
                    } else if inst.get_opcode() == InstructionOpcode::Store {
                        if let Some(prev_store_id) = last_store_by_pointer.get(&pointer_key) {
                            graph.edges.push(GraphEdge {
                                from: *prev_store_id,
                                to: node_id,
                                kind: "memory_overwrite".to_string(),
                                symbol: pointer_symbol.clone(),
                                value_key: Some(pointer_key),
                            });
                        }
                        last_store_by_pointer.insert(pointer_key, node_id);
                    }
                }

                if let Some(def_key) = define_value_key {
                    last_def_by_value.insert(def_key, node_id);
                }

                cursor = inst.get_next_instruction();
            }
        }
    }

    graph
}

fn pointer_operand_key(
    opcode: InstructionOpcode,
    inst: &inkwell::values::InstructionValue<'_>,
) -> Option<(u64, String)> {
    let operand_idx = match opcode {
        InstructionOpcode::Load => 0,
        InstructionOpcode::Store => 1,
        _ => return None,
    };

    let operand = inst.get_operand(operand_idx)?;
    let value = operand.value()?;
    let key = value.as_value_ref() as usize as u64;
    let symbol = value_symbol(operand);
    Some((key, symbol))
}

fn value_symbol(operand: Operand<'_>) -> String {
    if let Some(v) = operand.value() {
        let name = v.get_name().to_str().unwrap_or("");
        if !name.is_empty() {
            return format!("%{}", name);
        }
        return v.print_to_string().to_string();
    }
    "<bb>".to_string()
}

fn parse_definition_ssa(ir: &str) -> Option<String> {
    let trimmed = ir.trim_start();
    if !trimmed.starts_with('%') {
        return None;
    }

    let eq_idx = trimmed.find('=')?;
    let lhs = trimmed[..eq_idx].trim();
    if is_valid_ssa(lhs) {
        Some(lhs.to_string())
    } else {
        None
    }
}

fn is_valid_ssa(token: &str) -> bool {
    if !token.starts_with('%') || token.len() < 2 {
        return false;
    }
    token[1..].chars().all(is_ssa_char)
}

fn is_ssa_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '_' || c == '.'
}

fn extract_dbg_value_aliases(ir_text: &str) -> HashMap<String, String> {
    let mut local_names: HashMap<String, String> = HashMap::new();

    for line in ir_text.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with('!') || !trimmed.contains("!DILocalVariable(") {
            continue;
        }

        let Some((lhs, rhs)) = trimmed.split_once(" = ") else {
            continue;
        };
        let Some(name) = extract_quoted_arg(rhs, "name:") else {
            continue;
        };

        local_names.insert(lhs.trim().to_string(), name);
    }

    let mut aliases = HashMap::new();
    for line in ir_text.lines() {
        if !(line.contains("llvm.dbg.value") || line.contains("llvm.dbg.declare")) {
            continue;
        }

        let ssa = first_ssa_token(line);
        let local_ref = find_metadata_ref_after_marker(line, "metadata !");

        let (Some(ssa_name), Some(local_md_ref)) = (ssa, local_ref) else {
            continue;
        };

        if let Some(local_name) = local_names.get(&local_md_ref) {
            aliases.insert(ssa_name, local_name.clone());
        }
    }

    aliases
}

fn first_ssa_token(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut i = 0usize;

    while i < bytes.len() {
        if bytes[i] == b'%' {
            let mut j = i + 1;
            while j < bytes.len() && is_ssa_char(bytes[j] as char) {
                j += 1;
            }
            if j > i + 1 {
                return Some(text[i..j].to_string());
            }
        }
        i += 1;
    }

    None
}

fn find_metadata_ref_after_marker(text: &str, marker: &str) -> Option<String> {
    let start = text.find(marker)? + marker.len();
    let rest = &text[start..];
    let mut digits = String::new();

    for ch in rest.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }

    if digits.is_empty() {
        None
    } else {
        Some(format!("!{}", digits))
    }
}

fn extract_quoted_arg(text: &str, key: &str) -> Option<String> {
    let start = text.find(key)? + key.len();
    let rest = &text[start..];
    let first_quote = rest.find('"')?;
    let after_first = &rest[first_quote + 1..];
    let second_quote = after_first.find('"')?;
    Some(after_first[..second_quote].to_string())
}

fn graph_to_json(graph: &DdgGraph) -> String {
    let mut out = String::new();
    out.push_str("{\n  \"nodes\": [\n");

    for (idx, node) in graph.nodes.iter().enumerate() {
        if idx > 0 {
            out.push_str(",\n");
        }

        let defines = node
            .defines
            .as_deref()
            .map(json_escape)
            .unwrap_or_else(|| "null".to_string());
        let define_value_key = node
            .define_value_key
            .map(|v| v.to_string())
            .unwrap_or_else(|| "null".to_string());
        let human_name = node
            .human_name
            .as_deref()
            .map(json_escape)
            .unwrap_or_else(|| "null".to_string());

        let _ = write!(
            out,
            "    {{\"id\":{},\"function\":{},\"basic_block\":{},\"opcode\":{},\"defines\":{},\"define_value_key\":{},\"human_name\":{},\"ir\":{}}}",
            node.id,
            json_escape(&node.function),
            json_escape(&node.basic_block),
            json_escape(&node.opcode),
            defines,
            define_value_key,
            human_name,
            json_escape(&node.ir)
        );
    }

    out.push_str("\n  ],\n  \"edges\": [\n");

    for (idx, edge) in graph.edges.iter().enumerate() {
        if idx > 0 {
            out.push_str(",\n");
        }
        let value_key = edge
            .value_key
            .map(|v| v.to_string())
            .unwrap_or_else(|| "null".to_string());
        let _ = write!(
            out,
            "    {{\"from\":{},\"to\":{},\"kind\":{},\"symbol\":{},\"value_key\":{}}}",
            edge.from,
            edge.to,
            json_escape(&edge.kind),
            json_escape(&edge.symbol),
            value_key
        );
    }

    out.push_str("\n  ]\n}\n");
    out
}

fn graph_to_dot(graph: &DdgGraph) -> String {
    let mut out = String::new();
    out.push_str("digraph DDG {\n");
    out.push_str("  rankdir=LR;\n");
    out.push_str("  node [shape=box, fontsize=10];\n");

    for node in &graph.nodes {
        let human = node.human_name.clone().unwrap_or_else(|| "".to_string());
        let defines = node.defines.clone().unwrap_or_else(|| "".to_string());

        let label = if !human.is_empty() {
            format!(
                "{}\\n{}::{}\\n{}\\n{}",
                node.id, node.function, node.basic_block, node.opcode, human
            )
        } else if !defines.is_empty() {
            format!(
                "{}\\n{}::{}\\n{}\\n{}",
                node.id, node.function, node.basic_block, node.opcode, defines
            )
        } else {
            format!(
                "{}\\n{}::{}\\n{}",
                node.id, node.function, node.basic_block, node.opcode
            )
        };

        let _ = writeln!(
            out,
            "  n{} [label=\"{}\"];",
            node.id,
            dot_escape(&label)
        );
    }

    for edge in &graph.edges {
        let _ = writeln!(
            out,
            "  n{} -> n{} [label=\"{}:{}\"];",
            edge.from,
            edge.to,
            dot_escape(&edge.kind),
            dot_escape(&edge.symbol)
        );
    }

    out.push_str("}\n");
    out
}

fn json_escape(s: &str) -> String {
    let mut escaped = String::with_capacity(s.len() + 2);
    escaped.push('"');
    for ch in s.chars() {
        match ch {
            '"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            c if c.is_control() => {
                let _ = write!(escaped, "\\u{:04x}", c as u32);
            }
            c => escaped.push(c),
        }
    }
    escaped.push('"');
    escaped
}

fn dot_escape(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}
