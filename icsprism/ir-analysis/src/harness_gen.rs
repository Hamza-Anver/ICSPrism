//! prism-harness — generates a C harness from a prism-analyze layout JSON.
//!
//! The generated harness compiles alongside the instrumented ST object to
//! produce a shared library exposing a stable ABI that all prism fuzzer
//! variants call. No LLVM dependency — pure layout JSON processing.
//!
//! Usage: prism-harness <layout.json> <program_name> <output.c>

use std::{fmt::Write, path::Path};

use serde::Deserialize;

// ---------------------------------------------------------------------------
// Layout types — must match prism-analyze output exactly
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize, Clone)]
struct FieldLayout {
    index: u32,
    name: Option<String>,
    llvm_type: String,
    byte_size: u64,
    byte_offset: u64,
}

#[derive(Debug, Deserialize, Clone)]
struct ProgramLayout {
    struct_name: String,
    total_bytes: u64,
    fields: Vec<FieldLayout>,
}

// ---------------------------------------------------------------------------
// LLVM type → C type mapping
// ---------------------------------------------------------------------------

/// Represents a C type with enough information to emit struct fields,
/// memcpy calls, and nested struct declarations.
#[derive(Debug, Clone)]
enum CType {
    Scalar {
        c_type: &'static str,
    },
    Array {
        element_c_type: &'static str,
        count: usize,
    },
    Opaque {
        byte_size: u64,
    }, // ptr, unknown, or truly opaque
    Nested {
        struct_name: String,
    }, // embedded named struct
}

/// Parse an LLVM type string from the layout JSON into a CType.
/// Handles:
///   i8, i16, i32, i64, float, double  → scalar
///   [N x T]                           → array
///   ptr                               → opaque (8 bytes)
///   %Name = type { ... }              → nested struct (extract name)
///   %Name                             → nested struct reference
fn parse_llvm_type(llvm_type: &str, byte_size: u64) -> CType {
    let t = llvm_type.trim();

    // Scalar types
    match t {
        "i8" => return CType::Scalar { c_type: "int8_t" },
        "i16" => return CType::Scalar { c_type: "int16_t" },
        "i32" => return CType::Scalar { c_type: "int32_t" },
        "i64" => return CType::Scalar { c_type: "int64_t" },
        "float" => return CType::Scalar { c_type: "float" },
        "double" => return CType::Scalar { c_type: "double" },
        "ptr" => return CType::Opaque { byte_size },
        _ => {}
    }

    // Array: [N x T]
    if t.starts_with('[') && t.ends_with(']') {
        let inner = &t[1..t.len() - 1];
        // Find " x " separator
        if let Some(x_pos) = inner.find(" x ") {
            let count_str = inner[..x_pos].trim();
            let elem_str = inner[x_pos + 3..].trim();
            if let Ok(count) = count_str.parse::<usize>() {
                let elem_c = match elem_str {
                    "i8" => "int8_t",
                    "i16" => "int16_t",
                    "i32" => "int32_t",
                    "i64" => "int64_t",
                    "float" => "float",
                    "double" => "double",
                    _ => "uint8_t", // fallback for unknown element types
                };
                return CType::Array {
                    element_c_type: elem_c,
                    count,
                };
            }
        }
    }

    // Nested struct: "%Name = type { ... }" or just "%Name"
    if t.starts_with('%') {
        // Extract the struct name — everything after % up to first space or '='
        let name_end = t.find(|c: char| c == ' ' || c == '=').unwrap_or(t.len());
        let raw_name = &t[1..name_end];
        let struct_name = raw_name
            .trim_start_matches("struct.")
            .trim_start_matches("class.")
            .to_string();
        if !struct_name.is_empty() {
            return CType::Nested { struct_name };
        }
    }

    // Fallback: treat as opaque byte array
    CType::Opaque { byte_size }
}

// ---------------------------------------------------------------------------
// Field classification
// ---------------------------------------------------------------------------

