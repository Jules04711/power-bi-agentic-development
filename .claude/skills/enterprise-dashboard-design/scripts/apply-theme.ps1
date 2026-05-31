<#
.SYNOPSIS
    Register a theme JSON into a PBIR report's registered resources (thick byPath report).
.DESCRIPTION
    Copies a theme JSON into the report's StaticResources\RegisteredResources folder and
    reports the report.json entry needed to reference it. PBI Desktop MUST be CLOSED while
    editing report files (CLAUDE.md). For the exact report.json theme-collection edit, use
    the modifying-theme-json plugin skill. Always finish with pbir validate.
.PARAMETER ReportPath
    Path to the .Report folder.
.PARAMETER ThemePath
    Path to the theme JSON (default: this skill's assets\enterprise-theme.json).
.EXAMPLE
    .\apply-theme.ps1 -ReportPath "STLA_20-F_Model.Report"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $ReportPath,
    [string] $ThemePath = (Join-Path $PSScriptRoot '..\assets\enterprise-theme.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ReportPath)) { throw "Report path not found: $ReportPath" }
if (-not (Test-Path $ThemePath))  { throw "Theme file not found: $ThemePath" }

# Guard: PBI Desktop must be closed
$pbid = Get-Process PBIDesktop -ErrorAction SilentlyContinue
if ($pbid) {
    throw "PBI Desktop is running. Close it before editing report files (CLAUDE.md), then re-run."
}

# Validate theme JSON
try {
    $null = [System.IO.File]::ReadAllText($ThemePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
} catch {
    throw "Theme JSON is invalid: $ThemePath"
}

$resDir = Join-Path $ReportPath 'StaticResources\RegisteredResources'
if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir -Force | Out-Null }

$themeName = [System.IO.Path]::GetFileName($ThemePath)
$dest = Join-Path $resDir $themeName
Copy-Item -Path $ThemePath -Destination $dest -Force
Write-Output "Copied theme to: $dest"

Write-Output ""
Write-Output "Next steps (use the modifying-theme-json skill for exact report.json structure):"
Write-Output "  1. Reference '$themeName' in the report's theme collection (report.json / definition)."
Write-Output "  2. Run validate-report.ps1 -ReportPath `"$ReportPath`"."
Write-Output "  3. Reopen PBI Desktop to confirm the theme applied."
