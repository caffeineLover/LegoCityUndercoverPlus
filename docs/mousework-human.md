# Why the mouse camera broke after the ferry

Ferry travel to Albatross Island exposed three bugs in the original mouse mod.
The camera first spun continuously. Removing the spin revealed another problem:
mouse control could stop working on Albatross and remain dead after returning
to the mainland.

This guide explains the fixes. [The investigation record](mousework.md) contains
the dated observations, test results, and DLL hashes.

## The mod fought the scripted camera

The old mod changed camera fields whenever the game called its forced-camera
routine at address offset `0x8ED0A0`. The ferry uses that routine for its
scripted views. The game and mod kept moving the same camera, causing the spin.

Removing that hook stopped the conflict. The mod now uses the regular camera
update at `0x991500` and lets the game control scripted scenes.

These addresses are relative to the game executable and apply only to version
**1.0.0.15609011**.

## The first-person flag could get stuck

The game exposes a value at `0x18152A4`, called `isFirstPerson` in the mod.
During ferry loading it changes to `1` and can stay there even when the player
is clearly back in third-person view. Trusting it alone left mouse control
permanently disabled.

The mod now checks the camera's position as well. It remembers that a usable
third-person view was present before loading. After a long update gap, it lets
the game place the camera, then checks whether the new view still forms a valid
third-person orbit.

Only that combination permits recovery from a stale flag. A collapsed or
invalid orbit cancels recovery. The mod never changes the game's flag.

Timing mattered here: the ferry sets the flag before loading pauses camera
updates. The first recovery attempt forgot the previous third-person view as
soon as the flag changed. By the time loading began, it had lost the evidence
needed to recover. `CameraModeGate` now keeps that evidence while the camera
positions still describe third-person play.

## Windows was sending mouse input to a dead window

Raw Input delivers mouse messages to a registered Windows window. The old mod
created a hidden window on a camera worker thread. When loading replaced that
thread, Windows destroyed its window.

This explained a confusing failure: the camera hook was running and the mod
said it accepted input, but its Raw Input window handle was no longer valid.
Recreating the window on another camera worker failed for the same reason.

The fix uses the game's persistent window:

1. The hooked `WndProc` supplies the game window to Raw Input.
2. Windows sends `WM_INPUT` messages to that window.
3. The hook passes them to `RawInput::HandleRawInput`, then calls the game's
   original window procedure.

Camera workers now only request whether capture should be on or off. Replacing
a worker no longer destroys the mouse-input destination.

## Recovering without a camera jump

On disable, focus loss, or a loading transition, the mod clears accumulated
mouse movement and releases any synthesized button presses. When control can
resume, it lets the game update its camera first, then rebuilds the mod's
rotation and distance from the game's chosen view.

It resumes capture only if the game is still focused, the mod is still enabled,
and the camera is valid. A state revision check prevents an older camera update
from undoing a newer toggle or focus change.

The default mouse toggle is F8:

```ini
[mouse]
toggle=F8
sensitivity=0.003
```

Holding F8 toggles once. Turning it off unregisters capture; turning it back on
uses the same recovery sequence. The retired `[settings] togglekey` setting is
not used. F9 controls fullscreen/windowed mode; see the
[README](../README.md) for settings.

## Small mouse movements were being lost

A separate rotation bug converted each angle to an integer so it could wrap
with `% 360`. That threw away movements smaller than one degree and made
wrapping around zero behave unevenly.

`AdvanceRotation` keeps the angle in floating point and wraps it with
`std::fmod`. Tests cover fractional movements and wrapping in both directions.
Live testing at `sensitivity=0.160000` confirmed smooth slow movement. That was
a test setting; the default remains `0.003`.

## What was tested

The October 20, 2026 camera builds were tested in game for ferry travel in both
directions, continued mouse control, F8 disable/re-enable and held-key handling,
and focus loss. Inspection showed Raw Input staying attached to the persistent
game window. Slow rotation was tested after the floating-point fix.

The November 21 startup/release build was later installed on Steam and the owner
reported that it worked. That confirmation did not list every camera test above,
so it should not be treated as a new run of the full ferry test sequence.

## Where the code lives

| File | Responsibility |
| --- | --- |
| [MouseCameraState.h](../src/camera/MouseCameraState.h) and [MouseCameraState.cpp](../src/camera/MouseCameraState.cpp) | Camera-mode checks, state revisions, orbit rebasing, and rotation math |
| [dllmain.cpp](../src/game/dllmain.cpp) | Game hooks, window messages, and applying camera movement |
| [RawInput.cpp](../src/input/RawInput.cpp) | Mouse registration and input delivery |
| [tests/](../src/tests/) | Regression cases for these behaviors |

When changing this code, preserve the sequence: clear old input, let the game
set its camera, rebuild the orbit, then resume capture. Keep Raw Input attached
to the game window and keep rotation in floating point.
