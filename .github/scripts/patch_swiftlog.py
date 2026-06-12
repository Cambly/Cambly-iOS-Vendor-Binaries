#!/usr/bin/env python3
"""Patch swift-log's Logger.Storage initializer for library-evolution builds.

swift-log declares `Logger.Storage.init(label:handler:)` as `@inlinable`. Under
BUILD_LIBRARY_FOR_DISTRIBUTION (library evolution) + Swift 6.x, an `@inlinable`
designated initializer of a class must delegate to another initializer, which
this one doesn't — the build fails with:

    error: initializer for class 'Logger.Storage' is '@inlinable' and must
    delegate to another initializer

We ship swift-log as one of the InstantSearch vendor binaries: it's a runtime
dyld dependency of InstantSearchCore AND appears in InstantSearchCore's public
`.swiftinterface` (`import Logging`), so the consumer's compile must resolve the
`Logging` module — i.e. it has to be its own evolution-enabled, importable
xcframework, not statically absorbed.

To get it to build with evolution we downgrade that one initializer from
`@inlinable` to `@usableFromInline`: a non-inlinable initializer has no
delegation requirement, and `@usableFromInline` keeps it visible to the
`@inlinable copy()` method that calls it. No behavior change — only the
inlinability attribute changes.

The declaration has moved files across swift-log versions (`Logging.swift` in
1.6.x, `Logger.swift` in 1.13.x), so this takes the swift-log *checkout root*
and finds the file under `Sources/Logging/` that contains the initializer
itself rather than hard-coding a filename.

Idempotent: re-running on an already-patched checkout is a no-op. Fails loudly
if the expected `@inlinable init(...)` isn't found in any source file, which
catches upstream drift the next time swift-log is bumped.

Usage:
    python3 .github/scripts/patch_swiftlog.py <path-to-swift-log-checkout-root>
"""

from __future__ import annotations

import re
import stat
import sys
from pathlib import Path

# `@inlinable` attribute immediately preceding the Storage initializer. The
# capture group keeps the (whitespace + init signature) intact so we only swap
# the attribute and stay agnostic to indentation.
INIT_SIG = r"\n\s*init\(label: String, handler: any LogHandler\)"
PATTERN = re.compile(r"@inlinable(" + INIT_SIG + r")")
REPLACEMENT = r"@usableFromInline\1"
ALREADY_PATCHED = re.compile(r"@usableFromInline" + INIT_SIG)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.exit("usage: patch_swiftlog.py <path-to-swift-log-checkout-root>")

    root = Path(argv[1])
    sources = root / "Sources" / "Logging"
    if not sources.is_dir():
        sys.exit(f"❌ swift-log Logging sources not found at {sources}")

    candidates = sorted(sources.glob("*.swift"))
    already = False
    for path in candidates:
        text = path.read_text()
        new_text, n = PATTERN.subn(REPLACEMENT, text)
        if n:
            # SwiftPM marks dependency checkouts read-only; restore write first.
            path.chmod(path.stat().st_mode | stat.S_IWUSR)
            path.write_text(new_text)
            print(f"✓ Patched swift-log Logger.Storage initializer in {path.name} "
                  f"({n} site) → @usableFromInline")
            return 0
        if ALREADY_PATCHED.search(text):
            already = True

    if already:
        print("✓ swift-log already patched; nothing to do")
        return 0

    sys.exit(
        "❌ Expected `@inlinable init(label: String, handler: any LogHandler)` not "
        f"found in any {sources}/*.swift. Upstream may have changed — re-verify "
        "the library-evolution fix for the pinned swift-log version."
    )


if __name__ == "__main__":
    sys.exit(main(sys.argv))
