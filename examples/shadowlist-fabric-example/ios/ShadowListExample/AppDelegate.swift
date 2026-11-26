import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?

  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    // Engine flags that make list commits cheaper, see ShadowListEngineFlags.h.
    ShadowListApplyEngineFlags()
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = factory

    self.launchOptions = launchOptions

    if let plan = UserDefaults.standard.string(forKey: "SLAutoFling") {
      AutoFlingDriver.shared.start(plan: plan)
    }
    if let plan = UserDefaults.standard.string(forKey: "SLAutoDrag") {
      AutoDragDriver.shared.start(plan: plan)
    }
    let jsFps = UserDefaults.standard.string(forKey: "SLJsFps") == "1"
    let netLog = UserDefaults.standard.string(forKey: "SLNetLog") == "1"
    let bench = UserDefaults.standard.string(forKey: "SLRoute") == "Bench"
    let ruler = UserDefaults.standard.string(forKey: "SLRuler") == "1"
    if jsFps {
      UIFrameMonitor.shared.start()
    }
    if bench && UserDefaults.standard.string(forKey: "SLOps") == "1" {
      AnchorMonitor.shared.start()
    }
    if bench {
      FillMonitor.shared.start()
    }
    // Release builds drop JS logs: copy the scripted-run lines to stderr (simctl launch --console-pty).
    if jsFps || netLog || bench || ruler {
      RCTSetLogThreshold(.info)
      let defaultLog = RCTGetLogFunction()
      let tags = ["[SLFPS]", "[SLNET]", "[SLMOUNT]", "[SLBENCH]", "[SLOP]", "[SLRULER]"]
      RCTSetLogFunction { level, source, fileName, lineNumber, message in
        if let message, message.contains("[SLMOUNTSTART]") {
          FillMonitor.shared.markStart()
        }
        if let message, tags.contains(where: { message.contains($0) }) {
          FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        }
        defaultLog?(level, source, fileName, lineNumber, message)
      }
    }

    return true
  }

  func startReactNative(in window: UIWindow) {
    reactNativeFactory?.startReactNative(
      withModuleName: "ShadowListExample",
      in: window,
      launchOptions: launchOptions
    )
  }
}

/*
 * BENCHMARK-ONLY. With -SLJsFps 1, logs one [SLUI] line per second of main thread frames:
 * frames, frames over 20 ms, the longest gap. Same numbers for any list library.
 */
final class UIFrameMonitor: NSObject {
  static let shared = UIFrameMonitor()
  private var link: CADisplayLink?
  private var last: CFTimeInterval = 0
  private var windowStart: CFTimeInterval = 0
  private var frames = 0
  private var slow = 0
  private var longest: CFTimeInterval = 0

  func start() {
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    let now = link.timestamp
    if last != 0 {
      let gap = now - last
      frames += 1
      if gap > 0.020 { slow += 1 }
      longest = max(longest, gap)
    } else {
      windowStart = now
    }
    last = now
    if now - windowStart >= 1 {
      let line = String(
        format: "[SLUI] t=%.0f span=%.0f frames=%d slow=%d longest=%.1f",
        now * 1000, (now - windowStart) * 1000, frames, slow, longest * 1000)
      FileHandle.standardError.write((line + "\n").data(using: .utf8)!)
      windowStart = now
      frames = 0
      slow = 0
      longest = 0
    }
  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}

/*
 * BENCHMARK-ONLY. Rows of the list comparison screen (BenchScreen.tsx) inside a scroll view,
 * found by their testID bench-<id> (accessibilityIdentifier), the same way for any list library.
 */
enum BenchViewport {
  struct Row {
    let id: String
    let top: CGFloat
    let bottom: CGFloat
  }

  static func window() -> UIWindow? {
    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
  }

  static func tallestScrollView(in view: UIView) -> UIScrollView? {
    var best: UIScrollView?
    func visit(_ view: UIView) {
      if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height,
        scroll.contentSize.height > (best?.contentSize.height ?? 0)
      {
        best = scroll
      }
      view.subviews.forEach(visit)
    }
    visit(view)
    return best
  }

