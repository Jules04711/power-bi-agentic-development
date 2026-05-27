[CmdletBinding()]
param([Parameter(Mandatory = $true)][int]$Port)

$ErrorActionPreference = 'Stop'

$basePath = "$env:TEMP\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45"
Add-Type -Path "$basePath\Microsoft.AnalysisServices.Core.dll" | Out-Null
Add-Type -Path "$basePath\Microsoft.AnalysisServices.Tabular.dll" | Out-Null

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=localhost:$Port")
$model = $server.Databases[0].Model

# Region calculated table with deterministic sort order
$regionDax = @"
DATATABLE (
    "Region", STRING,
    "Sort",   INTEGER,
    {
        { "North America",         1 },
        { "Enlarged Europe",       2 },
        { "Middle East & Africa",  3 },
        { "South America",         4 },
        { "China India APAC",      5 },
        { "Maserati",              6 },
        { "Other",                 7 }
    }
)
"@

if (-not $model.Tables.Contains("Region")) {
    $tbl = New-Object Microsoft.AnalysisServices.Tabular.Table
    $tbl.Name = "Region"

    $part = New-Object Microsoft.AnalysisServices.Tabular.Partition
    $part.Name = "Region"
    $src = New-Object Microsoft.AnalysisServices.Tabular.CalculatedPartitionSource
    $src.Expression = $regionDax
    $part.Source = $src
    $tbl.Partitions.Add($part)

    $cName = New-Object Microsoft.AnalysisServices.Tabular.CalculatedTableColumn
    $cName.Name = "Region"
    $cName.SourceColumn = "[Region]"
    $cName.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::String
    $tbl.Columns.Add($cName)

    $cSort = New-Object Microsoft.AnalysisServices.Tabular.CalculatedTableColumn
    $cSort.Name = "Sort"
    $cSort.SourceColumn = "[Sort]"
    $cSort.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::Int64
    $cSort.IsHidden = $true
    $tbl.Columns.Add($cSort)

    $model.Tables.Add($tbl)
    Write-Output "Created Region table"
} else {
    Write-Output "Region table already exists"
}

# SortByColumn after Add (Power BI requires the columns to be on the table)
$model.SaveChanges() | Out-Null
$regionTbl = $model.Tables["Region"]
if ($regionTbl.Columns["Region"].SortByColumn -eq $null) {
    $regionTbl.Columns["Region"].SortByColumn = $regionTbl.Columns["Sort"]
    $model.SaveChanges() | Out-Null
    Write-Output "Set SortByColumn on Region[Region]"
}

# Dynamic measures on Region table (so Region[Region] drives them)
$aoiTbl = $model.Tables["AOI_FY2025"]

