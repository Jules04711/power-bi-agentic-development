<#
.SYNOPSIS
    Execute DAX against a running PBI Desktop model via ADOMD.NET and return results.
.DESCRIPTION
    A test harness for verifying measures before commit. Supports EVALUATE and
    DEFINE MEASURE ... EVALUATE. Can assert an expected scalar value (non-zero exit
    on mismatch) for use in the production quality gate. Read-only against the engine.
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER Dax
    The DAX query text (an EVALUATE statement, optionally preceded by DEFINE).
.PARAMETER ExpectColumn
    Optional column name in the first result row to assert against.
.PARAMETER ExpectValue
    Optional expected numeric value for ExpectColumn.
.PARAMETER Tolerance
    Relative tolerance for the assertion (default 0.0001).
.EXAMPLE
    .\test-dax.ps1 -Port 51234 -Dax 'EVALUATE ROW("AOI", [Adjusted Operating Income])'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [Parameter(Mandatory = $true)] [string] $Dax,
    [string] $ExpectColumn,
    [double] $ExpectValue,
    [double] $Tolerance = 0.0001
)

$ErrorActionPreference = 'Stop'

$adomdDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.AdomdClient.retail.amd64\lib\net45\Microsoft.AnalysisServices.AdomdClient.dll'
if (-not (Test-Path $adomdDll)) {
    throw "ADOMD.NET not found at $adomdDll. Reinstall: nuget install Microsoft.AnalysisServices.AdomdClient.retail.amd64 -OutputDirectory `$env:TEMP\tom_nuget -ExcludeVersion"
}
Add-Type -Path $adomdDll

$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection
$conn.ConnectionString = "Data Source=localhost:$Port"
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Dax
    $reader = $cmd.ExecuteReader()

    $cols = @()
    for ($i = 0; $i -lt $reader.FieldCount; $i++) { $cols += $reader.GetName($i) }

    $rows = New-Object System.Collections.Generic.List[object]
    while ($reader.Read()) {
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $obj[$cols[$i]] = $reader.GetValue($i)
        }
        $rows.Add([pscustomobject]$obj)
    }
    $reader.Close()

    $rows | Format-Table -AutoSize | Out-String | Write-Output

    if ($PSBoundParameters.ContainsKey('ExpectColumn') -and $PSBoundParameters.ContainsKey('ExpectValue')) {
        if ($rows.Count -eq 0) { Write-Error "Assertion failed: query returned no rows."; exit 2 }
        $actual = $rows[0].$ExpectColumn
        if ($null -eq $actual) {
            # try without brackets / case-insensitive match
            $match = $cols | Where-Object { $_.Trim('[',']') -eq $ExpectColumn.Trim('[',']') } | Select-Object -First 1
            if ($match) { $actual = $rows[0].$match }
        }
        $actualD = [double]$actual
        $denom = [math]::Max([math]::Abs($ExpectValue), 1e-9)
        $relErr = [math]::Abs($actualD - $ExpectValue) / $denom
        if ($relErr -le $Tolerance) {
            Write-Output "ASSERT PASS: $ExpectColumn = $actualD (expected $ExpectValue, relErr $([math]::Round($relErr,6)))"
        } else {
            Write-Error "ASSERT FAIL: $ExpectColumn = $actualD (expected $ExpectValue, relErr $([math]::Round($relErr,6)))"
            exit 1
        }
    }
}
finally {
    $conn.Close()
}
