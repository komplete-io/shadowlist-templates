import ShadowListKit
import UIKit

/*
 * Waits in display frames for the scripted scenarios and demos, in place of wall clock delays:
 * a step runs at the first frame its condition holds, or a number of frames on, which is after
 * the layout and the commit of the frames before.
 */
enum Frames {
  /*
   * Run work at the first display frame where ready returns true, checked once a frame.
   */
  static func when(_ ready: @escaping () -> Bool, _ work: @escaping () -> Void) {
    FrameWaiter(ready: ready, work: work).start()
  }

  /*
   * Run work count display frames from now.
   */
  static func after(frames count: Int, _ work: @escaping () -> Void) {
    var left = count
    when({
      left -= 1
      return left <= 0
    }, work)
  }

  /*
   * Run work at the first frame where the scroll view shows a row view of the library.
   */
  static func whenRowsShow(in scroll: UIScrollView, _ work: @escaping () -> Void) {
    when({ !Scenario.visibleRows(scroll).isEmpty }, work)
  }

  /*
   * Whether the list's shown cells run no animation, like after a drop or a change settled.
   * Views outside the cells, like a spinner in the footer, may animate on.
   */
  static func settled(_ list: ShadowListKitListView) -> Bool {
    list.visibleCells.allSatisfy { settled(view: $0) }
  }

  /*
   * Whether no layer under the view runs an animation.
   */
  static func settled(view: UIView) -> Bool {
    func idle(_ layer: CALayer, depth: Int) -> Bool {
      if !(layer.animationKeys() ?? []).isEmpty { return false }
      guard depth < 4 else { return true }
      return (layer.sublayers ?? []).allSatisfy { idle($0, depth: depth + 1) }
    }
    return idle(view.layer, depth: 0)
  }
}

/*
 * One wait. The display link holds it until the work ran.
 */
private final class FrameWaiter {
  private let ready: () -> Bool
  private let work: () -> Void
  private var link: CADisplayLink?

  init(ready: @escaping () -> Bool, work: @escaping () -> Void) {
    self.ready = ready
    self.work = work
  }

  func start() {
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick() {
    guard ready() else { return }
    link?.invalidate()
    link = nil
    work()
  }
}
