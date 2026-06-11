#!/usr/bin/env python3
"""Pin the Whiteboard pod version in fastboard-iOS's Example/Podfile.

Why: the Netless stack is built (xcodeproj/CocoaPods-mode) from Fastboard's
`Example/Fastboard.xcworkspace`, the only project in the cluster with
`use_frameworks!` enabled (so each pod becomes a dynamic .framework we can
package into an xcframework). Fastboard 1.4.1's podspec only requires
`Whiteboard ~> 2.16.81`, but Cambly-Swift consumes Whiteboard 2.16.89 via SPM.
To keep the vendored binary at the same Whiteboard version Cambly currently
ships, we inject an explicit `pod 'Whiteboard', '<version>'` into the Podfile's
shared pod block before `pod install`.

Idempotent: if a `pod 'Whiteboard'` line is already present, leaves the file
untouched. Invoked by the Makefile's `pod-install` target for VENDOR=fastboard.

Usage: patch_fastboard_podfile.py <path-to-Podfile> <whiteboard-version>
"""
import sys

ANCHOR = "def share\n"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: patch_fastboard_podfile.py <Podfile> <whiteboard-version>", file=sys.stderr)
        return 2
    podfile, version = sys.argv[1], sys.argv[2]
    with open(podfile) as f:
        src = f.read()

    if "pod 'Whiteboard'" in src or 'pod "Whiteboard"' in src:
        print(f"✓ Whiteboard pin already present in {podfile}; leaving as-is")
        return 0

    if ANCHOR not in src:
        print(f"❌ could not find `def share` anchor in {podfile} — "
              "upstream Podfile layout changed; update this script.", file=sys.stderr)
        return 1

    patched = src.replace(ANCHOR, f"{ANCHOR}  pod 'Whiteboard', '{version}'\n", 1)
    with open(podfile, "w") as f:
        f.write(patched)
    print(f"✓ pinned Whiteboard {version} in {podfile}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
