function Get-Mineral($ext) {
    if ($minerals.ContainsKey($ext)) { return $minerals[$ext] }
    return $defaultMineral
}

function Get-FG($r, $g, $b) { "${ESC}[38;2;$r;$g;${b}m" }

function Get-FileData {
    
    $files = @()
    if ($depth -le 0) { return $files }

    try {
        $items = Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if ($item.Name -notmatch '^(\.git|node_modules|\.vs|bin|obj)$') {
                    $files += Get-FileData -dir $item.FullName -depth ($depth - 1)
                }
            } else {
                $ext = [System.IO.Path]::GetExtension($item.Name).ToLower()
                $files += @{
                    name = $item.Name
                    ext = $ext
                    size = $item.Length
                    created = $item.CreationTime
                    modified = $item.LastWriteTime
                    path = $item.FullName
                }
            }
        }
    } catch {}
    return $files
}

function Get-FossilAgeRank($dt) {
    $age = ((Get-Date) - $dt).TotalDays
    if ($age -lt 1)   { return 0 }  # Holocene
    if ($age -lt 7)   { return 1 }  # Pleistocene
    if ($age -lt 30)  { return 2 }  # Miocene
    if ($age -lt 90)  { return 3 }  # Oligocene
    if ($age -lt 365) { return 4 }  # Eocene
    return 5                        # Paleocene
}

$eraNames = @('Holocene', 'Pleistocene', 'Miocene', 'Oligocene', 'Eocene', 'Paleocene')
$eraColors = @(@(200,255,200), @(180,220,180), @(160,200,160), @(140,180,140), @(120,160,120), @(100,140,100))

