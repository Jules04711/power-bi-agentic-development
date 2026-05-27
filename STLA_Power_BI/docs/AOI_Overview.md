# Stellantis FY2025 AOI Overview — Developer Documentation

**Project:** `STLA_20-F_Model.pbip`
**Page:** `AOI Overview`
**Author:** Generated via the Power BI Agentic Development framework
**Last updated:** 2026-05-27

---

## 1. Purpose

This document specifies the **AOI Overview** report page and the supporting semantic-model artifacts (tables, measures, calculated columns) that were added to `STLA_20-F_Model.pbip`. The page answers three questions:

1. What was Stellantis' Adjusted Operating Income (AOI) profile in FY2025?
2. Which one-time adjustments distinguished the FY2025 GAAP loss from the underlying AOI?
3. How does the €6 billion Value Creation Program (VCP) cost-cut commitment in the **FaSTLAne 2030** strategy close the gap to the 2030 AOI target of 7% margin on €190 B revenue?

Intended consumers: Power BI report developers, FP&A analysts, and data engineers who need to extend the model with additional scenarios, regions, or time periods.

---

## 2. Data Sources

| Source | URL | Used for |
|---|---|---|
| **Stellantis FY2025 Press Release (SEC EDGAR)** | `https://www.sec.gov/Archives/edgar/data/1605484/000160548426000019/stellantisnvfy2025pressrel.htm` | The AOI reconciliation table (Operating Income → AOI by segment + 11 adjustment categories). Scraped by `Web.BrowserContents` into the `AOI_FY2025` Power Query expression. |
| **Stellantis Corporate Strategy** | `https://www.stellantis.com/en/company/our-strategy` | The FaSTLAne 2030 plan (launched 21 May 2026): €6 B VCP cost-save target by 2028, 7% AOI margin target by 2030, €190 B revenue target, three global platforms covering 50% of volumes. |

### Source assumptions encoded in the model
- All monetary values are expressed in **€ millions** (millions of Euros).
- Segment names follow the Stellantis nomenclature: **North America**, **Enlarged Europe**, **Middle East & Africa**, **South America**, **China and India & Asia Pacific**, **Maserati**, **Other**. The **Other** column carries unallocated corporate / inter-segment eliminations.
- The press-release table is wide-format (one row per P&L line item, one column per segment + STELLANTIS total). The numeric values are stored as **strings** with thousand separators (`60,962`), parenthesised negatives (`(842)`), and em-dash (`—`) for missing values. All measures parse these strings into doubles.

---

## 3. PBIP Project Structure

