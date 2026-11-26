pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
  }
}

rootProject.name = "shadowlist-android-utils"

/*
 * The engine checkout: the SHADOWLIST_ROOT environment variable, then the Gradle property of the
 * same name, then ../shadowlist beside this repo. A relative value resolves against this repo's
 * root. The build reads the kit project and the core headers from it.
 */
val templatesRoot = settingsDir.resolve("../..").canonicalFile
val shadowlistRoot = (System.getenv("SHADOWLIST_ROOT")?.takeIf { it.isNotBlank() }
  ?: providers.gradleProperty("SHADOWLIST_ROOT").orNull?.takeIf { it.isNotBlank() }
  ?: "../shadowlist").let { templatesRoot.resolve(it).canonicalFile }
if (!shadowlistRoot.resolve("packages/shadowlist-android/settings.gradle.kts").isFile) {
  throw GradleException(
    "The shadowlist engine checkout was not found at $shadowlistRoot. Clone " +
      "https://github.com/azimgd/shadowlist there, or set SHADOWLIST_ROOT (environment variable " +
      "or Gradle property) to its folder. SHADOWLIST_ENGINE_REF in ShadowListUtils/gradle.properties names the " +
      "engine ref that published builds use.",
  )
}
gradle.extra["shadowlistRoot"] = shadowlistRoot

/*
 * ShadowListKit builds from the engine checkout. Its coordinates resolve to that project instead
 * of Maven Central. The published POM keeps the kit's Maven coordinates.
 */
includeBuild(shadowlistRoot.resolve("packages/shadowlist-android")) {
  dependencySubstitution {
    substitute(module("io.github.azimgd:shadowlist-kit")).using(project(":ShadowListKit"))
  }
}

// Keep Maven coordinates in publications while building the vendored native renderer locally.
includeBuild("../enriched-markdown-android") {
  dependencySubstitution {
    val markdownGroup = if (System.getenv("JITPACK") == "true") {
      "${System.getenv("GROUP") ?: "com.github.komplete-io"}.${System.getenv("ARTIFACT") ?: "shadowlist-templates"}"
    } else "io.github.azimgd"
    substitute(module("$markdownGroup:enriched-markdown-ui")).using(project(":ui"))
    substitute(module("$markdownGroup:enriched-markdown-parser")).using(project(":parser"))
  }
}

include(":ShadowListUtils")
