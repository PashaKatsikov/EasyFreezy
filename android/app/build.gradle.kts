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
// libsleet.so into jniLibs, so it is packaged into the APK and can be opened at
// runtime via dart:ffi (DynamicLibrary.open("libsleet.so")).
//
// This talks to cargo directly (no cargo-ndk needed): it resolves the NDK from
// AGP and points each target's linker at the NDK clang wrapper. Prerequisites:
//   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
// plus the Android NDK (already pulled in via `ndkVersion` above).
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

val buildRustSleet by tasks.registering {
    inputs.dir(File(rustRoot, "src"))
    inputs.file(File(rustRoot, "Cargo.toml"))
    outputs.dir(jniLibsOut)
    doLast {
        val binDir = File(android.ndkDirectory, "toolchains/llvm/prebuilt/$hostTag/bin")
        val clangExt = if (isWindows) ".cmd" else ""
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
            rustAbis.forEach { (triple, _, clangPrefix) ->
                val key = "CARGO_TARGET_${triple.uppercase().replace('-', '_')}_LINKER"
                environment(key, File(binDir, "$clangPrefix$rustApiLevel-clang$clangExt").absolutePath)
            }
        }
        rustAbis.forEach { (triple, abi, _) ->
            val built = File(rustRoot, "target/$triple/release/libsleet.so")
            val dstDir = File(jniLibsOut, abi).apply { mkdirs() }
            built.copyTo(File(dstDir, "libsleet.so"), overwrite = true)
        }
    }
}

tasks.named("preBuild") {
    dependsOn(buildRustSleet)
}

