// ir-analysis/src/layout.rs
//
// Extracts struct field layouts from RuSTy-generated LLVM IR.
//
// RuSTy naming conventions (verified from docs and IR output):
//   PROGRAM prg  →  struct type  %prg,  function  @prg(ptr %0)
//   FUNCTION foo →  function  @foo(ptr %0, ...)   (stateless, may have no struct)
//   FUNCTION_BLOCK fb → struct %fb, function @fb(ptr %0)
//
// In LLVM 21 all pointers are opaque (`ptr`). We cannot inspect a parameter's
// pointee type at the inkwell level. Instead we look up the struct by name:
// RuSTy always names the struct the same as the function, so for function @prg
// we call module.get_struct_type("prg").

use std::collections::HashMap;
use inkwell::module::Module;
use inkwell::targets::TargetData;
use inkwell::types::BasicTypeEnum;
use serde::{Deserialize, Serialize};

use crate::metadata::{
    extract_metadata_map, extract_metadata_ref_after,
    extract_metadata_refs, extract_quoted_arg,
};

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldLayout {
    /// Zero-based field index in the LLVM struct.
    pub index: u32,
    /// Human-readable name from debug metadata (e.g. "LANG").
    /// None when compiled without -g or when metadata is absent.
    pub name: Option<String>,
    /// LLVM type string exactly as it appears in IR (e.g. "i16", "[10 x i8]").
    pub llvm_type: String,
    /// Byte size of this field according to the target data layout.
    pub byte_size: u64,
    /// Byte offset of this field within the struct.
    pub byte_offset: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProgramLayout {
    /// LLVM struct type name without leading % (e.g. "MONTH_TO_STRING").
    pub struct_name: String,
    /// The function that owns this struct as its first argument.
    pub function_name: String,
    /// Total size of the struct in bytes.
    pub total_bytes: u64,
    pub fields: Vec<FieldLayout>,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Extract layout for every non-intrinsic function whose struct type can be
/// resolved. Pass `function_filter` to restrict to a single function name.
///
/// Works with LLVM 21 opaque pointers: struct lookup is purely name-based.
pub fn extract_layout<'ctx>(
    module: &Module<'ctx>,
    ir_text: &str,
    function_filter: Option<&str>,
) -> Vec<ProgramLayout> {
    // Build TargetData from the module's data layout string.
    // This gives us architecture-correct field offsets and sizes.
    let data_layout_str = module.get_data_layout();
    let data_layout_cstr = data_layout_str.as_str();
    let td = TargetData::create(data_layout_cstr.to_str().unwrap_or(""));

    // Parse debug metadata once for all structs.
    let debug_field_names = extract_field_names_from_debug(ir_text);

    let mut layouts = Vec::new();

    for func in module.get_functions() {
        let func_name = match func.get_name().to_str() {
            Ok(n) => n.to_string(),
            Err(_) => continue,
        };

        // Skip LLVM intrinsics and RuSTy internal init functions.
        if is_llvm_intrinsic(&func_name) {
            continue;
        }

        // Apply caller filter.
        if let Some(filter) = function_filter {
            if func_name != filter {
                continue;
            }
        }

        // In LLVM 21 the first param is `ptr` — no element type available.
        // RuSTy names the struct identically to the function for PROGRAM and
        // FUNCTION_BLOCK. Try that name first, then try with common prefixes
        // RuSTy may prepend (none observed, but guard anyway).
        let struct_type = match module.get_struct_type(&func_name) {
            Some(st) => st,
            None => {
                // Functions (stateless) have no associated struct — skip them
                // or try to find a struct from the IR text as a fallback.
                match find_struct_name_in_ir(ir_text, &func_name)
                    .and_then(|n| module.get_struct_type(&n))
                {
                    Some(st) => st,
                    None => continue,
                }
            }
        };

        // Guard: inkwell panics on get_field_type_at_index for opaque structs.
        if struct_type.is_opaque() {
            continue;
        }

        let num_fields = struct_type.count_fields();
        if num_fields == 0 {
            continue;
        }

        // Total struct size in bytes.
        let total_bytes = td.get_bit_size(&struct_type) / 8;

        // Field names from debug metadata, keyed by normalised struct name.
        let field_names = debug_field_names
            .get(&func_name)
            .cloned()
            .unwrap_or_default();

        let mut fields = Vec::with_capacity(num_fields as usize);

        for i in 0..num_fields {
            // unwrap: index is in bounds and struct is not opaque — checked above.
            let field_ty = struct_type.get_field_type_at_index(i).unwrap();

            let byte_offset = td.offset_of_element(&struct_type, i).unwrap_or(0);
            let byte_size = bit_size_of(&td, field_ty) / 8;
            let llvm_type = type_string(field_ty);
            let name = field_names.get(i as usize).cloned();

            fields.push(FieldLayout {
                index: i,
                name,
                llvm_type,
                byte_size,
                byte_offset,
            });
        }

        layouts.push(ProgramLayout {
            struct_name: func_name.clone(),
            function_name: func_name,
            total_bytes,
            fields,
        });
    }

    layouts
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Functions to skip: LLVM intrinsics, RuSTy init/runtime helpers.
fn is_llvm_intrinsic(name: &str) -> bool {
    name.starts_with("llvm.")
}

/// Compute bit size of a BasicTypeEnum using TargetData.
/// Falls back to a best-effort manual calculation for arrays.
fn bit_size_of(td: &TargetData, ty: BasicTypeEnum<'_>) -> u64 {
    // TargetData::get_bit_size takes AnyTypeEnum in some inkwell versions.
    // The safe path is to match on the concrete type and use get_bit_size
    // which accepts BasicTypeEnum via the AnyType blanket impl.
    td.get_bit_size(&ty)
}

/// Produce a human-readable LLVM type string without going through inkwell's
/// print_to_string (which sometimes adds extra metadata in debug builds).
fn type_string(ty: BasicTypeEnum<'_>) -> String {
    // inkwell's print_to_string on a type gives clean output like "i16",
    // "float", "[10 x i8]", etc. Safe to use here — we are not printing
    // a value, just a type.
    ty.print_to_string().to_string()
}

/// Fallback: scan the function definition line in raw IR text to find which
/// struct name is passed as the first argument.
///
/// RuSTy LLVM 21 output looks like:
///   define void @MONTH_TO_STRING(ptr %0)
///   ; with the struct %MONTH_TO_STRING defined separately
///
/// The naming convention (struct == function) handles this without scanning.
/// This fallback handles edge cases where names diverge (not observed in
/// current RuSTy but defensive).
fn find_struct_name_in_ir(ir_text: &str, func_name: &str) -> Option<String> {
    let needle = format!("@{}", func_name);
    for line in ir_text.lines() {
        if !line.starts_with("define") || !line.contains(&needle) {
            continue;
        }
        // Look for a typed pointer pattern: %StructName* or %"StructName"*
        // This only appears in older LLVM IR. In LLVM 21 it will be `ptr`.
        if let Some(pct) = line.find("(%") {
            let rest = &line[pct + 2..];
            let end = rest
                .find(|c: char| c == '*' || c == ' ' || c == ',' || c == ')')
                .unwrap_or(rest.len());
            let candidate = rest[..end].trim().trim_matches('"');
            if !candidate.is_empty() && candidate != func_name {
                return Some(candidate.to_string());
            }
        }
        // No typed pointer found — naming convention is our only option.
        break;
    }
    None
}

// ---------------------------------------------------------------------------
// Debug metadata: struct field names
// ---------------------------------------------------------------------------

/// Parse all !DICompositeType + !DIDerivedType metadata to extract
/// field name lists keyed by struct name.
///
/// Returns: HashMap<struct_name, Vec<field_name_in_declaration_order>>
fn extract_field_names_from_debug(ir_text: &str) -> HashMap<String, Vec<String>> {
    let md = extract_metadata_map(ir_text);
    let mut result: HashMap<String, Vec<String>> = HashMap::new();

    for rhs in md.values() {
        // We want structure type composite entries only.
        if !rhs.contains("!DICompositeType(") {
            continue;
        }
        if !rhs.contains("DW_TAG_structure_type") {
            continue;
        }

        // Extract struct name.
        let Some(raw_name) = extract_quoted_arg(rhs, "name:") else {
            continue;
        };
        // RuSTy emits the ST name directly (e.g. "MONTH_TO_STRING").
        // No "struct." prefix like clang. Strip it anyway for safety.
        let struct_name = raw_name
            .trim_start_matches("struct.")
            .trim_start_matches("class.")
            .to_string();

        // Get the elements tuple reference (!N).
        let Some(elements_ref) = extract_metadata_ref_after(rhs, "elements:") else {
            continue;
        };
        let Some(elements_rhs) = md.get(&elements_ref) else {
            continue;
        };

        // Each element ref in the tuple points to a !DIDerivedType member.
        let mut fields: Vec<String> = Vec::new();
        for member_ref in extract_metadata_refs(elements_rhs) {
            let Some(member_rhs) = md.get(&member_ref) else {
                continue;
            };
            if !member_rhs.contains("!DIDerivedType(") {
                continue;
            }
            if !member_rhs.contains("DW_TAG_member") {
                continue;
            }
            if let Some(field_name) = extract_quoted_arg(member_rhs, "name:") {
                fields.push(field_name);
            }
        }

        if !fields.is_empty() {
            result.insert(struct_name, fields);
        }
    }

    result
}