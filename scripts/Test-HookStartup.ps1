$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = Join-Path $repo ('Release/obj/hook-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force $root | Out-Null
& rc.exe /nologo "/fo$root/game.res" (Join-Path $repo 'src/tests/GameLayoutFixture.rc')
if ($LASTEXITCODE) { throw 'Cannot build hook test version resource.' }
$sources = @('src/tests/HookStartupTests.cpp','src/camera/MouseCameraState.cpp','src/camera/Vector3.cpp','src/config/Settings.cpp','src/input/RawInput.cpp') | ForEach-Object { Join-Path $repo $_ }
$includes = @('camera','config','input','steam_proxy','third_party/minhook','third_party/mini') | ForEach-Object { '/I' + (Join-Path $repo "src/$_") }
& cl.exe /nologo /std:c++17 /EHsc /W4 /MT /DWIN32_LEAN_AND_MEAN /D_CRT_SECURE_NO_WARNINGS @includes @sources "$root/game.res" Setupapi.lib User32.lib Version.lib "/Fo$root/" "/Fe:$root/HookStartupTests.exe"
if ($LASTEXITCODE) { throw 'Cannot build hook startup tests.' }
Push-Location $root
try
{
	$scenarios = @('success','init-failure','already-initialized','create-first-failure','create-second-failure','enable-first-failure','enable-second-failure','startup-log-failure','termination-detach','rollback-failure','rollback-log-failure','detach-failure')
	$failures = @()
	foreach ($scenario in $scenarios)
	{
		# Each invocation is a child process: fail-fast must exit with 1114,
		# while returning from unsafe rollback or escaping an exception fails.
		& "$root/HookStartupTests.exe" $scenario
		$expected = 0
		if ($scenario -in 'rollback-failure','rollback-log-failure','detach-failure') { $expected = 1114 }
		if ($LASTEXITCODE -ne $expected) { $failures += "$scenario exited $LASTEXITCODE (expected $expected)" }
	}
	if ($failures.Count) { throw ($failures -join '; ') }
}
finally { Pop-Location }
Write-Output "Hook startup/cleanup tests passed: $($scenarios.Count) child-process scenarios. Fixtures: $root"