  /*
   * The visible span of the content, clamped to the content so a bounce past either end
   * doesn't count as blank.
   */
  static func visibleSpan(of scroll: UIScrollView) -> (top: CGFloat, bottom: CGFloat) {
    let top = max(0, scroll.contentOffset.y + scroll.adjustedContentInset.top)
    let bottom = min(
      scroll.contentSize.height, scroll.contentOffset.y + scroll.bounds.height - scroll.adjustedContentInset.bottom)
    return (top, max(top, bottom))
  }

  /*
   * Shown rows in content coordinates. Doesn't descend into rows or hidden views.
   */
  static func rows(in scroll: UIScrollView) -> [Row] {
    var rows: [Row] = []
    func visit(_ view: UIView) {
      if view.isHidden || view.alpha < 0.01 { return }
      if let id = view.accessibilityIdentifier, id.hasPrefix("bench-") {
        let frame = view.convert(view.bounds, to: scroll)
        rows.append(Row(id: String(id.dropFirst(6)), top: frame.minY, bottom: frame.maxY))
        return
      }
      view.subviews.forEach(visit)
    }
    scroll.subviews.forEach(visit)
    return rows
  }

  /*
   * Points of the visible span no row covers, and the tallest uncovered band.
   */
  static func blank(in scroll: UIScrollView) -> (total: CGFloat, band: CGFloat, span: CGFloat) {
    let span = visibleSpan(of: scroll)
    let covered = rows(in: scroll)
      .map { (max($0.top, span.top), min($0.bottom, span.bottom)) }
      .filter { $0.0 < $0.1 }
      .sorted { $0.0 < $1.0 }
    var cursor = span.top
    var total: CGFloat = 0
    var band: CGFloat = 0
    for (top, bottom) in covered {
      // Sub-point gaps are rounding between rows, not blank.
      if top - cursor > 0.5 {
        total += top - cursor
        band = max(band, top - cursor)
      }
      cursor = max(cursor, bottom)
    }
    if span.bottom - cursor > 0.5 {
      total += span.bottom - cursor
      band = max(band, span.bottom - cursor)
    }
    return (total, band, span.bottom - span.top)
  }
}

/*
 * BENCHMARK-ONLY. Per phase numbers for one scroll phase: main thread frame gaps from the
 * display link and blank area of the list, logged as one [SLPHASE] line.
 */
struct BenchPhaseStats {
  var gaps: [Double] = []
  var blankFrames = 0
  var blankShare: Double = 0
  var blankBand: CGFloat = 0
  var start: CFTimeInterval = 0

  mutating func add(gap: Double, blank: (total: CGFloat, band: CGFloat, span: CGFloat)?) {
    gaps.append(gap)
    guard let blank, blank.span > 0 else { return }
    if blank.total > 0 { blankFrames += 1 }
    blankShare += Double(blank.total / blank.span)
    blankBand = max(blankBand, blank.band)
  }

  func line(_ name: String, end: CFTimeInterval) -> String {
    let sorted = gaps.sorted()
    func pct(_ q: Double) -> Double {
      sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int((q * Double(sorted.count - 1)).rounded()))]
    }
    let frame = 1000.0 / 60.0
    let dropped = gaps.reduce(0) { $0 + max(0, Int(($1 / frame).rounded()) - 1) }
    let janky = gaps.filter { $0 > frame * 1.5 }.count
    let mean = gaps.isEmpty ? 0 : gaps.reduce(0, +) / Double(gaps.count)
    return String(
      format:
        "[SLPHASE] phase=%@ ms=%.0f frames=%d mean=%.2f p50=%.2f p95=%.2f p99=%.2f max=%.2f janky=%d dropped=%d blank_frames=%d blank_pct=%.3f blank_band=%.1f",
      name, (end - start) * 1000, gaps.count, mean, pct(0.5), pct(0.95), pct(0.99), sorted.last ?? 0, janky,
      dropped, blankFrames, gaps.isEmpty ? 0 : 100 * blankShare / Double(gaps.count), blankBand)
  }
}

