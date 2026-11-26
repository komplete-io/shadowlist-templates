import EnrichedMarkdown
import UIKit

#if canImport(ShadowListUtilsCore)
import ShadowListUtilsCore
#endif

/*
 * A retained native markdown document and the template streaming indicator.
 */
public final class ShadowListUtilsAssistantMarkdown: UIView {
  public var text: String { didSet { if text != oldValue, !defersRender { render() } } }
  public var streaming = false { didSet { if streaming != oldValue, !defersRender { render(); updateMotion() } } }
  public var onCopyCode: ((String) -> Void)?
  public var onOpenLink: ((String) -> Void)?
  public var labels = ShadowListUtilsAssistantLabels() {
    didSet { markdownView.accessibilityLabels.codeBlock.copy = labels.copyCode }
  }
  public let theme: ShadowListUtilsTheme
  var onLayoutChange: (() -> Void)?
  let markdownView: EnrichedMarkdownView
  private let dot = UIView()
  private var defersRender = false

  public init(text: String = "", theme: ShadowListUtilsTheme = .system) {
    self.text = text
    self.theme = theme
    markdownView = EnrichedMarkdownView(markdown: text, style: ShadowListUtilsAssistantMarkdownStyle.configuration(theme))
    super.init(frame: .zero)
    dot.backgroundColor = theme.colors.secondaryLabel
    dot.layer.cornerRadius = 3
    dot.isAccessibilityElement = false
    addSubview(dot)
    addSubview(markdownView)
    markdownView.accessibilityLabels.codeBlock.copy = labels.copyCode
    markdownView.onCodeBlockCopy = { [weak self] in self?.onCopyCode?($0.code) }
    markdownView.onLinkPress = { [weak self] in _ = self?.open($0.absoluteString) }
    markdownView.onHeightChange = { [weak self] in
      self?.setNeedsLayout()
      self?.invalidateIntrinsicContentSize()
      self?.onLayoutChange?()
    }
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    CGSize(width: size.width, height: place(width: size.width))
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    _ = place(width: bounds.width)
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    updateMotion()
  }

  /*
   * Both values in one render. It renders even when neither changed, which re-resolves the
   * fonts after a Dynamic Type reload; the document skips a render that would change nothing.
   */
  func update(text: String, streaming: Bool) {
    let wasStreaming = self.streaming
    defersRender = true
    self.streaming = streaming
    self.text = text
    defersRender = false
    render()
    if wasStreaming != streaming { updateMotion() }
  }

  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
      ShadowListUtilsPlatform.resolve(category: traitCollection.preferredContentSizeCategory, window: window)
      render()
    }
  }

  /*
   * The height of a document at a width, for a row that has no view yet. One document is kept
   * for every measurement, so a streamed reply's next measurement parses only what was added.
   * A document with an image is measured in a view of its own: the kept one would hold the
   * height from before the image loaded until its own load report arrives.
   * UIKit/TextKit measurement must stay on the main thread, including a list's cache misses.
   */
  static func height(text: String, streaming: Bool, width: CGFloat, theme: ShadowListUtilsTheme) -> CGFloat {
    precondition(Thread.isMainThread)
    let style = ShadowListUtilsAssistantMarkdownStyle.configuration(theme)
    if text.contains("![") {
      return EnrichedMarkdownView(markdown: text, style: style, streaming: streaming).fittingHeight(for: width)
    }
    sizer.setMarkdown(text, streaming: streaming, style: style)
    return sizer.fittingHeight(for: width)
  }

  private static let sizer = EnrichedMarkdownView()

  /*
   * Opens a link through the handler, or by default only one the shared link policy allows.
   */
  @discardableResult
  static func open(_ href: String, handler: ((String) -> Void)?) -> Bool {
    if let handler { handler(href); return true }
    if ShadowListUtilsCore.isSafeUrl(href), let url = URL(string: ShadowListUtilsCore.trim(href)) {
      UIApplication.shared.open(url)
      return true
    }
    return false
  }

  @discardableResult
  func open(_ href: String) -> Bool { Self.open(href, handler: onOpenLink) }

  private func updateMotion() {
    dot.layer.removeAnimation(forKey: "pulse")
    guard streaming, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
    let pulse = CABasicAnimation(keyPath: "opacity")
    pulse.fromValue = 0.35
    pulse.toValue = 1
    pulse.duration = 0.8
    pulse.autoreverses = true
    pulse.repeatCount = .infinity
    dot.layer.add(pulse, forKey: "pulse")
  }

  private func render() {
    markdownView.setMarkdown(text, streaming: streaming, style: ShadowListUtilsAssistantMarkdownStyle.configuration(theme))
    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }

  private func place(width: CGFloat) -> CGFloat {
    let height = markdownView.fittingHeight(for: width)
    markdownView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    var y = height + (height > 0 ? theme.spacing.md : 0)
    dot.isHidden = !streaming
    if streaming { dot.frame = CGRect(x: 0, y: y, width: 6, height: 6); y += 6 + theme.spacing.md }
    return streaming ? max(0, y - theme.spacing.md) : height
  }
}
