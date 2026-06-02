plugins {
id("com.android.application")
id("dev.flutter.flutter-gradle-plugin")
}

android {
namespace = "com.example.expense_tracker"
compileSdk = flutter.compileSdkVersion
ndkVersion = flutter.ndkVersion

compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

defaultConfig {
    applicationId = "com.example.expense_tracker"
    minSdk = flutter.minSdkVersion
    targetSdk = 34
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}

signingConfigs {
    create("release") {
        storeFile = file("upload-keystore.jks")
        storePassword = "kapilv"
        keyAlias = "upload"
        keyPassword = "kapilv"
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
        isShrinkResources = false
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
