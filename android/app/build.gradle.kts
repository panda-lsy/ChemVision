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
            ?: "1"
    ).toInt()
}
val flutterVersionName: String by lazy {
    providers.gradleProperty("FLUTTER_VERSION_NAME").orNull
        ?: providers.gradleProperty("flutter.versionName").orNull
        ?: "1.0.0"
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
        minSdk = flutter.minSdkVersion
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

dependencies {
    // BlueLM 端侧 LLM SDK（需下载 AAR 放入 libs/）
    // 下载地址见 doc/APIS/BlueLM/BlueLMText.md
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
