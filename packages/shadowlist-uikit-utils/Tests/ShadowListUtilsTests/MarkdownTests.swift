import ShadowListKit
@testable import ShadowListUtils
import UIKit
import ShadowListUtilsCore
import XCTest

final class MarkdownTests: XCTestCase {
  func testTheStepBridgeReplaysEverySharedIntegerUtf16Fixture() throws {
    for entry in try Vectors.cases("assistant-steps.json") {
      let input = try XCTUnwrap(entry["input"] as? [String: Any])
      let positions = try XCTUnwrap(input["positions"] as? [Any]).map { NSNumber(value: ($0 as? Int) ?? 0) }
      let steps = ShadowListUtilsCore.stepsOf(try XCTUnwrap(input["content"] as? String), positions: positions)
      let expected = try XCTUnwrap(entry["output"] as? [[String: Any]])
      XCTAssertEqual(steps.count, expected.count)
      for (step, value) in zip(steps, expected) {
        if let text = step as? ShadowListUtilsAssistantTextStep {
          XCTAssertEqual(value["kind"] as? String, "text")
          XCTAssertEqual(text.text, value["text"] as? String)
          XCTAssertEqual(Int(text.at), value["at"] as? Int)
        } else {
          let calls = try XCTUnwrap(step as? ShadowListUtilsAssistantCallsStep)
          XCTAssertEqual(value["kind"] as? String, "calls")
          XCTAssertEqual(calls.callIndices.map(\.intValue), value["callIndices"] as? [Int])
        }
      }
    }
  }

  func testTheBridgePreservesEmbeddedNullCharacters() {
    let text = "before\0after"
    XCTAssertEqual(ShadowListUtilsCore.trim(text), text)
  }

  func testTheBridgeReadsHalfASurrogatePairAsTheReplacementCharacter() {
    let units = Array("https://example.com/".utf16) + [0xD83D]
    let url = NSString(characters: units, length: units.count) as String
    XCTAssertTrue(ShadowListUtilsCore.isSafeUrl(url))
    XCTAssertEqual(ShadowListUtilsCore.trim(url), "https://example.com/\u{FFFD}")
  }

  func testTheBridgeReplaysTheSharedUrlVectors() throws {
    for entry in try Vectors.cases("markdown.json") where entry["function"] as? String == "isSafeUrl" {
      let name = try XCTUnwrap(entry["name"] as? String)
      let input = try XCTUnwrap(entry["input"] as? [String: Any])
      XCTAssertEqual(ShadowListUtilsCore.isSafeUrl(try XCTUnwrap(input["url"] as? String)), entry["output"] as? Bool, name)
    }
  }
}