/// Whether a field is fuzzable input or persistent state.
/// Heuristic: __vtable and embedded structs/pointers are never fuzzable.
/// For the VAR_INPUT vs VAR distinction we use position: RuSTy places
/// VAR_INPUT fields before VAR fields in the struct. We mark all scalar
/// and array fields as fuzzable by default. The caller (fuzzer) can
/// further restrict based on DDG analysis.
#[derive(Debug, Clone, PartialEq)]
enum FieldKind {
    Input,  // VAR_INPUT — fuzzer writes these
    State,  // VAR — fuzzer reads these, optionally writes for Go-Explore
    Vtable, // compiler internal — never touch
}

fn classify_field(field: &FieldLayout) -> FieldKind {
    let name = field.name.as_deref().unwrap_or("");
    if name == "__vtable" {
        return FieldKind::Vtable;
    }
    // Nested structs are state (they contain function block instances)
    if field.llvm_type.starts_with('%') {
        return FieldKind::State;
    }
    // Pointers are internal state
    if field.llvm_type.trim() == "ptr" {
        return FieldKind::State;
    }
    // All scalar and array fields default to Input.
    // The DDG layer will later refine this for specific programs.
    FieldKind::Input
}

// ---------------------------------------------------------------------------
// Code generation
// ---------------------------------------------------------------------------

fn generate_harness(all_layouts: &[ProgramLayout], program_name: &str) -> Result<String, String> {
    // Find the target program layout
    let layout = all_layouts
        .iter()
        .find(|l| l.struct_name == program_name)
        .ok_or_else(|| format!("Program '{}' not found in layout JSON", program_name))?;

    let mut out = String::new();

    emit_header(&mut out, program_name);
    emit_forward_decls(&mut out, all_layouts, layout);
    emit_field_meta_table(&mut out, layout);
    emit_lifecycle(&mut out, layout);
    emit_execution(&mut out, layout, program_name);
    emit_state_access(&mut out, layout);
    emit_field_access(&mut out, layout);
    emit_metadata(&mut out, layout, program_name);

    Ok(out)
}

fn emit_header(out: &mut String, program_name: &str) {
    writeln!(
        out,
        "/* Generated by prism-harness for program: {} */",
        program_name
    )
    .unwrap();
    writeln!(
        out,
        "/* Do not edit — regenerate with: prism-harness <layout.json> {} <out.c> */",
        program_name
    )
    .unwrap();
    writeln!(out).unwrap();
    writeln!(out, "#include <stdint.h>").unwrap();
    writeln!(out, "#include <stddef.h>").unwrap();
    writeln!(out, "#include <string.h>").unwrap();
    writeln!(out, "#include <stdlib.h>").unwrap();
    writeln!(out).unwrap();
}

/// Emit typedef structs for all layouts found in the JSON, not just the
/// target. This handles nested structs — the target's layout references
/// sub-structs by name, and we need their C declarations first.
fn emit_forward_decls(out: &mut String, all_layouts: &[ProgramLayout], target: &ProgramLayout) {
    // Collect all nested struct names referenced by the target layout
    let mut needed: Vec<&str> = Vec::new();
    for field in &target.fields {
        if let CType::Nested { struct_name } = parse_llvm_type(&field.llvm_type, field.byte_size) {
            // Check if we have a layout entry for this struct
            if all_layouts.iter().any(|l| l.struct_name == struct_name) {
                if !needed.contains(&struct_name.as_str()) {
                    needed.push(
                        all_layouts
                            .iter()
                            .find(|l| l.struct_name == struct_name)
                            .map(|l| l.struct_name.as_str())
                            .unwrap(),
                    );
                }
            }
        }
    }

    // Emit nested struct typedefs first
    for nested_name in &needed {
        let nested_layout = all_layouts
            .iter()
            .find(|l| l.struct_name == *nested_name)
            .unwrap();
        emit_struct_typedef(out, nested_layout, all_layouts);
    }

    // Emit the target struct typedef
    emit_struct_typedef(out, target, all_layouts);
}

