# Multi-vendor xcframework builder.
#
# Builds upstream packages (xcodeproj-mode) as .xcframeworks suitable for
# distribution via the binaryTarget entries in Package.swift. Used by
# .github/workflows/build-*.yml but can also be invoked locally as a fallback.
#
# Usage:
#   make all VENDOR=facebook  VERSION=v11.0.1-cambly
#   make all VENDOR=alamofire VERSION=5.10.2
#   make all VENDOR=lottie    VERSION=4.5.2
#   make clean
#
# CI runners override UPSTREAM_REPO_URL to HTTPS form for public upstreams (no
# SSH key on macos-15). For private forks (Facebook), CI passes an https
# URL with PAT. Local devs can use the SSH defaults.

VENDOR ?=
VERSION ?=
BUILD_DIR := build
ARTIFACTS_DIR := $(BUILD_DIR)/artifacts
# SPM-mode vendors (USE_SPM=1) build via swift-create-xcframework instead of
# `xcodebuild archive` on a committed xcodeproj. Override to point at a local
# build; CI installs lonepalm's macOS-26 prebuilt binary to /usr/local/bin.
SWIFT_CREATE_XCFRAMEWORK ?= swift-create-xcframework
# Lazy `=` so `make clean` doesn't require VENDOR/VERSION at parse time.
WORK_DIR = $(BUILD_DIR)/$(VENDOR)-$(VERSION)

# ─── Per-vendor configuration ───────────────────────────────────────────────
# When adding a new vendor, add an `ifeq` block setting:
#   UPSTREAM_REPO_URL   – where to git clone
#   BUILD_PROJECT_FLAG  – passed to `xcodebuild archive`: e.g.
#                         `-project Alamofire.xcodeproj` or
#                         `-workspace FacebookSDK.xcworkspace`
#   SCHEME_PRODUCT_PAIRS – space-separated quoted "scheme:product" tokens.
#                         The build loop iterates each pair: `scheme` is what
#                         xcodebuild builds (may contain spaces / parens),
#                         `product` is the resulting framework name (also the
#                         binaryTarget name in our Package.swift).
#                         A single token uses double-quotes so shell `for`
#                         doesn't split it on internal whitespace.

ifeq ($(VENDOR),facebook)
  UPSTREAM_REPO_URL ?= git@github.com:Cambly/facebook-ios-sdk.git
  BUILD_PROJECT_FLAG := -workspace FacebookSDK.xcworkspace
  SCHEME_PRODUCT_PAIRS := \
    "FBSDKCoreKit_Basics-Dynamic:FBSDKCoreKit_Basics" \
    "FBSDKCoreKit-Dynamic:FBSDKCoreKit" \
    "FBSDKLoginKit-Dynamic:FBSDKLoginKit"
endif

ifeq ($(VENDOR),alamofire)
  UPSTREAM_REPO_URL ?= git@github.com:Alamofire/Alamofire.git
  BUILD_PROJECT_FLAG := -project Alamofire.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "Alamofire iOS:Alamofire"
endif

ifeq ($(VENDOR),lottie)
  UPSTREAM_REPO_URL ?= git@github.com:airbnb/lottie-ios.git
  BUILD_PROJECT_FLAG := -project Lottie.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "Lottie (iOS):Lottie"
endif

ifeq ($(VENDOR),keychainaccess)
  UPSTREAM_REPO_URL ?= git@github.com:kishikawakatsumi/KeychainAccess.git
  # xcodeproj is in Lib/ subdir, not at repo root (unlike Alamofire/Lottie).
  BUILD_PROJECT_FLAG := -project Lib/KeychainAccess.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "KeychainAccess:KeychainAccess"
endif

ifeq ($(VENDOR),devicekit)
  UPSTREAM_REPO_URL ?= git@github.com:devicekit/DeviceKit.git
  BUILD_PROJECT_FLAG := -project DeviceKit.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "DeviceKit:DeviceKit"
endif

ifeq ($(VENDOR),sdwebimage)
  UPSTREAM_REPO_URL ?= git@github.com:SDWebImage/SDWebImage.git
  BUILD_PROJECT_FLAG := -project SDWebImage.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "SDWebImage:SDWebImage"
endif

ifeq ($(VENDOR),sentry)
  UPSTREAM_REPO_URL ?= git@github.com:getsentry/sentry-cocoa.git
  BUILD_PROJECT_FLAG := -project Sentry.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "Sentry:Sentry"
endif

ifeq ($(VENDOR),posthog)
  UPSTREAM_REPO_URL ?= git@github.com:PostHog/posthog-ios.git
  BUILD_PROJECT_FLAG := -project PostHog.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "PostHog:PostHog"
  # Override default WORK_DIR (= $(BUILD_DIR)/$(VENDOR)-$(VERSION)) for posthog:
  # PostHog.xcodeproj references nested PostHogExample*.xcodeproj projects, and
  # one of them (PostHogExampleWithSPM.xcodeproj) declares a Local Swift Package
  # reference pointing at `../posthog-ios`. xcodebuild requires that sibling
  # directory to exist at SPM resolution time, even when archiving the unrelated
  # `PostHog` scheme — without this override the build fails with
  # "Could not resolve package dependencies: the package at 'build/posthog-ios'
  # cannot be accessed". So clone into the upstream's natural directory name.
  WORK_DIR := $(BUILD_DIR)/posthog-ios
