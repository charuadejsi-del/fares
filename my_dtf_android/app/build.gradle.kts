plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.serialization")
    kotlin("plugin.compose")
}

// Configuration d'une installation (atelier) : -Pmydtf.xxx=... ou variables d'environnement MYDTF_XXX,
// sinon valeurs de l'atelier d'origine. Aucune modification du code n'est nécessaire.
fun cfg(key: String, def: String): String =
    (project.findProperty("mydtf.$key") as String?) ?: System.getenv("MYDTF_" + key.uppercase()) ?: def
val cfgSupabaseUrl = cfg("supabaseUrl", "https://pxifieuohgthtqkwasug.supabase.co")
val cfgAnonKey = cfg("anonKey", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k")
val cfgAppName = cfg("appName", "My DTF")
val cfgAppId = cfg("appId", "com.mydtf")
val cfgAdminUrl = cfg("adminUrl", "mydtf-admin.pages.dev")

android {
    namespace = "com.mydtf.client"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.mydtf.client"
        minSdk = 26
        targetSdk = 35
        versionCode = (System.getenv("BUILD_NUMBER") ?: "1").toInt()
        versionName = "1.2." + (System.getenv("BUILD_NUMBER") ?: "0")
        buildConfigField("String", "SUPABASE_URL", "\"$cfgSupabaseUrl\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"$cfgAnonKey\"")
        buildConfigField("String", "ADMIN_URL", "\"$cfgAdminUrl\"")
        buildConfigField("String", "APP_NAME", "\"$cfgAppName\"")
    }

    signingConfigs {
        // Clé de signature stable fournie par le CI (secret), sinon clé debug.
        val ks = System.getenv("MYDTF_KEYSTORE")
        if (ks != null && file(ks).exists()) {
            create("release") {
                storeFile = file(ks)
                storePassword = System.getenv("MYDTF_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("MYDTF_KEY_ALIAS")
                keyPassword = System.getenv("MYDTF_KEY_PASSWORD")
            }
        }
    }

    // Deux applications à partir du même code : « My DTF » (clients) et « My DTF Pro » (équipe).
    flavorDimensions += "app"
    productFlavors {
        create("client") {
            dimension = "app"
            applicationId = "$cfgAppId.client"
            resValue("string", "app_name", cfgAppName)
            buildConfigField("boolean", "ADMIN", "false")
        }
        create("pro") {
            dimension = "app"
            applicationId = "$cfgAppId.pro"
            resValue("string", "app_name", "$cfgAppName Pro")
            buildConfigField("boolean", "ADMIN", "false")
        }
        create("admin") {
            dimension = "app"
            applicationId = "$cfgAppId.admin"
            resValue("string", "app_name", "$cfgAppName Admin")
            buildConfigField("boolean", "ADMIN", "true")
        }
    }
    // Code commun aux applications de l'équipe et de l'administrateur.
    sourceSets {
        getByName("pro").java.srcDir("src/team/java")
        getByName("admin").java.srcDir("src/team/java")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1,INDEX.LIST,DEPENDENCIES}" }
}

dependencies {
    implementation(project(":core"))

    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")

    implementation(platform("io.github.jan-tennert.supabase:bom:3.0.3"))
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.ktor:ktor-client-okhttp:3.0.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    implementation("io.coil-kt:coil-compose:2.7.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
