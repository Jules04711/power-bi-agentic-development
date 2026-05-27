# Stellantis FY2025 RISK Tab — Developer Documentation

**Project:** `STLA_20-F_Model.pbip`
**Page:** `RISK` (internal name `08d15d11b29b52ae0198`)
**Author:** Generated via the Power BI Agentic Development framework
**Last updated:** 2026-05-27

---

## 1. Purpose

This document specifies the **RISK** report page and the supporting semantic-model artifacts (M expressions, computed risk register, Python heatmap visual) that score and visualise Stellantis N.V.'s Item 3.D Risk Factors from the **FY2025 Form 20-F**. The page answers three questions:

1. What are Stellantis' enterprise risk factors as disclosed in the FY2025 20-F (Item 3.D)?
2. How do those risks rank by **Risk Score = Likelihood × Impact** on a 5×5 matrix?
3. Which risks are **Critical / High / Medium / Low** and which categories carry the heaviest narrative weight?

Intended consumers: Power BI report developers, risk analysts, audit teams, and data engineers who need to extend the model to new fiscal years, additional risk categories, or other OEM filings.

---

## 2. Data Sources

| Source | Location | Used for |
|---|---|---|
| **Stellantis N.V. Form 20-F — FY2025** | `STLA_Power_BI/resources/Stellantis-FY2025-20-F.pdf` (356 pages, 2.6 MB) | Risk Factors text extracted via Power Query `Pdf.Tables`. Item 3.D spans **PDF pages 80–103**. |
| **Stellantis Corporate Strategy (FaSTLAne 2030)** | `https://www.stellantis.com/en/company/our-strategy` | Context for strategic-risk descriptions (Investor Day, VCP, platform consolidation). |

### Source assumptions encoded in the pipeline

- The PDF is **read on every refresh**; there is no intermediate cache. Each refresh takes 5–10 s to parse the 356-page file.
- Text is extracted **page-by-page** (one row per page) then **filtered to the Item 3.D Risk Factors range** (PDF pages 80–103) before risk-pattern matching.
- All scoring is **deterministic** given the input PDF — the same PDF always produces the same 18 risk rows.
- Risk severity is inferred from **two signals**: (a) frequency of risk-category keyword matches, (b) frequency of impact-language words ("significant", "material", "minor", "limited", …) in the risk text overall.

---

## 3. PBIP Project Structure (Risk-related files)

```
STLA_Power_BI/
├── resources/
│   └── Stellantis-FY2025-20-F.pdf                 # PDF data source (356 pages)
├── STLA_20-F_Model.SemanticModel/
│   └── definition/
│       ├── expressions.tmdl                       # 20f_full_text, 10k_risk_section,
│       │                                          # RiskCategories_Config, fnCountPattern
│       └── tables/
│           └── risk_heatmap.tmdl                  # Computed risk register (18 rows × 12 cols)
└── STLA_20-F_Model.Report/
    └── definition/pages/
        └── 08d15d11b29b52ae0198/                  # RISK page folder
            ├── page.json                          # Page properties (1280 × 720)
            └── visuals/
                ├── 2fac20354bd0b7295428/visual.json   # Title textbox ("Risk Assessment")
                ├── 3d1b96e896153c5e1487/visual.json   # Page navigator
                ├── 51df4f4a7bec61583069/visual.json   # Risk register tableEx (5 columns)
                ├── 5b5e05eabddf74840503/visual.json   # Logo image
                ├── acda9bbc13074dc88258/visual.json   # Risk Level slicer
                ├── d027a30700b939ab54c3/visual.json   # Banner shape
                └── fbc2cbb1013b272d690b/visual.json   # Python heatmap visual
```

---

## 4. Semantic Model Pipeline (Power Query)

The risk register is produced by a chain of four M expressions and one computed table. All live in `STLA_20-F_Model.SemanticModel/definition/expressions.tmdl` (the function/config layer) and `tables/risk_heatmap.tmdl` (the computed output table).

