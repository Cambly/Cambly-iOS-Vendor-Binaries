#!/usr/bin/env python3
"""Strip the Modules/ directory from a vendored framework so it ships as a plain
(non-importable) dynamic library.

Used for SwiftProtobuf in the InstantSearch stack. Why (MOB-338):
- instantsearch-telemetry pulls apple/swift-protobuf, and Cambly-Swift's graph
  ALSO has apple/swift-protobuf from source (Cambly-Analytics-Tags @ 1.38). If the
  vendored SwiftProtobuf shipped an importable module, the consumer would see TWO
  importable `SwiftProtobuf` modules → ambiguous import / build failure. Removing
  Modules/ makes ours a pure runtime dylib (dyld resolves it by install-name +
  symbol; nobody imports it), leaving the app's source SwiftProtobuf as the only
  importable one.

History: we used to ALSO rename the framework SwiftProtobuf → ISSwiftProtobuf here
(via install_name_tool on the framework + every consumer's @rpath). That was to
dodge a SwiftPM target-name collision back when InstantSearch shipped as a
CamblyVendorBinaries `.binaryTarget`. InstantSearch now ships as per-Xcode LOCAL
frameworks (consumed via xcodegen `framework:`, never in a SwiftPM graph), so that
collision is gone — AND the install_name_tool surgery left the modified Mach-O's
code pages mis-validating at runtime (`CODESIGNING Invalid Page` SIGKILL under the
debugger on the simulator). So the rename is dropped; only the Modules/ strip
remains, which never touches the binary and so can't corrupt the signature.

Operates in place on an .xcarchive's `Products/Library/Frameworks` directory. Run
once per slice (device + simulator).

Usage:
    python3 postprocess_instantsearch.py <archive-frameworks-dir> <FrameworkName>
    e.g. ... .../iphoneos.xcarchive/Products/Library/Frameworks SwiftProtobuf
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.exit("usage: postprocess_instantsearch.py <frameworks-dir> <FrameworkName>")
    fwks = Path(argv[1])
    name = argv[2]
    if not fwks.is_dir():
        sys.exit(f"❌ frameworks dir not found: {fwks}")

    fw = fwks / f"{name}.framework"
    if not fw.is_dir():
        sys.exit(f"❌ {name}.framework not found in {fwks}")

    modules = fw / "Modules"
    if modules.is_dir():
        # No one imports this module; removing Modules/ lets create-xcframework
        # package it as a plain dynamic library (no .swiftinterface required) and
        # keeps the consumer from seeing a second importable `SwiftProtobuf`.
        shutil.rmtree(modules)
        print(f"✓ Stripped Modules/ from {name}.framework in {fwks}")
    else:
        print(f"• {name}.framework has no Modules/ (already stripped) in {fwks}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
