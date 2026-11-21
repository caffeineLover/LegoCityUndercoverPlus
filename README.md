# Lego City Undercover Plus


## Features

- Control the camera using your mouse
- Right, Left, Middle, and Side mouse buttons all function
- Mouse sensitivity can be adjusted.
- Toggle mouse support on/off
- Toggle fullscreen / windowed mode.

## Installation

- Close the game. Only Windows x64 executable **1.0.0.15609011** is supported.
- Download and extract the complete release ZIP to a separate folder.
- Preserve your game's **original** `steam_api64.dll` before installing the mod.
  The package does not include proprietary Steam/GOG DLLs.
- Run the package's `Install.ps1` with your game directory and `-Edition Steam`
  (or `GOG`). It preserves and verifies the original backend before replacement.
- Follow the [installation, upgrade, rollback, and troubleshooting guide](docs/INSTALL.md).
  Do not simply overwrite the original DLL. If v1.0.0 already replaced it,
  recover it from a backup or your storefront's Verify/Repair first.

## Build and package

With Visual Studio 2026 C++ tools (v145) and the Windows SDK installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1
```

This builds Release x64, runs the existing and startup/proxy regression tests,
then creates and checks a local ZIP under `Release/packages/`. It never publishes
a release or includes proprietary backend binaries. See the
[startup investigation and v1.0.1 checklist](docs/release-startup-analysis.md).

## Usage

- Mouse scroll adjusts camera distance (camera zoom)
- Adjust mouse sensitivity: in-game with Home/End buttons (increase/decrease sensitivity by `0.001`) or in the config file `lcu.ini`
- Toggle mouse support with F8.  Rebind with `lcu.ini` with a friendly name (e.g. `HOME`), single characters (e.g. `m`), or numeric/hexadecimal virtual-key codes.
- Toggle fullscreen / windowed mode with F9.  Rebind with `[window] toggle`.  The default `mode=scale` uses `window_scale=0.80` of the largest window with the correct aspect ratio that fits the monitor.  Set `mode=fixed` to choose `window_width` and `window_height` client dimensions instead (default `1280x720`).
- Mouse-camera sensitivity is stored as `[mouse] sensitivity` and is adjusted in game with Home/End. Missing or invalid values use `0.003`.
- By default Left and right click are bound to Q + E.  Edit the ini file to change these or adjust your in game mappings accordingly.  Use virtual keycodes in ini https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

## Recent Changes

- Added configurable, keyboard-only F8/F9 toggle bindings, with validation and defaults for invalid settings.
- Added scale-based and fixed-client-size windowed modes while preserving the game's aspect ratio in scale mode.
- `lcu.ini` is created with explanatory comments; updates retain comments while saving Home/End sensitivity changes.
