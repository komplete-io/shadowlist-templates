package com.shadowlist.utils

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.view.View
import android.view.ViewGroup
import com.swmansion.enriched.markdown.CodeBlockLayout
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.MarkdownOptions
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig

/*
 * One upstream document view and the streaming dot under it. EnrichedMarkdown owns parsing,
 * streaming repair, accessibility and stable segment views: its segment reconciler keeps
 * finished blocks during streaming, and the shared C++ session repairs the partial tail before
 * parsing it.
 */
class ShadowListUtilsAssistantMarkdown(
  context: Context,
  text: String = "",
  val theme: ShadowListUtilsTheme = ShadowListUtilsTheme.system(context),
) : ViewGroup(context) {
  var text = text
    set(value) { if (field != value) { field = value; updateContent() } }
  var streaming = false
    set(value) { if (field != value) { field = value; updateContent(); updateMotion() } }
  var onCopyCode: ((String) -> Unit)? = null
  var onOpenLink: ((String) -> Unit)? = null
  var labels = ShadowListUtilsAssistantLabels()
    set(value) { if (field != value) { field = value; updateContent() } }
  internal var onHeightChange: (() -> Unit)? = null

  // What the renderer was last given. A change of text and streaming in one update renders once.
  private var shownText = ""
  private var shownStreaming = false
  private var shownLabels = ShadowListUtilsAssistantLabels()
  private var updating = false
  private var renderReady = false
  private var measuring = false
  private var documentHeight = 0
  private var reportedWidth = -1
  private var reportedHeight = -1
  private val renderer = EnrichedMarkdown(context)
  private val dot = View(context).apply {
    background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(theme.colors.secondaryLabel) }
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
  }
  private var pulse: ObjectAnimator? = null
  private val reportHeight = Runnable {
    if (renderReady && measuredWidth > 0 && isAttachedToWindow) {
      measuring = true
      renderer.measure(MeasureSpec.makeMeasureSpec(measuredWidth, MeasureSpec.EXACTLY),
        MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
      measuring = false
      // A height the bounded cache lost, like one of a cell that was detached, is reported again.
      val recorded = ShadowListUtilsAssistantMarkdownHeights.record(shownText, shownStreaming, measuredWidth, theme, renderer.measuredHeight)
      if (recorded || reportedWidth != measuredWidth || reportedHeight != renderer.measuredHeight) {
        reportedWidth = measuredWidth
        reportedHeight = renderer.measuredHeight
        requestLayout()
        onHeightChange?.invoke()
      }
    }
  }

  init {
    addView(renderer)
    addView(dot)
    renderer.setMarkdownStyle(ShadowListUtilsAssistantMarkdownStyle.make(context, theme, labels))
    renderer.setOptions(MarkdownOptions.Default)
    renderer.setCodeBlockLayout(CodeBlockLayout.Scrollable)
    renderer.setEnableTaskListItemToggle(false)
    renderer.setSelectionColor(theme.colors.accentSoft)
    renderer.setSelectionHandleColor(theme.colors.accent)
    renderer.setSelectionMenuConfig(SelectionMenuConfig(copyAsMarkdown = false, copyImageUrl = false))
    renderer.setOnLinkPressCallback { open(it) }
    renderer.setOnCodeBlockCopyCallback { onCopyCode?.invoke(it.code) }
    renderer.onContentRendered = { renderReady = true; requestLayout(); scheduleHeightReport() }
    updateContent()
  }

  /*
   * Text and streaming in one render, for a caller that changes both at once.
   */
  internal fun update(text: String, streaming: Boolean) {
    updating = true
    this.text = text
    this.streaming = streaming
    updating = false
    updateContent()
    updateMotion()
  }

  private fun updateContent() {
    if (updating) return
    requestLayout()
    if (shownText == text && shownStreaming == streaming && shownLabels == labels) return
    val style = if (shownLabels != labels) ShadowListUtilsAssistantMarkdownStyle.make(context, theme, labels) else renderer.markdownStyle
    shownLabels = labels
    val styleChanged = renderer.markdownStyle != style
    if (shownText == text && shownStreaming == streaming && !styleChanged) return
    renderReady = false
    reportedWidth = -1
    reportedHeight = -1
    if (styleChanged) renderer.setMarkdownStyle(style)
    shownText = text
    shownStreaming = streaming
    renderer.setStreaming(streaming)
    renderer.setMarkdownContent(text)
  }

  override fun requestLayout() {
    super.requestLayout()
    // Images can change intrinsic size after the parser's render callback has run.
    if (renderReady && !measuring) scheduleHeightReport()
  }

  private fun scheduleHeightReport() {
    removeCallbacks(reportHeight)
    post(reportHeight)
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val width = MeasureSpec.getSize(widthMeasureSpec)
    measuring = true
    renderer.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
    measuring = false
    documentHeight = if (renderReady) renderer.measuredHeight
      else ShadowListUtilsAssistantMarkdownHeights.height(shownText, shownStreaming, width, theme)
    val height = documentHeight + if (streaming) 6f.px + (if (documentHeight > 0) theme.spacing.md.px else 0) else 0
    setMeasuredDimension(width, resolveSize(height, heightMeasureSpec))
    if (renderReady) scheduleHeightReport()
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    renderer.layout(0, 0, right - left, renderer.measuredHeight)
    val y = documentHeight + if (documentHeight > 0) theme.spacing.md.px else 0
    dot.visibility = if (streaming) VISIBLE else GONE
    dot.layout(0, y, 6f.px, y + 6f.px)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // The renderer renders again only for a style that changed. Without one, the height is
    // measured again at the new size.
    val style = ShadowListUtilsAssistantMarkdownStyle.make(context, theme, labels)
    if (style != renderer.markdownStyle) {
      renderReady = false
      renderer.setMarkdownStyle(style)
    } else {
      reportedWidth = -1
      if (renderReady) scheduleHeightReport()
    }
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (renderReady) scheduleHeightReport()
    updateMotion()
  }

  override fun onDetachedFromWindow() {
    removeCallbacks(reportHeight)
    pulse?.cancel()
    pulse = null
    super.onDetachedFromWindow()
  }

  internal fun open(href: String): Boolean {
    onOpenLink?.let { it(href); return true }
    if (!ShadowListUtilsCore.isSafeUrl(href)) return false
    return try {
      context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(ShadowListUtilsCore.trim(href))).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
      true
    } catch (_: ActivityNotFoundException) { false }
  }

  private fun updateMotion() {
    pulse?.cancel()
    pulse = null
    if (!streaming || !isAttachedToWindow || (Build.VERSION.SDK_INT >= 26 && !ValueAnimator.areAnimatorsEnabled())) return
    pulse = ObjectAnimator.ofFloat(dot, "alpha", 0.35f, 1f).apply {
      duration = 800
      repeatMode = ValueAnimator.REVERSE
      repeatCount = ValueAnimator.INFINITE
      start()
    }
  }
}
