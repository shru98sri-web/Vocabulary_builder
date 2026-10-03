plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.fresh_voca_builder"
    compileSdk = 37

    // Reads the high-performance native tools automatically from your system properties layer
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.fresh_voca_builder"

        // 1. Upgraded to 26 to satisfy your ML Speech recognition system needs
        minSdk = 26
        targetSdk = 35

        // Mapped values pointing directly to your root pubspec.yaml file versions
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Signing with the debug keys for now so local terminal runs deploy instantly
            signingConfig = signingConfigs.getByName("debug")

            // 2. Safely linked your custom ML Kit R8 exemption rules inside the compiler scope
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

// 3. Modern Flutter Built-in Kotlin target toolchain mapping
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
