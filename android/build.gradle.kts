buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Updated to latest stable AGP for Flutter 3.35+ (as of Oct 2025)
        // AGP 8.12.0 is recommended for compatibility with modern plugins like geolocator ^14+
        classpath("com.android.tools.build:gradle:8.12.0")
        
        // Updated Kotlin to 2.0.21 for Flutter 3.29+ compatibility
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21")
        
        // Google Services is up-to-date
        classpath("com.google.gms:google-services:4.4.3")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory logic (retained as-is)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}