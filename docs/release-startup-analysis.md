# Startup failure and the v1.0.1 fix

The v1.0.0 ZIP contained the mod DLL but omitted a working installation path
for the game's original Steam/GOG API DLL. Following its extraction-only
instructions on a clean installation could stop the game from starting.

This investigation began November 21, 2026 at commit `3e0dd0a`.
The resulting startup, rollback, installer, and packaging fixes were committed
as `1f2df62` and tagged `v1.0.1`. Only game executable **1.0.0.15609011**
is supported.

For installation steps, use [INSTALL.md](INSTALL.md).

## What the old release was missing

The game loads `steam_api64.dll`. The mod uses that name, then forwards the
game's API calls to an original DLL in `proxy/`:

- Steam: `proxy/steam_api64_steam.dll`
- GOG: `proxy/steam_api64_gog.dll`

The v1.0.0 package shipped only the mod. Its instructions told users to extract
that DLL over the game's original, without first preserving the original under
the required backend filename. An upgrade over upstream 1.2 could work because
it retained the older package's `proxy/` directory; that did not prove a
clean install worked.

The old loader also used paths relative to the process working directory and
did not check `LoadLibrary` or export lookup results. A missing original DLL
left null forwarding targets with no useful startup log. Its shared `PA`
forwarding pointer could also race between callers.

## Evidence from the release files

The published ZIPs were downloaded, hashed, extracted, and inspected as Windows
PE files.

