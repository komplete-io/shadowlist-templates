package com.shadowlist.utils

import android.content.Context
import com.swmansion.enriched.markdown.styles.HeadingStyle
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TableStyle
import kotlin.math.ceil

/*
 * The one mapping from template tokens to EnrichedMarkdown's pixel-based styles.
 */
internal object ShadowListUtilsAssistantMarkdownStyle {
  fun make(context: Context, theme: ShadowListUtilsTheme, labels: ShadowListUtilsAssistantLabels): StyleConfig {
    val defaults = StyleConfig.default(context)
    val colors = theme.colors
    val body = theme.typography.body
    val gap = theme.spacing.md.pxf
    val headings = Array<HeadingStyle?>(7) { level ->
      if (level == 0) null else {
        val token = when (level) { 1 -> theme.typography.title2; 2 -> theme.typography.title3; else -> theme.typography.headline }
        defaults.headingStyles[level]?.copy(fontSize = ceil(token.fontSize.spf), lineHeight = ceil(token.lineHeight.spf),
          fontWeight = weight(token.fontWeight), color = colors.label, marginTop = 0f, marginBottom = gap)
      }
    }
    val table = defaults.tableStyle.copy(
      fontSize = ceil(theme.typography.subhead.fontSize.spf), lineHeight = ceil(theme.typography.subhead.lineHeight.spf),
      fontWeight = weight(theme.typography.subhead.fontWeight), color = colors.label, headerTextColor = colors.label,
      headerBackgroundColor = colors.elevated, rowEvenBackgroundColor = colors.background,
      rowOddBackgroundColor = colors.elevated, borderColor = colors.separator, borderRadius = theme.radius.sm.pxf,
      cellPaddingHorizontal = gap, cellPaddingVertical = theme.spacing.sm.pxf, marginTop = 0f, marginBottom = gap,
    )
    return StyleConfig(
      paragraphStyleDefault = defaults.paragraphStyle.copy(fontSize = ceil(body.fontSize.spf), lineHeight = ceil(body.lineHeight.spf),
        fontWeight = weight(body.fontWeight), color = colors.label, marginTop = 0f, marginBottom = gap),
      headingStyles = headings,
      headingTypefaces = Array(7) { level -> if (level == 0) null else ShadowListUtilsTextStyle.typeface(headings[level]?.fontWeight?.toIntOrNull() ?: 600) },
      linkStyle = defaults.linkStyle.copy(color = colors.accent, underline = true),
      strongStyle = defaults.strongStyle.copy(fontWeight = "600"),
      emphasisStyle = defaults.emphasisStyle,
      strikethroughStyle = defaults.strikethroughStyle,
      underlineStyle = defaults.underlineStyle,
      highlightStyle = defaults.highlightStyle.copy(backgroundColor = colors.accentSoft),
      superscriptStyle = defaults.superscriptStyle,
      subscriptStyle = defaults.subscriptStyle,
      codeStyle = defaults.codeStyle.copy(fontFamily = "monospace", color = colors.label,
        backgroundColor = colors.elevated, borderColor = colors.separator),
      imageStyle = defaults.imageStyle.copy(borderRadius = theme.radius.sm.pxf, marginTop = 0f, marginBottom = gap),
      inlineImageStyle = defaults.inlineImageStyle,
      blockquoteStyle = defaults.blockquoteStyle.copy(fontSize = ceil(body.fontSize.spf), lineHeight = ceil(body.lineHeight.spf),
        fontWeight = weight(body.fontWeight), color = colors.secondaryLabel, borderColor = colors.separator,
        backgroundColor = null, gapWidth = gap, marginTop = 0f, marginBottom = gap),
      listStyle = defaults.listStyle.copy(fontSize = ceil(body.fontSize.spf), lineHeight = ceil(body.lineHeight.spf),
        fontWeight = weight(body.fontWeight), color = colors.label, bulletColor = colors.secondaryLabel,
        markerColor = colors.secondaryLabel, marginTop = 0f, marginBottom = gap),
      taskListStyle = defaults.taskListStyle.copy(checkedColor = colors.accent, borderColor = colors.separator,
        checkmarkColor = colors.onAccent, checkedTextColor = colors.secondaryLabel),
      codeBlockStyle = defaults.codeBlockStyle.copy(fontSize = ceil(14f.spf), lineHeight = ceil(20f.spf),
        color = colors.label, backgroundColor = colors.elevated, borderColor = colors.separator,
        borderRadius = theme.radius.sm.pxf, padding = gap, marginTop = 0f, marginBottom = gap,
        copyLabel = labels.copyCode, copiedLabel = labels.copied, languageFallback = labels.codeLanguageFallback),
      thematicBreakStyle = defaults.thematicBreakStyle.copy(color = colors.separator, height = 1f, marginTop = 0f, marginBottom = gap),
      tableStyle = table,
      tableTypeface = TableStyle.bodyTypeface(context, table),
      tableHeaderTypeface = TableStyle.headerTypeface(context, table),
      spoilerStyle = defaults.spoilerStyle.copy(color = colors.secondaryLabel),
    )
  }

  private fun weight(weight: ShadowListUtilsFontWeight): String = when (weight) {
    ShadowListUtilsFontWeight.REGULAR -> "400"
    ShadowListUtilsFontWeight.SEMIBOLD -> "600"
    ShadowListUtilsFontWeight.BOLD -> "700"
  }
}
