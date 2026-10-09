import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.easyfreezy.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.easyfreezy.app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.core:core-ktx:1.15.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ── Native Rust gray-layer (libsleet.so) ────────────────────────────────────
// Builds the rust/ crate for the Android ABIs and places the resulting
// libsleet.so into jniLibs, so it is packaged into the APK and can be opened
// at runtime via dart:ffi (DynamicLibrary.open("libsleet.so")).
//
// This talks to cargo directly (no cargo-ndk needed): it resolves the NDK
// from AGP and feeds cargo an environment tuned for the wreq + btls-sys
// (BoringSSL) stack:
//
//  * NDK clang bin goes on PATH so the `cc` crate finds the per-ABI wrapper
//    (<clangPrefix><api>-clang) on its own. We deliberately do NOT set
//    CC_<target>/CXX_<target>: when those are set the btls-sys BoringSSL
//    build pulls the host compiler for its first pass and the resulting
//    libssl.a is COFF x86_64 on Windows (magic 64 86), which lld silently
//    discards — leaving dlopen() screaming about missing SSL_CTX_free at
//    runtime. Letting cc auto-select keeps the right wrapper in play.
//
//  * CMake 3.x (major < 4) from Android SDK goes on PATH: cmake 4 is
//    incompatible with android.toolchain.cmake. We also prepend the matching
//    `ninja` so the cmake crate picks the Ninja generator.
//
//  * ANDROID_NDK_HOME is exported so the `cmake` crate automatically wires
//    CMAKE_TOOLCHAIN_FILE to android.toolchain.cmake.
//
//  * BINDGEN_EXTRA_CLANG_ARGS_<triple> gets --sysroot + --target so
//    btls-sys' bindgen walk over the BoringSSL headers resolves against the
//    NDK sysroot rather than the host.
//
//  * CFLAGS_<triple> / CXXFLAGS_<triple> each inject a SECOND --target
//    with the API suffix (e.g. aarch64-linux-android26). This exists purely
//    to work around a clash between cmake-rs 0.1.58 and the modern NDK's
//    android.toolchain.cmake: cmake-rs auto-generates
//    `-DCMAKE_C_FLAGS=--target=aarch64-linux-android -w` from the cc crate's
//    detected compiler args (no API level), which lands AFTER
//    android.toolchain.cmake's own `--target=aarch64-none-linux-android<API>`
//    on the clang command line. Clang keeps the last --target, strips the
//    API, and then looks for crtbegin_dynamic.o under
//    `<sysroot>/usr/lib/aarch64-linux-android/` (no API dir) — which does
//    not exist, so the whole btls-sys build dies at CMakeTestCCompiler.
//    By appending our own `--target=<clangPrefix><api>` via CFLAGS_, it
//    becomes the final --target, clang re-attaches the API, and the CRT
//    files are found. This matches what the user's spec allows:
//    "CFLAGS_/CXXFLAGS_ … оставить — их читает cc/bindgen, btls их
//    игнорирует."
//
// Prerequisites:
//   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
// plus the Android NDK (pulled in via `ndkVersion` above) and the Android
// SDK's cmake package (installed via "Android SDK → SDK Tools → CMake").
val rustRoot = rootProject.file("../rust")
val jniLibsOut = file("src/main/jniLibs")
val isWindows = System.getProperty("os.name").lowercase().contains("windows")
val hostTag = when {
    isWindows -> "windows-x86_64"
    System.getProperty("os.name").lowercase().contains("mac") -> "darwin-x86_64"
    else -> "linux-x86_64"
}
// Native API level for the .so; keep in sync with defaultConfig.minSdk.
val rustApiLevel = 26

// (rust target triple, jniLibs ABI dir, NDK clang wrapper prefix)
val rustAbis = listOf(
    Triple("aarch64-linux-android", "arm64-v8a", "aarch64-linux-android"),
    Triple("armv7-linux-androideabi", "armeabi-v7a", "armv7a-linux-androideabi"),
    Triple("x86_64-linux-android", "x86_64", "x86_64-linux-android"),
)

/**
 * Picks the newest CMake installed under `$SDK/cmake/` whose major version is
 * < 4. Returns null if nothing suitable is present.
 */
fun resolveSdkCmakeBin(): File? {
    val sdkDir = android.sdkDirectory ?: return null
    val cmakeRoot = File(sdkDir, "cmake")
    if (!cmakeRoot.isDirectory) return null
    val candidates = cmakeRoot.listFiles { f -> f.isDirectory }?.toList().orEmpty()
    val chosen = candidates
        .mapNotNull { dir ->
            val major = dir.name.substringBefore('.', missingDelimiterValue = "0").toIntOrNull()
            if (major != null && major in 1..3) dir to dir.name else null
        }
        .maxByOrNull { it.second }
        ?.first ?: return null
    return File(chosen, "bin").takeIf { it.isDirectory }
}