fn emit_struct_typedef(out: &mut String, layout: &ProgramLayout, all_layouts: &[ProgramLayout]) {
    writeln!(out, "typedef struct {{").unwrap();

    for field in &layout.fields {
        let pad_name;
        let name = match field.name.as_deref() {
            Some(n) => n,
            None => {
                pad_name = format!("_pad{}", field.index);
                &pad_name
            }
        };
        let ctype = parse_llvm_type(&field.llvm_type, field.byte_size);

        match &ctype {
            CType::Scalar { c_type } => {
                writeln!(
                    out,
                    "    {} {};  /* offset={} size={} */",
                    c_type, name, field.byte_offset, field.byte_size
                )
                .unwrap();
            }
            CType::Array {
                element_c_type,
                count,
            } => {
                writeln!(
                    out,
                    "    {} {}[{}];  /* offset={} size={} */",
                    element_c_type, name, count, field.byte_offset, field.byte_size
                )
                .unwrap();
            }
            CType::Opaque { byte_size } => {
                // Opaque fields (ptr, unknown) become uint8_t arrays
                writeln!(
                    out,
                    "    uint8_t {}[{}];  /* offset={} opaque */",
                    name, byte_size, field.byte_offset
                )
                .unwrap();
            }
            CType::Nested { struct_name } => {
                // Check if we have a full layout for this nested struct
                if all_layouts.iter().any(|l| l.struct_name == *struct_name) {
                    writeln!(
                        out,
                        "    {}_t {};  /* offset={} size={} nested */",
                        struct_name, name, field.byte_offset, field.byte_size
                    )
                    .unwrap();
                } else {
                    // No layout available — emit as opaque byte array
                    writeln!(
                        out,
                        "    uint8_t {}[{}];  /* offset={} size={} opaque nested */",
                        name, field.byte_size, field.byte_offset, field.byte_size
                    )
                    .unwrap();
                }
            }
        }
    }

    writeln!(out, "}} {}_t;", layout.struct_name).unwrap();
    writeln!(out).unwrap();
}

/// Emit the static field metadata table used by prism_field_* functions.
fn emit_field_meta_table(out: &mut String, layout: &ProgramLayout) {
    writeln!(out, "/* Field metadata */").unwrap();
    writeln!(out, "typedef struct {{").unwrap();
    writeln!(out, "    const char *name;").unwrap();
    writeln!(out, "    size_t offset;").unwrap();
    writeln!(out, "    size_t size;").unwrap();
    writeln!(out, "    int is_input;  /* 1=VAR_INPUT, 0=VAR/internal */").unwrap();
    writeln!(out, "}} PrismFieldMeta;").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "static const PrismFieldMeta PRISM_FIELDS[] = {{").unwrap();

    for field in &layout.fields {
        let name = field.name.as_deref().unwrap_or("?");
        let kind = classify_field(field);
        let is_input = match kind {
            FieldKind::Input => 1,
            FieldKind::State => 0,
            FieldKind::Vtable => 0,
        };
        writeln!(
            out,
            "    {{ \"{}\", {}, {}, {} }},",
            name, field.byte_offset, field.byte_size, is_input
        )
        .unwrap();
    }

    writeln!(out, "}};").unwrap();
    writeln!(
        out,
        "static const uint32_t PRISM_FIELD_COUNT = {};",
        layout.fields.len()
    )
    .unwrap();
    writeln!(out).unwrap();

    // State fields only — used by prism_get_state / prism_set_state
    // State size = sum of all non-vtable field sizes (entire struct minus vtable)
    let state_size: u64 = layout
        .fields
        .iter()
        .filter(|f| classify_field(f) != FieldKind::Vtable)
        .map(|f| f.byte_size)
        .sum();
    writeln!(
        out,
        "static const size_t PRISM_STATE_SIZE = {};",
        state_size
    )
    .unwrap();
    writeln!(out).unwrap();
}

