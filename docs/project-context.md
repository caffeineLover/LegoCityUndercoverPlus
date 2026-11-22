# Development overview

LEGO City Undercover Plus is a C++/Win32 mouse-camera mod for the Windows PC
game. It is a maintained fork of
[twisted89's mouse-support mod](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support),
distributed under [GPL-3.0](../LICENSE).

Only executable version **1.0.0.15609011**, running as an x64 process, is
supported. The project uses a Visual Studio solution and MSVC; CMake is not part
of the current build.

This overview describes the project as of November 21, 2026. Use the checked-out
source and tests to resolve differences with older investigation notes.

## Documentation

| Document | What it covers |
| --- | --- |
| [README](../README.md) | Controls, features, and a quick introduction |
| [Installation guide](INSTALL.md) | Install, upgrade, rollback, and startup errors |
| [Developer handoff](Agent_HANDOFF.md) | Current work status and behaviors to preserve |
| [Camera guide](mousework-human.md) | Plain-language explanation of the ferry and input fixes |
| [Camera investigation](mousework.md) | Technical evidence, historical hashes, and live test results |
| [Startup investigation](release-startup-analysis.md) | v1.0.0 packaging failure, v1.0.1 changes, and verification |
| [Third-party notices](THIRD-PARTY-NOTICES.txt) | Dependency licenses and attribution |
| [Proxy directory note](proxy-README.txt) | Where the game's original DLL belongs |

[AGENTS.md](../AGENTS.md) records coding conventions and repository rules.
Keep new work focused on a reproduced problem; preserve the working camera
behavior while changing startup or packaging.

## How the mod fits into the game

The game loads a DLL named `steam_api64.dll`. The mod occupies that filename,
loads the game's original API DLL from `proxy/`, and forwards calls to it.
Steam needs the complete 690-export table; the inspected GOG compatibility DLL
provides 11 required exports and depends on `Galaxy64.dll`.

The mod also hooks the game's regular camera update and window procedure.
MinHook installs those detours. Camera state and math live separately from
Windows input and hook code so they can be tested without the game.

| Area | Files |
| --- | --- |
| Startup, hooks, camera integration, and INI persistence | [dllmain.cpp](../src/game/dllmain.cpp) |
| Toggle/focus state, mode gate, orbit rebasing, and rotation | [MouseCameraState.cpp](../src/camera/MouseCameraState.cpp) |
| Raw mouse registration and messages | [RawInput.cpp](../src/input/RawInput.cpp) |
| INI defaults, parsing, and validation | [Settings.cpp](../src/config/Settings.cpp) |
| Backend loading and export forwarding | [steam_proxy/](../src/steam_proxy/) |
| Standalone regression tests | [tests/](../src/tests/) |
| Build, test, install, and packaging scripts | [scripts/](../scripts/) |
| Vendored MinHook and mINI | [third_party/](../src/third_party/) |

The project file is `lcu_mouse.vcxproj`; its filters file controls the folder
layout shown in Visual Studio. Keep both in sync when adding or moving files.

## Camera rules

Ferry travel exposed three failures: the mod fought a scripted camera, trusted
a stale first-person flag, and registered Raw Input to a window owned by a
short-lived camera worker. The fixes are explained in the camera documents.

| RVA | Use |
| --- | --- |
| `0x991500` | Regular camera-update hook retained by the mod |
| `0x8ED0A0` | Removed forced-camera hook that caused ferry spinning |
| `0x18152A4` | Reported first-person flag; can remain stale after loading |

These addresses are specific to the supported executable. Any new address or
build support needs its own reverse-engineering evidence.

Keep Raw Input registered to the persistent game window. On disable, focus
loss, or a loading transition, clear old mouse input and release synthesized
buttons. Let the game place its new camera before rebuilding the mod's orbit.
Resume input only if focus, enabled state, state revision, camera mode, and
geometry still allow it.

A stale first-person report may be overridden locally only after prior
third-person evidence, a loading gap, and a usable post-update orbit. The game
flag is never patched. Rotation stays in floating point and uses `std::fmod`
so small mouse movements are preserved.

## Controls and configuration

F8 toggles mouse-camera control; F9 toggles fullscreen/windowed mode.
The wheel changes camera distance. Home/End adjust sensitivity by `0.001`,
with an interactive minimum of `0.001`. Left/right click map to Q/E by default.

A supported first launch creates a commented `lcu.ini`. The main settings are:

```ini
[mouse]
toggle=F8
sensitivity=0.003

[window]
toggle=F9
mode=scale
window_scale=0.8
window_width=1280
window_height=720
```

`scale` uses a fraction of the largest correctly proportioned client area
that fits the monitor work area. `fixed` uses client-area pixel dimensions.
Invalid settings fall back to defaults; see
[Settings.cpp](../src/config/Settings.cpp) for the exact validation rules.

Toggle keys accept friendly names, a single character, or a decimal/hex Windows
virtual-key code. Mouse-button codes are rejected for the toggles. Holding a
toggle key does not repeat it. Configuration names are case-insensitive, and
saving sensitivity preserves comments.

The retired `[settings] togglekey` and sensitivity entries are ignored.
The separate legacy click bindings remain supported.

## Build and test

Install Visual Studio 2026 C++ Build Tools with toolset v145 and the Windows SDK.
From the repository root, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1
```

This builds Release x64, runs the state/settings/input and startup/proxy tests,
then creates and tests a release ZIP. The DLL is `Release/steam_api64.dll`;
the ZIP is under `Release/packages/`. Generated files stay out of Git.

The packager refuses to overwrite an existing ZIP. For code checks without a
new package, use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1 -SkipPackage
```

Use `-Version` with a new version when creating another package. For a
DLL-only rebuild from Developer PowerShell:

```powershell
msbuild LegoCitiesUndercoverPlus.sln /t:Rebuild /p:Configuration=Release /p:Platform=x64
```

The [startup investigation](release-startup-analysis.md) lists the tested failure
cases and known compiler warnings. The camera/settings tests use `/W4 /WX`.
Standalone tests are separate executables, not part of the mod DLL.

After deleting generated test folders, run the full workflow to recreate them.
A standalone `Test-Package.ps1` run expects proxy fixtures from
`Test-Proxy.ps1`.

## Installation and testing limits

Use the packaged installer and the original API DLL from the user's own game.
[INSTALL.md](INSTALL.md) covers the package-directory workaround and backup
layout. Discover the actual install location rather than assuming a drive letter.

The October 20 camera builds passed ferry and input checks in game. The
November 21 startup/release build passed automated tests, was installed on Steam,
and the owner reported that it worked. These are separate test records.
A basic success report does not establish a fresh run of every ferry, focus,
scripted-camera, window-mode, or storefront-service check. Live GOG testing
has not been established.

An earlier report described needing Alt-Tab out and back on the first Albatross
arrival. It was intermittent and not reliably reproduced later. Reproduce it
on the current build before treating it as an active bug.

For a new input failure, first check whether the camera hook runs, the mod is
enabled, the game is focused, the camera orbit is valid, and Raw Input reaches
the game window. Note whether keyboard/controller movement and F8 change the
symptom before changing game-memory behavior.

## Repository and upstream history

The maintained fork is
[caffeineLover/LegoCityUndercoverPlus](https://github.com/caffeineLover/LegoCityUndercoverPlus).
The older `LegoCitiesUndercoverMousePlus` repository is archived.

The camera, input, configuration, and window-mode work was accepted upstream in
[PR #6](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/pull/6),
merged October 28, 2026 as `2b7a223707f421910c0a79e5aeeb2dc87a1b431b`.
That submission contained 12 commits and changed 39 files. The recorded
2,988 additions and 444 deletions describe that PR, not the later startup fix.
Upstream acceptance does not grant write access to the upstream repository
or mean that a new binary has been released.

The fork's `v1.0.0` release was published October 26, 2026 at `3e0dd0a`.
Its incomplete installation package is documented in the startup investigation.
The `v1.0.1` tag identifies the tested startup fix at `1f2df62`.
The old contribution branch `LCUP_Caffeine` was deleted after confirming that
its commits were all in `main`.

To update a clone:

```powershell
git status
git switch main
git pull --ff-only origin main
```

If you want to inspect upstream separately, add it once as an `upstream`
remote, then fetch it. Review incoming changes before merging. Keep release
tags on the commits that were tested.

## Making changes

Follow the existing tabs, Allman braces, and naming conventions in
[AGENTS.md](../AGENTS.md). Keep deterministic camera decisions in the camera
state module and Windows side effects in the input/hook layer. Preserve Win64
signatures and all advertised exports.

Add focused regression coverage for behavior changes. Camera changes also need
manual checks for movement/zoom, F8/F9, focus changes, loading, ferry travel,
scripted views, and slow rotation. Keep game files, saves, local INIs, and
personal Visual Studio settings out of commits.
