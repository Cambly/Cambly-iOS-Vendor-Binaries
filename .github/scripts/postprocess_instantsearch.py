#!/usr/bin/env python3
"""Rename the vendored SwiftProtobuf framework to ISSwiftProtobuf in a built archive.

Why: instantsearch-telemetry-native pulls apple/swift-protobuf, so the InstantSearch
stack carries a SwiftProtobuf framework. But Cambly-Swift's graph ALSO has
apple/swift-protobuf from source (via Cambly-Analytics-Tags @ 1.38). Shipping our
own `.binaryTarget(name: "SwiftProtobuf")` collides — SwiftPM requires target names
to be unique across the whole package graph ("multiple packages declare targets with
a conflicting name: 'SwiftProtobuf'").

The clean fix would be a SwiftPM `moduleAliases` rename, but swift-create-xcframework's
generated xcodeproj does not honor module aliases (the aliased module fails to compile
its own internal `SwiftProtobuf.X` self-references). So instead we rename at the
Mach-O / bundle level after the build: the framework becomes ISSwiftProtobuf.framework
and every InstantSearch framework that dyld-links it is repointed. Nobody in
Cambly-Swift imports this module (it's purely an internal runtime dep of
InstantSearchTelemetry), so renaming the framework — while leaving the Swift module
name inside untouched — is safe: dyld resolves by install-name + symbol name, not by
Swift module name. The app keeps its own source SwiftProtobuf (1.38, used by
Analytics-Tags); our renamed copy coexists in a separate dylib under two-level
namespace. `Modules/` is stripped from the renamed framework because no one imports it
(and that lets `xcodebuild -create-xcframework` package it as a plain dynamic library
rather than demanding a matching `.swiftinterface`).

Operates in place on an .xcarchive's `Products/Library/Frameworks` directory. Run once
per slice (device + simulator).

Usage:
    python3 postprocess_instantsearch.py <archive-frameworks-dir> <OldName> <NewName>
    e.g. ... .../iphoneos.xcarchive/Products/Library/Frameworks SwiftProtobuf ISSwiftProtobuf
"""

from __future__ import annotations

import plistlib
import subprocess
import sys
from pathlib import Path


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        sys.exit("usage: postprocess_instantsearch.py <frameworks-dir> <OldName> <NewName>")
    fwks = Path(argv[1])
    old, new = argv[2], argv[3]
    if not fwks.is_dir():
        sys.exit(f"❌ frameworks dir not found: {fwks}")

    old_fw = fwks / f"{old}.framework"
    if not old_fw.is_dir():
        sys.exit(f"❌ {old}.framework not found in {fwks}")

    old_load = f"@rpath/{old}.framework/{old}"
    new_load = f"@rpath/{new}.framework/{new}"

    # 1) Repoint every OTHER framework that dyld-links the old one.
    for fw in sorted(fwks.glob("*.framework")):
        if fw.name == f"{old}.framework":
            continue
        binary = fw / fw.stem
        if not binary.is_file():
            continue
        otool = subprocess.run(["otool", "-L", str(binary)], capture_output=True, text=True).stdout
        if old_load in otool:
            run("install_name_tool", "-change", old_load, new_load, str(binary))
            print(f"  ↳ repointed {fw.name} → {new_load}")

    # 2) Rename the framework itself: binary, install-id, Info.plist, drop Modules/.
    run("install_name_tool", "-id", new_load, str(old_fw / old))
    (old_fw / old).rename(old_fw / new)

    info = old_fw / "Info.plist"
    if info.is_file():
        with info.open("rb") as fh:
            plist = plistlib.load(fh)
        for key in ("CFBundleExecutable", "CFBundleName"):
            if key in plist:
                plist[key] = new
        with info.open("wb") as fh:
            plistlib.dump(plist, fh)

    modules = old_fw / "Modules"
    if modules.is_dir():
        # No one imports this module; removing Modules/ lets create-xcframework
        # treat it as a plain dynamic library (no .swiftinterface required).
        run("rm", "-rf", str(modules))

    old_fw.rename(fwks / f"{new}.framework")
    print(f"✓ Renamed {old}.framework → {new}.framework in {fwks}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
