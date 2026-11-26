import UIKit

/// A selectable, non-scrolling UIKit markdown document. Use onHeightChange to invalidate a
/// containing row after an image loads. All methods and callbacks belong to the main thread.
public final class EnrichedMarkdownView: UIView {
    public private(set) var markdown = ""
    public private(set) var parsingOptions: MarkdownParsingOptions
    public private(set) var style: MarkdownStyleConfiguration
    public private(set) var isStreaming = false
    public var onLinkPress: ((URL) -> Void)? {
        didSet {
            coordinator.onLinkPress = onLinkPress
            textView.onLinkPress = onLinkPress
        }
    }
    public var onCodeBlockCopy: ((CodeBlockCopy) -> Void)? {
        didSet { textView.onCodeBlockCopy = onCodeBlockCopy }
    }
    public var onHeightChange: (() -> Void)?
    public var accessibilityLabels: MarkdownAccessibilityLabels = .default {
        didSet { textView.accessibilityLabels = accessibilityLabels }
    }

    private let textView = MarkdownTextView()
    private let coordinator = MarkdownTextViewRepresentable.Coordinator()
    private let document = UIKitStreamingDocument()
    private var hasRendered = false
    private var renderedDirection: UIUserInterfaceLayoutDirection?
    private var revealedSpoilers: Set<Int> = []

    public init(
        markdown: String = "",
        parsingOptions: MarkdownParsingOptions = .commonMark,
        style: MarkdownStyleConfiguration = .baseline(),
        streaming: Bool = false
    ) {
        self.parsingOptions = parsingOptions
        self.style = style
        super.init(frame: .zero)
        addSubview(textView)
        textView.delegate = coordinator
        textView.onSpoilerTap = { [weak self] range in
            self?.revealSpoiler(in: range)
        }
        textView.onAttachmentLayoutChange = { [weak self] in
            guard let self else { return }
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
            self.onHeightChange?()
        }
        setMarkdown(markdown, streaming: streaming)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Accepts append updates, replacement text, and stream completion. The text view and
    /// parsed finished blocks are retained; TextKit reflows the resulting attributed document.
    public func setMarkdown(
        _ markdown: String,
        streaming: Bool = false,
        parsingOptions: MarkdownParsingOptions? = nil,
        style: MarkdownStyleConfiguration? = nil
    ) {
        let options = parsingOptions ?? self.parsingOptions
        let config = style ?? self.style
        let direction = effectiveUserInterfaceLayoutDirection
        guard !hasRendered || self.markdown != markdown || isStreaming != streaming
            || self.parsingOptions != options || self.style != config || renderedDirection != direction else { return }
        // Ordinals survive style changes and append-only stream updates, including completion.
        // A replacement document or different parsing options starts concealed.
        let continuesStream = (isStreaming || streaming) && markdown.hasPrefix(self.markdown)
        if self.parsingOptions != options || (self.markdown != markdown && !continuesStream) {
            revealedSpoilers.removeAll()
        }
        self.markdown = markdown
        self.parsingOptions = options
        self.style = config
        isStreaming = streaming
        renderedDirection = direction
        hasRendered = true
        let ast = document.update(markdown, options: options, streaming: streaming)
        let annotated = SourceOffsetAnnotator.annotate(ast, source: document.source)
        let rendered = AttributedRenderer(config: config, layoutDirection: direction, codeBlockLayout: .scrollable)
            .renderRoot(annotated)
        coordinator.source = RenderedSource(markdown: document.source, options: options)
        textView.styleConfig = config
        applyRenderedText(SpoilerInteraction.revealing(in: rendered, ordinals: revealedSpoilers) ?? rendered)
    }

    private func revealSpoiler(in range: NSRange) {
        guard let attributedText = textView.attributedText,
            let ordinal = SpoilerInteraction.spoilerRanges(in: attributedText)
                .firstIndex(where: { NSLocationInRange(range.location, $0) }),
            let revealed = SpoilerInteraction.revealing(in: attributedText, ordinals: [ordinal])
        else { return }
        revealedSpoilers.insert(ordinal)
        applyRenderedText(revealed)
    }

    private func applyRenderedText(_ rendered: NSAttributedString) {
        let selection = textView.selectedRange
        textView.setMarkdownAttributedText(rendered)
        if selection.length > 0, NSMaxRange(selection) <= rendered.length {
            textView.selectedRange = selection
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    public func fittingHeight(for width: CGFloat) -> CGFloat {
        guard width > 0, !markdown.isEmpty else { return 0 }
        return ceil(textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: fittingHeight(for: size.width))
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fittingHeight(for: bounds.width))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if renderedDirection != effectiveUserInterfaceLayoutDirection {
            setMarkdown(markdown, streaming: isStreaming)
        }
        textView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: fittingHeight(for: bounds.width))
    }
}
