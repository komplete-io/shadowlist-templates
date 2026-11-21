// swift-tools-version:5.9

import Foundation
import PackageDescription

/*
 * ShadowListUtils is the templates library on ShadowListKit and builds for iOS only. Its C++
 * calls go through the Objective-C++ target ShadowListUtilsCore into ShadowListUtilsCpp, the
 * template logic in packages/shadowlist-utils-core. ShadowListUtilsCore also builds for macOS,
 * where the AppKit kit uses it without the Swift templates.
 * The template C++ includes itself as <shadowlist-utils-core/...>, which resolves from the
 * packages folder. It includes the engine core as <shadowlist-core/...> through the engine's
 * ShadowListCore product.
 */

/*
 * The engine package. SHADOWLIST_ROOT names a local engine checkout, and a shadowlist folder
 * next to this repository is used when it exists. Both paths resolve from this manifest's
 * folder, not from the working directory. Otherwise the engine comes from its git repository
 * at the version in packages/shadowlist-uikit-utils/version.json, which the podspec reads too.
 * The git fallback needs an engine tag that has the ShadowListCore product. No published tag
 * has it yet.
 * A checkout that SwiftPM or Xcode made for an app sits in a checkouts folder beside the
 * engine's own checkout. It skips the sibling lookup and takes the git dependency.
 */
let packageDirectory = URL(fileURLWithPath: Context.packageDirectory)

func engineDependency() -> Package.Dependency {
  if let root = Context.environment["SHADOWLIST_ROOT"], !root.isEmpty {
    let path = URL(fileURLWithPath: root, relativeTo: packageDirectory).standardizedFileURL.path
    return .package(name: "shadowlist", path: path)
  }
  let parent = packageDirectory.deletingLastPathComponent()
  let sibling = parent.appendingPathComponent("shadowlist")
  if parent.lastPathComponent != "checkouts",
    FileManager.default.fileExists(atPath: sibling.appendingPathComponent("Package.swift").path)
  {
    return .package(name: "shadowlist", path: sibling.path)
  }
  return .package(url: "https://github.com/azimgd/shadowlist", .upToNextMinor(from: engineVersion()))
}

func engineVersion() -> Version {
  let file = packageDirectory.appendingPathComponent("packages/shadowlist-uikit-utils/version.json")
  guard
    let data = try? Data(contentsOf: file),
    let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
    let text = json["shadowlist"],
    let version = Version(text)
  else {
    fatalError("No shadowlist version in \(file.path)")
  }
  return version
}

let package = Package(
  name: "ShadowListUtils",
  platforms: [.iOS(.v16), .macOS(.v14)],
  products: [
    .library(name: "ShadowListUtils", targets: ["ShadowListUtils"]),
    .library(name: "ShadowListUtilsCore", targets: ["ShadowListUtilsCore"]),
  ],
  dependencies: [
    engineDependency()
  ],
  targets: [
    .target(
      name: "ShadowListUtilsCpp",
      dependencies: [
        .product(name: "ShadowListCore", package: "shadowlist")
      ],
      path: "packages/shadowlist-utils-core",
      exclude: ["sources.cmake"],
      // SwiftPM wants an existing public headers folder.
      publicHeadersPath: ".",
      cxxSettings: [
        .headerSearchPath("..")
      ]
    ),
    .target(
      name: "ShadowListUtilsCore",
      dependencies: [
        "ShadowListUtilsCpp",
        .product(name: "ShadowListCore", package: "shadowlist"),
      ],
      path: "packages/shadowlist-uikit-utils/Sources/ShadowListUtilsCore",
      cxxSettings: [
        .headerSearchPath("../../..")
      ]
    ),
    .target(
      name: "ShadowListUtils",
      dependencies: [
        .product(name: "ShadowListKit", package: "shadowlist"),
        "ShadowListUtilsCore",
      ],
      path: "packages/shadowlist-uikit-utils/Sources/ShadowListUtils"
    ),
  ],
  cxxLanguageStandard: .cxx20
)
