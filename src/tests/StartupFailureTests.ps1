param([Parameter(Mandatory)][string]$Dll)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class StartupProbe {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr LoadLibraryW(string path);
    [DllImport("kernel32.dll")]
    public static extern bool FreeLibrary(IntPtr module);
}
'@
$root = Join-Path ([IO.Path]::GetTempPath()) ('LCUP-startup-' + [guid]::NewGuid())
New-Item -ItemType Directory $root | Out-Null
Copy-Item -LiteralPath $Dll -Destination (Join-Path $root 'steam_api64.dll')
$previousDirectory = [Environment]::CurrentDirectory
try
{
	[Environment]::CurrentDirectory = $root
	$handle = [StartupProbe]::LoadLibraryW((Join-Path $root 'steam_api64.dll'))
	$loadError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
}
finally { [Environment]::CurrentDirectory = $previousDirectory }
if ($handle -ne [IntPtr]::Zero)
{
	[void][StartupProbe]::FreeLibrary($handle)
	throw 'Missing backend must reject DLL initialization.'
}
$log = Join-Path $root 'lcu-startup.log'
if (!(Test-Path -LiteralPath $log)) { throw "Missing backend produced no diagnostic log (LoadLibrary error $loadError). Fixture retained: $root" }
$message = Get-Content -Raw -LiteralPath $log
if (!$message.Contains((Join-Path $root 'proxy\steam_api64_steam.dll')) -or !$message.Contains('Windows error'))
{
	throw "Missing backend diagnostic omitted the absolute path or Windows error: $message"
}
Write-Output "StartupFailureTests passed (missing backend; LoadLibrary error $loadError). Fixture: $root"
