import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ── RELEASE-1 / W11.1: release signing gate (hand-mirrored from the core
// template — the generator's `flutter create` owns this file's baseline, so a
// regeneration reverts these lines; re-apply per docs/RELEASE_RUNBOOK.md).
// Same contract as core: release builds MUST be signed from android/key.properties
// and fail CLOSED with a clear message when it is absent or incomplete. ──
val _releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
// Kotlin DSL sam-with-receiver: inside this lambda the receiver IS the
// TaskExecutionGraph (allTasks below resolves on it).
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.project == project &&
            (task.name == "bundleRelease" || task.name == "assembleRelease")
    }
    if (buildingRelease) {
        val missing = _releaseSigningKeys.filter { key ->
            keystoreProperties.getProperty(key).isNullOrBlank()
        }
        check(missing.isEmpty()) {
            "Release build requires a complete android/key.properties " +
                "(missing: $missing). Copy key.properties.template, fill in " +
                "your keystore values, and NEVER commit the file."
        }
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "labs.carnama.halal_boyz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "labs.carnama.halalboys"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // RELEASE-1 / W11.1: a release build is signed from
            // android/key.properties (the gate above fails closed when the
            // keystore is absent/incomplete) — never with the debug key.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// ── ANDROID-AAR-METADATA FIX (halal_boyz rebrand batch) ──────────────────────
// Mirrors the core_app template's PROVEN config (core_app/android/app/
// build.gradle.kts:53-57,102-104) that passes the SAME flutter-gradle-plugin +
// flutter_local_notifications 17.2.4 (packages/core pin) AAR build on this SDK.
// flutter_local_notifications' android/build.gradle sets
// `coreLibraryDesugaringEnabled true` (Java 1.8 target), so Gradle's
// checkDebugAarMetadata REQUIRES the consuming app (:app) to enable core-library
// desugaring too — the flutter-gradle-plugin does not propagate it
// (flutter/flutter#161964 resolved as app-side). Without this, `flutter build
// apk --debug` fails: "Dependency ':flutter_local_notifications' requires core
// library desugaring to be enabled for :app".
// Re-apply note (same as the RELEASE-1 signing mirror above): the generator's
// `flutter create` owns this file's baseline, so a regeneration reverts these
// lines; re-apply with the template on the next regen.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
