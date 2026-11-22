# Install LEGO City Undercover Plus

This is an unofficial mouse-camera mod based on
[twisted89's mouse-support mod](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support).
It supports the Windows x64 game executable **1.0.0.15609011**.

## Before you start

1. Close the game.
2. Extract the **entire release ZIP** to a separate folder, outside the game
   folder. Keep its files and subfolders together.
3. Make sure you have the original `steam_api64.dll` from your own Steam or
   GOG installation. The mod needs this file to keep the game's Steam/GOG
   functions working.

The ZIP includes `Install.ps1`, `Get-PeInfo.ps1`, the mod DLL, this guide,
license notices, checksums, and source code. It does not include proprietary
Steam/GOG DLLs.

**Already installed v1.0.0?** Check for an original DLL in `proxy/` or your
backups. If you have none, remove the mod DLL and use Steam's Verify integrity
or GOG's Verify/Repair to restore the original. Keep `lcu.ini` to retain your
settings. Storefront repair can leave mod-added files behind, so a renamed DLL
is not automatically a trustworthy original.

## Run the installer

Open Windows PowerShell in the extracted package folder. Replace
`C:\your\game` below with the folder containing `LEGOLCUR_DX11.exe`.

For Steam:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GameDirectory 'C:\your\game' -Edition Steam -PackageDirectory .
```

For GOG:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GameDirectory 'C:\your\game' -Edition GOG -PackageDirectory .
```

Keep `-PackageDirectory .` in the command. It explicitly selects the folder
you opened PowerShell in and avoids the default package-path lookup failure
seen with this release. Use an administrator PowerShell only if your game
folder requires administrator access.

GOG's original `gog.ico`, `Galaxy64.dll`, and other dependencies must remain
installed beside the game executable.

The installer checks the game version, edition marker, package checksums, and
DLL architecture/exports before changing files. It then:

- Preserves the original DLL under the correct `proxy/` filename.
- Saves the previous root DLL under `lcup-backups/<SHA256>/`, where the folder
  name is that file's checksum.
- Copies in the mod and verifies its checksum.

Existing original DLLs and backups are not overwritten with different files.
Your configuration is left alone. These checks catch common mistakes, but they
cannot prove a DLL's origin; start with your own storefront copy.

Launch the game through Steam or GOG after installation.

## Installed files

A Steam installation will have this layout:

```text
LEGO City Undercover/
  LEGOLCUR_DX11.exe
  steam_api64.dll                 # the mod
  proxy/
    steam_api64_steam.dll         # your original Steam DLL
  lcu.ini                        # generated on first supported launch
  lcup-backups/
    <SHA256>/
      steam_api64.dll             # the previous root DLL
```

GOG uses `proxy/steam_api64_gog.dll` instead, and keeps its original `gog.ico`
and `Galaxy64.dll` beside the executable. Only your edition's original API
DLL is needed.

The mod finds the original DLL relative to its installed location.
Configuration still uses the game's working directory; launching normally
through the storefront keeps the existing settings behavior.

## Upgrade

Close the game and back up your configuration. Extract the new package to a
separate folder and run its installer with the same game path and edition.
Keep the original DLL in `proxy/`; the previous mod DLL is not a replacement
for it. The installer preserves a verified copy of the previous root DLL.

## Remove the mod

From the extracted package folder, run the same command with `-Rollback`.
For Steam:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GameDirectory 'C:\your\game' -Edition Steam -PackageDirectory . -Rollback
```

Use `-Edition GOG` for GOG. Rollback checks the package, backs up the current
mod DLL, and restores your original DLL to `steam_api64.dll`. It leaves the
original in `proxy/`, your backups, and your configuration in place.

To return to an older mod version, copy its verified DLL from the appropriate
backup folder after saving the current one. If you have no trustworthy original,
use your storefront's repair function.

## Manual installation

Use this method if you prefer to manage the copies yourself.

1. Close the game and confirm its executable version in Properties > Details.
2. Make a separate backup of the original root `steam_api64.dll`.
3. Create `proxy/` beside the game executable. Copy the original DLL there as
   `steam_api64_steam.dll` or `steam_api64_gog.dll` for your edition.
4. Compare SHA-256 checksums of the original, backup, and backend copy with
   `Get-FileHash -Algorithm SHA256`. Continue only if they match.
5. Copy the package's mod DLL to the game folder as `steam_api64.dll`. Compare
   its checksum with the package copy.
6. Launch through Steam/GOG.

Keep GOG's original dependencies in place. The package's `source/` folder is
for development and does not belong in the game folder.

## If the game will not start

Look for `lcu-startup.log` beside the installed mod. If that location is not
writable, check `%TEMP%\LegoCityUndercoverPlus-startup.log`. The log records
the DLL path, Windows error, and missing export name when available.

| Windows error | What to check |
| --- | --- |
| 126 | The original DLL or one of its dependencies is missing. On GOG, check `Galaxy64.dll` too. |
| 193 | The DLL is invalid or has the wrong architecture. |
| 127 | The selected DLL lacks a required API/export. |
| 1114 | DLL initialization failed. Read the mod's log for a more specific cause. |

Keep the original Steam/GOG DLL separate from the mod; renaming the mod as its
own original will not work. Restore missing game files through the storefront
rather than downloading individual DLLs.

The Release DLL includes the MSVC runtime through static linking. A missing
system dependency can still stop Windows before the mod can write a log.

After installing, check mouse movement and zoom, mouse buttons, F8, F9, focus
changes, loading, scripted cameras, and the ferry trip to Albatross and back.
Automated tests cannot check how the camera behaves in the game.
