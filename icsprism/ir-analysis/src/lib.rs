pub mod ddg;
pub mod layout;
pub mod metadata;

pub use ddg::{build_ddg, DdgGraph, GraphEdge, GraphNode};
pub use layout::{extract_layout, FieldLayout, ProgramLayout};