```
                    Stellantis-FY2025-20-F.pdf
                              │
                              ▼
                  expression 20f_full_text
                  (parse 356 pages → text per page,
                   classify into 15 sections)
                              │
                              ▼
                expression 10k_risk_section
                (filter to Section = "Item 3.D - Risk Factors",
                 PDF pages 80–103)
                              │
                              ▼
                  table risk_heatmap (m)
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        │  Uses:                                    │
        │   - expression RiskCategories_Config      │
        │     (18 risk categories × patterns)       │
        │   - expression fnCountPattern             │
        │     (case-insensitive substring counter)  │
        │                                           │
        │  Produces 12 columns:                     │
        │   Risk_ID, Risk_Category, Description,    │
        │   Mentions, Likelihood, Impact,           │
        │   Risk_Score, Risk_Level,                 │
        │   Likelihood_Label, Impact_Label,         │
        │   Risk_Color, Quadrant                    │
        └───────────────────────────────────────────┘
```

### 4.1 `20f_full_text` — full-document text extraction

Reads the PDF, filters to page elements, extracts text by combining all columns of each page's `[Data]` table, removes Stellantis-specific repeating headers, deduplicates, and classifies pages into 15 sections.

```m
let
    Source = Pdf.Tables(
        File.Contents("C:\Users\golfc\OneDrive\Desktop\Power BI Agentic Development\STLA_Power_BI\resources\Stellantis-FY2025-20-F.pdf"),
        [Implementation="1.3"]
    ),
    PagesOnly = Table.SelectRows(Source, each [Kind] = "Page"),
    WithPageNum = Table.AddIndexColumn(PagesOnly, "Page_Number", 1, 1, Int64.Type),
    WithText = Table.AddColumn(WithPageNum, "Page_Text", each
        let
            dataTable = [Data],
            textList = Table.ToList(dataTable, (row) =>
                Text.Combine(
                    List.Transform(row, each if _ = null then "" else Text.From(_)),
                    " "
                )
            ),
            combined = Text.Combine(textList, " "),
            cleaned = Text.Replace(Text.Replace(combined, "  ", " "), "   ", " ")
        in Text.Trim(cleaned), type text),
    // … Stellantis header-stripping, dedup, char/word counts …
    WithSection = Table.AddColumn(WithWordCount, "Section", each
        if [Page_Number] <= 4 then "Cover & TOC"
        else if [Page_Number] >= 5 and [Page_Number] <= 8 then "Board Report - Introduction"
        else if [Page_Number] >= 9 and [Page_Number] <= 29 then "Management Report - Business Overview"
        else if [Page_Number] >= 30 and [Page_Number] <= 38 then "Environmental & Regulatory Matters"
        else if [Page_Number] >= 39 and [Page_Number] <= 66 then "Financial Overview & Results of Operations"
        else if [Page_Number] >= 67 and [Page_Number] <= 79 then "Liquidity & Capital Resources / Risk Management"
        else if [Page_Number] >= 80 and [Page_Number] <= 103 then "Item 3.D - Risk Factors"
        else if [Page_Number] >= 104 and [Page_Number] <= 161 then "Corporate Governance"
        else if [Page_Number] >= 162 and [Page_Number] <= 186 then "Remuneration Report"
        else if [Page_Number] >= 187 and [Page_Number] <= 190 then "Controls & Procedures"
        else if [Page_Number] >= 191 and [Page_Number] <= 201 then "Consolidated Financial Statements"
        else if [Page_Number] >= 202 and [Page_Number] <= 331 then "Notes to Financial Statements"
        else if [Page_Number] >= 332 and [Page_Number] <= 352 then "Other Information"
        else if [Page_Number] >= 353 and [Page_Number] <= 355 then "Form 20-F Cross Reference"
        else "Signatures", type text),
    // … Part classification, final column selection …
in FinalTable
```

**Page anchors** (PDF page numbers, 1-indexed) come from scanning the document with `pypdf`. The Stellantis 20-F TOC lists "Risk Factors 80" — but the PDF cover/board pages push the actual PDF page index by 0 in this filing, so printed-80 = PDF-80.

### 4.2 `10k_risk_section` — Item 3.D filter

Reuses the same parsing logic as `20f_full_text` then filters to the Risk Factors section only:

```m
…
FinalTable = Table.SelectColumns(WithPart, {"Page_Number", "Part", "Section", "Page_Text", "Char_Count", "Word_Count"}),
#"Filtered Rows" = Table.SelectRows(FinalTable, each ([Section] = "Item 3.D - Risk Factors"))
in #"Filtered Rows"
```

> The expression name (`10k_risk_section`) is a historical artifact from when the model was built against a 10-K. It now filters a 20-F. Renaming the expression would cascade into the `risk_heatmap` partition source and the Python visual references — leave as-is unless doing a coordinated rename.

### 4.3 `RiskCategories_Config` — the risk taxonomy