```
STLA_Power_BI/
├── STLA_20-F_Model.pbip                       # Entry point (open in PBI Desktop)
├── STLA_20-F_Model.SemanticModel/             # Tabular model (TMDL)
│   ├── .platform                              # Fabric Git integration metadata
│   ├── definition.pbism                       # Semantic-model definition pointer
│   └── definition/
│       ├── database.tmdl                      # Compatibility level (1600) + model ID
│       ├── model.tmdl                         # Model-level config + ref-table list
│       ├── relationships.tmdl                 # All 36 relationships
│       ├── expressions.tmdl                   # Shared M expressions / parameters
│       ├── cultures/en-US.tmdl                # Linguistic metadata
│       └── tables/
│           ├── AOI_FY2025.tmdl                # *** Modified: + 88 measures ***
│           ├── Region.tmdl                    # *** New: calculated table ***
│           ├── AdjustmentBridge.tmdl          # *** New: calculated table ***
│           ├── Date.tmdl
│           ├── 20-F.tmdl
│           ├── 20F_EDGAR_API.tmdl
│           ├── … (50 other tables, incl. ~30 LocalDateTable_* auto date tables)
├── STLA_20-F_Model.Report/                    # PBIR report definition
│   ├── .platform
│   ├── definition.pbir                        # byPath link to SemanticModel
│   ├── StaticResources/
│   │   └── RegisteredResources/CY23SU08.json  # Custom theme
│   └── definition/
│       ├── version.json                       # PBIR format version (4.0)
│       ├── report.json                        # Report-level config (theme, filters, settings)
│       └── pages/
│           ├── pages.json                     # Page order + activePageName
│           ├── ReportSection/                 # DASHBOARD page
│           ├── 7e3df8077ddc0d4cb50c/          # SEC FILINGS page
│           ├── ef0b43dedcae9040717c/          # AOI page (legacy)
│           ├── AOIOverview/                   # *** New: AOI Overview page ***
│           │   ├── page.json
│           │   └── visuals/
│           │       ├── title_textbox/visual.json
│           │       ├── card_aoi/visual.json
│           │       ├── card_aoi_margin/visual.json
│           │       ├── card_gap_to_target/visual.json
│           │       ├── card_gap_closed/visual.json
│           │       ├── matrix_region/visual.json
│           │       ├── bar_adjustments/visual.json
│           │       ├── card_strategic_reset/visual.json
│           │       ├── card_one_time/visual.json
│           │       ├── card_pro_forma/visual.json
│           │       └── card_annual_lift/visual.json
│           ├── 80a032416a0913071da9/          # SUBSIDIARIES
│           ├── 08d15d11b29b52ae0198/          # RISK
│           └── bac192a614aa930793bc/          # 10-K TEXT ANALYSIS
├── docs/
│   └── AOI_Overview.md                        # This document
└── .claude/
    ├── scripts/
    │   ├── add-aoi-measures.ps1               # 82 measures via TOM
    │   ├── add-region-dim.ps1                 # Region + AdjustmentBridge calc tables + 6 dynamic measures
    │   └── build-aoi-overview-page.ps1        # Page + visuals via PBIR JSON
    └── backups/<timestamp>/                   # Pre-change snapshots
```

### Key file types

| File | Format | Edit method |
|---|---|---|
| `*.pbip` | JSON (small) | Open in PBI Desktop |
| `*.pbism`, `*.pbir` | JSON | Connection / project pointers; do not hand-edit unless rebinding |
| `*.tmdl` | TMDL (tab-indented) | Tabular Editor, `connect-pbid` (TOM via PowerShell), or hand-edit (last resort) |
| `page.json`, `visual.json`, `pages.json`, `report.json` | PBIR JSON | `pbir-cli` for thin reports; direct JSON edit for thick reports (this project) |
| `*.tmdl` calculated table | TMDL `partition X = calculated` with multi-line DAX | TOM `TmdlSerializer` strongly preferred |

---

## 4. Semantic Model Additions

### 4.1 New tables

#### `Region` — dimension for the cross-segment matrix

Calculated table providing a single column to drive row context in matrix/slicer visuals.

```dax
table Region

	column Region
		dataType: string
		sourceColumn: [Region]
		sortByColumn: Sort

	column Sort
		dataType: int64
		isHidden
		sourceColumn: [Sort]

	partition Region = calculated
		source =
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
```

`Region[Region]` is **sorted by** `Region[Sort]` so segments appear in their canonical FY2025 press-release order. The table is **disconnected** — no relationship to `AOI_FY2025`. Measures dispatch on `SELECTEDVALUE('Region'[Region])`.

#### `AdjustmentBridge` — dimension for the adjustment waterfall

```dax
table AdjustmentBridge

	column Adjustment
		dataType: string
		sourceColumn: [Adjustment]
		sortByColumn: Sort

	column Sort
		dataType: int64
		isHidden
		sourceColumn: [Sort]

	column Category
		dataType: string
		sourceColumn: [Category]

	partition AdjustmentBridge = calculated
		source =
			DATATABLE (
			    "Adjustment", STRING,
			    "Sort",       INTEGER,
			    "Category",   STRING,
			    {
			        { "Product Plan Realignment",  1, "Strategic Reset" },
			        { "Platform Impairments",      2, "Strategic Reset" },
			        { "Warranty Estimate Change",  3, "Operational"     },
			        { "Battery JV Charges",        4, "Non-Recurring"   },
			        { "Hydrogen Fuel Cell Exit",   5, "Non-Recurring"   },
			        { "Restructuring & Other",     6, "Operational"     },
			        { "Takata Recall",             7, "Non-Recurring"   },
			        { "CAFE Penalty",              8, "Non-Recurring"   },
			        { "Other Impairments",         9, "Strategic Reset" },
			        { "Turkiye Disposal",         10, "Non-Recurring"   },
			        { "Other Adjustments",        11, "Operational"     }
			    }
			)
```

