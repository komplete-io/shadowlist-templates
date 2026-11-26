import com.vanniktech.maven.publish.AndroidSingleVariantLibrary

plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("com.vanniktech.maven.publish")
}

val shadowlistRoot = gradle.extra["shadowlistRoot"] as File

android {
  namespace = "com.shadowlist.utils"
  compileSdk = 36
  ndkVersion = "27.1.12297006"

  defaultConfig {
    minSdk = 24
    consumerProguardFiles("consumer-rules.pro")
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    externalNativeBuild {
      cmake {
        /*
         * The C++ runtime links statically. The AAR ships one .so and works next to libraries that
         * bring their own libc++_shared.so. Flexible page sizes align it for 16 KB page devices.
         */
        arguments += listOf("-DANDROID_STL=c++_static", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
        // The engine checkout that settings.gradle.kts found. CMake reads the core headers from it.
        arguments += "-DSHADOWLIST_ROOT=${shadowlistRoot.invariantSeparatorsPath}"
      }
    }
  }

  externalNativeBuild {
    cmake {
      path = file("src/main/cpp/CMakeLists.txt")
      version = "3.22.1"
    }
  }

  testOptions {
    // Only the instrumentation APK targets the current SDK. A legacy target shows a system
    // compatibility dialog that prevents real Activity focus and native clipboard acceptance.
    targetSdk = 36
  }

  sourceSets {
    // The tests replay the template vector files the core tests and the TypeScript tests share.
    getByName("androidTest").assets.srcDir("../../shadowlist-utils-core-tests/vectors")
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

kotlin {
  jvmToolchain(17)
}

dependencies {
  // api because the template lists subclass ShadowListKitListView publicly.
  // The kit releases from the engine repo with its own version.
  api("io.github.azimgd:shadowlist-kit:${property("SHADOWLIST_KIT_VERSION")}")
  val markdownGroup = if (System.getenv("JITPACK") == "true") {
    "${System.getenv("GROUP") ?: "com.github.komplete-io"}.${System.getenv("ARTIFACT") ?: "shadowlist-templates"}"
  } else "io.github.azimgd"
  val markdownVersion = if (System.getenv("JITPACK") == "true") {
    System.getenv("VERSION") ?: property("VERSION_NAME").toString()
  } else property("VERSION_NAME").toString()
  implementation("$markdownGroup:enriched-markdown-ui:$markdownVersion")
  // The tests run on a device or an emulator. They load the native core.
  androidTestImplementation("androidx.test:runner:1.6.2")
  androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

/*
 * JitPack publishes under its own group with the tag as the version.
 */
val jitpack = System.getenv("JITPACK") == "true"

mavenPublishing {
  configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = true))
  if (jitpack) {
    coordinates(
      groupId = "${System.getenv("GROUP") ?: "com.github.komplete-io"}.${System.getenv("ARTIFACT") ?: "shadowlist-templates"}",
      artifactId = property("POM_ARTIFACT_ID").toString(),
      version = System.getenv("VERSION") ?: property("VERSION_NAME").toString(),
    )
  }
  publishToMavenCentral()
  // Signing needs a key. Without one, publishToMavenLocal still works and Maven Central refuses the upload.
  val signingKey = providers.gradleProperty("signingInMemoryKey").orNull ?: providers.gradleProperty("signing.keyId").orNull
  if (!signingKey.isNullOrBlank()) {
    signAllPublications()
  }
}
