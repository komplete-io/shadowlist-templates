#include <shadowlist-utils-core/SafeUrl.hpp>

#include <shadowlist-utils-core/Text.hpp>

#include <cstddef>

namespace azimgd::shadowlist {

namespace {

constexpr std::string_view SAFE_URL_SCHEMES[] = {"http:", "https:", "mailto:"};

char lowerAscii(char letter) {
  return letter >= 'A' && letter <= 'Z' ? static_cast<char>(letter - 'A' + 'a') : letter;
}

}

bool isSafeUrl(std::string_view url) {
  std::string_view trimmed = trim(url);
  for (std::string_view scheme : SAFE_URL_SCHEMES) {
    if (trimmed.size() < scheme.size()) {
      continue;
    }
    bool matches = true;
    for (std::size_t index = 0; index < scheme.size() && matches; ++index) {
      matches = lowerAscii(trimmed[index]) == scheme[index];
    }
    if (matches) {
      return true;
    }
  }
  return false;
}

}