The **Category** column groups the 11 FY2025 adjustments into three economic buckets:

| Category | Meaning | Expected behaviour after 2026 |
|---|---|---|
| **Strategic Reset** | Platform/product write-downs tied to the 2030 strategy reset | Largely non-recurring; supports the VCP cost-save thesis |
| **Operational** | Recurring quality/restructuring costs that the run-rate should absorb | Will shrink with VCP execution but never zero |
| **Non-Recurring** | One-off events (Takata, hydrogen exit, Türkiye disposal, CAFE, battery JV mark-down) | Fall off in FY2026 baseline |

### 4.2 String-to-number parsing helper

All AOI line-item measures share the same parsing pattern (the `AOI_FY2025` table stores values as strings):

```dax
VAR _raw = CALCULATE (
    SELECTEDVALUE ( 'AOI_FY2025'[<column>] ),
    ALL ( 'AOI_FY2025' ),
    'AOI_FY2025'[Index] = <line>
)
VAR _c1  = SUBSTITUTE ( _raw, ",", "" )    -- strip thousand separators
VAR _c2  = SUBSTITUTE ( _c1,  "(", "-" )   -- accounting negative open
VAR _c3  = SUBSTITUTE ( _c2,  ")", "" )    -- accounting negative close
VAR _c4  = SUBSTITUTE ( _c3,  "—", "" )    -- em-dash → blank
VAR _c5  = TRIM ( _c4 )
RETURN  IF ( _c5 = "" || _c5 = "-", BLANK(), VALUE ( _c5 ) )
```

`ALL ( 'AOI_FY2025' )` removes any row filter context before the `Index = N` predicate is applied, so the measure returns the same scalar regardless of the surrounding visual.

### 4.3 AOI_FY2025 Index → P&L line item mapping

| Index | P&L Line | Driving measure(s) |
|---:|---|---|
| 1 | Net revenues from external customers | `Net Revenues from External Customers` |
| 2 | Net revenues from inter-segment transactions | (rolled into `Net Revenues`) |
| 3 | **Net revenues (total)** | `Net Revenues`, `Net Revenues - <Region>` |
| 4 | Net profit/(loss) | `Net Profit (Loss)` |
| 5 | Tax expense/(benefit) | `Tax Expense (Benefit)` |
| 6 | Net financial expenses/(income) | `Net Financial Expenses (Income)` |
| 7 | **Operating income/(loss)** | `Operating Income (Loss)` |
| 9 | Restructuring & other costs (A) | `Restructuring & Other Costs` |
| 10 | Takata airbags recall (B) | `Takata Airbags Recall` |
| 11 | Platform impairments (C) | `Platform Impairments` |
| 12 | Product plan realignments / cancellations (D) | `Product Plan Realignment & Cancellations` |
| 13 | Other impairments (E) | `Other Impairments` |
| 14 | Battery JVs (F) | `Battery JV Charges` |
| 15 | Hydrogen fuel cell discontinuation (G) | `Hydrogen Fuel Cell Discontinuation` |
| 16 | CAFE penalty rate (H) | `CAFE Penalty Rate Charge` |
| 17 | Stellantis Türkiye disposal (I) | `Stellantis Turkiye Disposal` |
| 18 | Warranty estimate change (J) | `Warranty Estimate Change` |
| 19 | Other adjustments (K) | `Other Adjustments` |
| 20 | **Total adjustments** | `Total Adjustments` |
| 21 | **Adjusted Operating Income** | `Adjusted Operating Income`, `AOI - <Region>` |

---

## 5. Measure Catalog (88 measures)

All measures live on the `AOI_FY2025` table. Format string `#,0;(#,0);—` displays integers in € millions with parenthesised negatives and an em-dash for blanks. Margin measures use `0.0%;(0.0%);—`.

### Folder `0. Dynamic by Region`

Dispatch measures that react to `Region[Region]` / `AdjustmentBridge[Adjustment]` filter context. Use these (not the per-region static measures) when building matrix visuals.

