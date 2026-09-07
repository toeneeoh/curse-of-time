param(
    [string] $SourceRoot = (Join-Path $PSScriptRoot '..\src')
)

$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $SourceRoot).Path
$manifestPath = Join-Path $sourcePath 'bootstrap\root.lua'
$failures = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Error "Bootstrap manifest not found: $manifestPath"
    exit 1
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw
$manifestEntries = [regex]::Matches($manifest, "dofile\('([^']+)'\)") |
    ForEach-Object { $_.Groups[1].Value }

foreach ($group in $manifestEntries | Group-Object) {
    if ($group.Count -gt 1) {
        $failures.Add("Duplicate manifest entry: $($group.Name)")
    }
}

foreach ($entry in $manifestEntries) {
    $target = Join-Path $sourcePath $entry
    if (-not (Test-Path -LiteralPath $target)) {
        $failures.Add("Missing manifest source: $entry")
    }
}

$providers = @{}
$initializers = [System.Collections.Generic.List[object]]::new()
$initializerPattern = [regex]'OnInit\.(global|final|config|main|root|trig)\(["'']([^"'']+)["'']'
$requirementPattern = [regex]'Require\(["'']([^"'']+)["'']\)'
$sourceFiles = Get-ChildItem -LiteralPath $sourcePath -Recurse -Filter '*.lua'

foreach ($file in $sourceFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    $matches = $initializerPattern.Matches($source)

    for ($index = 0; $index -lt $matches.Count; $index++) {
        $match = $matches[$index]
        $phase = $match.Groups[1].Value
        $name = $match.Groups[2].Value
        $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)

        if ($providers.ContainsKey($name)) {
            $failures.Add("Duplicate initializer '$name': $($providers[$name].File), $relativePath")
        } else {
            $providers[$name] = [pscustomobject]@{ Phase = $phase; File = $relativePath }
        }

        $end = if ($index + 1 -lt $matches.Count) { $matches[$index + 1].Index } else { $source.Length }
        $body = $source.Substring($match.Index, $end - $match.Index)
        $requirements = $requirementPattern.Matches($body) |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique

        $initializers.Add([pscustomobject]@{
            Name = $name
            Phase = $phase
            File = $relativePath
            Requirements = $requirements
        })
    }
}

# TimerQueue is an eagerly defined vendor-style global rather than a named
# TotalInitialization resource. All other literal requirements must have a
# named provider so renames and moves remain statically visible.
$allowedGlobalRequirements = @('TimerQueue')

foreach ($initializer in $initializers) {
    foreach ($requirement in $initializer.Requirements) {
        if (-not $providers.ContainsKey($requirement)) {
            if ($requirement -notin $allowedGlobalRequirements) {
                $failures.Add("Unresolved requirement '$requirement' in $($initializer.File)")
            }
            continue
        }

        $provider = $providers[$requirement]
        if ($initializer.Phase -eq 'global' -and $provider.Phase -eq 'final') {
            $failures.Add(
                "Phase inversion: global '$($initializer.Name)' requires final '$requirement'"
            )
        }
    }
}

if ($manifest -match 'legacy_helpers\.lua') {
    $failures.Add('Legacy helper module is present in the bootstrap manifest')
}

foreach ($file in $sourceFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    if ($source -match 'Require\(["'']Helper["'']\)') {
        $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)
        $failures.Add("Legacy Helper requirement in $relativePath")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Architecture check failed with $($failures.Count) problem(s):"
    foreach ($failure in $failures) {
        Write-Host "  - $failure"
    }
    exit 1
}

Write-Host (
    "Architecture check passed: {0} manifest entries, {1} named initializers, no phase inversions." -f
    $manifestEntries.Count,
    $providers.Count
)
