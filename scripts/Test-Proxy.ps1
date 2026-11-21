$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixtures = Join-Path $repo ('Release/obj/proxy-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force $fixtures | Out-Null
$gogNames = @('SteamAPI_Init','SteamAPI_RegisterCallback','SteamAPI_RestartAppIfNecessary','SteamAPI_RunCallbacks','SteamAPI_Shutdown','SteamAPI_UnregisterCallback','SteamApps','SteamRemoteStorage','SteamUser','SteamUserStats','SteamUtils')
$all = @(Get-Content (Join-Path $repo 'src/steam_proxy/steam_api64.def') | Where-Object { $_ -match '^\s*(\w+)=' } | ForEach-Object { [void]($_ -match '^\s*(\w+)='); $Matches[1] })
foreach ($kind in @('fixture','gog-fixture','reject-fixture','dependency-fixture'))
{
	$names = $all
	if ($kind -eq 'gog-fixture') { $names = $gogNames }
	$definition = @('EXPORTS')
	foreach ($name in $names)
	{
		$target = 'FixtureInteger'
		if ($name -eq 'SteamApps') { $target = 'FixtureOther' }
		if ($name -eq 'SteamUtils') { $target = 'FixtureFloat' }
		$definition += "$name=$target"
	}
	$def = Join-Path $fixtures "$kind.def"
	[IO.File]::WriteAllLines($def, $definition, [Text.Encoding]::ASCII)
	$extra = @()
	if ($kind -eq 'reject-fixture') { $extra += '/DREJECT_INITIALIZATION' }
	if ($kind -eq 'dependency-fixture')
	{
		$missingDef = Join-Path $fixtures 'missing.def'
		[IO.File]::WriteAllLines($missingDef, @('LIBRARY LCUPMissingDependency','EXPORTS','MissingDependency'), [Text.Encoding]::ASCII)
		& lib.exe /nologo /machine:x64 "/def:$missingDef" "/out:$fixtures/missing.lib"
		if ($LASTEXITCODE) { throw 'Cannot build dependency import library.' }
		$extra += @('/DMISSING_DEPENDENCY',"$fixtures/missing.lib")
	}
	& cl.exe /nologo /LD /MT /W4 src/tests/ProxyFixture.cpp "/Fo$fixtures/$kind.obj" "/Fe:$fixtures/$kind.dll" @extra /link "/def:$def" "/implib:$fixtures/$kind.lib"
	if ($LASTEXITCODE) { throw "Cannot build $kind." }
}
& ./Release/obj/ProxyLoaderTests.exe $fixtures
if ($LASTEXITCODE) { throw 'ProxyLoaderTests failed.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File src/tests/StartupFailureTests.ps1 -Dll Release/steam_api64.dll
if ($LASTEXITCODE) { throw 'StartupFailureTests failed.' }
# A non-game host cannot receive fixed-RVA hooks. Use it to exercise forwarding
# with real DLLs independently of game availability and with an unrelated CWD.
foreach ($edition in @('steam','gog'))
{
	$layout = Join-Path $fixtures $edition
	New-Item -ItemType Directory -Force (Join-Path $layout 'proxy') | Out-Null
	Copy-Item Release/steam_api64.dll (Join-Path $layout 'steam_api64.dll')
	$backend = 'fixture.dll'
	if ($edition -eq 'gog')
	{
		$backend = 'gog-fixture.dll'
		New-Item -ItemType File (Join-Path $layout 'gog.ico') | Out-Null
	}
	Copy-Item (Join-Path $fixtures $backend) (Join-Path $layout "proxy/steam_api64_$edition.dll")
	Push-Location $env:TEMP
	try
	{
		& "$repo/Release/obj/ProxyForwardingTests.exe" (Join-Path $layout 'steam_api64.dll')
		if ($LASTEXITCODE) { throw "Forwarding failed for $edition with unrelated CWD." }
		if (!(Get-Content -Raw (Join-Path $layout 'lcu-startup.log')).Contains('hooks disabled')) { throw 'Unverified host version was not rejected for hooks.' }
		if ($edition -eq 'gog')
		{
			& "$repo/Release/obj/ProxyForwardingTests.exe" (Join-Path $layout 'steam_api64.dll') missing
			if ($LASTEXITCODE -ne 127) { throw 'Missing optional GOG export did not fail safely with error 127.' }
			if (!(Get-Content -Raw (Join-Path $layout 'lcu-startup.log')).Contains('GetHSteamPipe')) { throw 'Missing export diagnostic omitted its name.' }
		}
	}
	finally { Pop-Location }
}
Write-Output "Proxy integration tests passed. Fixtures retained: $fixtures"
