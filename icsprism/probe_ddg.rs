/// probe_ddg.rs — standalone DDG proximity validator
///
/// Usage (no Cargo needed, just rustc):
///   rustc probe_ddg.rs -o probe_ddg
///   ./probe_ddg array_lookup_ddg.json array_lookup_layout.json

use std::collections::{HashMap, VecDeque};
use std::env;
use std::fs;

// ---------------------------------------------------------------------------
// JSON schema types — must match prism-analyze output exactly
// ---------------------------------------------------------------------------

/// One node in the DDG. Identity is `id`; defines is the LLVM SSA name
/// (e.g. "%index", "%tmpVar2"). has_dynamic_index marks GEP sinks.
#[derive(Debug)]
struct DdgNode {
    id: u64,
    defines: Option<String>,
    has_dynamic_index: bool,
}

/// One directed edge. kind is "data_ssa", "data_memory", or "memory_overwrite".
#[derive(Debug)]
struct DdgEdge {
    from: u64,
    to: u64,
    // kind not needed for BFS but useful for debugging
    #[allow(dead_code)]
    kind: String,
}

/// One field from the layout JSON.
#[derive(Debug)]
struct LayoutField {
    name: Option<String>,
    llvm_type: String,
    byte_offset: u64,
    byte_size: u64,
}

/// One program entry in the layout JSON (it's an array at the top level).
#[derive(Debug)]
struct ProgramLayout {
    struct_name: String,
    total_bytes: u64,
    fields: Vec<LayoutField>,
}

// ---------------------------------------------------------------------------
// Minimal hand-rolled JSON parser (no deps — this is a standalone .rs)
// ---------------------------------------------------------------------------
// We parse only what we need using serde_json-style patterns but with
// std::collections only. In prism-ddg itself use serde + serde_json.

fn parse_ddg(json: &str) -> (Vec<DdgNode>, Vec<DdgEdge>) {
    // Use a simple approach: parse as serde_json Value via stdlib... but
    // stdlib has no JSON. So we use a tiny recursive descent for our schema.
    // In practice: just shell out to Python for the probe, use serde in Rust.
    //
    // For the standalone probe we use a different strategy: embed a minimal
    // JSON value parser using only std. This is ~100 lines but keeps zero deps.

    parse_ddg_impl(json)
}

fn parse_ddg_impl(json: &str) -> (Vec<DdgNode>, Vec<DdgEdge>) {
    // Rather than write a full JSON parser, we use string scanning on the
    // well-known prism-analyze output format. This is intentionally brittle
    // and only used for the probe binary — prism-ddg uses serde_json.

    let mut nodes = Vec::new();
    let mut edges = Vec::new();

    // Split into "nodes" and "edges" sections
    let nodes_start = json.find("\"nodes\"").unwrap_or(0);
    let edges_start = json.find("\"edges\"").unwrap_or(json.len());

    let nodes_section = &json[nodes_start..edges_start];
    let edges_section = &json[edges_start..];

    // Parse nodes: scan for { ... } blocks, extract fields
    for block in object_blocks(nodes_section) {
        let id = extract_u64(block, "\"id\"");
        let defines = extract_string_opt(block, "\"defines\"");
        let has_dynamic_index = block.contains("\"has_dynamic_index\": true");
        if let Some(id) = id {
            nodes.push(DdgNode { id, defines, has_dynamic_index });
        }
    }

    // Parse edges: scan for { ... } blocks
    for block in object_blocks(edges_section) {
        let from = extract_u64(block, "\"from\"");
        let to   = extract_u64(block, "\"to\"");
        let kind = extract_string_opt(block, "\"kind\"").unwrap_or_default();
        if let (Some(from), Some(to)) = (from, to) {
            edges.push(DdgEdge { from, to, kind });
        }
    }

    (nodes, edges)
}

fn parse_layout(json: &str) -> Vec<ProgramLayout> {
    let mut layouts = Vec::new();

    // Top level is an array of layout objects
    for block in top_level_objects(json) {
        let struct_name = extract_string_opt(block, "\"struct_name\"").unwrap_or_default();
        let total_bytes = extract_u64(block, "\"total_bytes\"").unwrap_or(0);

        // Find "fields": [ ... ]
        let fields_start = block.find("\"fields\"").unwrap_or(block.len());
        let fields_section = &block[fields_start..];

        let mut fields = Vec::new();
        for fblock in object_blocks(fields_section) {
            let name      = extract_string_opt(fblock, "\"name\"");
            let llvm_type = extract_string_opt(fblock, "\"llvm_type\"").unwrap_or_default();
            let byte_size   = extract_u64(fblock, "\"byte_size\"").unwrap_or(0);
            let byte_offset = extract_u64(fblock, "\"byte_offset\"").unwrap_or(0);
            fields.push(LayoutField { name, llvm_type, byte_offset, byte_size });
        }

        layouts.push(ProgramLayout { struct_name, total_bytes, fields });
    }

    layouts
}