endif

ifeq ($(VENDOR),iterable)
  UPSTREAM_REPO_URL ?= git@github.com:Iterable/iterable-swift-sdk.git
  BUILD_PROJECT_FLAG := -project swift-sdk.xcodeproj
  # Scheme name `swift-sdk` produces `IterableSDK.framework` (the buildable
  # target inside is named differently from the scheme — verified via the
  # scheme's BuildableName attribute).
  SCHEME_PRODUCT_PAIRS := \
    "swift-sdk:IterableSDK"
endif

ifeq ($(VENDOR),starscream)
  UPSTREAM_REPO_URL ?= git@github.com:daltoniam/Starscream.git
  BUILD_PROJECT_FLAG := -project Starscream.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "Starscream:Starscream"
endif

ifeq ($(VENDOR),rxswift)
  UPSTREAM_REPO_URL ?= git@github.com:ReactiveX/RxSwift.git
  BUILD_PROJECT_FLAG := -project Rx.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "RxSwift:RxSwift"
endif

ifeq ($(VENDOR),promisekit)
  UPSTREAM_REPO_URL ?= git@github.com:mxcl/PromiseKit.git
  BUILD_PROJECT_FLAG := -project PromiseKit.xcodeproj
  SCHEME_PRODUCT_PAIRS := \
    "PromiseKit:PromiseKit"
endif

# Netless whiteboard stack — the ONLY CocoaPods-mode vendor (USE_COCOAPODS=1).
# All other vendors above build from a committed standalone xcodeproj; the
# Netless upstreams do NOT ship one — the only buildable, framework-producing
# project is the CocoaPods-generated `Example/Fastboard.xcworkspace`, which we
# regenerate with `pod install` (see the USE_COCOAPODS branch in
# build-xcframeworks). This single fastboard-iOS clone produces the WHOLE
# 4-framework dependency cluster (upstream's own `xcframework.sh` does the same):
#   Fastboard ──▶ Whiteboard ──▶ { NTLBridge (DSBridge), White_YYModel }
# With `use_frameworks!` each pod is a separate dynamic framework, so all four
# must be shipped + embedded — Fastboard.framework dyld-links the other three at
# runtime (they are NOT statically absorbed). This one block therefore delivers
# both MOB-339 (Fastboard) and MOB-340 (Whiteboard + DSBridge + White_YYModel).
#
# Only Fastboard's Example has `use_frameworks!` enabled; Whiteboard-iOS's own
# Example has it commented out (static-lib mode → no .framework), which is why
# we build the entire stack from fastboard-iOS rather than per-repo.
#
# Scheme names are the CocoaPods pod-target names (verified via `xcodebuild
# -list` on 1.4.1) — note `NTLBridge` / `White_YYModel`, NOT the stale
# `dsBridge` / `YYModel` names in upstream's xcframework.sh.
ifeq ($(VENDOR),fastboard)
  UPSTREAM_REPO_URL ?= git@github.com:netless-io/fastboard-iOS.git
  USE_COCOAPODS := 1
  # CocoaPods project lives in Example/; pod install regenerates the workspace.
  COCOAPODS_DIR := Example
  BUILD_PROJECT_FLAG := -workspace Example/Fastboard.xcworkspace
  # Pin Whiteboard to the version Cambly-Swift currently resolves via SPM
  # (2.16.89), not Fastboard 1.4.1's default (~> 2.16.81). Injected into the
  # Example Podfile before `pod install`. Fastboard 1.4.1 requires ~> 2.16.81,
  # which 2.16.89 satisfies. Transitive NTLBridge / White_YYModel versions are
  # whatever Whiteboard 2.16.89's podspec resolves — their CocoaPods version
  # numbers differ from the SPM tags (NTLBridge 3.1.x vs SPM DSBridge 3.2.1)
  # and cannot be byte-aligned across package managers; code is equivalent.
  WHITEBOARD_POD_VERSION := 2.16.89
  # Rename Fastboard's module to break the module-name == class-name collision
  # (module `Fastboard` contains `public class Fastboard`), which otherwise makes
  # the library-evolution .swiftinterface fail to recompile under a different
  # Swift version (built on 26.3/6.2.4, consumed on 26.5/6.3.2). Injected into
  # Fastboard.podspec as `s.module_name`. The CocoaPods scheme stays `Fastboard`
  # (= pod name) but now produces FastboardSDK.framework. The other three pods
  # have no such collision and keep their names. The public class is unchanged,
  # so Cambly-Swift only swaps `import Fastboard` → `import FastboardSDK`.
  FASTBOARD_MODULE_NAME := FastboardSDK
  SCHEME_PRODUCT_PAIRS := \
    "Fastboard:FastboardSDK" \
    "Whiteboard:Whiteboard" \
    "NTLBridge:NTLBridge" \
    "White_YYModel:White_YYModel"
