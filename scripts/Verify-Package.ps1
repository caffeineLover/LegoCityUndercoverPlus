param([Parameter(Mandatory)][string]$Zip)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Zip))
try
{
	$names = @($archive.Entries.FullName)
	if (($names | Select-Object -Unique).Count -ne $names.Count) { throw 'Duplicate ZIP entries.' }
	foreach ($name in $names)
	{
		if ($name -match '(^/|\\|(^|/)\.\.(/|$)|:)' -or $name -match '(?i)(steam_api64_(steam|gog)\.dll|Galaxy64\.dll|LEGOLCUR_DX11\.exe|\.ini$|\.pdb$|\.obj$)') { throw "Forbidden ZIP entry: $name" }
		if ($name -notin 'steam_api64.dll','INSTALL.md','LICENSE','THIRD-PARTY-NOTICES.txt','Install.ps1','Get-PeInfo.ps1','proxy/README.txt','SHA256SUMS' -and !$name.StartsWith('source/')) { throw "Unexpected ZIP entry: $name" }
	}
	foreach ($required in @('steam_api64.dll','INSTALL.md','LICENSE','THIRD-PARTY-NOTICES.txt','Install.ps1','Get-PeInfo.ps1','proxy/README.txt','SHA256SUMS','source/lcu_mouse.vcxproj','source/src/steam_proxy/steam_api64.def')) { if ($names -notcontains $required) { throw "Missing ZIP entry: $required" } }
	$reader = [IO.StreamReader]::new($archive.GetEntry('SHA256SUMS').Open())
	try { $manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
	$listed = @()
	foreach ($line in ($manifest -split '\r?\n' | Where-Object { $_ }))
	{
		if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw 'Invalid checksum record.' }
		$expected = $Matches[1]; $name = $Matches[2]; $listed += $name
		$entry = $archive.GetEntry($name)
		if (!$entry) { throw "Missing checksummed file: $name" }
		$stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
		try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() } finally { $stream.Dispose(); $sha.Dispose() }
		if ($actual -ne $expected) { throw "ZIP checksum mismatch: $name" }
	}
	if (Compare-Object ($names | Where-Object { $_ -ne 'SHA256SUMS' }) $listed) { throw 'Checksum manifest does not cover the complete ZIP.' }
	Write-Output "Verified $($names.Count) ZIP entries; no proprietary backends or game files."
}
finally { $archive.Dispose() }
