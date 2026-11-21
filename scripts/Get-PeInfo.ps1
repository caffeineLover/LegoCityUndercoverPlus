function Get-PeInfo
{
	param([Parameter(Mandatory)][string]$Path)
	$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
	if ($bytes.Length -lt 64 -or [BitConverter]::ToUInt16($bytes, 0) -ne 0x5A4D) { throw "Not a PE file: $Path" }
	$pe = [BitConverter]::ToInt32($bytes, 60)
	if ($pe -lt 0 -or $pe + 264 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550) { throw "Invalid PE header: $Path" }
	$optional = $pe + 24
	$magic = [BitConverter]::ToUInt16($bytes, $optional)
	if ($magic -notin 0x20B, 0x10B) { throw "Invalid optional header: $Path" }
	$directory = $optional + 96
	if ($magic -eq 0x20B) { $directory = $optional + 112 }
	$sections = @()
	$sectionTable = $optional + [BitConverter]::ToUInt16($bytes, $pe + 20)
	for ($i = 0; $i -lt [BitConverter]::ToUInt16($bytes, $pe + 6); ++$i)
	{
		$offset = $sectionTable + 40 * $i
		$sections += [pscustomobject]@{
			Rva = [BitConverter]::ToUInt32($bytes, $offset + 12)
			Size = [Math]::Max([BitConverter]::ToUInt32($bytes, $offset + 8), [BitConverter]::ToUInt32($bytes, $offset + 16))
			Raw = [BitConverter]::ToUInt32($bytes, $offset + 20)
		}
	}
	function Get-Offset([uint32]$rva)
	{
		foreach ($section in $sections)
		{
			if ($rva -ge $section.Rva -and $rva -lt $section.Rva + $section.Size) { return [int]($rva - $section.Rva + $section.Raw) }
		}
		throw "RVA outside sections in ${Path}: $rva"
	}
	function Get-String([uint32]$rva)
	{
		$offset = Get-Offset $rva
		$end = $offset
		while ($bytes[$end] -ne 0) { ++$end }
		return [Text.Encoding]::ASCII.GetString($bytes, $offset, $end - $offset)
	}
	$exports = @()
	$exportRva = [BitConverter]::ToUInt32($bytes, $directory)
	if ($exportRva)
	{
		$export = Get-Offset $exportRva
		$names = Get-Offset ([BitConverter]::ToUInt32($bytes, $export + 32))
		$ordinals = Get-Offset ([BitConverter]::ToUInt32($bytes, $export + 36))
		$functions = Get-Offset ([BitConverter]::ToUInt32($bytes, $export + 28))
		$base = [BitConverter]::ToUInt32($bytes, $export + 16)
		for ($i = 0; $i -lt [BitConverter]::ToUInt32($bytes, $export + 24); ++$i)
		{
			$index = [BitConverter]::ToUInt16($bytes, $ordinals + 2 * $i)
			$exports += [pscustomobject]@{ Name = Get-String ([BitConverter]::ToUInt32($bytes, $names + 4 * $i)); Ordinal = $base + $index; Rva = [BitConverter]::ToUInt32($bytes, $functions + 4 * $index) }
		}
	}
	$imports = @()
	$importFunctions = @{}
	$importRva = [BitConverter]::ToUInt32($bytes, $directory + 8)
	if ($importRva)
	{
		$descriptor = Get-Offset $importRva
		while ([BitConverter]::ToUInt32($bytes, $descriptor + 12))
		{
			$library = Get-String ([BitConverter]::ToUInt32($bytes, $descriptor + 12))
			$imports += $library
			$thunkRva = [BitConverter]::ToUInt32($bytes, $descriptor)
			if (!$thunkRva) { $thunkRva = [BitConverter]::ToUInt32($bytes, $descriptor + 16) }
			$thunk = Get-Offset $thunkRva
			$width = 4
			if ($magic -eq 0x20B) { $width = 8 }
			$functions = @()
			while ([BitConverter]::ToUInt32($bytes, $thunk))
			{
				if ($bytes[$thunk + $width - 1] -band 0x80) { $functions += '#' + [BitConverter]::ToUInt16($bytes, $thunk) }
				else { $functions += Get-String ([BitConverter]::ToUInt32($bytes, $thunk) + 2) }
				$thunk += $width
			}
			$importFunctions[$library] = $functions
			$descriptor += 20
		}
	}
	[pscustomobject]@{ Path = $Path; Machine = [BitConverter]::ToUInt16($bytes, $pe + 4); Exports = $exports; Imports = $imports; ImportFunctions = $importFunctions; Bytes = $bytes; Sections = $sections }
}
