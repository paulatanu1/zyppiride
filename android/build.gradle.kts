buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP and Kotlin versions are declared in settings.gradle.kts pluginManagement.
        // Only Google Services is here because it has no pluginManagement entry.
        classpath("com.google.gms:google-services:4.4.4")
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

// Upgrade any plugin that still targets Java 8 to Java 11 so JDK 21 doesn't emit
// deprecation warnings (e.g. geolocator_android). Configured at the task level to
// avoid the "project already evaluated" error with afterEvaluate.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        if (sourceCompatibility == "1.8" || sourceCompatibility == "8") {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}