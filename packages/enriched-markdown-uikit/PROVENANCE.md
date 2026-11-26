# Provenance and integration notes

- Upstream: https://github.com/software-mansion/enriched-markdown
- Commit: `27db9a7f8e13e485dc00064c4bcf16a7ea2daad2`
- Sources: `packages/enriched-markdown-ios/Sources/EnrichedMarkdown` and `cpp/`.
- License: upstream MIT `LICENSE`, with original source notices retained.
- Omitted: the LaTeX, syntax-highlighting and tree-sitter targets, optional sources/assets,
  tests, benchmarks, examples, scripts, package-manager metadata and upstream manifest.
  Nothing was copied from the React Native package.
- Upstream `core/` symlinks were not copied. Root manifests point directly to
  `../enriched-markdown-core` instead. No external symlinks remain.

## Every local upstream patch

1. `Parser/MarkdownParserBridge.swift`: make `convertNode` module-internal so the separate
   UIKit bridge can reuse the existing AST conversion. Read node content with an explicit
   byte length, preserving content after embedded NULs in the new length-aware input path.
2. `Views/MarkdownTextView.swift`: add `onAttachmentLayoutChange` and invoke it after upstream
   attachment invalidation, letting a UIKit list invalidate its cached row height.
   Paths above are relative to `Sources/EnrichedMarkdown`. All other copied content is unchanged.

## Additions

- `cpp/SwiftStreamingCAPI.h`, `cpp/SwiftStreamingShim.cpp`: a length-aware C boundary around
  upstream `DocumentStore.snapshot` / `parse`, retaining a parsed document and reporting
  shared leading blocks. Snapshot uses `StreamingSession` filtering and repair; math is disabled.
- `Parser/UIKitStreamingDocument.swift`: own that handle, retain converted finished AST blocks,
  and decode the repaired source. This is confined to the main-thread UIKit owner.
- `Views/EnrichedMarkdownView.swift`: public, selectable UIKit entry taking markdown, parsing
  options, style, streaming state, link/copy callbacks and fitting width. It retains the upstream
  text view/delegate and valid text selection, and exposes image-driven height invalidation.
  Installs upstream-equivalent spoiler reveal handling and reapplies revealed ordinals after
  style changes, append-only streaming updates and completion. Replacement text or changed
  parsing options clears reveal state; newly appended spoilers remain concealed.
- Root `Package.swift` and `EnrichedMarkdown{,CppShim}.podspec`: the original module names,
  C++20 (repository convention), UTF-8 define, core include paths and iOS-only Swift product.
  CocoaPods compiles the core into the C shim pod and sets a package name for upstream Swift 5.9
  `package` access. No optional-feature defines, binary targets or asset fetches are used.

## ShadowListUtils integration and behavior

The assistant uses one retained native document per text/tool step. Its existing public Swift
properties and callbacks are retained. `ShadowListUtilsAssistantMarkdownStyle` maps theme fonts,
colors, line heights, spacing, code, tables, lists and quotes for drawing and measurement.
The upstream parser accepts GFM; grammar and layout therefore differ from the old handwritten
blocks. Code panels use upstream's icon and native copy/menu behavior, including copying a
currently visible partial fence, rather than the former closing-fence gate and timed Copied label.
The existing localized copy-code accessibility label is forwarded. Rich VoiceOver navigation
and native selection come from upstream. Custom link callbacks now receive the upstream URL's
absolute string; direct `open` calls retain their original string. The existing safe-URL default
opener remains in place. Reply-wide copy/share still receive the application's original content.

Incrementality: the view, delegate, C++ finished parse nodes and converted leading AST blocks
are retained. Attributed rendering/source annotation and TextKit reflow still process the full
snapshot, matching upstream's renderer; this is not a fully incremental text-layout engine.
Synchronous UIKit fitting is used both by standalone views and row measurement. Assistant rows
opt out of background prefetch via an internal marker protocol; other rows retain their existing
prefetch behavior. Image-driven size changes invalidate the list layout cache. This trades
background reply typesetting for matching UIKit rendering and measurement; profile long streams.

