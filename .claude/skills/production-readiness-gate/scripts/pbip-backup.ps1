<#
.SYNOPSIS
    Timestamped backup of the PBIP SemanticModel and Report folders.
.DESCRIPTION
    Copies the .SemanticModel and .Report folders into .claude\backups\<timestamp>\ per the
    CLAUDE.md backup pattern. Run before any risky model/report change. Restore by closing
    PBI Desktop, removing the live folders, and copying a backup back.
.PARAMETER ProjectRoot
    The STLA_Power_BI folder containing the .SemanticModel and .Report (default: auto-detect
    relative to this script, falling back to .\STLA_Power_BI).
.PARAMETER SemanticModelName
    Folder name of the semantic model (default STLA_20-F_Model.SemanticModel).
.PARAMETER ReportName
    Folder name of the report (default STLA_20-F_Model.Report).
.EXAMPLE
    .\pbip-backup.ps1
    .\pbip-backup.ps1 -ProjectRoot "C:\path\to\STLA_Power_BI"
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot,
    [string] $SemanticModelName = 'STLA_20-F_Model.SemanticModel',
    [string] $ReportName = 'STLA_20-F_Model.Report'
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectRoot) {
    # script is at <ws>\.claude\skills\production-readiness-gate\scripts; workspace is 4 up
    $ws = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
    $candidate = Join-Path $ws 'STLA_Power_BI'
    $ProjectRoot = if (Test-Path $candidate) { $candidate } else { (Resolve-Path '.\STLA_Power_BI').Path }
}
if (-not (Test-Path $ProjectRoot)) { throw "Project root not found: $ProjectRoot" }

$model  = Join-Path $ProjectRoot $SemanticModelName
$report = Join-Path $ProjectRoot $ReportName
if (-not (Test-Path $model))  { throw "Semantic model folder not found: $model" }
if (-not (Test-Path $report)) { throw "Report folder not found: $report" }

# Timestamp from the system clock (CLAUDE.md uses Get-Date); deterministic-safe in PS.
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $ProjectRoot ".claude\backups\$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Copy-Item -Path $model  -Destination $backupDir -Recurse -Force
Copy-Item -Path $report -Destination $backupDir -Recurse -Force

Write-Output "Backup created: $backupDir"
Write-Output "  - $SemanticModelName"
Write-Output "  - $ReportName"
Write-Output ""
Write-Output "Restore (close PBI Desktop first):"
Write-Output "  Get-Process PBIDesktop, msmdsrv -EA SilentlyContinue | Stop-Process -Force"
Write-Output "  Remove-Item `"$model`", `"$report`" -Recurse -Force"
Write-Output "  Copy-Item `"$backupDir\$SemanticModelName`" `"$ProjectRoot`" -Recurse"
Write-Output "  Copy-Item `"$backupDir\$ReportName`" `"$ProjectRoot`" -Recurse"
