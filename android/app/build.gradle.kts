import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing keys are git-ignored. android/key.properties is the primary copy;
// signing/local/ is the local backup inside the project folder (see signing/README.md).
val repoSigningDir = rootProject.projectDir.parentFile
fun resolveSigningFile(path: String): File? =
    listOf(rootProject.file(path), repoSigningDir.resolve(path)).firstOrNull { it.exists() }

val keystoreProperties = Properties().apply {
    val file = listOf(rootProject.file("key.properties"), repoSigningDir.resolve("signing/local/key.properties"))
        .firstOrNull { it.exists() }
    if (file != null) load(FileInputStream(file))
}
val resolvedStoreFile = keystoreProperties.getProperty("storeFile")?.let { resolveSigningFile(it) }
val hasReleaseKeystore = resolvedStoreFile != null

// A debug-signed release APK cannot update existing installs, so refuse to build
// one instead of silently falling back.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !hasReleaseKeystore) {
        throw GradleException(
            "Release signing key not found. Restore it first: bash signing/restore_signing.sh"
        )
    }
}

android {
    namespace = "com.majumaink.quotimate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.majumaink.quotimate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else null
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
