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
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // `FlameRenderer`in iddialari `src/sharedTest` altinda TEK yerde duruyor;
    // iki kosum evi (Robolectric + cihaz) ayni dosyayi derliyor. Ayri ayri
    // yazilsalar zamanla ayrisirlardi, ayrisma da tam bu maddenin kapatmaya
    // calistigi bosluk.
    sourceSets {
        getByName("test").java.srcDir("src/sharedTest/kotlin")
        getByName("androidTest").java.srcDir("src/sharedTest/kotlin")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
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

// Robolectric acilirken conscrypt'i yukluyor, conscrypt de kutuphane adini
// VARSAYILAN yerel ayarla kucultuyor: tr-TR'de "Windows".lowercase() ->
// "wındows" (noktasiz i) ve paketteki "conscrypt_openjdk_jni-windows-x86_64"
// bulunamiyor, test UnsatisfiedLinkError ile duser. Test JVM'i bu yuzden
// Ingilizce yerel ayarda kosuyor - uygulamanin diliyle ilgisi yok.
tasks.withType<Test>().configureEach {
    jvmArgs("-Duser.language=en", "-Duser.country=US")
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

    // Robolectric'in NATIVE grafik kipi gercek Bitmap/Canvas/Shader kosturuyor;
    // stub android.jar bunlarin hepsinde "Stub!" atardi, yani duz JVM testi
    // FlameRenderer'i cagirmaya yetmiyor.
    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("org.robolectric:robolectric:4.14.1")

    androidTestImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}
