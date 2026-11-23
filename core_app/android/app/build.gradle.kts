import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ── RELEASE-1 / W11.1: release signing gate (fail-closed, never silent) ──
// Debug/profile builds never need a keystore. A RELEASE build must be signed
// with a REAL keystore via android/key.properties (copy key.properties.template
// and fill it in; the file and any *.jks are gitignored and must never be
// committed). A missing/incomplete keystore in a release build fails here with
// a clear message instead of emitting a debug-signed or unsigned artifact.
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
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.firebase.firebase-perf")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.carnama.labs"
    compileSdk = 35
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
        applicationId = "com.carnama.labs"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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
            // ── R8 / ProGuard ────────────────────────────────────────────────
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ── Signing ──────────────────────────────────────────────────────
            // WHY: debug signingConfig was a production stopper for Google Play.
            // key.properties is populated in CI via KEYSTORE_* environment secrets.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