fn emit_lifecycle(out: &mut String, layout: &ProgramLayout) {
    let sname = &layout.struct_name;
    let sbytes = layout.total_bytes;

    writeln!(
        out,
        "/* ── Lifecycle ─────────────────────────────────────── */"
    )
    .unwrap();
    writeln!(out).unwrap();

    writeln!(out, "void *prism_alloc(void) {{").unwrap();
    writeln!(out, "    void *p = calloc(1, {});", sbytes).unwrap();
    writeln!(out, "    return p;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "void prism_reset(void *instance) {{").unwrap();
    writeln!(out, "    memset(instance, 0, {});", sbytes).unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "void prism_free(void *instance) {{").unwrap();
    writeln!(out, "    free(instance);").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    // Forward declaration of the ST program function
    writeln!(out, "extern void {}({}_t *instance);", sname, sname).unwrap();
    writeln!(out).unwrap();
}

fn emit_execution(out: &mut String, layout: &ProgramLayout, program_name: &str) {
    writeln!(
        out,
        "/* ── Execution ──────────────────────────────────────── */"
    )
    .unwrap();
    writeln!(out).unwrap();

    // Collect input fields for the mapping code
    let input_fields: Vec<&FieldLayout> = layout
        .fields
        .iter()
        .filter(|f| classify_field(f) == FieldKind::Input)
        .collect();

    // prism_run: write inputs then execute one cycle
    writeln!(
        out,
        "void prism_run(void *instance, const uint8_t *data, size_t len) {{"
    )
    .unwrap();
    writeln!(
        out,
        "    {}_t *s = ({}_t *)instance;",
        layout.struct_name, layout.struct_name
    )
    .unwrap();
    writeln!(out, "    size_t cursor = 0;").unwrap();

    for field in &input_fields {
        let name = field.name.as_deref().unwrap_or("?");
        let size = field.byte_size;
        writeln!(out, "    if (cursor + {} <= len) {{", size).unwrap();
        writeln!(
            out,
            "        memcpy(&s->{}, data + cursor, {});",
            name, size
        )
        .unwrap();
        writeln!(out, "    }}").unwrap();
        writeln!(out, "    cursor += {};", size).unwrap();
    }

    writeln!(out, "    (void)cursor;").unwrap();
    writeln!(out, "    {}(s);", program_name).unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    // prism_step: execute one cycle without touching inputs (for scan cycle fuzzing)
    writeln!(out, "void prism_step(void *instance) {{").unwrap();
    writeln!(
        out,
        "    {}_t *s = ({}_t *)instance;",
        layout.struct_name, layout.struct_name
    )
    .unwrap();
    writeln!(out, "    {}(s);", program_name).unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    // prism_input_size: total bytes of input fields
    let input_bytes: u64 = input_fields.iter().map(|f| f.byte_size).sum();
    writeln!(
        out,
        "size_t prism_input_size(void) {{ return {}; }}",
        input_bytes
    )
    .unwrap();
    writeln!(out).unwrap();
}

fn emit_state_access(out: &mut String, layout: &ProgramLayout) {
    writeln!(
        out,
        "/* ── State access ───────────────────────────────────── */"
    )
    .unwrap();
    writeln!(out).unwrap();

    writeln!(
        out,
        "size_t prism_state_size(void) {{ return PRISM_STATE_SIZE; }}"
    )
    .unwrap();
    writeln!(out).unwrap();

    // prism_get_state: copy all non-vtable fields into a flat buffer
    // We copy the entire struct minus the vtable slot at offset 0.
    // For simplicity we copy the whole struct — the caller ignores vtable bytes.
    writeln!(
        out,
        "void prism_get_state(const void *instance, uint8_t *out) {{"
    )
    .unwrap();
    writeln!(out, "    memcpy(out, instance, {});", layout.total_bytes).unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(
        out,
        "void prism_set_state(void *instance, const uint8_t *state, size_t len) {{"
    )
    .unwrap();
    writeln!(
        out,
        "    if (len > {}) len = {};",
        layout.total_bytes, layout.total_bytes
    )
    .unwrap();
    // Preserve vtable — do not overwrite offset 0..8 if it is a vtable field
    let has_vtable = layout
        .fields
        .iter()
        .any(|f| f.name.as_deref() == Some("__vtable"));
    if has_vtable {
        writeln!(out, "    /* Preserve vtable pointer at offset 0 */").unwrap();
        writeln!(out, "    uint8_t *dst = (uint8_t *)instance;").unwrap();
        writeln!(out, "    if (len > 8) {{").unwrap();
        writeln!(out, "        memcpy(dst + 8, state + 8, len - 8);").unwrap();
        writeln!(out, "    }}").unwrap();
    } else {
        writeln!(out, "    memcpy(instance, state, len);").unwrap();
    }
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();
}

fn emit_field_access(out: &mut String, layout: &ProgramLayout) {
    writeln!(
        out,
        "/* ── Field access ───────────────────────────────────── */"
    )
    .unwrap();
    writeln!(out).unwrap();

    writeln!(
        out,
        "size_t prism_get_field(const void *instance, uint32_t idx, uint8_t *out) {{"
    )
    .unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    const PrismFieldMeta *f = &PRISM_FIELDS[idx];").unwrap();
    writeln!(
        out,
        "    memcpy(out, (const uint8_t *)instance + f->offset, f->size);"
    )
    .unwrap();
    writeln!(out, "    return f->size;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(
        out,
        "int prism_set_field(void *instance, uint32_t idx, const uint8_t *data, size_t len) {{"
    )
    .unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    const PrismFieldMeta *f = &PRISM_FIELDS[idx];").unwrap();
    writeln!(out, "    if (len != f->size) return 0;").unwrap();
    writeln!(out, "    /* Never allow writing to vtable */").unwrap();
    writeln!(
        out,
        "    if (f->offset == 0 && f->size == 8 && !f->is_input) return 0;"
    )
    .unwrap();
    writeln!(
        out,
        "    memcpy((uint8_t *)instance + f->offset, data, f->size);"
    )
    .unwrap();
    writeln!(out, "    return 1;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();
}

fn emit_metadata(out: &mut String, layout: &ProgramLayout, program_name: &str) {
    writeln!(
        out,
        "/* ── Metadata ───────────────────────────────────────── */"
    )
    .unwrap();
    writeln!(out).unwrap();

    writeln!(
        out,
        "size_t   prism_struct_size(void)  {{ return {}; }}",
        layout.total_bytes
    )
    .unwrap();
    writeln!(
        out,
        "uint32_t prism_field_count(void)  {{ return PRISM_FIELD_COUNT; }}"
    )
    .unwrap();
    writeln!(
        out,
        "const char *prism_program_name(void) {{ return \"{}\"; }}",
        program_name
    )
    .unwrap();
    writeln!(out).unwrap();

    writeln!(out, "const char *prism_field_name(uint32_t idx) {{").unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    return PRISM_FIELDS[idx].name;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "size_t prism_field_offset(uint32_t idx) {{").unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    return PRISM_FIELDS[idx].offset;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "size_t prism_field_size(uint32_t idx) {{").unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    return PRISM_FIELDS[idx].size;").unwrap();
    writeln!(out, "}}").unwrap();
    writeln!(out).unwrap();

    writeln!(out, "int prism_field_is_input(uint32_t idx) {{").unwrap();
    writeln!(out, "    if (idx >= PRISM_FIELD_COUNT) return 0;").unwrap();
    writeln!(out, "    return PRISM_FIELDS[idx].is_input;").unwrap();
    writeln!(out, "}}").unwrap();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        eprintln!("Usage: prism-harness <layout.json> <program_name> <output.c>");
        eprintln!("  layout.json   — produced by prism-analyze");
        eprintln!("  program_name  — ST PROGRAM or FUNCTION_BLOCK name");
        eprintln!("  output.c      — path to write the generated C harness");
        std::process::exit(1);
    }

    let layout_path = Path::new(&args[1]);
    let program_name = &args[2];
    let output_path = Path::new(&args[3]);

    let layout_text = std::fs::read_to_string(layout_path)
        .unwrap_or_else(|e| panic!("Cannot read {:?}: {}", layout_path, e));

    let all_layouts: Vec<ProgramLayout> = serde_json::from_str(&layout_text)
        .unwrap_or_else(|e| panic!("Cannot parse layout JSON: {}", e));

    let harness = generate_harness(&all_layouts, program_name)
        .unwrap_or_else(|e| panic!("Generation failed: {}", e));

    std::fs::write(output_path, &harness)
        .unwrap_or_else(|e| panic!("Cannot write {:?}: {}", output_path, e));

    println!("[prism-harness] Written: {}", output_path.display());
    println!("[prism-harness] Program: {}", program_name);

    // Print a quick summary
    let layout = all_layouts
        .iter()
        .find(|l| l.struct_name == *program_name)
        .unwrap();

    let input_count = layout
        .fields
        .iter()
        .filter(|f| classify_field(f) == FieldKind::Input)
        .count();
    let state_count = layout
        .fields
        .iter()
        .filter(|f| classify_field(f) == FieldKind::State)
        .count();

    println!(
        "[prism-harness] Fields: {} input, {} state, {} total",
        input_count,
        state_count,
        layout.fields.len()
    );
}
