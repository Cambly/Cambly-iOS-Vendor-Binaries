# Cambly-iOS-Vendor-Binaries

Prebuilt `.xcframework` distribution of vendored iOS SDKs for Cambly's iOS apps. Wraps upstream sources (or Cambly forks where applicable) so Cambly-Swift skips recompilation of these vendors on every clean build. See [MOB-222](https://cambly.atlassian.net/browse/MOB-222) for context.

Versions tracked:

| Vendor product | Upstream source | Current release tag |
|---|---|---|
| `FacebookLogin` (+ 5 transitive frameworks) | `Cambly/facebook-ios-sdk@v11.0.1-cambly` (Cambly fork) | `facebook-v11.0.1-cambly` |

More vendors to be added — see "Adding a new vendor" below.

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
3. In Cambly-Swift, bump `project_files/swift_packages.yml`:
   ```diff
    CamblyVendorBinaries:
      url: git@github.com:Cambly/Cambly-iOS-Vendor-Binaries
   -  revision: facebook-v11.0.1-cambly
   +  revision: facebook-v11.0.2-cambly
   ```
4. Verify locally, then open a Cambly-Swift PR — diff should be just that one yml line plus an auto-updated `Package.resolved`.

## Adding a new vendor (4 steps)

Each vendor is: one `.library` product, N `.binaryTarget`s, one Makefile section, one GHA workflow. Marker comments tie everything together.

1. **`Package.swift`** — under `products:`, add a `// === <vendor-key> ===` marker line and a `.library(name: "<ProductName>", targets: [...])`. Under `targets:`, add the same marker line and N `.binaryTarget(name: ..., url: "...PENDING...", checksum: "0000…")` entries. Use 64 hex zeros as the placeholder checksum; the first workflow run patches everything to real values.
2. **`Makefile`** — add a per-vendor block:
   ```makefile
   ifeq ($(VENDOR),<vendor-key>)
     UPSTREAM_REPO_URL ?= git@github.com:<owner>/<repo>.git
     PRODUCTS := <space-separated scheme list, transitive deps first>
   endif
   ```
   For public upstreams (Alamofire / Lottie / etc.), use the unauthenticated `https://github.com/...` URL as the default and no PAT is needed.
3. **`.github/workflows/build-<vendor>.yml`** — copy `build-facebook.yml`, change:
   - `name:` and the `workflow_dispatch` description
   - `VENDOR` env (used by patch script)
   - `ASSETS_TAG: <vendor-key>-${{ inputs.version }}`
   - The `<TargetName>_SHA` env vars list (one per `.binaryTarget` you declared in step 1)
   - Release tag in the `gh release create` step
4. **Cambly-Swift** — in `project_files/shared_swift_packages_dependencies.yml` (and any per-target SPM dep yml), replace `package: <UpstreamSPMPackage> / product: X` with `package: CamblyVendorBinaries / product: X`. Remove the old `<UpstreamSPMPackage>` entry from `swift_packages.yml`. Bump the `revision:` pin to the new vendor's tag.

## One-time setup

For vendors with **private** upstream repos (Cambly forks), this repo needs a `SOURCE_REPO_TOKEN` secret:

- Settings → Secrets and variables → Actions → New repository secret
- Name: `SOURCE_REPO_TOKEN`
- Value: a fine-grained PAT with **Read** access to **Contents** on the relevant Cambly org repos (e.g. `Cambly/facebook-ios-sdk`)

Public upstreams don't need this token — their `UPSTREAM_REPO_URL` uses the unauthenticated form.

## Local fallback

If GitHub Actions is unavailable:

```bash
make all VENDOR=facebook VERSION=v11.0.1-cambly
# Outputs build/artifacts/*.xcframework.zip and prints sha256 to stdout
```

Then manually:
- Upload zips as a new GitHub Release (`gh release create facebook-v11.0.1-cambly build/artifacts/*.xcframework.zip`)
- Patch `Package.swift` (run the python script the same way the workflow does, or edit by hand)
- Commit + push

## Why a single xcframework slice per vendor

This repo builds every framework with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, which emits `.swiftinterface` files forward-compatible across Xcode versions. So one xcframework per scheme works across the 26.x family.

Contrast `Cambly-Realm-Binary`, which ships 4 slices (Xcode 26.1 / 26.2 / 26.3 / 26.4.1) because its build doesn't enable library evolution — `.swiftmodule` is tied to the exact compiler version. If a future vendor's source can't compile with library evolution (rare; usually fails in emit-module), escalate at that point and add per-Xcode slicing.

## Why a monorepo vs per-vendor repo

Unlike `Cambly-PromiseKit-Binary` / `Cambly-RxSwift-Binary` which are per-vendor, this repo houses multiple vendors to keep repo count down (5-6 near-identical per-vendor repos would be more drag than they save). The trade-off: vendor builds queue via the `package-update` concurrency group, but they're rare and slow anyway so queuing doesn't matter.
