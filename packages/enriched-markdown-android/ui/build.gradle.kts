import com.vanniktech.maven.publish.AndroidSingleVariantLibrary

plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("com.vanniktech.maven.publish")
}

android {
  namespace = "com.swmansion.enriched.markdown.ui"
  compileSdk = 36
  ndkVersion = "27.1.12297006"

  defaultConfig {
    minSdk = 24
    consumerProguardFiles("consumer-rules.pro")
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

kotlin { jvmToolchain(17) }

dependencies {
  api(project(":parser"))
  implementation("androidx.appcompat:appcompat:1.7.0")
  implementation("androidx.core:core-ktx:1.15.0")
  implementation("com.squareup.okhttp3:okhttp:4.12.0")
}

mavenPublishing {
  configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = true))
  coordinates(rootProject.group.toString(), property("POM_ARTIFACT_ID").toString(), rootProject.version.toString())
  publishToMavenCentral()
  val signingKey = providers.gradleProperty("signingInMemoryKey").orNull ?: providers.gradleProperty("signing.keyId").orNull
  if (!signingKey.isNullOrBlank()) signAllPublications()
}
