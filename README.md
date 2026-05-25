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

## Operational gotchas

Two things that have bitten this repo's release flow. Read before bumping or rebuilding any vendor.

### The Makefile strips dev-time files from every `.framework`

Framework bundles built via `xcodebuild archive` honor whatever the upstream xcodeproj declares in its **Copy Bundle Resources** phase. Some upstream projects accidentally land dev-time scripts/sources there — e.g. PostHog 3.58.3 ships `generate-pb-c.sh`, a PLCrashReporter `protoc-c` codegen helper. Source-form SwiftPM excludes such files via `Package.swift`'s `exclude:`, but our pipeline doesn't honor that — it obeys the xcodeproj.

If such a file reaches the consuming app's `Frameworks/` dir, **App Store Connect rejects the IPA with error 90035 "Code object is not signed at all"**. `altool` treats any non-Mach-O file inside a framework bundle as nested code that must be signed, and a shell script (or `.swift` / `.c` / `Makefile` / etc.) can't be signed. The reject only surfaces at TestFlight/App Store upload — simulator builds and even on-device dev builds don't trip it.

The Makefile's `build-xcframeworks` target therefore strips a broad list of dev-time file types (`*.sh / *.py / *.swift / *.c / Makefile / ...`) from each `.framework` slice before `-create-xcframework`. Canonical framework contents (`Mach-O / Info.plist / Headers/ / Modules/ / PrivateHeaders/ / Resources/ / PrivacyInfo.xcprivacy`) are not matched. If you add a new vendor and discover the sanitize step removes something it shouldn't, narrow the pattern — don't disable the step.

### Don't reuse a release tag once consumers have pulled it

Consumers cache `binaryTarget` downloads in `~/Library/Caches/org.swift.swiftpm/artifacts/`, **keyed by URL**. If you delete-and-recreate a release tag with different zip contents (the per-vendor workflows do `gh release delete --cleanup-tag && gh release create`), every consumer with a populated cache will fall into one of two bad states:

1. **`checksum of downloaded artifact ... does not match checksum specified by the manifest`** — SwiftPM serves the old zip from cache, but `Package.swift` advertises the new sha256.
2. **`binary target 'X' could not be mapped to an artifact with expected name 'X'`** — after a partial cache clear, an empty `<Product>/` directory remains in `<DerivedData>/SourcePackages/artifacts/cambly-ios-vendor-binaries/`.

Recovery requires every developer (and CI cache layer) to manually `rm -rf` the stale cache entries. This bit us hard on `posthog-3.58.3` — see PR Cambly-Swift#4081.

**Rule**: the first release of a given upstream version uses `<vendor>-<version>` as the tag. Any rebuild at the same upstream version (e.g. fixing a packaging bug, not a code change) must go out under a fresh tag — `<vendor>-<version>-<suffix>` is fine (`posthog-3.58.3-codesign-fix`, `lottie-4.6.0-r2`). A new tag means a new URL, which means a fresh cache key, which means every consumer auto-redownloads cleanly with zero local intervention.

The per-vendor workflows currently take `version` as input and reuse the tag — that's correct for the **first** build of a given upstream version. For a rebuild, either tweak the workflow (one-off) to take a separate tag suffix, or do it by hand: trigger the workflow to regenerate the zip (it'll overwrite the original `<vendor>-<version>` release; that's OK since you're abandoning it), then manually `gh release create <vendor>-<version>-<suffix> --target main <built-zip>` and patch `Package.swift` to point the binaryTarget url at the new tag.

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
4. **Cambly-Swift** —

   a. **Rename package refs.** In every `project_files/*.yml` that references the upstream package, replace `package: <UpstreamSPMPackage> / product: X` with `package: CamblyVendorBinaries / product: X`. Remove the old `<UpstreamSPMPackage>` entry from `swift_packages.yml`. Bump the `revision:` pin to the new vendor's tag.

   b. **Audit every app target for direct embed declarations.** ⚠️ *This is the load-bearing step.* When a vendor moves from source-form SPM to a binary xcframework, every `application` target that uses the vendor (even transitively through an intermediate framework like `Networking` or `Syntax`) must declare the binary product **directly** in its own `dependencies:` list — not only on the intermediate framework. SPM auto-embeds binary xcframeworks into `.app/Frameworks/` *only* for products that are direct deps of the app target; transitive declarations through framework targets are silently link-but-not-embed, and the app crashes on real devices at launch with `dyld[..]: Library not loaded: @rpath/X.framework/X`. Source-form deps don't have this issue (the consumer framework statically absorbs the compiled code), which is what hid the gap before vendoring.

   The 4 places to update (Cambly-Swift has 7 app targets total — 4 production apps + 3 preview hosts):

   | App target | yml file | Used by |
   |---|---|---|
   | `Cambly` | `shared_swift_packages_dependencies.yml` (`SharedSPMDependencies` template) | Adults |
   | `CamblyKids` | `shared_swift_packages_dependencies.yml` (same template) | Kids |
   | `Lexicon` | `lexicon_target.yml` | Lexicon |
   | `ComponentsApp` | `components_app.yml` | Components preview host |
   | `SyntaxApp` | `syntax_app.yml` | Syntax preview host |
   | `SyntaxSwiftUIApp` | `syntax_swiftui_app.yml` | Syntax SwiftUI preview host |
   | `LexiconComponentsApp` | `lexicon_components_app.yml` | Lexicon Components preview host |

   For each app target that (transitively) imports the new vendor, add:

   ```yml
   - package: CamblyVendorBinaries
     product: <ProductName>
   ```

   Do **not** add `embed: true` / `codeSign: true` flags — SPM handles auto-embed for `binaryTarget` products itself, and explicit flags actually conflict with that and break the Copy Frameworks build phase (caught us on Lottie in PR #4040).

   c. **Run the lint:** `python3 scripts/lint_binary_embeds.py` walks every app target's transitive deps and fails if any binary product is used but not declared directly. CI also runs this as the `check-binary-embeds` job; you can run it locally before pushing.

   d. **Verify on a real device.** A successful `xcodebuild build` on iOS Simulator is **not sufficient** — simulator dyld searches `Build/Products/.../PackageFrameworks/` in addition to `.app/Frameworks/`, masking missing embeds. The crash only surfaces on a physical device. Plug in a phone, install + launch each app (adults / kids / lexicon) at least once before merging. The CI lint above catches the obvious cases at PR time but isn't a complete substitute for an on-device launch.

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
