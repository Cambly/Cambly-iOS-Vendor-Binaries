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
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKLoginKit.xcframework.zip",
      checksum: "d3aeffd6b1ff2317351691ce5a1edf8da8f98471f2517d0778157f93d01b5bd2"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit.xcframework.zip",
      checksum: "1ad86bedfdbf8ee0052a9bf8f691876e469db5e5de6d5e23052bd64723757c2c"
    ),
    .binaryTarget(
      name: "FBSDKCoreKit_Basics",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/facebook-v11.0.1-cambly/FBSDKCoreKit_Basics.xcframework.zip",
      checksum: "cdb427ed40c5466e36152808c6ab2e92cd3a7dfb9f150bef7d132cbfdf6c4682"
    ),

    // === alamofire ===
    // Source: Alamofire/Alamofire (public upstream, no fork)
    // URLs + checksums patched by build-alamofire.yml workflow on each release.
    // Placeholder state until first workflow run patches them.
    .binaryTarget(
      name: "Alamofire",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/alamofire-5.12.0/Alamofire.xcframework.zip",
      checksum: "0a2a215884c6c4015b584c5ecf592a1540b566597652509f724d8175d76335f3"
    ),

    // === lottie ===
    // Source: airbnb/lottie-ios (public upstream, no fork)
    // URLs + checksums patched by build-lottie.yml workflow on each release.
    .binaryTarget(
      name: "Lottie",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/lottie-4.6.0/Lottie.xcframework.zip",
      checksum: "d88114888426151744794732c179995f4fa5f59126c847de96c69eff6413dad8"
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
      url: "PENDING",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),

    // === sentry ===
    // Source: getsentry/sentry-cocoa (public upstream, no fork)
    // URLs + checksums patched by build-sentry.yml on each release.
    .binaryTarget(
      name: "Sentry",
      url: "PENDING",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),

    // === posthog ===
    // Source: PostHog/posthog-ios (public upstream, no fork)
    // URLs + checksums patched by build-posthog.yml on each release.
    .binaryTarget(
      name: "PostHog",
      url: "PENDING",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),

    // === iterable ===
    // Source: Iterable/iterable-swift-sdk (public upstream, no fork)
    // URLs + checksums patched by build-iterable.yml on each release.
    .binaryTarget(
      name: "IterableSDK",
      url: "PENDING",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),

    // === starscream ===
    // Source: daltoniam/Starscream (public upstream, no fork)
    // URLs + checksums patched by build-starscream.yml on each release.
    .binaryTarget(
      name: "Starscream",
      url: "PENDING",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
  ]
)