endif

# InstantSearch — the ONLY SPM-mode vendor (USE_SPM=1). instantsearch-ios is a
# pure-SwiftPM package with no committed framework-producing xcodeproj (only an
# Examples app), so the `xcodebuild archive`-on-xcodeproj path used by every
# other vendor doesn't apply. We build it with swift-create-xcframework instead
# (unsignedapps/swift-create-xcframework; CI uses lonepalm's macOS-26 prebuilt
# fork — the archived original can't compile against the macOS 26 SDK).
#
# Topology (verified): swift-create-xcframework builds EVERY target — including
# transitive dependency packages — as a SEPARATE dynamic framework, and the
# listed top-level frameworks dyld-link the rest at runtime (NOT statically
# absorbed). `import InstantSearch` re-exports InstantSearchCore which re-exports
# AlgoliaSearchClient (@_exported), and InstantSearchCore's public .swiftinterface
# additionally `import`s InstantSearchInsights / InstantSearchTelemetry / Logging.
# So all 7 modules must ship as embeddable, importable (evolution-enabled)
# xcframeworks — same multi-framework model as the Netless stack.
#
# Two-stage build (a single `swift-create-xcframework` run can't emit all 7:
# listing interdependent targets makes it archive each as its own scheme and
# fail to resolve siblings — `unable to resolve module dependency: 'Logging'`):
#   1. swift-create-xcframework builds the 3 top-level products with evolution
#      and emits their xcframeworks directly. `--stack-evolution` (safe once
#      swift-log is patched, see below) makes it build the whole dependency
#      stack with library evolution too, so the archive it leaves behind
#      contains all 7 frameworks each carrying a .swiftinterface.
#   2. The other 4 (the transitive deps) are pulled out of that archive's
#      Products/Library/Frameworks via `xcodebuild -create-xcframework`.
#
# swift-log patch: swift-log's `Logger.Storage.init` is `@inlinable`, which a
# library-evolution build rejects ("must delegate to another initializer").
# patch_swiftlog.py downgrades it to `@usableFromInline`. Run after `swift
# package resolve` materializes the checkout, before the build.
#
# IPHONEOS_DEPLOYMENT_TARGET=14.0 (= Cambly's app min deployment) is forced via
# --xc-setting (NOT --xcconfig, which silently no-ops) to keep every generated
# target's deployment target consistent — otherwise dependency targets get a
# different floor than the root and module imports fail across them.
#
# CRITICAL: this MUST be ≤ the app's min deployment (iOS 14), NOT 17.0. A prebuilt
# framework bakes its IPHONEOS_DEPLOYMENT_TARGET into LC_BUILD_VERSION minos; if
# minos (17.0) > the running OS (e.g. an iOS 16 device/sim the app still supports),
# dyld refuses to load it at launch — "Symbol not found … built for iOS 17.0 which
# is newer than running OS". Source-form SPM consumption never hit this because the
# *consumer* target's deployment target governed the compile. Same rule the
# Fastboard pipeline documents: "A framework's min ≤ the app's min is required".
ifeq ($(VENDOR),instantsearch)
  UPSTREAM_REPO_URL ?= git@github.com:algolia/instantsearch-ios.git
  USE_SPM := 1
  SPM_DEPLOYMENT_TARGET := 14.0
  # Products swift-create-xcframework BUILDS with --stack-evolution. Building the
  # top-level `InstantSearch` product leaves an archive containing the whole stack
  # (all 7 frameworks, each with a .swiftinterface). We then create every shipped
  # xcframework ourselves from that single archive (below), so the tool's own
  # --output xcframeworks are discarded.
  SPM_BUILD_PRODUCTS := InstantSearch InstantSearchCore AlgoliaSearchClient
  # The vendored SwiftProtobuf framework: strip its Modules/ so it ships as a
  # plain (non-importable) dynamic library. Why NOT rename it (MOB-338):
  #   - instantsearch-telemetry pulls apple/swift-protobuf, and Cambly-Swift's
  #     graph already has apple/swift-protobuf from source (Analytics-Tags @ 1.38).
  #   - The ORIGINAL reason for renaming → ISSwiftProtobuf was a SwiftPM target-name
  #     collision when InstantSearch was a CamblyVendorBinaries `.binaryTarget`.
  #     That's gone: InstantSearch now ships as per-Xcode LOCAL frameworks
  #     (LocalPackages/InstantSearchBinary, consumed via xcodegen `framework:`),
  #     never entering any SwiftPM package graph — no target-name uniqueness check.
  #   - The rename was done with `install_name_tool` (rename framework + repoint
  #     every consumer's @rpath). On arm64 that left the modified Mach-O's code
  #     pages mis-validating at runtime → `CODESIGNING Invalid Page` SIGKILL when
  #     launched under the debugger (verified on sim). Dropping the rename removes
  #     ALL install_name_tool surgery → no page corruption.
  #   - Stripping Modules/ is still required so the consumer sees only ONE
  #     importable `SwiftProtobuf` module (the app's source 1.38), not two.
  # The duplicate-ObjC-class warning (two SwiftProtobuf dylibs at runtime) is
  # unchanged by the rename either way (internal module name is `SwiftProtobuf`
  # regardless) and is non-fatal.
  SPM_PROTOBUF_STRIP_MODULES := SwiftProtobuf
  # All 7 frameworks we ship (no rename; SwiftProtobuf keeps its name, Modules stripped).
  SPM_SHIP_FRAMEWORKS := InstantSearch InstantSearchCore AlgoliaSearchClient InstantSearchInsights InstantSearchTelemetry Logging SwiftProtobuf
  # Product names for sign / zip / checksum (via PRODUCTS_LIST).
  SCHEME_PRODUCT_PAIRS := \
    "InstantSearch:InstantSearch" \
    "InstantSearchCore:InstantSearchCore" \
    "AlgoliaSearchClient:AlgoliaSearchClient" \
    "InstantSearchInsights:InstantSearchInsights" \
    "InstantSearchTelemetry:InstantSearchTelemetry" \
    "Logging:Logging" \
    "SwiftProtobuf:SwiftProtobuf"
