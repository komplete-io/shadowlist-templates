# EnrichedMarkdown Android provenance

- Upstream: https://github.com/software-mansion/enriched-markdown
- Commit: `27db9a7f8e13e485dc00064c4bcf16a7ea2daad2`
- License: MIT; upstream root license is copied as `LICENSE`. Source headers are preserved.
- Source: `packages/enriched-markdown-android/{parser,ui}/src/main` and their consumer rules.
- Omitted: `compose`, `math`, `code-highlight`, `display-benchmark`, upstream tests, examples,
  wrapper, publishing/formatting scripts and React Native packages. No symlinks are copied.
- Shared C++ comes from sibling `../enriched-markdown-core`, maintained separately as the
  upstream `packages/core/cpp` tree without tests/wasm. This package does not modify it.

## Local patches

1. Replaced upstream Groovy root/settings/module Gradle files with Kotlin DSL, using the existing
   ShadowList Android toolchain and Vanniktech publishing conventions. Added root/module Gradle
   properties. Publish `enriched-markdown-parser` and `enriched-markdown-ui` under `io.github.azimgd`
   at the templates' version, read from `../shadowlist-android-utils/ShadowListUtils/gradle.properties`.
   The publishing group comes from that same file's `GROUP`, and each artifact ID comes from its
   module's `POM_ARTIFACT_ID`. Release CI publishes parser, then UI, then ShadowListUtils using
   the existing signing credentials and `publishAndReleaseToMavenCentral` tasks.
   JitPack uses the same repository group/tag as `shadowlist-utils`. Retained upstream dependency
   versions; parser's fbjni is `implementation` rather than `compileOnly` so standalone consumers
   receive its Java runtime as well as native library. Exclude imported `libfbjni.so` and
   `libc++_shared.so` from the parser AAR instead of upstream's pick-first rule: fbjni's runtime AAR
   supplies them, preventing duplicate libraries in consuming apps. The locally cached fbjni 0.7.0
   AAR includes both and declares NDK 27 in its prefab ABI metadata. Retained `c++_shared` because fbjni shares
   C++ types across native libraries; enabled flexible page sizes for NDK 27.1. ShadowList's two
   existing native libraries retain their static runtimes.
2. `parser/src/main/cpp/CMakeLists.txt`: `CPP_ROOT` points to
   `../../../../../enriched-markdown-core` from the CMake directory. Source selection is unchanged:
   enrmrkd C, parser/repair C++, language display names, LaTeX speech and JNI. Language names and
   speech are self-contained helpers, not tree-sitter or a math renderer; no generated assets are
   needed. C++17 and C11 are retained; Gradle pins CMake 3.22.1.
3. `parser/src/main/java/com/swmansion/enriched/markdown/parser/Parser.kt`,
   `parser/src/main/cpp/jni/{JavaTypes.h,ParserJni.cpp}`: optional `streaming` argument crosses JNI.
   Before parsing partial input, call upstream `streamingSnapshot` with the same parser flags and
   default progressive block modes. Its filter/repair affects the unfinished tail. Mark the trailing
   open top-level code block with a `streaming` AST attribute so copy chrome waits for closure.
   The pinned upstream standalone Android UI **does not call StreamingSession**; this bridge adds
   that missing path. Each update prepares a snapshot and parses it; this is not DocumentStore
   incremental AST parsing, pacing or per-word animation.
4. `ui/src/main/java/com/swmansion/enriched/markdown/EnrichedMarkdown.kt`: add `setStreaming` and
   `onContentRendered`; snapshot streaming state with each cancellable asynchronous render and
   invoke the callback after the latest segments are applied on the UI thread. Clear the added
   state on reuse. Existing segment reconciliation and accessibility implementation are retained.
5. `ui/src/main/java/com/swmansion/enriched/markdown/styles/CodeBlockStyle.kt`: optional localized
   copy/copied/fallback-language labels, with defaults preserving upstream behavior.
6. `ui/src/main/java/com/swmansion/enriched/markdown/segments/CodeBlockContainerView.kt`: consume
   those labels; suppress copy and long-press menus for an open streaming fence; show a checkmark
   and announce copied feedback for 1500 ms; reset feedback on detach or segment update. Avoid
   an active touch delegate for hidden copy chrome. Clipboard writing remains upstream's code.

All other upstream main-source files and both consumer rule files are byte-for-byte copies.
Math/highlighting remain disabled through upstream's optional plugin seams; no plugin is installed.

## Toolchain audit (source inspection only)

Compared with `packages/shadowlist-android-utils/{build.gradle.kts,settings.gradle.kts,gradle.properties,
ShadowListUtils/build.gradle.kts,gradle/wrapper/gradle-wrapper.properties}` and the corresponding
files under `../shadowlist/packages/shadowlist-android` / `ShadowListKit`.
Neither ShadowList build has a Gradle version catalog. Both declare the same versions below.

| Location / setting                         | Upstream                              | Vendored / ShadowList                           |
| ------------------------------------------ | ------------------------------------- | ----------------------------------------------- |
| Root `settings.gradle`, AGP plugin         | 9.2.1                                 | 8.12.0, root Kotlin DSL plugin block            |
| Root `build.gradle`, Kotlin classpath      | 2.4.0                                 | explicit Kotlin Android plugin 2.1.20           |
| `parser/build.gradle`, `ui/build.gradle`   | AGP 9 implicit Kotlin support         | explicitly apply `org.jetbrains.kotlin.android` |
| Root `build.gradle`, NDK                   | 28.2.13676358                         | 27.1.12297006                                   |
| `gradle/wrapper/gradle-wrapper.properties` | Gradle 9.5.1                          | use existing ShadowListUtils wrapper 9.3.1      |
| Root Android SDK declarations              | compile/target/build tools 36, min 24 | compile 36, min 24; build tools chosen by AGP   |
| Module Java compatibility                  | 11                                    | 17, plus Kotlin JVM toolchain 17                |
| Parser CMake minimum                       | 3.13, no Gradle version pin           | same minimum, Gradle pins 3.22.1                |
| Publishing/lint root configuration         | nmcp 1.4.4, ktlint 14.1.0             | Vanniktech 0.35.0; upstream scripts omitted     |

