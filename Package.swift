// swift-tools-version: 5.9
// AUTO-GENERATED parts (urls + checksums) are updated by
// .github/scripts/patch_package_swift.py when a new release is cut. Manual
// edits to those fields will be overwritten. Add new vendor sections by
// following the "Adding a new vendor" steps in README.md.
//
// Vendor sections are delimited by `// === <vendor-key> ===` marker comments
// (matched literally by the patch script). Keep the markers exactly as-is.

import PackageDescription

let package = Package(
  name: "CamblyVendorBinaries",
  platforms: [.iOS(.v17)],
  products: [
    // One .library per vendor. Each library's targets: list includes every
    // binary target the consumer needs to link transitively — SwiftPM links
    // them all when the consumer asks for the product.

    // === facebook ===
    .library(
      name: "FacebookLogin",
      targets: [
        "FacebookLogin",
        "FacebookCore",
        "FBSDKLoginKit",
        "FBSDKCoreKit",
        "LegacyCoreKit",
        "FBSDKCoreKit_Basics",
      ]
    ),
  ],
  targets: [
    // === facebook ===
    // Source: Cambly/facebook-ios-sdk (Cambly fork of facebook/facebook-ios-sdk)
    // URLs + checksums patched by build-facebook.yml workflow on each release.
    // Placeholder state: url points at a non-existent tag, checksum is 64 zeros
    // — SwiftPM resolve will fail until the first workflow run patches them.
    .binaryTarget(
      name: "FacebookLogin",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FacebookLogin.xcframework.zip",
      checksum: "22c035a0dbbd7de601621a9ab92ec3468fa3f370c0d784b7b970d3a6dd7ef0f6"
    ),
    .binaryTarget(
      name: "FacebookCore",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FacebookCore.xcframework.zip",
      checksum: "3bd9844f152595d92ef969ead539c7d729fe5d7d9859170ea07114e9f35d080e"
    ),
    .binaryTarget(
      name: "FBSDKLoginKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKLoginKit.xcframework.zip",
      checksum: "8b0243aa3a71d869f1c76ba3b5051de4dc6af7b8c1b7f7ae0f08fc0a0fbaba00"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit.xcframework.zip",
      checksum: "eb1aa8fa64d7335895392ec0c0d4d440eb3855b8aa1349ded56761f07c322c67"
    ),
    .binaryTarget(
      name: "LegacyCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/LegacyCoreKit.xcframework.zip",
      checksum: "85f4031cd94b7b202774d05dde480ea2499f2d9ade9e89cdad5c4995c97c9591"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit_Basics",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit_Basics.xcframework.zip",
      checksum: "d30926992d29141a9f3622e459000321804e831d81215b46c7f991330467485d"
    ),
  ]
)
