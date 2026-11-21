param(
	[Parameter(Mandatory)][string]$GameDirectory,
	[Parameter(Mandatory)][ValidateSet('Steam','GOG')][string]$Edition,
	[string]$PackageDirectory = $PSScriptRoot,
	[switch]$Rollback
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-PeInfo.ps1')
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$exe = Join-Path $game 'LEGOLCUR_DX11.exe'
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Choose the folder containing LEGOLCUR_DX11.exe.' }
if (Get-Process LEGOLCUR_DX11 -ErrorAction SilentlyContinue) { throw 'Close LEGO City Undercover before installing or rolling back.' }
$rootDll = Join-Path $game 'steam_api64.dll'
$backend = Join-Path $game ('proxy/steam_api64_' + $Edition.ToLowerInvariant() + '.dll')
function Copy-Verified([string]$source, [string]$destination)
{
	$hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
	if (Test-Path -LiteralPath $destination)
	{
		if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $hash) { throw "Refusing to overwrite existing backup: $destination" }
		return
	}
	Copy-Item -LiteralPath $source -Destination $destination
	if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $hash) { throw "Backup verification failed: $destination" }
}
function Assert-Original([string]$path)
{
	$info = Get-PeInfo $path
	if ($info.Machine -ne 0x8664 -or $info.Imports -contains 'SETUPAPI.dll') { throw "Not an unmodified x64 game API DLL: $path. Restore it from your own storefront installation/backup." }
	$required = @('SteamAPI_Init','SteamAPI_RegisterCallback','SteamAPI_RestartAppIfNecessary','SteamAPI_RunCallbacks','SteamAPI_Shutdown','SteamAPI_UnregisterCallback','SteamApps','SteamRemoteStorage','SteamUser','SteamUserStats','SteamUtils')
	if ($Edition -eq 'Steam')
	{
		$required = @(Get-Content (Join-Path $PackageDirectory 'source/src/steam_proxy/steam_api64.def') | Where-Object { $_ -match '^\s*(\w+)=' } | ForEach-Object { [void]($_ -match '^\s*(\w+)='); $Matches[1] })
		if ($required.Count -ne 690) { throw 'Package source export definition is missing or invalid.' }
	}
	foreach ($name in $required) { if ($info.Exports.Name -notcontains $name) { throw "Original DLL lacks $name : $path" } }
}
# Validate the complete required package layout for installation AND rollback,
# before creating backend/backup directories or replacing any DLL.
$listed = @()
foreach ($line in Get-Content -LiteralPath (Join-Path $PackageDirectory 'SHA256SUMS'))
{
	if ($line -notmatch '^([0-9A-Fa-f]{64})  (.+)$') { throw 'Invalid package checksum manifest.' }
	$expected = $Matches[1]; $relative = $Matches[2]
	# Canonical relative names prevent two records naming the same Windows file.
	if ($relative -match '(^/|\\|(^|/)\.\.?(/|$)|:|//|/$|[. ](/|$))') { throw 'Unsafe package manifest path.' }
	if ($listed -contains $relative) { throw "Duplicate package manifest path: $relative" }
	$listed += $relative
	if ((Get-FileHash -LiteralPath (Join-Path $PackageDirectory $relative) -Algorithm SHA256).Hash -ne $expected) { throw "Package checksum mismatch: $relative" }
}
foreach ($requiredInput in @('steam_api64.dll','INSTALL.md','LICENSE','THIRD-PARTY-NOTICES.txt','Install.ps1','Get-PeInfo.ps1','proxy/README.txt','source/lcu_mouse.vcxproj','source/src/steam_proxy/steam_api64.def'))
{
	if ($listed -notcontains $requiredInput) { throw "Package manifest does not cover installation input: $requiredInput" }
}
if ($Rollback)
{
	Assert-Original $backend
}
else
{
	if ((Get-Item -LiteralPath $exe).VersionInfo.FileVersion -ne '1.0.0.15609011') { throw 'Only executable version 1.0.0.15609011 is supported. No files changed.' }
	if ((Test-Path -LiteralPath (Join-Path $game 'gog.ico') -PathType Leaf) -ne ($Edition -eq 'GOG')) { throw 'Edition does not agree with the installed gog.ico marker. No files changed.' }
	$mod = Join-Path $PackageDirectory 'steam_api64.dll'
	if ((Get-PeInfo $mod).Machine -ne 0x8664) { throw 'The mod must be x64.' }
	if (Test-Path -LiteralPath $backend)
	{
		Assert-Original $backend
	}
	else
	{
		Assert-Original $rootDll
		New-Item -ItemType Directory -Force (Join-Path $game 'proxy') | Out-Null
		Copy-Verified $rootDll $backend
	}
}
if (Test-Path -LiteralPath $rootDll)
{
	$rootHash = (Get-FileHash -LiteralPath $rootDll -Algorithm SHA256).Hash
	$backupFolder = Join-Path $game ('lcup-backups/' + $rootHash)
	New-Item -ItemType Directory -Force $backupFolder | Out-Null
	Copy-Verified $rootDll (Join-Path $backupFolder 'steam_api64.dll')
}
$replacement = $backend
if (!$Rollback) { $replacement = $mod }
# Every overwritten DLL is now recoverable from a verified copy. Copying the
# replacement never removes the original backend or a prior-version backup.
Copy-Item -LiteralPath $replacement -Destination $rootDll -Force
if ((Get-FileHash -LiteralPath $replacement).Hash -ne (Get-FileHash -LiteralPath $rootDll).Hash) { throw 'Installed DLL checksum mismatch; restore the verified backup.' }
Write-Output "DLL installed and verified: $rootDll. Original retained: $backend. Configuration untouched."
