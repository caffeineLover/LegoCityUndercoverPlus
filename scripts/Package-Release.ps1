param([string]$Version = '1.0.1', [string]$Dll = (Join-Path $PSScriptRoot '../Release/steam_api64.dll'))
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') { throw 'Invalid release version.' }
. (Join-Path $PSScriptRoot 'Get-PeInfo.ps1')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$info = Get-PeInfo $Dll
if ($info.Machine -ne 0x8664) { throw 'Release DLL is not x64.' }
if ($info.Imports -match '(?i)(msvcp|vcruntime|msvcr|ucrtbase|api-ms-win-crt)') { throw 'Release DLL must use the static release CRT (/MT).' }
$expected = @(Get-Content (Join-Path $repo 'src/steam_proxy/steam_api64.def') | Where-Object { $_ -match '^\s*(\w+)=(\w+)\s+@(\d+)' } | ForEach-Object {
	[void]($_ -match '^\s*(\w+)=(\w+)\s+@(\d+)'); '{0}:{1}' -f $Matches[1],$Matches[3]
})
$actual = @($info.Exports | ForEach-Object { '{0}:{1}' -f $_.Name,$_.Ordinal })
if ($expected.Count -ne 690 -or (Compare-Object $expected $actual)) { throw 'Release export names/ordinals differ from the supported proxy.' }
$output = Join-Path $repo 'Release/packages'
New-Item -ItemType Directory -Force $output | Out-Null
$stage = Join-Path $output ('stage-' + [guid]::NewGuid())
New-Item -ItemType Directory $stage | Out-Null
$files = [ordered]@{
	'steam_api64.dll' = (Resolve-Path $Dll).Path
	'INSTALL.md' = (Join-Path $repo 'docs/INSTALL.md')
	'LICENSE' = (Join-Path $repo 'LICENSE')
	'THIRD-PARTY-NOTICES.txt' = (Join-Path $repo 'docs/THIRD-PARTY-NOTICES.txt')
	'Install.ps1' = (Join-Path $PSScriptRoot 'Install-Mod.ps1')
	'Get-PeInfo.ps1' = (Join-Path $PSScriptRoot 'Get-PeInfo.ps1')
	'proxy/README.txt' = (Join-Path $repo 'docs/proxy-README.txt')
}
# Ship the exact buildable source used for this binary, including vendored
# licenses and build/test/package scripts. Never collect Release or local INIs.
foreach ($folder in @('src','scripts'))
{
	Get-ChildItem (Join-Path $repo $folder) -Recurse -File | Where-Object { $_.Extension -in '.cpp','.h','.c','.asm','.def','.inc','.ps1','.rc' } | ForEach-Object {
		$relative = $_.FullName.Substring($repo.Length + 1).Replace('\','/')
		$files['source/' + $relative] = $_.FullName
	}
}
foreach ($file in @('LegoCitiesUndercoverPlus.sln','lcu_mouse.vcxproj','lcu_mouse.vcxproj.filters','LICENSE','README.md','AGENTS.md','docs/INSTALL.md','docs/THIRD-PARTY-NOTICES.txt','docs/proxy-README.txt','docs/release-startup-analysis.md','docs/Agent_HANDOFF.md','docs/mousework.md','docs/mousework-human.md')) { $files['source/' + $file] = Join-Path $repo $file }
$checksums = @()
foreach ($relative in $files.Keys)
{
	$destination = Join-Path $stage $relative
	New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
	Copy-Item -LiteralPath $files[$relative] -Destination $destination
	$checksums += ('{0}  {1}' -f (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant(),$relative)
}
[IO.File]::WriteAllLines((Join-Path $stage 'SHA256SUMS'), ($checksums | Sort-Object), [Text.Encoding]::ASCII)
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$zipPath = Join-Path $output ('LegoCityUndercoverPlus.v' + $Version + '.zip')
if (Test-Path -LiteralPath $zipPath) { throw "Output already exists; choose another version or move it aside: $zipPath" }
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try
{
	Get-ChildItem $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
		$relative = $_.FullName.Substring($stage.Length + 1).Replace('\','/')
		$entry = $zip.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
		$entry.LastWriteTime = [DateTimeOffset]'2000-01-01T00:00:00Z'
		$input = [IO.File]::OpenRead($_.FullName); $stream = $entry.Open()
		try { $input.CopyTo($stream) } finally { $input.Dispose(); $stream.Dispose() }
	}
}
finally { $zip.Dispose() }
& (Join-Path $PSScriptRoot 'Verify-Package.ps1') -Zip $zipPath
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($zipPath + '.sha256'), "$hash  $([IO.Path]::GetFileName($zipPath))`n", [Text.Encoding]::ASCII)
Write-Output "Release candidate: $zipPath`nSHA256: $hash`nStaging directory retained: $stage"
