# Lego City Undercover Plus


## Features

- Control the camera using your mouse
- Right, Left, Middle, and Side mouse buttons all function
- Mouse sensitivity can be adjusted.
- Toggle mouse support on/off
- Toggle fullscreen / windowed mode.

## Installation

- Download latest release
- Extract contents into LEGO City Undercover installation folder (where LEGOLCUR_DX11.exe is located)
- Play!

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
