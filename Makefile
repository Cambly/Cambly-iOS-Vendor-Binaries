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
  # Each scheme corresponds to a binary-production product injected by the
  # facebook-prepare target's Package.swift overlay
  # (.github/scripts/binary_build_overlay_facebook.py).
  # Order: leaf deps first (less wasteful if a later target fails).
  PRODUCTS := FBSDKCoreKit_Basics LegacyCoreKit FacebookCore FBSDKCoreKit FBSDKLoginKit FacebookLogin
endif

# ─── Targets ────────────────────────────────────────────────────────────────

.PHONY: all clean clone facebook-prepare build-xcframeworks zip checksums require-args

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
	@# Per-vendor "prepare" hook: idempotent transformation of WORK_DIR contents
	@# (removing conflicting xcworkspaces, applying Package.swift overlays, etc.)
	@# Vendors with clean SPM packages can omit a *-prepare target; this guard
	@# silently skips when there isn't one.
	@if $(MAKE) -n $(VENDOR)-prepare >/dev/null 2>&1; then \
	  $(MAKE) --no-print-directory $(VENDOR)-prepare; \
	fi

# Facebook-specific prep: force SPM mode + reshape products for binary distribution.
#   1. Remove FacebookSDK.xcworkspace — without this, xcodebuild auto-picks it
#      over Package.swift and our SPM-target scheme names fail to resolve.
#   2. Remove all *.xcodeproj — many sub-module xcodeprojs would also confuse
#      auto-detection.
#   3. Overlay Package.swift `products: [...]` to expose 6 dynamic single-target
#      products. See .github/scripts/binary_build_overlay_facebook.py.
facebook-prepare:
	@echo "→ facebook-prepare: forcing SPM mode + overlaying Package.swift in $(WORK_DIR)"
	rm -rf $(WORK_DIR)/FacebookSDK.xcworkspace
	find $(WORK_DIR) -type d -name "*.xcodeproj" -prune -exec rm -rf {} +
	python3 $(CURDIR)/.github/scripts/binary_build_overlay_facebook.py $(WORK_DIR)/Package.swift

build-xcframeworks: clone
	mkdir -p $(ARTIFACTS_DIR)
	@# Pass `-workspace .swiftpm/xcode/package.xcworkspace` explicitly so xcodebuild
	@# uses the SwiftPM auto-generated workspace (auto-created on first invocation
	@# from a Package.swift directory). This is the only way to get scheme=product
	@# names matching what our overlay declared.
	@#
	@# Iteration A (debugging Modules/ absence): no -quiet, extra build settings
	@# that should encourage module emission, and post-archive inspection so we
	@# can see where Swift module / ObjC modulemap actually land.
	@#
	@# Only probe FBSDKCoreKit_Basics first (the leaf, fastest). If diagnostic data
	@# is enough we can revert to the full loop after fixing.
	@for product in $(PRODUCTS); do \
	  echo ""; \
	  echo "▶▶▶ Build $$product (iOS device)"; \
	  rm -rf $(BUILD_DIR)/$$product-iOS-device.xcarchive $(BUILD_DIR)/$$product-iOS-sim.xcarchive; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -workspace .swiftpm/xcode/package.xcworkspace \
	    -scheme $$product \
	    -destination "generic/platform=iOS" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-device.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    DEFINES_MODULE=YES \
	    SWIFT_INSTALL_OBJC_HEADER=YES \
	    SWIFT_EMIT_MODULE_INTERFACE=YES \
	  ) || exit 1; \
	  echo ""; \
	  echo "▶▶▶ Build $$product (iOS Simulator)"; \
	  ( cd $(WORK_DIR) && xcodebuild archive \
	    -workspace .swiftpm/xcode/package.xcworkspace \
	    -scheme $$product \
	    -destination "generic/platform=iOS Simulator" \
	    -archivePath $(CURDIR)/$(BUILD_DIR)/$$product-iOS-sim.xcarchive \
	    -configuration Release \
	    SKIP_INSTALL=NO \
	    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
	    DEFINES_MODULE=YES \
	    SWIFT_INSTALL_OBJC_HEADER=YES \
	    SWIFT_EMIT_MODULE_INTERFACE=YES \
	  ) || exit 1; \
	  echo ""; \
	  echo "🔍 Post-archive diagnostics for $$product:"; \
	  echo "  --- all .framework dirs in device archive:"; \
	  find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "*.framework" 2>/dev/null || true; \
	  echo "  --- module-related files anywhere in device archive:"; \
	  find $(BUILD_DIR)/$$product-iOS-device.xcarchive \( -name "*.swiftmodule" -o -name "*.swiftinterface" -o -name "*.modulemap" -o -name "module.modulemap" \) 2>/dev/null || true; \
	  echo "  --- Modules/ dirs in device archive:"; \
	  find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "Modules" 2>/dev/null || true; \
	  echo ""; \
	  echo "📦 Creating $$product.xcframework..."; \
	  rm -rf $(ARTIFACTS_DIR)/$$product.xcframework; \
	  : "Prefer Library/Frameworks/ over usr/local/lib/ (former is dynamic-ready, latter is often static stub)"; \
	  device_fwk=$$(find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "$$product.framework" -path "*Library/Frameworks*" 2>/dev/null | head -n 1); \
	  [ -z "$$device_fwk" ] && device_fwk=$$(find $(BUILD_DIR)/$$product-iOS-device.xcarchive -type d -name "$$product.framework" 2>/dev/null | head -n 1); \
	  sim_fwk=$$(find $(BUILD_DIR)/$$product-iOS-sim.xcarchive -type d -name "$$product.framework" -path "*Library/Frameworks*" 2>/dev/null | head -n 1); \
	  [ -z "$$sim_fwk" ] && sim_fwk=$$(find $(BUILD_DIR)/$$product-iOS-sim.xcarchive -type d -name "$$product.framework" 2>/dev/null | head -n 1); \
	  if [ -z "$$device_fwk" ] || [ -z "$$sim_fwk" ]; then \
	    echo "❌ Could not locate $$product.framework"; exit 1; \
	  fi; \
	  echo "  using device: $$device_fwk"; \
	  echo "  using sim:    $$sim_fwk"; \
	  echo "  --- device framework contents:"; \
	  find "$$device_fwk" -maxdepth 3 2>/dev/null || true; \
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
