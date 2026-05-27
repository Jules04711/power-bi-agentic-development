[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$Port,
    [string]$Table = 'AOI_FY2025'
)

$ErrorActionPreference = 'Stop'

$basePath = "$env:TEMP\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45"
Add-Type -Path "$basePath\Microsoft.AnalysisServices.Core.dll" | Out-Null
Add-Type -Path "$basePath\Microsoft.AnalysisServices.Tabular.dll" | Out-Null

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=localhost:$Port")
$model = $server.Databases[0].Model
$tbl = $model.Tables[$Table]
if (-not $tbl) { throw "Table $Table not found" }

function _ParseExpr {
    param([string]$Column, [int]$Index)
@"
VAR _raw = CALCULATE ( SELECTEDVALUE ( 'AOI_FY2025'[$Column] ), ALL ( 'AOI_FY2025' ), 'AOI_FY2025'[Index] = $Index )
VAR _c1  = SUBSTITUTE ( _raw, ",", "" )
VAR _c2  = SUBSTITUTE ( _c1,  "(", "-" )
VAR _c3  = SUBSTITUTE ( _c2,  ")", "" )
VAR _c4  = SUBSTITUTE ( _c3,  "$([char]0x2014)", "" )
VAR _c5  = TRIM ( _c4 )
RETURN IF ( _c5 = "" || _c5 = "-", BLANK(), VALUE ( _c5 ) )
"@
}

$fmtMoney  = '#,0;(#,0);"$([char]0x2014)"'.Replace('"$([char]0x2014)"', '"' + [char]0x2014 + '"')
$fmtPct    = '0.0%;(0.0%);"$([char]0x2014)"'.Replace('"$([char]0x2014)"', '"' + [char]0x2014 + '"')

# Numeric format strings (Power BI accepts these for measure FormatString)
$fmtMoney = "#,0;(#,0);" + [char]0x2014
$fmtPct   = "0.0%;(0.0%);" + [char]0x2014

# Index mapping (from EVALUATE 'AOI_FY2025' ORDER BY Index)
# 1=NetRevExt, 3=NetRevTotal, 4=NetProfit, 7=OperatingIncome,
# 9=Restructuring, 10=Takata, 11=PlatformImpair, 12=ProductPlanRealign,
# 13=OtherImpair, 14=BatteryJV, 15=Hydrogen, 16=CAFE, 17=Turkiye,
# 18=Warranty, 19=OtherAdj, 20=TotalAdjustments, 21=AOI

$regions = @(
    @{ Col = 'NORTH AMERICA';                  Tag = 'North America'    },
    @{ Col = 'ENLARGED EUROPE';                Tag = 'Enlarged Europe'  },
    @{ Col = 'MIDDLE EAST & AFRICA';           Tag = 'Middle East & Africa' },
    @{ Col = 'SOUTH AMERICA';                  Tag = 'South America'    },
    @{ Col = 'CHINA AND INDIA & ASIA PACIFIC'; Tag = 'China India APAC' },
    @{ Col = 'MASERATI';                       Tag = 'Maserati'         },
    @{ Col = 'OTHER(*)';                       Tag = 'Other'            }
)

$measures = [System.Collections.Generic.List[object]]::new()

