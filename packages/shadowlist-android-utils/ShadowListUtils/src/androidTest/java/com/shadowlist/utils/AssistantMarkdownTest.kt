package com.shadowlist.utils

import android.app.Activity
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class ShadowListUtilsAssistantTestActivity : Activity()

class AssistantMarkdownTest {
  @Test fun stable_document_keeps_its_view_while_the_last_block_and_streaming_dot_grow() = withActivity { activity ->
    lateinit var markdown: ShadowListUtilsAssistantMarkdown
    val firstRender = CountDownLatch(1)
    onMain {
      markdown = ShadowListUtilsAssistantMarkdown(activity, "# Title\n\nA reply", testTheme)
      markdown.onHeightChange = { firstRender.countDown() }
      activity.setContentView(FrameLayout(activity).apply { addView(markdown, FrameLayout.LayoutParams(250f.px, -2)) })
    }
    assertTrue(firstRender.await(10, TimeUnit.SECONDS))
    lateinit var first: View
    var previous = 0
    fun height(): Int {
      markdown.measure(View.MeasureSpec.makeMeasureSpec(250f.px, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
      return markdown.measuredHeight
    }
    val nextRender = CountDownLatch(1)
    onMain {
      first = markdown.getChildAt(0)
      previous = height()
      markdown.onHeightChange = { nextRender.countDown() }
      markdown.text += " that keeps growing over several lines with a useful answer for the crew."
    }
    assertTrue(nextRender.await(10, TimeUnit.SECONDS))
    var beforeStreaming = 0
    val streamingRender = CountDownLatch(1)
    onMain {
      assertSame(first, markdown.getChildAt(0))
      assertTrue(height() > previous)
      beforeStreaming = height()
      markdown.onHeightChange = { streamingRender.countDown() }
      markdown.streaming = true
    }
    assertTrue(streamingRender.await(10, TimeUnit.SECONDS))
    onMain { assertTrue(height() > beforeStreaming) }
  }

  @Test fun unsafe_links_are_blocked_and_custom_handlers_get_the_original_target() = onMain {
    val view = ShadowListUtilsAssistantMarkdown(testContext, "[Call](tel:+123)", testTheme)
    assertFalse(view.open("tel:+123"))
    var target: String? = null
    view.onOpenLink = { target = it }
    assertTrue(view.open("  tel:+123  "))
    assertEquals("  tel:+123  ", target)
  }

  @Test fun code_waits_for_a_closed_fence_and_copied_state_resets_after_delay_and_detach() = withActivity { activity ->
    lateinit var view: ShadowListUtilsAssistantMarkdown
    lateinit var container: FrameLayout
    val partialRender = CountDownLatch(1)
    onMain {
      view = ShadowListUtilsAssistantMarkdown(activity, theme = testTheme)
      view.onHeightChange = { partialRender.countDown() }
      view.update("```swift\nlet text = 1", true)
      container = FrameLayout(activity)
      container.addView(view, FrameLayout.LayoutParams(250f.px, -2))
      activity.setContentView(container)
    }
    assertTrue(partialRender.await(10, TimeUnit.SECONDS))
    val closedRender = CountDownLatch(1)
    onMain {
      assertEquals(View.GONE, copyButton(view).visibility)
      view.onHeightChange = { closedRender.countDown() }
      view.update("```swift\nlet text = 1\n```", false)
    }
    assertTrue(closedRender.await(10, TimeUnit.SECONDS))
    lateinit var button: View
    onMain {
      button = copyButton(view)
      var copied: String? = null
      view.onCopyCode = { copied = it }
      button.performClick()
      assertEquals("let text = 1", copied)
      assertEquals("Copied", button.contentDescription)
    }
    Thread.sleep(1650)
    onMain {
      assertEquals("Copy code", button.contentDescription)
      button.performClick()
      assertEquals("Copied", button.contentDescription)
      container.removeView(view)
      assertEquals("Copy code", button.contentDescription)
    }
  }

  private fun copyButton(view: View): View = descendants(view).first { it.contentDescription == "Copy code" }

  private fun descendants(view: View): Sequence<View> = sequence {
    yield(view)
    if (view is ViewGroup) for (index in 0 until view.childCount) yieldAll(descendants(view.getChildAt(index)))
  }

  private fun withActivity(block: (Activity) -> Unit) {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context = instrumentation.context
    val activity = instrumentation.startActivitySync(Intent().setClassName(context.packageName,
      ShadowListUtilsAssistantTestActivity::class.java.name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    try { block(activity) } finally { onMain { activity.finish() } }
  }
}
