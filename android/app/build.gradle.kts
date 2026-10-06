import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// The google-services plugin fails the build without google-services.json,
// and that file is gitignored (the repository is public). So, exactly like
// the signing config above: wire it up only when it is usable. CI and a fresh
// clone still build, and Crashlytics starts working the moment the file is
// dropped in.
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.lifecycle(
        "google-services.json not found - Crashlytics is disabled for this " +
            "build. Download it from the Firebase console into android/app/."
    )
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// A signing config whose keystore is missing makes bundletool fail deep inside
// `signReleaseBundle` with a bare NullPointerException, which says nothing about
// the real problem. Decide up front whether release signing is usable.
fun keystoreValue(key: String): String? =
    (keystoreProperties[key] as String?)?.trim()?.takeIf { it.isNotEmpty() }

// Flutter's convention: a relative storeFile is resolved from android/app/,
// so `../keystore.jks` means android/keystore.jks.
val keystoreFile = keystoreValue("storeFile")?.let { path ->
    val candidate = File(path)
    if (candidate.isAbsolute) candidate else file(path)
}

val hasReleaseSigning = keystorePropertiesFile.exists() &&
    keystoreValue("keyAlias") != null &&
    keystoreValue("keyPassword") != null &&
    keystoreValue("storePassword") != null &&
    keystoreFile?.exists() == true

val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (releaseBuildRequested && !hasReleaseSigning) {
    val reason = when {
        !keystorePropertiesFile.exists() ->
            "android/key.properties topilmadi (u .gitignore da, shuning uchun repoda yo'q)."
        keystoreFile == null -> "key.properties ichida storeFile ko'rsatilmagan."
        keystoreFile.exists().not() ->
            "keystore fayli topilmadi: " + keystoreFile.absolutePath
        else -> "key.properties ichida keyAlias / keyPassword / storePassword to'liq emas."
    }
    throw GradleException(
        """
        Release qurilmasi imzolanmaydi: $reason

        android/key.properties quyidagicha bo'lishi kerak:
            storeFile=/absolute/path/to/upload-keystore.jks
            storePassword=...
            keyAlias=upload
            keyPassword=...

        Diqqat: Play Store'ga yangilanish yuborish uchun ilova birinchi marta
        qaysi kalit bilan imzolangan bo'lsa, o'sha kalit kerak. Yangi keystore
        yaratish faqat Play App Signing yoqilgan va yangi upload kalit
        ro'yxatdan o'tkazilgan holda ishlaydi.
        """.trimIndent()
    )
}

android {
    namespace = "com.nazorat.aat.uz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs on older Android
        // releases too; without desugaring the build fails.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nazorat.aat.uz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreValue("keyAlias")
                keyPassword = keystoreValue("keyPassword")
                storeFile = keystoreFile
                storePassword = keystoreValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Only wire it up when it is actually usable; an empty config is what
            // produced the NullPointerException in `signReleaseBundle`.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
