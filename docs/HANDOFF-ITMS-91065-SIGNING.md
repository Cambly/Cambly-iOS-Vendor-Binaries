# ITMS-91065 SDK Signing — Handoff

> Started by huihuang on 2026-05-27 in response to Apple rejecting Lexicon v1.2.6 (build 17456). Half-done. Blocked on access I don't have. Picking it up from this doc should be straightforward — read top-to-bottom, then start at the "Unblock & continue" section.

## Problem statement

On 2026-05-27 Apple rejected Lexicon v1.2.6 with `ITMS-91065: Missing signature` for 7 SDKs on their [commonly used third-party SDK list](https://developer.apple.com/support/third-party-SDK-requirements/):

- `FBSDKCoreKit`, `FBSDKCoreKit_Basics`, `FBSDKLoginKit`
- `Lottie`
- `RealmSwift`
- `SDWebImage`
- `Starscream`

Apple now requires xcframeworks of those SDKs to carry a top-level Apple Distribution signature. This repo's Makefile + 10 `build-*.yml` workflows had **zero** `codesign` step — xcframeworks were built, zipped, and uploaded raw. Same for `Cambly-Realm-Binary` repo. Both need a signing step injected into their build pipeline, and every affected vendor needs to be republished under a fresh tag (`-signed` suffix) so SwiftPM consumers re-download cleanly (per the "Don't reuse a release tag" rule already documented in this repo's README).

### Timeline that explains why it suddenly broke

| Date | Event |
|---|---|
| 2026-04-17 | Lexicon's first App Store submission (v1.0) — still source-form SPM |
| 2026-05-19 | First batch of vendor binaries released (facebook / alamofire / lottie / keychainaccess / devicekit) |
| 2026-05-21 | MOB-222 PR #4040 merged into Cambly-Swift — apps now consume binary `CamblyVendorBinaries` |
| 2026-05-22 | Lexicon v1.2.2 — v1.2.5 submitted (same unsigned binaries), **all accepted** ✅ |
| 2026-05-25 | Adults v8.51.0 released (same unsigned binaries) — also accepted, but at risk on next submission |
| **2026-05-27** | Lexicon v1.2.6 (only a build-number bump from v1.2.5, no SDK change) **rejected** ❌ |

So this is Apple tightening enforcement, not anything we changed. The same fix path protects Adults / Kids from the same fate on their next release cycle.

### ⚠️ Important caveat — Apple's ITMS-91065 enforcement is non-deterministic

This is the single most important thing to internalize before reading the rest of the doc, because it shapes the urgency level.

The same set of unsigned binaries:
- ✅ Passed Lexicon v1.2.2, v1.2.3, v1.2.4, v1.2.5 (all submitted on 2026-05-22, all approved)
- ✅ Passed Adults v8.51.0 (submitted 2026-05-25, approved)
- ❌ Got rejected on Lexicon v1.2.6 (submitted 2026-05-27)

Lexicon v1.2.6's release PR diff vs v1.2.5 was a **build-number bump only** — no SDK change, no code change. The binaries Apple analyzed were structurally identical to the four they had just approved 5 days earlier.

**Implication**: Apple's `ITMS-91065` check is intermittent / sampled, not deterministic. One passing submission tells you nothing about the next. We don't know what triggers the check (heuristics on review queue? random sampling? new app vs established app? account-level flags?). What we do know:

1. **Don't read a successful submission as "we're fine"** — Adults v8.51.0 was accepted with unsigned binaries on 2026-05-25 but is at the same risk level as Lexicon was, and **must** ship with signed binaries on its next release.
2. **Don't assume a re-submission of the rejected build will pass** — we considered re-submitting Lexicon 1.2.6 unchanged as a gamble, but explicitly rejected that path (huihuang's decision: "不赌，直接等 signing 修完 + 1.2.7"). The chance of an intermittent pass exists, but waiting is not a tactic — the only durable fix is to sign everything.
3. **Don't pause partway** — once the lottie pilot passes (Step 1), don't stop and verify "did it actually fix the problem" by submitting Lexicon 1.2.7 immediately. Finish Steps 2–4 first (all listed vendors signed), submit 1.2.7, **then** validate. Otherwise an intermittent pass on a partially-signed build gives you a false positive and you might think you're done when you're not.

## What's already done (merged to main)

### PR #1 — `sign-xcframeworks-itms91065-fix` (merged commit `4d03b61`)

