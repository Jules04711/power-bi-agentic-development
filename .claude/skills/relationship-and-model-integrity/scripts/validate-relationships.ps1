<#
.SYNOPSIS
    Validate relationship integrity and RLS posture of a PBI Desktop model via TOM (read-only).
.DESCRIPTION
    Flags many-to-many, bidirectional cross-filter, inactive relationships not used by
    USERELATIONSHIP, orphaned/disconnected tables, auto-date LocalDateTable relationships,
    and zero-RLS posture. Read-only: never calls SaveChanges().
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER Json
    Emit findings as JSON (for the quality gate).
.EXAMPLE
    .\validate-relationships.ps1 -Port 51234
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

$tomDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
if (-not (Test-Path $tomDll)) { throw "TOM assembly not found at $tomDll." }
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

    $both = [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::BothDirections
    $many = [Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::Many

    # Gather all measure expressions to check USERELATIONSHIP usage
    $allDax = ($model.Tables | ForEach-Object { $_.Measures } | ForEach-Object { $_.Expression }) -join "`n"

    $userRels = @()
    foreach ($r in $model.Relationships) {
        $isAuto = ($r.FromTable.Name -like 'LocalDateTable_*' -or $r.ToTable.Name -like 'LocalDateTable_*' -or
                   $r.FromTable.Name -like 'DateTableTemplate_*' -or $r.ToTable.Name -like 'DateTableTemplate_*')
        $label = "$($r.FromTable.Name)[$($r.FromColumn.Name)] -> $($r.ToTable.Name)[$($r.ToColumn.Name)]"

        if ($isAuto) {
            Add-Finding 'INFO' 'AutoDateRelationship' "Auto Date/Time relationship: $label (artifact; fix via semantic-model-architect)."
            continue
        }
        $userRels += $r

        if ($r.FromCardinality -eq $many -and $r.ToCardinality -eq $many) {
            Add-Finding 'WARN' 'ManyToMany' "Native many-to-many: $label. Prefer a bridge table."
        }
        if ($r.CrossFilteringBehavior -eq $both) {
            Add-Finding 'WARN' 'Bidirectional' "Bidirectional cross-filter: $label. Justify or switch to single direction."
        }
        if (-not $r.IsActive) {
            $fromCol = $r.FromColumn.Name
            if ($allDax -notmatch [regex]::Escape($fromCol)) {
                Add-Finding 'WARN' 'UnusedInactive' "Inactive relationship $label has no apparent USERELATIONSHIP reference."
            } else {
                Add-Finding 'INFO' 'InactiveUsed' "Inactive relationship $label (referenced in DAX)."
            }
        }
    }

    Add-Finding 'INFO' 'RelationshipCount' "$($userRels.Count) user relationship(s), $($model.Relationships.Count) total (incl. auto-date)."

    # Disconnected / orphaned tables
    $related = New-Object System.Collections.Generic.HashSet[string]
    foreach ($r in $userRels) { [void]$related.Add($r.FromTable.Name); [void]$related.Add($r.ToTable.Name) }
    $userTables = @($model.Tables | Where-Object { $_.Name -notlike 'LocalDateTable_*' -and $_.Name -notlike 'DateTableTemplate_*' })
    foreach ($t in $userTables) {
        if (-not $related.Contains($t.Name)) {
            Add-Finding 'INFO' 'Disconnected' "Table '$($t.Name)' has no relationship (disconnected dim or orphan - confirm intent)."
        }
    }

    # RLS posture
    if ($model.Roles.Count -eq 0) {
        Add-Finding 'CRITICAL' 'NoRLS' "Zero RLS roles. Define at least a read role for downstream consumers (especially for financial data)."
    } else {
        foreach ($role in $model.Roles) {
            $perms = @($role.TablePermissions | Where-Object { -not [string]::IsNullOrWhiteSpace($_.FilterExpression) })
            Add-Finding 'INFO' 'Role' "Role '$($role.Name)': $($perms.Count) filtered table permission(s), permission = $($role.ModelPermission)."
            foreach ($p in $perms) {
                if ($p.FilterExpression -match '(?i)USERNAME\s*\(') {
                    Add-Finding 'WARN' 'RlsUsername' "Role '$($role.Name)' uses USERNAME(); prefer USERPRINCIPALNAME() for Service portability."
                }
            }
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
