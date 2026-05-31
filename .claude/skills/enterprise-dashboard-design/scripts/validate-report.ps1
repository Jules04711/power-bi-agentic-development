<#
.SYNOPSIS
    Validate a PBIR report with the pbir CLI, plus quick structural checks.
.DESCRIPTION
    Wrapper around 'pbir validate' (the pbir CLI is installed under miniconda3 per
    CLAUDE.md). Adds the miniconda Scripts dir to PATH for this process if needed, then
    runs validation. Also reports page count and the JSON validity of page/visual files.
    Read-only.
.PARAMETER ReportPath
    Path to the .Report folder (e.g. "STLA_20-F_Model.Report" or a full path).
.PARAMETER MinicondaScripts
    Optional path to the miniconda Scripts dir (default C:\Users\golfc\miniconda3\Scripts).
.EXAMPLE
    .\validate-report.ps1 -ReportPath "STLA_20-F_Model.Report"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $ReportPath,
    [string] $MinicondaScripts = 'C:\Users\golfc\miniconda3\Scripts'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ReportPath)) { throw "Report path not found: $ReportPath" }

# Ensure pbir is reachable
$pbir = Get-Command pbir -ErrorAction SilentlyContinue
if (-not $pbir) {
    if (Test-Path $MinicondaScripts) {
        $env:PATH = "$MinicondaScripts;$env:PATH"
        $pbir = Get-Command pbir -ErrorAction SilentlyContinue
    }
}
if (-not $pbir) {
    Write-Warning "pbir CLI not found. Install: pip install pbir-cli (or uv tool install pbir-cli). Skipping CLI validation; running structural checks only."
} else {
    Write-Output "Running: pbir -q validate `"$ReportPath`""
    & pbir -q validate "$ReportPath"
    Write-Output "pbir exit code: $LASTEXITCODE"
}

# Structural checks
$pageJsons   = Get-ChildItem -Path $ReportPath -Recurse -Filter 'page.json'   -ErrorAction SilentlyContinue
$visualJsons = Get-ChildItem -Path $ReportPath -Recurse -Filter 'visual.json' -ErrorAction SilentlyContinue
Write-Output "Pages: $($pageJsons.Count); Visuals: $($visualJsons.Count)"

$badJson = 0
foreach ($f in @($pageJsons) + @($visualJsons)) {
    try {
        $null = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    } catch {
        Write-Warning "Invalid JSON: $($f.FullName)"
        $badJson++
    }
}
if ($badJson -eq 0) { Write-Output "All page/visual JSON parsed OK." }
else { Write-Output "$badJson file(s) failed JSON parse." }

if ($pageJsons.Count -gt 8) {
    Write-Warning "Report has $($pageJsons.Count) pages (> 8 is typically excessive)."
}
