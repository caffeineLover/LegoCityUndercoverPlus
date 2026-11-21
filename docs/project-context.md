# LEGO City Undercover Plus — Complete Codex Project Context

**Purpose:** Portable development handoff for Codex in Visual Studio Code, Visual Studio, or a terminal.  
**Suggested repository location:** `docs/project-context.md`  
**Prepared:** 2026-11-21  
**Project:** [caffeineLover/LegoCityUndercoverPlus](https://github.com/caffeineLover/LegoCityUndercoverPlus)

> **Instructions for Codex:** Read the repository's current `AGENTS.md`, `README.md`, source files, and tests before editing. This file supplies historical context, requirements, diagnostic evidence, and decisions from the owner's ChatGPT discussions. **The actual checked-out code, current tests, and current user request take precedence over this historical handoff whenever they disagree.** Check `git status`, branch, and HEAD before assuming a fact still applies. Do not infer that a proposed feature is implemented unless the code or tests confirm it.

## 1. Project identity and goals

- **Public name:** **Lego City Undercover Plus** (a mod for **LEGO City Undercover** on Windows PC).
- **GitHub repository:** `https://github.com/caffeineLover/LegoCityUndercoverPlus`
- **Original upstream project:** `https://github.com/twisted89/Lego-City-Undercover-Mouse-Support`
- **Relationship:** A maintained **fork** of twisted89's mouse-support mod, extending camera/input reliability, camera smoothness, usability and configuration.
- **License:** GPL-3.0; preserve copyright, attribution, existing license text, and obligations for redistributing binaries and source. Do not present the fork as an official game release or imply affiliation with the game's publisher.
- **Primary technical outcome:** Build a native Windows `steam_api64.dll` Steam API proxy that adds mouse camera control without breaking the original game's loading, camera scripting, or input.
- **Preferred engineering approach:** Small, evidence-based fixes, focused tests, clear documentation and build steps. The owner prefers **camelCase** rather than introducing **snake_case** for new code identifiers. Retain existing established INI keys such as `window_scale` where needed for compatibility with this mod's current format. Avoid needless cosmetic rewriting.

This is **a native C++ / Win32** game mod, **not** a Vintage Story mod or a C# plugin. The owner's other modding and gameplay discussions should not be imported into this development context.

## 2. Current GitHub and distribution status

### Repositories and remotes

On a fresh clone of this fork, the ordinary Git remote is:

```powershell
git clone https://github.com/caffeineLover/LegoCityUndercoverPlus.git
cd LegoCityUndercoverPlus
git remote add upstream https://github.com/twisted89/Lego-City-Undercover-Mouse-Support.git
git remote -v
```

- `origin`: owner's independently maintained fork; normal destination for pushes.
- `upstream`: twisted89's original repository; source of upstream changes. This is optional on new clones and should only be added if absent.
- Default branch in the fork: `main`.
- `LCUP_Caffeine`: original contribution branch that was submitted to upstream in pull request #6. Do not confuse with an accidentally created `LCU_Caffeine` branch, previously deleted.
- An older, separate repository named `caffeineLover/LegoCitiesUndercoverMousePlus` was archived and is **not** the maintained project.

### Accepted upstream contribution

- **Original pull request:** [twisted89/Lego-City-Undercover-Mouse-Support#6](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/pull/6), **“Mouse fixes and some QoL features”**.
- **Merged:** October 28, 2026; **12 commits**, **39 changed files**, **2,988 additions**, **444 deletions** as recorded by GitHub.
- **Upstream merge commit:** `2b7a223707f421910c0a79e5aeeb2dc87a1b431b`.
- **Reviewer:** twisted89 explicitly approved, writing, “Looks good, thanks for your contribution.”
- The merged PR included the submitted camera/input bug fixes, smoothing, toggles, windowed mode, configuration and refactoring, rather than a selection of individually cherry-picked patches.
- The owner **does not have write, maintain, or admin access** to twisted89's repository, as checked via repository permissions. A merged PR does not confer co-ownership. A direct collaborator-permission API query was restricted, so do not infer any other private GitHub permissions.
- As checked November 21, 2026, twisted89 had **not published a release incorporating PR #6**. His last listed official release was **1.2** dated March 23, 2026; earlier release **1.1** was dated September 16, 2024. Upstream having merged code is distinct from publishing a binary release.

### Independent fork release

- **Owner's release:** [Lego City Undercover Plus v1.0.0](https://github.com/caffeineLover/LegoCityUndercoverPlus/releases/tag/v1.0.0).
- **Published:** October 26, 2026.
- **Binary asset:** `LegoCityUndercoverPlus.v1.0.0.zip` (~88 KB).
- Release tag `v1.0.0` originally pointed to fork `main` commit `3e0dd0acbd839a24ba01d9c1fa87ff77d90aae31`.
- Recorded published ZIP SHA-256: `8d326ac735088f8fd082702ce92e3a2af0dea2412646bf749b337a52f9c9cfdc` (historical evidence; recompute on any newly downloaded file).
- Installer is **not** required: extract the mod's `steam_api64.dll` into the same folder as `LEGOLCUR_DX11.exe` within the installed game. The DLL generates a commented `lcu.ini` on first launch.
- The repository's public `README.md` is intentionally approachable and concise. Avoid rewriting user-facing announcements into overly technical jargon. A Steam Community discussion announcing the fork has been written/published separately; it is not a build artifact.

### Release and repository authority

The owner's fork is now maintained independently even though upstream accepted the PR. The owner can publish new releases without waiting for twisted89. For any future release, verify which commits it contains, build the DLL, test in-game, inspect the ZIP contents and calculate checksums. Never equate “code merged into upstream” with “upstream released binaries.”

## 3. Supported target and build environment

- **Target game:** Windows PC LEGO City Undercover, executable `LEGOLCUR_DX11.exe`.
- **Verified executable version:** `1.0.0.15609011`.
- **Architecture:** x64 Windows process, DLL and calling conventions.
- **Tooling:** Microsoft Visual Studio with C++ desktop tooling/Windows SDK/MSVC, Developer PowerShell, and Git. The project uses a Visual Studio `.sln` and `.vcxproj`, not CMake as the primary build.
- **Solution:** `LegoCitiesUndercoverPlus.sln`.
- **Project:** `lcu_mouse.vcxproj`.
- **Output:** `Release\steam_api64.dll` with intermediates under `Release\obj\`; test executables can be placed in that intermediates directory.
- **Toolset at prior verification:** `v145` in `.vcxproj`; check local VS installation if the required compiler toolset is not installed.
- **Build:**

```powershell
msbuild LegoCitiesUndercoverPlus.sln /t:Rebuild /p:Configuration=Release /p:Platform=x64
```

The owner has successfully used Visual Studio 2026 and the Developer PowerShell. A historical build showed a pre-existing `C4244` double-to-float warning in `src/camera/Vector3.cpp`; this was not a release-blocking error. Documentation also notes `C4456` / `C4018` warnings in Raw Input test compilation. Verify current diagnostics instead of assuming they remain.

**Local deployment from older workstation:** `D:\Program Files (x86)\Steam\steamapps\common\LEGO City Undercover`. This is an example, **not** a portable default for the owner's laptop. Ask for or discover the actual Steam install path if needed; do not bake this path into source.

**Safe deployment:** Close the game before replacing `steam_api64.dll`, back up the existing DLL if appropriate, copy the Release x64 artifact into the game's EXE directory and compare hashes:

```powershell
Get-FileHash .\Release\steam_api64.dll -Algorithm SHA256
Get-FileHash 'D:\Program Files (x86)\Steam\steamapps\common\LEGO City Undercover\steam_api64.dll' -Algorithm SHA256
```

Do not commit compiled binaries, game EXEs, saves, local INIs, or machine-specific Visual Studio `.vcxproj.user` files.

## 4. Repository layout

Key current paths established from the public repository:

```text
LegoCityUndercoverPlus/
├── AGENTS.md                         # Codex / contributor instructions
├── README.md                         # Public install and usage guide
├── LICENSE                           # GPL-3.0
├── LegoCitiesUndercoverPlus.sln
├── lcu_mouse.vcxproj
├── lcu_mouse.vcxproj.filters
├── docs/
│   ├── Agent_HANDOFF.md              # Older technical handoff (2026-10-21)
│   ├── mousework.md                  # Detailed, dated bug investigation
│   ├── mousework-human.md            # Human-focused narrative; parts historically stale
│   └── project-context.md            # Suggested location for THIS document
└── src/
    ├── game/
    │   └── dllmain.cpp              # Lifecycle, hooks, WndProc, camera integration
    ├── camera/
    │   ├── MouseCameraState.h/.cpp  # State transitions, stale-mode gate, math
    │   └── Vector3.h/.cpp
    ├── input/
    │   └── RawInput.h/.cpp          # Win32 raw mouse messages / registration
    ├── config/
    │   └── Settings.h/.cpp          # INI defaults, parsing, validation
    ├── steam_proxy/
    │   ├── Proxy.h
    │   ├── steam_api64.asm
    │   └── steam_api64.def           # Steam API export forwarding
    ├── tests/
    │   ├── MouseCameraStateTests.cpp
    │   ├── RawInputLifecycleTests.cpp
    │   └── SettingsTests.cpp
    └── third_party/
        ├── minhook/                 # Vendored MinHook
        └── mini/ini.h              # Vendored mINI
```

**Read order for a new coding session:** `AGENTS.md` → this file → `README.md` → `docs/mousework.md` (especially the latest dated sections) → `src/camera/MouseCameraState.*` → `src/game/dllmain.cpp` → `src/input/RawInput.*` → `src/config/Settings.*` → tests. Some historical docs refer to intermediate solutions that were later superseded.

The `.vcxproj.filters` is used to make the VS Solution Explorer presentation match the physical `src/` hierarchy. If files are moved or created, keep the project and filters synchronized.

## 5. Architecture and safety principles

### Steam API DLL proxy

The game loads `steam_api64.dll`. The mod builds a replacement/proxy DLL which forwards Steam API exports while attaching mod behavior. The export definition/assembly in `src/steam_proxy/` are critical: changing or omitting an exported function can prevent the game from starting or break Steam integration. Maintain the correct Windows x64 ABI and exact hook signatures. Do not rewrite the forwarding layer as cleanup without a tested reason.

### Camera integration

- Camera detours and Windows message routing are primarily connected in `src/game/dllmain.cpp`.
- State behavior is isolated where practical in `src/camera/MouseCameraState.*` for deterministic unit tests.
- Third-party detours use vendored MinHook.
- Win32 mouse capture is separated into `src/input/RawInput.*`.
- Configuration is parsed and validated in `src/config/Settings.*` with mINI.
- Reverse-engineered memory offsets are **specific to game executable version `1.0.0.15609011`**, and need new evidence before targeting another game version.

### Hard-coded offsets found during investigation

| RVA | Meaning / status |
| --- | --- |
| `0x991500` | Regular camera-update hook retained in the validated design. |
| `0x8ED0A0` | Former forced/scripted-camera detour; **removed deliberately** because it fought ferry cutscenes and caused spinning. Do **not** restore casually. |
| `0x18152A4` | Game-global reported first-person flag, historically called `isFirstPerson`; proved **stale/unreliable during ferry loading**. Never patch it merely to re-enable the mod. |

Any new hard-coded RVA must be justified by version-specific reverse-engineering evidence. Do not extrapolate to other builds.

## 6. Major bug investigation: ferry camera spinning, dead mouse input

### Original symptoms

The mouse camera worked on the mainland but broke when traveling by ferry to **Albatross Island**:

1. The camera spun continuously on/after arrival.
2. Removing the spinning revealed a second issue: mouse-camera control could stop working on Albatross and remain dead on returning to the mainland.
3. An additional lifetime problem could keep input disabled even when camera state looked healthy.

The investigation found **three independent bugs**, not a single mysterious ferry issue.

### Root cause A: conflict with scripted camera

The old mod detoured the game's forced-camera function (RVA `0x8ED0A0`) and wrote forced camera direction on every call. Ferry travel uses this same scripted camera path. The game and mod fought for control, producing the spin.

**Fix:** Remove that detour, leave scripted/forced-camera transitions to the game, and retain the ordinary update detour at `0x991500`.

### Root cause B: unreliable first-person state

The game-global reported `isFirstPerson` at `0x18152A4` became `1` during the ferry transition and could remain `1` when the actual camera was still an ordinary third-person orbit on Albatross. Previously the mod trusted this signal and rejected mouse movement permanently.

**Fix:** `CameraModeGate` combines the reported mode with geometric evidence of a valid third-person orbit. It retains prior third-person evidence as a loading gap approaches and permits a **local** stale-flag override only after a load-sized update gap and verified usable orbit geometry. It never writes or resets the game's flag. A collapsed/invalid or genuinely first-person camera revokes the override.

**Important sequencing detail:** The game may set the flag *before* the long loading pause. An early implementation discarded prior third-person evidence immediately, leaving nothing to support recovery. The final gate preserves evidence while camera geometry remains third person.

### Root cause C: dead Raw Input target HWND

The earlier implementation used a hidden message-only window created by whichever camera worker thread happened to run capture setup. That window belonged to a short-lived camera thread. When loading replaced the worker thread, Windows destroyed its window. The mod could report camera input enabled while `IsWindow` on its Raw Input target returned false.

An intermediate attempt recreated the message-only window on new camera threads, but that was not durable: the replacement worker could also terminate.

**Final fix:** Target the **persistent game HWND** instead:

1. The hooked game `WndProc` provides the game window via `RawInput::SetTargetWindow`.
2. It forwards `WM_INPUT` to `RawInput::HandleRawInput`.
3. It then forwards the message to the original game `WndProc` to preserve game handling.
4. Camera worker threads request enable/disable registration via `RawInput::Update(bool)` but do **not** own a hidden message window or pump a private Raw Input queue.
5. Target replacement or destruction is detected and registration is transferred/removed safely.

**Do not reintroduce camera-thread-owned message windows** as a purported fix. Some early paragraphs in `docs/mousework.md` describe that now-superseded solution; the dated 2026-10-20 investigation update records the durable HWND design.

## 7. State, transition and smooth-camera invariants

### Focus, F8 and loading transitions

- Track desired enabled/focused state and revision; compare revisions to avoid stale worker-thread decisions.
- On disabling, focus loss, or loading transitions, **suspend input**, **clear pending deltas**, **release synthesized button states**, and unregister Raw Input when appropriate.
- On re-enable or after transition, **call the original game camera update first**, then derive the new camera orbit/rotation/distance from the game's chosen camera and target positions.
- Resume capture only if the state revision, enabled/focus status, camera mode gate and geometry all remain valid.
- Holding a toggle key must cause **one toggle on initial key-down** only; ignore autorepeat.
- Avoid camera jumps when turning the mod back on: never apply queued old deltas or stale orbit values.

### Floating-point rotation

The original code cast mouse rotation angles from floating point to `int` solely to use `% 360`. It **discarded sub-degree motion** every update and introduced asymmetric behavior near 0 degrees.

**Fix:** `AdvanceRotation` preserves floating-point math and uses `std::fmod`, normalizing the result into `[0, 360)` without losing fractional movement. Keep regression tests covering small moves, negative wrap and wrapping above 360. Do **not** restore `static_cast<int>(angle) % 360` or any equivalent loss of precision.

Live manual testing with `sensitivity=0.160000` confirmed smooth low-speed camera movement.

### Historical validation evidence

`docs/mousework.md` records final in-game testing on October 20, 2026: mainland → ferry → Albatross, ferry return to mainland, continued mouse control, no camera spin, stable persistent HWND, F8 held/re-enabled and focus-loss cleanup. The low-speed smoothness fix was also tested in-game after the mathematical change. These findings are evidence for **that build**, not a guarantee for every subsequent commit or game version.

Historical DLL hashes recorded in development docs refer to intermediate installations. Do not confuse those hashes with the published v1.0.0 ZIP or a newly built DLL.

## 8. User-visible features and keyboard behavior

The project currently provides the following capabilities, as recorded in the README and code-oriented handoff:

- Mouse-controlled camera.
- Support for left/right/middle/side mouse buttons; left/right mouse button behavior maps by default to `Q` / `E` synthesized input (read current mapping code/config for exact details).
- Mouse scroll for camera zoom.
- Home and End sensitivity adjustment while playing.
- **F8:** mouse-camera on/off, configurable.
- **F9:** fullscreen/windowed mode toggle, configurable.
- Window size can be specified as a fraction of available display area, preserving aspect ratio, or as fixed client dimensions.
- First run auto-generates **self-documenting `lcu.ini`**.

### Current INI schema

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

Defaults:

- Sensitivity `0.003` and Home/End step `0.001`, minimum `0.001` for interactive adjustment.
- `window_scale=0.8` = 80% of the largest correctly aspect-ratio-preserving client size fitting the monitor work area (not naively 80% of arbitrary screen dimensions).
- `mode=fixed` uses `window_width` / `window_height` as **client-area** pixel dimensions; defaults `1280x720`.
- Invalid fixed dimensions and invalid/unknown mode fall back to default scale mode. Invalid scale and non-finite/zero/negative sensitivity use defaults. Check precise range and edge rules in current `Settings.cpp`/tests.
- Friendly hotkey names such as `F8`, `HOME`, `page up`, single character keys, decimal or hex Win32 virtual-key codes are supported. Mouse button virtual-key codes are **rejected** for the two toggles. An invalid key falls back to default.
- INI parsing is designed to be case-insensitive for recognized keys/sections and to preserve existing explanatory comments when sensitivity is written back.
- Earlier formats such as `[settings] togglekey` are **retired**; there was an explicit decision **not to implement backwards compatibility** for old INI formats. Do not add it without a new request.
- An older `docs/mousework-human.md` paragraph still shows `[settings] togglekey=0x77`. **That example is obsolete.** Follow `src/config/Settings.*`, `SettingsTests.cpp`, and the current README.

The DLL should create a helpful default INI if missing. Do not require users to ship/edit an INI just to get defaults; do not destroy explanatory comments when saving Home/End sensitivity.

## 9. Coding conventions and constraints

Current `AGENTS.md` is the authoritative house style, and records:

- Tabs for indentation and **Allman braces**.
- `PascalCase` for types and public methods; `camelCase` for locals/state.
- Avoid new snake_case identifiers; existing third-party, Windows API and established config names need not be renamed.
- Keep deterministic camera decisions in `MouseCameraState.*`; keep Win32 side effects in hook and input integration code.
- Document reverse-engineered offsets and why they are safe; **no speculative game memory writes**.
- Preserve Windows x64 hook function signatures, export forwarding and calling conventions.
- Do not commit generated output or third-party game files.
- Introduce focused regression tests when changing bug-prone behavior.
- Prefer focused, imperative git commits. Preserve `AGENTS.md` decisions unless the owner explicitly changes them.
- Avoid a sprawling redesign when a small fix addresses a verified repro.

Some legacy symbols in upstream code use lowercase or snake_case. The preference is about **new local code**, not an instruction for an indiscriminate rename of functioning APIs or vendor libraries.

## 10. Tests and standard verification

Run in **Visual Studio Developer PowerShell** from the repository root after making sure `Release\obj` exists. The commands documented in the current repository's `AGENTS.md` are:

```powershell
# Build DLL
msbuild LegoCitiesUndercoverPlus.sln /t:Rebuild /p:Configuration=Release /p:Platform=x64

# Camera state, stale first-person recovery, transitions, floating-point rotation
cl /nologo /std:c++17 /EHsc /W4 /WX src\tests\MouseCameraStateTests.cpp src\camera\MouseCameraState.cpp /Fe:Release\obj\MouseCameraStateTests.exe
.\Release\obj\MouseCameraStateTests.exe

# Raw Input lifecycle and replacement HWND behavior
cl /nologo /std:c++17 /EHsc /W4 src\tests\RawInputLifecycleTests.cpp src\input\RawInput.cpp Setupapi.lib User32.lib /Fe:Release\obj\RawInputLifecycleTests.exe
.\Release\obj\RawInputLifecycleTests.exe

# Config parsing, defaults, malformed input, INI comment preservation
cl /nologo /std:c++17 /EHsc /W4 /WX /Isrc\third_party\mini src\tests\SettingsTests.cpp src\config\Settings.cpp /Fe:Release\obj\SettingsTests.exe
.\Release\obj\SettingsTests.exe
```

If build output paths do not exist, create `Release\obj` first. If compiler support differs on the laptop, describe the exact failure rather than improvising a different toolchain unnoticed. The standalone tests are separate executables, not compiled into the game DLL.

### Camera regression cases

- Normal mainland camera movement and scrolling.
- F8 toggle, including key-repeat suppression, disable cleanup and successful resynchronization on re-enable.
- Alt-tab / focus loss and regain; stale deltas should not burst after resuming.
- Mainland → Albatross ferry and back, plus other loading/fast-travel boundaries as available.
- Scripted camera sequences, Criminal Scanner and genuine first-person-like views. Avoid incorrectly activating mouse-camera input in those views.
- Small mouse moves: fractional rotations, no quantization, symmetric wrap at 0°/360°.
- Game window replacement or target invalidation: no use of dead HWND.
- Fixed and scaled windowed mode with correct client size/aspect behavior and F9 toggle.
- Missing, commented, malformed or manually customized `lcu.ini`; first-run creation and persisted Home/End changes.

**Note:** Some of these are regression expectations and **should be manually rechecked after relevant changes**, not a claim that every one has been performed after every commit.

### Diagnosing a new mouse failure

Do not assume every ferry symptom is the same root cause. First distinguish:

1. Camera detour not running / unsupported game version.
2. Mod disabled, game unfocused, stale revision, or legitimate scripted-camera suppression.
3. Mode gate rejects a stale game first-person flag.
4. Orbit invalid; rebasing fails.
5. Camera accepts movement but Raw Input isn't reaching the persistent game HWND.
6. Rotation math or sensitivity causes apparent non-movement.

Useful observations include whether keyboard/controller camera movement works, whether F8 toggling changes symptoms, whether the game changes area or runs a scripted view, and whether WM_INPUT still arrives at the expected HWND. Prefer minimal logging and read-only state inspection before altering memory behavior.

## 11. Current issues, incomplete work and documentation debt

The owner's previous investigations recorded one intermittent symptom: on **the first arrival to Albatross Island in a game**, mouse input sometimes needed an **Alt-Tab out/back** to wake up; it did not reliably reproduce on later visits. The owner said he might not pursue it. This appeared in his upstream PR description **before/around release**. Treat it as an **observed possible residual edge case**, not a confirmed currently reproducible bug. Re-test before writing code.

Older `docs/Agent_HANDOFF.md` (dated 2026-10-21) listed tasks such as harmonizing `docs/mousework-human.md` and cleaning up minor warning diagnostics. That document is historical, and its specific statement of an old `main` commit (`47f9f3c`) is no longer the latest branch position. Check the actual tree/HEAD rather than trusting its branch status.

Known documentation discrepancy: `docs/mousework-human.md` had an old INI example under `[settings]` even though the current schema uses `[mouse]`/`[window]`. It also included early versions of the bug investigation; the later `docs/mousework.md` sections settle the persistent-HWND architecture. Correct stale docs only if requested or pertinent to work, and preserve historical investigation notes where they explain important decisions.

Do not invent a roadmap. No automatic upstream releases, co-maintainer role, new graphics engine, or support for other game executable versions has been authorized by the owner.

## 12. Git and collaboration workflow

After cloning on another Windows PC:

```powershell
git clone https://github.com/caffeineLover/LegoCityUndercoverPlus.git
cd LegoCityUndercoverPlus
git status
git branch -a
git remote -v
```

Optionally add original upstream **once**:

```powershell
git remote add upstream https://github.com/twisted89/Lego-City-Undercover-Mouse-Support.git
```

Update the fork's local default branch:

```powershell
git checkout main
git pull --ff-only origin main
```

Inspect upstream separately without merging automatically:

```powershell
git fetch upstream
git log --oneline --decorate --graph --all -20
```

**Historical merge step:** The owner previously moved his fork's `main` forward from his completed PR branch using:

```powershell
git checkout main
git merge --ff-only LCUP_Caffeine
git push -u origin main
```

This was a one-time history operation, **not** an instruction to run it on each clone. Be deliberate about what branch is currently checked out and where new contributions will go. There is no need to force-push or rewrite history to keep the fork up to date.

If Visual Studio asks whether to reload files or projects after a Git branch switch or Codex edit, use the IDE reload operation as appropriate; do not accidentally overwrite edits made outside the IDE.

### Upstream communication

GitHub PR #6 already carries an approved and merged contribution. To discuss future collaboration or publication, the owner can comment on that PR with `@twisted89` or open a relevant issue. Neither action implies the project owner has added the user as a maintainer. The maintained fork may be promoted independently in Steam Community Discussions, Nexus Mods, ModDB or PCGamingWiki if appropriate. Keep credit to the original developer.

## 13. Useful primary sources

- [Maintained fork](https://github.com/caffeineLover/LegoCityUndercoverPlus)
- [Fork README](https://github.com/caffeineLover/LegoCityUndercoverPlus/blob/main/README.md)
- [Fork AGENTS.md](https://github.com/caffeineLover/LegoCityUndercoverPlus/blob/main/AGENTS.md)
- [Detailed ferry/camera investigation](https://github.com/caffeineLover/LegoCityUndercoverPlus/blob/main/docs/mousework.md)
- [Older agent handoff](https://github.com/caffeineLover/LegoCityUndercoverPlus/blob/main/docs/Agent_HANDOFF.md)
- [Human investigation guide](https://github.com/caffeineLover/LegoCityUndercoverPlus/blob/main/docs/mousework-human.md)
- [Owner's released v1.0.0 binary](https://github.com/caffeineLover/LegoCityUndercoverPlus/releases/tag/v1.0.0)
- [Accepted upstream PR #6](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/pull/6)
- [Upstream releases](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support/releases)

## 14. What Codex should do when beginning new work

1. **Inspect** `git status`, current branch/commit, `AGENTS.md`, relevant implementation and unit tests.
2. **Restate the user's requested change** and distinguish verified existing functionality from inferred behavior.
3. **Protect invariants**: scripted cameras are game-controlled; reported first-person flag is unreliable; Raw Input targets persistent game HWND; transitions clear/rebase; rotation remains floating point.
4. **Make the smallest coherent change** in the right subsystem, keeping the coding style and existing names.
5. **Add or update focused tests** and run the relevant compilation/tests plus x64 Release build; disclose unrun tests or missing game access.
6. **Provide a concise report** of files changed, motivation, build/test evidence, manual game-testing needed, and any new game-offset risk.
7. **Ask before pushing, publishing releases, editing unrelated files or substantially rewriting public documentation.**

**Scope:** This file documents development of the **Lego City Undercover Plus mouse/camera mod**. The lengthy, separate conversations about playing LEGO City Undercover—finding collectibles, progressing museum/castle/pagoda missions, keyboard controls for gameplay, etc.—are **not implementation requirements** and have intentionally not been folded into the coding handoff.
