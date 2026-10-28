import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val flutterVersionCode: Int by lazy {
    (
        providers.gradleProperty("FLUTTER_VERSION_CODE").orNull
            ?: providers.gradleProperty("flutter.versionCode").orNull
            ?: flutter.versionCode.toString()
    ).toInt()
}
val flutterVersionName: String by lazy {
    providers.gradleProperty("FLUTTER_VERSION_NAME").orNull
        ?: providers.gradleProperty("flutter.versionName").orNull
        ?: flutter.versionName
}

android {
    namespace = "com.chemvision.chemvision"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.chemvision.chemvision"
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
