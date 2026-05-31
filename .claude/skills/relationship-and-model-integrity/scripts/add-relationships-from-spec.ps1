<#
.SYNOPSIS
    Create relationships from a JSON spec via TOM (in-memory).
.DESCRIPTION
    Each spec entry creates a single-column relationship with the given cardinality,
    cross-filter direction, and active flag. Defaults are the safe defaults: many-to-one
    (fact -> dim) is expressed as fromCardinality=Many, toCardinality=One, single cross-filter.
    TOM SaveChanges() is IN-MEMORY ONLY (CLAUDE.md). Validate afterward with
    validate-relationships.ps1.
.PARAMETER Port
    Local Analysis Services port.
.PARAMETER SpecPath
    JSON array of: fromTable, fromColumn, toTable, toColumn,
      fromCardinality (Many|One, default Many), toCardinality (One|Many, default One),
      crossFilter (Single|Both, default Single), isActive (default true).
.EXAMPLE
    .\add-relationships-from-spec.ps1 -Port 51234 -SpecPath .\rels.json
.NOTES
    Example:
    [ { "fromTable": "Sales", "fromColumn": "Order Date",
        "toTable": "Date", "toColumn": "Date", "isActive": false } ]
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [Parameter(Mandatory = $true)] [string] $SpecPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $SpecPath)) { throw "Spec file not found: $SpecPath" }

$tomDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
if (-not (Test-Path $tomDll)) { throw "TOM assembly not found at $tomDll." }
Add-Type -Path $tomDll

$specText = [System.IO.File]::ReadAllText($SpecPath, [System.Text.Encoding]::UTF8)
$spec = $specText | ConvertFrom-Json
if ($spec -isnot [System.Array]) { $spec = @($spec) }

function ConvertTo-Cardinality([string]$v, $default) {
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    switch ($v.ToLower()) {
        'many' { [Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::Many }
        'one'  { [Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::One }
        default { throw "Invalid cardinality '$v' (use Many|One)." }
    }
}

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$Port")
try {
    $db = $server.Databases[0]
    $model = $db.Model
    $count = 0

    foreach ($s in $spec) {
        foreach ($req in 'fromTable','fromColumn','toTable','toColumn') {
            if (-not $s.$req) { throw "Spec entry missing '$req': $($s | ConvertTo-Json -Compress)" }
        }
        $ft = $model.Tables[$s.fromTable]; if (-not $ft) { throw "fromTable '$($s.fromTable)' not found." }
        $tt = $model.Tables[$s.toTable];   if (-not $tt) { throw "toTable '$($s.toTable)' not found." }
        $fc = $ft.Columns[$s.fromColumn]; if (-not $fc) { throw "fromColumn '$($s.fromColumn)' not found in '$($s.fromTable)'." }
        $tc = $tt.Columns[$s.toColumn];   if (-not $tc) { throw "toColumn '$($s.toColumn)' not found in '$($s.toTable)'." }

        $rel = New-Object Microsoft.AnalysisServices.Tabular.SingleColumnRelationship
        $rel.FromColumn = $fc
        $rel.ToColumn = $tc
        $rel.FromCardinality = ConvertTo-Cardinality $s.fromCardinality ([Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::Many)
        $rel.ToCardinality   = ConvertTo-Cardinality $s.toCardinality   ([Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::One)

        $cf = if ([string]::IsNullOrWhiteSpace($s.crossFilter)) { 'Single' } else { $s.crossFilter }
        $rel.CrossFilteringBehavior = if ($cf -ieq 'Both') {
            [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::BothDirections
        } else {
            [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::OneDirection
        }
        if ($s.PSObject.Properties.Name -contains 'isActive') { $rel.IsActive = [bool]$s.isActive }

        $model.Relationships.Add($rel)
        $count++
        Write-Output "Added: $($s.fromTable)[$($s.fromColumn)] -> $($s.toTable)[$($s.toColumn)] (active=$($rel.IsActive), cf=$cf)"
        if ($rel.CrossFilteringBehavior -eq [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::BothDirections) {
            Write-Warning "  Bidirectional relationship created - ensure this is justified (ambiguity/perf/RLS)."
        }
    }

    $model.SaveChanges() | Out-Null
    Write-Output "SaveChanges complete (IN-MEMORY): $count relationship(s). PERSIST per CLAUDE.md, then run validate-relationships.ps1."
}
finally {
    $server.Disconnect()
}
