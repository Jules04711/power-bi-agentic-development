<#
.SYNOPSIS
    Hygiene gate for a Power BI tabular model: checks dimensional shape, date table,
    keys, data types, formatting, and auto-date-time state via TOM (read-only).
.DESCRIPTION
    Connects to a running PBI Desktop AS instance and emits findings with severities
    (CRITICAL / WARN / INFO). Read-only: never calls SaveChanges(). Encodes the
    model-hygiene-checklist.md items that are machine-checkable.
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER Json
    Emit findings as JSON instead of text (for the quality gate).
.EXAMPLE
    .\validate-model-shape.ps1 -Port 51234
    .\validate-model-shape.ps1 -Port 51234 -Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

$tomDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
if (-not (Test-Path $tomDll)) {
    throw "TOM assembly not found at $tomDll. Reinstall the Microsoft.AnalysisServices.retail.amd64 NuGet package."
}
Add-Type -Path $tomDll

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$Severity, [string]$Check, [string]$Detail) {
    $findings.Add([pscustomobject]@{ Severity = $Severity; Check = $Check; Detail = $Detail })
}

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$Port")
try {
    $db = $server.Databases[0]
    $model = $db.Model

    # Compatibility level
    Add-Finding 'INFO' 'CompatibilityLevel' "Compatibility level $($db.CompatibilityLevel)$(if ($db.CompatibilityLevel -lt 1601) { ' (< 1601: DAX UDFs unavailable)' })"

    # Auto Date/Time
    $tiEnabled = $null
    if ($model.Annotations.ContainsName('__PBI_TimeIntelligenceEnabled')) {
        $tiEnabled = $model.Annotations['__PBI_TimeIntelligenceEnabled'].Value
    }
    $shadows = @($model.Tables | Where-Object { $_.Name -like 'LocalDateTable_*' -or $_.Name -like 'DateTableTemplate_*' })
    if ($tiEnabled -eq '1' -or $shadows.Count -gt 0) {
        Add-Finding 'CRITICAL' 'AutoDateTime' "Auto Date/Time appears ON ($($shadows.Count) shadow tables). Disable and use an explicit Date table."
    } else {
        Add-Finding 'INFO' 'AutoDateTime' 'Auto Date/Time disabled.'
    }

    # User (non-shadow) tables
    $userTables = @($model.Tables | Where-Object { $_.Name -notlike 'LocalDateTable_*' -and $_.Name -notlike 'DateTableTemplate_*' })

    # Marked date table
    $dateTables = @($userTables | Where-Object { $_.DataCategory -eq 'Time' })
    if ($dateTables.Count -eq 0) {
        Add-Finding 'CRITICAL' 'DateTable' 'No table marked as a date table (dataCategory = Time).'
    } elseif ($dateTables.Count -gt 1) {
        Add-Finding 'WARN' 'DateTable' "More than one marked date table: $($dateTables.Name -join ', ')."
    } else {
        Add-Finding 'INFO' 'DateTable' "Marked date table: $($dateTables[0].Name)."
    }

    # Measure distribution
    $measureCounts = $userTables | ForEach-Object { [pscustomobject]@{ Table = $_.Name; Count = $_.Measures.Count } } | Where-Object { $_.Count -gt 0 }
    $totalMeasures = ($measureCounts | Measure-Object -Property Count -Sum).Sum
    if ($measureCounts.Count -eq 1 -and $totalMeasures -gt 20) {
        Add-Finding 'WARN' 'MeasureDistribution' "All $totalMeasures measures live on a single table ($($measureCounts[0].Table)). Distribute by subject or use a dedicated measures table."
    } else {
        Add-Finding 'INFO' 'MeasureDistribution' "$totalMeasures measures across $($measureCounts.Count) table(s)."
    }

    # Columns: data types, format strings, summarizeBy, wide tables, string-numeric smell
    foreach ($t in $userTables) {
        $dataCols = @($t.Columns | Where-Object { $_.Type -ne [Microsoft.AnalysisServices.Tabular.ColumnType]::RowNumber })
        if ($dataCols.Count -gt 30) {
            Add-Finding 'WARN' 'WideTable' "Table '$($t.Name)' has $($dataCols.Count) columns (> 30: denormalization smell)."
        }
        foreach ($c in $dataCols) {
            if ($c.DataType -eq [Microsoft.AnalysisServices.Tabular.DataType]::Unknown) {
                Add-Finding 'CRITICAL' 'DataType' "Column '$($t.Name)'[$($c.Name)] has no data type."
            }
            if ($c.DataType -eq [Microsoft.AnalysisServices.Tabular.DataType]::Double -and $c.Name -match '(?i)amount|price|cost|revenue|sales|currency|usd|eur') {
                Add-Finding 'WARN' 'CurrencyAsDouble' "Column '$($t.Name)'[$($c.Name)] looks like currency but is Double; use Decimal/Currency."
            }
            if ($c.DataType -eq [Microsoft.AnalysisServices.Tabular.DataType]::String -and $c.Name -match '(?i)amount|revenue|income|total|qty|quantity|count|value') {
                Add-Finding 'WARN' 'NumericAsString' "Column '$($t.Name)'[$($c.Name)] looks numeric but is String; convert in Power Query."
            }
            $isKey = $c.IsKey -or ($c.Name -match '(?i)(^id$|key$|id$)')
            if ($isKey -and $c.SummarizeBy -ne [Microsoft.AnalysisServices.Tabular.AggregateFunction]::None) {
                Add-Finding 'WARN' 'KeySummarizeBy' "Key-like column '$($t.Name)'[$($c.Name)] has summarizeBy = $($c.SummarizeBy); set to None."
            }
        }
    }

    # Measures: format strings + display folders + descriptions
    foreach ($t in $userTables) {
        foreach ($m in $t.Measures) {
            if ([string]::IsNullOrWhiteSpace($m.FormatString)) {
                Add-Finding 'WARN' 'MeasureFormat' "Measure [$($m.Name)] has no format string."
            }
            if ([string]::IsNullOrWhiteSpace($m.DisplayFolder)) {
                Add-Finding 'INFO' 'MeasureFolder' "Measure [$($m.Name)] has no display folder."
            }
        }
    }

    # Orphaned tables (no relationship, not disconnected-by-design heuristic)
    $related = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $model.Relationships) {
        [void]$related.Add($r.FromTable.Name); [void]$related.Add($r.ToTable.Name)
    }
    foreach ($t in $userTables) {
        if (-not $related.Contains($t.Name) -and $t.DataCategory -ne 'Time') {
            Add-Finding 'INFO' 'Disconnected' "Table '$($t.Name)' participates in no relationship (orphaned or intentional disconnected dim)."
        }
    }
}
finally {
    $server.Disconnect()
}

if ($Json) {
    $findings | ConvertTo-Json -Depth 4
} else {
    $order = @{ CRITICAL = 0; WARN = 1; INFO = 2 }
    $findings | Sort-Object { $order[$_.Severity] }, Check | Format-Table -AutoSize Severity, Check, Detail | Out-String | Write-Output
    $c = ($findings | Where-Object Severity -eq 'CRITICAL').Count
    $w = ($findings | Where-Object Severity -eq 'WARN').Count
    Write-Output "Summary: $c CRITICAL, $w WARN, $($findings.Count) total findings."
}
