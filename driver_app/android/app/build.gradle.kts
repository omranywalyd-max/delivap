plugins {
    id("com.android.application")
    // 1. تعريف لغة كوتلن (تمت الإضافة)
    id("org.jetbrains.kotlin.android")
    
    id("dev.flutter.flutter-gradle-plugin")
    // 2. سطر الفايربيز
    id("com.google.gms.google-services")
}

android {
    namespace = "com.deliv.driver" 
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // --- إضافة هذا السطر لحل مشكلة flutter_local_notifications ---
        isCoreLibraryDesugaringEnabled = true 
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.deliv.driver"
        
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true 
    }

    signingConfigs {
        create("release") {
            storeFile = file("../../keystore.jks")?.takeIf { it.exists() }
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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

// --- إضافة هذا الجزء في نهاية الملف لحل مشكلة Desugaring ---
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
