import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key for Google Play (android/key.properties, never committed — see
// .gitignore). Only App Bundles (Play uploads) are signed with it; APKs built
// for testing on a phone keep the debug key so they install over each other.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val buildingBundle = gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }

android {
    namespace = "com.farazlabs.bijli_kab"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Scheduled notifications (flutter_local_notifications) need desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.farazlabs.bijli_kab"
        // Firebase needs Android 6.0+.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildFeatures {
        resValues = true
    }

    signingConfigs {
        if (keyProps.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Installs next to the real app as "Bijli Kab Dev", with its own data.
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Bijli Kab Dev")
        }
        release {
            resValue("string", "app_name", "Bijli Kab?")
            signingConfig =
                if (buildingBundle && keyProps.containsKey("storeFile")) signingConfigs.getByName("upload")
                else signingConfigs.getByName("debug")
        }
        getByName("profile") {
            resValue("string", "app_name", "Bijli Kab?")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AppCompat theme for the fingerprint dialog on Android 8 and below.
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
