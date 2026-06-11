#!/usr/bin/env python3
"""Rename the Fastboard pod's Swift module via `s.module_name` in Fastboard.podspec.

Why: Fastboard's module contains a top-level `public class Fastboard` whose name
collides with the module name `Fastboard`. With library evolution
(BUILD_LIBRARY_FOR_DISTRIBUTION=YES), the emitted `.swiftinterface` writes
module-qualified references like `Fastboard.OperationBarDirection`; when a
*different* compiler version re-compiles that interface, `Fastboard` resolves
ambiguously to the class, and types like `OperationBarDirection` /
`FastRoomErrorType` fail with "is not a member type of class Fastboard.Fastboard".
This is what breaks consuming the prebuilt xcframework on Xcode != the build's
(e.g. built on 26.3 / Swift 6.2.4, consumed on 26.5 / Swift 6.3.2), while
collision-free vendors (Alamofire, Whiteboard, …) round-trip fine.

Renaming the *module* to `FastboardSDK` (the class stays `Fastboard`) makes the
interface write `FastboardSDK.Fastboard` (class) vs `FastboardSDK.OperationBar…`
(type) — no ambiguity — restoring true cross-Xcode version independence.

The class name is unchanged, so consumers keep `Fastboard.createFastRoom(...)`;
only the import line changes (`import Fastboard` → `import FastboardSDK`).
Fastboard's own sources have no self-referential `<Fastboard/...>` imports, so
the rename is internally safe.

Idempotent. Invoked by the Makefile's `pod-install` target for VENDOR=fastboard.

Usage: patch_fastboard_podspec.py <path-to-Fastboard.podspec> <module-name>
"""
import re
import sys

# Anchor: insert the module_name line right after the `s.name = '...'` line.
NAME_RE = re.compile(r"^(?P<indent>[ \t]*)s\.name\s*=\s*['\"][^'\"]+['\"][ \t]*\n", re.MULTILINE)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: patch_fastboard_podspec.py <Fastboard.podspec> <module-name>", file=sys.stderr)
        return 2
    podspec, module_name = sys.argv[1], sys.argv[2]
    with open(podspec) as f:
        src = f.read()

    if "module_name" in src:
        print(f"✓ module_name already set in {podspec}; leaving as-is")
        return 0

    m = NAME_RE.search(src)
    if not m:
        print(f"❌ could not find `s.name = '...'` anchor in {podspec} — "
              "upstream podspec layout changed; update this script.", file=sys.stderr)
        return 1

    indent = m.group("indent")
    insertion = f"{indent}s.module_name = '{module_name}'\n"
    src = src[:m.end()] + insertion + src[m.end():]
    with open(podspec, "w") as f:
        f.write(src)
    print(f"✓ set s.module_name = '{module_name}' in {podspec}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
