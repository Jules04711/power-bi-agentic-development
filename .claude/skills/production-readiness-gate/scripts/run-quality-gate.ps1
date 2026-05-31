<#
.SYNOPSIS
    Consolidated enterprise production-readiness quality gate for a Power BI solution.
.DESCRIPTION
    Runs the sibling skills' validators and aggregates a single PASS/FAIL verdict:
      1. Model shape          (semantic-model-architect/validate-model-shape.ps1)
      2. Relationships + RLS   (relationship-and-model-integrity/validate-relationships.ps1)
      3. DAX smoke test        (dax-measure-engineering/test-dax.ps1)
      4. Report validation     (enterprise-dashboard-design/validate-report.ps1)
    Any CRITICAL finding => FAIL. Read-only. BPA is recommended separately (see bpa-gate.md);
    this script notes it as a manual gate item.
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER ReportPath
    Path to the .Report folder (optional; skips report check if omitted).
.PARAMETER SmokeDax
    A DAX EVALUATE to smoke-test (optional; skips DAX check if omitted).
.PARAMETER Json
    Emit the aggregated result as JSON.
.EXAMPLE
    .\run-quality-gate.ps1 -Port 51234 -ReportPath "STLA_20-F_Model.Report" -SmokeDax 'EVALUATE ROW("AOI",[Adjusted Operating Income])'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [string] $ReportPath,
    [string] $SmokeDax,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$skillsRoot = Join-Path $PSScriptRoot '..\..'   # .claude\skills

$modelShape = Join-Path $skillsRoot 'semantic-model-architect\scripts\validate-model-shape.ps1'
$relCheck   = Join-Path $skillsRoot 'relationship-and-model-integrity\scripts\validate-relationships.ps1'
$daxTest    = Join-Path $skillsRoot 'dax-measure-engineering\scripts\test-dax.ps1'
$reportVal  = Join-Path $skillsRoot 'enterprise-dashboard-design\scripts\validate-report.ps1'

$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$Check, [string]$Status, [string]$Detail) {
    $results.Add([pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail })
}

$criticalTotal = 0
$warnTotal = 0

# 1. Model shape
if (Test-Path $modelShape) {
    try {
        $json = & $modelShape -Port $Port -Json | Out-String
        $findings = $json | ConvertFrom-Json
        $c = @($findings | Where-Object Severity -eq 'CRITICAL').Count
        $w = @($findings | Where-Object Severity -eq 'WARN').Count
        $criticalTotal += $c; $warnTotal += $w
        Add-Result 'ModelShape' (if ($c -gt 0) { 'FAIL' } else { 'PASS' }) "$c CRITICAL, $w WARN"
        foreach ($f in ($findings | Where-Object Severity -in 'CRITICAL','WARN')) {
            Add-Result "  ModelShape:$($f.Severity)" $f.Check $f.Detail
        }
    } catch { Add-Result 'ModelShape' 'ERROR' $_.Exception.Message; $criticalTotal++ }
} else { Add-Result 'ModelShape' 'SKIP' "Script not found: $modelShape" }

# 2. Relationships + RLS
if (Test-Path $relCheck) {
    try {
        $json = & $relCheck -Port $Port -Json | Out-String
        $findings = $json | ConvertFrom-Json
        $c = @($findings | Where-Object Severity -eq 'CRITICAL').Count
        $w = @($findings | Where-Object Severity -eq 'WARN').Count
        $criticalTotal += $c; $warnTotal += $w
        Add-Result 'Relationships' (if ($c -gt 0) { 'FAIL' } else { 'PASS' }) "$c CRITICAL, $w WARN"
        foreach ($f in ($findings | Where-Object Severity -in 'CRITICAL','WARN')) {
            Add-Result "  Rel:$($f.Severity)" $f.Check $f.Detail
        }
    } catch { Add-Result 'Relationships' 'ERROR' $_.Exception.Message; $criticalTotal++ }
} else { Add-Result 'Relationships' 'SKIP' "Script not found: $relCheck" }

# 3. DAX smoke test
if ($SmokeDax) {
    if (Test-Path $daxTest) {
        try {
            $out = & $daxTest -Port $Port -Dax $SmokeDax 2>&1 | Out-String
            if ($LASTEXITCODE -in 0, $null) {
                Add-Result 'DAXSmoke' 'PASS' ($out.Trim() -replace '\s+', ' ')
            } else {
                Add-Result 'DAXSmoke' 'FAIL' ($out.Trim() -replace '\s+', ' '); $criticalTotal++
            }
        } catch { Add-Result 'DAXSmoke' 'ERROR' $_.Exception.Message; $criticalTotal++ }
    } else { Add-Result 'DAXSmoke' 'SKIP' "Script not found: $daxTest" }
} else { Add-Result 'DAXSmoke' 'SKIP' "No -SmokeDax supplied" }

# 4. Report validation
if ($ReportPath) {
    if (Test-Path $reportVal) {
        try {
            $out = & $reportVal -ReportPath $ReportPath 2>&1 | Out-String
            $status = if ($out -match '(?i)invalid|error') { 'WARN' } else { 'PASS' }
            if ($status -eq 'WARN') { $warnTotal++ }
            Add-Result 'Report' $status ($out.Trim() -replace '\s+', ' ')
        } catch { Add-Result 'Report' 'ERROR' $_.Exception.Message; $warnTotal++ }
    } else { Add-Result 'Report' 'SKIP' "Script not found: $reportVal" }
} else { Add-Result 'Report' 'SKIP' "No -ReportPath supplied" }

# 5. BPA reminder (manual / CI)
Add-Result 'BPA' 'MANUAL' "Run Tabular Editor BPA (see bpa-gate.md) - not executed by this script."

$verdict = if ($criticalTotal -gt 0) { 'FAIL' } else { 'PASS' }

if ($Json) {
    [pscustomobject]@{ Verdict = $verdict; Critical = $criticalTotal; Warn = $warnTotal; Results = $results } | ConvertTo-Json -Depth 5
} else {
    $results | Format-Table -AutoSize Check, Status, Detail | Out-String | Write-Output
    Write-Output "==================================================================="
    Write-Output "QUALITY GATE VERDICT: $verdict  ($criticalTotal CRITICAL, $warnTotal WARN)"
    Write-Output "PASS requires zero CRITICAL findings and recorded sign-off on each WARN."
    Write-Output "==================================================================="
}

if ($verdict -eq 'FAIL') { exit 1 }
