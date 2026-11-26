require "json"

versions = JSON.parse(File.read(File.join(__dir__, "packages", "shadowlist-uikit-utils", "version.json")))

Pod::Spec.new do |s|
  s.name = "EnrichedMarkdownCppShim"
  s.version = versions["version"]
  s.summary = "Vendored Enriched Markdown parser and native Swift C bridge."
  s.homepage = "https://github.com/software-mansion/enriched-markdown"
  s.license = { :type => "MIT", :file => "packages/enriched-markdown-core/LICENSE" }
  s.authors = "Software Mansion"
  s.platforms = { :ios => "16.0" }
  s.source = { :git => "https://github.com/komplete-io/shadowlist-templates.git", :tag => "v#{s.version}" }
  s.source_files = [
    "packages/enriched-markdown-core/{enrmrkd,parser,repair,highlight,latex}/*.{c,cpp,h,hpp}",
    "packages/enriched-markdown-uikit/cpp/*.{h,cpp}",
  ]
  s.public_header_files = "packages/enriched-markdown-uikit/cpp/*.h"
  s.private_header_files = "packages/enriched-markdown-core/{enrmrkd,parser,repair,highlight,latex}/*.{h,hpp}"
  s.libraries = "c++"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) ENRMRKD_USE_UTF8=1",
    "HEADER_SEARCH_PATHS" => ["enrmrkd", "parser", "repair", "highlight", "latex"].map { |folder|
      "\"$(PODS_TARGET_SRCROOT)/packages/enriched-markdown-core/#{folder}\""
    }.join(" "),
  }
end
