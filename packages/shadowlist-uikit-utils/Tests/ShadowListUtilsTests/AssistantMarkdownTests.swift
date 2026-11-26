@testable import ShadowListUtils
import ShadowListUtilsCore
import UIKit
import XCTest

@MainActor
final class AssistantMarkdownTests: XCTestCase {
  private let theme = ShadowListUtilsTheme.light

  func testStableBlocksKeepTheirViewsWhileTheLastBlockAndStreamingDotGrow() throws {
    let markdown = ShadowListUtilsAssistantMarkdown(text: "# Title\n\nA reply", theme: theme)
    let first = markdown.markdownView
    let height = markdown.sizeThatFits(CGSize(width: 250, height: 1000)).height
    markdown.text += " that keeps growing over several lines with a useful answer for the crew."
    XCTAssertTrue(markdown.subviews.contains { $0 === first })
    XCTAssertGreaterThan(markdown.sizeThatFits(CGSize(width: 250, height: 1000)).height, height)
    let before = markdown.sizeThatFits(CGSize(width: 250, height: 1000)).height
    markdown.streaming = true
    XCTAssertGreaterThan(markdown.sizeThatFits(CGSize(width: 250, height: 1000)).height, before)
  }

  func testDefaultUnsafeLinksAreBlockedAndACustomHandlerGetsTheOriginalTarget() throws {
    let view = ShadowListUtilsAssistantMarkdown(text: "[Call](tel:+123)", theme: theme)
    XCTAssertFalse(view.open("tel:+123"))
    var target: String?
    view.onOpenLink = { target = $0 }
    XCTAssertTrue(view.open("  tel:+123  "))
    XCTAssertEqual(target, "  tel:+123  ")
  }

  func testStreamingRepairAndCompletionKeepTheTextViewAndFittingHeight() throws {
    let view = ShadowListUtilsAssistantMarkdown(theme: theme)
    view.update(text: "**A partial", streaming: true)
    let textView = try XCTUnwrap(view.markdownView.subviews.compactMap { $0 as? UITextView }.first)
    XCTAssertEqual(textView.attributedText.string, "A partial")
    view.update(text: "**A partial reply**", streaming: false)
    XCTAssertTrue(view.markdownView.subviews.contains { $0 === textView })
    XCTAssertEqual(textView.attributedText.string, "A partial reply")
    let size = view.sizeThatFits(CGSize(width: 240, height: 1000))
    XCTAssertEqual(size.height, ShadowListUtilsAssistantMarkdown.height(
      text: "**A partial reply**", streaming: false, width: 240, theme: theme))
    XCTAssertGreaterThan(size.height, 0)
  }

  func testNativeSelectionCopiesRenderedText() throws {
    let view = ShadowListUtilsAssistantMarkdown(text: "**Copy** this reply", theme: theme)
    let textView = try XCTUnwrap(view.markdownView.subviews.compactMap { $0 as? UITextView }.first)
    XCTAssertTrue(textView.isSelectable)
    XCTAssertFalse(textView.isEditable)
    textView.selectedRange = NSRange(location: 0, length: textView.attributedText.length)
    textView.copy(nil)
    XCTAssertEqual(UIPasteboard.general.string, "Copy this reply")
  }
}
