package com.shadowlist.utils

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.view.animation.LinearInterpolator
import kotlin.math.PI
import kotlin.math.cos

/* Three composited opacity pulses on one lifecycle-owned animator, each a step behind the one before. */
class ShadowListUtilsAssistantTypingIndicator(context: Context, val theme: ShadowListUtilsTheme = ShadowListUtilsTheme.system(context)) : ViewGroup(context) {
  var labels = ShadowListUtilsAssistantLabels()
    set(value) { field = value; contentDescription = value.typing }
  private val dots = List(3) { View(context).apply {
    background = GradientDrawable().apply { setColor(theme.colors.secondaryLabel); cornerRadius = 3.5f.px.toFloat() }
  } }
  private var ready = false
  private var pulse: ValueAnimator? = null
  init { dots.forEach(::addView); isFocusable = true; importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES; contentDescription = labels.typing; ready = true }
  override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
    super.onInitializeAccessibilityNodeInfo(info); info.className = "android.widget.ProgressBar"
  }
  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    setMeasuredDimension(resolveSize(21f.px + 2 * theme.spacing.xs.px, widthMeasureSpec), resolveSize(7f.px + 2 * theme.spacing.sm.px, heightMeasureSpec))
  }
  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    dots.forEachIndexed { index, dot ->
      val x = index * (7f.px + theme.spacing.xs.px)
      val start = if (layoutDirection == LAYOUT_DIRECTION_RTL) width - x - 7f.px else x
      dot.layout(start, theme.spacing.sm.px, start + 7f.px, theme.spacing.sm.px + 7f.px)
    }
  }
  override fun onVisibilityChanged(changedView: View, visibility: Int) {
    super.onVisibilityChanged(changedView, visibility)
    if (ready) { if (isShown && isAttachedToWindow) startPulse() else stopPulse() }
  }
  override fun onAttachedToWindow() { super.onAttachedToWindow(); startPulse() }
  override fun onDetachedFromWindow() { stopPulse(); super.onDetachedFromWindow() }
  private fun stopPulse() { pulse?.cancel(); pulse = null; dots.forEach { it.alpha = 1f } }
  private fun startPulse() {
    stopPulse()
    if (!isShown || !isAttachedToWindow) return
    if (Build.VERSION.SDK_INT >= 26 && !ValueAnimator.areAnimatorsEnabled()) return
    pulse = ValueAnimator.ofFloat(0f, 1f).apply {
      duration = 2 * PULSE_DURATION_MS; repeatCount = ValueAnimator.INFINITE; interpolator = LinearInterpolator()
      addUpdateListener { animator ->
        val time = animator.animatedFraction * duration
        dots.forEachIndexed { index, dot -> dot.alpha = alphaAt(time - index * PULSE_STEP_MS) }
      }
      start()
    }
  }

  private companion object {
    const val PULSE_DURATION_MS = 600L
    const val PULSE_STEP_MS = 160L
    const val DIM_ALPHA = 0.25f

    /*
     * A dot's opacity at time into its cycle: up for one pulse and down for the next, eased like an
     * animator's default interpolator. A time before the cycle's start wraps to its end.
     */
    fun alphaAt(time: Float): Float {
      val period = 2f * PULSE_DURATION_MS
      val cycle = ((time % period + period) % period) / PULSE_DURATION_MS
      val linear = if (cycle <= 1f) cycle else 2f - cycle
      val eased = (cos((linear + 1) * PI) / 2 + 0.5).toFloat()
      return DIM_ALPHA + (1f - DIM_ALPHA) * eased
    }
  }
}
