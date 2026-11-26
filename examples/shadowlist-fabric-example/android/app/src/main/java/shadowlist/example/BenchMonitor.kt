package shadowlist.example

import android.app.Activity
import android.util.Log
import android.view.Choreographer
import android.view.View
import android.view.ViewGroup
import kotlin.math.max
import kotlin.math.min

/*
 * BENCHMARK-ONLY. The Android side of AppDelegate.swift's BenchViewport, for the list comparison
 * screen (SLRoute Bench). Rows are found by their testID bench-<id>, the same way for any list
 * library. Every frame it scores the frame that was just shown:
 *
 *   [SLBLANK] once a second: frames, frame gaps over 25 ms, blank frames, the mean share of the
 *     list no row covered and the tallest uncovered band in dp, with the uptime in ms so
 *     scroll-bench.sh can keep the windows of each phase.
 *   [SLANCHOR] with SLOps 1: the top three shown rows and their y in dp, whenever they change.
 *   [SLFILLED] once, on the first frame rows cover the whole list. scroll-bench.sh times it from
 *     the [SLMOUNTSTART] line BenchScreen logs, by their logcat timestamps.
 *
 * It runs from Choreographer frame callbacks, so it measures on the frames the UI thread draws.
 */
class BenchMonitor(private val activity: Activity, private val anchors: Boolean) :
    Choreographer.FrameCallback {

  private class Row(val id: String, val top: Int, val bottom: Int)

  private val density = activity.resources.displayMetrics.density
  private var list: View? = null
  private var lastFrameNanos = 0L
  private var windowStartNanos = 0L
  private var frames = 0
  private var slowFrames = 0
  private var blankFrames = 0
  private var blankShare = 0.0
  private var blankBandPx = 0
  private var lastAnchor = ""
  private var filled = false
  private val listLocation = IntArray(2)
  private val rowLocation = IntArray(2)

  fun start() {
    Choreographer.getInstance().postFrameCallback(this)
  }

  override fun doFrame(frameTimeNanos: Long) {
    Choreographer.getInstance().postFrameCallback(this)
    val view = list?.takeIf { it.isAttachedToWindow } ?: findList()
    list = view
    if (view == null) return
    val rows = rows(view)
    if (anchors) logAnchor(view, rows)
    if (!filled && rows.isNotEmpty() && blankPx(view, rows).first == 0) {
      filled = true
      Log.i(TAG, "[SLFILLED] t=${frameTimeNanos / 1_000_000L}")
    }
    if (lastFrameNanos != 0L) {
      frames++
      if (frameTimeNanos - lastFrameNanos > 25_000_000L) slowFrames++
      score(view, rows)
    } else {
      windowStartNanos = frameTimeNanos
    }
    lastFrameNanos = frameTimeNanos
    if (frameTimeNanos - windowStartNanos >= 1_000_000_000L) {
      Log.i(
          TAG,
          String.format(
              java.util.Locale.US,
              "[SLBLANK] t=%d span=%d frames=%d slow=%d blank_frames=%d blank_pct=%.3f blank_band=%.1f",
              frameTimeNanos / 1_000_000L,
              (frameTimeNanos - windowStartNanos) / 1_000_000L,
              frames,
              slowFrames,
              blankFrames,
              if (frames > 0) 100.0 * blankShare / frames else 0.0,
              blankBandPx / density))
      windowStartNanos = frameTimeNanos
      frames = 0
      slowFrames = 0
      blankFrames = 0
      blankShare = 0.0
      blankBandPx = 0
    }
  }

  /*
   * The tallest view that scrolls vertically.
   */
  private fun findList(): View? {
    var best: View? = null
    fun visit(view: View) {
      if ((view.canScrollVertically(1) || view.canScrollVertically(-1)) &&
          view.height > (best?.height ?: 0)) {
        best = view
      }
      if (view is ViewGroup) for (i in 0 until view.childCount) visit(view.getChildAt(i))
    }
    visit(activity.window.decorView)
    return best
  }

  /*
   * Shown rows with their top and bottom in px from the list's top. Doesn't descend into rows
   * or hidden views.
   */
  private fun rows(list: View): List<Row> {
    val rows = ArrayList<Row>()
    list.getLocationInWindow(listLocation)
    fun visit(view: View) {
      if (view.visibility != View.VISIBLE || view.alpha < 0.01f) return
      val testId = view.getTag(com.facebook.react.R.id.react_test_id) as? String
      if (testId != null && testId.startsWith("bench-")) {
        view.getLocationInWindow(rowLocation)
        val top = rowLocation[1] - listLocation[1]
        rows.add(Row(testId.substring(6), top, top + view.height))
        return
      }
      if (view is ViewGroup) for (i in 0 until view.childCount) visit(view.getChildAt(i))
    }
    if (list is ViewGroup) for (i in 0 until list.childCount) visit(list.getChildAt(i))
    return rows
  }

  /*
   * Uncovered px of the list and the tallest uncovered band. Space past the content's ends,
   * where the list can't scroll further, isn't blank.
   */
  private fun blankPx(list: View, rows: List<Row>): Pair<Int, Int> {
    val height = list.height
    if (height <= 0) return Pair(0, 0)
    val covered =
        rows.map { Pair(max(0, it.top), min(height, it.bottom)) }
            .filter { it.first < it.second }
            .sortedBy { it.first }
    var cursor = 0
    var total = 0
    var band = 0
    for ((index, span) in covered.withIndex()) {
      val gap = span.first - cursor
      val atStart = index == 0 && !list.canScrollVertically(-1)
      if (gap > 1 && !atStart) {
        total += gap
        band = max(band, gap)
      }
      cursor = max(cursor, span.second)
    }
    val tail = height - cursor
    if (tail > 1 && (covered.isEmpty() || list.canScrollVertically(1))) {
      total += tail
      band = max(band, tail)
    }
    return Pair(total, band)
  }

  private fun score(list: View, rows: List<Row>) {
    if (list.height <= 0) return
    val (total, band) = blankPx(list, rows)
    if (total > 0) blankFrames++
    blankShare += total.toDouble() / list.height
    blankBandPx = max(blankBandPx, band)
  }

  private fun logAnchor(list: View, rows: List<Row>) {
    val line =
        rows.filter { it.bottom > 0 && it.top < list.height }
            .sortedBy { it.top }
            .take(3)
            .joinToString(",") {
              String.format(java.util.Locale.US, "%s:%.1f", it.id, it.top / density)
            }
    if (line != lastAnchor) {
      lastAnchor = line
      Log.i(TAG, "[SLANCHOR] t=${System.nanoTime() / 1_000_000L} $line")
    }
  }

  companion object {
    const val TAG = "SLBench"
  }
}
