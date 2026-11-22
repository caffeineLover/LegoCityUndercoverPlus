The mod needs the original steam_api64.dll from your own game installation.
This package does not include Steam/GOG proprietary DLLs.

The installer preserves that original here as:

  Steam: proxy/steam_api64_steam.dll
  GOG:   proxy/steam_api64_gog.dll

Only your edition's DLL is needed. For GOG, leave Galaxy64.dll and the game's
other original dependencies beside the executable.

For manual installation, copy the original DLL here before replacing the root
DLL with the mod. Never use the mod itself as the original.

See INSTALL.md and Install.ps1 in the package's top folder.
