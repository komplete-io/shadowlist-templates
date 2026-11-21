import ShadowListKit
@testable import ShadowListUtils
import UIKit
import XCTest

final class TextLayoutTests: XCTestCase {
  @MainActor
  func testTemplateTextPreservesRunColorsAndWrappedHitTesting() throws {
    let style = ShadowListUtilsTheme.light.typography.footnote
    let rich = style.layout(NSAttributedString(string: "Red", attributes: [.foregroundColor: UIColor.red]), width: 200)
    let plain = style.layout("Red", width: 200)
    func pixels(_ layout: ShadowListKitTextLayout, _ color: UIColor) -> Data? {
      UIGraphicsImageRenderer(size: CGSize(width: 200, height: 40)).image { context in
        layout.draw(at: .zero, in: context.cgContext, color: color.cgColor)
      }.pngData()
    }
    XCTAssertEqual(pixels(rich, .blue), pixels(rich, .red))
    XCTAssertNotEqual(pixels(plain, .blue), pixels(plain, .red))
    let wrapped = style.layout("First\nSecond", width: 200)
    XCTAssertEqual(wrapped.lineCount, 2)
    XCTAssertEqual(wrapped.size.height, style.lineHeight * 2)
    let second = wrapped.rectForLine(at: 1)
    XCTAssertEqual(wrapped.characterIndex(at: CGPoint(x: second.minX + 0.1, y: second.midY)), 6)
    let truncated = style.layout("A very long line that needs truncation", width: 70, maxLines: 1)
    XCTAssertEqual(truncated.lineCount, 1)
    let last = truncated.rectForLine(at: 0)
    XCTAssertEqual(truncated.characterIndex(at: CGPoint(x: last.maxX - 0.1, y: last.midY)), UInt(NSNotFound))
  }

}
