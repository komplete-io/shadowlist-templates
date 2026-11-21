// swift-tools-version:5.9

import PackageDescription

/*
 * The UIKit templates' tests, run with xcodebuild test on an iOS simulator. The templates come
 * from the package at the repo root, and the core and the kit from the engine package it names.
 */
let package = Package(
  name: "ShadowListUtilsTests",
  platforms: [.iOS(.v16)],
  dependencies: [
    .package(name: "shadowlist-templates", path: "../..")
  ],
  targets: [
    .testTarget(
      name: "ShadowListUtilsTests",
      dependencies: [
        .product(name: "ShadowListUtils", package: "shadowlist-templates")
      ],
      path: "Tests/ShadowListUtilsTests"
    )
  ]
)
