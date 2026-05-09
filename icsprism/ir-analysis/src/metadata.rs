use std::collections::HashMap;

/// Parse all numbered metadata entries (!0, !1, ...) from IR text.
/// Returns a map of "!N" -> the raw RHS string of that metadata entry.
pub(crate) fn extract_metadata_map(ir: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for line in ir.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with('!') {
            continue;
        }
        let Some((lhs, rhs)) = trimmed.split_once(" = ") else {
            continue;
        };
        // Only numbered entries like !0, !42 — not named ones like !dbg
        if lhs.len() > 1 && lhs[1..].chars().all(|c| c.is_ascii_digit()) {
            map.insert(lhs.to_string(), rhs.to_string());
        }
    }
    map
}

/// Extract the value of a quoted argument from a metadata string.
/// e.g. extract_quoted_arg(`!DILocalVariable(name: "LANG", ...)`, "name:") -> Some("LANG")
pub(crate) fn extract_quoted_arg(text: &str, key: &str) -> Option<String> {
    let start = text.find(key)? + key.len();
    let rest = &text[start..];
    let first = rest.find('"')? + 1;
    let after = &rest[first..];
    let second = after.find('"')?;
    Some(after[..second].to_string())
}

/// Extract a metadata reference like "!42" that follows a given key.
/// e.g. extract_metadata_ref_after(`elements: !12,`, "elements:") -> Some("!12")
pub(crate) fn extract_metadata_ref_after(text: &str, key: &str) -> Option<String> {
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
    if id.len() > 1 { Some(id) } else { None }
}

/// Extract all metadata references (!N) from a string.
pub(crate) fn extract_metadata_refs(text: &str) -> Vec<String> {
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

/// Build a map of SSA name (e.g. "%lang") -> human variable name (e.g. "LANG")
/// by walking llvm.dbg.value / llvm.dbg.declare call sites and matching them
/// to !DILocalVariable metadata entries.
pub(crate) fn build_ssa_name_map(ir: &str) -> HashMap<String, String> {
    let md = extract_metadata_map(ir);

    // Map !N -> variable name for all DILocalVariable entries
    let mut local_names: HashMap<String, String> = HashMap::new();
    for (key, rhs) in &md {
        if rhs.contains("!DILocalVariable(") {
            if let Some(name) = extract_quoted_arg(rhs, "name:") {
                local_names.insert(key.clone(), name);
            }
        }
    }

    // Walk dbg intrinsic call lines to connect SSA names to variable names
    let mut aliases: HashMap<String, String> = HashMap::new();
    for line in ir.lines() {
        if !(line.contains("llvm.dbg.value") || line.contains("llvm.dbg.declare")) {
            continue;
        }
        let Some(ssa) = first_ssa_in_line(line) else { continue };
        let Some(md_ref) = extract_metadata_ref_after(line, "metadata !") else { continue };
        if let Some(var_name) = local_names.get(&md_ref) {
            aliases.insert(ssa, var_name.clone());
        }
    }
    aliases
}

/// Find the first %name token in a line.
pub(crate) fn first_ssa_in_line(line: &str) -> Option<String> {
    let bytes = line.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' {
            let mut j = i + 1;
            while j < bytes.len() && is_ssa_char(bytes[j]) {
                j += 1;
            }
            if j > i + 1 {
                return Some(line[i..j].to_string());
            }
        }
        i += 1;
    }
    None
}

pub(crate) fn is_ssa_char(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'_' || c == b'.'
}