`Makefile`:
- New `sign-xcframeworks` target chained between `build-xcframeworks` and `zip`. Runs `codesign --force --timestamp -v --sign "$SIGNING_IDENTITY"` on every `.xcframework` bundle in `$(ARTIFACTS_DIR)`.
- `all:` target chain updated to `require-args build-xcframeworks sign-xcframeworks zip checksums`.
- Requires `SIGNING_IDENTITY` env var (CI: from secret; local: pass on cmdline).

`.github/workflows/build-lottie.yml` (lottie is the pilot vendor):
- 3 new setup steps inserted before the existing build step:
  1. `webfactory/ssh-agent@v0.9.0` loads the GitHub bot SSH key from `secrets.MATCH_GIT_SSH_PRIVATE_KEY`
  2. `gem install fastlane --no-document`
  3. `fastlane sync_code_signing type:appstore readonly:true` clones the encrypted `Cambly-Swift-Signing` repo (via SSH-form `git_url`) and installs the team's Apple Distribution cert into the runner's keychain
- Existing build step renamed to "Build + sign Lottie xcframework via Makefile" and given `SIGNING_IDENTITY: ${{ secrets.SIGNING_IDENTITY }}` env so the Makefile's sign target activates.

### PR #2 — `add-tag-suffix-input` (merged commit `2172334`)

`.github/workflows/build-lottie.yml`:
- New optional `tag_suffix` workflow_dispatch input (default empty).
- `ASSETS_TAG` env and `gh release create "$tag"` line both construct `lottie-${version}${tag_suffix}`.

Why this is needed: signing changes the zip's SHA256 but not the upstream version. Republishing `lottie-4.6.0` under the same tag would brick every consumer's SwiftPM cache (URL-keyed — see the "Don't reuse a release tag" gotcha in the README). With this input, the signed rebuild goes out as `lottie-4.6.0-signed` — fresh URL, fresh cache key, original `lottie-4.6.0` release left alone.

### Repo secrets configured (Settings → Secrets and variables → Actions)

| Secret | Status | Value source |
|---|---|---|
| `MATCH_PASSWORD` | ✅ Set | Same value as Cambly-Swift CircleCI's `MATCH_PASSWORD` |
| `MATCH_GIT_SSH_PRIVATE_KEY` | ⚠️ Set, but currently does not authenticate (see Blocker below) |
| `SIGNING_IDENTITY` | ✅ Set | `Apple Distribution: Cambly Inc. (ZNP9AYBP23)` |

## Current blocker — SSH key authentication

Two workflow runs failed in sequence trying to validate the signing pipeline end-to-end with `lottie-4.6.0`:

- **Run [26504683213](https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/actions/runs/26504683213)**: Failed at the ssh-agent step with `Error loading key "(stdin)": invalid format`. The secret value was rejected by `ssh-add`. Was the result of pasting the wrong thing.

- **Run [26504963206](https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/actions/runs/26504963206)**: After re-uploading what was thought to be the right private key (the `Cambly-Swift-Signing_id_ed25529` file from the "Github - iOS Eng - Machine User" 1Password entry, 411 bytes), failed at the `sync_code_signing` step with:

  ```
  git@github.com: Permission denied (publickey).
  fatal: Could not read from remote repository.
  ```

  The ssh-agent step **did** load the key (no format error). But GitHub rejected it during clone — meaning the loaded private key doesn't correspond to any public key currently authorized on the bot account.

### Root cause

The `cambly-machine-user-ios` GitHub account has **only one** SSH public key registered:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9SwE0fuqODnUOamn20OCcqDogEvOCBpMIemYE2fTpi
```

Verify:
```bash
gh api users/cambly-machine-user-ios/keys
# (last_used: 2026-05-25 — confirms CircleCI is still using this key, so it IS the active key)
```

The 1Password entry "Github - iOS Eng - Machine User" contains two keypair files (`Cambly-Swift_id_ed25529` + `.pub` and `Cambly-Swift-Signing_id_ed25529` + `.pub`), but neither of their public keys matches the one currently registered on GitHub. They appear to be historical leftovers from a previous rotation. **The private key that actually pairs with the currently-registered public key is not in the 1Password vault accessible to huihuang.**

## Unblock & continue — what you (next collaborator) need to do

### Step 0 — Unblock SSH

Two paths. Both need ~10 minutes of work. **Path A is preferred** to keep symmetry with how Cambly-Swift CircleCI authenticates today (same bot account, just a new key alongside the existing one). **Path B is the fallback** if you also can't access the bot account.

#### Path A (preferred) — add a new SSH key to the `cambly-machine-user-ios` bot account

This requires:
- Login access to GitHub as `cambly-machine-user-ios` (password in 1Password entry "Github - iOS Eng - Machine User", email `ios-eng@cambly.com`, recovery codes file also in same entry)
- An authorized 2FA device for that account — **huihuang doesn't have this. If you do, take this path.**

Steps:

1. Locally generate a fresh ed25519 keypair, no passphrase:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/cambly-vendor-binaries-ssh -N "" \
     -C "vendor-binaries-gha-readonly"
   ```

