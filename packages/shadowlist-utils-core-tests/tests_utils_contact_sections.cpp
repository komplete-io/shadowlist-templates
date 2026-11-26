/*
 * Contact section tests: the section a contact's name falls in.
 */

#include "TestFramework.hpp"

#include <shadowlist-utils-core/ContactSection.hpp>

#include <string>

using namespace slt;
using namespace azimgd::shadowlist;

TEST(a_contact_section_is_titled_with_the_first_letter_in_upper_case) {
  CHECK_EQ(sectionInitial("Ada"), std::string("A"));
  CHECK_EQ(sectionInitial("bob"), std::string("B"));
  CHECK_EQ(sectionInitial("z"), std::string("Z"));
}

TEST(a_contact_section_title_skips_the_white_space_before_the_name) {
  CHECK_EQ(sectionInitial("  Bea"), std::string("B"));
  // A no-break space, then a tab.
  CHECK_EQ(sectionInitial("\xC2\xA0\tcy "), std::string("C"));
}

TEST(a_name_that_starts_with_no_letter_falls_in_the_other_section) {
  CHECK_EQ(sectionInitial(""), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("   "), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("42"), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("_x"), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("#1"), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("@home"), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("[x]"), std::string(SECTION_OTHER_TITLE));
  CHECK_EQ(sectionInitial("{x}"), std::string(SECTION_OTHER_TITLE));
}

TEST(a_contact_section_title_outside_ascii_is_left_to_the_host) {
  // U+00E9, and U+1F600 as one code point.
  CHECK_EQ(sectionInitial("\xC3\xA9mile"), std::string("\xC3\xA9"));
  CHECK_EQ(sectionInitial(" \xF0\x9F\x98\x80 Ada"), std::string("\xF0\x9F\x98\x80"));
}
