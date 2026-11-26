import com.vanniktech.maven.publish.AndroidSingleVariantLibrary

plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("com.vanniktech.maven.publish")
}

android {
  namespace = "com.swmansion.enriched.markdown.parser"
  compileSdk = 36
  ndkVersion = "27.1.12297006"

  defaultConfig {
    minSdk = 24
    consumerProguardFiles("consumer-rules.pro")

    externalNativeBuild {
      cmake {
        cppFlags += "-std=c++17"
        // fbjni shares C++ objects across the JNI library boundary.
        arguments += listOf("-DANDROID_STL=c++_shared", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
      }
    }
    ndk {
      abiFilters += (providers.gradleProperty("enrichedMarkdownArchitectures").orNull
        ?: "armeabi-v7a,arm64-v8a,x86,x86_64").split(",").map { it.trim() }
    }
  }

  buildFeatures { prefab = true }
  packaging {
    // fbjni's runtime AAR supplies these. Do not republish CMake's imported copies in this AAR.
    jniLibs.excludes += listOf("**/libc++_shared.so", "**/libfbjni.so")
  }
  externalNativeBuild {
    cmake {
      path = file("src/main/cpp/CMakeLists.txt")
      version = "3.22.1"
    }
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

kotlin { jvmToolchain(17) }

dependencies {
  // The JNI bridge uses fbjni's native and Java runtime, including in standalone hosts.
  implementation("com.facebook.fbjni:fbjni:0.7.0")
}

mavenPublishing {
  configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = true))
  coordinates(rootProject.group.toString(), property("POM_ARTIFACT_ID").toString(), rootProject.version.toString())
  publishToMavenCentral()
  val signingKey = providers.gradleProperty("signingInMemoryKey").orNull ?: providers.gradleProperty("signing.keyId").orNull
  if (!signingKey.isNullOrBlank()) signAllPublications()
}
