# Cambly-iOS-Vendor-Binaries

Prebuilt `.xcframework` distribution of vendored iOS SDKs for Cambly's iOS apps. Wraps upstream sources (or Cambly forks where applicable) so Cambly-Swift skips recompilation of these vendors on every clean build. See [MOB-222](https://cambly.atlassian.net/browse/MOB-222) for context.

Versions tracked:

| Vendor product | Upstream source | Current release tag | Build via |
|---|---|---|---|
| `FBSDKLoginKit` (+ `FBSDKCoreKit` + `FBSDKCoreKit_Basics` transitive) | `Cambly/facebook-ios-sdk@v11.0.1-cambly` (private Cambly fork) | `facebook-v11.0.1-cambly` | `FBSDK*-Dynamic` schemes in `FacebookSDK.xcworkspace` |
| `Alamofire` | `Alamofire/Alamofire@5.12.0` | `alamofire-5.12.0` | `Alamofire iOS` scheme in `Alamofire.xcodeproj` |
| `Lottie` | `airbnb/lottie-ios@4.6.0` | `lottie-4.6.0` | `Lottie (iOS)` scheme in `Lottie.xcodeproj` |
| `KeychainAccess` | `kishikawakatsumi/KeychainAccess@v4.2.2` | `keychainaccess-v4.2.2` | `KeychainAccess` scheme in `Lib/KeychainAccess.xcodeproj` |
| `DeviceKit` | `devicekit/DeviceKit@5.8.0` | `devicekit-5.8.0` | `DeviceKit` scheme in `DeviceKit.xcodeproj` |
| `SDWebImage` | `SDWebImage/SDWebImage@5.21.7` | `sdwebimage-5.21.7` | `SDWebImage` scheme in `SDWebImage.xcodeproj` |
| `Sentry` | `getsentry/sentry-cocoa@9.13.0` | `sentry-9.13.0` | `Sentry` scheme in `Sentry.xcodeproj` |
| `PostHog` | `PostHog/posthog-ios@3.58.3` | `posthog-3.58.3` | `PostHog` scheme in `PostHog.xcodeproj` |
| `IterableSDK` | `Iterable/iterable-swift-sdk@6.7.1` | `iterable-6.7.1` | `swift-sdk` scheme in `swift-sdk.xcodeproj` (scheme builds `IterableSDK.framework`) |
| `Starscream` | `daltoniam/Starscream@4.0.8` | `starscream-4.0.8` | `Starscream` scheme in `Starscream.xcodeproj` |

Cambly-Swift pins this repo by `revision: <vendor>-<version>` (typically the most recently bumped vendor's tag — the commit at that tag carries all vendors' current URLs/checksums, since each workflow patches the shared `Package.swift`).

More vendors may be added — see "Adding a new vendor" below. Google auth stack (`GoogleSignIn` / `GTMAppAuth` / `AppAuth` / `GTMSessionFetcher`) is currently **blocked**: those packages are SPM-only (no upstream xcodeproj), and our xcodeproj-mode pipeline doesn't fit. Other SPM-only candidates in Cambly-Swift today (`InstantSearch`, `BSON`, `Nantes`, `Reusable`, `MultiSlider`) face the same constraint — they would need a `swift-create-xcframework` based pipeline; see the abandoned attempt for Google auth in git history (reverted in `113f18b`) for the negative result and the kinds of issues that path runs into.

## How it works

A single `Package.swift` declares one `.library` product per vendor, each backed by one or more `.binaryTarget`s pointing at GitHub Release assets of this repo. Cambly-Swift adds this repo once in `swift_packages.yml` and references the relevant products in its target dependency lists — same usage shape as any source-form SwiftPM package.

Vendor sections inside `Package.swift` (both in `products:` and `targets:`) are delimited by `// === <vendor-key> ===` marker comments. The marker convention is load-bearing: `.github/scripts/patch_package_swift.py` uses it to locate the section to rewrite on each release.

## Upgrading an existing vendor

Each vendor has its own `workflow_dispatch` workflow in **Actions**.

1. **Actions → Build &lt;Vendor&gt; → Run workflow**, set `version` to the new upstream tag/ref, **Run**.
2. The workflow (~15-30 min) does:
   - Clone upstream at that version
   - For each scheme: `xcodebuild archive` for iOS device + iOS simulator with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, then `xcodebuild -create-xcframework`, zip, sha256
   - Patch this vendor's `// === <vendor> ===` section in `Package.swift` with new URLs + checksums
   - Commit + push `Package.swift` to `main`
   - Create GitHub release `<vendor>-<version>` with the zipped xcframeworks as assets
3. In Cambly-Swift, bump `project_files/swift_packages.yml` to the new vendor tag:
   ```diff
    CamblyVendorBinaries:
      url: git@github.com:Cambly/Cambly-iOS-Vendor-Binaries
   -  revision: devicekit-5.7.0
   +  revision: alamofire-5.11.0
   ```
   It doesn't matter which vendor tag you pin to — the commit at that tag carries the patched URL/checksum for **all** vendors. Convention: bump to whatever vendor you just released.
4. Verify locally, then open a Cambly-Swift PR — diff should be just that one yml line plus an auto-updated `Package.resolved`.

## Adding a new vendor (4 steps)

