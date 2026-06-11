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
  SCHEME_PRODUCT_PAIRS := \
    "Fastboard:Fastboard" \
    "Whiteboard:Whiteboard" \
    "NTLBridge:NTLBridge" \
    "White_YYModel:White_YYModel"
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
	  facebook|alamofire|lottie|keychainaccess|devicekit|sdwebimage|sentry|posthog|iterable|starscream|rxswift|promisekit|fastboard) : ;; \
	  *) echo "❌ Unknown VENDOR='$(VENDOR)' — add an ifeq block in Makefile"; exit 1 ;; \
	esac

clean:
	rm -rf $(BUILD_DIR)

clone: require-args
	mkdir -p $(BUILD_DIR)
	test -d $(WORK_DIR) || git clone --depth 1 --branch $(VERSION) $(UPSTREAM_REPO_URL) $(WORK_DIR)

# CocoaPods-mode vendors (USE_COCOAPODS=1) build from a `pod install`-generated
# workspace rather than a committed xcodeproj. Patch the Podfile to pin the
# Whiteboard version, then resolve pods. No-op for every other vendor (their
# upstream ships a standalone xcodeproj, so there is nothing to pod-install).
pod-install: clone
	@if [ -n "$(USE_COCOAPODS)" ]; then \
	  echo "▶▶▶ CocoaPods vendor '$(VENDOR)': pin Whiteboard $(WHITEBOARD_POD_VERSION) + pod install in $(WORK_DIR)/$(COCOAPODS_DIR)"; \
	  python3 $(CURDIR)/.github/scripts/patch_fastboard_podfile.py \
	    "$(WORK_DIR)/$(COCOAPODS_DIR)/Podfile" "$(WHITEBOARD_POD_VERSION)" || exit 1; \
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