endif

# Zendesk — the ONLY prebuilt-xcframework vendor (USE_PREBUILT=1). Every other
# vendor builds from source (xcodeproj / CocoaPods / SPM); Zendesk does NOT ship
# source — each zendesk/sdk_*_ios SPM package is a `path:` binaryTarget over a
# committed <Module>.xcframework. So there is nothing to archive: we clone each
# sub-repo at its pinned tag, lift the prebuilt .xcframework from the repo root,
# and re-sign it under Cambly's identity (the sign / zip / checksum tail is the
# same shared path as every other vendor — see sign-xcframeworks below).
#
# The 11 sub-frameworks are one matched ABI set (the messaging 2.35.0 train).
# Vendoring them behind ONE Cambly-iOS-Vendor-Binaries revision is exactly what
# prevents the partial-float skew that crashed Cambly-Swift develop when a loose
# `from:`-range SwiftPM resolve bumped ui_components alone (MOB-363 / postmortem).
# The pin set mirrors Cambly-Swift's known-good Package.resolved.
ifeq ($(VENDOR),zendesk)
  USE_PREBUILT := 1
  # Public upstreams; clone over https (no SSH key on macos runners).
  ZENDESK_BASE ?= https://github.com/zendesk
  # "<repo>:<upstream-tag>:<FrameworkName>" — clone each, lift
  # <FrameworkName>.xcframework from the repo root (the package's `path:`
  # binaryTarget). NOTE: these are the per-sub-package upstream tags, independent
  # of the vendor-release VERSION (which only names this repo's release tag).
  PREBUILT_REPO_TAGS := \
    "sdk_messaging_ios:2.35.0:ZendeskSDKMessaging" \
    "sdk_zendesk_ios:3.15.0:ZendeskSDK" \
    "sdk_ui_components_ios:14.3.1:ZendeskSDKUIComponents" \
    "sdk_conversation_kit_ios:13.2.0:ZendeskSDKConversationKit" \
    "sdk_guide_kit_ios:2.8.0:ZendeskSDKGuideKit" \
    "sdk_http_client_ios:0.20.1:ZendeskSDKHTTPClient" \
    "sdk_storage_ios:1.5.0:ZendeskSDKStorage" \
    "sdk_faye_client_ios:1.16.0:ZendeskSDKFayeClient" \
    "sdk_socket_client_ios:1.14.0:ZendeskSDKSocketClient" \
    "sdk_core_utilities_ios:7.2.0:ZendeskSDKCoreUtilities" \
    "sdk_logger_ios:0.11.0:ZendeskSDKLogger"
  # All shipped framework names → PRODUCTS_LIST (sign / zip / checksum). The
  # leading "x:" is a dummy scheme so the shared `awk -F: '{print $$2}'`
  # extraction yields the framework name (prebuilt mode has no real schemes).
  SCHEME_PRODUCT_PAIRS := \
    "x:ZendeskSDKMessaging" \
    "x:ZendeskSDK" \
    "x:ZendeskSDKUIComponents" \
    "x:ZendeskSDKConversationKit" \
    "x:ZendeskSDKGuideKit" \
    "x:ZendeskSDKHTTPClient" \
    "x:ZendeskSDKStorage" \
    "x:ZendeskSDKFayeClient" \
    "x:ZendeskSDKSocketClient" \
    "x:ZendeskSDKCoreUtilities" \
    "x:ZendeskSDKLogger"
endif

# ─── Targets ────────────────────────────────────────────────────────────────

.PHONY: all clean clone pod-install build-xcframeworks sign-xcframeworks zip checksums require-args

