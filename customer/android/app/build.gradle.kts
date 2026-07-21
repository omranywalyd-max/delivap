plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // تأكد أن هذا الاسم هو نفسه الموجود في Firebase Console وفي ملف google-services.json
    namespace = "com.deliv.customer" 
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ تفعيل ميزة Desugaring لحل مشكلة مكتبة الإشعارات
        isCoreLibraryDesugaringEnabled = true 

        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        // تأكد أن هذا هو نفس الـ Package Name القديم لكي يعمل الـ SHA-1
        applicationId = "com.deliv.customer"
        
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // 3. دعم مكتبات الفايربيز الكبيرة
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

flutter {
    source = "../.."
}

// 5. ✅ إضافة المكتبة اللازمة لعملية الـ Desugaring
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-auth")
    implementation("androidx.core:core-ktx:1.13.1")
}
