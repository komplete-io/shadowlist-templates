import java.util.Properties

plugins {
  id("com.android.library") version "8.12.0" apply false
  id("org.jetbrains.kotlin.android") version "2.1.20" apply false
  id("com.vanniktech.maven.publish") version "0.35.0" apply false
}

// The vendored artifacts release with ShadowListUtils, under this repository's coordinates.
val templates = Properties().apply {
  file("../shadowlist-android-utils/ShadowListUtils/gradle.properties").inputStream().use { load(it) }
}
val jitpack = System.getenv("JITPACK") == "true"
allprojects {
  group = if (jitpack) {
    "${System.getenv("GROUP") ?: "com.github.komplete-io"}.${System.getenv("ARTIFACT") ?: "shadowlist-templates"}"
  } else templates.getProperty("GROUP")
  version = if (jitpack) System.getenv("VERSION") ?: templates.getProperty("VERSION_NAME") else templates.getProperty("VERSION_NAME")
}
