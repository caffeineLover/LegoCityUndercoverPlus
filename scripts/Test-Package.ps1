param([Parameter(Mandatory)][string]$Zip)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = Join-Path $repo ('Release/obj/package-tests-' + [guid]::NewGuid())
$package = Join-Path $root 'package'
New-Item -ItemType Directory -Force $package | Out-Null
Expand-Archive -LiteralPath $Zip -DestinationPath $package
$fixture = Get-ChildItem (Join-Path $repo 'Release/obj') -Directory -Filter 'proxy-tests-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (!$fixture) { throw 'Run Test-Proxy.ps1 to build synthetic backend fixtures first.' }
& rc.exe /nologo "/fo$root/game.res" (Join-Path $repo 'src/tests/GameLayoutFixture.rc')
if ($LASTEXITCODE) { throw 'Cannot build synthetic game version resource.' }
& cl.exe /nologo /MT (Join-Path $repo 'src/tests/GameLayoutFixture.cpp') "$root/game.res" "/Fo$root/game.obj" "/Fe:$root/game.exe"
if ($LASTEXITCODE) { throw 'Cannot build synthetic game executable.' }
foreach ($edition in @('Steam','GOG'))
{
	$game = Join-Path $root $edition
	New-Item -ItemType Directory $game | Out-Null
	Copy-Item (Join-Path $root 'game.exe') (Join-Path $game 'LEGOLCUR_DX11.exe')
	$original = Join-Path $fixture.FullName 'fixture.dll'
	if ($edition -eq 'GOG')
	{
		$original = Join-Path $fixture.FullName 'gog-fixture.dll'
		New-Item -ItemType File (Join-Path $game 'gog.ico') | Out-Null
	}
	Copy-Item $original (Join-Path $game 'steam_api64.dll')
	$originalHash = (Get-FileHash $original).Hash
	$modHash = (Get-FileHash (Join-Path $package 'steam_api64.dll')).Hash
	& (Join-Path $package 'Install.ps1') -GameDirectory $game -Edition $edition
	$backend = Join-Path $game ('proxy/steam_api64_' + $edition.ToLowerInvariant() + '.dll')
	if ((Get-FileHash $backend).Hash -ne $originalHash -or (Get-FileHash (Join-Path $game 'steam_api64.dll')).Hash -ne $modHash) { throw "$edition clean-install layout/hash verification failed." }
	$originalBackup = Join-Path $game "lcup-backups/$originalHash/steam_api64.dll"
	if ((Get-FileHash $originalBackup).Hash -ne $originalHash) { throw 'Original not recoverable before replacement.' }
	# Reinstall/upgrade retains the original instead of backing up the mod as it.
	& (Join-Path $package 'Install.ps1') -GameDirectory $game -Edition $edition
	if ((Get-FileHash $backend).Hash -ne $originalHash) { throw 'Upgrade replaced the original backend.' }
	& (Join-Path $package 'Install.ps1') -GameDirectory $game -Edition $edition -Rollback
	if ((Get-FileHash (Join-Path $game 'steam_api64.dll')).Hash -ne $originalHash) { throw 'Rollback did not restore the original.' }
	if ((Get-FileHash (Join-Path $game "lcup-backups/$modHash/steam_api64.dll")).Hash -ne $modHash) { throw 'Rollback failed to preserve the mod.' }
}
# Invalid manifests must leave files AND backup/backend directories untouched,
# including upgrades and rollback (which also consume package validation code).
$manifestPath = Join-Path $package 'SHA256SUMS'
$originalManifest = [IO.File]::ReadAllLines($manifestPath)
$modRecord = $originalManifest | Where-Object { $_.EndsWith('  steam_api64.dll') }
$cases = @(
	@{ Name='empty'; Records=@() },
	@{ Name='duplicate'; Records=@($originalManifest) + @($originalManifest[0]) },
	@{ Name='case duplicate'; Records=@($originalManifest) + @($modRecord.ToUpperInvariant()) },
	@{ Name='aliased duplicate'; Records=@($originalManifest) + @($modRecord.Replace('  steam_api64.dll','  ./steam_api64.dll')) },
	@{ Name='checksum mismatch'; Records=@($originalManifest | ForEach-Object { if ($_ -eq $modRecord) { ('0' * 64) + '  steam_api64.dll' } else { $_ } }) }
)
foreach ($requiredInput in @('steam_api64.dll','INSTALL.md','LICENSE','THIRD-PARTY-NOTICES.txt','Install.ps1','Get-PeInfo.ps1','proxy/README.txt','source/lcu_mouse.vcxproj','source/src/steam_proxy/steam_api64.def'))
{
	$cases += @{ Name="missing $requiredInput"; Records=@($originalManifest | Where-Object { !$_.EndsWith('  ' + $requiredInput) }) }
}
try
{
	foreach ($case in $cases)
	{
		[IO.File]::WriteAllLines($manifestPath, [string[]]$case.Records, [Text.Encoding]::ASCII)
		foreach ($mode in @('clean','upgrade','rollback'))
		{
			$manifestGame = Join-Path $root ('manifest-' + [guid]::NewGuid())
			New-Item -ItemType Directory $manifestGame | Out-Null
			Copy-Item (Join-Path $root 'game.exe') (Join-Path $manifestGame 'LEGOLCUR_DX11.exe')
			$rootSource = Join-Path $fixture.FullName 'fixture.dll'
			if ($mode -ne 'clean')
			{
				New-Item -ItemType Directory (Join-Path $manifestGame 'proxy') | Out-Null
				Copy-Item $rootSource (Join-Path $manifestGame 'proxy/steam_api64_steam.dll')
				$rootSource = Join-Path $package 'steam_api64.dll'
			}
			Copy-Item $rootSource (Join-Path $manifestGame 'steam_api64.dll')
			$before = @(Get-ChildItem $manifestGame -Recurse -Force | ForEach-Object { $_.FullName; if (!$_.PSIsContainer) { (Get-FileHash -LiteralPath $_.FullName).Hash } })
			$rejected = $false
			try { & (Join-Path $package 'Install.ps1') -GameDirectory $manifestGame -Edition Steam -Rollback:($mode -eq 'rollback') }
			catch
			{
				if ($_.Exception.Message -notmatch '(?i)(manifest|checksum)') { throw }
				$rejected = $true
			}
			$after = @(Get-ChildItem $manifestGame -Recurse -Force | ForEach-Object { $_.FullName; if (!$_.PSIsContainer) { (Get-FileHash -LiteralPath $_.FullName).Hash } })
			if (!$rejected -or (Compare-Object $before $after)) { throw "Installer accepted $($case.Name) manifest or changed the $mode installation before rejecting it." }
		}
	}
}
finally { [IO.File]::WriteAllLines($manifestPath, $originalManifest, [Text.Encoding]::ASCII) }
# An overwritten original with no backend must not be mistaken for stock.
$broken = Join-Path $root 'missing-original'
New-Item -ItemType Directory $broken | Out-Null
Copy-Item (Join-Path $root 'game.exe') (Join-Path $broken 'LEGOLCUR_DX11.exe')
Copy-Item (Join-Path $package 'steam_api64.dll') (Join-Path $broken 'steam_api64.dll')
$rejected = $false
try { & (Join-Path $package 'Install.ps1') -GameDirectory $broken -Edition Steam } catch { $rejected = $true }
if (!$rejected -or (Test-Path (Join-Path $broken 'proxy'))) { throw 'Installer failed to reject a missing original without changing layout.' }
# Unsupported executable must be rejected without creating a backend.
Copy-Item (Join-Path $PSHOME 'powershell.exe') (Join-Path $broken 'LEGOLCUR_DX11.exe') -Force
$rejected = $false
try { & (Join-Path $package 'Install.ps1') -GameDirectory $broken -Edition Steam } catch { $rejected = $true }
if (!$rejected -or (Test-Path (Join-Path $broken 'proxy'))) { throw 'Installer failed to reject an unsupported executable.' }
# Prove the ZIP verifier catches an accidental bundled proprietary backend.
$badZip = Join-Path $root 'bad-proprietary.zip'
Copy-Item -LiteralPath $Zip -Destination $badZip
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($badZip, [IO.Compression.ZipArchiveMode]::Update)
[void]$archive.CreateEntry('proxy/steam_api64_steam.dll')
$archive.Dispose()
$rejected = $false
try { & (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Zip $badZip } catch { $rejected = $true }
if (!$rejected) { throw 'ZIP verifier accepted a forbidden backend.' }
$badZip = Join-Path $root 'bad-checksum.zip'
Copy-Item -LiteralPath $Zip -Destination $badZip
$archive = [IO.Compression.ZipFile]::Open($badZip, [IO.Compression.ZipArchiveMode]::Update)
$archive.GetEntry('steam_api64.dll').Delete()
$stream = $archive.CreateEntry('steam_api64.dll').Open()
$stream.WriteByte(0); $stream.Dispose(); $archive.Dispose()
$rejected = $false
try { & (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Zip $badZip } catch { $rejected = $true }
if (!$rejected) { throw 'ZIP verifier accepted a corrupted DLL.' }
Write-Output "Package tests passed: Steam/GOG clean install, upgrade, rollback, missing original, unsupported version, prohibited backend and corruption. Fixtures: $root"
