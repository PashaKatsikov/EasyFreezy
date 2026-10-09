// Android cdylib link glue for the BoringSSL (btls-sys) backend used by wreq.
//
// Why this exists:
//
//   btls-sys emits `cargo:rustc-link-lib=ssl` followed by
//   `cargo:rustc-link-lib=crypto` in that order. Both archives contain mutual
//   references (SSL_* calls into EVP_*/X509_*). Android's lld is a
//   single-pass linker: libssl.a is pulled in first, its unresolved symbols
//   remain on the pending list, libcrypto.a is scanned and resolves them,
//   but libssl.a is NOT revisited — so any X509_*/EVP_* needed by libssl
//   that is only pulled in once lld has already walked past libssl stays
//   undefined (SSL_CTX_free is the canonical repro).
//
//   `--start-group ... --end-group` tells the linker to re-scan the enclosed
//   archives until no new references appear, which is exactly what mutually
//   recursive BoringSSL archives need. We put the group AFTER btls-sys'
//   plain -lssl/-lcrypto lines so the group's extra pass fills the gaps.
//
// This is only emitted for Android targets. Host builds (used by the Dart
// generator's doctor tests) link ssl/crypto on their own with GNU ld, which
// handles archive cycles natively.
fn main() {
    let target = std::env::var("TARGET").unwrap_or_default();
    if target.contains("android") {
        println!("cargo:rustc-link-arg-cdylib=-Wl,--start-group");
        println!("cargo:rustc-link-arg-cdylib=-lssl");
        println!("cargo:rustc-link-arg-cdylib=-lcrypto");
        println!("cargo:rustc-link-arg-cdylib=-Wl,--end-group");
        // btls-sys hard-codes CMAKE_ANDROID_STL_TYPE=c++_shared, so the
        // resulting libsleet.so has DT_NEEDED libc++_shared.so. The matching
        // .so is shipped alongside libsleet.so from the gradle task
        // (buildRustSleet) — do NOT try to statically link libc++ here, it
        // would not change the archive's dynamic deps and only produces a
        // misleading set of flags.
    }
}