// Yield top-level { ... } blocks from a JSON array string
fn top_level_objects(s: &str) -> Vec<&str> {
    let mut result = Vec::new();
    let bytes = s.as_bytes();
    let mut depth = 0i32;
    let mut start = None;
    let mut in_string = false;
    let mut escaped = false;

    for (i, &b) in bytes.iter().enumerate() {
        if escaped { escaped = false; continue; }
        if b == b'\\' && in_string { escaped = true; continue; }
        if b == b'"' { in_string = !in_string; continue; }
        if in_string { continue; }

        match b {
            b'{' => {
                if depth == 0 { start = Some(i); }
                depth += 1;
            }
            b'}' => {
                depth -= 1;
                if depth == 0 {
                    if let Some(st) = start {
                        result.push(&s[st..=i]);
                        start = None;
                    }
                }
            }
            _ => {}
        }
    }
    result
}

// Yield nested { ... } blocks (depth >= 1 from caller's perspective)
fn object_blocks(s: &str) -> Vec<&str> {
    top_level_objects(s)
}

fn extract_u64(s: &str, key: &str) -> Option<u64> {
    let pos = s.find(key)?;
    let after = &s[pos + key.len()..];
    let after = after.trim_start_matches([' ', '\t', '\n', '\r', ':']);
    let end = after.find(|c: char| !c.is_ascii_digit()).unwrap_or(after.len());
    after[..end].parse().ok()
}

fn extract_string_opt(s: &str, key: &str) -> Option<String> {
    let pos = s.find(key)?;
    let after = &s[pos + key.len()..];
    let after = after.trim_start_matches([' ', '\t', '\n', '\r', ':']);
    if after.starts_with("null") {
        return None;
    }
    if after.starts_with('"') {
        let inner = &after[1..];
        let end = inner.find('"')?;
        return Some(inner[..end].to_string());
    }
    None
}

// ---------------------------------------------------------------------------
// Core DDG logic — this is the exact function that goes into prism-ddg/src/ddg.rs
// ---------------------------------------------------------------------------

/// Compute per-byte weights from DDG + layout.
///
/// Returns Vec<f32> of length `layout.total_bytes`.
/// Each byte's weight = 1/(1+d) where d = BFS distance from the byte's
/// layout field to the nearest dynamic-index GEP sink in the DDG.
/// Bytes with no path to any sink get weight 0.0.
pub fn build_byte_weights(
    nodes: &[DdgNode],
    edges: &[DdgEdge],
    layout: &ProgramLayout,
) -> Vec<f32> {
    let input_size = layout.total_bytes as usize;

    // 1. Collect all sink node IDs (has_dynamic_index = true)
    let sinks: Vec<u64> = nodes.iter()
        .filter(|n| n.has_dynamic_index)
        .map(|n| n.id)
        .collect();

    println!("  Sinks ({}):", sinks.len());
    for &s in &sinks {
        if let Some(n) = nodes.iter().find(|n| n.id == s) {
            println!("    node {:>3}  defines={:?}", n.id, n.defines);
        }
    }

    // 2. Build reversed adjacency list for backward BFS
    //    Forward edge: from → to means "from flows into to"
    //    Backward BFS: we want predecessors of each node, so we invert
    let mut rev_adj: HashMap<u64, Vec<u64>> = HashMap::new();
    for e in edges {
        rev_adj.entry(e.to).or_default().push(e.from);
    }

    // 3. Multi-source BFS from all sinks simultaneously
    //    dist[node_id] = minimum hops to reach any sink
    let mut dist: HashMap<u64, u32> = HashMap::new();
    let mut queue: VecDeque<u64> = VecDeque::new();
    for &s in &sinks {
        dist.insert(s, 0);
        queue.push_back(s);
    }
    while let Some(node_id) = queue.pop_front() {
        let d = dist[&node_id];
        if let Some(preds) = rev_adj.get(&node_id) {
            for &pred in preds {
                if !dist.contains_key(&pred) {
                    dist.insert(pred, d + 1);
                    queue.push_back(pred);
                }
            }
        }
    }

    // 4. Build name → score map
    //    DDG defines field is "%fieldname" — strip the % to get layout name
    //    Score = 1/(1+d), never zero for reachable nodes
    let mut name_score: HashMap<String, f32> = HashMap::new();
    for node in nodes {
        if let Some(def) = &node.defines {
            let field_name = def.trim_start_matches('%').to_string();
            let score = if let Some(&d) = dist.get(&node.id) {
                1.0 / (1.0 + d as f32)
            } else {
                0.0
            };
            // Keep the best score if the same name appears multiple nodes
            let entry = name_score.entry(field_name).or_insert(0.0);
            if score > *entry {
                *entry = score;
            }
        }
    }

    // 5. Map scores to per-byte weight vector using layout field byte ranges
    //    Only fuzzable fields (not __vtable, not struct-typed) get a score
    let mut weights = vec![0.0f32; input_size];
    for field in &layout.fields {
        let name = field.name.as_deref().unwrap_or("");
        let is_fuzzable = name != "__vtable" && !field.llvm_type.starts_with('%');
        if !is_fuzzable {
            continue;
        }

        // Match by stripping any numeric suffix (e.g. "load_index2" → "index")
        // The primary match is exact: layout name == stripped DDG defines name
        let score = name_score.get(name).copied().unwrap_or(0.0);

        let start = field.byte_offset as usize;
        let end   = start + field.byte_size as usize;
        for b in start..end.min(input_size) {
            weights[b] = score;
        }
    }

    weights
}