all: require-args build-xcframeworks sign-xcframeworks zip checksums

require-args:
	@test -n "$(VENDOR)"  || { echo "❌ VENDOR is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(VERSION)" || { echo "❌ VERSION is required"; exit 1; }
	@# Avoid `test -n "$(SCHEME_PRODUCT_PAIRS)"` here — that variable's value
	@# embeds its own double quotes (so each scheme:product token survives shell
	@# word-splitting), and re-quoting it tears the value apart. Validate VENDOR
	@# against the known list of ifeq blocks instead.
	@case "$(VENDOR)" in \
	  facebook|alamofire|lottie|keychainaccess|devicekit|sdwebimage|sentry|posthog|iterable|starscream|rxswift|promisekit|fastboard|instantsearch|zendesk) : ;; \
	  *) echo "❌ Unknown VENDOR='$(VENDOR)' — add an ifeq block in Makefile"; exit 1 ;; \
	esac

clean:
	rm -rf $(BUILD_DIR)

clone: require-args
	mkdir -p $(BUILD_DIR)
	@if [ -n "$(USE_PREBUILT)" ]; then \
	  echo "▶▶▶ prebuilt vendor '$(VENDOR)': per-repo clones happen in build-xcframeworks; skipping single-repo clone"; \
	else \
	  test -d $(WORK_DIR) || git clone --depth 1 --branch $(VERSION) $(UPSTREAM_REPO_URL) $(WORK_DIR); \
	fi

# CocoaPods-mode vendors (USE_COCOAPODS=1) build from a `pod install`-generated
# workspace rather than a committed xcodeproj. Patch the Podfile to pin the
# Whiteboard version, then resolve pods. No-op for every other vendor (their
# upstream ships a standalone xcodeproj, so there is nothing to pod-install).
pod-install: clone
	@if [ -n "$(USE_COCOAPODS)" ]; then \
	  echo "▶▶▶ CocoaPods vendor '$(VENDOR)': pin Whiteboard $(WHITEBOARD_POD_VERSION) + rename Fastboard module to $(FASTBOARD_MODULE_NAME) + pod install in $(WORK_DIR)/$(COCOAPODS_DIR)"; \
	  python3 $(CURDIR)/.github/scripts/patch_fastboard_podfile.py \
	    "$(WORK_DIR)/$(COCOAPODS_DIR)/Podfile" "$(WHITEBOARD_POD_VERSION)" || exit 1; \
	  python3 $(CURDIR)/.github/scripts/patch_fastboard_podspec.py \
	    "$(WORK_DIR)/Fastboard.podspec" "$(FASTBOARD_MODULE_NAME)" || exit 1; \
	  echo "🧹 Removing committed Podfile.lock so the pinned Whiteboard $(WHITEBOARD_POD_VERSION) resolves cleanly (upstream commits a lock pinning the old version, which otherwise conflicts)."; \
	  rm -f "$(WORK_DIR)/$(COCOAPODS_DIR)/Podfile.lock"; \
	  ( cd $(WORK_DIR)/$(COCOAPODS_DIR) && pod install --repo-update ) || exit 1; \
	else \
	  echo "▶▶▶ vendor '$(VENDOR)' is not CocoaPods-mode; skipping pod install"; \
	fi

# PRODUCTS is derived from SCHEME_PRODUCT_PAIRS for use by zip / checksums.
# (Bash-level split on ":" inside each pair.)
PRODUCTS_LIST = $(shell printf '%s\n' $(SCHEME_PRODUCT_PAIRS) | tr -d '"' | awk -F: '{print $$2}')

build-xcframeworks: clone pod-install
	mkdir -p $(ARTIFACTS_DIR)
