mod ddg_graph;

use inkwell::context::Context;
use inkwell::memory_buffer::MemoryBuffer;
use std::collections::HashMap;
use std::ffi::CString;
use std::path::Path;

fn normalize_struct_name(name: &str) -> String {
    name
        .trim()
        .trim_start_matches("struct.")
        .trim_start_matches("class.")
        .to_string()
}

fn extract_named_structs(ir: &str) -> Vec<(String, usize)> {
    let mut structs = Vec::new();

    for line in ir.lines() {
        let trimmed = line.trim();

        if !trimmed.starts_with('%') || !trimmed.contains("= type") {
            continue;
        }

        let Some(eq_idx) = trimmed.find("= type") else {
            continue;
        };

        let raw_name = trimmed[1..eq_idx].trim();
        let name = normalize_struct_name(raw_name);
        let field_count = count_struct_fields(trimmed);
        structs.push((name, field_count));
    }

    structs
}

fn count_struct_fields(type_decl_line: &str) -> usize {
    let Some(start) = type_decl_line.find('{') else {
        return 0;
    };
    let Some(end) = type_decl_line.rfind('}') else {
        return 0;
    };
    if end <= start {
        return 0;
    }

    let body = type_decl_line[start + 1..end].trim();
    if body.is_empty() {
        return 0;
    }

    let mut count = 1;
    let mut paren_depth = 0;
    let mut brace_depth = 0;
    let mut angle_depth = 0;

    for ch in body.chars() {
        match ch {
            '(' => paren_depth += 1,
            ')' => paren_depth = (paren_depth - 1).max(0),
            '{' => brace_depth += 1,
            '}' => brace_depth = (brace_depth - 1).max(0),
            '<' => angle_depth += 1,
            '>' => angle_depth = (angle_depth - 1).max(0),
            ',' if paren_depth == 0 && brace_depth == 0 && angle_depth == 0 => count += 1,
            _ => {}
        }
    }

    count
}

fn extract_metadata_map(ir: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();

    for line in ir.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with('!') {
            continue;
        }

        let Some((lhs, rhs)) = trimmed.split_once(" = ") else {
            continue;
        };

        if lhs.len() > 1 && lhs[1..].chars().all(|c| c.is_ascii_digit()) {
            map.insert(lhs.to_string(), rhs.to_string());
        }
    }

    map
}

fn extract_quoted_arg(text: &str, key: &str) -> Option<String> {
    let start = text.find(key)? + key.len();
    let rest = &text[start..];
    let first_quote = rest.find('"')?;
    let after_first = &rest[first_quote + 1..];
    let second_quote = after_first.find('"')?;
    Some(after_first[..second_quote].to_string())
}

fn extract_metadata_ref_after(text: &str, key: &str) -> Option<String> {
    let start = text.find(key)? + key.len();
    let rest = text[start..].trim_start();
    if !rest.starts_with('!') {
        return None;
    }

    let mut id = String::from("!");
    for ch in rest[1..].chars() {
        if ch.is_ascii_digit() {
            id.push(ch);
        } else {
            break;
        }
    }

    if id.len() > 1 {
        Some(id)
    } else {
        None
    }
}

fn extract_metadata_refs(text: &str) -> Vec<String> {
    let mut refs = Vec::new();
    let bytes = text.as_bytes();
    let mut i = 0;

    while i < bytes.len() {
        if bytes[i] == b'!' {
            let mut j = i + 1;
            while j < bytes.len() && bytes[j].is_ascii_digit() {
                j += 1;
            }
            if j > i + 1 {
                refs.push(text[i..j].to_string());
            }
            i = j;
        } else {
            i += 1;
        }
    }

    refs
}

