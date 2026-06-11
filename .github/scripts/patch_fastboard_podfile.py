#!/usr/bin/env python3
"""Prepare fastboard-iOS's Example/Podfile for the vendor-binary build.

Why: the Netless stack is built (CocoaPods-mode) from Fastboard's
`Example/Fastboard.xcworkspace`, the only project in the cluster with
`use_frameworks!` enabled (so each pod becomes a dynamic .framework we can
package into an xcframework). Two adjustments are needed before `pod install`:

1. **Pin Whiteboard.** Fastboard 1.4.1's podspec only requires
   `Whiteboard ~> 2.16.81`, but Cambly-Swift consumes Whiteboard 2.16.89 via
   SPM. Inject an explicit `pod 'Whiteboard', '<version>'` into the shared pod
   block to keep the vendored binary at the version Cambly ships. (The stale
   committed `Example/Podfile.lock`, which pins `= 2.16.81` and would make this
   unsatisfiable, is removed by the Makefile's pod-install target.)

2. **Bump the platform.** Upstream's Podfile declares `platform :ios, '11.0'`.
   Cambly's app min deployment is iOS 14, so build the frameworks at 14.0 too —
   matches what Cambly ships and avoids CocoaPods' "required a higher minimum
   deployment target" resolution failure. (A framework's min ≤ the app's min is
   required; 14.0 = app min is the safe maximal choice.)

3. **Force the pod targets' deployment target via a post_install hook.** The
   `platform :ios` line only sets the *user* (Example app) target. Each pod's
   framework target inherits its own podspec's `s.ios.deployment_target`
   (Fastboard / Whiteboard / NTLBridge / White_YYModel all declare `10.0`), so
   without this the frameworks compile at iOS 10 and fail on iOS-11+ APIs the
   sources use unguarded (e.g. `'CACornerMask' is only available in iOS 11.0 or
   newer`). The hook pins every pod target to the same 14.0.

Idempotent: re-running on an already-patched Podfile is a no-op for each edit.
Invoked by the Makefile's `pod-install` target for VENDOR=fastboard.

Usage: patch_fastboard_podfile.py <path-to-Podfile> <whiteboard-version>
"""
import re
import sys

ANCHOR = "def share\n"
PLATFORM_TARGET = "14.0"
PLATFORM_RE = re.compile(r"platform\s*:ios\s*,\s*['\"][0-9.]+['\"]")

POST_INSTALL_MARKER = "# cambly-vendor: force pod target deployment"
POST_INSTALL_BLOCK = f"""
{POST_INSTALL_MARKER}
post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '{PLATFORM_TARGET}'
    end
  end
end
"""


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: patch_fastboard_podfile.py <Podfile> <whiteboard-version>", file=sys.stderr)
        return 2
    podfile, version = sys.argv[1], sys.argv[2]
    with open(podfile) as f:
        src = f.read()

    # 1) Pin Whiteboard.
    if "pod 'Whiteboard'" in src or 'pod "Whiteboard"' in src:
        print(f"✓ Whiteboard pin already present in {podfile}; leaving as-is")
    elif ANCHOR not in src:
        print(f"❌ could not find `def share` anchor in {podfile} — "
              "upstream Podfile layout changed; update this script.", file=sys.stderr)
        return 1
    else:
        src = src.replace(ANCHOR, f"{ANCHOR}  pod 'Whiteboard', '{version}'\n", 1)
        print(f"✓ pinned Whiteboard {version} in {podfile}")

    # 2) Bump the iOS platform to match Cambly's app min deployment.
    desired = f"platform :ios, '{PLATFORM_TARGET}'"
    if desired in src:
        print(f"✓ platform already {PLATFORM_TARGET} in {podfile}; leaving as-is")
    elif PLATFORM_RE.search(src):
        src = PLATFORM_RE.sub(desired, src, count=1)
        print(f"✓ bumped platform to iOS {PLATFORM_TARGET} in {podfile}")
    else:
        print(f"❌ could not find a `platform :ios, '<v>'` line in {podfile} — "
              "upstream Podfile layout changed; update this script.", file=sys.stderr)
        return 1

    # 3) Append the post_install hook that forces every pod target's
    #    IPHONEOS_DEPLOYMENT_TARGET (the `platform` line above only covers the
    #    user/Example target). Upstream's Podfile has no post_install block.
    if POST_INSTALL_MARKER in src:
        print(f"✓ post_install deployment-target hook already present in {podfile}; leaving as-is")
    else:
        if not src.endswith("\n"):
            src += "\n"
        src += POST_INSTALL_BLOCK
        print(f"✓ appended post_install hook forcing pod targets to iOS {PLATFORM_TARGET} in {podfile}")

    with open(podfile, "w") as f:
        f.write(src)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
