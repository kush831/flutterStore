plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.crave.store.apporiostore.apporio_store_30sept"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.crave.store.apporiostore.apporio_store_30sept"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    flavorDimensions += "default"
    productFlavors {
        create("crave") {
            dimension = "default"
            applicationId = "com.crave.store.apporiostore"
            resValue("string", "app_name", "Crave Store")
        }
        create("apporio") {
            dimension = "default"
            applicationId = "com.apporio.resturanent"
            resValue("string", "app_name", "All-In-One Store App")
        }
        create("apporioPreview") {
            dimension = "default"
            applicationId = "com.apporio.previewstore"
            resValue("string", "app_name", "Apporio Preview - Store")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    dependencies {
        implementation("com.onesignal:OneSignal:5.1.6") // the service extension below compiles against it
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

flutter {
    source = "../.."
}