$measures = @(
    @{ Name = 'Region AOI'; Format = '#,0;(#,0);' + [char]0x2014; Folder = '0. Dynamic by Region'; Desc = 'AOI for the selected region (use with Region[Region]).'; Expr = @"
VAR _r = SELECTEDVALUE ( 'Region'[Region], "STELLANTIS" )
RETURN
    SWITCH (
        TRUE (),
        _r = "North America",        [AOI - North America],
        _r = "Enlarged Europe",      [AOI - Enlarged Europe],
        _r = "Middle East & Africa", [AOI - Middle East & Africa],
        _r = "South America",        [AOI - South America],
        _r = "China India APAC",     [AOI - China India APAC],
        _r = "Maserati",             [AOI - Maserati],
        _r = "Other",                [AOI - Other],
        [Adjusted Operating Income]
    )
"@ },
    @{ Name = 'Region Net Revenues'; Format = '#,0;(#,0);' + [char]0x2014; Folder = '0. Dynamic by Region'; Desc = 'Net revenues for the selected region.'; Expr = @"
VAR _r = SELECTEDVALUE ( 'Region'[Region], "STELLANTIS" )
RETURN
    SWITCH (
        TRUE (),
        _r = "North America",        [Net Revenues - North America],
        _r = "Enlarged Europe",      [Net Revenues - Enlarged Europe],
        _r = "Middle East & Africa", [Net Revenues - Middle East & Africa],
        _r = "South America",        [Net Revenues - South America],
        _r = "China India APAC",     [Net Revenues - China India APAC],
        _r = "Maserati",             [Net Revenues - Maserati],
        _r = "Other",                [Net Revenues - Other],
        [Net Revenues]
    )
"@ },
    @{ Name = 'Region AOI Margin %'; Format = '0.0%;(0.0%);' + [char]0x2014; Folder = '0. Dynamic by Region'; Desc = 'AOI margin for the selected region.'; Expr = "DIVIDE ( [Region AOI], [Region Net Revenues] )" },
    @{ Name = 'Region Pro-Forma AOI'; Format = '#,0;(#,0);' + [char]0x2014; Folder = '0. Dynamic by Region'; Desc = 'Region AOI plus its pro-rata share of the 6B VCP save.'; Expr = @"
VAR _r = SELECTEDVALUE ( 'Region'[Region], "STELLANTIS" )
RETURN
    SWITCH (
        TRUE (),
        _r = "North America",        [Pro-Forma AOI - North America],
        _r = "Enlarged Europe",      [Pro-Forma AOI - Enlarged Europe],
        _r = "Middle East & Africa", [Pro-Forma AOI - Middle East & Africa],
        _r = "South America",        [Pro-Forma AOI - South America],
        _r = "China India APAC",     [Pro-Forma AOI - China India APAC],
        _r = "Maserati",             [Pro-Forma AOI - Maserati],
        _r = "Other",                [Pro-Forma AOI - Other],
        [AOI After VCP Save (FY2025 Pro-Forma)]
    )
"@ },
    @{ Name = 'Region VCP Save Allocation'; Format = '#,0;(#,0);' + [char]0x2014; Folder = '0. Dynamic by Region'; Desc = 'Pro-rata share of the 6B VCP save allocated to the selected region.'; Expr = @"
VAR _r = SELECTEDVALUE ( 'Region'[Region], "STELLANTIS" )
RETURN
    SWITCH (
        TRUE (),
        _r = "North America",        [VCP Save Allocation - North America],
        _r = "Enlarged Europe",      [VCP Save Allocation - Enlarged Europe],
        _r = "Middle East & Africa", [VCP Save Allocation - Middle East & Africa],
        _r = "South America",        [VCP Save Allocation - South America],
        _r = "China India APAC",     [VCP Save Allocation - China India APAC],
        _r = "Maserati",             [VCP Save Allocation - Maserati],
        _r = "Other",                [VCP Save Allocation - Other],
        [VCP Cost Save Target 2028]
    )
"@ }
)

$existing = @{}; foreach ($m in $aoiTbl.Measures) { $existing[$m.Name] = $m }
$created = 0; $updated = 0
foreach ($def in $measures) {
    if ($existing.ContainsKey($def.Name)) {
        $m = $existing[$def.Name]
        $m.Expression = $def.Expr; $m.FormatString = $def.Format; $m.DisplayFolder = $def.Folder; $m.Description = $def.Desc
        $updated++
    } else {
        $m = New-Object Microsoft.AnalysisServices.Tabular.Measure
        $m.Name = $def.Name; $m.Expression = $def.Expr; $m.FormatString = $def.Format; $m.DisplayFolder = $def.Folder; $m.Description = $def.Desc
        $aoiTbl.Measures.Add($m)
        $created++
    }
}

# Also add an adjustment-bridge "labeled" table for the waterfall: easier to add a calculated table than rely on 11 separate measures
if (-not $model.Tables.Contains("AdjustmentBridge")) {
    $bridge = New-Object Microsoft.AnalysisServices.Tabular.Table
    $bridge.Name = "AdjustmentBridge"
    $bp = New-Object Microsoft.AnalysisServices.Tabular.Partition
    $bp.Name = "AdjustmentBridge"
    $bsrc = New-Object Microsoft.AnalysisServices.Tabular.CalculatedPartitionSource
    $bsrc.Expression = @"
DATATABLE (
    "Adjustment", STRING,
    "Sort",       INTEGER,
    "Category",   STRING,
    {
        { "Product Plan Realignment",     1, "Strategic Reset"   },
        { "Platform Impairments",          2, "Strategic Reset"   },
        { "Warranty Estimate Change",      3, "Operational"       },
        { "Battery JV Charges",            4, "Non-Recurring"     },
        { "Hydrogen Fuel Cell Exit",       5, "Non-Recurring"     },
        { "Restructuring & Other",         6, "Operational"       },
        { "Takata Recall",                 7, "Non-Recurring"     },
        { "CAFE Penalty",                  8, "Non-Recurring"     },
        { "Other Impairments",             9, "Strategic Reset"   },
        { "Turkiye Disposal",             10, "Non-Recurring"     },
        { "Other Adjustments",            11, "Operational"       }
    }
)
"@
    $bp.Source = $bsrc; $bridge.Partitions.Add($bp)
    foreach ($c in @(@("Adjustment","[Adjustment]","String"), @("Sort","[Sort]","Int64"), @("Category","[Category]","String"))) {
        $col = New-Object Microsoft.AnalysisServices.Tabular.CalculatedTableColumn
        $col.Name = $c[0]; $col.SourceColumn = $c[1]; $col.DataType = [Microsoft.AnalysisServices.Tabular.DataType]$c[2]
        $bridge.Columns.Add($col)
    }
    $model.Tables.Add($bridge)
    Write-Output "Created AdjustmentBridge table"
}

$model.SaveChanges() | Out-Null

# Now add dynamic adjustment-bridge value measure on AOI_FY2025
if (-not $aoiTbl.Measures.Contains("Adjustment Value")) {
    $m = New-Object Microsoft.AnalysisServices.Tabular.Measure
    $m.Name = "Adjustment Value"
    $m.FormatString = '#,0;(#,0);' + [char]0x2014
    $m.DisplayFolder = '0. Dynamic by Region'
    $m.Description = "Value of the adjustment selected in AdjustmentBridge[Adjustment]."
    $m.Expression = @"
VAR _a = SELECTEDVALUE ( 'AdjustmentBridge'[Adjustment], "TOTAL" )
RETURN
    SWITCH (
        TRUE (),
        _a = "Product Plan Realignment",   [Product Plan Realignment & Cancellations],
        _a = "Platform Impairments",       [Platform Impairments],
        _a = "Warranty Estimate Change",   [Warranty Estimate Change],
        _a = "Battery JV Charges",         [Battery JV Charges],
        _a = "Hydrogen Fuel Cell Exit",    [Hydrogen Fuel Cell Discontinuation],
        _a = "Restructuring & Other",      [Restructuring & Other Costs],
        _a = "Takata Recall",              [Takata Airbags Recall],
        _a = "CAFE Penalty",               [CAFE Penalty Rate Charge],
        _a = "Other Impairments",          [Other Impairments],
        _a = "Turkiye Disposal",           [Stellantis Turkiye Disposal],
        _a = "Other Adjustments",          [Other Adjustments],
        [Total Adjustments]
    )
"@
    $aoiTbl.Measures.Add($m)
    Write-Output "Created Adjustment Value measure"
}

# Sort the Adjustment column by Sort
$bridgeTbl = $model.Tables["AdjustmentBridge"]
if ($bridgeTbl.Columns["Adjustment"].SortByColumn -eq $null) {
    $bridgeTbl.Columns["Adjustment"].SortByColumn = $bridgeTbl.Columns["Sort"]
    $bridgeTbl.Columns["Sort"].IsHidden = $true
}

$model.SaveChanges() | Out-Null
Write-Output "Created: $created   Updated: $updated"
Write-Output "DONE"
$server.Disconnect()