Hand-curated table of 18 risk categories. Each row carries:

| Column | Purpose |
|---|---|
| `Risk_ID` | Stable identifier (R01–R18); used in the heatmap bubble labels |
| `Risk_Category` | Display name on the heatmap legend and tableEx |
| `Search_Pattern` | Pipe-separated regex-alternation terms — each term is counted as a literal substring (case-insensitive) |
| `Description` | Long-form text shown in the tableEx and Python visual tooltip |
| `Base_Impact` | Default Impact score (1–5) before severity-language adjustment |

```m
let
    RiskConfig = #table(
        {"Risk_ID", "Risk_Category", "Search_Pattern", "Description", "Base_Impact"},
        {
            {"R01", "Tariffs & Trade Policy", "tariff|duties|trade policy|trade partner|import|customs|USMCA|cross-border", "U.S. tariffs on imports from Mexico, Canada, China, EU; impact on North America profitability (e.g., Jeep Cherokee from Toluca)", 5},
            {"R02", "Regulatory & Compliance", "regulate|regulation|emissions standard|fuel economy|CAFE|Euro 6|Euro 7|EPA|NHTSA|CARB|homologation|legal requirement", "Vehicle safety, emissions, fuel economy regulations across EU, U.S., China; Euro 7, GSR, FMVSS", 5},
            {"R03", "Competition & Market", "competition|competitive|market share|competitor|consolidation|new entrant|Chinese OEM|BYD|Chery|Leapmotor|pricing pressure", "Competitive pressure from legacy OEMs (VW, Toyota, Ford, GM) and new Chinese entrants (BYD, Chery)", 4},
            {"R04", "Supply Chain & Raw Materials", "supply chain|supplier|shortage|procurement|semiconductor|chip|raw material|lithium|cobalt|nickel|rare earth|battery material", "Component shortages, raw material price volatility, battery material sourcing, supplier financial health", 4},
            {"R05", "EV Transition & Electrification", "electric vehicle|electrification|BEV|PHEV|REEV|battery|charging|ZEV|Dare Forward|powertrain|hybrid", "Demand-led BEV adoption uncertainty, EV program cancellations, platform impairments, battery capacity resizing", 5},
            {"R06", "Strategic Reset & Execution", "strategic plan|reassessment|strategic reset|leadership transition|Investor Day|execution|restructuring|reorganization", "New CEO Antonio Filosa-led strategic reassessment; pending May 2026 Investor Day; execution risk on portfolio realignment", 4},
            {"R07", "Cybersecurity & IT Systems", "cyber|data breach|security incident|hack|malfunction|disruption|information technology|electronic control|connected vehicle", "IT system breaches, vehicle electronic control system compromise, data privacy", 4},
            {"R08", "Macroeconomic & FX", "economic condition|recession|inflation|interest rate|exchange rate|currency|cyclicality|consumer confidence|disposable income", "Cyclical demand, inflation, interest rates, Euro/USD/BRL/ARS FX exposure across regions", 3},
            {"R09", "Financial Services & Credit", "financial services|auto financing|credit risk|residual value|dealer financing|floorplan|SFS|leasing|BNP Paribas|Santander", "SFS U.S., Leasys, JV partnerships with BNPP and SCF; credit losses, residual values, dealer floorplan", 3},
            {"R10", "Labor Relations", "labor|union|UAW|Unifor|workforce|strike|collective bargaining|works council|European Works Council|industrial relations", "UAW, Unifor, European Works Council relations; 85% of workforce under collective bargaining", 4},
            {"R11", "Product Quality & Recalls", "warranty|recall|defect|quality|product liability|Takata|airbag|safety recall|class action", "Quality challenges on new platforms/powertrains, Takata airbag litigation, recall costs", 4},
            {"R12", "Emissions Litigation & Investigations", "emissions investigation|diesel|Euro 5|KBA|RDW|consumer fraud|emissions non-compliance|Kraftfahrt|public prosecutor", "Ongoing diesel emissions investigations in France, Germany (KBA), Netherlands, UK, Italy; FCA/PSA legacy exposure", 4},
            {"R13", "China & Asia Pacific Operations", "China|Chinese|joint venture|DPCA|Dongfeng|Leapmotor|FIAPL|Tofas|geopolitical|Asia Pacific", "DPCA JV, Leapmotor International (51% owned), Tofas JV in Turkey; declining China market share (0.2%)", 4},
            {"R14", "Climate & Sustainability", "climate|greenhouse|GHG|CO2|carbon|sustainability|ESG|end-of-life|ELV|recycl|circular economy", "EU CO2 fleet targets (€95/g penalty), ELV directive, decarbonization commitments", 3},
            {"R15", "Autonomous & Software", "autonomous|self-driving|automated driving|ADAS|driver assist|software-defined|over-the-air|OTA|connectivity", "Autonomous features (GSR mandates), software-defined vehicle development, Archer Aviation investment", 3},
            {"R16", "Pension & Benefit Obligations", "pension|defined benefit|retiree|OPEB|funding shortfall|actuarial", "Defined benefit pension funding shortfalls across legacy FCA and PSA plans", 3},
            {"R17", "Political & Geopolitical Instability", "political|geopolitical|social instability|conflict|sanctions|banned countries|Russia|Ukraine|Middle East", "Operations exposure in MEA, banned countries (Russia, Iran, Syria, Cuba, Sudan, Belarus); regional instability", 3},
            {"R18", "Natural Disasters & Operations", "earthquake|disaster|flood|natural disaster|plant shutdown|production disruption|force majeure", "Plant shutdowns, natural disasters affecting manufacturing footprint (EU, NA, SA, Africa)", 2}
        }
    )
in RiskConfig
```

