mod ddg;
mod layout;
mod metadata;

use inkwell::context::Context;
use inkwell::memory_buffer::MemoryBuffer;
use std::path::{Path, PathBuf};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: prism-analyze <file.ll|file.bc> <output_prefix>");
        eprintln!("  output_prefix: path without extension, e.g. benchmarks/out/foo/foo");
        eprintln!("  produces: <prefix>_layout.json, <prefix>_ddg.json");
        std::process::exit(1);
    }

    let input_path = Path::new(&args[1]);
    let output_prefix = Path::new(&args[2]);
    let function_filter: Option<&str> = args.get(3).map(|s| s.as_str());

    let ctx = Context::create();

    // Load the module directly from file — avoids CString null-byte issues
    // with debug IR. Works for both .ll (text) and .bc (bitcode).
    let buf = MemoryBuffer::create_from_file(input_path).expect("Failed to read IR file");
    let module = ctx.create_module_from_ir(buf).expect("Failed to parse IR");

    // Read raw text separately for metadata string parsing.
    // This is independent of module parsing and does not go through CString.
    let ir_text = std::fs::read_to_string(input_path).unwrap_or_default();

    println!("[*] Module: {}", input_path.display());
    println!("[*] Filter: {}", function_filter.unwrap_or("(all)"));

    // --- Layout extraction ---
    let layouts = ir_analysis::extract_layout(&module, &ir_text, function_filter);
    println!("\n[+] Program/Function struct layouts ({}):", layouts.len());
    for prog in &layouts {
        println!("  {} -> {}()", prog.struct_name, prog.function_name);
        for f in &prog.fields {
            println!(
                "    [{:>3}] offset={:<4} size={:<3} type={:<16} name={}",
                f.index,
                f.byte_offset,
                f.byte_size,
                f.llvm_type,
                f.name.as_deref().unwrap_or("?"),
            );
        }
    }

    let layout_path = PathBuf::from(format!("{}_layout.json", output_prefix.display()));
    let ddg_prefix = PathBuf::from(format!("{}_ddg", output_prefix.display()));
    let layout_json = serde_json::to_string_pretty(&layouts).unwrap();
    std::fs::write(&layout_path, &layout_json).expect("Failed to write layout JSON");
    println!("\n[+] Layout written: {}", layout_path.display());

    // --- DDG ---
    match ir_analysis::ddg::build_and_write_ddg(&module, &ir_text, function_filter, &ddg_prefix) {
        Ok(paths) => {
            println!("[+] DDG JSON: {}", paths.json_path.display());

            // Also print some stats about the graph.
            let graph = ir_analysis::build_ddg(&module, &ir_text, function_filter);
            let calls = graph.nodes.iter().filter(|n| n.callee.is_some()).count();
            let dyn_geps = graph.nodes.iter().filter(|n| n.has_dynamic_index).count();
            println!(
                "[+] Nodes: {}  Edges: {}  Calls: {}  Dynamic GEPs: {}",
                graph.nodes.len(),
                graph.edges.len(),
                calls,
                dyn_geps
            );
        }
        Err(e) => eprintln!("[!] DDG write failed: {}", e),
    }
}
