fn main() {
    let lib_dir = std::env::var("PRISM_LIB_DIR")
        .expect("PRISM_LIB_DIR must be set to the directory containing the target .so");
    let lib_name = std::env::var("PRISM_LIB_NAME")
        .expect("PRISM_LIB_NAME must be set to the library name without lib prefix or .so suffix");

    println!("cargo:rustc-link-search=native={}", lib_dir);
    println!("cargo:rustc-link-lib=dylib={}", lib_name);
    println!("cargo:rustc-link-arg=-Wl,-rpath,{}", lib_dir);
    println!("cargo:rustc-link-arg=-Wl,--allow-shlib-undefined");
    println!("cargo:rustc-link-arg=-Wl,--export-dynamic");

    println!("cargo:rerun-if-env-changed=PRISM_LIB_DIR");
    println!("cargo:rerun-if-env-changed=PRISM_LIB_NAME");
}