> **`Search_Pattern` is alternation, NOT regex.** The helper `fnCountPattern` splits each pattern on `|` and counts each term as a literal case-insensitive substring. Regex anchors (`\b`, `^`, `$`), character classes (`[a-z]`), and groups (`(?:…)`) are treated as literal text and will match zero occurrences.

### 4.4 `fnCountPattern` — keyword counter helper

```m
(text as text, pattern as text) as number =>
let
    terms = Text.Split(pattern, "|"),
    lowerText = Text.Lower(text),
    counts = List.Transform(terms, each
        let
            term = Text.Trim(Text.Lower(_)),
            originalLength = Text.Length(lowerText),
            replacedText = Text.Replace(lowerText, term, ""),
            replacedLength = Text.Length(replacedText),
            termLength = Text.Length(term),
            count = if termLength > 0 then (originalLength - replacedLength) / termLength else 0
        in Number.Round(count, 0)
    ),
    totalCount = List.Sum(counts)
in totalCount
```

Counts non-overlapping case-insensitive substrings by length-difference of pre/post `Text.Replace`. Fast and dependency-free.

### 4.5 `risk_heatmap` — the computed risk register

The M partition of the `risk_heatmap` table (in `tables/risk_heatmap.tmdl`) joins everything:

```m
let
    RiskText  = Lines.ToText(#"10k_risk_section"[Page_Text]),
    RiskConfig = RiskCategories_Config,

    // 1) Count mentions per category
    WithMentions = Table.AddColumn(RiskConfig, "Mentions",
        each fnCountPattern(RiskText, [Search_Pattern]), Int64.Type),

    // 2) Likelihood (1–5) by mention-frequency percentile
    MaxMentions = List.Max(WithMentions[Mentions]),
    WithLikelihood = Table.AddColumn(WithMentions, "Likelihood", each
        let ratio = if MaxMentions = 0 then 0 else [Mentions] / MaxMentions in
            if      ratio >= 0.7 then 5
            else if ratio >= 0.5 then 4
            else if ratio >= 0.3 then 3
            else if ratio >= 0.1 then 2
            else                     1, Int64.Type),

    // 3) Impact = Base_Impact + 1 if severity-language ratio > 2×, capped at 5
    WithImpact = Table.AddColumn(WithLikelihood, "Impact", each
        let
            high = fnCountPattern(RiskText, "significant|material|substantial|severe|major|critical|adverse"),
            low  = fnCountPattern(RiskText, "minor|limited|marginal|minimal|slight"),
            adj  = if high > low * 2 then 1 else 0
        in List.Min({5, [Base_Impact] + adj}), Int64.Type),

    // 4) Risk_Score = Likelihood × Impact
    WithRiskScore = Table.AddColumn(WithImpact, "Risk_Score",
        each [Likelihood] * [Impact], Int64.Type),

    // 5) Risk_Level classification
    WithRiskLevel = Table.AddColumn(WithRiskScore, "Risk_Level", each
        if      [Risk_Score] >= 20 then "Critical"
        else if [Risk_Score] >= 15 then "High"
        else if [Risk_Score] >= 9  then "Medium"
        else if [Risk_Score] >= 4  then "Low"
        else                            "Very Low", type text),

    // 6) Labels + colors + quadrant for the heatmap
    // … Likelihood_Label, Impact_Label, Risk_Color (#FF0000/#FF6B6B/#FFE66D/#4ECDC4),
    //   Quadrant ("High Likelihood / High Impact", etc.) …
in Final
```

