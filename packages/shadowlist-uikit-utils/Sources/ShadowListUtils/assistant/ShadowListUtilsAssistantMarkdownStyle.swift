import EnrichedMarkdown
import UIKit

/*
 * The only mapping from template tokens to upstream renderer styles. Used for drawing and sizing.
 */
enum ShadowListUtilsAssistantMarkdownStyle {
  static func configuration(_ theme: ShadowListUtilsTheme) -> MarkdownStyleConfiguration {
    let scale = ShadowListUtilsPlatform.textScale
    let colors = theme.colors
    func element(_ text: ShadowListUtilsTextStyle, color: UIColor) -> ElementStyle {
      ElementStyle(font: .systemFont(ofSize: text.fontSize * scale, weight: text.weight),
        foregroundColor: color, marginTop: 0, marginBottom: theme.spacing.md,
        lineHeight: text.lineHeight * scale)
    }
    var config = MarkdownStyleConfiguration.baseline()
    config.paragraph = element(theme.typography.body, color: colors.label)
    for level in 1...6 {
      let text = level == 1 ? theme.typography.title2 : level == 2 ? theme.typography.title3 : theme.typography.headline
      config.setHeadingStyle(element(text, color: colors.label), for: level)
    }
    config.link.foregroundColor = colors.accent
    config.link.underline = true
    config.code.font = .monospacedSystemFont(ofSize: theme.typography.subhead.fontSize * scale, weight: .regular)
    config.code.foregroundColor = colors.label
    config.code.backgroundColor = colors.fill
    config.codeBlock = CodeBlockStyle(font: .monospacedSystemFont(ofSize: 14 * scale, weight: .regular),
      foregroundColor: colors.label, backgroundColor: colors.elevated, marginTop: 0, marginBottom: theme.spacing.md,
      lineHeight: 20 * scale, padding: theme.spacing.md, borderColor: colors.separator,
      cornerRadius: theme.radius.sm, headerForegroundColor: colors.secondaryLabel)
    config.blockquote = BlockquoteStyle(font: config.paragraph.font, foregroundColor: colors.secondaryLabel,
      marginTop: 0, marginBottom: theme.spacing.md, lineHeight: config.paragraph.lineHeight,
      borderColor: colors.separator, borderWidth: 3, gapWidth: theme.spacing.md)
    config.list.font = config.paragraph.font
    config.list.foregroundColor = colors.label
    config.list.lineHeight = config.paragraph.lineHeight
    config.list.marginTop = 0
    config.list.marginBottom = theme.spacing.md
    config.list.bulletColor = colors.secondaryLabel
    config.list.markerColor = colors.secondaryLabel
    config.taskList.checkedColor = colors.accent
    config.taskList.borderColor = colors.separator
    config.taskList.checkedTextColor = colors.secondaryLabel
    config.taskList.checkmarkColor = colors.background
    config.thematicBreak = ThematicBreakStyle(color: colors.separator, height: ShadowListUtilsTheme.hairline,
      marginTop: 0, marginBottom: theme.spacing.md)
    let table = theme.typography.subhead
    config.table = TableStyle(font: .systemFont(ofSize: table.fontSize * scale), foregroundColor: colors.label,
      lineHeight: table.lineHeight * scale, headerFont: .systemFont(ofSize: table.fontSize * scale, weight: .semibold),
      headerTextColor: colors.label, headerBackgroundColor: colors.elevated,
      rowEvenBackgroundColor: colors.background, rowOddBackgroundColor: colors.fill,
      borderColor: colors.separator, cornerRadius: theme.radius.sm,
      cellPaddingHorizontal: theme.spacing.md, cellPaddingVertical: theme.spacing.md,
      marginTop: 0, marginBottom: theme.spacing.md)
    return config
  }
}
