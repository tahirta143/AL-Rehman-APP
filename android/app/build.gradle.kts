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
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // ✅ Split-friendly APK rename
    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abi = filters.find { it.filterType == "ABI" }?.identifier
            if (abi != null) {
                output.outputFileName = "WaseelaDiabesity-${buildType.name}-$abi.apk"
            } else {
                output.outputFileName = "WaseelaDiabesity-${buildType.name}.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}
