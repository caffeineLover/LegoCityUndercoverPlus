# Camera and Raw Input investigation

The ferry to Albatross Island exposed three separate failures: a spinning
camera, a stale camera-mode flag, and lost Raw Input. This record covers the
October 2026 investigation and the builds tested then. For a shorter explanation,
read the [camera guide](mousework-human.md).

All addresses below are relative to executable version **1.0.0.15609011**.

## Findings

### Scripted-camera conflict

The mod hooked the forced-camera routine at `0x8ED0A0` and wrote camera
direction fields on each call. Ferry arrival repeatedly uses that routine, so
the mod fought the game's scripted camera and caused continuous spinning.

Removing that detour stopped the spin. The regular camera-update hook at
`0x991500` was retained.

### Stale first-person report

The game-global value at `0x18152A4`, called `isFirstPerson` in the mod,
changed to `1` during ferry travel and could remain `1` during ordinary
third-person play on Albatross.

At the failure point, live inspection showed:

- The camera hook was running.
- The mod was enabled and the game was focused.
- `isFirstPerson` was `1`.
- Camera resynchronization was pending and input acceptance was off.

The ferry changed the flag before the long camera-update gap. An early recovery
attempt discarded its previous third-person evidence as soon as the flag
changed, so it could not recognize the later loading transition.

Temporarily arming the mod's recovery gate made the override active,
resynchronization completed, and input resumed. This changed the mod's state;
it did not patch the game's flag.

The resulting `CameraModeGate` keeps prior third-person evidence while the
orbit remains usable. After a loading gap, it calls the original game update
and checks the resulting orbit before allowing a local stale-flag override.
Invalid or collapsed geometry cancels the override. A startup gap alone cannot
enable it.

### Dead Raw Input target

After the camera-gate fix, a later inspection found a different failure. The
camera detour ran about every 15 ms, recovery had completed, and input acceptance
was on. Raw Input nevertheless reported a registered window handle for which
`IsWindow` returned false.

The hidden Raw Input window belonged to whichever camera worker had created
it. Loading could replace that worker, causing Windows to destroy the window.
An interim fix checked the window's identity, process, and thread, then recreated
it on the current camera worker. That failed again when the replacement worker
also exited.

The persistent-window design described below superseded that approach on
October 20, 2026. The earlier implementation notes reflected commit `5168d81`;
they are not instructions for the current code.

## Final input and recovery design

Raw Input uses the game's persistent window. The hooked `WndProc` supplies its
handle through `SetTargetWindow`, passes `WM_INPUT` to `HandleRawInput`, and
then calls the game's original window procedure. Raw Input does not create a
hidden window or pump a camera-worker message queue.

Camera workers call `Update(bool)` to request registration changes. Changing
targets removes the old registration before using the new one. Destroyed
targets are detected before capture resumes.

After a loading gap or re-enable, camera recovery follows this order:

1. Suspend input and clear accumulated movement.
2. Call the original camera update.
3. Rebuild rotation and distance from the resulting camera and target positions.
4. Resume capture only if focus, enabled state, state revision, camera mode, and
   positions are still valid.

Disabling also unregisters capture and releases synthesized button presses.
Initial key-down toggles once; autorepeat does not toggle again.

These safeguards remain part of the design:

- Never write the game's first-person flag to force recovery.
- Require prior third-person evidence, an update gap, and a usable post-update
  orbit before overriding a stale report.
- Reject invalid geometry and genuine first-person views.
- Check state revisions before applying a camera-thread decision.

The gate still relies on orbit geometry. A special or scripted camera with a
non-zero horizontal orbit across a loading gap could resemble stale third-person
state. This remains a narrow risk; test Criminal Scanner and other scripted or
first-person views when changing the gate.

## October 20, 2026 verification

The Release x64 build, `MouseCameraStateTests`, and `RawInputLifecycleTests`
passed after the persistent-window change. The recorded build warning was the
existing double-to-float conversion in `Vector3.cpp`.

Camera-state tests covered F8 edges, state revisions, stale input, update gaps,
ferry ordering, orbit rebasing, stale-mode recovery, and genuine first-person
rejection. Raw Input tests used real Win32 registration to check that:

1. A persistent target remained valid after the transient camera worker exited.
2. Destroying and replacing the target removed stale registration and used the
   replacement window.

Live testing of the persistent-window build confirmed mouse control on
Albatross and after the return ferry, with no renewed spin. Inspection showed
current camera updates, completed resynchronization, input acceptance on, and
Raw Input registered to the same game window.

Holding F8 produced one disable transition, recorded at revision 10. Input was
cleared and capture unregistered. A second key-down enabled control at revision
11, rebuilt the orbit, and registered capture again. Focus loss independently
cleared input and unregistered capture.

The earlier notes that called this ferry validation pending were written before
that live test. Scripted and genuine first-person views should still be
rechecked when changing the camera gate.

## Floating-point rotation follow-up

The old rotation calculation converted a floating-point angle to `int` to
apply `% 360`. Each update discarded the fraction. This lost small movements
and made behavior near zero asymmetric because integer conversion truncates
toward zero.

`AdvanceRotation` now uses floating-point math and `std::fmod` to normalize
angles into `[0, 360)`. The camera detour uses that helper. Regression cases
for quarter-degree movement and wrapping below zero and above 360 failed before
the change and passed afterward. The Release build and Raw Input tests passed.

The owner then tested the smoothing build at `sensitivity=0.160000` and
confirmed smooth slow movement. An earlier INI read of `3.280027` was a
historical setting, not a recommended default. The default sensitivity is
`0.003`; Home/End adjust it by `0.001`.

## Historical DLL hashes

These identify intermediate camera builds, not the v1.0.0 release ZIP or the
later v1.0.1 startup/release build.

| Build | SHA-256 |
| --- | --- |
| Failing DLL inspected before the persistent-window fix | `55CDF534322E939F0EEA09D8E03E40550BD071540D1063F57159300E582E565D` |
| Persistent-window build; built and installed copies matched | `6A5CF165507058564C629C15DFD5EDE533712056474C8655204496A889FBEAE5` |
| Floating-point smoothing build; built and installed copies matched | `C91F779BC2B9C803BCDD38AB377FE4980D4D40F2EA0269D9FAC11AA578C67041` |

The game was stopped during replacement, and `steam_api64.pre-codex.dll` was
retained as an untouched backup during that investigation.

## Retesting camera changes

Check mainland movement and scrolling, F8 disable/re-enable and held-key
behavior, focus loss/regain, loading and fast travel, ferry travel in both
directions, Criminal Scanner, and other scripted or genuine first-person views.
Use small mouse movements to catch a return of integer rounding.

If input fails, record whether keyboard/controller camera movement still works,
whether F8 changes the symptom, and whether `WM_INPUT` reaches the persistent
game window. Those observations help distinguish camera-mode rejection from
lost mouse delivery.

The later [startup investigation](release-startup-analysis.md) records the
v1.0.1 automated checks and the owner's subsequent Steam installation report.
