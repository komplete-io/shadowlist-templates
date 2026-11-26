/*
 * Link policy tests: which links may open.
 */

#include "TestFramework.hpp"

#include <shadowlist-utils-core/SafeUrl.hpp>

using namespace slt;
using namespace azimgd::shadowlist;

TEST(only_web_and_mail_links_are_safe_to_open) {
  CHECK(isSafeUrl("https://example.com"));
  CHECK(isSafeUrl("http://example.com"));
  CHECK(isSafeUrl("mailto:someone@example.com"));
  CHECK(isSafeUrl("  HTTPS://EXAMPLE.COM\n"));
  CHECK(!isSafeUrl("tel:+15551234"));
  CHECK(!isSafeUrl("javascript:alert(1)"));
  CHECK(!isSafeUrl("myapp://open"));
  CHECK(!isSafeUrl("see https://example.com"));
  CHECK(!isSafeUrl("https"));
  CHECK(!isSafeUrl(""));
}