fn extract_struct_field_names_from_debug(ir: &str) -> HashMap<String, Vec<String>> {
    let md = extract_metadata_map(ir);
    let mut struct_fields = HashMap::new();

    for rhs in md.values() {
        if !rhs.contains("!DICompositeType(") {
            continue;
        }
        if !(rhs.contains("DW_TAG_structure_type") || rhs.contains("DW_TAG_class_type")) {
            continue;
        }

        let Some(struct_name_raw) = extract_quoted_arg(rhs, "name:") else {
            continue;
        };
        let struct_name = normalize_struct_name(&struct_name_raw);

        let Some(elements_ref) = extract_metadata_ref_after(rhs, "elements:") else {
            continue;
        };
        let Some(elements_rhs) = md.get(&elements_ref) else {
            continue;
        };

        let mut fields = Vec::new();
        for member_ref in extract_metadata_refs(elements_rhs) {
            let Some(member_rhs) = md.get(&member_ref) else {
                continue;
            };
            if !member_rhs.contains("!DIDerivedType(") || !member_rhs.contains("DW_TAG_member") {
                continue;
            }
            if let Some(field_name) = extract_quoted_arg(member_rhs, "name:") {
                fields.push(field_name);
            }
        }

        if !fields.is_empty() {
            struct_fields.insert(struct_name, fields);
        }
    }

    struct_fields
}

fn main() {
    let context = Context::create();
    let path_str = "../temp/pipeline_ctrl_debug.ll";
    let path = Path::new(path_str);

    // 1. Create a null-terminated MemoryBuffer from the IR file content
    let ir_content = std::fs::read_to_string(path).expect("Failed to read IR file");
    let ir_with_nul = CString::new(ir_content.clone()).expect("Failed to create CString from IR");
    
    // create_from_memory_range requires the nul byte at the end
    let memory_buffer = MemoryBuffer::create_from_memory_range(
        ir_with_nul.as_bytes_with_nul(), 
        "ir_buffer"
    );

    let module = context.create_module_from_ir(memory_buffer)
        .expect("Failed to parse IR into Module");

    println!("[*] Analyzing Module: {}", path_str);

    // 2. Identify Human-Readable Variables (Globals)
    // In ST, persistent state variables like @PLC_PRG_instance are globals
    println!("\n[+] Global Variables (State Variables):");
    for global in module.get_globals() {
        let name = global.get_name().to_str().unwrap_or("unnamed");
        let ty = global.get_value_type();
        println!("  - Name: @{}", name);
        println!("    Type: {:?}", ty);
    }

    // 3. Identify Entry Points and Logic (Functions)
    println!("\n[+] Functions (Control Logic):");
    for function in module.get_functions() {
        let func_name = function.get_name().to_str().unwrap_or("unnamed");
        
        // Filter out LLVM intrinsics for clarity
        if !func_name.starts_with("llvm.") {
            println!("  - Function: @{}", func_name);
            
            // Basic blocks represent the control flow graph (CFG) nodes
            for bb in function.get_basic_blocks() {
                let bb_name = bb.get_name().to_str().unwrap_or("unnamed_block");
                println!("    - BB: {}", bb_name);
            }
        }
    }

    // 4. Retrieve specific Struct layout (Deterministic Extraction)
    // Parse IR + debug metadata to print human-readable names for all structs/fields.
    let named_structs = extract_named_structs(&ir_content);
    let debug_struct_fields = extract_struct_field_names_from_debug(&ir_content);

    println!("\n[+] Structs (Human-Readable Names):");
    for (struct_name, layout_field_count) in named_structs {
        println!("  - Struct: %{}", struct_name);

        if let Some(field_names) = debug_struct_fields.get(&struct_name) {
            for field_name in field_names {
                println!("    - {}", field_name);
            }

            if field_names.len() != layout_field_count {
                println!(
                    "    - [info] metadata fields: {}, IR layout fields: {}",
                    field_names.len(),
                    layout_field_count
                );
            }
        } else {
            println!(
                "    - (no debug field names found; {} field slots in IR layout)",
                layout_field_count
            );
        }
    }

    let ddg_output_prefix = Path::new("../temp/ddg_graph");
    match ddg_graph::build_and_write_ddg(&module, &ir_content, Some("PipelineCtrl"), ddg_output_prefix) {
        Ok(paths) => {
            println!("\n[+] DDG Graph Written:");
            println!("  - JSON: {}", paths.json_path.display());
            println!("  - DOT:  {}", paths.dot_path.display());
        }
        Err(err) => {
            println!("\n[!] Failed to write DDG graph files: {}", err);
        }
    }
}