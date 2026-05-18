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
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/FacebookLogin.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "FacebookCore",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/FacebookCore.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "FBSDKLoginKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/FBSDKLoginKit.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/FBSDKCoreKit.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "LegacyCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/LegacyCoreKit.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit_Basics",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/FBSDKCoreKit_Basics.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
  ]
)
