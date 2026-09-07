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

$currencySource = Get-Content -LiteralPath (Join-Path $sourcePath 'gameplay\economy\currency.lua') -Raw
if ($currencySource -match '\b(BlzCreateFrame|BlzFrame|GetLocalPlayer|RESOURCE_BAR|HONOR_TEXT|FACTION_TEXT)') {
    $failures.Add('Currency gameplay module contains HUD presentation logic')
}

$factionSource = Get-Content -LiteralPath (Join-Path $sourcePath 'gameplay\players\factions.lua') -Raw
if ($factionSource -match '\b(BlzCreateFrame|BlzFrame|GetLocalPlayer|PromptFrame|SimpleButton)') {
    $failures.Add('Faction gameplay module contains presentation logic')
}

$shopDomainFiles = @(
    'gameplay\shops\quote.lua',
    'gameplay\shops\transaction.lua'
)
foreach ($shopDomainFile in $shopDomainFiles) {
    $shopDomainSource = Get-Content -LiteralPath (Join-Path $sourcePath $shopDomainFile) -Raw
    if ($shopDomainSource -match '\bshop\.(current|stock|view)\b') {
        $failures.Add("Shop domain module reads frame-backed state: $shopDomainFile")
    }
}

foreach ($file in $sourceFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    if ($source -match 'Require\(["'']Helper["'']\)') {
        $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)
        $failures.Add("Legacy Helper requirement in $relativePath")
    }
}

# First-party resource names use PascalCase equivalents of their snake_case
# filenames. A resource may add contextual words needed for uniqueness, such
# as warrior.lua -> WarriorSpells, but the filename must remain recognizable.
# Vendor names are retained exactly as supplied upstream.
foreach ($file in $sourceFiles) {
    $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)
    if ($relativePath.StartsWith("vendor$([IO.Path]::DirectorySeparatorChar)")) {
        continue
    }

    $source = Get-Content -LiteralPath $file.FullName -Raw
    $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $normalizedBase = $baseName.Replace('_', '').ToLowerInvariant()

    foreach ($match in $initializerPattern.Matches($source)) {
        $resourceName = $match.Groups[2].Value
        $normalizedResource = $resourceName.Replace('_', '').ToLowerInvariant()
        if (-not (
            $normalizedResource.Contains($normalizedBase) -or
            $normalizedBase.Contains($normalizedResource)
        )) {
            $failures.Add(
                "Initializer '$resourceName' does not match filename '$($file.Name)' in $relativePath"
            )
        }
    }

    $introLines = ($source -split "`r?`n") | Select-Object -First 5
    foreach ($line in $introLines) {
        $label = $line.Trim()
        if ($label -match '^[A-Za-z0-9_ -]+\.lua$' -and $label -cne $file.Name) {
            $failures.Add(
                "Introductory filename '$label' should be '$($file.Name)' in $relativePath"
            )
        }
    }
}

foreach ($file in $sourceFiles) {
    $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)
    $gameplayPrefix = "gameplay$([IO.Path]::DirectorySeparatorChar)"
    if (-not $relativePath.StartsWith($gameplayPrefix)) {
        continue
    }

    $source = Get-Content -LiteralPath $file.FullName -Raw
    if ($source -match 'Require\(["'']Shop["'']\)') {
        $failures.Add("Gameplay module requires shop UI: $relativePath")
    }
    if ($source -match '\bShop\.refresh\s*\(') {
        $failures.Add("Gameplay module refreshes shop UI directly: $relativePath")
    }
}

# Shop inventory is declarative content. Keeping registration calls in one
# subtree prevents world and player runtime modules from acquiring UI/catalog
# responsibilities again.
$shopRegistrationPattern = [regex]'\b(CreateShop|ShopAddCategory|ShopAddItem)\s*\('
foreach ($file in $sourceFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    if (-not $shopRegistrationPattern.IsMatch($source)) {
        continue
    }

    $relativePath = [IO.Path]::GetRelativePath($sourcePath, $file.FullName)
    $contentPrefix = "content$([IO.Path]::DirectorySeparatorChar)shops$([IO.Path]::DirectorySeparatorChar)"
    if (-not $relativePath.StartsWith($contentPrefix)) {
        $failures.Add("Shop registration outside content/shops: $relativePath")
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
    "Architecture check passed: {0} manifest entries, {1} named initializers, naming and phases valid." -f
    $manifestEntries.Count,
    $providers.Count
)
