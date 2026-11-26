import ShadowListKit
import UIKit

/*
 * TextKit draws the same line boxes as React Native. The kit retains line heights and hit testing.
 *
 * The TextKit objects that measured the text, often on the layout cache's queue, wait in a shared
 * cache for the first draw, which then draws their glyphs without laying the text out again.
 * A draw takes them out while it uses them and puts them back for the next one. Two draws never
 * share them. The cache holds a bounded number. One evicted is made again at draw.
 */
final class ShadowListUtilsTextLayout: ShadowListKitTextLayout, @unchecked Sendable {
  private static let prepared: NSCache<NSNumber, NSTextStorage> = {
    let cache = NSCache<NSNumber, NSTextStorage>()
    cache.countLimit = preparedLimit
    // A memory warning drops them all. A draw then lays its text out again.
    NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { _ in
      cache.removeAllObjects()
    }
    return cache
  }()

  /*
   * How many laid out texts wait for their draw: the rows the layout cache makes ahead, up to
   * 100 on each side of the viewport, two or three texts each. A short row's TextKit objects take
   * a few kilobytes.
   */
  private static let preparedLimit = 512

  private let layout: ShadowListKitTextLayout
  private let text: NSAttributedString
  private let width: CGFloat
  private let maxLines: Int
  private var measuredSize: CGSize = .zero

  init(layout: ShadowListKitTextLayout, text: NSAttributedString, width: CGFloat, maxLines: Int) {
    self.layout = layout
    self.text = text
    self.width = width
    self.maxLines = maxLines
    super.init()
    let storage = makeTextStorage()
    let manager = storage.layoutManagers[0]
    let container = manager.textContainers[0]
    manager.ensureLayout(for: container)
    let glyphs = manager.glyphRange(for: container)
    let truncated = glyphs.length > 0 && manager.truncatedGlyphRange(inLineFragmentForGlyphAt: NSMaxRange(glyphs) - 1).location != NSNotFound
    let measuredWidth = truncated ? width : min(width, ShadowListUtilsPlatform.ceilToPixel(manager.usedRect(for: container).width))
    measuredSize = CGSize(width: measuredWidth, height: layout.size.height)
    Self.prepared.setObject(storage, forKey: cacheKey)
  }

  deinit {
    Self.prepared.removeObject(forKey: cacheKey)
  }

  /*
   * This layout's entry in the shared cache, removed when the layout goes away, before another
   * object can reuse its address.
   */
  private var cacheKey: NSNumber {
    NSNumber(value: UInt(bitPattern: ObjectIdentifier(self).hashValue))
  }

  override var size: CGSize { measuredSize }
  override var lineCount: UInt { layout.lineCount }
  override func rectForLine(at index: UInt) -> CGRect { layout.rectForLine(at: index) }
  override func characterIndex(at point: CGPoint) -> UInt { layout.characterIndex(at: point) }

  /*
   * Text without a color of its own draws in the given one. The layout manager adds it while it
   * draws, which leaves the text storage, and with it the layout, as it is.
   */
  override func draw(at point: CGPoint, in context: CGContext, color: CGColor) {
    let key = cacheKey
    let storage = Self.prepared.object(forKey: key) ?? makeTextStorage()
    Self.prepared.removeObject(forKey: key)
    guard let manager = storage.layoutManagers.first as? ShadowListUtilsColoringLayoutManager else { return }
    manager.fallbackColor = UIColor(cgColor: color)
    UIGraphicsPushContext(context)
    manager.drawGlyphs(forGlyphRange: manager.glyphRange(for: manager.textContainers[0]), at: point)
    UIGraphicsPopContext()
    manager.fallbackColor = nil
    Self.prepared.setObject(storage, forKey: key)
  }

  private func makeTextStorage() -> NSTextStorage {
    let storage = NSTextStorage(attributedString: text)
    let manager = ShadowListUtilsColoringLayoutManager()
    manager.usesFontLeading = false
    let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    container.maximumNumberOfLines = maxLines
    container.lineBreakMode = maxLines > 0 ? .byTruncatingTail : .byClipping
    manager.addTextContainer(container)
    storage.addLayoutManager(manager)
    return storage
  }
}

/*
 * A layout manager that draws glyphs without a color of their own in fallbackColor.
 */
final class ShadowListUtilsColoringLayoutManager: NSLayoutManager {
  var fallbackColor: UIColor?

  override func showCGGlyphs(
    _ glyphs: UnsafePointer<CGGlyph>, positions: UnsafePointer<CGPoint>, count glyphCount: Int, font: UIFont,
    textMatrix: CGAffineTransform, attributes: [NSAttributedString.Key: Any] = [:], in context: CGContext
  ) {
    // The manager set the context's fill color from the attributes already. Text without one
    // would draw black.
    if attributes[.foregroundColor] == nil, let fallbackColor {
      context.setFillColor(fallbackColor.cgColor)
    }
    super.showCGGlyphs(glyphs, positions: positions, count: glyphCount, font: font, textMatrix: textMatrix, attributes: attributes, in: context)
  }
}