// ---------------------------------------------------------------------------
// Main — print a report and sanity-check against expected values
// ---------------------------------------------------------------------------

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: probe_ddg <ddg.json> <layout.json>");
        eprintln!("Example: probe_ddg array_lookup_ddg.json array_lookup_layout.json");
        std::process::exit(1);
    }

    let ddg_path    = &args[1];
    let layout_path = &args[2];

    let ddg_json    = fs::read_to_string(ddg_path)
        .unwrap_or_else(|e| panic!("Cannot read {}: {}", ddg_path, e));
    let layout_json = fs::read_to_string(layout_path)
        .unwrap_or_else(|e| panic!("Cannot read {}: {}", layout_path, e));

    println!("=== probe_ddg ===");
    println!("DDG    : {}", ddg_path);
    println!("Layout : {}", layout_path);
    println!();

    let (nodes, edges) = parse_ddg(&ddg_json);
    let layouts = parse_layout(&layout_json);

    println!("Parsed {} DDG nodes, {} edges", nodes.len(), edges.len());
    println!("Parsed {} layout struct(s)", layouts.len());
    println!();

    for layout in &layouts {
        println!("--- Struct: {} ({} bytes) ---", layout.struct_name, layout.total_bytes);

        let weights = build_byte_weights(&nodes, &edges, layout);

        println!();
        println!("Field scores:");
        for field in &layout.fields {
            let name = field.name.as_deref().unwrap_or("<unnamed>");
            let is_fuzzable = name != "__vtable" && !field.llvm_type.starts_with('%');
            if !is_fuzzable {
                println!("  {:20}  [offset {:>3}, size {:>2}]  SKIP (not fuzzable)", name, field.byte_offset, field.byte_size);
                continue;
            }
            let byte_start = field.byte_offset as usize;
            // All bytes in a field share the same score
            let score = if byte_start < weights.len() { weights[byte_start] } else { 0.0 };
            let bar_len = (score * 40.0) as usize;
            let bar: String = "█".repeat(bar_len);
            println!("  {:20}  [offset {:>3}, size {:>2}]  score={:.4}  {}", name, field.byte_offset, field.byte_size, score, bar);
        }

        println!();
        println!("Byte weight vector ({} bytes):", weights.len());
        for (i, w) in weights.iter().enumerate() {
            print!("  [{:>3}] {:.4}", i, w);
            if (i + 1) % 4 == 0 { println!(); }
        }
        println!();

        // Sanity check for array_lookup: index and selector should score ~0.167
        // bias, result, safe_result, out_a, out_b should score 0.0
        if layout.struct_name == "array_lookup" {
            println!("--- Sanity check (array_lookup expected values) ---");
            let checks: &[(&str, f32, f32)] = &[
                // (field_name, expected_score, tolerance)
                ("index",       0.167, 0.01),
                ("selector",    0.167, 0.01),
                ("bias",        0.0,   0.001),
                ("result",      0.0,   0.001),
                ("safe_result", 0.0,   0.001),
                ("out_a",       0.0,   0.001),
                ("out_b",       0.0,   0.001),
            ];

            let mut all_pass = true;
            for &(fname, expected, tol) in checks {
                let field = layout.fields.iter().find(|f| f.name.as_deref() == Some(fname));
                let actual = field.map(|f| {
                    let b = f.byte_offset as usize;
                    if b < weights.len() { weights[b] } else { 0.0 }
                }).unwrap_or(0.0);

                let diff = (actual - expected).abs();
                let pass = diff <= tol;
                all_pass &= pass;
                println!("  {:20}  expected={:.4}  actual={:.4}  {}",
                    fname, expected, actual, if pass { "PASS ✓" } else { "FAIL ✗" });
            }
            println!();
            println!("Result: {}", if all_pass { "ALL PASS ✓" } else { "FAILURES — check BFS logic" });
        }
    }
}