# ---------- 1. AOI Core (Stellantis-total) ----------
$measures.Add(@{ Name = 'Net Revenues'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'FY2025 consolidated net revenues (line 3), STELLANTIS column.'; Expr = (_ParseExpr 'STELLANTIS' 3) })
$measures.Add(@{ Name = 'Net Revenues from External Customers'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'FY2025 net revenues from external customers (line 1).'; Expr = (_ParseExpr 'STELLANTIS' 1) })
$measures.Add(@{ Name = 'Operating Income (Loss)'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'GAAP operating income/(loss) (line 7).'; Expr = (_ParseExpr 'STELLANTIS' 7) })
$measures.Add(@{ Name = 'Net Profit (Loss)'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'Reported net profit/(loss) (line 4).'; Expr = (_ParseExpr 'STELLANTIS' 4) })
$measures.Add(@{ Name = 'Tax Expense (Benefit)'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'Tax expense/(benefit) (line 5).'; Expr = (_ParseExpr 'STELLANTIS' 5) })
$measures.Add(@{ Name = 'Net Financial Expenses (Income)'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'Net financial expenses/(income) (line 6).'; Expr = (_ParseExpr 'STELLANTIS' 6) })
$measures.Add(@{ Name = 'Total Adjustments'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'Sum of all reconciling items between Operating Income and AOI (line 20).'; Expr = (_ParseExpr 'STELLANTIS' 20) })
$measures.Add(@{ Name = 'Adjusted Operating Income'; Folder = '1. AOI Core'; Format = $fmtMoney; Desc = 'AOI = Operating Income + Total Adjustments (line 21).'; Expr = (_ParseExpr 'STELLANTIS' 21) })
$measures.Add(@{ Name = 'AOI Margin %'; Folder = '1. AOI Core'; Format = $fmtPct; Desc = 'AOI divided by Net Revenues.'; Expr = "DIVIDE ( [Adjusted Operating Income], [Net Revenues] )" })
$measures.Add(@{ Name = 'Operating Margin %'; Folder = '1. AOI Core'; Format = $fmtPct; Desc = 'GAAP operating income margin.'; Expr = "DIVIDE ( [Operating Income (Loss)], [Net Revenues] )" })

# ---------- 2. AOI by Region ----------
foreach ($r in $regions) {
    $measures.Add(@{ Name = "AOI - $($r.Tag)"; Folder = '2. AOI by Region'; Format = $fmtMoney; Desc = "FY2025 Adjusted Operating Income for the $($r.Tag) segment."; Expr = (_ParseExpr $r.Col 21) })
}

# ---------- 3. Revenue by Region ----------
foreach ($r in $regions) {
    $measures.Add(@{ Name = "Net Revenues - $($r.Tag)"; Folder = '3. Revenue by Region'; Format = $fmtMoney; Desc = "FY2025 net revenues for the $($r.Tag) segment (line 3)."; Expr = (_ParseExpr $r.Col 3) })
}

# ---------- 4. Margin by Region ----------
foreach ($r in $regions) {
    $measures.Add(@{ Name = "AOI Margin % - $($r.Tag)"; Folder = '4. Margin by Region'; Format = $fmtPct; Desc = "AOI margin for the $($r.Tag) segment."; Expr = "DIVIDE ( [AOI - $($r.Tag)], [Net Revenues - $($r.Tag)] )" })
}

