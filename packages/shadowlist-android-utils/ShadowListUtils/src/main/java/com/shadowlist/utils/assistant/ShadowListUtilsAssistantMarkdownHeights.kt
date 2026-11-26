package com.shadowlist.utils

import android.content.res.Resources
import android.util.LruCache

/*
 * Only heights cross from the UI renderer to background row layout. No Views or mutable spans
 * enter the cache. LruCache synchronizes reads/writes; retained source strings are bounded.
 */
internal object ShadowListUtilsAssistantMarkdownHeights {
  private data class Key(
    val text: String, val streaming: Boolean, val widthPx: Int, val theme: ShadowListUtilsTheme,
    val density: Float, val textScale: Float, val rightToLeft: Boolean,
  )
  private val heights = object : LruCache<Key, Int>(2 * 1024 * 1024) {
    override fun sizeOf(key: Key, value: Int): Int = key.text.length * 2 + 256
  }

  private fun key(text: String, streaming: Boolean, widthPx: Int, theme: ShadowListUtilsTheme) =
    Key(text, streaming, widthPx, theme, Resources.getSystem().displayMetrics.density,
      ShadowListUtilsPlatform.textScale, ShadowListUtilsPlatform.isRightToLeft)

  fun height(text: String, streaming: Boolean, widthPx: Int, theme: ShadowListUtilsTheme): Int {
    heights.get(key(text, streaming, widthPx, theme))?.let { return it }
    // The async renderer replaces this estimate with its actual measured height, then invalidates
    // the row. Do not create Android views on the layout-prefetch thread.
    return if (text.isBlank()) 0 else theme.typography.body.layout(text, widthPx.coerceAtLeast(1)).height
  }

  fun record(text: String, streaming: Boolean, widthPx: Int, theme: ShadowListUtilsTheme, heightPx: Int): Boolean {
    val key = key(text, streaming, widthPx, theme)
    return heights.put(key, heightPx) != heightPx
  }
}