2. Login to GitHub as `cambly-machine-user-ios` → https://github.com/settings/keys → **New SSH key**:
   - Title: `vendor-binaries-gha`
   - Key: contents of `~/.ssh/cambly-vendor-binaries-ssh.pub` (note: `.pub`)
   - Save

3. Update the repo secret with the **private** key (not `.pub`):
   - https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/settings/secrets/actions
   - Find `MATCH_GIT_SSH_PRIVATE_KEY` → **Update**
   - Paste the entire contents of `~/.ssh/cambly-vendor-binaries-ssh` (the file without `.pub` suffix), including the `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` lines and a trailing newline.
   - Save

4. Backup the new private key into the same 1Password entry alongside the existing files, then `rm ~/.ssh/cambly-vendor-binaries-ssh*` locally.

The existing `cambly-machine-user-ios` SSH key on GitHub stays untouched — Cambly-Swift CircleCI continues to use it. We're just adding a second key. Both will authenticate independently.

#### Path B (fallback) — deploy key on `Cambly-Swift-Signing` repo

Use this if you can't get bot-account 2FA either. Bypasses the bot account entirely with a repo-scoped deploy key.

Requires: admin access to https://github.com/Cambly/Cambly-Swift-Signing

Steps:
1. Same `ssh-keygen` as Path A step 1.
2. https://github.com/Cambly/Cambly-Swift-Signing/settings/keys → **Add deploy key**:
   - Title: `vendor-binaries-gha-readonly`
   - Key: contents of `~/.ssh/cambly-vendor-binaries-ssh.pub`
   - **Do NOT** check "Allow write access"
   - Save
3. Same secret update as Path A step 3.
4. Same backup as Path A step 4.

No workflow yml change needed — `git@github.com:Cambly/Cambly-Swift-Signing.git` URL and `webfactory/ssh-agent` work the same against a deploy key.

### Step 1 — Trigger lottie workflow and verify signing pipeline end-to-end (~15 min)

Once SSH is unblocked:

```bash
gh workflow run build-lottie.yml \
  --repo Cambly/Cambly-iOS-Vendor-Binaries \
  -f version=4.6.0 \
  -f tag_suffix=-signed
```

Or via UI: Actions → Build Lottie → Run workflow → version `4.6.0`, tag_suffix `-signed`.

Expected to take ~10–15 minutes. **Success criteria, in order**:

1. The "Set up SSH agent" step succeeds with `Identity added: (stdin)`
2. The "Sync Apple Distribution cert from Cambly-Swift-Signing" step's `security find-identity` output (printed at the end of the step) contains:
   ```
   Apple Distribution: Cambly Inc. (ZNP9AYBP23)
   ```
3. The "Build + sign Lottie xcframework via Makefile" step's log contains:
   ```
   🔏 Signing Lottie.xcframework with: Apple Distribution: Cambly Inc. (ZNP9AYBP23)
   ```
   followed by a clean codesign run.
4. A new release `lottie-4.6.0-signed` appears at https://github.com/Cambly/Cambly-iOS-Vendor-Binaries/releases
5. `Package.swift`'s `// === lottie ===` section auto-patched to point at the new url + sha256 (committed to main by the workflow itself).
6. Local verification:
   ```bash
   gh release download lottie-4.6.0-signed --repo Cambly/Cambly-iOS-Vendor-Binaries
   unzip Lottie.xcframework.zip
   codesign -dv --verbose=4 Lottie.xcframework
   # Look for:
   #   Authority=Apple Distribution: Cambly Inc. (ZNP9AYBP23)
   #   TeamIdentifier=ZNP9AYBP23
   ```

If anything fails here, diagnose before propagating to other vendors.

### Step 2 — Phase 2 PR: composite action + 9 remaining workflows (~45 min)

The 3 setup steps in `build-lottie.yml` (ssh-agent, fastlane install, sync_code_signing) plus the `tag_suffix` input pattern need to land in the other 9 `build-*.yml` workflows. The cleanest refactor is a composite action.

