import ShadowListKit
import UIKit

/*
 * An empty-state overlay; it never contributes rows to the transcript's content size.
 */
public final class ShadowListUtilsAssistantEmpty: UIView {
  public var suggestions: [ShadowListUtilsAssistantSuggestion] = [] { didSet { rebuildSuggestions() } }
  public var onSelectSuggestion: ((ShadowListUtilsAssistantSuggestion) -> Void)? { didSet { buttons.forEach { $0.isEnabled = onSelectSuggestion != nil } } }
  public var labels = ShadowListUtilsAssistantLabels() { didSet { setNeedsLayout(); invalidateIntrinsicContentSize() } }
  public let theme: ShadowListUtilsTheme
  private let mark = UIImageView(image: ShadowListUtilsSparkleIcon.image(size: 28))
  private let title = ShadowListKitTextView(frame: .zero)
  private let subtitle = ShadowListKitTextView(frame: .zero)
  private let rows = UIView()
  private var separators: [UIView] = []
  private var buttons: [UIButton] = []
  private var measuredWidth: CGFloat = -1
  public init(theme: ShadowListUtilsTheme = .system) {
    self.theme = theme
    super.init(frame: .zero)
    mark.backgroundColor = theme.colors.accent; mark.tintColor = theme.colors.onAccent
    mark.contentMode = .center; mark.layer.cornerRadius = min(theme.radius.pill, (theme.tapTarget + theme.spacing.md) / 2)
    rows.backgroundColor = theme.colors.elevated; rows.layer.cornerRadius = theme.grouped.radius; rows.clipsToBounds = true
    addSubview(rows)
    addSubview(mark); addSubview(title); addSubview(subtitle)
    title.isAccessibilityElement = true; title.accessibilityTraits = .header
    subtitle.isAccessibilityElement = true
  }
  @available(*, unavailable)
  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  private func rebuildSuggestions() {
    buttons.forEach { $0.removeFromSuperview() }
    separators.forEach { $0.removeFromSuperview() }; separators = []
    let theme = self.theme
    buttons = suggestions.map { suggestion in
      let button = UIButton(type: .system)
      var configuration = UIButton.Configuration.plain()
      configuration.title = suggestion.title; configuration.subtitle = suggestion.description ?? suggestion.prompt
      configuration.titleAlignment = .leading
      configuration.titlePadding = theme.spacing.xxs
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { _ in
        AttributeContainer(theme.typography.subhead.with(.semibold).attributedString(" ", color: theme.colors.label).attributes(at: 0, effectiveRange: nil))
      }
      configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { _ in
        AttributeContainer(theme.typography.footnote.attributedString(" ", color: theme.colors.secondaryLabel).attributes(at: 0, effectiveRange: nil))
      }
      configuration.baseForegroundColor = theme.colors.label
      configuration.contentInsets = NSDirectionalEdgeInsets(top: theme.spacing.md, leading: theme.grouped.rowInset, bottom: theme.spacing.md, trailing: theme.grouped.rowInset)
      configuration.titleLineBreakMode = .byWordWrapping
      configuration.subtitleLineBreakMode = .byWordWrapping
      button.configuration = configuration
      button.backgroundColor = theme.colors.elevated
      button.contentHorizontalAlignment = .leading
      button.contentVerticalAlignment = .top
      button.accessibilityLabel = suggestion.title; button.accessibilityHint = suggestion.description ?? suggestion.prompt
      button.isEnabled = onSelectSuggestion != nil
      button.addAction(UIAction { [weak self] _ in self?.select(suggestion) }, for: .touchUpInside)
      button.titleLabel?.numberOfLines = 0
      rows.addSubview(button)
      let separator = UIView(); separator.backgroundColor = theme.colors.separator
      rows.addSubview(separator); separators.append(separator)
      return button
    }
    invalidateIntrinsicContentSize(); setNeedsLayout()
  }
  func select(_ suggestion: ShadowListUtilsAssistantSuggestion) { onSelectSuggestion?(suggestion) }

  public override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: layout(width: max(1, bounds.width), apply: false)) }
  public override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: layout(width: size.width, apply: false)) }
  public override func layoutSubviews() {
    super.layoutSubviews()
    if measuredWidth != bounds.width {
      measuredWidth = bounds.width
      invalidateIntrinsicContentSize()
    }
    _ = layout(width: bounds.width, apply: true)
  }
  private func layout(width: CGFloat, apply: Bool) -> CGFloat {
    let spacing = theme.spacing
    let inner = max(1, width - 2 * spacing.lg)
    let heading = theme.typography.title2.layout(labels.emptyTitle, width: inner, maxLines: 0, scaled: true, alignment: .center)
    let detail = theme.typography.subhead.layout(labels.emptySubtitle, width: inner, maxLines: 0, scaled: true, alignment: .center)
    var y = spacing.xxl
    let markSize = theme.tapTarget + spacing.md
    if apply { mark.frame = CGRect(x: ShadowListUtilsPlatform.floorToPixel((width - markSize) / 2), y: y, width: markSize, height: markSize) }
    y += markSize + spacing.lg
    if apply {
      title.show(heading, theme.colors.label); title.accessibilityLabel = labels.emptyTitle
      title.frame = CGRect(x: spacing.lg, y: y, width: inner, height: heading.size.height)
    }
    y += heading.size.height
    if !labels.emptySubtitle.isEmpty {
      y += spacing.xs
      if apply {
        subtitle.show(detail, theme.colors.secondaryLabel); subtitle.accessibilityLabel = labels.emptySubtitle
        subtitle.frame = CGRect(x: spacing.lg, y: y, width: inner, height: detail.size.height)
      }
      y += detail.size.height
    }
    if apply { subtitle.isHidden = labels.emptySubtitle.isEmpty }
    if apply { rows.isHidden = suggestions.isEmpty }
    guard !suggestions.isEmpty else { return y + spacing.xxl }
    y += spacing.xxl
    let rowsTop = y
    for (index, item) in suggestions.enumerated() {
      if index > 0 { y += ShadowListUtilsTheme.hairline }
      let textWidth = max(1, inner - 2 * theme.grouped.rowInset)
      let height = max(theme.grouped.rowHeight,
        theme.typography.subhead.with(.semibold).layout(item.title, width: textWidth).size.height
          + spacing.xxs + theme.typography.footnote.layout(item.description ?? item.prompt, width: textWidth, maxLines: 2).size.height + 2 * spacing.md)
      if apply {
        buttons[index].frame = CGRect(x: 0, y: y - rowsTop, width: inner, height: height)
        separators[index].isHidden = index == 0
        separators[index].frame = CGRect(x: 0, y: y - rowsTop - ShadowListUtilsTheme.hairline, width: inner, height: ShadowListUtilsTheme.hairline)
      }
      y += height
    }
    if apply { rows.frame = CGRect(x: spacing.lg, y: rowsTop, width: inner, height: y - rowsTop) }
    return y + spacing.xxl
  }
}