| Archive | Size | Contents |
| --- | --- | --- |
| [Fork v1.0.0](https://github.com/caffeineLover/LegoCityUndercoverPlus/releases/tag/v1.0.0) | 88,592 bytes | One enclosing folder containing only the 242,176-byte mod DLL; no original DLL, installer, or installation guide |
| [Upstream 1.2](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/releases/tag/1.2) | 481,982 bytes | Mod DLL plus original Steam DLL (206,760 bytes) and GOG DLL (790,016 bytes) |

Both mod DLLs advertised the same 690 names and ordinals. The inspected Steam
original provided all 690 exports. The GOG compatibility DLL provided 11
required exports and imported `Galaxy64.dll`.

The v1.0.0 mod depended on the dynamic MSVC runtime: `MSVCP140`,
`VCRUNTIME140`, `VCRUNTIME140_1`, and UCRT API sets. That dependency was
observed, but a missing runtime was not established as the cause of this failure.

A separate process loaded the published mod without a backend. Loading failed
with Windows error 1114 and produced no startup log. That reproduced silent DLL
initialization failure; it did not capture a live game crash stack or identify
the first API the game would have called.

## Initial game installation

The inspected Steam installation was at
`C:\Program Files (x86)\Steam\steamapps\common\LEGO City Undercover`.
Its executable reported `1.0.0.15609011`.

At the initial inspection, its root DLL matched the published v1.0.0 mod and
there was no `proxy/` directory. A preserved `steam_api64.dll.orig` matched
the original Steam DLL from upstream 1.2. The new loader loaded that original
and validated all its exports.

The game executable imported these 11 APIs by name:

```text
SteamAPI_Init
SteamAPI_RegisterCallback
SteamAPI_RestartAppIfNecessary
SteamAPI_RunCallbacks
SteamAPI_Shutdown
SteamAPI_UnregisterCallback
SteamApps
SteamRemoteStorage
SteamUser
SteamUserStats
SteamUtils
```

Both edition originals and the published proxy exposed those names. Missing
exports in the mod were therefore not supported as the cause.

These observations describe the installation before recovery. By the later
installation attempt, the root DLL was the original Steam DLL again. The
packaged installer preserved it in `proxy/` and a checksum-named backup folder,
then installed the new mod. Checksums confirmed the installed DLL matched the
build and the existing INI was unchanged. The owner then reported that it worked.

The first `powershell.exe -File` invocation failed when the package directory
was omitted. Supplying `-PackageDirectory` explicitly succeeded.
[INSTALL.md](INSTALL.md) includes that workaround; the default lookup issue
still needs a code fix.

## What changed

| Area | v1.0.1 behavior |
| --- | --- |
| Original DLL loading | Resolve paths relative to the installed mod; search dependencies in the backend folder, application folder, and System32 |
| Export validation | Check all Steam exports or GOG's 11 required APIs before publishing function pointers |
| Forwarding | Preserve all 690 names/ordinals with per-export MASM tail jumps that retain Win64 register/stack arguments and return values |
| Missing optional GOG API | Write an export-specific diagnostic and terminate with error 127 |
| Startup diagnostics | Log the attempted path, Windows error, and missing export; fall back to TEMP if the game folder is not writable |
| Executable checks | Compare the FileVersion text before using fixed RVAs; leave hooks disabled if the version cannot be verified |
| Hook failures | Create both hooks before enabling either; check rollback results and terminate if live detours cannot be removed |
| Diagnostic failures | Run cleanup before reporting startup failure; an allocation/logging exception cannot bypass required termination |
| Installation and rollback | Verify package checksums, canonical unique paths, and all nine required files before creating backups or replacing DLLs |
| Distribution | Use the static Release CRT and include source, build scripts, license notices, installer, and checksums |

The FileVersion text check matters because `15609011` does not fit in a
16-bit version field. Comparing truncated `VS_FIXEDFILEINFO` components would
not verify the advertised build correctly.

No new camera/input addresses or game-version support were added. The original
Steam/GOG DLL still comes from the user's own game. Publicly downloadable
copies are not included in the release package.

## Remaining startup limits

Backend loading, configuration I/O, and MinHook setup still run inside
`DllMain`. Microsoft
[warns against loading libraries and synchronizing threads under the loader lock](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices).
MinHook can suspend threads while changing hooks. Checking error returns does
not remove that inherited risk, and loader-lock deadlock was not established
as the cause of the reported failure.

Moving startup work out of `DllMain` would require a separate design and timing
tests. Any later change must preserve the forwarding ABI and finish resolving
imports before the game uses them. Starting a worker and waiting for it inside
`DllMain` would introduce another loader-lock hazard.

Explicit DLL unload while game callbacks are in flight is unsupported. During
normal process termination, cleanup avoids MinHook thread suspension and
recursive backend unloading.

## Automated verification

The Release x64 build used MSVC 14.52.37025 / v145 and VS Build Tools 18.12.1.
The following checks passed for the startup fix:

| Tests | Coverage |
| --- | --- |
| Camera state, Raw Input lifecycle, and settings | Existing state, registration, and configuration regressions; camera/settings compile with `/W4 /WX` |
| Proxy loader | Missing file, invalid image, missing export/dependency, rejected backend initialization, Steam/GOG success, wrong edition, and the local original Steam DLL |
| Startup diagnostics | Missing backend rejected with error 1114 and an absolute-path diagnostic; published v1.0.0 failed the diagnostic assertion |
| Forwarding | Integer/floating-point arguments and returns, fifth stack argument, concurrent calls, both edition fixtures, unrelated working directory, unsupported-host gating, and missing optional GOG API |
| Hook startup/cleanup | 12 child-process scenarios covering initialization, creation/enabling failures, ownership, cleanup, diagnostic exceptions, and termination with error 1114 |
| Package and installer | Steam/GOG clean install, upgrade, rollback, backup recovery, unsupported version, missing original, prohibited ZIP files, and checksum corruption |
| Manifest rejection | 42 cases across clean install, upgrade, and rollback, including omitted required files, duplicates, case/alias duplicates, and checksum mismatches |

Hook failure tests substitute the MinHook, backend, and diagnostic boundaries
while exercising the real startup/cleanup code. They do not inject failures
into a running game.

PE inspection confirmed x64 architecture, all 690 exports, and imports limited
to `VERSION.dll`, `SETUPAPI.dll`, `KERNEL32.dll`, and `USER32.dll`.
Builds retain existing C4244 conversion and C4456 shadowing warnings; the
`/W4` hook test also reports the existing conversion in `dllmain.cpp`.

The owner's later Steam success report is a basic in-game confirmation.
A fresh full ferry/focus/scripted-camera sequence, live GOG compatibility, and
all storefront-service behavior have not been established for this build.

## Build another package

With Visual Studio 2026 C++ Build Tools and the Windows SDK installed, run from
the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1
```

The script rebuilds Release x64, runs the tests, creates the ZIP and checksum
sidecar under `Release/packages/`, then tests the package. It does not publish
anything. If a ZIP with that version already exists, move it aside or choose a
new version with `-Version`. Use `-SkipPackage` to run build/code tests only.

The packager requires the expected x64 export table and no dynamic CRT imports.
It writes sorted ZIP entries with fixed timestamps and includes corresponding
source. Identical inputs produce identical ZIP bytes; that does not promise
identical MSVC binaries across different toolchain versions.

The verifier checks the required layout, checksums, unsafe paths, duplicates,
and forbidden game/backend/INI/build files. Preserve the matching source and
DLL when preparing a release.

## Recorded checksums

These identify the inspected files and the tested build. Recompute checksums
when downloading or rebuilding an artifact.

| File | SHA-256 |
| --- | --- |
| v1.0.0 ZIP | `8d326ac735088f8fd082702ce92e3a2af0dea2412646bf749b337a52f9c9cfdc` |
| Upstream 1.2 ZIP | `beddf5ec6aee541c10195aa41b8cc4a113515a8084644f53a84a51ea6282e351` |
| Game executable | `624fed07274bbd105d1d571ecb97a290df6f6f0aff76898c516890da6d136f76` |
| Published v1.0.0 mod DLL | `175513465aa99ebbcd1e8fd7461c0c43038423e7b1605b667d46fd7bbe2f14e5` |
| Preserved original Steam DLL | `81321a5cb72ae3f81243fd0b0d8928a063ca09129ab0878573bd36a28422ec4c` |
| Tested v1.0.1 ZIP, 415,712 bytes | `e5b9b1b23184a102027c7c606a9ee369c60c1adac3b990d3a0ea6fcfbe187a80` |
| Tested and installed v1.0.1 mod DLL | `acae03991807213efc4fdef9bc79307cbe2963bd5e1d5992684b31cfd252d8b8` |

The tested ZIP was renamed to `LegoCityUndercoverPlus.v1.0.1.zip` without
changing its contents. Later documentation edits are not part of that artifact.

## Before publishing another package

- Fix and retest the default installer package-directory lookup, or keep the
  explicit workaround in the installation command.
- Run the final build/test/package workflow and verify the ZIP and DLL hashes.
- Check camera controls, F8/F9, focus changes, loading, scripted views, and the
  Albatross ferry trip in both directions.
- Test the supported GOG dependency layout before claiming new live GOG coverage.
- Exercise diagnostics in writable and protected game folders, including the
  TEMP log fallback.
- Keep proprietary game DLLs out of the package and include the source and
  license notices.
- Publish only the approved assets and instructions. Keep existing release tags
  attached to the commits that were tested.
