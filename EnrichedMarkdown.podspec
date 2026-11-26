require "json"

versions = JSON.parse(File.read(File.join(__dir__, "packages", "shadowlist-uikit-utils", "version.json")))

Pod::Spec.new do |s|
  s.name = "EnrichedMarkdown"
  s.version = versions["version"]
  s.summary = "Native UIKit and SwiftUI Markdown rendering."
  s.homepage = "https://github.com/software-mansion/enriched-markdown"
  s.license = { :type => "MIT", :file => "packages/enriched-markdown-uikit/LICENSE" }
  s.authors = "Software Mansion"
  s.platforms = { :ios => "16.0" }
  s.source = { :git => "https://github.com/komplete-io/shadowlist-templates.git", :tag => "v#{s.version}" }
  s.swift_version = "5.9"
  s.source_files = "packages/enriched-markdown-uikit/Sources/EnrichedMarkdown/**/*.swift"
  s.frameworks = "UIKit", "SwiftUI"
  s.dependency "EnrichedMarkdownCppShim", "= #{s.version}"
  # Upstream uses Swift 5.9 package access for its optional plugin seams.
  s.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "$(inherited) -package-name EnrichedMarkdown" }
end