| Measure | Returns | Used in |
|---|---|---|
| `Region AOI` | AOI for the selected region; defaults to total Stellantis if no region is selected | Region matrix |
| `Region Net Revenues` | Net revenues for the selected region | Region matrix |
| `Region AOI Margin %` | `DIVIDE([Region AOI], [Region Net Revenues])` | Region matrix |
| `Region Pro-Forma AOI` | Region AOI + that region's pro-rata share of the €6 B VCP save | Region matrix |
| `Region VCP Save Allocation` | Pro-rata share of the €6 B VCP save | Region matrix tooltip |
| `Adjustment Value` | Value for the selected `AdjustmentBridge[Adjustment]`; defaults to `Total Adjustments` | Adjustment bar chart |

```dax
Region AOI =
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
```

### Folder `1. AOI Core` (10 measures, Stellantis-total)

| Measure | Line | Description |
|---|---|---|
| `Net Revenues` | 3 | Consolidated net revenues |
| `Net Revenues from External Customers` | 1 | External revenue (excludes inter-segment) |
| `Operating Income (Loss)` | 7 | GAAP operating income |
| `Net Profit (Loss)` | 4 | Reported net profit |
| `Tax Expense (Benefit)` | 5 | |
| `Net Financial Expenses (Income)` | 6 | |
| `Total Adjustments` | 20 | Sum of reconciling items |
| `Adjusted Operating Income` | 21 | `= Operating Income + Total Adjustments` |
| `AOI Margin %` | — | `DIVIDE([Adjusted Operating Income], [Net Revenues])` |
| `Operating Margin %` | — | `DIVIDE([Operating Income (Loss)], [Net Revenues])` |

### Folder `2. AOI by Region` (7 measures)

One measure per segment, e.g.:

```dax
AOI - North America =
VAR _raw = CALCULATE (
    SELECTEDVALUE ( 'AOI_FY2025'[NORTH AMERICA] ),
    ALL ( 'AOI_FY2025' ),
    'AOI_FY2025'[Index] = 21
)
… (parse pattern) …
```

`AOI - North America`, `AOI - Enlarged Europe`, `AOI - Middle East & Africa`, `AOI - South America`, `AOI - China India APAC`, `AOI - Maserati`, `AOI - Other`.

### Folder `3. Revenue by Region` (7 measures)

Same shape as AOI by region, sourced from Index = 3:

`Net Revenues - North America`, `Net Revenues - Enlarged Europe`, … `Net Revenues - Other`.

### Folder `4. Margin by Region` (7 measures)

```dax
AOI Margin % - North America = DIVIDE ( [AOI - North America], [Net Revenues - North America] )
```

… and equivalents for the six other segments.

### Folder `5. Adjustment Bridge` (13 measures)

One measure per AOI-reconciliation line plus two roll-ups.

| Measure | Index | FY2025 value (€M) |
|---|---:|---:|
| `Restructuring & Other Costs` | 9 | 913 |
| `Takata Airbags Recall` | 10 | 622 |
| `Platform Impairments` | 11 | 6,583 |
| `Product Plan Realignment & Cancellations` | 12 | 9,072 |
| `Other Impairments` | 13 | 243 |
| `Battery JV Charges` | 14 | 2,054 |
| `Hydrogen Fuel Cell Discontinuation` | 15 | 1,094 |
| `CAFE Penalty Rate Charge` | 16 | 269 |
| `Stellantis Turkiye Disposal` | 17 | 246 |
| `Warranty Estimate Change` | 18 | 4,130 |
| `Other Adjustments` | 19 | 186 |
| **`Strategic Realignment Charges`** | — | **15,898** (= Platform + Product Plan + Other Impairments) |
| **`One-Time Charges - Non-Recurring`** | — | **4,285** (= Takata + Hydrogen + Türkiye + Battery JV + CAFE) |

### Folder `6. FaSTLAne 2030 Targets` (10 measures)

The forward-looking scenario layer. All numeric constants are encoded in DAX so they are auditable.