These are all newer upstream build declarations affecting the included modules. Inspection found
no retained Kotlin syntax, standard-library call, C++ feature or unguarded Android API that requires
Kotlin 2.4, AGP 9, NDK 28.2 or a minSdk above 24. This is not a compilation guarantee. Kotlin
ArrayDeque operations are Kotlin APIs (not Android 35 List additions). Newer Android APIs in the
UI are guarded. AndroidX appcompat 1.7.0/core-ktx 1.15.0 and OkHttp 4.12.0 are retained.
SDK 36, NDK 27.1 and CMake 3.22.1 directories exist locally; nothing was executed from them.
The omitted Compose and benchmark plugin declarations were not migrated.

## Dependencies

- **fbjni 0.7.0:** required by the parser's native JavaClass/collection conversion, method
  registration and JNI initialization. The UI depends on the parser. Dropping it requires
  rewriting the JNI bridge; retained, including its Java runtime and shared C++ runtime.
- **AndroidX:** appcompat widgets, core graphics/view helpers and accessibility support including
  `ExploreByTouchHelper` (transitive customview). These are used by base text, code, tables and
  screen-reader support. Retained; replacing only appcompat widgets would not remove AndroidX.
- **OkHttp 4.12.0:** only `utils/text/ImageDownloader.kt` imports it. Base parsing, text, lists,
  code and tables do not need HTTP. It could be removed with a localized replacement of that
  downloader (preserving callbacks, decoding and caches), or by disabling remote images. Retained
  to preserve upstream image behavior. Hosts still declare INTERNET for remote images.

## ShadowList integration and edited existing files

Paths below are under `packages/shadowlist-android-utils` unless noted otherwise.

- `settings.gradle.kts`: included build and explicit parser/UI Maven dependency substitutions,
  following the sibling ShadowListKit build pattern.
- `ShadowListUtils/build.gradle.kts`: implementation dependency on the vendored UI's release or
  JitPack coordinates. The public ShadowListUtils API does not expose EnrichedMarkdown types.
- `README.md`: native runtime/dependency changes, publication command and asynchronous sizing.
- `ShadowListUtils/src/main/java/com/shadowlist/utils/assistant/ShadowListUtilsAssistantMarkdown.kt`:
  retain the public API and streaming dot; host a persistent upstream document view. It replaces
  hand-built spans and parser blocks with `EnrichedMarkdown`, options, callbacks, measured heights and safe
  default link opening. Custom handlers still receive the original href. Code copy also writes
  the system clipboard. Selection and semantic accessibility come from the upstream view.
- `ShadowListUtilsAssistantReplyMessage.kt`: use measured upstream document heights, with an
  estimate until rendering completes; forward height changes.
- `ShadowListUtilsAssistantRow.kt`, `ShadowListUtilsAssistantRowView.kt`,
  `ShadowListUtilsAssistantList.kt`: carry height-change callbacks and per-row revisions;
  invalidate only that row's cached layout and rebuild its list entry.
- `ShadowListUtils/src/androidTest/java/com/shadowlist/utils/AssistantMarkdownTest.kt`: migrate
  existing rendering/copy tests to attached asynchronous views and completion latches; retain
  the legacy parser's embedded-NUL test. Tests were edited but not run.
- Repository-root `jitpack.yml`: publish both included-build AARs before publishing ShadowListUtils;
  without this its POM would reference unpublished template artifacts. Existing SDK/NDK/CMake
  installation commands remain sufficient.

New integration files in that assistant folder:
`ShadowListUtilsAssistantMarkdownStyle.kt` centralizes theme colors, font sizes/weights/line heights,
spacing, selection and copy labels; `ShadowListUtilsAssistantMarkdownHeights.kt` holds a 2 MiB
thread-safe cache of scalar measurements. Layout prefetch never creates Views or shares mutable
spans. A plain-text estimate can cause an initial size correction; async image sizes also correct
rows. Upstream StyleConfig has no tracking token, so custom theme letter spacing is not mapped.
Code headers use upstream's secondary tint derived from the code text color.

The legacy core Markdown reader (`packages/shadowlist-utils-core/MarkdownDocument.*`), its JNI and
the Kotlin bridge models are removed. URL policy (`SafeUrl.*`) and reply/tool segmentation continue
using their existing shared-core helpers.

## Verification still required

Only file comparisons, source searches and whitespace/diff inspection were performed. No Gradle,
compiler, tests, package manager, build or network command was run.

First command, from repository root:

```sh
cd packages/shadowlist-android-utils && ./gradlew :ShadowListUtils:assembleDebug
```

Then validate instrumentation tests, streaming inline/fence/table repair, copy/links/TalkBack,
RTL/font scaling, image-driven size changes, row reuse and follow-appends on a device. Also verify
release/R8 JNI loading, 16 KiB native alignment, shared runtime packaging, Gradle substitution and
published POM/module dependencies. Publish all three AARs for Maven Central as well as JitPack:

```sh
./gradlew :enriched-markdown-android:parser:publishToMavenLocal :enriched-markdown-android:ui:publishToMavenLocal :ShadowListUtils:publishToMavenLocal
```