Create `.github/actions/setup-signing/action.yml`:

```yaml
name: Set up xcframework signing
description: Loads SSH key, installs fastlane, syncs Apple Distribution cert from Cambly-Swift-Signing
runs:
  using: composite
  steps:
    - uses: webfactory/ssh-agent@v0.9.0
      with:
        ssh-private-key: ${{ env.MATCH_GIT_SSH_PRIVATE_KEY }}

    - shell: bash
      run: gem install fastlane --no-document

    - shell: bash
      run: |
        fastlane run sync_code_signing \
          type:appstore readonly:true \
          git_url:"git@github.com:Cambly/Cambly-Swift-Signing.git" \
          app_identifier:com.cambly.Cambly
        echo "--- codesign identities available after match:"
        security find-identity -v -p codesigning
```

In each `build-*.yml`:

1. Replace the 3 inline setup steps (in `build-lottie.yml`) or insert (in the other 9) with a single composite action call:
   ```yaml
   - name: Set up xcframework signing
     uses: ./.github/actions/setup-signing
     env:
       MATCH_GIT_SSH_PRIVATE_KEY: ${{ secrets.MATCH_GIT_SSH_PRIVATE_KEY }}
       MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
   ```
2. Add the `tag_suffix` input (mirror the block from `build-lottie.yml` lines 14–18).
3. Update `ASSETS_TAG` and the `gh release create "$tag"` line to use `${{ inputs.version }}${{ inputs.tag_suffix }}`.
4. Add `SIGNING_IDENTITY: ${{ secrets.SIGNING_IDENTITY }}` env to the existing `make all ...` step.

Workflows to update: `build-facebook.yml`, `build-alamofire.yml`, `build-lottie.yml` (refactor only), `build-keychainaccess.yml`, `build-devicekit.yml`, `build-sdwebimage.yml`, `build-sentry.yml`, `build-posthog.yml`, `build-iterable.yml`, `build-starscream.yml`.

Open as one PR — straightforward mechanical change, low review burden.

### Step 3 — Re-release the 7 Apple-listed vendors with `-signed` (~2–3 hours total runtime, sequential)

Only the 7 vendors on Apple's list need signing for the Lexicon 1.2.7 fix. Trigger after Phase 2 PR merges:

```bash
# Already done in Step 1:
# - lottie (lottie-4.6.0-signed)

# Required for ITMS-91065:
gh workflow run build-facebook.yml --repo Cambly/Cambly-iOS-Vendor-Binaries \
  -f version=v11.0.1-cambly -f tag_suffix=-signed

gh workflow run build-sdwebimage.yml --repo Cambly/Cambly-iOS-Vendor-Binaries \
  -f version=5.21.7 -f tag_suffix=-signed

gh workflow run build-starscream.yml --repo Cambly/Cambly-iOS-Vendor-Binaries \
  -f version=4.0.8 -f tag_suffix=-signed

# Realm — see Step 4, separate repo

# Optional but recommended for future-proofing (not on Apple's current list but might be added later):
gh workflow run build-alamofire.yml      --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=5.12.0     -f tag_suffix=-signed
gh workflow run build-devicekit.yml      --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=5.8.0      -f tag_suffix=-signed
gh workflow run build-keychainaccess.yml --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=v4.2.2     -f tag_suffix=-signed
gh workflow run build-sentry.yml         --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=9.13.0     -f tag_suffix=-signed
gh workflow run build-posthog.yml        --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=3.58.3     -f tag_suffix=-signed
gh workflow run build-iterable.yml       --repo Cambly/Cambly-iOS-Vendor-Binaries -f version=6.7.1      -f tag_suffix=-signed
```

Workflows take 10–30 min each. The `concurrency: package-update` group on every workflow serializes them automatically — they queue rather than run in parallel, so you don't have to wait between triggers.

Verify each release with `codesign -dv` on the produced xcframework before moving on.

### Step 4 — Mirror the change into `Cambly-Realm-Binary` repo

`Cambly-Realm-Binary` builds `RealmSwift.xcframework` as **4 per-Xcode slices** (26.1 / 26.2 / 26.3 / 26.4.1) — its build doesn't enable library evolution, so it needs one binary per Xcode generation. The Makefile + workflow mirror this repo's structure.