| Measure | Expression | Value |
|---|---|---:|
| `VCP Cost Save Target 2028` | `6000` | 6,000 |
| `2030 Revenue Target` | `190000` | 190,000 |
| `2030 AOI Margin Target %` | `0.07` | 7.0% |
| `2030 AOI Target` | `[2030 Revenue Target] * [2030 AOI Margin Target %]` | 13,300 |
| `AOI After VCP Save (FY2025 Pro-Forma)` | `[Adjusted Operating Income] + [VCP Cost Save Target 2028]` | 5,158 |
| `AOI Margin % After VCP Save` | `DIVIDE([AOI After VCP Save (FY2025 Pro-Forma)], [Net Revenues])` | 3.4% |
| `Gap to 2030 AOI Target` | `[2030 AOI Target] - [Adjusted Operating Income]` | 14,142 |
| `Gap Closed by VCP %` | `DIVIDE([VCP Cost Save Target 2028], [Gap to 2030 AOI Target])` | 42.4% |
| `Remaining Gap After VCP` | `[Gap to 2030 AOI Target] - [VCP Cost Save Target 2028]` | 8,142 |
| `Implied Annual AOI Lift Required (2026-2030)` | `DIVIDE([Gap to 2030 AOI Target], 5)` | 2,828 |

### Folder `7. VCP Save Allocation` (21 measures)

Three measures per region (Revenue Share %, VCP Save Allocation, Pro-Forma AOI), totalling 21:

| Pattern | Example for North America |
|---|---|
| `Revenue Share % - <Region>` | `DIVIDE([Net Revenues - North America], [Net Revenues])` → 39.7% |
| `VCP Save Allocation - <Region>` | `[VCP Cost Save Target 2028] * [Revenue Share % - North America]` → 2,384 |
| `Pro-Forma AOI - <Region>` | `[AOI - North America] + [VCP Save Allocation - North America]` → 492 |
| `Pro-Forma AOI Margin % - <Region>` | `DIVIDE([Pro-Forma AOI - North America], [Net Revenues - North America])` → 0.8% |

Allocation by revenue share is illustrative only. Real cost-save allocation will skew heavier to North America and Enlarged Europe where the platform consolidation and footprint actions are concentrated.

---

## 6. AOI Overview Page Specification

### 6.1 Page properties

| Property | Value |
|---|---|
| Display name | `AOI Overview` |
| Internal name | `AOIOverview` |
| Width × Height | 1280 × 720 |
| Display option | `FitToPage` |
| Background | `#F4F6FA` (light neutral) |
| Schema | `page/2.1.0` |

### 6.2 Visual layout

```
┌────────────────────────────────────────────────────────────────────┐
│ title_textbox  (20,20 - 1240×60)                                   │  y=20
│ "FY2025 AOI Overview - FaSTLAne 2030 Cost-Cut Lens"                │
├────────────┬────────────┬────────────┬─────────────────────────────┤
│ card_aoi   │ card_aoi_  │ card_gap_  │ card_gap_closed             │  y=100
│            │ margin     │ to_target  │                             │  h=120
│ AOI        │ AOI %      │ Gap 2030   │ Gap closed by VCP %         │
├────────────┴────────────┼────────────┴─────────────────────────────┤
│ matrix_region           │ bar_adjustments                          │  y=240
│ (20,240) 620×240        │ (660,240) 600×240                        │  h=240
│ rows: Region            │ x: AdjustmentBridge[Adjustment]          │
│ vals: Region Revenue,   │ y: [Adjustment Value]                    │
│       Region AOI,       │ series colour: Category                  │
│       Region Margin %,  │ sort: [Adjustment Value] desc            │
│       Region Pro-Forma  │                                          │
├────────────┬────────────┼────────────┬─────────────────────────────┤
│ card_      │ card_one_  │ card_pro_  │ card_annual_lift            │  y=500
│ strategic_ │ time       │ forma      │                             │  h=120
│ reset      │            │            │                             │
│ €15,898 M  │ €4,285 M   │ €5,158 M   │ €2,828 M/yr                 │
└────────────┴────────────┴────────────┴─────────────────────────────┘
```

### 6.3 Visual-to-measure binding