The legacy core Markdown reader (`MarkdownDocument.*`) and its Objective-C++ bridge are removed.
URL policy (`SafeUrl.*`) and `stepsOf` continue through the existing core bridge.

## macOS / AppKit scope (not implemented)

The root package still declares iOS 16 and macOS 14. `ShadowListUtilsCore` remains available to
macOS. `EnrichedMarkdown` is an iOS-only product: its sources are plain UIKit code with no
platform guards, so the target does not compile for macOS. The root manifest keeps it out of
macOS builds through iOS conditions on the dependency edges (`ShadowListUtils` to
`EnrichedMarkdown`, `EnrichedMarkdown` to its shim); both podspecs declare iOS only. The portable
C/C++ core and shim contain no UIKit. AppKit clients select `ShadowListUtilsCore`; a macOS build
that names `EnrichedMarkdown` or `ShadowListUtils` directly, or builds every target, fails.

The copied base module has 103 files directly importing UIKit, approximately 11,979 upstream
lines (inventory below). This is affected source size, not a rewrite estimate. An AppKit port needs:

- `MarkdownTextView.swift` (567 lines) and `MarkdownTextViewRepresentable.swift` (247): an
  `NSTextView`/TextKit host, `NSViewRepresentable`, fitting/invalidation, native selection, pointer
  hit testing, URL actions, menus, scrolling and `NSPasteboard` integration.
- Attachment providers and hosted panels: `CodeBlockAttachmentView.swift` (368),
  `TableAttachmentView.swift` (310), `MarkdownImageAttachment.swift` (359), plus code/table/rule
  attachment models. Replace UIKit view providers, scrolling panels, image drawing and image cache
  types; retain parser and model calculations where independent of UIKit.
- `Views/Layout/*`, spoiler overlays and decorations: replace UIView/CALayer placement,
  UIBezierPath drawing, UIKit gesture recognizers and enclosing-scroll observation with AppKit
  equivalents. Preserve selection geometry and RTL behavior.
- `Accessibility/*`: replace UIAccessibility elements, traits, custom actions and rotors with
  NSAccessibility semantics; test headings, links, lists, tables and code actions with VoiceOver.
- Theme/style/rendering/extraction: abstract UIFont, UIColor, UIImage, trait collections,
  text scaling, screen scale, layout direction and attributed-string font/color handling.
  `ThemeResolver.swift` alone is 332 lines; `MarkdownSourceSlicer.swift` (584),
  `MarkdownExtractor.swift` (544) and `MarkdownHTMLGenerator.swift` (525) also import UIKit.
- A separate AppKit product and adapter, plus AppKit measurement, interaction, selection/copy,
  streaming and accessibility validation. The C/C++ parser, repair and new C boundary are reusable.

## Verification status

Only source inspection, byte comparison, file inventories and diff review were performed.
No build, compile, test, package install, pod install, dependency resolution, or network call ran.
Swift/C++ interoperability, SwiftPM/CocoaPods integration, linking, runtime layout, selection,
copy, links, accessibility, image height invalidation and streaming performance remain unverified.
Existing assistant tests were updated for the new host and main-thread sizing; they were not run.

First command, from the repository root (same build shape as CI):

```sh
xcodebuild -scheme ShadowListUtils -destination 'generic/platform=iOS Simulator' build
```

Then run the UIKit test package with an available simulator, and validate the three local podspecs
alongside the engine podspec. Development Podfiles must register `EnrichedMarkdown`,
`EnrichedMarkdownCppShim`, and `ShadowListUtils` with `:path` pointing at this repository.

## UIKit-bound upstream source inventory

Paths relative to `Sources/EnrichedMarkdown`; line counts at the pinned upstream commit.