Mirror changes:
- Makefile: add `sign-xcframeworks` target that loops over **all 4 slices** (each slice is its own xcframework — adapt the iteration that already exists in `build-xcframeworks`).
- Workflow: insert the same 3 setup steps (or reference the composite action once that pattern is extracted into a shared template — but composite actions can't be shared across repos without copying; just inline-copy the 3 steps here).
- Add the same 3 secrets to this repo (Settings → Secrets and variables → Actions): `MATCH_PASSWORD`, `MATCH_GIT_SSH_PRIVATE_KEY`, `SIGNING_IDENTITY`. The `MATCH_GIT_SSH_PRIVATE_KEY` should be the **same private key** added in Step 0.
- Republish as `realm-<version>-signed`.

### Step 5 — Cambly-Swift PR: switch to signed vendor releases

In https://github.com/Cambly/Cambly-Swift:

1. `project_files/swift_packages.yml` — bump the revision pin:
   ```diff
   CamblyVendorBinaries:
     url: git@github.com:Cambly/Cambly-iOS-Vendor-Binaries
   -  revision: starscream-4.0.8
   +  revision: starscream-4.0.8-signed
   ```
   Convention: pin to whichever vendor was just released. The commit at that tag holds the up-to-date URLs for **all** vendors.

2. `LocalPackages/RealmBinary/realm-binaries.json` — update all 4 slice URLs + SHA256s to the new signed Realm release.

3. Regenerate the workspace:
   ```bash
   ./update.sh --skip-resolve-packages
   # Then open Xcode or run xcodebuild -resolvePackageDependencies to refresh Package.resolved
   ```

4. Build verification (each must succeed):
   ```bash
   for scheme in "Cambly Production" "CamblyKids Production" "Lexicon Production"; do
     xcodebuild -disableAutomaticPackageResolution \
       -workspace Cambly.xcworkspace \
       -scheme "$scheme" \
       -destination 'generic/platform=iOS Simulator' \
       build
   done
   ```

5. Lint:
   ```bash
   python3 scripts/lint_binary_embeds.py
   ```

6. **Install on a physical device** for all three apps and confirm each launches without `dyld: Library not loaded` errors. Simulator dyld searches `PackageFrameworks/` as a fallback, so simulator-only verification is not sufficient — this is documented in CLAUDE.md (Build Verification section).

7. Open PR titled e.g. `[BUGFIX] Switch vendor binaries to signed releases (ITMS-91065)`.

### Step 6 — Submit Lexicon 1.2.7 to TestFlight

After Step 5 merges, cut a fresh Lexicon release branch + tag (use the same release flow as v1.2.6 did — typically a `[RELEASE] lexicon vX.Y.Z` PR). Submit to App Store Connect.

**Primary success criterion**: ITMS-91065 no longer fires.

If accepted: queue Adults and Kids release cycles to confirm no regression. Both will hit the same signed pipeline on their next release cut.

If still rejected: capture the new error and triage. Possibilities (low likelihood): incorrect signing identity used, framework bundle layout corrupted by codesign, or Apple flagging a different SDK we missed.

## Useful pointers

- Original Apple rejection email: ITMS-91065, sent 2026-05-27 about Lexicon 1.2.6 build 17456 (check `ios-eng@cambly.com` inbox for the full text)
- The internal full design doc (Chinese) and decision log: on huihuang's machine at `~/.claude/dev_docs/cambly_vendor-binaries-codesign-itms91065.md`
- The internal SSH-key flow diagram (Chinese): `~/.claude/dev_docs/cambly_vendor-binaries-signing-flow.svg`
- Approved plan with context: `~/.claude/plans/giggly-growing-comet.md`
- Repo README's "Operational gotchas" section has two related notes that are still in force: framework sanitize (PostHog gotcha) and don't-reuse-a-tag (PostHog 3.58.3, posthog-3.58.3-codesign-fix history)

## Open questions / decisions to revisit

1. **Should non-Apple-listed vendors be signed too?** (alamofire / devicekit / keychainaccess / sentry / posthog / iterable) — recommended yes for future-proofing, but not blocking the Lexicon 1.2.7 fix. Tagged as "optional" in Step 3.
2. **Tag naming convention for future signing rebuilds**: standardize on `-signed` suffix forever? Or move to `-v2`, `-v3`? Recommend `-signed` for now; revisit at the next vendor upgrade cycle where the upstream version changes anyway.
3. **Key rotation policy**: the SSH key added in Step 0 has no expiry. Document a rotation cadence somewhere (suggest in the repo README under the existing "One-time setup" section) — e.g. yearly, or whenever an engineer leaves the team.