Write-Host "${ESC}[?25l" -NoNewline
try {
    Write-Host $CLS -NoNewline

    # Scan
    Write-Host "`n  strata - reading the digital sediment..." -NoNewline
    $allFiles = Get-FileData -dir $Path -depth $Depth

    if ($allFiles.Count -eq 0) {
        Write-Host "`n  No files found in the sediment. Try shallower?"
        return
    }

    # Build strata layers
    $strata = @{}
    foreach ($f in $allFiles) {
        $ageRank = Get-FossilAgeRank $f.created
        $mineral = Get-Mineral $f.ext
        if (-not $strata.ContainsKey($ageRank)) { $strata[$ageRank] = @{} }
        if (-not $strata[$ageRank].ContainsKey($f.ext)) { $strata[$ageRank][$f.ext] = @{count=0; size=0; mineral=$mineral} }
        $strata[$ageRank][$f.ext].count++
        $strata[$ageRank][$f.ext].size += $f.size
    }

    # Render
    $maxCount = ($strata.Values | ForEach-Object { $_.Values | Measure-Object count -Sum }).Sum | Sort-Object -Descending | Select-Object -First 1
    $totalFiles = $allFiles.Count
    $totalSize = ($allFiles | Measure-Object size -Sum).Sum

    Write-Host $CLS -NoNewline
    Write-Host ""

    # Title
    $tfg = Get-FG 180 140 100
    Write-Host "${tfg}   ╔══════════════════════════════════════╗${RESET}"
    Write-Host "${tfg}   ║     STRATA : DIGITAL CORE SAMPLE     ║${RESET}"
    Write-Host "${tfg}   ╚══════════════════════════════════════╝${RESET}"
    Write-Host ""
    Write-Host "${tfg}   Site:  ${Path}${RESET}"
    Write-Host "${tfg}   Depth: ${Depth} levels  |  ${totalFiles} artifacts  |  $([Math]::Round($totalSize/1MB, 2))MB mass${RESET}"
    Write-Host ""

    # Draw column
    $colWidth = 50
    $hasData = $false
    for ($era = 5; $era -ge 0; $era--) {
        if (-not $strata.ContainsKey($era)) { continue }
        $hasData = $true
        $er, $eg, $eb = $eraColors[$era]
        $efg = Get-FG $er $eg $eb
        $eraTotal = ($strata[$era].Values | Measure-Object count -Sum).Sum
        $eraPct = [Math]::Round($eraTotal / $totalFiles * 100, 1)

        Write-Host "${efg}   ── ${eraNames[$era]} Layer ──  ${eraTotal} fossils (${eraPct}%)${RESET}"

        # Sort minerals by count descending
        $sortedMins = $strata[$era].GetEnumerator() | Sort-Object { $_.Value.count } -Descending

        foreach ($entry in $sortedMins) {
            $m = $entry.Value.mineral
            $mfg = Get-FG $m.r $m.g $m.b
            $barLen = [Math]::Max(1, [Math]::Min($colWidth, [Math]::Round($entry.Value.count / $maxCount * $colWidth)))
            $bar = $m.sym * $barLen

            Write-Host "   ${mfg}${bar}${RESET}  $($entry.Value.count)x ${m.name} (.$($entry.Key))"
        }
        Write-Host ""
    }

    if (-not $hasData) {
        Write-Host "${tfg}   No strata found. The sediment is undisturbed.${RESET}"
    }

    # Fossil map
    Write-Host "${tfg}   ╔══════════════════════════════════════╗${RESET}"
    Write-Host "${tfg}   ║       FOSSIL DISTRIBUTION MAP        ║${RESET}"
    Write-Host "${tfg}   ╚══════════════════════════════════════╝${RESET}"
    Write-Host ""

    $gridH = 20
    $gridW = 60

    if ($Animate) {
        for ($anim = 0; $anim -lt 30; $anim++) {
            Write-Host $CLS -NoNewline
            Write-Host "${tfg}   Strata Map (excavating...)${RESET}"
            Write-Host ""
            for ($y = 0; $y -lt $gridH; $y++) {
                $line = "   "
                $reveal = [Math]::Min($gridW, [Math]::Round($gridW * ($anim + $y) / ($gridH + 30)))
                for ($x = 0; $x -lt $gridW; $x++) {
                    if ($x -gt $reveal) { $line += "·"; continue }
                    $px = [Math]::Round($x / $gridW * ($allFiles.Count - 1))
                    $f = $allFiles[$px]
                    if (-not $f) { $line += "·"; continue }
                    $m = Get-Mineral $f.ext
                    $mfg = Get-FG $m.r $m.g $m.b
                    if ($f.size -gt 1MB) { $line += "${mfg}●${RESET}" }
                    elseif ($f.size -gt 100KB) { $line += "${mfg}◉${RESET}" }
                    elseif ($f.size -gt 1KB) { $line += "${mfg}·${RESET}" }
                    else { $line += "${mfg}·${RESET}" }
                }
                Write-Host $line
            }
            Start-Sleep -Milliseconds 80
        }
    } else {
        for ($y = 0; $y -lt $gridH; $y++) {
            $line = "   "
            for ($x = 0; $x -lt $gridW; $x++) {
                $px = [Math]::Round($x / $gridW * ($allFiles.Count - 1))
                $f = $allFiles[$px]
                if (-not $f) { $line += "·"; continue }
                $m = Get-Mineral $f.ext
                $mfg = Get-FG $m.r $m.g $m.b
                if ($f.size -gt 1MB) { $line += "${mfg}●${RESET}" }
                elseif ($f.size -gt 100KB) { $line += "${mfg}◉${RESET}" }
                elseif ($f.size -gt 1KB) { $line += "${mfg}·${RESET}" }
                else { $line += "${mfg}·${RESET}" }
            }
            Write-Host $line
        }
    }

    # Legend
    Write-Host ""
    Write-Host "${tfg}   Mineral Key:${RESET}"
    $legendMins = $minerals.GetEnumerator() | Sort-Object Name
    $i = 0
    foreach ($entry in $legendMins) {
        $m = $entry.Value
        $mfg = Get-FG $m.r $m.g $m.b
        Write-Host "   ${mfg}${m.sym}${RESET}  $($m.name)  (.$($entry.Key))" -NoNewline
        $i++
        if ($i % 3 -eq 0) { Write-Host "" }
        else { Write-Host "  " -NoNewline }
    }

    Write-Host ""
    Write-Host ""
    Write-Host "${tfg}   Core sample complete. ${totalFiles}
 artifacts catalogued.${RESET}"

} finally {
    Write-Host "${ESC}[?25h${RESET}"
}
