fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Prefer vendored protoc so local/CI builds do not require a system install.
    if let Ok(path) = protoc_bin_vendored::protoc_bin_path() {
        std::env::set_var("PROTOC", path);
    }
    let proto = std::path::Path::new("../schemas/benchmark_data.proto");
    let includes = std::path::Path::new("../schemas");
    if proto.is_file() {
        prost_build::Config::new()
            // Keep field names close to the shared .proto for fidelity mapping.
            .compile_protos(&[proto], &[includes])?;
        println!("cargo:rerun-if-changed=../schemas/benchmark_data.proto");
    } else {
        // Docker/cwd may differ; try relative to CARGO_MANIFEST_DIR.
        let manifest = std::path::PathBuf::from(std::env::var("CARGO_MANIFEST_DIR")?);
        let proto = manifest.join("../schemas/benchmark_data.proto");
        let includes = manifest.join("../schemas");
        prost_build::Config::new().compile_protos(&[&proto], &[&includes])?;
        println!("cargo:rerun-if-changed={}", proto.display());
    }
    Ok(())
}
