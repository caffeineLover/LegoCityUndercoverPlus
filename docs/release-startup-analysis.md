# v1.0.0 startup investigation and v1.0.1 candidate

Investigated 2026-11-21 against local HEAD
`3e0dd0acbd839a24ba01d9c1fa87ff77d90aae31`. The pre-existing untracked
`docs/project-context.md` was read and left unchanged. No commit, push, tag
change, publication, real-game deployment, or game launch was performed.

## Confirmed evidence

The actual published assets were downloaded from GitHub, hashed, extracted,
and inspected as PE files. Public availability of a backend does not establish
permission to redistribute it; none is included in the new package.

| Artifact | SHA-256 | Contents |
| --- | --- | --- |
| [v1.0.0 ZIP](https://github.com/caffeineLover/LegoCityUndercoverPlus/releases/tag/v1.0.0), 88,592 bytes | `8d326ac735088f8fd082702ce92e3a2af0dea2412646bf749b337a52f9c9cfdc` | One enclosing folder and only `steam_api64.dll` (242,176 bytes). No backend, install instructions, or prerequisite information. |
| [Upstream 1.2 ZIP](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/releases/tag/1.2), 481,982 bytes | `beddf5ec6aee541c10195aa41b8cc4a113515a8084644f53a84a51ea6282e351` | Root mod `steam_api64.dll`, `proxy/steam_api64_steam.dll` (206,760 bytes), `proxy/steam_api64_gog.dll` (790,016 bytes). |

Both mod DLLs export the same 690 names and ordinals. The original Steam
backend exports all 690. The GOG compatibility backend exports only 11 and
imports `Galaxy64.dll`. The published mod imports the dynamic MSVC runtime
(`MSVCP140`, `VCRUNTIME140`, `VCRUNTIME140_1`, UCRT API sets), unlike the new
static-CRT candidate.

The published binary contains both relative `proxy\\steam_api64_*.dll` paths.
The matching release source calls `LoadLibrary` without checking the result,
then resolves all 690 exports without checking them. A missing backend leaves
null forwarding targets. The old shared `PA` trampoline also provides no
thread-local isolation between concurrent forwarded calls.

An isolated process probe of the actual published DLL with no backend returned
Windows error 1114 and produced no startup log. This reproduces a silent attach
failure in a non-game host; it is not claimed to reproduce an exact game crash
stack or to establish which game API would fail first.

### Additional evidence from the local installed game (read-only)

The game is installed at `C:\Program Files (x86)\Steam\steamapps\common\LEGO City Undercover`,
not the historical D: path. Its EXE reports `1.0.0.15609011`.

- EXE SHA-256: `624fed07274bbd105d1d571ecb97a290df6f6f0aff76898c516890da6d136f76`.
- Root DLL SHA-256: `175513465aa99ebbcd1e8fd7461c0c43038423e7b1605b667d46fd7bbe2f14e5`,
  exactly matching the mod DLL extracted from published v1.0.0.
- No `proxy/` directory is present.
- `steam_api64.dll.orig` is preserved, SHA-256
  `81321a5cb72ae3f81243fd0b0d8928a063ca09129ab0878573bd36a28422ec4c`,
  exactly matching upstream 1.2's original Steam backend. The new native loader
  successfully loaded this local original and validated all its exports.
- The EXE imports 11 Steam APIs, all by name: `SteamAPI_Init`,
  `SteamAPI_RegisterCallback`, `SteamAPI_RestartAppIfNecessary`,
  `SteamAPI_RunCallbacks`, `SteamAPI_Shutdown`, `SteamAPI_UnregisterCallback`,
  `SteamApps`, `SteamRemoteStorage`, `SteamUser`, `SteamUserStats`, `SteamUtils`.
  All are present in both edition backends and the published proxy.

This establishes a concrete incomplete installation matching the release
packaging defect. The original is recoverable; there is no need to obtain a
replacement DLL from an unofficial site. No files in that installation were
changed during this investigation.

For this specific installation, follow the manual-backend step in INSTALL.md:
verify the preserved `.orig` hash above, create `proxy/`, copy that original as
`proxy/steam_api64_steam.dll` without overwriting any existing backend, verify
the copy, then run the extracted candidate's installer. Retain `.orig` as an
independent recovery copy. These are recovery instructions, not actions already
performed on the installed game.

## Root cause versus hypotheses

**Confirmed release defect:** v1.0.0's extraction-only instructions omit a
runtime backend required by its loader. A clean installation made from that ZIP
cannot forward the game's required Steam APIs. Unchecked loading/export lookup
and debug-only/silent attach errors make that defect difficult to diagnose.
An upgrade over upstream 1.2 could accidentally work because it retains the
missing `proxy/` directory; it was not a valid clean-install test.

**Confirmed independent loader defect:** supporting paths use process CWD
instead of the installed mod's directory. A launch with a different working
directory can miss an otherwise correctly installed backend.

**Not established as causes of this reported incident:** missing MSVC runtime,
a wrong-architecture backend, a backend's failing `DllMain`, loader-lock
deadlock, or a different game version. The release's named/ordinal export table
is complete for the inspected supported executable; missing exported names in
the published mod are not supported as the cause. We have not claimed a live
game launch or a captured crash stack.

## Changes and boundaries

- Resolve the backend from `GetModuleFileNameW(hModule)`, with checked path
  handling. Search dependencies only in the backend directory, application
  directory and System32; never in CWD. Preserve installed GOG dependencies.
- Reject failed loads before export resolution. Validate the complete advertised
  Steam backend table, or GOG's 11 required APIs, before publishing pointers.
  Failed validation releases the module and leaves no partial table.
- Preserve all 690 exported names/ordinals using a checked shared manifest.
  Replace the shared scratch-pointer C++ wrappers with per-export MASM tail
  jumps, preserving integer/floating-point registers, stack arguments and return
  values. Missing optional GOG APIs terminate with an export-specific diagnostic
  rather than calling null or returning a fabricated result.
- Write absolute path, missing export and Windows error text/code to
  `lcu-startup.log`, with debugger output and a TEMP fallback. No modal User32
  UI is added inside `DllMain`.
- Verify the executable's FileVersion text before applying existing RVAs.
  The final build number exceeds a WORD, so it must not be truncated into
  `VS_FIXEDFILEINFO` components. Unsupported/unverifiable hosts retain API
  forwarding but get no camera/input/window hooks. This does not add support for
  any other executable version. All game offsets and camera/input behavior are
  unchanged.
- Create both hooks before enabling either; clean up on failure. If cleanup
  itself fails, log and terminate rather than unload a DLL still referenced by
  enabled detours. This rare fail-fast path is reviewed against MinHook's failure
  contract; it has not been fault-injected live. Avoid MinHook thread suspension
  and recursive backend unloading on process-termination detach. Preserve
  sensitivity saving and existing INI lookup behavior.
- Build the Release DLL with the static CRT and ship exact corresponding
  source, GPL/license notices, installation/rollback tooling and checksums.

### DllMain review / residual risk

Backend loading, config I/O and MinHook setup still run during attach. Microsoft
[explicitly warns against LoadLibrary/LoadLibraryEx and thread synchronization
under the loader lock](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices).
MinHook may suspend threads while installing hooks, so this remains an inherited
startup risk, not a proven cause here. The focused fix does not pretend that
checking a load result removes loader-lock risk.

Recommended follow-up: use an ABI-preserving, once-only lazy export bootstrap
outside `DllMain`, then install hooks at a verified safe point. Do not start a
worker and wait for it inside `DllMain`, or let an asynchronous worker race
unresolved game imports. That architectural change needs dedicated timing and
live-game validation; it is deliberately not mixed into this packaging repair.
Explicit dynamic unload while game callbacks are active is also not supported.

## Reproduce the candidate and checks

Use Visual Studio 2026 C++ Build Tools (v145) plus Windows SDK:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1
```

The script builds Release x64, runs all three pre-existing suites and the new
loader/forwarding tests, then creates the package and runs clean-layout tests.
The ZIP path is `Release/packages/LegoCityUndercoverPlus.v1.0.1.zip`, with a
`.sha256` sidecar and an internal `SHA256SUMS`. Existing output ZIPs are not
silently overwritten: move an old candidate aside or choose `-Version` first.

`Package-Release.ps1` accepts only an x64 DLL with the expected export
name/ordinal table and no dynamic CRT imports. It uses an explicit payload,
controlled source-file collection, sorted entries and fixed ZIP timestamps.
`Verify-Package.ps1` checks complete checksum coverage, exact required layout,
unexpected/unsafe paths, and forbidden game/backend/INI/build files. Repeating
packaging with identical inputs yields identical ZIP bytes; this is not a claim
of bit-for-bit reproducible MSVC compilation across toolchain versions.

The private installation supplies its own original DLL. Do not copy proprietary
backends into a release staging directory. The package's `proxy/README.txt`
preserves the required directory hierarchy without redistributing game code.
See [INSTALL.md](INSTALL.md) for clean installation, upgrades and rollback.

## Verification results

- Release x64 built with MSVC 14.52.37025 / v145, VS Build Tools 18.12.1.
- Existing `MouseCameraStateTests`, `RawInputLifecycleTests`, `SettingsTests`:
  passed. Camera/settings tests compile with `/W4 /WX` as required.
- `ProxyLoaderTests`: missing file, invalid image, missing required export,
  Steam/GOG fixture success, wrong edition, rejected backend initialization,
  missing dependent DLL, and the local original Steam DLL: passed.
- `StartupFailureTests`: published v1.0.0 failed the new diagnostic assertion;
  candidate passed, with error 1114 plus the absolute backend path/error log.
- `ProxyForwardingTests`: integer/floating-point and fifth stack argument,
  return values, concurrent calls, both editions, unrelated CWD, unsupported
  host gating, and safe unavailable GOG-export termination: passed.
- Package checks and Steam/GOG synthetic clean install, repeat install/upgrade,
  rollback and verified backup recovery: passed. Missing-original and
  unsupported-version layouts, forbidden backend ZIP entries and checksum
  corruption are rejected. Empty/incomplete/duplicate extracted-package
  manifests are rejected before modifying an installation.
- PE inspection: x64, all 690 names/ordinals preserved; candidate imports only
  `VERSION.dll`, `SETUPAPI.dll`, `KERNEL32.dll`, `USER32.dll`.
- Known unchanged warnings: `Vector3.cpp` C4244 (double-to-float) and
  `RawInput.cpp` C4456 (shadowed local). Not represented as a warning-free build.
- Actual game launch, camera/ferry regressions and live Steam/GOG services:
  **not run**. Synthetic GOG coverage does not establish live GOG compatibility.

Build Tools/SDK were absent initially. Microsoft's signed installer was verified
and installation approved before building. The first sandboxed MSBuild run hit
FileTracker access denial; the approved unsandboxed build succeeded. The only
compiler compatibility adjustment was replacing deprecated `std::result_of`
with equivalent C++17 `std::invoke_result` in the existing ABI assertion.

## Suggested v1.0.1 release checklist (approval required to publish)

- [ ] Review the focused source, loader-lock limitations and installation guide.
- [ ] From the final tree, run the full build/test/package command above.
- [ ] Verify ZIP and DLL hashes, export parity, static runtime and source/license
      payload; retain the matching source tree and build output.
- [ ] Test a known-clean supported Steam installation using its own original DLL.
      Verify install, startup, Steam services and rollback with backups intact.
- [ ] Recheck mouse movement/zoom/buttons, F8 and held F8, F9, focus loss/regain,
      scripted cameras, loading/fast travel, and Albatross ferry round trip.
- [ ] Test the same supported GOG executable/dependency layout if advertising
      GOG compatibility; otherwise clearly state that GOG is not newly live-tested.
- [ ] Test missing backend and failed backend diagnostics on a user-writable and
      a protected game directory; confirm TEMP fallback on the latter.
- [ ] Explain that v1.0.0 was an incomplete clean-install package, originals must
      come from the user's own game, and no new executable versions are supported.
- [ ] After owner approval only: commit final sources, create v1.0.1, upload the
      verified ZIP/checksum, and publish corrected instructions. Do not move or
      replace v1.0.0's tag. Any v1.0.0 release-note edit also needs owner approval.
