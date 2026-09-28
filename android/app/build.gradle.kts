plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.jood.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.jood.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Production credentials must come from CI/local environment, not Git.
    // Do not fail during Gradle configuration: Flutter debug builds must work
    // on developer devices without access to the production keystore.
    val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
    val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
    val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
    val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")
    val releaseSigningConfigured = !keystorePath.isNullOrBlank() &&
        !keystorePassword.isNullOrBlank() &&
        !keyAliasValue.isNullOrBlank() &&
        !keyPasswordValue.isNullOrBlank()

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = keystorePassword
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    // Fail only when a release task is actually requested, never for `flutter run`.
    gradle.taskGraph.whenReady {
        if (!releaseSigningConfigured && allTasks.any { it.name.contains("Release") }) {
            throw GradleException(
                "Release signing is not configured. Set ANDROID_KEYSTORE_PATH, " +
                    "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and " +
                    "ANDROID_KEY_PASSWORD in the build environment."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