# ---------- 5. Adjustment Bridge (FY2025 one-time items) ----------
$measures.Add(@{ Name = 'Restructuring & Other Costs'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Restructuring and other costs, net of reversals (line 9, footnote A).'; Expr = (_ParseExpr 'STELLANTIS' 9) })
$measures.Add(@{ Name = 'Takata Airbags Recall'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Takata airbags recall campaign (line 10, footnote B).'; Expr = (_ParseExpr 'STELLANTIS' 10) })
$measures.Add(@{ Name = 'Platform Impairments'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Platform impairment charges (line 11, footnote C). Largest in NA: ~5.7B.'; Expr = (_ParseExpr 'STELLANTIS' 11) })
$measures.Add(@{ Name = 'Product Plan Realignment & Cancellations'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Costs related to product plan realignments and program cancellations (line 12, footnote D). Largest single adjustment in FY2025.'; Expr = (_ParseExpr 'STELLANTIS' 12) })
$measures.Add(@{ Name = 'Other Impairments'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Other impairment charges (line 13, footnote E).'; Expr = (_ParseExpr 'STELLANTIS' 13) })
$measures.Add(@{ Name = 'Battery JV Charges'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Battery joint venture related charges (line 14, footnote F).'; Expr = (_ParseExpr 'STELLANTIS' 14) })
$measures.Add(@{ Name = 'Hydrogen Fuel Cell Discontinuation'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Hydrogen fuel cell program discontinuation (line 15, footnote G).'; Expr = (_ParseExpr 'STELLANTIS' 15) })
$measures.Add(@{ Name = 'CAFE Penalty Rate Charge'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'CAFE penalty rate adjustment (line 16, footnote H).'; Expr = (_ParseExpr 'STELLANTIS' 16) })
$measures.Add(@{ Name = 'Stellantis Turkiye Disposal'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Stellantis Turkiye disposal (line 17, footnote I).'; Expr = (_ParseExpr 'STELLANTIS' 17) })
$measures.Add(@{ Name = 'Warranty Estimate Change'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Change in estimate for contractual warranties (line 18, footnote J).'; Expr = (_ParseExpr 'STELLANTIS' 18) })
$measures.Add(@{ Name = 'Other Adjustments'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Other reconciling items (line 19, footnote K).'; Expr = (_ParseExpr 'STELLANTIS' 19) })

# Bridge summary
$measures.Add(@{ Name = 'One-Time Charges - Non-Recurring'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Sum of charges considered largely non-recurring in 2026+ (Takata, hydrogen exit, Turkiye disposal, battery JV writedowns, CAFE).'; Expr = "[Takata Airbags Recall] + [Hydrogen Fuel Cell Discontinuation] + [Stellantis Turkiye Disposal] + [Battery JV Charges] + [CAFE Penalty Rate Charge]" })
$measures.Add(@{ Name = 'Strategic Realignment Charges'; Folder = '5. Adjustment Bridge'; Format = $fmtMoney; Desc = 'Sum of strategic-realignment charges tied to 2030 product/platform reset (platform impairments + product plan cancellations + other impairments).'; Expr = "[Platform Impairments] + [Product Plan Realignment & Cancellations] + [Other Impairments]" })

# ---------- 6. FaSTLAne 2030 Targets & Scenarios ----------
$measures.Add(@{ Name = 'VCP Cost Save Target 2028'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'Stellantis Value Creation Program: 6,000 EUR M annual cost run-rate by 2028 vs 2025 baseline (per FaSTLAne 2030 strategy, May 2026).'; Expr = "6000" })
$measures.Add(@{ Name = '2030 Revenue Target'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'Top-line ambition: 190,000 EUR M by 2030 (vs 153,508 in 2025).'; Expr = "190000" })
$measures.Add(@{ Name = '2030 AOI Margin Target %'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtPct; Desc = '7% AOI margin target by 2030.'; Expr = "0.07" })
$measures.Add(@{ Name = '2030 AOI Target'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = '7% of the 2030 revenue target = 13,300 EUR M.'; Expr = "[2030 Revenue Target] * [2030 AOI Margin Target %]" })
$measures.Add(@{ Name = 'AOI After VCP Save (FY2025 Pro-Forma)'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'Hypothetical: FY2025 AOI lifted by the full 6B VCP run-rate. Illustrative only - VCP achieves run-rate by 2028.'; Expr = "[Adjusted Operating Income] + [VCP Cost Save Target 2028]" })
$measures.Add(@{ Name = 'AOI Margin % After VCP Save'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtPct; Desc = 'Pro-forma AOI margin assuming full 6B VCP captured on FY2025 revenue base.'; Expr = "DIVIDE ( [AOI After VCP Save (FY2025 Pro-Forma)], [Net Revenues] )" })
$measures.Add(@{ Name = 'Gap to 2030 AOI Target'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'Distance between FY2025 AOI and the 2030 AOI target. Positive number = improvement still required.'; Expr = "[2030 AOI Target] - [Adjusted Operating Income]" })
$measures.Add(@{ Name = 'Gap Closed by VCP %'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtPct; Desc = 'Share of the 2030 AOI gap that the 6B VCP cost-save alone would close (assumes no revenue or mix change).'; Expr = "DIVIDE ( [VCP Cost Save Target 2028], [Gap to 2030 AOI Target] )" })
$measures.Add(@{ Name = 'Remaining Gap After VCP'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'AOI gap remaining after applying the full 6B VCP - must come from revenue growth, mix and pricing.'; Expr = "[Gap to 2030 AOI Target] - [VCP Cost Save Target 2028]" })
$measures.Add(@{ Name = 'Implied Annual AOI Lift Required (2026-2030)'; Folder = '6. FaSTLAne 2030 Targets'; Format = $fmtMoney; Desc = 'Linear annual improvement in AOI required to hit the 2030 target across 5 years.'; Expr = "DIVIDE ( [Gap to 2030 AOI Target], 5 )" })

# ---------- 7. VCP Save Allocation (proportional to revenue) ----------
$measures.Add(@{ Name = 'Revenue Share % - North America';     Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'NA share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - North America], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - Enlarged Europe';   Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'Enlarged Europe share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - Enlarged Europe], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - Middle East & Africa'; Folder = '7. VCP Save Allocation'; Format = $fmtPct; Desc = 'MEA share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - Middle East & Africa], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - South America';     Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'South America share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - South America], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - China India APAC';  Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'China & India & Asia Pacific share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - China India APAC], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - Maserati';          Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'Maserati share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - Maserati], [Net Revenues] )" })
$measures.Add(@{ Name = 'Revenue Share % - Other';             Folder = '7. VCP Save Allocation'; Format = $fmtPct;   Desc = 'Other segment share of FY2025 Stellantis net revenues.'; Expr = "DIVIDE ( [Net Revenues - Other], [Net Revenues] )" })

foreach ($r in $regions) {
    $tag = $r.Tag
    $measures.Add(@{ Name = "VCP Save Allocation - $tag"; Folder = '7. VCP Save Allocation'; Format = $fmtMoney; Desc = "Pro-rata share of the 6B VCP save allocated by $tag's FY2025 revenue contribution. Illustrative - real allocation will vary."; Expr = "[VCP Cost Save Target 2028] * [Revenue Share % - $tag]" })
    $measures.Add(@{ Name = "Pro-Forma AOI - $tag"; Folder = '7. VCP Save Allocation'; Format = $fmtMoney; Desc = "$tag AOI uplifted by its pro-rata share of the 6B VCP save."; Expr = "[AOI - $tag] + [VCP Save Allocation - $tag]" })
    $measures.Add(@{ Name = "Pro-Forma AOI Margin % - $tag"; Folder = '7. VCP Save Allocation'; Format = $fmtPct; Desc = "$tag pro-forma AOI margin after VCP allocation."; Expr = "DIVIDE ( [Pro-Forma AOI - $tag], [Net Revenues - $tag] )" })
}

# ---------- Create measures ----------
$existing = @{}
foreach ($m in $tbl.Measures) { $existing[$m.Name] = $m }

$created = 0; $updated = 0
foreach ($def in $measures) {
    $name = $def.Name
    if ($existing.ContainsKey($name)) {
        $m = $existing[$name]
        $m.Expression = $def.Expr
        $m.FormatString = $def.Format
        $m.DisplayFolder = $def.Folder
        $m.Description = $def.Desc
        $updated++
    } else {
        $m = New-Object Microsoft.AnalysisServices.Tabular.Measure
        $m.Name = $name
        $m.Expression = $def.Expr
        $m.FormatString = $def.Format
        $m.DisplayFolder = $def.Folder
        $m.Description = $def.Desc
        $tbl.Measures.Add($m)
        $created++
    }
}

Write-Output "About to save: $created new, $updated updated. Total in batch: $($measures.Count)"

try {
    $model.SaveChanges() | Out-Null
    Write-Output "SaveChanges OK"
} catch {
    Write-Output "SaveChanges FAILED: $($_.Exception.Message)"
    try { $model.UndoLocalChanges() } catch {}
    $server.Disconnect()
    exit 1
}

# Echo final list
Write-Output ""
Write-Output ("Measures on " + $Table + " (after save):")
foreach ($m in ($tbl.Measures | Sort-Object DisplayFolder, Name)) {
    Write-Output ("  [{0,-22}] {1}" -f $m.DisplayFolder, $m.Name)
}

$server.Disconnect()
Write-Output "DONE"