val buildRustSleet by tasks.registering {
    inputs.dir(File(rustRoot, "src"))
    inputs.file(File(rustRoot, "Cargo.toml"))
    inputs.file(File(rustRoot, "build.rs"))
    outputs.dir(jniLibsOut)
    doLast {
        val ndkDir = android.ndkDirectory
        val binDir = File(ndkDir, "toolchains/llvm/prebuilt/$hostTag/bin")
        val sysroot = File(ndkDir, "toolchains/llvm/prebuilt/$hostTag/sysroot")
        val clangExt = if (isWindows) ".cmd" else ""
        val cmakeBin = resolveSdkCmakeBin()
            ?: error(
                "Android SDK CMake (major < 4) not found under ${android.sdkDirectory}/cmake. " +
                    "Install it via Android Studio → SDK Manager → SDK Tools → CMake (3.x)."
            )

        exec {
            workingDir = rustRoot
            val args = mutableListOf<String>()
            if (isWindows) {
                args.add("cmd"); args.add("/c")
            }
            args.add("cargo"); args.add("build"); args.add("--release")
            rustAbis.forEach { (triple, _, _) ->
                args.add("--target"); args.add(triple)
            }
            commandLine = args

            // Prepend NDK clang + Android SDK CMake (which also ships ninja)
            // to PATH so both the `cc` and `cmake` Rust crates find a working
            // Android-aware toolchain without us having to pin CC_/CXX_.
            val pathSep = if (isWindows) ";" else ":"
            val existingPath = System.getenv("PATH") ?: ""
            environment(
                "PATH",
                listOf(binDir.absolutePath, cmakeBin.absolutePath, existingPath)
                    .filter { it.isNotEmpty() }
                    .joinToString(pathSep)
            )
            // Hint for the `cmake` crate: it reads this to set
            // CMAKE_TOOLCHAIN_FILE=<ndk>/build/cmake/android.toolchain.cmake.
            environment("ANDROID_NDK_HOME", ndkDir.absolutePath)
            environment("ANDROID_NDK_ROOT", ndkDir.absolutePath)
            // Force Ninja: without this, CMake on Windows picks NMake and
            // dies with "'nmake' '-?' failed" because MSVC isn't on PATH.
            // The Android SDK's cmake dir already ships ninja.exe next to
            // cmake.exe, and PATH was prepended above.
            environment("CMAKE_GENERATOR", "Ninja")

            rustAbis.forEach { (triple, _, clangPrefix) ->
                val tripleU = triple.uppercase().replace('-', '_')
                // Per-triple linker: NDK's clang wrapper already carries the
                // right sysroot flags, so cargo doesn't need separate -L dirs.
                environment(
                    "CARGO_TARGET_${tripleU}_LINKER",
                    File(binDir, "$clangPrefix$rustApiLevel-clang$clangExt").absolutePath,
                )
                // bindgen reads this exact env name (hyphens stay as-is) when
                // generating bindings for btls-sys' BoringSSL headers; without
                // it libclang falls back to host includes and the whole crate
                // fails to compile on cross builds.
                environment(
                    "BINDGEN_EXTRA_CLANG_ARGS_$triple",
                    "--sysroot=\"${sysroot.absolutePath}\" --target=$clangPrefix$rustApiLevel",
                )
                // cc crate reads CFLAGS_<triple-with-underscores>; see the
                // long comment at the top of this task for why we need to
                // smuggle in a trailing `--target=` with the API suffix.
                val tripleUnder = triple.replace('-', '_')
                val apiTarget = "--target=$clangPrefix$rustApiLevel"
                environment("CFLAGS_$tripleUnder", apiTarget)
                environment("CXXFLAGS_$tripleUnder", apiTarget)
            }
        }

        // Verify what we just built really IS an Android ELF — guards against
        // the exact failure mode above (host-COFF slipping into the .so).
        rustAbis.forEach { (triple, abi, _) ->
            val built = File(rustRoot, "target/$triple/release/libsleet.so")
            require(built.isFile) { "cargo did not produce $built" }
            val head = ByteArray(4).also { buf ->
                built.inputStream().use { it.read(buf) }
            }
            require(head[0] == 0x7F.toByte() && head[1] == 'E'.code.toByte() &&
                    head[2] == 'L'.code.toByte() && head[3] == 'F'.code.toByte()) {
                "$built is not an ELF file (magic ${head.joinToString(" ") { "%02X".format(it) }}) " +
                    "— btls-sys likely compiled with the host toolchain. Make sure CC_$triple / " +
                    "CXX_$triple are NOT set in the build environment."
            }
            val dstDir = File(jniLibsOut, abi).apply { mkdirs() }
            built.copyTo(File(dstDir, "libsleet.so"), overwrite = true)
        }
    }
}

tasks.named("preBuild") {
    dependsOn(buildRustSleet)
}