ifeq ($(USE_SPM),1)
	@echo "▶▶▶ SPM-mode vendor '$(VENDOR)': swift-create-xcframework builds the stack, then we strip $(SPM_PROTOBUF_STRIP_MODULES) Modules/ and package $(words $(SPM_SHIP_FRAMEWORKS)) frameworks from the archive"
	@# Materialize SwiftPM checkouts via swift-create-xcframework's OWN resolver
	@# (--list-products resolves + checks out without building) so the swift-log
	@# version we patch is the SAME one the build uses. `swift package resolve`
	@# (system SwiftPM) pins a newer swift-log than swift-create-xcframework's
	@# bundled resolver, which the build step then re-resolves + overwrites —
	@# discarding the patch. The build below reuses these checkouts and does not
	@# re-clone, so the patch survives (verified MOB-338).
	cd $(WORK_DIR) && $(SWIFT_CREATE_XCFRAMEWORK) --list-products
	python3 $(CURDIR)/.github/scripts/patch_swiftlog.py \
	  "$(WORK_DIR)/.build/checkouts/swift-log"
	@echo "▶▶▶ Build [$(SPM_BUILD_PRODUCTS)] with library evolution (leaves a full-stack archive)"
	@# --output goes to scratch: the tool's own xcframeworks are interface-only
	@# (no binary .swiftmodule) and don't include the full 7-framework set, so we
	@# discard them and build every shipped xcframework ourselves from the archive.
	cd $(WORK_DIR) && $(SWIFT_CREATE_XCFRAMEWORK) \
	  --platform ios \
	  --stack-evolution \
	  --xc-setting IPHONEOS_DEPLOYMENT_TARGET=$(SPM_DEPLOYMENT_TARGET) \
	  --output $(CURDIR)/$(BUILD_DIR)/spm-scratch/ \
	  $(SPM_BUILD_PRODUCTS)
	@# Post-process + package. The top-level product's archive links the whole
	@# stack, so its Frameworks/ dir holds all 7 frameworks (each with a
	@# .swiftinterface from --stack-evolution). For each device/sim slice: strip
	@# Modules/ from SwiftProtobuf.framework (so it's a non-importable plain dylib;
	@# NO rename / NO install_name_tool — see the var block above). Then create one
	@# xcframework per shipped framework from the slices.
	@#
	@# CRITICAL (MOB-338): `xcodebuild -create-xcframework` strips the binary
	@# .swiftmodule, keeping only the .swiftinterface (the normal distribution
	@# form, for compiler-version independence). But swift-create-xcframework emits
	@# these interfaces with `-no-verify-emitted-module-interface`, so they are
	@# NOT round-trippable: InstantSearchTelemetry's class==module-name self-refs
	@# don't resolve, unavailable-type Sendable extensions fail, and — worst — the
	@# entire `extension SearchParameters { ... }` (Query.hitsPerPage et al.) is
	@# dropped. A consumer that recompiles from these interfaces breaks. Because
	@# this is a PER-XCODE matrix (each slice's compiler === the consumer's Xcode),
	@# we copy the COMPLETE binary .swiftmodule back into each xcframework slice
	@# after create-xcframework; the consumer loads it directly and never touches
	@# the broken interface. (SwiftProtobuf has no Modules/ — skipped.)
	@primary="$(firstword $(SPM_BUILD_PRODUCTS))"; \
	 archbase="$(WORK_DIR)/.build/swift-create-xcframework/build/$$primary"; \
	 dev="$$archbase/iphoneos.xcarchive/Products/Library/Frameworks"; \
	 sim="$$archbase/iphonesimulator.xcarchive/Products/Library/Frameworks"; \
	 for slice in "$$dev" "$$sim"; do \
	   echo "🔧 Stripping Modules/ from $(SPM_PROTOBUF_STRIP_MODULES).framework in $$slice (no rename — see MOB-338)"; \
	   python3 $(CURDIR)/.github/scripts/postprocess_instantsearch.py \
	     "$$slice" $(SPM_PROTOBUF_STRIP_MODULES) || exit 1; \
	 done; \
	 for m in $(SPM_SHIP_FRAMEWORKS); do \
	   echo "📦 Creating $$m.xcframework from post-processed archive"; \
	   if [ ! -d "$$dev/$$m.framework" ] || [ ! -d "$$sim/$$m.framework" ]; then \
	     echo "❌ $$m.framework missing in archive"; echo "device:"; ls "$$dev"; echo "sim:"; ls "$$sim"; exit 1; \
	   fi; \
	   rm -rf $(ARTIFACTS_DIR)/$$m.xcframework; \
	   xcodebuild -create-xcframework \
	     -framework "$$dev/$$m.framework" \
	     -framework "$$sim/$$m.framework" \
	     -output $(ARTIFACTS_DIR)/$$m.xcframework || exit 1; \
	   for slicedir in $(ARTIFACTS_DIR)/$$m.xcframework/*/; do \
	     dstmod="$$slicedir$$m.framework/Modules/$$m.swiftmodule"; \
	     [ -d "$$dstmod" ] || continue; \
	     case "$$slicedir" in *simulator*) srcmod="$$sim/$$m.framework/Modules/$$m.swiftmodule";; *) srcmod="$$dev/$$m.framework/Modules/$$m.swiftmodule";; esac; \
	     for bm in "$$srcmod"/*.swiftmodule; do [ -e "$$bm" ] && cp "$$bm" "$$dstmod/"; done; \
	     echo "  ↳ kept binary .swiftmodule in $$m/$$(basename $$slicedir)"; \
	   done; \
	 done
	@# MOB-375 no-drift guard: every shipped iOS slice must bake exactly the
	@# deployment target we asked for. A slice with a HIGHER minos than the app
	@# supports links fine but crashes the consumer at launch on older iOS
	@# (the InstantSearch minos-17-on-an-iOS-14-app regression). SPM-mode builds
	@# iOS-only (--platform ios), so every slice here is iOS — no platform filter.
	@echo "🔎 Verifying every shipped slice's minos == $(SPM_DEPLOYMENT_TARGET) (MOB-375)"
	@bad=0; \
	 for m in $(SPM_SHIP_FRAMEWORKS); do \
	   for fwbin in $(ARTIFACTS_DIR)/$$m.xcframework/*/$$m.framework/$$m; do \
	     [ -f "$$fwbin" ] || { echo "❌ missing binary: $$fwbin"; bad=1; continue; }; \
	     slice=$$(basename $$(dirname $$(dirname "$$fwbin"))); \
	     got=$$(otool -l "$$fwbin" | awk '$$1=="cmd"&&($$2=="LC_BUILD_VERSION"||$$2=="LC_VERSION_MIN_IPHONEOS"){f=1} f&&$$1=="minos"{print $$2;exit} f&&$$1=="version"{print $$2;exit}'); \
	     if [ "$$got" != "$(SPM_DEPLOYMENT_TARGET)" ]; then \
	       echo "❌ $$m [$$slice]: minos=$$got != $(SPM_DEPLOYMENT_TARGET)"; bad=1; \
	     else \
	       echo "  ✓ $$m [$$slice] minos=$$got"; \
	     fi; \
	   done; \
	 done; \
	 [ "$$bad" = 0 ] || { echo "❌ minos drift — a slice was built for the wrong deployment target (MOB-375). Check IPHONEOS_DEPLOYMENT_TARGET=$(SPM_DEPLOYMENT_TARGET) reached every archive."; exit 1; }