/*
 * BENCHMARK-ONLY. -SLAutoFling "quiet,forward,back,velocity" flings the tallest vertical scroll
 * view in the window, like a finger would: each fling starts at velocity pt/s and slows with
 * UIKit's normal deceleration, set straight on contentOffset once per frame. It replaces
 * XCTest gestures, which snapshot the accessibility tree on the main thread for every gesture
 * and cost more the more views a list keeps mounted. Negative velocity flings toward the
 * start (a chat's history).
 *
 * It starts once the main thread has drawn quiet seconds of frames in a row on time, and on
 * the Bench route once JS also said it is ready (SLBenchReady, set through Settings). No
 * wall clock delay: a slow launch waits as long as it takes.
 *
 * -SLAutoSlow "speed,seconds" first scrolls forward at a constant speed pt/s, like a reading
 * finger, for that many seconds of frames. Each phase ends with a [SLPHASE] line (frame gaps,
 * blank area); [SLBENCH] start and end lines bracket the flings.
 */
final class AutoFlingDriver: NSObject {
  static let shared = AutoFlingDriver()
  private enum Phase { case waiting, slow, settle, fling, done }
  private var link: CADisplayLink?
  private var phase = Phase.waiting
  private var flings: [Double] = []
  private var velocity: Double = 0
  private var last: CFTimeInterval = 0
  private var pauseFrames = 0
  private var quietFrames = 0
  private var neededQuietFrames = 0
  private var slowSpeed: Double = 0
  private var slowFrames = 0
  private var waitForJs = false
  private var jsReady = false
  private var stats = BenchPhaseStats()
  private weak var scrollView: UIScrollView?

  func start(plan: String) {
    let parts = plan.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return }
    let speed = parts[3]
    flings = Array(repeating: speed, count: Int(parts[1])) + Array(repeating: -speed, count: Int(parts[2]))
    neededQuietFrames = Int(parts[0] * 60)
    if let slow = UserDefaults.standard.string(forKey: "SLAutoSlow")?.split(separator: ",").compactMap({ Double($0) }),
      slow.count == 2
    {
      slowSpeed = slow[0]
      slowFrames = Int(slow[1] * 60)
    }
    waitForJs = UserDefaults.standard.string(forKey: "SLRoute") == "Bench"
    // A value left from an earlier launch must not count.
    UserDefaults.standard.removeObject(forKey: "SLBenchReady")
    NotificationCenter.default.addObserver(
      self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func defaultsChanged() {
    if UserDefaults.standard.object(forKey: "SLBenchReady") != nil {
      jsReady = true
    }
  }

  private func begin(_ now: CFTimeInterval) -> Bool {
    guard let window = BenchViewport.window(), let target = BenchViewport.tallestScrollView(in: window) else {
      return false
    }
    scrollView = target
    let span = BenchViewport.visibleSpan(of: target)
    log(
      String(
        format: "[SLBENCH] start view=%@ content=%.0f span=%.0f-%.0f rows=%d", NSStringFromClass(type(of: target)),
        target.contentSize.height, span.top, span.bottom, BenchViewport.rows(in: target).count))
    stats = BenchPhaseStats(start: now)
    phase = slowFrames > 0 ? .slow : .fling
    return true
  }

  private func endPhase(_ name: String, _ now: CFTimeInterval) {
    let where_ = scrollView.map { String(format: " offset=%.0f content=%.0f", $0.contentOffset.y, $0.contentSize.height) } ?? ""
    log(stats.line(name, end: now) + where_)
    stats = BenchPhaseStats(start: now)
  }

  @objc private func tick(_ link: CADisplayLink) {
    let now = link.timestamp
    defer { last = now }
    guard last != 0 else { return }
    let dt = now - last
    switch phase {
    case .waiting:
      quietFrames = dt < 0.020 ? quietFrames + 1 : 0
      if quietFrames >= neededQuietFrames, !waitForJs || jsReady {
        _ = begin(now)
      }
      return
    case .done:
      return
    default:
      break
    }
    guard let scrollView else {
      link.invalidate()
      log("[SLBENCH] no scroll view")
      return
    }
    // Score what the last frame showed, before moving: rows mounted since then count.
    stats.add(gap: dt * 1000, blank: BenchViewport.blank(in: scrollView))
    var offset = scrollView.contentOffset
    let minY = -scrollView.adjustedContentInset.top
    let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
    switch phase {
    case .slow:
      offset.y = min(maxY, offset.y + slowSpeed * dt)
      scrollView.contentOffset = offset
      slowFrames -= 1
      if slowFrames <= 0 || offset.y == maxY {
        endPhase("slow", now)
        phase = .settle
        pauseFrames = 30
      }
    case .settle:
      pauseFrames -= 1
      if pauseFrames <= 0 {
        stats = BenchPhaseStats(start: now)
        phase = .fling
      }
    case .fling:
      if velocity == 0 {
        if pauseFrames > 0 {
          pauseFrames -= 1
          return
        }
        if flings.isEmpty {
          endPhase("fling", now)
          link.invalidate()
          phase = .done
          log("[SLBENCH] end")
          return
        }
        velocity = flings.removeFirst()
      }
      // UIScrollView.DecelerationRate.normal is 0.998 per millisecond.
      velocity *= pow(0.998, dt * 1000)
      offset.y = min(maxY, max(minY, offset.y + velocity * dt))
      scrollView.contentOffset = offset
      if abs(velocity) < 60 || offset.y == minY || offset.y == maxY {
        velocity = 0
        pauseFrames = 6
      }
    default:
      break
    }
  }

  private func log(_ line: String) {
    FileHandle.standardError.write((line + "\n").data(using: .utf8)!)
  }
}

/*
 * BENCHMARK-ONLY. On the Bench route, logs [SLFILLED] ms=... once rows first cover the whole
 * list, timed from the [SLMOUNTSTART] line BenchScreen logs on its first render (taken on the JS
 * thread as the line is logged). Time to a full first screen, the same way for any list.
 */
final class FillMonitor: NSObject {
  static let shared = FillMonitor()
  private var link: CADisplayLink?
  private let lock = NSLock()
  private var startTime: CFTimeInterval = 0
  private weak var scrollView: UIScrollView?

