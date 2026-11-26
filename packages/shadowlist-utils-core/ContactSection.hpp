#pragma once

#include <string>
#include <string_view>

namespace azimgd::shadowlist {

/*
 * The title of the section for names that start with no letter. It sorts after every other
 * section.
 */
constexpr std::string_view SECTION_OTHER_TITLE = "#";

/*
 * The title of the section a contact's name falls in: the first code point of the name after
 * trimming, as UTF-8. An ASCII letter comes back in upper case. A blank name, and a name that
 * starts with an ASCII character that is no letter, gives SECTION_OTHER_TITLE. A first
 * code point outside ASCII comes back as written. The host turns it to upper case when its own
 * string type, which knows every script, calls it a letter, and takes
 * SECTION_OTHER_TITLE for anything else.
 */
std::string sectionInitial(std::string_view name);

}
