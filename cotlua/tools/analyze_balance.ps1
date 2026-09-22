param(
    [string] $DataDirectory = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Warcraft III\CustomMapData\CoT Nevermore BETA\dev'),
    [string[]] $Hero = @('Vampire Lord'),
    [int[]] $Levels = @(400),
    [ValidateSet('All', 'Attack', 'Spell', 'Balanced', 'Durability')]
    [string] $Objective = 'All',
    [ValidateSet('Both', 'Average', 'Perfect')]
    [string] $Quality = 'Both',
    [ValidateSet('Any', 'Drop', 'Shop')]
    [string] $Acquisition = 'Any',
    [switch] $RequireProficiency,
    [double] $StrengthWeight = 1.0,
    [double] $AgilityWeight = 1.0,
    [double] $IntelligenceWeight = 1.0,
    [double] $TargetArmor = -1.0,
    [ValidateSet('Auto', 'Normal', 'Chaos')]
    [string] $TargetDefense = 'Auto',
    [ValidateRange(20, 300)]
    [int] $CandidateLimit = 40,
    [ValidateRange(50, 5000)]
    [int] $BeamWidth = 150,
    [string] $OutputPath = (Join-Path (Get-Location) 'BALANCE_BUILDS.md')
)

$ErrorActionPreference = 'Stop'
$Invariant = [Globalization.CultureInfo]::InvariantCulture
$script:ActiveTargetArmor = 0.0
$script:ActiveChaosMultiplier = 1.0

$StatNames = @(
    'health', 'mana', 'damage', 'armor', 'strength', 'agility',
    'intelligence', 'regeneration', 'mana_regeneration', 'damage_resist',
    'magic_resist', 'physical_dealt', 'magic_dealt', 'movespeed',
    'evasion', 'spellboost', 'crit_chance', 'crit_damage',
    'base_attack_speed', 'gold_find'
)

