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
    // === rxswift ===
    // Built from ReactiveX/RxSwift via its `Rx.xcodeproj` scheme `RxSwift`.
    // Migrated from the separate Cambly-RxSwift-Binary repo into this
    // monorepo on 2026-05-28 (consolidating per-vendor binary repos).
    .library(
      name: "RxSwift",
      targets: ["RxSwift"]
    ),
    // === promisekit ===
    // Built from mxcl/PromiseKit via its `PromiseKit.xcodeproj` scheme
    // `PromiseKit`. Migrated from the separate Cambly-PromiseKit-Binary repo
    // into this monorepo on 2026-05-28.
    .library(
      name: "PromiseKit",
      targets: ["PromiseKit"]
    ),
    // === fastboard ===
    // Built from netless-io/fastboard-iOS@<version> CocoaPods-mode (from
    // Fastboard's Example/Fastboard.xcworkspace) — produces the whole Netless
    // dependency cluster in one build: Fastboard → Whiteboard → { NTLBridge
    // (the DSBridge-IOS pod), White_YYModel }. Under `use_frameworks!` each pod
    // is a separate dynamic framework that the others dyld-link at runtime, so
    // every consumer must link + embed all four — they are NOT statically
    // absorbed into Fastboard.framework.
    //
    // Two products preserve Cambly-Swift's existing import sites unchanged
    // (`import Fastboard` / `import Whiteboard`). Each lists the full set of
    // frameworks its top-level framework loads, so SwiftPM embeds every needed
    // xcframework into the consuming app target.
    //
    // The Fastboard binary's module is named `FastboardSDK` (not `Fastboard`)
    // to break a module-name == class-name collision — `module Fastboard` had a
    // top-level `public class Fastboard`, which made the library-evolution
    // .swiftinterface fail to recompile under a different Swift version. The
    // product name stays `Fastboard`; only the imported module differs
    // (`import FastboardSDK`). See `// === fastboard ===` in targets + README.
    .library(
      name: "Fastboard",
      targets: ["FastboardSDK", "Whiteboard", "NTLBridge", "White_YYModel"]
    ),
    .library(
      name: "Whiteboard",
      targets: ["Whiteboard", "NTLBridge", "White_YYModel"]
    ),
    // === instantsearch ===
    // Built from algolia/instantsearch-ios@7.27.0 SPM-mode via
    // swift-create-xcframework (the only USE_SPM=1 vendor — see Makefile
    // VENDOR=instantsearch). instantsearch-ios is pure SwiftPM with no
    // framework-producing xcodeproj, so it can't go through the xcodebuild-
    // archive path the other vendors use.
    //
    // swift-create-xcframework builds every module — including the transitive
    // dependency packages — as a SEPARATE dynamic framework, and the top-level
    // ones dyld-link the rest at runtime (NOT statically absorbed). So this one
    // product must list all 7 binary targets, same multi-framework shipping
    // model as the Netless stack: the consumer's app target embeds every one.
    //
    // `import InstantSearch` re-exports InstantSearchCore which re-exports
    // AlgoliaSearchClient (@_exported), so both import sites Cambly-Swift uses
    // (`import InstantSearch`, `import AlgoliaSearchClient`) resolve from this
    // single product — no separate AlgoliaSearchClient product needed.
    // Logging (swift-log) / SwiftProtobuf (swift-protobuf) / InstantSearchInsights
    // / InstantSearchTelemetry are transitive runtime deps; nobody imports them
    // directly, but they must ship + embed because InstantSearch/Core dyld-link
    // them (and InstantSearchCore's public .swiftinterface imports the first
    // three). URLs + checksums patched by build-instantsearch.yml on each release.
    .library(
      name: "InstantSearch",
      targets: [
        "InstantSearch",
        "InstantSearchCore",
        "AlgoliaSearchClient",
        "InstantSearchInsights",
        "InstantSearchTelemetry",
        "Logging",
        "SwiftProtobuf",
      ]
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
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/keychainaccess-v4.2.2-signed/KeychainAccess.xcframework.zip",
      checksum: "4c0aabc1493d22a601775ad6a4f8f1df5296f8abc9f865ca20cc823640206ab0"
    ),

    // === devicekit ===
    // Source: devicekit/DeviceKit (public upstream, no fork)
    // URLs + checksums patched by build-devicekit.yml on each release.
    .binaryTarget(
      name: "DeviceKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/devicekit-5.8.0-signed/DeviceKit.xcframework.zip",
      checksum: "c597e053518b6c4fa7aaf126530337d41947e2cff3dc19233e25ca27c207db09"
    ),

    // === sdwebimage ===
    // Source: SDWebImage/SDWebImage (public upstream, no fork)
    // URLs + checksums patched by build-sdwebimage.yml on each release.
    .binaryTarget(
      name: "SDWebImage",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/sdwebimage-5.21.7-signed/SDWebImage.xcframework.zip",
      checksum: "fe9d145bdf9b64079e7eb8f056cbbf0fe0f718bda08a79e300ddd7494a420d6e"
    ),

    // === sentry ===
    // Source: getsentry/sentry-cocoa (public upstream, no fork)
    // URLs + checksums patched by build-sentry.yml on each release.
    .binaryTarget(
      name: "Sentry",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/sentry-9.13.0-signed/Sentry.xcframework.zip",
      checksum: "5a4eef1dd4b93b4503582421d0b10560de886c09d8308e8b02180f64abd361dd"
    ),

    // === posthog ===
    // Source: PostHog/posthog-ios (public upstream, no fork)
    // URLs + checksums patched by build-posthog.yml on each release.
    .binaryTarget(
      name: "PostHog",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/posthog-3.58.3-signed/PostHog.xcframework.zip",
      checksum: "860364333725532e9bdc182311eff70a3007fbfe0704883d09c1ab48025db0e1"
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
    // === rxswift ===
    // Source: ReactiveX/RxSwift (public upstream, no fork)
    // URLs + checksums patched by build-rxswift.yml on each release.
    .binaryTarget(
      name: "RxSwift",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/rxswift-6.9.1-signed/RxSwift.xcframework.zip",
      checksum: "db457946b7addee15d8cacab592544fb33dbe13479d32f805d5f7e60fc373db0"
    ),
    // === promisekit ===
    // Source: mxcl/PromiseKit (public upstream, no fork)
    // URLs + checksums patched by build-promisekit.yml on each release.
    .binaryTarget(
      name: "PromiseKit",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/promisekit-6.22.1-signed/PromiseKit.xcframework.zip",
      checksum: "af631ad5f9551410cff3fa3b854acd163d4a54bd506bccc2ebb3e55168a423a6"
    ),
    // === fastboard ===
    // Source: netless-io/fastboard-iOS (+ transitive netless-io/Whiteboard-iOS,
    // DSBridge-IOS [CocoaPods pod name: NTLBridge], White_YYModel). Built
    // CocoaPods-mode from Fastboard's Example workspace (see Makefile VENDOR
    // =fastboard). URLs + checksums patched by build-fastboard.yml on each
    // release. Placeholder state until the first workflow run patches them.
    .binaryTarget(
      name: "FastboardSDK",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/fastboard-1.4.1-r2/FastboardSDK.xcframework.zip",
      checksum: "49d7e749e41f7528855cefdd6dbbed5ae4371d3e1d69af38188305b1ec8fae10"
    ),
    .binaryTarget(
      name: "Whiteboard",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/fastboard-1.4.1-r2/Whiteboard.xcframework.zip",
      checksum: "8b5acce6d7f4bf8b29ee040ede9a1ef3c49d596d8e73e73e74d2acc012d629f0"
    ),
    .binaryTarget(
      name: "NTLBridge",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/fastboard-1.4.1-r2/NTLBridge.xcframework.zip",
      checksum: "8ee685ab0730cd4bfa6a11bdda8ee42f17ad8ad3e68866ae2dda98a2435f51e6"
    ),
    .binaryTarget(
      name: "White_YYModel",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/fastboard-1.4.1-r2/White_YYModel.xcframework.zip",
      checksum: "505993b6e2fbbddc3d1b4f2ec4e9029cb2049efcd0336b9c6c5f8eaf23caf92a"
    ),

    // === instantsearch ===
    // Source: algolia/instantsearch-ios (+ transitive algoliasearch-client-swift,
    // instantsearch-telemetry-native, apple/swift-log, apple/swift-protobuf).
    // Built SPM-mode via swift-create-xcframework — see Makefile VENDOR
    // =instantsearch + the `// === instantsearch ===` product comment above.
    // URLs + checksums patched by build-instantsearch.yml on each release.
    // Placeholder state (PENDING url + 64-zero checksum) until the first
    // workflow run patches them.
    .binaryTarget(
      name: "InstantSearch",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/InstantSearch.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "InstantSearchCore",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/InstantSearchCore.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "AlgoliaSearchClient",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/AlgoliaSearchClient.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "InstantSearchInsights",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/InstantSearchInsights.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "InstantSearchTelemetry",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/InstantSearchTelemetry.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "Logging",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/Logging.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
    .binaryTarget(
      name: "SwiftProtobuf",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/instantsearch-PENDING/SwiftProtobuf.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
  ]
)
