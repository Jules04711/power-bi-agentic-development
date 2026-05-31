<#
.SYNOPSIS
    Create or update measures from a JSON spec via TOM (in-memory), with format string,
    display folder, and description, then trigger a calculate refresh.
.DESCRIPTION
    Mirrors the project's add-aoi-measures.ps1 pattern. TOM SaveChanges() is IN-MEMORY
    ONLY (CLAUDE.md): to persist to disk, Ctrl+S in PBI Desktop or serialize while closed.
    Always test created measures afterward with test-dax.ps1.
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER SpecPath
    Path to a JSON file: an array of objects with fields:
      table, name, expression, formatString (opt), displayFolder (opt),
      description (opt), isHidden (opt).
.PARAMETER NoRefresh
    Skip the calculate refresh (use when only measures changed and no calc tables exist).
.EXAMPLE
    .\add-measures-from-spec.ps1 -Port 51234 -SpecPath .\measures.json
.NOTES
    Example spec:
    [ { "table": "Sales", "name": "Margin %",
        "expression": "DIVIDE([Total Margin],[Total Revenue])",
        "formatString": "0.0%", "displayFolder": "Margin",
        "description": "Margin as a percent of revenue." } ]
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [Parameter(Mandatory = $true)] [string] $SpecPath,
    [switch] $NoRefresh
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SpecPath)) { throw "Spec file not found: $SpecPath" }

$tomDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
if (-not (Test-Path $tomDll)) { throw "TOM assembly not found at $tomDll." }
Add-Type -Path $tomDll

# Read spec as UTF-8 (avoid PS 5.1 round-trip corruption)
$specText = [System.IO.File]::ReadAllText($SpecPath, [System.Text.Encoding]::UTF8)
$spec = $specText | ConvertFrom-Json
if ($spec -isnot [System.Array]) { $spec = @($spec) }

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$Port")
try {
    $db = $server.Databases[0]
    $model = $db.Model
    $created = 0; $updated = 0

    foreach ($item in $spec) {
        if (-not $item.table -or -not $item.name -or -not $item.expression) {
            Write-Warning "Skipping spec entry missing table/name/expression: $($item | ConvertTo-Json -Compress)"
            continue
        }
        $tbl = $model.Tables[$item.table]
        if ($null -eq $tbl) { Write-Warning "Table '$($item.table)' not found; skipping [$($item.name)]."; continue }

        $m = $tbl.Measures.Find($item.name)
        if ($null -eq $m) {
            $m = New-Object Microsoft.AnalysisServices.Tabular.Measure
            $m.Name = $item.name
            $tbl.Measures.Add($m)
            $created++
        } else {
            $updated++
        }
        $m.Expression = $item.expression
        if ($item.PSObject.Properties.Name -contains 'formatString' -and $item.formatString) { $m.FormatString = $item.formatString }
        if ($item.PSObject.Properties.Name -contains 'displayFolder' -and $item.displayFolder) { $m.DisplayFolder = $item.displayFolder }
        if ($item.PSObject.Properties.Name -contains 'description' -and $item.description) { $m.Description = $item.description }
        if ($item.PSObject.Properties.Name -contains 'isHidden') { $m.IsHidden = [bool]$item.isHidden }
        Write-Output "Set measure '$($item.table)'[$($item.name)]"
    }

    $model.SaveChanges() | Out-Null
    Write-Output "SaveChanges complete (IN-MEMORY): $created created, $updated updated."

    if (-not $NoRefresh) {
        $refreshJson = '{ "refresh": { "type": "calculate", "objects": [ { "database": "' + $db.Name + '" } ] } }'
        $server.Execute($refreshJson) | Out-Null
        Write-Output "Calculate refresh issued."
    }

    Write-Output "PERSIST: Ctrl+S in PBI Desktop, or serialize TMDL while Desktop is CLOSED. Then re-test with test-dax.ps1."
}
finally {
    $server.Disconnect()
}