| Visual | Type | Binding |
|---|---|---|
| `title_textbox` | `textbox` | Static text |
| `card_aoi` | `card` | Values: `AOI_FY2025[Adjusted Operating Income]` |
| `card_aoi_margin` | `card` | Values: `AOI_FY2025[AOI Margin %]` |
| `card_gap_to_target` | `card` | Values: `AOI_FY2025[Gap to 2030 AOI Target]` |
| `card_gap_closed` | `card` | Values: `AOI_FY2025[Gap Closed by VCP %]` |
| `matrix_region` | `pivotTable` | Rows: `Region[Region]`; Values: `Region Net Revenues`, `Region AOI`, `Region AOI Margin %`, `Region Pro-Forma AOI`; Sort: `Region[Sort]` ascending |
| `bar_adjustments` | `barChart` | Category: `AdjustmentBridge[Adjustment]`; Series: `AdjustmentBridge[Category]`; Y: `AOI_FY2025[Adjustment Value]`; Sort: Y descending |
| `card_strategic_reset` | `card` | Values: `AOI_FY2025[Strategic Realignment Charges]` |
| `card_one_time` | `card` | Values: `AOI_FY2025[One-Time Charges - Non-Recurring]` |
| `card_pro_forma` | `card` | Values: `AOI_FY2025[AOI After VCP Save (FY2025 Pro-Forma)]` |
| `card_annual_lift` | `card` | Values: `AOI_FY2025[Implied Annual AOI Lift Required (2026-2030)]` |

### 6.4 Verified FY2025 key values

| Measure | Value |
|---|---:|
| Net Revenues | €153,508 M |
| Operating Income (Loss) | (€26,254 M) |
| Total Adjustments | €25,412 M |
| Adjusted Operating Income | **(€842 M)** |
| AOI Margin % | (0.5%) |
| Gap to 2030 AOI Target | €14,142 M |
| Gap Closed by VCP % | 42.4% |
| AOI After VCP Save (Pro-Forma) | €5,158 M |
| AOI Margin % After VCP Save | 3.4% |
| Implied Annual AOI Lift Required | €2,828 M/yr |

---

## 7. Power BI Agentic Development Framework

### 7.1 What it is

A Claude Code plugin distributed as `power-bi-agentic-development`. It bundles skills that teach an LLM agent how to read and modify every layer of the Microsoft BI stack (PBIP, TMDL, PBIR, Fabric items, Tabular Editor, Power BI Service). Skills are loaded on demand and contain runnable scripts plus reference material.

### 7.2 Plugin cache layout

```
%USERPROFILE%\.claude\plugins\cache\power-bi-agentic-development\
├── fabric-admin/<ver>/skills/*           # Tenant settings, audit
├── fabric-cli/<ver>/skills/*             # fab CLI guidance
├── pbi-desktop/<ver>/skills/
│   ├── connect-pbid/                     # TOM + ADOMD.NET PowerShell patterns
│   └── query-listener/                   # DMV polling for visual queries
├── pbip/<ver>/skills/
│   ├── pbip/                             # Project structure, rename, fork
│   ├── pbir-format/                      # Hand-editing PBIR JSON (fallback)
│   └── tmdl/                             # Hand-editing TMDL (fallback)
├── reports/<ver>/skills/
│   ├── pbir-cli/                         # Recommended: pbir command-line
│   ├── pbi-report-design/                # Design principles
│   ├── create-pbi-report/                # Step-by-step report build
│   ├── deneb-visuals/, python-visuals/, r-visuals/, svg-visuals/
│   ├── modifying-theme-json/, review-report/
├── semantic-models/<ver>/skills/         # DAX optimisation, naming, lineage
└── tabular-editor/<ver>/skills/          # TE2/TE3, BPA rules, C# scripting
```

### 7.3 Skills used to build the AOI Overview