else ifeq ($(USE_PREBUILT),1)
	@echo "▶▶▶ prebuilt-mode vendor '$(VENDOR)': lift committed .xcframeworks from $(words $(PREBUILT_REPO_TAGS)) pinned sub-repos (no source build)"
	@# Clone each zendesk sub-repo at its pinned tag and copy the prebuilt
	@# <Framework>.xcframework (the package's `path:` binaryTarget) out of the
	@# repo root into ARTIFACTS_DIR. The shared sign-xcframeworks step then
	@# re-signs each one under Cambly's identity; zip + checksums follow.
	@srcroot="$(BUILD_DIR)/$(VENDOR)-src"; rm -rf "$$srcroot"; mkdir -p "$$srcroot"; \
	for triple in $(PREBUILT_REPO_TAGS); do \
	  t=$$(printf '%s' "$$triple" | tr -d '"'); \
	  repo=$$(printf '%s' "$$t" | cut -d: -f1); \
	  tag=$$(printf '%s' "$$t" | cut -d: -f2); \
	  fwk=$$(printf '%s' "$$t" | cut -d: -f3); \
	  dest="$$srcroot/$$repo"; \
	  echo ""; echo "▶▶▶ $$repo @ $$tag → $$fwk.xcframework"; \
	  git clone --depth 1 --branch "$$tag" "$(ZENDESK_BASE)/$$repo.git" "$$dest" || exit 1; \
	  ( cd "$$dest" && git lfs pull 2>/dev/null || true ); \
	  src="$$dest/$$fwk.xcframework"; \
	  test -f "$$src/Info.plist" || { echo "❌ $$fwk.xcframework/Info.plist missing at root of $$repo@$$tag (Git LFS not materialized?)"; ls -la "$$dest"; exit 1; }; \
	  rm -rf "$(ARTIFACTS_DIR)/$$fwk.xcframework"; \
	  cp -R "$$src" "$(ARTIFACTS_DIR)/$$fwk.xcframework" || exit 1; \
	  echo "  ✓ staged $$fwk.xcframework"; \
	done
