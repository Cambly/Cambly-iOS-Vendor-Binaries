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
    // Built from Cambly/facebook-ios-sdk@v11.0.1-cambly via the fork's
    // FBSDK*-Dynamic xcodeproj schemes. The Swift wrapper APIs that lived in
    // SPM modules "FacebookCore" / "FacebookLogin" are merged inside the
    // FBSDKCoreKit / FBSDKLoginKit frameworks under xcodeproj-mode build, so
    // there is no separate `FacebookLogin` or `FacebookCore` module exposed
    // by these binaries. Cambly-Swift consumers `import FBSDKLoginKit` /
    // `import FBSDKCoreKit` to get the same APIs.
    .library(
      name: "FBSDKLoginKit",
      targets: [
        "FBSDKLoginKit",
        "FBSDKCoreKit",
        "FBSDKCoreKit_Basics",
      ]
    ),

    // === alamofire ===
    // Built from Alamofire/Alamofire@5.10.2 via its `Alamofire iOS` xcodeproj
    // scheme.
    .library(
      name: "Alamofire",
      targets: ["Alamofire"]
    ),

    // === lottie ===
    // Built from airbnb/lottie-ios@4.5.2 via its `Lottie (iOS)` xcodeproj
    // scheme.
    .library(
      name: "Lottie",
      targets: ["Lottie"]
    ),

    // === keychainaccess ===
    // Built from kishikawakatsumi/KeychainAccess@v4.2.2 via its
    // `Lib/KeychainAccess.xcodeproj` scheme `KeychainAccess`. The library is a
    // thin Swift wrapper around iOS Keychain Services; bundle-id-related
    // behavior is dictated by the consuming app's entitlements + runtime
    // process identity, not by the framework binary itself.
    .library(
      name: "KeychainAccess",
      targets: ["KeychainAccess"]
    ),

    // === devicekit ===
    // Built from devicekit/DeviceKit@5.7.0 via its `DeviceKit.xcodeproj`
    // scheme `DeviceKit`.
    .library(
      name: "DeviceKit",
      targets: ["DeviceKit"]
    ),

    // === sdwebimage ===
    // Built from SDWebImage/SDWebImage@5.21.7 via its `SDWebImage.xcodeproj`
    // scheme `SDWebImage` (the dynamic-framework scheme; the repo also has
    // `SDWebImage XCFramework` / `SDWebImage static` / `SDWebImageMapKit`
    // siblings which we don't need).
    .library(
      name: "SDWebImage",
      targets: ["SDWebImage"]
    ),

    // === sentry ===
    // Built from getsentry/sentry-cocoa@9.13.0 via its `Sentry.xcodeproj`
    // scheme `Sentry`. We don't ship the `SentrySwiftUI` sibling — Cambly
    // only imports the core `Sentry` module.
    .library(
      name: "Sentry",
      targets: ["Sentry"]
    ),

    // === posthog ===
    // Built from PostHog/posthog-ios@3.58.3 via its `PostHog.xcodeproj`
    // scheme `PostHog`.
    .library(
      name: "PostHog",
      targets: ["PostHog"]
    ),

    // === iterable ===
    // Built from Iterable/iterable-swift-sdk@6.7.1 via its `swift-sdk.xcodeproj`
    // scheme `swift-sdk`, which builds the `IterableSDK.framework` target
    // (scheme name and framework name don't match here — see Makefile
    // SCHEME_PRODUCT_PAIRS for how that's handled). The repo also defines a
    // `notification-extension` target producing `IterableAppExtensions.framework`,
    // but Cambly-Swift's notification extensions don't link Iterable today, so
    // we ship only `IterableSDK`.
    .library(
      name: "IterableSDK",
      targets: ["IterableSDK"]
    ),

    // === starscream ===
    // Built from daltoniam/Starscream@4.0.8 via its `Starscream.xcodeproj`
    // scheme `Starscream`.
    .library(
      name: "Starscream",
      targets: ["Starscream"]
    ),
  ],
  targets: [
    // === facebook ===
    // Source: Cambly/facebook-ios-sdk (Cambly fork of facebook/facebook-ios-sdk)
    // URLs + checksums patched by build-facebook.yml workflow on each release.
    .binaryTarget(
      name: "FBSDKLoginKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly-signed/FBSDKLoginKit.xcframework.zip",
      checksum: "6db9e8d284e3ee2e0b08b03f9cc2874759197f2bdb86bd6a5e8520b5d9b2a6c3"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly-signed/FBSDKCoreKit.xcframework.zip",
      checksum: "ccc268aecd66001c09b70c11b8745268299d3e0102ba86ef0e7bf8ce91bb7970"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit_Basics",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly-signed/FBSDKCoreKit_Basics.xcframework.zip",
      checksum: "23a9a022f356d59ab48cfc4bc08d04389a5e97e17d3ec83f08181537bf53a74d"
    ),

    // === alamofire ===
    // Source: Alamofire/Alamofire (public upstream, no fork)
    // URLs + checksums patched by build-alamofire.yml workflow on each release.
    // Placeholder state until first workflow run patches them.
    .binaryTarget(
      name: "Alamofire",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/alamofire-5.12.0-signed/Alamofire.xcframework.zip",
      checksum: "3e05b5187d650b7e4027dce189f36e1d96354f4468da935755fc85c10a2580d3"
    ),

    // === lottie ===
    // Source: airbnb/lottie-ios (public upstream, no fork)
    // URLs + checksums patched by build-lottie.yml workflow on each release.
    .binaryTarget(
      name: "Lottie",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/lottie-4.6.0-signed/Lottie.xcframework.zip",
      checksum: "da80c84569636eb33223ebfb5bc1df163f8b3faedc29f902e90d25fde7c1995f"
    ),

    // === keychainaccess ===
    // Source: kishikawakatsumi/KeychainAccess (public upstream, no fork)
    // URLs + checksums patched by build-keychainaccess.yml on each release.
    .binaryTarget(
      name: "KeychainAccess",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/keychainaccess-v4.2.2/KeychainAccess.xcframework.zip",
      checksum: "5f90fa1664e30e84336d31528fb966486c54dea8ba3057201b0cc97c0f649595"
    ),

    // === devicekit ===
    // Source: devicekit/DeviceKit (public upstream, no fork)
    // URLs + checksums patched by build-devicekit.yml on each release.
    .binaryTarget(
      name: "DeviceKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/devicekit-5.8.0/DeviceKit.xcframework.zip",
      checksum: "b3394b6d9d47d585c4a4996d58693e72546f3d50f91dc8e1424992095e3de237"
    ),

    // === sdwebimage ===
    // Source: SDWebImage/SDWebImage (public upstream, no fork)
    // URLs + checksums patched by build-sdwebimage.yml on each release.
    .binaryTarget(
      name: "SDWebImage",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/sdwebimage-5.21.7/SDWebImage.xcframework.zip",
      checksum: "d7cf0d35f8c7235ce35e0d4a89c2a83418a02b95b210c66c1806f1698e31dd6c"
    ),

    // === sentry ===
    // Source: getsentry/sentry-cocoa (public upstream, no fork)
    // URLs + checksums patched by build-sentry.yml on each release.
    .binaryTarget(
      name: "Sentry",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/sentry-9.13.0/Sentry.xcframework.zip",
      checksum: "34a7637a49856e4c11ce0b3b366d3b9e54c88f7a5ed2586c9d878f76c7dcedef"
    ),

    // === posthog ===
    // Source: PostHog/posthog-ios (public upstream, no fork)
    // URLs + checksums patched by build-posthog.yml on each release.
    .binaryTarget(
      name: "PostHog",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/posthog-3.58.3-codesign-fix/PostHog.xcframework.zip",
      checksum: "51562848b8fbd05576ab0c74dbe3a316d4ddf32e9d3f9b1cbd056e78ed711251"
    ),

    // === iterable ===
    // Source: Iterable/iterable-swift-sdk (public upstream, no fork)
    // URLs + checksums patched by build-iterable.yml on each release.
    .binaryTarget(
      name: "IterableSDK",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/iterable-6.7.1-signed/IterableSDK.xcframework.zip",
      checksum: "895680dae84cdd3b8f379521c2bb092e060ec1fc395641d95be0e8c9b150ebaf"
    ),

    // === starscream ===
    // Source: daltoniam/Starscream (public upstream, no fork)
    // URLs + checksums patched by build-starscream.yml on each release.
    .binaryTarget(
      name: "Starscream",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/starscream-4.0.8-signed/Starscream.xcframework.zip",
      checksum: "1a518aae307811a0ca973afb163c84c99e5646e78185bd8649d1be56c54e9042"
    ),
  ]
)
