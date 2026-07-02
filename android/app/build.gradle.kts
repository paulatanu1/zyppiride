import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load signing credentials from key.properties (never committed to git)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

// Load local.properties for keys that must not be committed to git
val localProperties = Properties().apply {
    val f = rootProject.file("../local.properties")
    if (f.exists()) load(FileInputStream(f))
}

dependencies {
  // Import the Firebase BoM (latest stable as of Jun 2026)
  implementation(platform("com.google.firebase:firebase-bom:34.15.0"))

  // Firebase products
  implementation("com.google.firebase:firebase-analytics")
  implementation("com.google.firebase:firebase-auth")
  implementation("com.google.firebase:firebase-appcheck-playintegrity")

  // Play Integrity for Phone Auth silent verification (SafetyNet is deprecated)
  implementation("com.google.android.play:integrity:1.3.0")

  // Core library desugaring for flutter_local_notifications
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

android {
    namespace = "com.zyppiride.app"

    // Updated to 36 to resolve plugin warnings (Android 16 / API 36, stable since March 2025)
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Java 17 for AGP 8.12+ and Flutter 3.35+ compatibility
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    // Kotlin 2.3+ replaced kotlinOptions{} with the compilerOptions DSL.
    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.zyppiride.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        
        minSdk = 24
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true

        manifestPlaceholders["MAPS_API_KEY"] = localProperties.getProperty("MAPS_API_KEY") ?: ""
    }

    signingConfigs {
        create("release") {
            // CI reads secrets from env vars; local dev falls back to key.properties.
            // Names match the release-android.yml workflow's secrets.
            keyAlias     = System.getenv("ZYPPI_KEY_ALIAS")
                ?: keyProperties.getProperty("keyAlias")     ?: ""
            keyPassword  = System.getenv("ZYPPI_KEY_PASSWORD")
                ?: keyProperties.getProperty("keyPassword")  ?: ""
            storePassword = System.getenv("ZYPPI_STORE_PASSWORD")
                ?: keyProperties.getProperty("storePassword") ?: ""
            storeFile = (System.getenv("ZYPPI_STORE_FILE")
                ?: keyProperties.getProperty("storeFile"))
                ?.let { file(it) }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