else
	@# Loop over scheme:product pairs. Quoted Make tokens like "Alamofire iOS:Alamofire"
	@# survive shell word-splitting because the surrounding double-quotes are still
	@# present in the substituted text; `for pair in ...` then treats each quoted
	@# token as a single iteration.
	@#
	@# Sanitize step (inside the loop, between archive and -create-xcframework):
	@# Some upstream xcodeprojs add dev-time scripts/sources to the Copy Bundle
	@# Resources phase (e.g. PostHog ships `generate-pb-c.sh`, a protoc-c codegen
	@# helper for PLCrashReporter). Source-form SwiftPM excludes them via
	@# Package.swift `exclude:`, but xcodebuild archive obeys the xcodeproj and
	@# copies them into <Product>.framework/. If they reach the App's Frameworks/
	@# dir, App Store Connect rejects the IPA with error 90035 "Code object is
	@# not signed at all" — altool treats any non-Mach-O file inside a framework
	@# bundle as nested code that must be signed. Stripping them here keeps each
	@# .framework canonical: Mach-O + Info.plist + Headers/ + Modules/ +
	@# Resources/ (+ PrivateHeaders/, PrivacyInfo.xcprivacy when present).
	@for pair in $(SCHEME_PRODUCT_PAIRS); do \
	  scheme="$${pair%%:*}"; \
	  product="$${pair##*:}"; \
	  echo ""; \
	  echo "▶▶▶ Archive scheme=\"$$scheme\" → $$product.framework (iOS device)"; \
	  rm -rf $(BUILD_DIR)/$$product-iOS-device.xcarchive $(BUILD_DIR)/$$product-iOS-sim.xcarchive; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    $(BUILD_PROJECT_FLAG) \
	    -scheme "$$scheme" \
	    -destination "generic/platform=iOS" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-device.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet ) || exit 1; \
	  echo "▶▶▶ Archive scheme=\"$$scheme\" → $$product.framework (iOS Simulator)"; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    $(BUILD_PROJECT_FLAG) \
	    -scheme "$$scheme" \
	    -destination "generic/platform=iOS Simulator" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-sim.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet ) || exit 1; \
	  echo "📦 Creating $$product.xcframework..."; \
	  rm -rf $(ARTIFACTS_DIR)/$$product.xcframework; \
	  device_fwk=$$(find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "$$product.framework" 2>/dev/null | head -n 1); \
	  sim_fwk=$$(find $(BUILD_DIR)/$$product-iOS-sim.xcarchive -type d -name "$$product.framework" 2>/dev/null | head -n 1); \
	  if [ -z "$$device_fwk" ] || [ -z "$$sim_fwk" ]; then \
	    echo "❌ Could not locate $$product.framework"; \
	    echo "  device archive contents:"; find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "*.framework" 2>/dev/null; \
	    echo "  sim archive contents:";    find $(BUILD_DIR)/$$product-iOS-sim.xcarchive    -type d -name "*.framework" 2>/dev/null; \
	    exit 1; \
	  fi; \
	  echo "  device: $$device_fwk"; \
	  echo "  sim:    $$sim_fwk"; \
	  for fwk in "$$device_fwk" "$$sim_fwk"; do \
	    echo "🧹 Stripping dev-time files mistakenly bundled in $$fwk (if any)..."; \
	    find "$$fwk" \( \
	      -name "*.sh" -o -name "*.py" -o -name "*.rb" -o -name "*.pl" -o -name "*.bash" \
	      -o -name "Makefile" -o -name "Rakefile" -o -name "Gemfile*" -o -name "Podfile*" \
	      -o -name "*.swift" -o -name "*.c" -o -name "*.m" -o -name "*.mm" \
	      -o -name "*.cpp" -o -name "*.cc" -o -name "*.proto" -o -name "*.h.in" \
	    \) -print -delete; \
	  done; \
	  echo "  device framework contents (post-sanitize):"; \
	  find "$$device_fwk" -maxdepth 3 2>/dev/null | sed 's|^|    |'; \
	  xcodebuild -create-xcframework \
	    -framework $$device_fwk \
	    -framework $$sim_fwk \
	    -output $(ARTIFACTS_DIR)/$$product.xcframework || exit 1; \
	done
endif

# Sign each .xcframework with the team's Apple Distribution identity before
# zipping. Required by Apple for SDKs on the "commonly used third-party SDK"
# list (Facebook / Lottie / Realm / SDWebImage / Starscream — caught us when
# ITMS-91065 rejected Lexicon 1.2.6, 2026-05-27). Signs the bundle as a whole
# (Apple's documented path; writes _CodeSignature/ at the bundle root + a
# per-slice signature) so consumers can verify origin with `codesign -dv X.xcframework`.
#
# SIGNING_IDENTITY env/make-var is required. CI passes it from
# secrets.SIGNING_IDENTITY; locally:
#   make sign-xcframeworks VENDOR=lottie VERSION=4.6.0 \
#     SIGNING_IDENTITY="Apple Distribution: Cambly Inc. (ZNP9AYBP23)"
#
# --force allows re-running over an already-signed bundle (workflow re-runs).
sign-xcframeworks: build-xcframeworks
	@test -n "$(SIGNING_IDENTITY)" || { echo "❌ SIGNING_IDENTITY required (env or make var)"; exit 1; }
	@# Diagnostic — print what identities codesign can see at sign time, and
	@# the keychain search list / default. If sign fails downstream this is
	@# the first place to look.
	@echo "=== [sign-xcframeworks] keychain state at sign time ==="
	@echo "--- default keychain:"; security default-keychain || true
	@echo "--- search list:"; security list-keychains -d user || true
	@echo "--- codesign identities (all keychains):"; security find-identity -v -p codesigning || true
	@for product in $(PRODUCTS_LIST); do \
	  echo "🔏 Signing $$product.xcframework with: $(SIGNING_IDENTITY)"; \
	  codesign --force --timestamp -vvvv --sign "$(SIGNING_IDENTITY)" \
	    $(ARTIFACTS_DIR)/$$product.xcframework \
	    || { echo "✗ codesign FAILED with exit $$?"; exit 1; }; \
	done

zip: sign-xcframeworks
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS_LIST); do \
	  echo "🗜  Zipping $$product.xcframework..."; \
	  rm -f $$product.xcframework.zip; \
	  zip -qry $$product.xcframework.zip $$product.xcframework; \
	done

checksums: zip
	@echo ""
	@echo "=== sha256 checksums ==="
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS_LIST); do \
	  sha=$$(swift package compute-checksum $$product.xcframework.zip); \
	  echo "$$product: $$sha"; \
	done
