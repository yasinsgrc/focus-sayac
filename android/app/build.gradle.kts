import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası `android/key.properties`ten okunur; dosya `.gitignore`da
// (anahtar deposu ve parolalar depoya girmez — bkz. `docs/play/RELEASE.md`).
// Dosya yoksa `release` yine debug anahtarıyla imzalanır: geliştirici
// makinesinde `flutter build apk --release` çalışmaya devam etsin diye.
// Böyle bir çıktı Play'e yüklenemez, Console debug imzasını reddeder.
val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        keystoreFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.focussayac.focussayac"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // `flutter_local_notifications` (Ekran 12'nin zamanlanmış bildirimleri)
        // java.time API'lerini kullanıyor ve AAR meta verisinde desugaring
        // şart koşuyor; kapalıyken `:app:checkProfileAarMetadata` düşüyor.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.focussayac.focussayac"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Ana ekran widgetlarinin bitmap metinleri res/font altindaki yazi
    // tiplerini ResourcesCompat ile yukluyor (widget/WidgetTypography.kt).
    // Flutter gomulusu androidx.core getiriyor ama gecisli bagimlilik
    // sessizce degisebilir; dogrudan bildiriliyor.
    implementation("androidx.core:core-ktx:1.13.1")
}
