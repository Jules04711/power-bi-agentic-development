<#
.SYNOPSIS
    Test Row-Level Security by running a DAX query in a role context via ADOMD.NET.
.DESCRIPTION
    Opens an ADOMD connection with Roles (and optionally EffectiveUserName for dynamic RLS)
    set, then evaluates a query so you can compare row counts / totals against the
    unrestricted result. Read-only. If no roles exist, reports that there is nothing to test.
.PARAMETER Port
    Local Analysis Services port of the running PBI Desktop instance.
.PARAMETER Role
    Role name to impersonate. Omit to list available roles.
.PARAMETER EffectiveUserName
    For dynamic RLS, the UPN/email to simulate (sets EffectiveUserName).
.PARAMETER Dax
    DAX query to run under the role. Default counts rows of all tables is not possible;
    supply a specific EVALUATE. Example: 'EVALUATE ROW("Rows", COUNTROWS(Sales))'
.EXAMPLE
    .\test-rls.ps1 -Port 51234                       # list roles
    .\test-rls.ps1 -Port 51234 -Role "East" -Dax 'EVALUATE ROW("Rows", COUNTROWS(Sales))'
    .\test-rls.ps1 -Port 51234 -Role "Dynamic" -EffectiveUserName "user@contoso.com" -Dax '...'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [int] $Port,
    [string] $Role,
    [string] $EffectiveUserName,
    [string] $Dax
)

$ErrorActionPreference = 'Stop'

$tomDll   = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll'
$adomdDll = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.AdomdClient.retail.amd64\lib\net45\Microsoft.AnalysisServices.AdomdClient.dll'
if (-not (Test-Path $tomDll))   { throw "TOM assembly not found at $tomDll." }
if (-not (Test-Path $adomdDll)) { throw "ADOMD.NET not found at $adomdDll." }
Add-Type -Path $tomDll

# List roles via TOM
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$Port")
$dbName = $null
try {
    $db = $server.Databases[0]
    $dbName = $db.Name
    $roles = @($db.Model.Roles | ForEach-Object { $_.Name })
    if ($roles.Count -eq 0) {
        Write-Output "No RLS roles defined in '$dbName'. Nothing to test. (This is a governance gap for shared/financial models.)"
        return
    }
    Write-Output "Roles in '$dbName': $($roles -join ', ')"
    if (-not $Role) { Write-Output "Pass -Role <name> (and -Dax) to test a specific role."; return }
    if ($roles -notcontains $Role) { throw "Role '$Role' not found. Available: $($roles -join ', ')" }
}
finally {
    $server.Disconnect()
}

if (-not $Dax) { Write-Output "Supply -Dax 'EVALUATE ...' to run under role '$Role'."; return }

Add-Type -Path $adomdDll
$connStr = "Data Source=localhost:$Port;Initial Catalog=$dbName;Roles=$Role"
if ($EffectiveUserName) { $connStr += ";EffectiveUserName=$EffectiveUserName" }

$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection
$conn.ConnectionString = $connStr
$conn.Open()
try {
    Write-Output "Connected with Roles=$Role$(if ($EffectiveUserName) { ", EffectiveUserName=$EffectiveUserName" })"
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Dax
    $reader = $cmd.ExecuteReader()
    $cols = @(); for ($i = 0; $i -lt $reader.FieldCount; $i++) { $cols += $reader.GetName($i) }
    $rows = New-Object System.Collections.Generic.List[object]
    while ($reader.Read()) {
        $o = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) { $o[$cols[$i]] = $reader.GetValue($i) }
        $rows.Add([pscustomobject]$o)
    }
    $reader.Close()
    $rows | Format-Table -AutoSize | Out-String | Write-Output
    Write-Output "Compare these values to the unrestricted result to confirm the role filters correctly."
}
finally {
    $conn.Close()
}
