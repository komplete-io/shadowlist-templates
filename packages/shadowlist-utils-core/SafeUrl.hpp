#pragma once

#include <string_view>

namespace azimgd::shadowlist {

/*
 * Whether a link may open: http, https and mailto only, in any letter case. Links in a reply
 * come from model output, and a phone, message or deep link could start an action the reader
 * never asked for.
 */
bool isSafeUrl(std::string_view url);

}
