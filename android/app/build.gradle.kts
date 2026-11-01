plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.glamzo.glamzo_saloon"
    compileSdk = 36

    signingConfigs {
        // ⚠️  SECURITY: NEVER hardcode keystore credentials here.
    // Store them in android/local.properties (already .gitignored):
    //   storePassword=your_store_password
    //   keyPassword=your_key_password
    //   keyAlias=glamzo
    //   storeFile=glamzo-release.keystore
    //
    // Then read them below:
    create("release") {
        val props = java.util.Properties()
        val localPropsFile = rootProject.file("local.properties")
        if (localPropsFile.exists()) {
            props.load(localPropsFile.inputStream())
        }
        storeFile = file(props.getProperty("storeFile", "glamzo-release.keystore"))
        storePassword = props.getProperty("storePassword", "")
        keyAlias = props.getProperty("keyAlias", "glamzo")
        keyPassword = props.getProperty("keyPassword", "")
    }
    }

    defaultConfig {
        applicationId = "com.glamzo.glamzo_saloon"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // ✅ Reads versionCode and versionName from pubspec.yaml automatically
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // ── Strip unused locale resources (keeps only English + Indian)
        // This alone can save 2-5 MB by removing 60+ unused language folders
        resConfigs("en", "hi", "ta", "te", "kn", "ml", "mr", "bn")
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            // R8 full-mode: strips unused classes, methods, and fields
            isMinifyEnabled = true
            // Remove unused drawables, layouts, strings, etc.
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ── ABI Splits: only for release (Flutter debug sets its own abiFilters) ──
    // Generates separate smaller APKs per CPU architecture for release builds
    splits {
        abi {
            isEnable = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = false
        }
    }

    // ── Bundle language splits (for AAB / Play Store) ──
    bundle {
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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

// ── Fix: Redirect build output to Flutter's expected location ──────────────
// AGP 9+ dropped the deprecated buildDir setter that Flutter's Gradle plugin
// used to redirect outputs. Flutter's tool expects the APK at:
//   <flutter-project-root>/build/app/outputs/flutter-apk/app-release.apk
// rootProject.projectDir = android/, so parentFile = flutter project root.
val flutterProjectRoot = rootProject.projectDir.parentFile
layout.buildDirectory.set(File(flutterProjectRoot, "build/app"))

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
