param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../src/steam_proxy/ProxyExports.inc')
$entries = @($manifest | Where-Object { $_ -match '^PROXY_EXPORT\(' } | ForEach-Object {
	if ($_ -notmatch '^PROXY_EXPORT\((\w+), (\w+), (\d+)\)$') { throw "Invalid proxy manifest entry: $_" }
	[pscustomobject]@{ Name=$Matches[1]; Stub=$Matches[2]; Index=[int]$Matches[3] }
})
if ($entries.Count -ne 690) { throw 'Proxy manifest must preserve all 690 exports.' }
$definitions = @('LIBRARY steam_api64', 'EXPORTS')
$assembly = @()
foreach ($entry in $entries)
{
	$definitions += ('{0}={1} @{2}' -f $entry.Name,$entry.Stub,($entry.Index + 1))
	$assembly += ('PROXY_EXPORT {0}, {1}, {2}' -f $entry.Name,$entry.Stub,$entry.Index)
}
$original = @(Get-Content (Join-Path $PSScriptRoot '../src/steam_proxy/steam_api64.def') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if (Compare-Object $original $definitions) { throw 'Manifest differs from the authoritative export definition.' }
[IO.File]::WriteAllLines((Join-Path $OutputDirectory 'ProxyExports.generated.inc'), $assembly, [Text.Encoding]::ASCII)