> **Severity-language adjustment is global, not per-category.** It counts high- vs low-impact words across the *entire* risk text (not per risk) and applies the +1 uniformly. For Stellantis FY2025 the ratio is **257 high : 9 low → 28.6:1** — so every Base_Impact gets +1 (capped at 5).

### 4.6 `Risk_Level` thresholds

| Risk_Score range | Risk_Level | Color (`Risk_Color`) |
|:---:|:---|:---|
| 20–25 | **Critical** | `#FF0000` |
| 15–19 | **High** | `#FF6B6B` |
| 9–14 | **Medium** | `#FFE66D` |
| 4–8 | **Low** | `#4ECDC4` |
| 1–3 | Very Low | `#888888` |

---

## 5. RISK Page Specification

### 5.1 Page properties

| Property | Value |
|---|---|
| Display name | `RISK` |
| Internal name | `08d15d11b29b52ae0198` |
| Width × Height | 1280 × 720 |
| Display option | `FitToWidth` |
| Outspace pane width | 327 |

### 5.2 Visual inventory

| Visual ID | Type | Position (x, y, w×h) | Bound fields |
|---|---|---|---|
| `d027a30700b939ab54c3` | shape | (0, 0, 1280×38) | — (decorative banner) |
| `5b5e05eabddf74840503` | image | (26, 56, 179×74) | — (logo) |
| `3d1b96e896153c5e1487` | pageNavigator | (525, 56, 582×40) | — |
| `2fac20354bd0b7295428` | textbox | (25, 141, 553×88) | static text: "Risk Assessment" |
| `acda9bbc13074dc88258` | slicer | (676, 202, 254×66) | `risk_heatmap[Risk_Level]` |
| `fbc2cbb1013b272d690b` | **pythonVisual** | (61, 268, 599×433) | 12 `risk_heatmap` columns (full row context) |
| `51df4f4a7bec61583069` | **tableEx** | (676, 300, 584×369) | 5 columns — Risk ID, Risk Score (Sum), Risk Category, Description, **Risk Level** |

### 5.3 Risk register tableEx

| Display Name | Source field | Aggregation | Notes |
|---|---|---|---|
| Risk ID | `risk_heatmap[Risk_ID]` | — | First column |
| Risk_Score | `risk_heatmap[Risk_Score]` | `Sum` (Function: 0) | Sorted descending — drives row order |
| Risk Category | `risk_heatmap[Risk_Category]` | — | |
| Description | `risk_heatmap[Description]` | — | Pre-set width 250 px |
| **Risk Level** | `risk_heatmap[Risk_Level]` | — | Critical / High / Medium / Low |

Formatting: bold + underlined column headers, `#F4F4F4` header background, 9 px row padding, totals row hidden, `Risk_Category` width pre-set to 147 px.

### 5.4 Python heatmap (5×5 matrix)