Each vendor is: one `.library` product, N `.binaryTarget`s, one Makefile section, one GHA workflow. Marker comments tie everything together. Reference `build-alamofire.yml` (single-framework public upstream) or `build-facebook.yml` (multi-framework private fork) as templates.

1. **`Package.swift`** — under `products:`, add a `// === <vendor-key> ===` marker line and a `.library(name: "<ProductName>", targets: [...])`. Under `targets:`, add the same marker line and N `.binaryTarget(name: ..., url: "...PENDING...", checksum: "0000…")` entries. Use 64 hex zeros as the placeholder checksum; the first workflow run patches everything to real values.
2. **`Makefile`** — add a per-vendor `ifeq` block. Two patterns depending on upstream layout:
   ```makefile
   # Pattern A — upstream xcodeproj/xcworkspace at root
   ifeq ($(VENDOR),<vendor-key>)
     BUILD_PROJECT_FLAG := -project <Name>.xcodeproj    # or -workspace <Name>.xcworkspace
     SCHEME_PRODUCT_PAIRS := "<scheme>:<output-product-name>"
   endif

   # Pattern B — xcodeproj in a subdirectory (e.g. KeychainAccess uses Lib/)
   ifeq ($(VENDOR),<vendor-key>)
     BUILD_PROJECT_FLAG := -project Lib/<Name>.xcodeproj
     SCHEME_PRODUCT_PAIRS := "<scheme>:<output-product-name>"
   endif
   ```
   Add `<vendor-key>` to the `case` statement in `require-args`. Use quoted `"scheme:product"` tokens to handle scheme names with spaces / parens (e.g. `"Alamofire iOS:Alamofire"`, `"Lottie (iOS):Lottie"`).
3. **`.github/workflows/build-<vendor>.yml`** — copy `build-alamofire.yml` (simplest template), change:
   - `name:` and the `workflow_dispatch` description / default version
   - `VENDOR` env (used by patch script)
   - `ASSETS_TAG: <vendor-key>-${{ inputs.version }}`
   - The `<TargetName>_SHA` env vars list (one per `.binaryTarget` you declared in step 1)
   - `UPSTREAM_REPO_URL` in the `make all` invocation
   - Release tag in the `gh release create` step

   Keep `concurrency: { group: package-update, cancel-in-progress: false }` and the `git fetch origin main && git rebase origin/main` retry loop — they prevent race-on-push when two vendor workflows touch `Package.swift` in close succession.
4. **Cambly-Swift** — in `project_files/shared_swift_packages_dependencies.yml` (and any per-target SPM dep yml), replace `package: <UpstreamSPMPackage> / product: X` with `package: CamblyVendorBinaries / product: X`. Remove the old `<UpstreamSPMPackage>` entry from `swift_packages.yml`. Bump the `revision:` pin to the new vendor's tag.

   ⚠️ **Watch for single-line `- package: X` shortcuts** in yml — xcodegen lets you omit `product:` when it matches the package name. Those break after rename to `CamblyVendorBinaries` (no product named `CamblyVendorBinaries` exists). Always add an explicit `product: <Original>` line after the rename. (Caught us on `login.yml` for DeviceKit.)

## One-time setup

For vendors with **private** upstream repos (Cambly forks), this repo needs a `SOURCE_REPO_TOKEN` secret:

- Settings → Secrets and variables → Actions → New repository secret
- Name: `SOURCE_REPO_TOKEN`
- Value: a fine-grained PAT with **Read** access to **Contents** on the relevant Cambly org repos (e.g. `Cambly/facebook-ios-sdk`)

Public upstreams don't need this token — their `UPSTREAM_REPO_URL` uses the unauthenticated form.

## Local fallback

If GitHub Actions is unavailable:

```bash
make all VENDOR=alamofire VERSION=5.10.2 \
  UPSTREAM_REPO_URL=https://github.com/Alamofire/Alamofire.git
# Outputs build/artifacts/*.xcframework.zip
```

Compute checksums with `swift package compute-checksum`, then manually:
- Upload zips as a new GitHub Release (`gh release create alamofire-5.10.2 --cleanup-tag build/artifacts/*.xcframework.zip`)
- Patch `Package.swift` (run `.github/scripts/patch_package_swift.py` the same way the workflow does, or edit the `// === <vendor> ===` section by hand)
- Commit + push

## Why a single xcframework slice per vendor

This repo builds every framework with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, which emits `.swiftinterface` files forward-compatible across Xcode versions. So one xcframework per scheme works across the 26.x family.

Contrast `Cambly-Realm-Binary`, which ships 4 slices (Xcode 26.1 / 26.2 / 26.3 / 26.4.1) because its build doesn't enable library evolution — `.swiftmodule` is tied to the exact compiler version. If a future vendor's source can't compile with library evolution (rare; usually fails in emit-module), escalate at that point and add per-Xcode slicing.

## Why a monorepo vs per-vendor repo

Unlike `Cambly-PromiseKit-Binary` / `Cambly-RxSwift-Binary` which are per-vendor, this repo houses multiple vendors to keep repo count down (5-6 near-identical per-vendor repos would be more drag than they save). The trade-off: vendor builds queue via the `package-update` concurrency group, but they're rare and slow anyway so queuing doesn't matter.
