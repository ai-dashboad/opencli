//! Attach this crate's manifest to this crate's own executables.
//!
//! `winres` writes a resource containing VERSIONINFO as well as the manifest,
//! and announces it with `cargo:rustc-link-lib=resource` — a *name*, resolved
//! by the linker against every search path it has been given, in order. That
//! is fine while this crate is the thing being built and ruinous when it is a
//! dependency of something that has a resource of its own: the desktop app
//! embeds one through Tauri, its output directory is searched first, and the
//! unqualified `resource` resolved to Tauri's copy. The same file was then
//! linked twice, and every Windows bundle died in
//! `CVT1100: duplicate resource. type:VERSION`.
//!
//! So the resource is attached only when this package is the one being built.
//! As a dependency it contributes code, which is all anything wanted from it.

fn main() {
    // Set by cargo for the packages it was asked to build, and absent when
    // this crate is pulled in as a dependency — which is exactly the
    // distinction that matters here.
    if std::env::var_os("CARGO_PRIMARY_PACKAGE").is_none() {
        return;
    }

    // A manifest is a Windows thing. Running this elsewhere only ever printed
    // an error into a build that then succeeded anyway.
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }

    let mut res = winres::WindowsResource::new();
    res.set_manifest_file("opencli-windows-sandbox-setup.manifest");
    let _ = res.compile();
}
