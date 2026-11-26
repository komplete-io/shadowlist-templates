package com.shadowlist.utils

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkdownTest {
  @Test fun the_step_bridge_replays_every_shared_integer_utf16_fixture() {
    for (entry in Vectors.cases("assistant-steps.json")) {
      val input = entry.getJSONObject("input")
      val positions = input.getJSONArray("positions")
      val steps = ShadowListUtilsCore.stepsOf(input.getString("content"), LongArray(positions.length()) { positions.optLong(it, 0) })
      val expected = entry.getJSONArray("output")
      assertEquals(expected.length(), steps.size)
      steps.forEachIndexed { index, step ->
        val value = expected.getJSONObject(index)
        when (step) {
          is ShadowListUtilsAssistantStep.Text -> {
            assertEquals("text", value.getString("kind"))
            assertEquals(value.getString("text"), step.text)
            assertEquals(value.getInt("at"), step.at)
          }
          is ShadowListUtilsAssistantStep.Calls -> {
            assertEquals("calls", value.getString("kind"))
            val indices = value.getJSONArray("callIndices")
            assertEquals((0 until indices.length()).map { indices.getInt(it) }, step.callIndices.toList())
          }
        }
      }
    }
  }

  @Test fun the_bridge_preserves_embedded_null_characters() {
    val text = "before\u0000after"
    assertEquals(text, ShadowListUtilsCore.trim(text))
  }

  @Test fun the_bridge_replays_shared_url_vectors() {
    for (entry in Vectors.cases("markdown.json")) {
      if (entry.getString("function") != "isSafeUrl") continue
      val url = entry.getJSONObject("input").getString("url")
      assertEquals(entry.getString("name"), entry.getBoolean("output"), ShadowListUtilsCore.isSafeUrl(url))
    }
  }
}