| Order | Skill | Purpose | Why we used it |
|---:|---|---|---|
| 1 | `pbi-desktop:connect-pbid` | Connect to PBI Desktop's local Analysis Services via TOM (PowerShell + `Microsoft.AnalysisServices.Tabular.dll`) | Adding measures and calculated tables is more reliable through TOM than through hand-edited TMDL — the engine validates DAX on `SaveChanges()`. |
| 2 | `reports:pbir-cli` | Inspect existing report, validate structure | We needed `pbir model`, `pbir validate`, `pbir tree` to understand the existing 5-page report before adding a 6th. |
| 3 | `pbip:pbir-format` | Direct PBIR JSON editing | Fallback when `pbir add page` rejected the byPath (thick) report. We wrote `page.json` and 11 `visual.json` files directly. |
| 4 | `pbip:tmdl` | TMDL syntax reference | Needed when validating that `TmdlSerializer` output matched expected calculated-table indentation. |

### 7.4 External tools installed

| Tool | Source | Used for |
|---|---|---|
| **NuGet CLI** (`nuget.exe`) | `winget install Microsoft.NuGet` | Pulling TOM + ADOMD.NET packages |
| **Microsoft.AnalysisServices.retail.amd64** (19.84.1) | NuGet | TOM (Tabular Object Model) |
| **Microsoft.AnalysisServices.AdomdClient.retail.amd64** (19.84.1) | NuGet | ADOMD.NET (DAX query client) |
| **pbir-cli** 0.9.21 | `py -3.11 -m pip install pbir-cli` | Report exploration + validation |

NuGet packages cache at `%TEMP%\tom_nuget\`; DLLs are loaded with `Add-Type -Path …\lib\net45\*.dll`.

### 7.5 End-to-end command transcript

The build was scripted into three reusable PowerShell files. Each was executed against PBI Desktop's local AS port (`localhost:<port>` — discovered via `netstat -ano` against the `msmdsrv.exe` PID, or via the port file under `%LOCALAPPDATA%\Microsoft\Power BI Desktop\AnalysisServicesWorkspaces\*\Data\msmdsrv.port.txt`).

```powershell
# 1. Discover the running PBI Desktop AS port
$pid    = (Get-Process msmdsrv).Id
$port   = (netstat -ano | Select-String "LISTENING" |
           Where-Object { ($_ -split "\s+")[-1] -eq "$pid" } |
           ForEach-Object { ($_ -split "\s+")[2] -replace ".*:" } |
           Sort-Object -Unique)[0]

# 2. Add 82 AOI measures (8 display folders)
&  .\.claude\scripts\add-aoi-measures.ps1 -Port $port

# 3. Add Region + AdjustmentBridge calculated tables and 6 dynamic measures
&  .\.claude\scripts\add-region-dim.ps1   -Port $port

# 4. Refresh the calculated tables (otherwise they read as empty)
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=localhost:$port")
$dbName = $server.Databases[0].Name
$server.Execute('{ "refresh": { "type": "calculate", "objects": [ { "database": "' + $dbName + '" } ] } }')
$server.Disconnect()

