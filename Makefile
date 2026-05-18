# Multi-vendor xcframework builder.
#
# Builds upstream SPM packages as .xcframeworks suitable for distribution via
# the binaryTarget entries in Package.swift. Used by .github/workflows/build-*.yml
# but can also be invoked locally as a fallback.
#
# Usage:
#   make all VENDOR=facebook  VERSION=v11.0.1-cambly
#   make all VENDOR=alamofire VERSION=5.10.2          # future
#   make clean
#
# CI runners override UPSTREAM_REPO_URL to HTTPS form with a PAT (no SSH key
# on macos-15). Local devs can use the SSH default.

VENDOR ?=
VERSION ?=
BUILD_DIR := build
ARTIFACTS_DIR := $(BUILD_DIR)/artifacts
# Lazy `=` so `make clean` doesn't require VENDOR/VERSION at parse time.
WORK_DIR = $(BUILD_DIR)/$(VENDOR)-$(VERSION)

# ─── Per-vendor configuration ───────────────────────────────────────────────
# When adding a new vendor: add an ifeq block setting UPSTREAM_REPO_URL and
# PRODUCTS (the SPM scheme list to archive). Keep the VENDOR key in lockstep
# with the `// === <vendor> ===` markers in Package.swift.

ifeq ($(VENDOR),facebook)
  UPSTREAM_REPO_URL ?= git@github.com:Cambly/facebook-ios-sdk.git
  PRODUCTS := FBSDKCoreKit_Basics LegacyCoreKit FacebookCore FBSDKCoreKit FBSDKLoginKit FacebookLogin
endif

# ─── Targets ────────────────────────────────────────────────────────────────

.PHONY: all clean clone build-xcframeworks zip checksums require-args

all: require-args build-xcframeworks zip checksums

require-args:
	@test -n "$(VENDOR)"  || { echo "❌ VENDOR is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(VERSION)" || { echo "❌ VERSION is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(PRODUCTS)" || { echo "❌ Unknown VENDOR='$(VENDOR)' — add an ifeq block in Makefile"; exit 1; }

clean:
	rm -rf $(BUILD_DIR)

clone: require-args
	mkdir -p $(BUILD_DIR)
	test -d $(WORK_DIR) || git clone --depth 1 --branch $(VERSION) $(UPSTREAM_REPO_URL) $(WORK_DIR)

build-xcframeworks: clone
	mkdir -p $(ARTIFACTS_DIR)
	@for product in $(PRODUCTS); do \
	  echo "🔨 Building $$product for iOS device + simulator..."; \
	  rm -rf $(BUILD_DIR)/$$product-iOS-device.xcarchive $(BUILD_DIR)/$$product-iOS-sim.xcarchive; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -scheme $$product \
	    -destination "generic/platform=iOS" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-device.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet ) || exit 1; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -scheme $$product \
	    -destination "generic/platform=iOS Simulator" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-sim.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet ) || exit 1; \
	  echo "📦 Creating $$product.xcframework..."; \
	  rm -rf $(ARTIFACTS_DIR)/$$product.xcframework; \
	  xcodebuild -create-xcframework \
	    -framework $(BUILD_DIR)/$$product-iOS-device.xcarchive/Products/Library/Frameworks/$$product.framework \
	    -framework $(BUILD_DIR)/$$product-iOS-sim.xcarchive/Products/Library/Frameworks/$$product.framework \
	    -output $(ARTIFACTS_DIR)/$$product.xcframework || exit 1; \
	done

zip: build-xcframeworks
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS); do \
	  echo "🗜  Zipping $$product.xcframework..."; \
	  rm -f $$product.xcframework.zip; \
	  zip -qry $$product.xcframework.zip $$product.xcframework; \
	done

checksums: zip
	@echo ""
	@echo "=== sha256 checksums ==="
	@cd $(ARTIFACTS_DIR) && for product in $(PRODUCTS); do \
	  sha=$$(swift package compute-checksum $$product.xcframework.zip); \
	  echo "$$product: $$sha"; \
	done
