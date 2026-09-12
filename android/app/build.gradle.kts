plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lunaapp.luna_app"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lunaapp.luna_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

}





kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-splashscreen:1.0.1")
}

// ── Strip native debug symbols for release ──────────────────────────────────
// Flutter's Gradle plugin on Windows skips stripping libflutter.so.
// We hook in after mergeReleaseNativeLibs to strip it ourselves.
afterEvaluate {
    val stripExe = "C:\\Users\\Rahul\\AppData\\Local\\Android\\sdk\\ndk\\30.0.16248370\\toolchains\\llvm\\prebuilt\\windows-x86_64\\bin\\llvm-strip.exe"
    tasks.matching { it.name == "mergeReleaseNativeLibs" }.configureEach {
        doLast {
            val mergedDir = file("${layout.buildDirectory.get()}/intermediates/merged_native_libs/release/mergeReleaseNativeLibs")
            if (mergedDir.exists()) {
                fileTree(mergedDir) { include("**/*.so") }.forEach { soFile ->
                    val before = soFile.length() / 1_048_576.0
                    val proc = ProcessBuilder(stripExe, "--strip-debug", soFile.absolutePath)
                        .redirectErrorStream(true)
                        .start()
                    proc.waitFor()
                    val after = soFile.length() / 1_048_576.0
                    println("Stripped ${soFile.name}: ${"%.1f".format(before)}MB → ${"%.1f".format(after)}MB")
                }
            }
        }
    }
}
