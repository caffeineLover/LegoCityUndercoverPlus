# Developer handoff

Updated November 21, 2026. This is a starting point for work on the mod.
Build and coding instructions are in [AGENTS.md](../AGENTS.md).

## Where things stand

The `v1.0.1` tag points to commit `1f2df62`, which fixes startup loading,
hook rollback, and release installation. The Release x64 build and automated
tests passed. The owner installed that build on Steam and reported that it
works. That report does not establish that every camera or ferry regression
check was repeated.

One installer issue remains: an invocation with `powershell.exe -File` failed
when the package directory was omitted. Supplying `-PackageDirectory` explicitly
worked. The commands in [INSTALL.md](INSTALL.md) include that workaround.

## Read what you need

| Task | Start here |
| --- | --- |
| Install, upgrade, or remove the mod | [Installation guide](INSTALL.md) |
| Understand the ferry and mouse fixes | [Camera guide](mousework-human.md) |
| Check camera investigation evidence and historical DLL hashes | [Camera investigation](mousework.md) |
| Understand the v1.0.0 startup failure and v1.0.1 tests | [Startup investigation](release-startup-analysis.md) |
| Find controls and configuration defaults | [README](../README.md) |

## Keep these behaviors intact

Only executable version **1.0.0.15609011** is supported. The hooks use
version-specific addresses and Windows x64 calling conventions.

- Leave scripted cameras under the game's control. The removed hook at
  `0x8ED0A0` caused ferry-arrival spinning; the regular camera hook is
  `0x991500`.
- Treat the reported first-person flag at `0x18152A4` as fallible. Recover from
  a stale flag only after prior third-person evidence, a loading gap, and a
  usable camera orbit. Never patch the game's flag.
- Register Raw Input to the persistent game window supplied by `WndProc`.
  A camera worker can exit during loading, taking any window it owns with it.
- Clear pending input and release synthesized buttons on disable or focus
  loss. After a transition, let the game update its camera before rebuilding
  the mod's rotation and distance.
- Check the enabled/focused state revision before resuming input, so an old
  camera update cannot undo a newer toggle.
- Keep rotation in floating point. `AdvanceRotation` uses `std::fmod` to
  preserve movements smaller than one degree.
- Remove owned hooks before allowing a failed startup to unload the DLL.
  If MinHook cleanup fails, terminate even if writing the diagnostic fails.

## Code map

| Area | Files |
| --- | --- |
| DLL lifecycle, game hooks, and configuration persistence | [dllmain.cpp](../src/game/dllmain.cpp) |
| Camera state, mode checks, and orbit math | [MouseCameraState.cpp](../src/camera/MouseCameraState.cpp) |
| Windows mouse registration and messages | [RawInput.cpp](../src/input/RawInput.cpp) |
| Settings defaults and validation | [Settings.cpp](../src/config/Settings.cpp) |
| Original DLL loading and Steam API forwarding | [steam_proxy/](../src/steam_proxy/) |
| Regression tests and build tools | [tests/](../src/tests/) and [scripts/](../scripts/) |

Use the full build/test workflow after code changes. Camera changes also need
in-game checks for F8, focus changes, loading, scripted cameras, and ferry travel
in both directions. The dated investigation records describe tests on particular
builds; they do not replace testing a new DLL.

The older handoff named commits `43106dd` and `47f9f3c`. They are historical
camera-fix milestones, not the current branch position.
