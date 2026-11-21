import ShadowListKit
import ShadowListUtils
import UIKit
import XCTest

@MainActor
final class ItemActionsViewTests: XCTestCase {
  private func attached(_ view: UIView) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    let controller = UIViewController()
    window.rootViewController = controller
    controller.view.addSubview(view)
    view.frame = CGRect(x: 10, y: 20, width: 300, height: 60)
    window.isHidden = false
    view.setNeedsLayout(); view.layoutIfNeeded()
    return window
  }

  private func configuration(_ title: String,
    handler: @escaping (ShadowListKitSwipeAction, @escaping (Bool) -> Void) -> Void
  ) -> ShadowListKitSwipeActionsConfiguration {
    ShadowListKitSwipeActionsConfiguration(actions: [
      ShadowListKitSwipeAction(style: .normal, title: title, handler: handler),
    ])
  }

  func testGroupedRowDynamicProxyStaysCurrentWithoutDuplicateOwnedActions() throws {
    let row = ShadowListUtilsGroupedRow(title: "Reservation")
    let inspect = UIAccessibilityCustomAction(name: "Inspect") { _ in true }
    row.accessibilityCustomActions = [inspect]
    row.onLongPress = {}
    row.longPressLabel = "Details"
    row.leadingSwipeActions = configuration("Archive") { _, _ in }
    let window = attached(row)
    defer { window.isHidden = true }
    XCTAssertEqual(row.accessibilityCustomActions?.map(\.name), ["Inspect", "Details", "Archive"])
    row.leadingSwipeActions = configuration("Remove") { _, _ in }
    // Configuration forwarding alone updates the proxy; no unrelated row property is assigned.
    XCTAssertEqual(row.accessibilityCustomActions?.map(\.name), ["Inspect", "Details", "Remove"])
    for _ in 0..<3 { row.setNeedsLayout(); row.layoutIfNeeded() }
    XCTAssertEqual(row.accessibilityCustomActions?.map(\.name), ["Inspect", "Details", "Remove"])
    XCTAssertTrue(row.accessibilityCustomActions?.first === inspect)
    XCTAssertTrue(row.isAccessibilityElement)
  }
}