  func markStart() {
    lock.lock()
    if startTime == 0 { startTime = CACurrentMediaTime() }
    lock.unlock()
  }

  func start() {
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    lock.lock()
    let start = startTime
    lock.unlock()
    guard start > 0 else { return }
    if scrollView == nil, let window = BenchViewport.window() {
      scrollView = BenchViewport.tallestScrollView(in: window)
    }
    guard let scrollView, !BenchViewport.rows(in: scrollView).isEmpty else { return }
    let blank = BenchViewport.blank(in: scrollView)
    guard blank.span > 0, blank.total == 0 else { return }
    link.invalidate()
    FileHandle.standardError.write(
      String(format: "[SLFILLED] ms=%.1f\n", (CACurrentMediaTime() - start) * 1000).data(using: .utf8)!)
  }
}

/*
 * BENCHMARK-ONLY. With -SLOps 1 on the Bench route, logs the top three shown rows of the list
 * and where they sit in the viewport, [SLANCHOR] id:y,..., on every frame they change. A data
 * update that keeps the visible content still leaves the first row's y alone.
 */
final class AnchorMonitor: NSObject {
  static let shared = AnchorMonitor()
  private var link: CADisplayLink?
  private var lastLine = ""
  private weak var scrollView: UIScrollView?

  func start() {
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  @objc private func tick(_ link: CADisplayLink) {
    if scrollView == nil, let window = BenchViewport.window() {
      scrollView = BenchViewport.tallestScrollView(in: window)
    }
    guard let scrollView else { return }
    let span = BenchViewport.visibleSpan(of: scrollView)
    let rows = BenchViewport.rows(in: scrollView)
      .filter { $0.bottom > span.top + 0.5 && $0.top < span.bottom }
      .sorted { $0.top < $1.top }
      .prefix(3)
    let line = rows.map { String(format: "%@:%.1f", $0.id, $0.top - span.top) }.joined(separator: ",")
    if line != lastLine {
      lastLine = line
      FileHandle.standardError.write(
        (String(format: "[SLANCHOR] t=%.4f %@\n", link.timestamp, line)).data(using: .utf8)!)
    }
  }
}

/*
 * TEST-ONLY. -SLAutoDrag "quiet;x,y,x2,y2,move,hold[,x3,y3,move,hold...];..." drags list rows,
 * since XCTest and simulator automation tools cannot hold and drag. It starts once the main
 * thread has drawn quiet seconds of frames in a row on time. Each step picks up the row at x,y in
 * window points, moves to each waypoint over move seconds, holds for hold seconds and drops at
 * the last one, through the list's debugDragPhase hook. Writes [SLDRAG] lines to stderr.
 * The moves and holds are a finger's timeline, so they follow the display link's clock.
 */
final class AutoDragDriver: NSObject {
  static let shared = AutoDragDriver()
  private var link: CADisplayLink?
  private var steps: [[Double]] = []
  private var step: [Double] = []
  private var stepStart: CFTimeInterval = 0
  private var dropped = false
  private var last: CFTimeInterval = 0
  private var quietFrames = 0
  private var neededQuietFrames = 0
  private weak var list: UIView?

