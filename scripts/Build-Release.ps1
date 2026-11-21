param([string]$Version = '1.0.1', [switch]$SkipPackage)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo
if (!(Get-Command cl.exe -ErrorAction SilentlyContinue))
{
	$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
	if (!(Test-Path $vswhere)) { throw 'Install Visual Studio 2026 C++ Build Tools (v145) and the Windows SDK.' }
	$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
	if (!$installation) { throw 'No Visual Studio C++ installation found.' }
	& (Join-Path $installation 'Common7/Tools/Launch-VsDevShell.ps1') -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
}
function Invoke-Checked([string]$Command, [string[]]$Arguments)
{
	& $Command @Arguments
	if ($LASTEXITCODE -ne 0) { throw "$Command exited with $LASTEXITCODE" }
}
New-Item -ItemType Directory -Force Release/obj | Out-Null
Invoke-Checked msbuild.exe @('LegoCitiesUndercoverPlus.sln','/t:Rebuild','/p:Configuration=Release','/p:Platform=x64','/nologo','/verbosity:minimal')
$common = @('/nologo','/std:c++17','/EHsc','/W4','/MT','/DWIN32_LEAN_AND_MEAN','/FoRelease/obj/')
Invoke-Checked cl.exe ($common + @('/WX','src/tests/MouseCameraStateTests.cpp','src/camera/MouseCameraState.cpp','/Fe:Release/obj/MouseCameraStateTests.exe'))
Invoke-Checked './Release/obj/MouseCameraStateTests.exe' @()
Invoke-Checked cl.exe ($common + @('src/tests/RawInputLifecycleTests.cpp','src/input/RawInput.cpp','Setupapi.lib','User32.lib','/Fe:Release/obj/RawInputLifecycleTests.exe'))
Invoke-Checked './Release/obj/RawInputLifecycleTests.exe' @()
Invoke-Checked cl.exe ($common + @('/WX','/Isrc/third_party/mini','src/tests/SettingsTests.cpp','src/config/Settings.cpp','/Fe:Release/obj/SettingsTests.exe'))
Invoke-Checked './Release/obj/SettingsTests.exe' @()
Invoke-Checked cl.exe ($common + @('/WX','src/tests/ProxyLoaderTests.cpp','src/steam_proxy/ProxyLoader.cpp','/Fe:Release/obj/ProxyLoaderTests.exe'))
Invoke-Checked cl.exe ($common + @('/WX','src/tests/ProxyForwardingTests.cpp','/Fe:Release/obj/ProxyForwardingTests.exe'))
& (Join-Path $PSScriptRoot 'Test-Proxy.ps1')
& (Join-Path $PSScriptRoot 'Test-HookStartup.ps1')
if (!$SkipPackage)
{
	& (Join-Path $PSScriptRoot 'Package-Release.ps1') -Version $Version
	& (Join-Path $PSScriptRoot 'Test-Package.ps1') -Zip (Join-Path $repo "Release/packages/LegoCityUndercoverPlus.v$Version.zip")
}
