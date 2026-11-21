# Code style

The engine's [code style](https://github.com/azimgd/shadowlist/blob/main/docs/code-style.md) holds the shared language-level rules: naming, the public API words, C++, Objective-C and Swift, Kotlin and Java, JNI, comments and structure. They apply here too. This document adds the rules for template code: `packages/shadowlist-utils`, `packages/shadowlist-utils-core`, `packages/shadowlist-uikit-utils`, `packages/shadowlist-android-utils`, `packages/shadowlist-wasm-utils` and the apps in `examples/`.

## Naming

| Package                                              | Prefix                                                                                                                                                                                        |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shadowlist-uikit-utils`, `shadowlist-android-utils` | `ShadowListUtils` for every type, in Swift too. Objective-C constants take `SHADOWLIST_UTILS_`. Kotlin constants sit unprefixed in their class. The JNI macro is `SHADOWLIST_UTILS_JNI(name)` |

Entry points sit in one `extern "C"` block and use one macro per class (`SHADOWLIST_UTILS_JNI(name)`), as in the engine.

## Public API words

The template rows of the engine's Public API words table, with the same columns. The engine's table has the kit and Fabric words they build on.

| Concept                | Word                          | Objective-C                                                                                                                                              | Kotlin                                                                                                             | Fabric (JS)                                                                                                   |
| ---------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| Activity header        | `ActivityHeader`              | `ShadowListUtilsActivityHeader` with typed `ShadowListUtilsActivityHeaderAction`                                                                         | `ShadowListUtilsActivityHeader` with typed `ShadowListUtilsActivityHeaderAction`                                   | `ActivityHeader`, `ActivityHeaderAction`                                                                      |
| Chat composer          | `ChatInput`                   | `ShadowListUtilsChatInput` (`value`, `onChangeText`, `onSend`, `disabled`, `maxLength`, `labels`)                                                        | `ShadowListUtilsChatInput` with the same members                                                                   | `ChatInput` with controlled `value` or initial `defaultValue`                                                 |
| Drag between lists     | `DragBoard`                   | —                                                                                                                                                        | —                                                                                                                  | ShadowListUtils `Board.List` `onMoveItem(BoardMoveInfo)` (`sourceColumnKey`, `destinationColumnKey`)          |
| Row model              | `ShadowListUtilsRow`          | iOS templates `ShadowListUtilsRow` (`key`, `contentVersion`, `viewClass`, `reuseIdentifier`, `layout(width:)`)                                           | Android templates `ShadowListUtilsRow` (`key`, `contentVersion`, `reuseIdentifier`, `makeView`, `layout(widthPx)`) | —                                                                                                             |
| Template icons         | `<Name>Icon`                  | iOS templates `ShadowListUtilsCopyIcon`, `DocIcon`, `FolderIcon`, `PlusIcon`, `RetryIcon` (`image(size:strokeWidth:)`, a template image the tint colors) | Android templates the same five as a `Drawable` (`color`, `size`, `strokeWidth`)                                   | ShadowListUtils `CopyIcon`, `DocIcon`, `FolderIcon`, `PlusIcon`, `RetryIcon` (`size`, `color`, `strokeWidth`) |
| Text style on a widget | `applyTo`, `attributedString` | iOS templates `ShadowListUtilsTextStyle.attributedString(_:color:weight:alignment:lineBreakMode:)` for a `UILabel`                                       | Android templates `ShadowListUtilsTextStyle.applyTo(view, color, weight)` for a `TextView`                         | —                                                                                                             |

- A new public concept gets one row here before it ships on any platform.
- A rename moves every caller in the same change and leaves no alias.

## C++

- Text crosses into `packages/shadowlist-utils-core` as UTF-8 in a `std::string_view`. A function that counts UTF-16 code units, as JS, `NSString` and Java strings do, says `Utf16` in its name.

## Template logic tests

- Every change in `packages/shadowlist-utils-core` comes with a test in `packages/shadowlist-utils-core-tests`.
- Test names are sentences in `snake_case` that state the behavior.
- Template logic tests go in `tests_utils_*.cpp`, in the file of their area.
- A template function with a twin in TypeScript shares a vector file with it in `packages/shadowlist-utils-core-tests/vectors`: an array of cases, each a `name`, an `input` and the `output` both sides must give, with a `function` where a file holds more than one. `tests_utils_vectors.cpp` replays each file through the C++ in a `VECTOR_TEST`, and `packages/shadowlist-utils/src/native/__tests__/vectors.test.ts` replays it through one loader, `packages/shadowlist-utils/src/native/__fixtures__/vectors.ts`. A file in the folder without a replay fails on both sides, as does a case that names a function without one and, in C++, an output field no check reads. `UPDATE_VECTORS=1 yarn test` writes the outputs from the TypeScript, after a change both sides make, and then replays them. `theme.json` holds the tokens of the TypeScript themes for the templates' tests on each platform.
- A fuzz test is named `fuzz_...` and runs its seeds through `forEachFuzzSeed` from `FuzzHelpers.hpp`. It draws through `pickInt`, `pickSize`, `chance` and the other picks there, never through a distribution of `<random>`.
- Helpers shared by test files live in `<Area>Helpers.hpp`: `FuzzHelpers.hpp`, `VectorHelpers.hpp` and `UtilsVectorHelpers.hpp` for the vector files.

## Native templates

`shadowlist-uikit-utils` and `shadowlist-android-utils` are one design in two languages, like the kits they build on. A change in one lands in the other in the same change with the same names, or the change notes why not. The same logic carries the same comment wording in both.

- Tests: the UIKit templates' tests are in `packages/shadowlist-uikit-utils/Tests`, run with `xcodebuild test` on a simulator, and the Android templates' in `packages/shadowlist-android-utils/ShadowListUtils/src/androidTest` on a device. Both suites hold the same tests under the same sentences.

## Structure

Logic the templates share, like a chat bubble's insets, an avatar's color or the Markdown of a reply, goes in `packages/shadowlist-utils-core`. It builds without the engine's `host/*.cpp` and the core's own sources, and includes only their headers. Its sources are `SHADOWLIST_UTILS_SOURCES` in `packages/shadowlist-utils-core/sources.cmake`, which the templates libraries and the template logic tests compile. The engine's base kits and Fabric package do not compile them. `shadowlist-wasm-utils` compiles them into its own utility binary, separate from the engine's list binary.

The functions in `packages/shadowlist-utils-core` are the C++ side of templates that also run in TypeScript, and the vector files hold each one equal to its TypeScript twin. The UIKit and Android templates call `avatarColorIndex`, `avatarInitials`, `avatarInitialsMetrics`, `chatMessageSizeSpec`, `feedSingleImageFrame`, `relativeTime`, `relativeTimeHasDate`, `sectionInitial`, `pollTally` and `pollPercent` today. The wasm utilities call the avatar, relative-time and poll helpers for the web Feed and Poll examples. The AppKit example uses the existing platform-neutral bridge for avatar colors, initials and contact section initials. Native Tree templates use the engine's shared `TreeSource` and `TreeRows`; Board templates use the shared board layout and `planBoardMove`. Native Assistant templates use the shared Markdown parser, link policy, `assistantUserMessageSizeSpec` and `stepsOf`; the reply segmentation shares vectors with the React Native view. `groupContactsIntoSections` and `lengthUtf16` have no caller outside the tests yet. They stay, with their vectors, for the templates that move to them.

## Repo

- Example apps and demo screens live in `examples/`. ShadowListUtils is `packages/shadowlist-utils` in TypeScript, `packages/shadowlist-uikit-utils` in Swift and `packages/shadowlist-android-utils` in Kotlin. Its shared C++ is `packages/shadowlist-utils-core`.
- Everything builds against the engine checkout at `SHADOWLIST_ROOT`, by default `../shadowlist`.

## Checklist before you finish

- Template logic changed: a new test, and `yarn test:core` passes. CI runs the template logic tests under ThreadSanitizer too, without the fuzz tests.
- Native templates changed: the other platform has the same change, and the example apps that use them build.
- TypeScript changed: `yarn typecheck`, `yarn test` and `yarn lint` pass.
- Always: `yarn format:check` passes, as CI checks it.
- A new or renamed public word has its row in the Public API words table.
