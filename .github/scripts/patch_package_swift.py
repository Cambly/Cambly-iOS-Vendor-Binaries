#!/usr/bin/env python3
"""Patch Package.swift binaryTarget urls + checksums for one vendor section.

Reads env vars VENDOR + ASSETS_TAG + <TargetName>_SHA for each .binaryTarget
inside the vendor's section, and rewrites the file in place.

Vendor sections are delimited by `// === <vendor-key> ===` marker comments in
Package.swift. The script processes the targets-array section, not the
products-array section (only binaryTargets need patching).

Usage (from CI):
    VENDOR=facebook \\
    ASSETS_TAG=facebook-v11.0.1-cambly \\
    FacebookLogin_SHA=abcd... \\
    FacebookCore_SHA=efgh... \\
    ... \\
    python3 .github/scripts/patch_package_swift.py
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REPO_URL_BASE = "https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases/download"
PACKAGE_SWIFT = Path(__file__).resolve().parents[2] / "Package.swift"


def main() -> int:
    vendor = require_env("VENDOR")
    assets_tag = require_env("ASSETS_TAG")

    text = PACKAGE_SWIFT.read_text()
    targets_section = locate_targets_array(text)
    if targets_section is None:
        sys.exit("❌ Couldn't locate `targets: [ ... ]` array in Package.swift")
    targets_start, targets_end = targets_section

    vendor_section = locate_vendor_section(text, vendor, targets_start, targets_end)
    if vendor_section is None:
        sys.exit(
            f"❌ Couldn't find `// === {vendor} ===` marker inside targets array. "
            f"Add the marker + at least one .binaryTarget entry before running."
        )
    section_start, section_end = vendor_section

    section_text = text[section_start:section_end]
    new_section, patched = patch_section(section_text, assets_tag)
    if patched == 0:
        sys.exit(f"❌ No .binaryTarget entries found inside `{vendor}` section")

    new_text = text[:section_start] + new_section + text[section_end:]
    if new_text == text:
        print(f"✓ No changes (already up-to-date for {vendor}@{assets_tag})")
        return 0

    PACKAGE_SWIFT.write_text(new_text)
    print(f"✓ Patched {patched} binaryTarget(s) in `{vendor}` section → {assets_tag}")
    return 0


def require_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        sys.exit(f"❌ Missing required env var: {name}")
    return val


# Match `targets: [` and find its matching `]`. Naive bracket counting works
# because Package.swift doesn't put `[` / `]` in string literals.
def locate_targets_array(text: str) -> tuple[int, int] | None:
    m = re.search(r"\btargets:\s*\[", text)
    if not m:
        return None
    open_pos = m.end() - 1  # the `[`
    depth = 0
    for i in range(open_pos, len(text)):
        ch = text[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                return open_pos + 1, i
    return None


# Find lines `// === <vendor> ===` (case-insensitive on vendor) within
# [targets_start, targets_end). The vendor section runs from after that marker
# line until the next `// === ...` marker OR until targets_end.
def locate_vendor_section(
    text: str, vendor: str, targets_start: int, targets_end: int
) -> tuple[int, int] | None:
    region = text[targets_start:targets_end]
    pattern = re.compile(
        rf"(^[ \t]*//\s*===\s*{re.escape(vendor)}\s*===[^\n]*\n)",
        re.MULTILINE | re.IGNORECASE,
    )
    m = pattern.search(region)
    if not m:
        return None
    section_start = targets_start + m.end()

    next_marker = re.search(r"^[ \t]*//\s*===\s*\S", region[m.end():], re.MULTILINE)
    if next_marker:
        section_end = targets_start + m.end() + next_marker.start()
    else:
        section_end = targets_end
    return section_start, section_end


# Replace url + checksum inside each `.binaryTarget(name: "X", url: "...", checksum: "...")`.
# Preserves indentation by reusing the original whitespace before `.binaryTarget`.
BINARY_TARGET_RE = re.compile(
    r"""
    (?P<indent>^[ \t]*)
    \.binaryTarget\(\s*
        name:\s*"(?P<name>[A-Za-z0-9_]+)"\s*,\s*
        url:\s*"[^"]*"\s*,\s*
        checksum:\s*"[^"]*"\s*
    \)
    """,
    re.VERBOSE | re.MULTILINE,
)


def patch_section(section: str, assets_tag: str) -> tuple[str, int]:
    count = 0

    def replace(m: re.Match) -> str:
        nonlocal count
        name = m.group("name")
        indent = m.group("indent")
        sha_env = f"{name}_SHA"
        sha = os.environ.get(sha_env)
        if not sha:
            sys.exit(f"❌ Missing env var: {sha_env} (required for binaryTarget '{name}')")
        if len(sha) != 64 or not all(c in "0123456789abcdef" for c in sha.lower()):
            sys.exit(f"❌ {sha_env} doesn't look like a sha256 (expected 64 hex chars), got: {sha!r}")
        count += 1
        url = f"{REPO_URL_BASE}/{assets_tag}/{name}.xcframework.zip"
        inner_indent = indent + "  "
        return (
            f"{indent}.binaryTarget(\n"
            f'{inner_indent}name: "{name}",\n'
            f'{inner_indent}url: "{url}",\n'
            f'{inner_indent}checksum: "{sha}"\n'
            f"{indent})"
        )

    new_section = BINARY_TARGET_RE.sub(replace, section)
    return new_section, count


if __name__ == "__main__":
    sys.exit(main())