| File                                                      | Lines |
| --------------------------------------------------------- | ----: |
| `Accessibility/MarkdownAccessibilityElement.swift`        |    80 |
| `Accessibility/MarkdownAccessibilityElementBuilder.swift` |   386 |
| `Accessibility/MarkdownAccessibilityRotors.swift`         |    39 |
| `Attachments/CodeBlockAttachment.swift`                   |   170 |
| `Attachments/CodeBlockAttachmentView.swift`               |   368 |
| `Attachments/HorizontallyScrollingAttachment.swift`       |     6 |
| `Attachments/ImageSizing+Box.swift`                       |    81 |
| `Attachments/MarkdownImageAttachment.swift`               |   359 |
| `Attachments/TableAttachment.swift`                       |   211 |
| `Attachments/TableAttachmentView.swift`                   |   310 |
| `Attachments/ThematicBreakAttachment.swift`               |    34 |
| `Deprecated/ParsingOptions+Deprecated.swift`              |    42 |
| `Deprecated/StyleRecords+Deprecated.swift`                |   263 |
| `Extraction/MarkdownExtractor.swift`                      |   544 |
| `Extraction/MarkdownHTMLGenerator+Styles.swift`           |   161 |
| `Extraction/MarkdownHTMLGenerator+Table.swift`            |    29 |
| `Extraction/MarkdownHTMLGenerator.swift`                  |   525 |
| `Extraction/MarkdownSliceValidator.swift`                 |    86 |
| `Extraction/MarkdownSourceSlicer.swift`                   |   584 |
| `Extraction/SelectionMenuItems.swift`                     |    70 |
| `Rendering/AdmonitionHeader.swift`                        |    82 |
| `Rendering/AsyncRenderCoordinator.swift`                  |    44 |
| `Rendering/AttributedRenderer.swift`                      |    64 |
| `Rendering/FontHelpers.swift`                             |   186 |
| `Rendering/InlineBackground.swift`                        |   103 |
| `Rendering/LinkStyleResolver.swift`                       |    34 |
| `Rendering/MarkdownRenderPlugin.swift`                    |    86 |
| `Rendering/MarkdownRenderer.swift`                        |    66 |
| `Rendering/NodeRenderer.swift`                            |    17 |
| `Rendering/ParagraphStyleHelpers.swift`                   |   223 |
| `Rendering/RenderContext.swift`                           |   166 |
| `Rendering/RendererFactory.swift`                         |   137 |
| `Rendering/Renderers/BaselineShiftRenderer.swift`         |    83 |
| `Rendering/Renderers/BlankLineRenderer.swift`             |    35 |
| `Rendering/Renderers/BlockquoteRenderer.swift`            |   170 |
| `Rendering/Renderers/CodeBlockRenderer.swift`             |   154 |
| `Rendering/Renderers/CodeRenderer.swift`                  |    38 |
| `Rendering/Renderers/EmphasisRenderer.swift`              |    50 |
| `Rendering/Renderers/HeadingRenderer.swift`               |    94 |
| `Rendering/Renderers/HighlightRenderer.swift`             |    47 |
| `Rendering/Renderers/ImageRenderer.swift`                 |    42 |
| `Rendering/Renderers/LineBreakRenderer.swift`             |    13 |
| `Rendering/Renderers/LinkRenderer.swift`                  |    53 |
| `Rendering/Renderers/ListItemRenderer.swift`              |   261 |
| `Rendering/Renderers/ListRenderer.swift`                  |    83 |
| `Rendering/Renderers/ParagraphRenderer.swift`             |    86 |
| `Rendering/Renderers/SoftBreakRenderer.swift`             |    11 |
| `Rendering/Renderers/SpoilerRenderer.swift`               |    20 |
| `Rendering/Renderers/StrikethroughRenderer.swift`         |    25 |
| `Rendering/Renderers/StrongRenderer.swift`                |    44 |
| `Rendering/Renderers/TableRenderer.swift`                 |   137 |
| `Rendering/Renderers/TextRenderer.swift`                  |    11 |
| `Rendering/Renderers/ThematicBreakRenderer.swift`         |    29 |
| `Rendering/Renderers/UnderlineRenderer.swift`             |    25 |
| `Rendering/SpoilerConcealment.swift`                      |    51 |
| `Rendering/TaskListDecoration.swift`                      |    47 |
| `Rendering/TrailingSpacing.swift`                         |    50 |
| `Rendering/WritingDirectionResolver.swift`                |   135 |
| `Theme/BaselineShiftThemeElement.swift`                   |    28 |
| `Theme/Elements/Subscript.swift`                          |    12 |
| `Theme/Elements/Superscript.swift`                        |    12 |
| `Theme/MarkdownStyleConfiguration+Resolve.swift`          |    18 |
| `Theme/MarkdownStyleConfiguration.swift`                  |   159 |
| `Theme/MarkdownTheme.swift`                               |    20 |
| `Theme/MarkdownThemeContent.swift`                        |    20 |
| `Theme/MarkdownThemeElement.swift`                        |   184 |
| `Theme/Styles/AdmonitionStyle.swift`                      |    21 |
| `Theme/Styles/BaselineShiftStyle.swift`                   |    19 |
| `Theme/Styles/BlockquoteStyle.swift`                      |    62 |
| `Theme/Styles/CodeBlockStyle.swift`                       |    61 |
| `Theme/Styles/ElementStyle.swift`                         |    55 |
| `Theme/Styles/ImageStyle.swift`                           |    84 |
| `Theme/Styles/LinkVariantStyle.swift`                     |    11 |
| `Theme/Styles/ListStyle.swift`                            |    55 |
| `Theme/Styles/SpoilerStyle.swift`                         |    33 |
| `Theme/Styles/TableStyle.swift`                           |    92 |
| `Theme/Styles/TaskListStyle.swift`                        |    39 |
| `Theme/Styles/ThematicBreakStyle.swift`                   |    27 |
| `Theme/TextStyleRecord.swift`                             |    22 |
| `Theme/ThemeResolver.swift`                               |   332 |
| `Utils/ImageDecoder.swift`                                |    34 |
| `Utils/ImageDownloader.swift`                             |   107 |
| `Utils/LocalImageLoader.swift`                            |   102 |
| `Utils/UIImage+ByteCost.swift`                            |     9 |
| `Views/EnrichedMarkdownText.swift`                        |   159 |
| `Views/HorizontalBlockScrollView.swift`                   |    29 |
| `Views/Layout/BlockDecorationConfig.swift`                |   106 |
| `Views/Layout/BlockquoteBorderDrawer.swift`               |    82 |
| `Views/Layout/CodeBlockBackgroundDrawer.swift`            |    72 |
| `Views/Layout/InlineBackgroundDrawer.swift`               |   329 |
| `Views/Layout/MarkdownViewportDecorator.swift`            |    86 |
| `Views/Layout/ParagraphLayoutWalker.swift`                |   165 |
| `Views/Layout/ParagraphMarkerDrawer.swift`                |   179 |
| `Views/Layout/SnapshotTextContainer.swift`                |     5 |
| `Views/Layout/TextLayoutHelpers.swift`                    |   153 |
| `Views/MarkdownRenderStore.swift`                         |   146 |
| `Views/MarkdownTextView.swift`                            |   567 |
| `Views/MarkdownTextViewRepresentable.swift`               |   247 |
| `Views/Spoiler/SpoilerInteraction.swift`                  |    71 |
| `Views/Spoiler/SpoilerOverlayManager.swift`               |   168 |
| `Views/Spoiler/SpoilerOverlayProvider.swift`              |    67 |
| `Views/Spoiler/SpoilerOverlayView.swift`                  |   239 |
| `Views/TaskListInteraction.swift`                         |   141 |
