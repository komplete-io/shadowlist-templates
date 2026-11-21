require "json"

# The pod's version and the ShadowListKit version it builds on. Package.swift reads the same file.
versions = JSON.parse(File.read(File.join(__dir__, "packages", "shadowlist-uikit-utils", "version.json")))

Pod::Spec.new do |s|
  s.name         = "ShadowListUtils"
  s.version      = versions["version"]
  s.summary      = "Themed list templates for ShadowListKit."
  s.description  = "ShadowListUtils is the templates package for ShadowListKit on UIKit: a theme, rows, primitives and " \
                   "the Masonry, Feed, Reorder, Snap, Nested, Contacts, Inbox, Chat, Activity and Poll lists."
  s.homepage     = "https://github.com/komplete-io/shadowlist-templates"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "azimgd" => "me@azimgd.com" }
  s.platforms    = { :ios => "16.0" }
  s.source       = { :git => "https://github.com/komplete-io/shadowlist-templates.git", :tag => "v#{s.version}" }
  s.swift_version = "5.9"

  s.dependency "ShadowListKit", "~> #{versions["shadowlist"]}"

  # The C++ the Objective-C++ files call is the template logic in shadowlist-utils-core, which
  # compiles here and not in the ShadowListKit pod.
  s.source_files = [
    "packages/shadowlist-uikit-utils/Sources/**/*.{swift,h,mm}",
    "packages/shadowlist-utils-core/*.{hpp,cpp}",
  ]
  s.public_header_files = "packages/shadowlist-uikit-utils/Sources/ShadowListUtilsCore/include/ShadowListUtilsCore/*.h"
  s.project_header_files = "packages/shadowlist-utils-core/*.hpp"
  s.frameworks   = "UIKit"
  s.libraries    = "c++"

  # The template C++ includes itself as <shadowlist-utils-core/...>, which resolves from this
  # pod's packages folder. The core includes are <shadowlist-core/...>, which resolve from the
  # packages folder of the ShadowListKit pod. An installed ShadowListKit pod sits under
  # PODS_ROOT. A development pod (pod lib lint --include-podspecs, or :path in a Podfile) has
  # no copy there. Set SHADOWLIST_ROOT to its engine checkout for pod install or lint.
  header_search_paths = [
    '"$(PODS_TARGET_SRCROOT)/packages"',
    '"$(PODS_ROOT)/ShadowListKit/packages"',
  ]
  engine_root = ENV["SHADOWLIST_ROOT"]
  if engine_root && !engine_root.empty?
    header_search_paths << "\"#{File.join(File.expand_path(engine_root, __dir__), "packages")}\""
  end

  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => header_search_paths.join(" "),
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
  }
end
