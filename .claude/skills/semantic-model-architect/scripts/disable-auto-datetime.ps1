<#
.SYNOPSIS
    Disable Auto Date/Time on a Power BI Desktop model via TOM (in-memory).
.DESCRIPTION
    Sets the model annotation __PBI_TimeIntelligenceEnabled = "0" and reports the
    auto-generated LocalDateTable_* / DateTableTemplate_* shadow tables that should be
    removed. Per CLAUDE.md, TOM SaveChanges() is IN-MEMORY ONLY: to persist, Ctrl+S in
    PBI Desktop, or serialize + copy the TMDL while PBI Desktop is CLOSED.

    Removing the shadow tables themselves and fully clearing the setting is most reliably
    done in Power BI Desktop UI (Options > Current File > Data Load > uncheck Auto date/time,
    then save) because the shadows are regenerated until the file is saved with the option off.
.PARAMETER Port
    The local Analysis Services port of the running PBI Desktop instance.
.PARAMETER WhatIf
    Report only; do not call SaveChanges().
.EXAMPLE
    .\disable-auto-datetime.ps1 -Port 51234
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

$tomDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
if (-not (Test-Path $tomDll)) {
    throw "TOM assembly not found at $tomDll. Reinstall: nuget install Microsoft.AnalysisServices.retail.amd64 -OutputDirectory `$env:TEMP\tom_nuget -ExcludeVersion"
}
Add-Type -Path $tomDll

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$Port")
try {
    $db = $server.Databases[0]
    $model = $db.Model

    $current = $null
    if ($model.Annotations.ContainsName('__PBI_TimeIntelligenceEnabled')) {
        $current = $model.Annotations['__PBI_TimeIntelligenceEnabled'].Value
    }
    Write-Output "Current __PBI_TimeIntelligenceEnabled = '$current'"

    $shadows = @($model.Tables | Where-Object { $_.Name -like 'LocalDateTable_*' -or $_.Name -like 'DateTableTemplate_*' })
    Write-Output "Shadow auto-date tables present: $($shadows.Count)"
    foreach ($t in $shadows) { Write-Output "  - $($t.Name)" }

    if ($WhatIf) {
        Write-Output "[WhatIf] Would set __PBI_TimeIntelligenceEnabled = '0' and SaveChanges()."
        return
    }

    if ($model.Annotations.ContainsName('__PBI_TimeIntelligenceEnabled')) {
        $model.Annotations['__PBI_TimeIntelligenceEnabled'].Value = '0'
    } else {
        $ann = New-Object Microsoft.AnalysisServices.Tabular.Annotation
        $ann.Name = '__PBI_TimeIntelligenceEnabled'
        $ann.Value = '0'
        $model.Annotations.Add($ann)
    }
    $model.SaveChanges() | Out-Null
    Write-Output "Set __PBI_TimeIntelligenceEnabled = '0' (in-memory)."
    Write-Output "PERSIST: In PBI Desktop, Options > Current File > Data Load > uncheck Auto date/time, then Save."
    Write-Output "The $($shadows.Count) shadow tables clear only after the file is saved with the option off."
}
finally {
    $server.Disconnect()
}