function Read-PreloadTsv([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Balance export not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    $matches = [regex]::Matches($raw, 'i\(\[\[(.*?)\]\]\)', 'Singleline')
    if ($matches.Count -eq 0) {
        throw "No FileIO payload chunks found in $Path"
    }

    $payload = ($matches | ForEach-Object { $_.Groups[1].Value }) -join ''
    return @($payload.TrimEnd("`r", "`n") | ConvertFrom-Csv -Delimiter "`t")
}

function Get-Number($Row, [string] $Name) {
    $value = $Row.$Name
    if ([string]::IsNullOrWhiteSpace($value)) { return 0.0 }
    return [double]::Parse($value, $Invariant)
}

function Get-HeroNumber($Row, [string] $Name) {
    return Get-Number $Row $Name
}

function Test-Proficiency($HeroRow, [int] $Type) {
    if ($Type -eq 0 -or $Type -eq 5) { return $true }
    if ($Type -lt 1 -or $Type -gt 10) { return $false }
    $mask = [int](Get-HeroNumber $HeroRow 'proficiency_mask')
    $required = 1 -shl ($Type - 1)
    return ($mask -band $required) -ne 0
}

function New-Candidate($Row, $HeroRow, [string] $Roll) {
    $type = [int](Get-Number $Row 'type')
    $proficient = Test-Proficiency $HeroRow $type
    $modifier = if ($proficient) { 1.0 } else { 0.75 }
    $stats = [double[]]::new($StatNames.Count)
    $suffix = if ($Roll -eq 'Average') { '_average' } else { '_perfect' }

    for ($index = 0; $index -lt $StatNames.Count; $index++) {
        $value = Get-Number $Row ($StatNames[$index] + $suffix)
        # ItemProfMod applies only to the first seven stat applicators.
        if (-not $proficient -and $index -le 6) { $value *= $modifier }
        $stats[$index] = $value
    }

    return [pscustomobject]@{
        Rawcode = $Row.rawcode
        Name = $Row.name.Trim()
        Type = $type
        Requirement = [int](Get-Number $Row 'requirement')
        Limit = [int](Get-Number $Row 'limit')
        Proficient = $proficient
        Stats = $stats
        BatFactor = 1.0 + $stats[18] * 0.01
        DamageTakenFactor = 1.0 - $stats[9] * 0.01
        MagicTakenFactor = 1.0 - $stats[10] * 0.01
        Ability1 = $Row.ability_1
        Ability2 = $Row.ability_2
    }
}

function Get-Metrics($HeroRow, [int] $Level, [double[]] $Stats,
        [double] $BatFactor, [double] $DamageTakenFactor,
        [double] $MagicTakenFactor) {
    $strength = (Get-HeroNumber $HeroRow 'base_strength') +
        (Get-HeroNumber $HeroRow 'strength_gain') * ($Level - 1) + $Stats[4]
    $agility = (Get-HeroNumber $HeroRow 'base_agility') +
        (Get-HeroNumber $HeroRow 'agility_gain') * ($Level - 1) + $Stats[5]
    $intelligence = (Get-HeroNumber $HeroRow 'base_intelligence') +
        (Get-HeroNumber $HeroRow 'intelligence_gain') * ($Level - 1) + $Stats[6]

    $main = switch ($HeroRow.main_attribute) {
        'str' { $strength }
        'agi' { $agility }
        'int' { $intelligence }
        default { 0.0 }
    }

    $critChance = (Get-HeroNumber $HeroRow 'base_crit_chance') + $Stats[16]
    $critDamage = (Get-HeroNumber $HeroRow 'base_crit_damage') + $Stats[17]
    $critMultiplier = 1.0 + [math]::Min(100.0, $critChance) * 0.01 * $critDamage * 0.01
    $attackSpeed = (1.0 / 1.8) * $BatFactor * (1.0 + [math]::Min(400.0, $agility) * 0.01)
    $physicalDealt = (Get-HeroNumber $HeroRow 'physical_dealt') * (1.0 + $Stats[11] * 0.01)
    $magicDealt = 1.0 + $Stats[12] * 0.01
    $targetArmorMultiplier = if ($script:ActiveTargetArmor -ge 0) {
        1.0 / (1.0 + 0.05 * $script:ActiveTargetArmor)
    } else {
        2.0 - [math]::Pow(0.94, -$script:ActiveTargetArmor)
    }
    $rawAttack = [math]::Max(1.0, $main + $Stats[2] + 1.0) * $critMultiplier *
        $attackSpeed * $physicalDealt
    $attack = $rawAttack * $targetArmorMultiplier * $script:ActiveChaosMultiplier

    # This is deliberately a transparent gear-throughput proxy. Exact spell
    # DPS remains hero/rotation specific and is supplied by combat recordings.
    $weightedAttributes = $StrengthWeight * $strength +
        $AgilityWeight * $agility + $IntelligenceWeight * $intelligence
    $rawSpell = [math]::Max(1.0, $weightedAttributes) *
        (1.0 + $Stats[15] * 0.01) * $magicDealt
    $spell = $rawSpell * $script:ActiveChaosMultiplier

    $health = [math]::Max(1.0, $Stats[0] + 25.0 * $strength)
    $armor = (Get-HeroNumber $HeroRow 'base_armor') + $Stats[3] + 0.03 * $agility
    $armorFactor = if ($armor -ge 0) { 1.0 + 0.05 * $armor } else { 1.0 / (2.0 - [math]::Pow(0.94, -$armor)) }
    $physicalTaken = (Get-HeroNumber $HeroRow 'physical_taken') *
        [math]::Max(0.001, $DamageTakenFactor)
    $magicalTaken = (Get-HeroNumber $HeroRow 'magical_taken') *
        [math]::Max(0.001, $MagicTakenFactor)
    $evasionFactor = 1.0 / [math]::Max(0.05, 1.0 - [math]::Min(95.0, $Stats[14]) * 0.01)
    $physicalEhp = $health * $armorFactor * $evasionFactor / [math]::Max(0.001, $physicalTaken)
    $magicalEhp = $health / [math]::Max(0.001, $magicalTaken)
    $durability = [math]::Sqrt($physicalEhp * $magicalEhp)

    return [pscustomobject]@{
        Strength = $strength
        Agility = $agility
        Intelligence = $intelligence
        RawAttack = $rawAttack
        RawSpell = $rawSpell
        Attack = $attack
        Spell = $spell
        Balanced = [math]::Sqrt($attack * $spell)
        PhysicalEhp = $physicalEhp
        MagicalEhp = $magicalEhp
        Durability = $durability
        CritChance = $critChance
        CritDamage = $critDamage
        Spellboost = $Stats[15]
        BatFactor = $BatFactor
    }
}

function Get-ObjectiveScore($Metrics, [string] $Name) {
    switch ($Name) {
        'Attack' { $Metrics.Attack }
        'Spell' { $Metrics.Spell }
        'Balanced' { $Metrics.Balanced }
        'Durability' { $Metrics.Durability }
    }
}

function Test-LimitConflict($State, $Candidate) {
    foreach ($item in $State.Items) {
        # Benchmark builds model obtainable equipment rather than allowing the
        # beam search to clone a unique object-data item into several slots.
        if ($item.Rawcode -eq $Candidate.Rawcode) { return $true }

        if ($Candidate.Limit -le 0) { continue }
        if ($item.Limit -ne $Candidate.Limit) { continue }
        if ($Candidate.Limit -ne 1) {
            return $true
        }
    }
    return $false
}

function Add-Candidate($State, $Candidate, $HeroRow, [int] $Level,
        [string] $ObjectiveName, [int] $NextIndex) {
    $stats = [double[]]::new($StatNames.Count)
    for ($index = 0; $index -lt $StatNames.Count; $index++) {
        $stats[$index] = $State.Stats[$index] + $Candidate.Stats[$index]
    }

    $bat = $State.BatFactor * $Candidate.BatFactor
    $damageTaken = $State.DamageTakenFactor * $Candidate.DamageTakenFactor
    $magicTaken = $State.MagicTakenFactor * $Candidate.MagicTakenFactor
    $metrics = Get-Metrics $HeroRow $Level $stats $bat $damageTaken $magicTaken

    return [pscustomobject]@{
        Stats = $stats
        BatFactor = $bat
        DamageTakenFactor = $damageTaken
        MagicTakenFactor = $magicTaken
        Items = @($State.Items) + $Candidate
        NextIndex = $NextIndex
        Metrics = $metrics
        Score = Get-ObjectiveScore $metrics $ObjectiveName
    }
}

function Find-Build($Candidates, $HeroRow, [int] $Level, [string] $ObjectiveName) {
    $emptyStats = [double[]]::new($StatNames.Count)
    $emptyMetrics = Get-Metrics $HeroRow $Level $emptyStats 1.0 1.0 1.0
    $empty = [pscustomobject]@{
        Stats = $emptyStats
        BatFactor = 1.0
        DamageTakenFactor = 1.0
        MagicTakenFactor = 1.0
        Items = @()
        NextIndex = 0
        Metrics = $emptyMetrics
        Score = Get-ObjectiveScore $emptyMetrics $ObjectiveName
    }

    # The individual ranking keeps the beam search tractable. A wide default
    # pool is retained because crit/BAT/resistance combinations are nonlinear.
    $ranked = foreach ($candidate in $Candidates) {
        $state = Add-Candidate $empty $candidate $HeroRow $Level $ObjectiveName 0
        [pscustomobject]@{ Candidate = $candidate; Score = $state.Score }
    }
    $pool = @($ranked | Sort-Object Score -Descending | Select-Object -First $CandidateLimit |
        ForEach-Object { $_.Candidate })

    $states = @($empty)
    for ($slot = 0; $slot -lt 6; $slot++) {
        $next = [Collections.Generic.List[object]]::new()
        foreach ($state in $states) {
            for ($index = $state.NextIndex; $index -lt $pool.Count; $index++) {
                $candidate = $pool[$index]
                if (-not (Test-LimitConflict $state $candidate)) {
                    $next.Add((Add-Candidate $state $candidate $HeroRow $Level $ObjectiveName $index))
                }
            }
        }
        $states = @($next | Sort-Object Score -Descending | Select-Object -First $BeamWidth)
        if ($states.Count -eq 0) { throw "No legal $ObjectiveName build remained at slot $($slot + 1)." }
    }

    return $states[0]
}

$itemPath = Join-Path $DataDirectory 'balance-items-player-1.pld'
$heroPath = Join-Path $DataDirectory 'balance-heroes-player-1.pld'
$itemRows = Read-PreloadTsv $itemPath
$heroRows = Read-PreloadTsv $heroPath

$selectedHeroes = if ($Hero.Count -eq 1 -and $Hero[0] -eq 'All') {
    $heroRows
} else {
    @($heroRows | Where-Object {
        $row = $_
        $Hero | Where-Object { $_ -eq $row.rawcode -or $_ -eq $row.name }
    })
}
if ($selectedHeroes.Count -eq 0) {
    throw "No hero matched: $($Hero -join ', ')"
}

$objectives = if ($Objective -eq 'All') {
    @('Attack', 'Spell', 'Balanced', 'Durability')
} else { @($Objective) }
$rolls = if ($Quality -eq 'Both') { @('Average', 'Perfect') } else { @($Quality) }

$lines = [Collections.Generic.List[string]]::new()
$lines.Add('# Generated balance builds')
$lines.Add('')
$lines.Add('Generated from the in-engine `balance-items-player-1.pld` and')
$lines.Add('`balance-heroes-player-1.pld` exports.')
$lines.Add('Every loadout has six equipped items, honors level and item-limit rules,')
$lines.Add('and applies the live 75% penalty to proficiency-sensitive stats when needed.')
$lines.Add('')
$lines.Add('Attack is a formula estimate using primary attribute, item damage, crit, BAT,')
$lines.Add('Agility attack speed, physical-dealt multipliers, and target armor. Spell is an explicitly')
$lines.Add("generic attribute-throughput proxy with weights STR=$StrengthWeight, AGI=$AgilityWeight, INT=$IntelligenceWeight;")
$lines.Add('it is not claimed as spell DPS. Item ability effects are listed but not scored.')
$lines.Add('Durability is the geometric mean of physical and magical EHP. Final rankings')
$lines.Add('must use in-engine combat recordings, especially for proc and summon items.')
$lines.Add('')

foreach ($heroRow in $selectedHeroes) {
    $lines.Add("## $($heroRow.name) ($($heroRow.rawcode))")
    $lines.Add('')
    foreach ($level in ($Levels | Sort-Object -Unique)) {
        $script:ActiveTargetArmor = if ($TargetArmor -ge 0) { $TargetArmor } else { 0.75 * $level }
        $useChaos = switch ($TargetDefense) {
            'Chaos' { $true }
            'Normal' { $false }
            default { $level -ge 200 }
        }
        $script:ActiveChaosMultiplier = if ($useChaos) { 0.03 } else { 1.0 }
        $defenseLabel = if ($useChaos) { 'chaos' } else { 'normal' }
        $lines.Add("### Level $level")
        $lines.Add('')
        $lines.Add(('Target profile: `{0:N1}` armor, `{1}` defense.' -f
            $script:ActiveTargetArmor, $defenseLabel))
        $lines.Add('')
        foreach ($roll in $rolls) {
            $availableRows = @($itemRows | Where-Object {
                $row = $_
                $type = [int](Get-Number $row 'type')
                $available = switch ($Acquisition) {
                    'Drop' { $row.drop_pool -eq '1' }
                    'Shop' { $row.shop_catalog -eq '1' }
                    default { $row.drop_pool -eq '1' -or $row.shop_catalog -eq '1' -or $row.runtime_definition -eq '1' }
                }
                $proficient = Test-Proficiency $heroRow $type
                $available -and $type -ge 0 -and $type -le 10 -and
                    [int](Get-Number $row 'requirement') -le $level -and
                    $row.name -ne 'Useless Item!' -and
                    (-not $RequireProficiency -or $proficient)
            })
            $candidates = @($availableRows | ForEach-Object { New-Candidate $_ $heroRow $roll })
            if ($candidates.Count -lt 1) { throw "No candidate items for $($heroRow.name), level $level, $roll." }

            foreach ($objectiveName in $objectives) {
                $build = Find-Build $candidates $heroRow $level $objectiveName
                $m = $build.Metrics
                $lines.Add("#### $objectiveName — $roll rolls")
                $lines.Add('')
                $lines.Add(('* Score: `{0:N2}`; Attack `{1:N2}`; Spell proxy `{2:N2}`; Physical EHP `{3:N0}`; Magical EHP `{4:N0}`.' -f
                    $build.Score, $m.Attack, $m.Spell, $m.PhysicalEhp, $m.MagicalEhp))
                $lines.Add(('* STR `{0:N0}`; AGI `{1:N0}`; INT `{2:N0}`; Spellboost `{3:N2}%`; Crit `{4:N2}%` / `{5:N2}%`; BAT factor `{6:N4}`.' -f
                    $m.Strength, $m.Agility, $m.Intelligence, $m.Spellboost,
                    $m.CritChance, $m.CritDamage, $m.BatFactor))
                $lines.Add('')
                $lines.Add('| Item | Rawcode | Proficiency | Abilities |')
                $lines.Add('|---|---:|---:|---|')
                foreach ($item in $build.Items) {
                    $proficiency = if ($item.Proficient) { '100%' } else { '75% stats' }
                    $abilities = @($item.Ability1, $item.Ability2) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    $lines.Add("| $($item.Name) | ``$($item.Rawcode)`` | $proficiency | $($abilities -join ', ') |")
                }
                $ids = ($build.Items | ForEach-Object { $_.Rawcode }) -join ' '
                $lines.Add('')
                $lines.Add("Dev command: ``-balance equip $($roll.ToLowerInvariant()) $ids``")
                $lines.Add('')
            }
        }
    }
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.File]::WriteAllLines($resolvedOutput, $lines, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $resolvedOutput"
