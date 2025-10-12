plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_sage"  // 👈 add this line
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.app_sage"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // ✅ Correct syntax for Kotlin DSL
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Example: add your other dependencies here
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
}
    
flutter {
    source = "../.."
}
