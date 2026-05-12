import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Загружаем значения из local.properties (там лежат пути к SDK и версии)
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

// Локальная release-подпись не хранится в git.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStorePassword = keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
val yandexMapKitApiKey =
    localProperties.getProperty("YANDEX_MAPKIT_API_KEY")
        ?: providers.environmentVariable("YANDEX_MAPKIT_API_KEY").orNull
        ?: ""
val escapedYandexMapKitApiKey = yandexMapKitApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val yandexSuggestApiKey =
    localProperties.getProperty("YANDEX_SUGGEST_API_KEY")
        ?: providers.environmentVariable("YANDEX_SUGGEST_API_KEY").orNull
        ?: ""
val escapedYandexSuggestApiKey = yandexSuggestApiKey
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")

android {
    namespace = "ru.hozyainbarin.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    signingConfigs {
        create("release") {
            if (releaseStoreFile.isNotEmpty()) {
                storeFile = file(releaseStoreFile)
            }
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "ru.hozyainbarin.app"
        // YooKassa Flutter plugin requires minSdkVersion 24+
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName

        // Scheme for YooKassa/SBP return-to-app flows (used by YooKassa SDK)
        resValue("string", "ym_app_scheme", "yookassapaymentsflutter")
        manifestPlaceholders["YANDEX_MAPKIT_API_KEY"] = yandexMapKitApiKey
        buildConfigField(
            "String",
            "YANDEX_MAPKIT_API_KEY",
            "\"$escapedYandexMapKitApiKey\""
        )
        buildConfigField(
            "String",
            "YANDEX_SUGGEST_API_KEY",
            "\"$escapedYandexSuggestApiKey\""
        )
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("com.yandex.android:maps.mobile:4.4.0-full")
}
