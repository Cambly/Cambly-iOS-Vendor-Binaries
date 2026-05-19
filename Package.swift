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

    // === google-auth ===
    // Built from google/GoogleSignIn-iOS@7.1.0 via unsignedapps/swift-create-xcframework
    // — pure SPM upstream (no native xcodeproj), so xcodeproj-mode build doesn't
    // apply. swift-create-xcframework generates an xcodeproj on the fly that
    // produces a framework with proper Modules/ (plain SPM dynamic archive
    // drops module metadata; see plan).
    //
    // Transitive deps (AppAuth / GTMAppAuth / GTMSessionFetcher) statically
    // linked into GoogleSignIn.xcframework's binary, so we ship 1 xcframework.
    // Cambly's only `import GoogleSignIn` works; AppAuth / GTMAppAuth /
    // GTMSessionFetcher are not exposed as importable modules (Cambly doesn't
    // import them anyway — verified 0 imports).
    .library(
      name: "GoogleSignIn",
      targets: ["GoogleSignIn"]
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
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/alamofire-5.10.2/Alamofire.xcframework.zip",
      checksum: "959d814c1413e99b827323e989d29108de1419decb6c246387fb721919b21d54"
    ),

    // === lottie ===
    // Source: airbnb/lottie-ios (public upstream, no fork)
    // URLs + checksums patched by build-lottie.yml workflow on each release.
    .binaryTarget(
      name: "Lottie",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/lottie-4.5.2/Lottie.xcframework.zip",
      checksum: "d725b443b4805f608842b2e352a6788970f58dec65a6ada050c5649587788c2d"
    ),

    // === google-auth ===
    // Source: google/GoogleSignIn-iOS (public upstream, no fork)
    // Single xcframework with AppAuth / GTMAppAuth / GTMSessionFetcher
    // statically linked in (see product comment above).
    // URLs + checksums patched by build-google-auth.yml on each release.
    .binaryTarget(
      name: "GoogleSignIn",
      url: "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download/PENDING/GoogleSignIn.xcframework.zip",
      checksum: "0000000000000000000000000000000000000000000000000000000000000000"
    ),
  ]
)
