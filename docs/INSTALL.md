# Install, upgrade, and recover

LEGO City Undercover Plus is an unofficial mod based on twisted89's
[mouse-support mod](https://github.com/twisted89/Lego-City-Undercover-Mouse-Support).
Only Windows x64 executable **1.0.0.15609011** is supported. Other versions
are not supported; the DLL refuses to apply its fixed camera/window offsets
when that executable version cannot be verified.

## Before you install

Close the game. Extract the entire ZIP to a separate folder first, not directly
over your game. No Steam/GOG proprietary DLL is included. Use the original
`steam_api64.dll` supplied with **your own installation of this game and edition**.
Do not use another game's SDK DLL, a downloaded replacement, or the mod itself.

If v1.0.0 already overwrote your original DLL, look for an existing original
under `proxy/` or your backups. Otherwise uninstall the mod DLL, then use Steam's
Verify integrity or GOG's Verify/Repair to restore the original. Verify/Repair
may leave mod-added files behind; it does not prove that a renamed file is stock.
Keep `lcu.ini` if you want to retain your settings.

## Recommended installation

From the extracted package folder, run Windows PowerShell (administrator rights
are needed only if your game folder requires them):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GameDirectory 'C:\your\game' -Edition Steam
```

For GOG use `-Edition GOG`. Its installed `gog.ico` marker must be present and its
original `Galaxy64.dll` and dependencies must remain installed beside the EXE.
The script checks the supported executable version, package checksums, x64 API
exports and common mod-proxy signatures. These are safeguards, not proof of a
file's provenance: start from a known-clean storefront installation.

Before replacing anything, the script copies the original to the correct
`proxy/` filename and verifies its SHA-256. An existing backend is validated and
never overwritten. The root DLL is also copied into a content-addressed
`lcup-backups/<SHA256>/` folder before replacement. The installed DLL's hash is
checked against the package. Your INI is not overwritten.

The resulting layout is:

```text
LEGO City Undercover/
  LEGOLCUR_DX11.exe           # version 1.0.0.15609011
  steam_api64.dll             # this mod
  proxy/
    steam_api64_steam.dll     # original from YOUR Steam game, OR
    steam_api64_gog.dll       # original from YOUR GOG game
  gog.ico                    # GOG only; supplied by that installation
  Galaxy64.dll               # GOG only; supplied by that installation
  lcu.ini                    # generated on first supported game launch
  lcup-backups/               # verified prior root DLLs; retain for recovery
```

Only the backend for your edition is required. Paths are resolved relative to
the installed mod DLL, so changing a shortcut's working directory cannot hide
the backend. Existing INI lookup/persistence remains game-working-directory
relative; launch normally through your storefront to retain existing behavior.

## Manual installation

1. Close the game and confirm its executable version in Properties > Details.
2. Make a separate verified backup of its original root `steam_api64.dll`.
3. Create `proxy/` beside the EXE. Copy (do not merely move) that original into
   `proxy/steam_api64_steam.dll` or `proxy/steam_api64_gog.dll` for your edition.
4. Compare SHA-256 hashes of the original, separate backup, and backend copy
   with `Get-FileHash -Algorithm SHA256`. Stop if they differ.
5. Only now copy the package's root `steam_api64.dll` beside the EXE. Keep all
   original GOG dependencies and the `gog.ico` marker. Compare the installed
   mod DLL's hash with the package copy.
6. Launch through Steam/GOG. Do not copy the package's `source/` folder into
   your game. It is the exact corresponding source for this release.

## Upgrade

Close the game. Back up `lcu.ini` and the current mod DLL. Retain the original
backend in `proxy/`; do **not** replace it with the old mod. Extract the new
package elsewhere and run its installer with the same game path and edition.
It preserves the backend and a verified copy of the prior root DLL.

## Rollback / uninstall

Close the game and run the same installer with `-Rollback` added. It validates
the original backend, backs up the current root DLL, then restores the original
to `steam_api64.dll`. It does not delete the backend, backups, or configuration.
To return to an older mod instead, copy that mod from the appropriate verified
`lcup-backups/<SHA256>/` folder to the root after saving the current DLL.
If no trustworthy original remains, use your storefront's repair function.

## Startup diagnostics

Check `lcu-startup.log` beside the installed mod. If that directory is not
writable, check `%TEMP%\LegoCityUndercoverPlus-startup.log`. Messages also go to
Windows debugger output. A backend failure identifies its absolute path,
Windows error code/text, and a missing required export where applicable.
Error 126 can mean the DLL **or one of its dependencies** is missing (notably
GOG's `Galaxy64.dll`); 193 usually means a wrong-architecture or invalid DLL;
127 means an incompatible API/export set. The game may additionally show a
generic DLL initialization error (1114).

The Release build uses the static MSVC runtime; no VC runtime installers or
runtime DLL copies are bundled. A missing system dependency can still stop
Windows before this mod's diagnostic code runs. Restore/repair the game rather
than obtaining individual system DLLs from third-party download sites.

The game still needs a live smoke test after installing: startup, Steam/GOG
integration, mouse movement/zoom/buttons, F8 (including held-key behavior), F9,
focus loss/regain, scripted cameras, loading/fast travel, and ferry travel to
Albatross Island and back. Automated fixture tests are not an in-game test.