# 5. Persist the running model to TMDL (overwrites in-memory state to disk)
[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder(
    $server.Databases[0],
    "$env:TEMP\stla_tmdl_dump"
)
# … then file-copy AOI_FY2025.tmdl, Region.tmdl, AdjustmentBridge.tmdl, model.tmdl
# into STLA_20-F_Model.SemanticModel\definition\

# 6. Stop Power BI Desktop so the report files are unlocked
Get-Process PBIDesktop, msmdsrv | Stop-Process -Force

# 7. Build the AOI Overview page (PBIR JSON)
& .\.claude\scripts\build-aoi-overview-page.ps1

# 8. Validate the report structure
pbir -q validate "STLA_20-F_Model.Report"

# 9. Re-open Power BI Desktop
Start-Process "STLA_20-F_Model.pbip"
```

#### Critical sequencing rules

1. **Power BI Desktop does not watch its files.** External edits to TMDL or PBIR JSON while PBI Desktop is open are silently ignored, and the next PBI Desktop save may overwrite them. Always close PBI Desktop before editing report files on disk.
2. **TOM `SaveChanges()` writes to the running AS instance, not to disk.** To persist to TMDL you must either (a) press Ctrl+S in PBI Desktop while it's still running, or (b) use `TmdlSerializer.SerializeDatabaseToFolder` and copy the output over the project files while PBI Desktop is closed.
3. **Calculated tables need a `calculate` refresh** after creation; otherwise queries return *"calculated table … does not hold any data because it needs to be recalculated"*. The TMSL `{ "refresh": { "type": "calculate" } }` payload triggers it.
4. **`pbir add page` rejects byPath (thick) reports** because it cannot run a model query without a remote workspace. For local PBIP reports, write `page.json` and `visual.json` directly and use `pbir validate` to check structure.

---

## 8. Reproduction / Extension

### 8.1 To extend with FY2024 comparison

1. Create an `AOI_FY2024` table in Power Query (same shape as `AOI_FY2025`, sourced from the FY2024 SEC filing).
2. Duplicate the helper-pattern measures with `YoY` variants, parameterised by year.
3. Add a `Year` disconnected dimension; replace `AOI_FY2025[STELLANTIS]` references in `Region AOI` with a year-aware switch.

### 8.2 To swap to byConnection (thin report against a published model)

1. Publish `STLA_20-F_Model.SemanticModel` to a Fabric workspace.
2. Rewrite `STLA_20-F_Model.Report/definition.pbir` from:
   ```json
   { "datasetReference": { "byPath": { "path": "../STLA_20-F_Model.SemanticModel" } } }
   ```
   to:
   ```json
   { "datasetReference": { "byConnection": {
       "connectionString": "Data Source=powerbi://api.powerbi.com/v1.0/myorg/<Workspace>;Initial Catalog=STLA_20-F_Model"
   } } }
   ```
3. `pbir connect "STLA_20-F_Model.Report"` and then `pbir add visual …` will work end-to-end without TOM.

### 8.3 To restore from backup

```powershell
$backup = "C:\Users\golfc\OneDrive\Desktop\Power BI Agentic Development\STLA_Power_BI\.claude\backups\<timestamp>"
$proj   = "C:\Users\golfc\OneDrive\Desktop\Power BI Agentic Development\STLA_Power_BI"
Get-Process PBIDesktop, msmdsrv -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item "$proj\STLA_20-F_Model.SemanticModel", "$proj\STLA_20-F_Model.Report" -Recurse -Force
Copy-Item "$backup\STLA_20-F_Model.SemanticModel" "$proj\" -Recurse
Copy-Item "$backup\STLA_20-F_Model.Report"       "$proj\" -Recurse
```

---

## 9. Known caveats

- **`Other` segment** carries unallocated corporate / inter-segment items; pro-forma views of `Other` are illustrative only.
- **`OTHER(*)` column** in `AOI_FY2025` has trailing `(*)` (footnote marker). DAX column references must include the parentheses: `'AOI_FY2025'[OTHER(*)]`.
- **Auto Date/Time is enabled** in this model, producing ~30 `LocalDateTable_*` hidden tables. They are unrelated to the AOI page but inflate the table count in TOM/`pbir tree`.
- **Compatibility level is 1600**, which predates DAX User-Defined Functions. The repeating SUBSTITUTE pattern is intentional; upgrading to 1610+ would allow replacing it with a single UDF.
- **The FY2025 press release URL returns HTTP 403 to anonymous WebFetch.** All FY2025 figures in this document come from the AOI table itself (which was M-scraped from that URL inside `AOI_FY2025`'s Power Query partition).
- **The `OTHER` AOI of (€1,567 M)** includes corporate eliminations, so by-region totals reconcile to the press release: `(1,892) + (651) + 1,429 + 1,963 + 74 + (198) + (1,567) = (842)`.

---

## 10. References

- `STLA_Power_BI/docs/Semantic_Model_Reference.md` — canonical reference for the full `STLA_20-F_Model` semantic model (all 25 tables, 9 relationships, 88 measures, 6 M expressions, security/governance posture, Mermaid ERD + lineage + measure-dependency diagrams).
- `STLA_Power_BI/docs/Risk_Tab.md` — companion documentation for the Risk tab and the `risk_heatmap` register.

## 11. Document changelog

| Date | Change |
|---|---|
| 2026-05-27 | Initial version: 88 measures, 2 calculated tables, 1 page (`AOI Overview`), full reproduction guide |
| 2026-05-27 | Added § 10 References cross-link to `Semantic_Model_Reference.md`. |
