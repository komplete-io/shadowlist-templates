import ShadowListKit
import ShadowListUtils
import UIKit

/*
 * The rows the engine comparison runs on, opened with -SLRoute Bench. -SLBenchRows picks them:
 *
 *   fixed  contacts, every row one height
 *   text   chat bubbles of text only, of one to three sample texts, heights vary
 *   image  feed posts with photos and text, one photo or a carousel of three
 *
 * Every engine shows the same row views with the same data. The sl engine shows them in a plain
 * ShadowListUtilsList, the others through ListController. The rows are set in viewDidLoad,
 * without the fake network, and the screen logs one [SLMOUNT] line at the first display frame
 * that shows a row:
 *
 *   firstContentMs  from setting the rows to the start of that frame
 *   mainCpuMs       main thread CPU time over the same span
 *
 * -SLBenchOps 1 then times data changes and jumps while resting mid list and logs one [SLOPS]
 * line, see runOps. -SLBenchExit 1 quits after the last line. Without -SLBenchOps the screen
 * stays for the scroll bench of ShadowListKitBench, which -SLBenchOnReady 1 starts at that
 * first frame.
 */
final class BenchScreen: ListScreen {
  enum Kind: String {
    case fixed, text, image
  }

  private let kind = Kind(rawValue: UserDefaults.standard.string(forKey: "SLBenchRows") ?? "") ?? .text
  private let rowsList = ShadowListUtilsList(theme: AppTheme.theme)
  private var rows: [ShadowListUtilsRow] = []
  private var generated = 0
  private var mountStart: CFTimeInterval = 0
  private var mountCpuStart: Double = 0
  private var link: CADisplayLink?

  override func makeTemplate() -> ShadowListUtilsList? { rowsList }

  override func loadView() {
    let root = ImageBlankProbe()
    root.screen = self
    view = root
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Bench"
    // -SLMountOverscan sets how far past the viewport shadowlist mounts cells, in viewports.
    if let kitList = list.view as? ShadowListKitListView, let value = UserDefaults.standard.string(forKey: "SLMountOverscan"),
      let overscan = Double(value)
    {
      kitList.mountOverscan = CGFloat(overscan)
    }
    let seed = make(Settings.count)
    if kind == .fixed, let first = seed.first {
      list.fixedRowHeight = list.cache.layout(first, width: UIScreen.main.bounds.width).height
    }
    mountStart = CACurrentMediaTime()
    mountCpuStart = MainThreadClock.cpuSeconds()
    rows = seed
    show(.reset)
    let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  private func make(_ count: Int) -> [ShadowListUtilsRow] {
    defer { generated += count }
    return (generated..<generated + count).map(row)
  }

  private func row(_ index: Int) -> ShadowListUtilsRow {
    switch kind {
    case .fixed:
      return ShadowListUtilsContactRow(item: Items.contact(Contact(index: index)), showsChevron: false, theme: AppTheme.theme)
    case .text:
      let texts = FixtureStrings.sampleTexts
      let text = (0...(index % 3)).map { texts[(index + $0 * 7) % texts.count] }.joined(separator: " ")
      let author = Author(index % 3 == 0 ? FixtureStrings.avatarNames[index % FixtureStrings.avatarNames.count] : "Me")
      let message = ChatMessage(id: "text-\(index)", author: author, isOwn: index % 3 != 0, text: text)
      return ShadowListUtilsChatBubble(
        item: Items.chat(message), caption: nil, showsAuthor: !message.isOwn, theme: AppTheme.theme, labels: ShadowListUtilsChatLabels())
    case .image:
      return ShadowListUtilsFeedRow(item: Items.feed(FeedPost(index: index)), theme: AppTheme.theme, labels: ShadowListUtilsFeedLabels())
    }
  }

  private func show(_ change: RowChange) {
    show(rows, change, template: { rowsList.setRows($0) }, row: { $0 })
  }

  override func prependRowsNow() {
    rows = make(10) + rows
    show(.prepend(10))
  }

  override func appendRowsNow() {
    rows += make(10)
    show(.append(10))
  }

  override func prependRows() { prependRowsNow() }
  override func appendRows() { appendRowsNow() }

  /*
   * Waits for the first display frame with a row on screen.
   */
  @objc private func frame(_ link: CADisplayLink) {
    guard !Scenario.visibleRows(list.view).isEmpty else { return }
    link.invalidate()
    self.link = nil
    let result: [String: Any] = [
      "engine": engine.rawValue, "rows": kind.rawValue, "count": rows.count,
      "firstContentMs": (link.timestamp - mountStart) * 1000,
      "mainCpuMs": (MainThreadClock.cpuSeconds() - mountCpuStart) * 1000,
    ]
    BenchLog.line("SLMOUNT", result)
    // The scroll bench, started with -SLBenchOnReady 1, runs from here.
    NotificationCenter.default.post(name: .ShadowListKitBenchReady, object: nil)
    if UserDefaults.standard.bool(forKey: "SLBenchOps") {
      // Layouts the hosted engines make ahead would compete with the timed changes.
      list.prefetchPaused = true
      DispatchQueue.main.async { self.runOps() }
    } else if UserDefaults.standard.bool(forKey: "SLMountOnly") {
      exit(0)
    }
  }

  /*
   * Times each change while resting mid list, 15 times each, the kinds taking turns:
   *   insertTop, insertMiddle  ten new rows at the start or in the middle
   *   removeMiddle, removeTop  ten rows taken out there
   *   jump                     scrollToItem to a far row, without animation
   * Each time covers the engine's update call and the layout it causes. The rows the screen
   * builds are made before the clock starts. Logs the median, p95, min and max in milliseconds.
   */
  private func runOps() {
    let scroll = list.view
    let inset = scroll.adjustedContentInset
    scroll.setContentOffset(CGPoint(x: 0, y: max(-inset.top, (scroll.contentSize.height - scroll.bounds.height) / 2)), animated: false)
    scroll.layoutIfNeeded()
    let runs = 15
    var times: [String: [Double]] = [:]
    func timed(_ name: String, _ work: () -> Void) {
      let start = CACurrentMediaTime()
      work()
      scroll.layoutIfNeeded()
      times[name, default: []].append((CACurrentMediaTime() - start) * 1000)
    }
    for run in 0..<runs {
      let middle = rows.count / 2
      let top = make(10)
      timed("insertTop") {
        rows.insert(contentsOf: top, at: 0)
        show(.insert(IndexSet(integersIn: 0..<10)))
      }
      let inMiddle = make(10)
      timed("insertMiddle") {
        rows.insert(contentsOf: inMiddle, at: middle)
        show(.insert(IndexSet(integersIn: middle..<middle + 10)))
      }
      timed("removeMiddle") {
        rows.removeSubrange(middle..<middle + 10)
        show(.delete(IndexSet(integersIn: middle..<middle + 10)))
      }
      timed("removeTop") {
        rows.removeSubrange(0..<10)
        show(.delete(IndexSet(integersIn: 0..<10)))
      }
      let targets = [rows.count * 3 / 4, rows.count / 4, rows.count - 20, 10, rows.count / 2]
      timed("jump") { list.scrollToItem(at: targets[run % targets.count], animated: false) }
      scroll.setContentOffset(CGPoint(x: 0, y: max(-inset.top, (scroll.contentSize.height - scroll.bounds.height) / 2)), animated: false)
      scroll.layoutIfNeeded()
    }
    var result: [String: Any] = ["engine": engine.rawValue, "rows": kind.rawValue, "count": rows.count, "runs": runs]
    for (name, values) in times {
      let sorted = values.sorted()
      result[name] = [
        "median": sorted[sorted.count / 2], "p95": sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))],
        "min": sorted[0], "max": sorted[sorted.count - 1],
      ]
    }
    BenchLog.line("SLOPS", result)
    if UserDefaults.standard.bool(forKey: "SLBenchExit") {
      exit(0)
    }
  }
}

