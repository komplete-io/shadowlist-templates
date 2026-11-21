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

rootProject.name = "shadowlist-android-example"

/*
 * The engine checkout: the SHADOWLIST_ROOT environment variable, then the Gradle property of the
 * same name, then ../shadowlist beside this repo. A relative value resolves against this repo's
 * root. The kit project, its Bench sources and the core headers come from it.
 */
val templatesRoot = settingsDir.resolve("../..").canonicalFile
val shadowlistRoot = (System.getenv("SHADOWLIST_ROOT")?.takeIf { it.isNotBlank() }
  ?: providers.gradleProperty("SHADOWLIST_ROOT").orNull?.takeIf { it.isNotBlank() }
  ?: "../shadowlist").let { templatesRoot.resolve(it).canonicalFile }
if (!shadowlistRoot.resolve("packages/shadowlist-android/settings.gradle.kts").isFile) {
  throw GradleException(
    "The shadowlist engine checkout was not found at $shadowlistRoot. Clone " +
      "https://github.com/azimgd/shadowlist there, or set SHADOWLIST_ROOT (environment variable " +
      "or Gradle property) to its folder.",
  )
}
gradle.extra["shadowlistRoot"] = shadowlistRoot

include(":ShadowListKit")
project(":ShadowListKit").projectDir = shadowlistRoot.resolve("packages/shadowlist-android/ShadowListKit")
include(":ShadowListUtils")
project(":ShadowListUtils").projectDir = file("../../packages/shadowlist-android-utils/ShadowListUtils")
include(":app")

/*
 * ShadowListUtils depends on the kit by its published coordinates. Inside this build they
 * resolve to the kit project beside it.
 */
gradle.beforeProject {
  configurations.configureEach {
    resolutionStrategy.dependencySubstitution {
      substitute(module("io.github.azimgd:shadowlist-kit")).using(project(":ShadowListKit"))
    }
  }
}
