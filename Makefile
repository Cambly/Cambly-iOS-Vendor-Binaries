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

# ─── Targets ────────────────────────────────────────────────────────────────

.PHONY: all clean clone build-xcframeworks zip checksums require-args

all: require-args build-xcframeworks zip checksums

require-args:
	@test -n "$(VENDOR)"  || { echo "❌ VENDOR is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(VERSION)" || { echo "❌ VERSION is required"; exit 1; }
	@# Avoid `test -n "$(SCHEME_PRODUCT_PAIRS)"` here — that variable's value
	@# embeds its own double quotes (so each scheme:product token survives shell
	@# word-splitting), and re-quoting it tears the value apart. Validate VENDOR
	@# against the known list of ifeq blocks instead.
	@case "$(VENDOR)" in \
	  facebook|alamofire|lottie|keychainaccess|devicekit|sdwebimage|sentry|posthog|iterable|starscream) : ;; \
	  *) echo "❌ Unknown VENDOR='$(VENDOR)' — add an ifeq block in Makefile"; exit 1 ;; \
	esac

clean:
	rm -rf $(BUILD_DIR)

clone: require-args
	mkdir -p $(BUILD_DIR)
	test -d $(WORK_DIR) || git clone --depth 1 --branch $(VERSION) $(UPSTREAM_REPO_URL) $(WORK_DIR)

# PRODUCTS is derived from SCHEME_PRODUCT_PAIRS for use by zip / checksums.
# (Bash-level split on ":" inside each pair.)
PRODUCTS_LIST = $(shell printf '%s\n' $(SCHEME_PRODUCT_PAIRS) | tr -d '"' | awk -F: '{print $$2}')

build-xcframeworks: clone
	mkdir -p $(ARTIFACTS_DIR)
	@# Loop over scheme:product pairs. Quoted Make tokens like "Alamofire iOS:Alamofire"
	@# survive shell word-splitting because the surrounding double-quotes are still
	@# present in the substituted text; `for pair in ...` then treats each quoted
	@# token as a single iteration.
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
	  echo "  device framework contents:"; \
	  find "$$device_fwk" -maxdepth 3 2>/dev/null | sed 's|^|    |'; \
	  xcodebuild -create-xcframework \
	    -framework $$device_fwk \
	    -framework $$sim_fwk \
	    -output $(ARTIFACTS_DIR)/$$product.xcframework || exit 1; \
	done

zip: build-xcframeworks
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
