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
      checksum: "e328d5ddb0f2762a3d6f0f0039895926771824bc8c3cf859291b329762169e8e"
    ),
    .binaryTarget(
      name: "FacebookCore",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FacebookCore.xcframework.zip",
      checksum: "38037de6aa1564d14218c47f5f0a94edf5e45389cf42e7b641b309f21b500790"
    ),
    .binaryTarget(
      name: "FBSDKLoginKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKLoginKit.xcframework.zip",
      checksum: "9af4e2c0d413badb8d79aba6fabdb458dac7d044b63cd7f60d3e06de92c6491f"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit.xcframework.zip",
      checksum: "d4d00365ced82946f3ab931aca2064bbad46696a4c9345c8f222e908dccba906"
    ),
    .binaryTarget(
      name: "LegacyCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/LegacyCoreKit.xcframework.zip",
      checksum: "93560416c6a55dad348d14ed71ba90d77ca0208522a45131f7fe064b27d07bd2"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit_Basics",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit_Basics.xcframework.zip",
      checksum: "978b4f7fbf795af0f527965eb45a1124bf0b25cc00dab40a275062db7e9e963a"
    ),
  ]
)
