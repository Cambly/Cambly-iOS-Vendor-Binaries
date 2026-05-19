# Multi-vendor xcframework builder.
#
# Builds upstream SPM packages / xcodeprojs as .xcframeworks suitable for
# distribution via the binaryTarget entries in Package.swift. Used by
# .github/workflows/build-*.yml but can also be invoked locally as a fallback.
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
# SCHEMES (the xcodebuild scheme list to archive). PRODUCTS is derived from
# SCHEMES by stripping the "-Dynamic" suffix; if a vendor doesn't follow this
# naming convention, set PRODUCTS explicitly to match the framework names.

ifeq ($(VENDOR),facebook)
  UPSTREAM_REPO_URL ?= git@github.com:Cambly/facebook-ios-sdk.git
  # Use the Cambly fork's existing dynamic xcodeproj schemes — these produce
  # proper distribution-ready frameworks with Modules/, Headers/, and Swift
  # module interface files. The fork shipped these for Carthage years ago.
  #
  # We tried SPM-mode build with .library(... type: .dynamic, targets: [X])
  # first; it produced binaries but no module metadata (no .swiftmodule, no
  # modulemap), so consumers couldn't `import` them. See plan for details.
  #
  # Schemes here are dependency-leaf first.
  SCHEMES := FBSDKCoreKit_Basics-Dynamic FBSDKCoreKit-Dynamic FBSDKLoginKit-Dynamic
endif

# Strip "-Dynamic" suffix from each scheme to get the framework / product name.
# (FBSDKCoreKit-Dynamic scheme → produces FBSDKCoreKit.framework etc.)
PRODUCTS := $(SCHEMES:-Dynamic=)

# ─── Targets ────────────────────────────────────────────────────────────────

.PHONY: all clean clone build-xcframeworks zip checksums require-args

all: require-args build-xcframeworks zip checksums

require-args:
	@test -n "$(VENDOR)"  || { echo "❌ VENDOR is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(VERSION)" || { echo "❌ VERSION is required, e.g. make all VENDOR=facebook VERSION=v11.0.1-cambly"; exit 1; }
	@test -n "$(SCHEMES)" || { echo "❌ Unknown VENDOR='$(VENDOR)' — add an ifeq block in Makefile"; exit 1; }

clean:
	rm -rf $(BUILD_DIR)

clone: require-args
	mkdir -p $(BUILD_DIR)
	test -d $(WORK_DIR) || git clone --depth 1 --branch $(VERSION) $(UPSTREAM_REPO_URL) $(WORK_DIR)

build-xcframeworks: clone
	mkdir -p $(ARTIFACTS_DIR)
	@for scheme in $(SCHEMES); do \
	  product=$${scheme%-Dynamic}; \
	  echo ""; \
	  echo "▶▶▶ Archive $$scheme (iOS device)"; \
	  rm -rf $(BUILD_DIR)/$$product-iOS-device.xcarchive $(BUILD_DIR)/$$product-iOS-sim.xcarchive; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -workspace FacebookSDK.xcworkspace \
	    -scheme $$scheme \
	    -destination "generic/platform=iOS" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-device.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    -quiet ) || exit 1; \
	  echo "▶▶▶ Archive $$scheme (iOS Simulator)"; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -workspace FacebookSDK.xcworkspace \
	    -scheme $$scheme \
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
	  echo "  device framework contents (sanity check Modules/ + Headers/):"; \
	  find "$$device_fwk" -maxdepth 3 2>/dev/null | sed 's|^|    |'; \
	  xcodebuild -create-xcframework \
	    -framework $$device_fwk \
	    -framework $$sim_fwk \
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
