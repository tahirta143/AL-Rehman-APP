plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hims_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Updated per Gradle recommendation
        freeCompilerArgs += listOf("-Xjvm-default=all")
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.waseeladiabesity"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ Kotlin DSL safe APK rename
    applicationVariants.all {
        outputs.all {
            // Safe cast to rename APK
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            outputImpl.outputFileName = "WaseelaDiabesity-${buildType.name}.apk"
        }
    }
}

flutter {
    source = "../.."
}