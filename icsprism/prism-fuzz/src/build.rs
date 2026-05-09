fn main() {
    let lib = "/workspaces/ICSPrism/benchmarks/out/harness_test_buggy";
    println!("cargo:rustc-link-search=native={}", lib);
    println!("cargo:rustc-link-lib=dylib=harness_test_buggy");
    println!("cargo:rustc-link-arg=-Wl,-rpath,{}", lib);
    println!("cargo:rustc-link-arg=-Wl,--allow-shlib-undefined");
}