/*
 * The bench screen's root view tells ShadowListKitBench how much of the viewport shows a photo
 * that has not arrived yet, the share of its area that image views without an image cover.
 * The bench counts that share as blank content next to rows that draw nothing.
 */
final class ImageBlankProbe: UIView, ShadowListKitBenchProbe {
  weak var screen: ListScreen?

  func shadowListKit_benchBlankFraction() -> Double {
    guard let scroll = screen?.list?.view else { return 0 }
    let visible = scroll.bounds.inset(by: scroll.adjustedContentInset)
    guard visible.width > 0, visible.height > 0 else { return 0 }
    var missing: CGFloat = 0
    func walk(_ view: UIView, depth: Int) {
      for child in view.subviews where !child.isHidden && child.alpha > 0.01 {
        if BenchWindow.enabled, child is ShadowListUtilsRowView {
          BenchWindow.mounted(child.convert(child.bounds, to: scroll), visible: visible)
        }
        if let image = child as? ShadowListUtilsImageView {
          let shown = image.convert(image.bounds, to: scroll).intersection(visible)
          if image.image == nil, !shown.isNull {
            missing += shown.width * shown.height
          }
        } else if depth < 8 {
          walk(child, depth: depth + 1)
        }
      }
    }
    walk(scroll, depth: 0)
    return Double(min(1, missing / (visible.width * visible.height)))
  }
}

/*
 * -SLBenchWindow 1: how far past the viewport an engine keeps row views in its hierarchy, and
 * how far ahead its prefetching API asks for rows, in viewport heights. The overscan the
 * comparison gives shadowlist comes from these. Logs an [SLWINDOW] line whenever a maximum grows.
 */
enum BenchWindow {
  static let enabled = UserDefaults.standard.bool(forKey: "SLBenchWindow")
  private static var mountedAhead: CGFloat = 0
  private static var prefetchedAhead: CGFloat = 0

  /*
   * A row view's frame and the viewport, both in the scroll view's content.
   */
  static func mounted(_ frame: CGRect, visible: CGRect) {
    let beyond = max(visible.minY - frame.maxY, frame.minY - visible.maxY)
    if beyond > 0, beyond / visible.height > mountedAhead + 0.01 {
      mountedAhead = beyond / visible.height
      log()
    }
  }

  static func prefetched(_ frame: CGRect, in scroll: UIScrollView) {
    guard enabled else { return }
    let visible = scroll.bounds.inset(by: scroll.adjustedContentInset)
    let beyond = max(visible.minY - frame.maxY, frame.minY - visible.maxY)
    if beyond > 0, beyond / visible.height > prefetchedAhead + 0.01 {
      prefetchedAhead = beyond / visible.height
      log()
    }
  }

  private static func log() {
    BenchLog.line("SLWINDOW", ["mountedViewports": Double(mountedAhead), "prefetchedViewports": Double(prefetchedAhead)])
  }
}

/*
 * One JSON line on standard output, for the scripts that read the launch's console.
 */
enum BenchLog {
  static func line(_ tag: String, _ result: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: result, options: .sortedKeys)
    print("[\(tag)] \(String(data: data, encoding: .utf8)!)")
    fflush(stdout)
  }
}

/*
 * CPU time the main thread used, user and system, in seconds.
 */
enum MainThreadClock {
  private static let thread = pthread_mach_thread_np(pthread_self())

  static func cpuSeconds() -> Double {
    var info = thread_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count) }
    }
    guard status == KERN_SUCCESS else { return 0 }
    let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1e6
    let system = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1e6
    return user + system
  }
}
