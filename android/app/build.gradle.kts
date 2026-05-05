import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load signing credentials from key.properties (never committed to git)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

dependencies {
  // Import the Firebase BoM (latest stable as of Oct 2025)
  implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

  // Firebase products
  implementation("com.google.firebase:firebase-analytics")
  implementation("com.google.firebase:firebase-auth")
  implementation("com.google.firebase:firebase-appcheck-playintegrity")

  // Required for Phone Auth silent verification (avoids reCAPTCHA)
  implementation("com.google.android.gms:play-services-safetynet:18.0.1")
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

    kotlinOptions {
        // Java 17
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.zyppiride.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        
        // Explicitly set for compatibility (Flutter default may be lower)
        minSdk = flutter.minSdkVersion
        targetSdk = 36  // Updated to match compileSdk for latest security/best practices
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Recommended: Add multiDexEnabled if your app exceeds 64K methods (common with Firebase/plugins)
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias     = keyProperties.getProperty("keyAlias")     ?: ""
            keyPassword  = keyProperties.getProperty("keyPassword")  ?: ""
            storeFile    = keyProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProperties.getProperty("storePassword") ?: ""
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

// Optional: Add this block for better build performance with AGP 8+
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        freeCompilerArgs += "-Xcontext-receivers"
    }
}