The Python visual renders the canonical Likelihood × Impact heatmap with bubbles sized by mention frequency. All 12 `risk_heatmap` columns are bound to the `Values` well (Power BI passes the full row context into the script's `dataset` DataFrame).

**Key script parameters (configurable inline):**

```python
FIGURE_WIDTH = 12
FIGURE_HEIGHT = 9
BASE_BUBBLE_SIZE = 180          # px² minimum bubble
BUBBLE_SCALE_FACTOR = 14        # px² added per mention
JITTER_STRENGTH = 0.12          # ± offset to prevent bubble overlap
HEATMAP_COLORS = ['#2ECC71', '#F1C40F', '#E67E22', '#E74C3C', '#C0392B']  # green→red gradient
```

**Background**: 5×5 cell grid coloured by `Likelihood × Impact` product (1 in bottom-left to 25 in top-right).

**Bubbles**: positioned at `(Likelihood, Impact)` with random jitter, sized by `BASE_BUBBLE_SIZE + Mentions × BUBBLE_SCALE_FACTOR`, coloured by `risk_heatmap[Risk_Color]`, labeled with `Risk_ID`.

**Chrome**: legend keyed by Risk_Level (Critical / High / Medium / Low), colorbar showing the 1–25 score gradient, footnote `Bubble size = 20-F Item 3.D mention frequency`, title `Stellantis N.V. FY 2025\nEnterprise Risk Assessment Matrix\n(Item 3.D - Form 20-F)`.

> Visible at `STLA_20-F_Model.Report/definition/pages/08d15d11b29b52ae0198/visuals/fbc2cbb1013b272d690b/visual.json` under `objects.script[0].properties.source` (full Python script embedded as a JSON string).

### 5.5 Verified FY2025 risk register

| Risk_ID | Risk Score | Risk Category | Description (abbrev.) | Risk Level | Mentions |
|:---:|---:|---|---|:---:|---:|
| R03 | **25** | Competition & Market | Legacy OEMs (VW/Toyota/Ford/GM) + Chinese entrants (BYD, Chery, Leapmotor) | Critical | 69 |
| R02 | **20** | Regulatory & Compliance | EU/US/China safety + emissions; Euro 7, GSR, FMVSS | Critical | 44 |
| R04 | **20** | Supply Chain & Raw Materials | Semiconductors, battery materials, supplier health | Critical | 47 |
| R07 | **20** | Cybersecurity & IT Systems | IT breaches, ECU compromise, connected-vehicle data | Critical | 35 |
| R08 | 16 | Macroeconomic & FX | Cyclical demand, inflation, EUR/USD/BRL/ARS exposure | High | 48 |
| R05 | 15 | EV Transition & Electrification | BEV adoption uncertainty, program cancellations | High | 23 |
| R13 | 15 | China & Asia Pacific Operations | DPCA / Leapmotor / Tofas; share 0.2% in China | High | 23 |
| R11 | 15 | Product Quality & Recalls | New-platform quality, Takata litigation | High | 22 |
| R10 | 15 | Labor Relations | UAW / Unifor / Works Council; 85% CBA coverage | High | 24 |
| R09 | 12 | Financial Services & Credit | SFS US, Leasys, BNPP/SCF JVs | Medium | 29 |
| R01 | 10 | Tariffs & Trade Policy | US tariffs on MX/CA/CN/EU; Jeep Cherokee Toluca | Medium | 12 |
| R14 | 8 | Climate & Sustainability | EU CO₂ €95/g penalty, ELV, decarbonization | Low | 11 |
| R15 | 8 | Autonomous & Software | ADAS/GSR mandates, SDV, Archer Aviation | Low | 9 |
| R16 | 8 | Pension & Benefit Obligations | Legacy FCA / PSA pension funding gaps | Low | 19 |
| R17 | 8 | Political & Geopolitical Instability | MEA exposure, banned-country footprint | Low | 19 |
| R18 | 6 | Natural Disasters & Operations | Plant shutdowns, force majeure | Low | 8 |
| R12 | 5 | Emissions Litigation & Investigations | Diesel investigations FR/DE/NL/UK/IT | Low | 5 |
| R06 | 5 | Strategic Reset & Execution | Filosa CEO, May 2026 Investor Day | Low | 2 |

**Totals**: 18 risks. 4 Critical, 5 High, 2 Medium, 7 Low.

### 5.6 Heatmap quadrant interpretation

| Quadrant | Meaning | Stellantis FY2025 occupants |
|---|---|---|
| **High Likelihood / High Impact** (top-right) | Most urgent — manage immediately | R03, R02, R04, R07, R08 |
| **Low Likelihood / High Impact** (top-left) | Tail risks — contingency planning | R05, R13, R11, R10, R01, R09, R14, R15, R16, R17, R12, R06 |
| **High Likelihood / Low Impact** (bottom-right) | Operational nuisances | (none this filing) |
| **Low Likelihood / Low Impact** (bottom-left) | Background noise | R18 |

The cluster of high-impact / low-likelihood items reflects how 20-F risk disclosures are written: every risk is qualitatively "material" by SEC definition, so impact stays high, but mention frequency separates them on the Likelihood axis.

---

## 6. Power BI Agentic Development Framework — Risk Tab Build

### 6.1 Skills used to source the PDF and update the page

| Order | Skill | Purpose |
|:---:|---|---|
| 1 | `pbi-desktop:connect-pbid` | Connect to PBI Desktop's local AS via TOM; trigger TMSL refresh per table |
| 2 | `reports:pbir-cli` | Inspect existing RISK-page visuals and identify visual IDs |
| 3 | `pbip:pbir-format` | Direct PBIR JSON editing for the tableEx + Python visual swap |
| 4 | `pbip:tmdl` | TMDL syntax reference for the `expressions.tmdl` edits |
| 5 | `reports:python-visuals` | Reference for `pythonVisual` field bindings + script source structure |

### 6.2 PDF reconnaissance

Before editing M, locate the Item 3.D section in the new PDF:

```python
from pypdf import PdfReader
r = PdfReader(r'STLA_Power_BI\resources\Stellantis-FY2025-20-F.pdf')
print(f'PAGES: {len(r.pages)}')                     # → 356

# Read TOC
print(r.pages[2].extract_text())                    # Risk Factors → page 80

# Confirm section starts at PDF page 81
for i in [78, 79, 80, 81, 82, 100, 101, 102, 103, 104]:
    print(f'p.{i+1}: {r.pages[i].extract_text()[:200]}')
```

### 6.3 End-to-end command transcript

```powershell
# 1. Close PBI Desktop so TMDL edits land
Get-Process PBIDesktop, msmdsrv | Stop-Process -Force

# 2. Backup project before editing
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item .\STLA_Power_BI\STLA_20-F_Model.SemanticModel ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse
Copy-Item .\STLA_Power_BI\STLA_20-F_Model.Report        ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse

# 3. Edit M expressions: PDF path + section classifier
#    File: STLA_20-F_Model.SemanticModel\definition\expressions.tmdl
#    - 20f_full_text:     update Pdf.Tables path, rewrite WithSection page ranges
#    - 10k_risk_section:  same path/classifier; change filter to "Item 3.D - Risk Factors"

# 4. Edit Python visual title (escaped JSON string — use Python, not Edit tool)
py -c "fp = r'...\\visuals\\fbc2cbb1013b272d690b\\visual.json';
       s = open(fp, encoding='utf-8').read();
       open(fp, 'w', encoding='utf-8').write(s.replace('General Motors FY 2024', 'Stellantis N.V. FY 2025'))"

# 5. Append Risk_Level projection to tableEx
#    File: ...\visuals\51df4f4a7bec61583069\visual.json
#    Add a 5th Column projection on risk_heatmap[Risk_Level]

# 6. Re-launch PBI Desktop, wait for AS to come up
Start-Process .\STLA_Power_BI\STLA_20-F_Model.pbip
# (wait for msmdsrv, capture port via netstat)

# 7. Force-refresh the dependent tables in order
$port = <discovered>
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=localhost:$port")
$db = $server.Databases[0]
foreach ($tbl in @("10k_risk_section", "20f_full_text", "risk_heatmap")) {
    $tmsl = '{ "refresh": { "type": "full", "objects": [{ "database": "' + $db.Name + '", "table": "' + $tbl + '" }] } }'
    $server.Execute($tmsl) | Out-Null
}
$server.Disconnect()

# 8. Verify via ADOMD
$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection
$conn.ConnectionString = "Data Source=localhost:$port"
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "EVALUATE 'risk_heatmap' ORDER BY 'risk_heatmap'[Risk_Score] DESC"
# … iterate reader …
```

### 6.4 Critical sequencing rules

1. **PBI Desktop must be CLOSED** when editing `expressions.tmdl` or any `visual.json`. External edits while open are silently overwritten on the next save.
2. **Refresh dependencies in dependency order**: `20f_full_text` → `10k_risk_section` → `risk_heatmap`. The engine does NOT auto-cascade upstream refreshes when only `risk_heatmap` is refreshed.
3. **`Edit` tool fails on JSON-escaped Python scripts** in `visual.json`. Use `py -c "open(fp).read().replace(old, new)"` for those payloads.
4. **`fnCountPattern` is alternation, not regex.** New patterns must use literal substrings split by `|` — no regex anchors, character classes, or backreferences.

---

## 7. Reproduction / Extension

### 7.1 To update to FY2026 (new 20-F filing)

1. Drop the new PDF at `STLA_Power_BI/resources/Stellantis-FY2026-20-F.pdf`.
2. Either rename to `Stellantis-FY2025-20-F.pdf` (zero code change), OR update the path in both `20f_full_text` and `10k_risk_section` in `expressions.tmdl`.
3. Run pypdf TOC scan to confirm Risk Factors page range hasn't shifted (re-run §6.2). Update the `WithSection` `if [Page_Number] >= 80 …` ranges if needed.
4. Refresh in order (§6.3 step 7).

### 7.2 To add a new risk category

Edit the `#table()` in `RiskCategories_Config` to add a row:

```m
{"R19", "Greenhouse Gas Compliance Cost", "scope 1|scope 2|scope 3|carbon credit|carbon tax|CBAM", "EU CBAM, US SEC climate disclosure, scope-3 supplier emissions", 3}
```

Then refresh `risk_heatmap`. No DAX or visual changes required — the heatmap and tableEx are bound to the table, not to individual rows.

### 7.3 To swap to a different OEM (e.g., Ford, Toyota)

1. Drop the new 10-K / 20-F PDF in `resources/`.
2. Update both M expressions' `Pdf.Tables(...)` path.
3. Run `pypdf` TOC scan to find the new Risk Factors page range; rewrite `WithSection`.
4. **The Risk-category `Search_Pattern`s in `RiskCategories_Config` need to be reviewed** — Stellantis-specific terms (DPCA, Leapmotor, Tofas, BNPP, Filosa) will return 0 mentions in another OEM's filing and skew Likelihood scores. Replace with the new OEM's specific entities.

### 7.4 To restore from backup

```powershell
$backup = "C:\…\STLA_Power_BI\.claude\backups\<timestamp>"
$proj   = "C:\…\STLA_Power_BI"
Get-Process PBIDesktop, msmdsrv | Stop-Process -Force
Remove-Item "$proj\STLA_20-F_Model.SemanticModel", "$proj\STLA_20-F_Model.Report" -Recurse -Force
Copy-Item "$backup\STLA_20-F_Model.SemanticModel" "$proj\" -Recurse
Copy-Item "$backup\STLA_20-F_Model.Report"       "$proj\" -Recurse
```

---

## 8. Known caveats

- **PDF path is absolute and hard-coded** in `20f_full_text` and `10k_risk_section`. Moving the project to another machine requires updating both paths. Centralising via an `expression PdfPath = "..."` would help but requires touching the partition references.
- **`Search_Pattern` regex limitation**: `fnCountPattern` does substring replace, NOT real regex. Patterns with `\b`, `^`, `$`, `[…]`, `(…)`, `?`, `+`, `*` will be treated as literal text and match zero occurrences. Use only `term1|term2|term3` alternation.
- **Severity-language Impact adjustment is global**, not per-category. Every category gets +1 if the *overall* text has high:low impact-word ratio > 2:1 (Stellantis 20-F is 28.6:1). To make per-category adjustments, the M would need to count severity words within each category's matching sentences.
- **R06 Strategic Reset scores Low** because only 2 mentions match its `Search_Pattern` in the Stellantis 20-F Item 3.D text. The Filosa transition / Investor Day narrative lives in other 20-F sections (Management Report). Broaden the pattern to include `Filosa|Investor Day|2026 plan|portfolio realignment` to capture it.
- **The expression name `10k_risk_section` is misleading** — it filters a 20-F now, not a 10-K. Renaming would cascade into `risk_heatmap` partition source + Python visual references. Leave as-is unless doing a coordinated rename.
- **The tableEx column "Risk Score" displays as `Risk_Score`** (with underscore) because `nativeQueryRef` was set during initial build. The displayed header can be overridden via `displayName` in the projection — already done for "Risk ID", "Risk Category", "Risk Level".
- **Page-level filters and slicers persist across page navigation.** If the user filters Risk_Level on the RISK page, the slicer state will apply when they return. Reset via the slicer or page navigator.

---

## 9. References

- `STLA_Power_BI/docs/Semantic_Model_Reference.md` — canonical reference for the full `STLA_20-F_Model` semantic model. See §4 (Data Sources & Lineage), §5 (Query Groups & Power Query Expressions — full M code for `20f_full_text`, `20f_risk_section`, `RiskCategories_Config`, `fnCountPattern`), §5.8 (Mermaid risk-scoring pipeline), and §6 (table catalog entry for `risk_heatmap`).
- `STLA_Power_BI/docs/AOI_Overview.md` — companion documentation for the AOI Overview page and the 88 AOI measures.

## 10. Document changelog

| Date | Change |
|---|---|
| 2026-05-27 | Initial version: PDF source switched from GM 10-K to Stellantis FY2025 20-F, section classifier rewritten, Python visual title updated, Risk Level column added to register tableEx, 18 risks scored. |
| 2026-05-27 | Added § 9 References cross-link to `Semantic_Model_Reference.md`. |
