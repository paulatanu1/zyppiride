plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
  // Import the Firebase BoM (latest stable as of Oct 2025)
  implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")

  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
  // Example: implementation("com.google.firebase:firebase-firestore")
  //          implementation("com.google.firebase:firebase-storage")
  //          implementation("com.google.firebase:firebase-auth")
}

android {
    namespace = "com.example.zyppi_ride"
    
    // Updated to 36 to resolve plugin warnings (Android 16 / API 36, stable since March 2025)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17 for AGP 8.12+ and Flutter 3.35+ compatibility
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Java 17
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID[](https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.zyppi_ride"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Optional: Enable minification for release builds
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