  /*
   * Held still after pickup, like a long press, and after each drop.
   */
  private let pickupPause = 0.3
  private let dropPause = 1.5

  func start(plan: String) {
    let parts = plan.split(separator: ";").map(String.init)
    guard let quiet = parts.first.flatMap(Double.init) else { return }
    neededQuietFrames = Int(quiet * 60)
    steps = []
    for part in parts.dropFirst() {
      let numbers: [Double] = part.split(separator: ",").compactMap { Double($0) }
      if numbers.count >= 6 && (numbers.count - 2) % 4 == 0 {
        steps.append(numbers)
      }
    }
    let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  private var window: UIWindow? {
    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
  }

  /*
   * The innermost list under a window point.
   */
  private func listView(at point: CGPoint, in view: UIView) -> UIView? {
    guard let listClass = NSClassFromString("ShadowListView") else { return nil }
    var found: UIView?
    func visit(_ view: UIView) {
      if view.isKind(of: listClass), view.convert(view.bounds, to: nil).contains(point) {
        found = view
      }
      view.subviews.forEach(visit)
    }
    visit(view)
    return found
  }

  private func send(_ phase: Int, _ point: CGPoint) {
    guard let list else { return }
    let local = list.convert(point, from: nil)
    _ = list.perform(
      NSSelectorFromString("debugDragPhase:point:"), with: NSNumber(value: phase),
      with: NSValue(cgPoint: local))
  }

  /*
   * Where the finger is at elapsed seconds into the step, or nil once every waypoint is done.
   */
  private func position(at elapsed: Double) -> CGPoint? {
    var from = CGPoint(x: step[0], y: step[1])
    var time = elapsed - pickupPause
    var index = 2
    while index + 3 < step.count {
      let to = CGPoint(x: step[index], y: step[index + 1])
      let move = step[index + 2]
      let hold = step[index + 3]
      if time < move {
        let progress = move > 0 ? time / move : 1
        return CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
      }
      if time < move + hold {
        return to
      }
      time -= move + hold
      from = to
      index += 4
    }
    return nil
  }

  @objc private func tick(_ link: CADisplayLink) {
    let now = link.timestamp
    defer { last = now }
    if quietFrames < neededQuietFrames {
      quietFrames = last != 0 && now - last < 0.020 ? quietFrames + 1 : 0
      return
    }
    if step.isEmpty {
      if steps.isEmpty {
        link.invalidate()
        log("[SLDRAG] end")
        return
      }
      step = steps.removeFirst()
      stepStart = now
      dropped = false
      let from = CGPoint(x: step[0], y: step[1])
      guard let window, let target = listView(at: from, in: window) else {
        log("[SLDRAG] no list at \(from)")
        step = []
        return
      }
      list = target
      log("[SLDRAG] pickup \(from)")
      send(1, from)
      return
    }
    let elapsed = now - stepStart
    if elapsed < pickupPause {
      return
    }
    if !dropped, let point = position(at: elapsed) {
      send(2, point)
      return
    }
    if !dropped {
      let last = CGPoint(x: step[step.count - 4], y: step[step.count - 3])
      send(3, last)
      log("[SLDRAG] drop \(last)")
      dropped = true
      stepStart = now
      return
    }
    if elapsed >= dropPause {
      step = []
    }
  }

  private func log(_ line: String) {
    FileHandle.standardError.write((line + "\n").data(using: .utf8)!)
  }
}
