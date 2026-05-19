#!/usr/bin/env python3
"""Overlay the upstream Cambly/facebook-ios-sdk Package.swift for binary production.

The upstream Package.swift declares 4 library products at coarse granularity:

  .library(name: "FacebookCore", targets: ["FacebookCore", "FBSDKCoreKit"])
  .library(name: "FacebookLogin", targets: ["FacebookLogin"])
  .library(name: "FacebookShare", ...)
  .library(name: "FacebookGamingServices", ...)

Defaults are static. That doesn't match what we need for xcframework distribution:
each importable Swift/ObjC module should ship as its own dynamic framework so
consumers can `import FacebookLogin` *and* `import FBSDKLoginKit` *and*
`import FacebookCore` *and* `import FBSDKCoreKit` — all four are used by
Cambly-Swift (verified 2026-05-19, see MOB-222 plan).

This script rewrites the products: [...] block in upstream Package.swift to
expose 6 `.library(... type: .dynamic, targets: [<single-target>])` entries,
one per SPM target in the FacebookLogin transitive dep chain:

  FBSDKCoreKit_Basics, LegacyCoreKit, FacebookCore, FBSDKCoreKit,
  FBSDKLoginKit, FacebookLogin

We deliberately drop FacebookShare / FacebookGamingServices / FBSDKTVOSKit —
Cambly-Swift has 0 imports of those (verified 2026-05-19).

The targets: [...] section is untouched. Only the products array is replaced.

Usage:
    python3 binary_build_overlay_facebook.py <path-to-upstream-Package.swift>

Idempotent: running twice produces the same result.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

NEW_PRODUCTS_BLOCK = """    products: [
        // ─── Binary-production products (overlay generated for MOB-222) ─────
        // Each SPM target becomes a separate dynamic framework so consumers can
        // import them independently. Order matches the dependency chain from
        // leaf (no deps) to root (FacebookLogin = full Cambly usage).
        .library(name: "FBSDKCoreKit_Basics", type: .dynamic, targets: ["FBSDKCoreKit_Basics"]),
        .library(name: "LegacyCoreKit",       type: .dynamic, targets: ["LegacyCoreKit"]),
        .library(name: "FacebookCore",        type: .dynamic, targets: ["FacebookCore"]),
        .library(name: "FBSDKCoreKit",        type: .dynamic, targets: ["FBSDKCoreKit"]),
        .library(name: "FBSDKLoginKit",       type: .dynamic, targets: ["FBSDKLoginKit"]),
        .library(name: "FacebookLogin",       type: .dynamic, targets: ["FacebookLogin"]),
    ]"""


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit("usage: binary_build_overlay_facebook.py <Package.swift>")
    path = Path(sys.argv[1])
    if not path.is_file():
        sys.exit(f"❌ file not found: {path}")

    original = path.read_text()
    new_text = replace_products_block(original)

    if new_text == original:
        print(f"✓ Already overlaid (no changes): {path}")
        return 0

    path.write_text(new_text)
    print(f"✓ Overlaid products block in {path}")
    return 0


def replace_products_block(content: str) -> str:
    """Find `products: [` and its matching closing `]`, replace with NEW_PRODUCTS_BLOCK.

    Uses naive bracket counting — Package.swift doesn't put `[`/`]` inside string
    literals at this scope, so this is safe.
    """
    m = re.search(r"(?P<indent>[ \t]*)products:\s*\[", content)
    if not m:
        sys.exit("❌ Couldn't find `products: [` in upstream Package.swift")

    block_start = m.start()
    open_bracket = m.end() - 1  # index of `[`
    depth = 0
    close_bracket = None
    for i in range(open_bracket, len(content)):
        ch = content[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                close_bracket = i
                break
    if close_bracket is None:
        sys.exit("❌ Unmatched `[` after `products:` — Package.swift looks malformed")

    block_end = close_bracket + 1
    return content[:block_start] + NEW_PRODUCTS_BLOCK + content[block_end:]


if __name__ == "__main__":
    sys.exit(main())
