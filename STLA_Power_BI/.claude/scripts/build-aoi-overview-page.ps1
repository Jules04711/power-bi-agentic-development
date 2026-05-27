[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$reportDir = "C:\Users\golfc\OneDrive\Desktop\Power BI Agentic Development\STLA_Power_BI\STLA_20-F_Model.Report"
$pagesDir  = Join-Path $reportDir "definition\pages"
$pageId    = "AOIOverview"
$pageDir   = Join-Path $pagesDir $pageId
$visualsDir = Join-Path $pageDir "visuals"

if (-not (Test-Path $pagesDir)) { throw "Pages dir missing: $pagesDir" }
New-Item -ItemType Directory -Path $visualsDir -Force | Out-Null

$visContSchema = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.9.0/schema.json"
$pageSchema    = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json"
$pagesSchema   = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json"

function Write-Json($path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 30
    # Use UTF-8 without BOM
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Field-Measure($entity, $name) {
    return [ordered]@{
        Measure = [ordered]@{
            Expression = [ordered]@{ SourceRef = [ordered]@{ Entity = $entity } }
            Property   = $name
        }
    }
}
function Field-Column($entity, $name) {
    return [ordered]@{
        Column = [ordered]@{
            Expression = [ordered]@{ SourceRef = [ordered]@{ Entity = $entity } }
            Property   = $name
        }
    }
}
function Projection-Measure($entity, $name) {
    return [ordered]@{
        field         = (Field-Measure $entity $name)
        queryRef      = "$entity.$name"
        nativeQueryRef = $name
    }
}
function Projection-Column($entity, $name) {
    return [ordered]@{
        field         = (Field-Column $entity $name)
        queryRef      = "$entity.$name"
        nativeQueryRef = $name
        active        = $true
    }
}

function Make-Card($name, $title, $x, $y, $w, $h, $z, $entity, $measure) {
@{
  '$schema' = $visContSchema
  name      = $name
  position  = [ordered]@{ x=$x; y=$y; z=$z; height=$h; width=$w; tabOrder=$z }
  visual    = [ordered]@{
    visualType = "card"
    query      = [ordered]@{
      queryState = [ordered]@{
        Values = [ordered]@{ projections = @( (Projection-Measure $entity $measure) ) }
      }
    }
    objects    = [ordered]@{
      labels    = @(@{ properties = [ordered]@{ fontSize = @{ expr = @{ Literal = @{ Value = "28D" } } }; bold = @{ expr = @{ Literal = @{ Value = "true" } } } } })
      categoryLabels = @(@{ properties = [ordered]@{ show = @{ expr = @{ Literal = @{ Value = "true" } } }; fontSize = @{ expr = @{ Literal = @{ Value = "11D" } } } } })
    }
    visualContainerObjects = [ordered]@{
      title = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        text = @{ expr = @{ Literal = @{ Value = "'" + $title + "'" } } }
        fontSize = @{ expr = @{ Literal = @{ Value = "11D" } } }
        bold     = @{ expr = @{ Literal = @{ Value = "true" } } }
      }})
      background = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        color = @{ solid = @{ color = @{ expr = @{ Literal = @{ Value = "'#FFFFFF'" } } } } }
      }})
      border = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        radius = @{ expr = @{ Literal = @{ Value = "6D" } } }
      }})
    }
    drillFilterOtherVisuals = $true
  }
}
}

function Make-Textbox($name, $text, $x, $y, $w, $h, $z, $fontSize, $bold) {
@{
  '$schema' = $visContSchema
  name      = $name
  position  = [ordered]@{ x=$x; y=$y; z=$z; height=$h; width=$w; tabOrder=$z }
  visual    = [ordered]@{
    visualType = "textbox"
    objects    = [ordered]@{
      general = @(@{ properties = [ordered]@{
        paragraphs = @(@{
          textRuns = @(@{
            value = $text
            textStyle = [ordered]@{
              fontSize  = "$fontSize" + "pt"
              fontFamily = "Segoe UI"
              fontWeight = if ($bold) { "bold" } else { "normal" }
              color = "#1F3A5F"
            }
          })
          horizontalTextAlignment = "left"
        })
      }})
    }
    drillFilterOtherVisuals = $true
  }
}
}

# ---- Page.json ----
$page = [ordered]@{
  '$schema'    = $pageSchema
  name         = $pageId
  displayName  = "AOI Overview"
  displayOption = "FitToPage"
  height       = 720
  width        = 1280
  objects      = [ordered]@{
    background = @(@{ properties = [ordered]@{
      color = @{ solid = @{ color = @{ expr = @{ Literal = @{ Value = "'#F4F6FA'" } } } } }
      transparency = @{ expr = @{ Literal = @{ Value = "0D" } } }
    }})
  }
}
Write-Json (Join-Path $pageDir "page.json") $page

# ---- Visual list ----
$visuals = @()

# Title
$visuals += @{ Folder = "title_textbox"; Json = (Make-Textbox "title_textbox" "FY2025 AOI Overview  -  FaSTLAne 2030 Cost-Cut Lens" 20 20 1240 60 1000 22 $true) }

# Top KPI row (y 100, h 120)
$visuals += @{ Folder = "card_aoi";            Json = (Make-Card "card_aoi"            "Adjusted Operating Income"  20 100 290 120 2001 "AOI_FY2025" "Adjusted Operating Income") }
$visuals += @{ Folder = "card_aoi_margin";     Json = (Make-Card "card_aoi_margin"     "AOI Margin %"              320 100 290 120 2002 "AOI_FY2025" "AOI Margin %") }
$visuals += @{ Folder = "card_gap_to_target";  Json = (Make-Card "card_gap_to_target"  "Gap to 2030 AOI Target"    620 100 290 120 2003 "AOI_FY2025" "Gap to 2030 AOI Target") }
$visuals += @{ Folder = "card_gap_closed";     Json = (Make-Card "card_gap_closed"     "Gap Closed by VCP %"       920 100 290 120 2004 "AOI_FY2025" "Gap Closed by VCP %") }

# Region matrix (pivotTable)
$matrixJson = @{
  '$schema' = $visContSchema
  name      = "matrix_region"
  position  = [ordered]@{ x=20; y=240; z=3001; height=240; width=620; tabOrder=3001 }
  visual    = [ordered]@{
    visualType = "pivotTable"
    query      = [ordered]@{
      queryState = [ordered]@{
        Rows = [ordered]@{ projections = @( (Projection-Column "Region" "Region") ) }
        Values = [ordered]@{ projections = @(
          (Projection-Measure "AOI_FY2025" "Region Net Revenues"),
          (Projection-Measure "AOI_FY2025" "Region AOI"),
          (Projection-Measure "AOI_FY2025" "Region AOI Margin %"),
          (Projection-Measure "AOI_FY2025" "Region Pro-Forma AOI")
        )}
      }
      sortDefinition = [ordered]@{
        sort = @(@{
          field = (Field-Column "Region" "Sort")
          direction = "Ascending"
        })
      }
    }
    visualContainerObjects = [ordered]@{
      title = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        text = @{ expr = @{ Literal = @{ Value = "'Region comparison - AOI, revenue, margin, pro-forma'" } } }
        fontSize = @{ expr = @{ Literal = @{ Value = "12D" } } }
        bold     = @{ expr = @{ Literal = @{ Value = "true" } } }
      }})
      background = @(@{ properties = [ordered]@{ show = @{ expr = @{ Literal = @{ Value = "true" } } }; color = @{ solid = @{ color = @{ expr = @{ Literal = @{ Value = "'#FFFFFF'" } } } } } }})
      border = @(@{ properties = [ordered]@{ show = @{ expr = @{ Literal = @{ Value = "true" } } }; radius = @{ expr = @{ Literal = @{ Value = "6D" } } } }})
    }
    drillFilterOtherVisuals = $true
  }
}
$visuals += @{ Folder = "matrix_region"; Json = $matrixJson }

# Bar chart - Adjustment waterfall (sorted desc by Adjustment Value)
$barJson = @{
  '$schema' = $visContSchema
  name      = "bar_adjustments"
  position  = [ordered]@{ x=660; y=240; z=3002; height=240; width=600; tabOrder=3002 }
  visual    = [ordered]@{
    visualType = "barChart"
    query      = [ordered]@{
      queryState = [ordered]@{
        Category = [ordered]@{ projections = @( (Projection-Column "AdjustmentBridge" "Adjustment") ) }
        Y        = [ordered]@{ projections = @( (Projection-Measure "AOI_FY2025" "Adjustment Value") ) }
        Series   = [ordered]@{ projections = @( (Projection-Column "AdjustmentBridge" "Category") ) }
      }
      sortDefinition = [ordered]@{
        sort = @(@{
          field = (Field-Measure "AOI_FY2025" "Adjustment Value")
          direction = "Descending"
        })
      }
    }
    objects = [ordered]@{
      categoryAxis = @(@{ properties = [ordered]@{
        fontSize = @{ expr = @{ Literal = @{ Value = "10D" } } }
      }})
      valueAxis = @(@{ properties = [ordered]@{
        fontSize = @{ expr = @{ Literal = @{ Value = "9D" } } }
      }})
      labels = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        fontSize = @{ expr = @{ Literal = @{ Value = "9D" } } }
        labelDisplayUnits = @{ expr = @{ Literal = @{ Value = "0D" } } }
      }})
      legend = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        position = @{ expr = @{ Literal = @{ Value = "'TopCenter'" } } }
      }})
    }
    visualContainerObjects = [ordered]@{
      title = @(@{ properties = [ordered]@{
        show = @{ expr = @{ Literal = @{ Value = "true" } } }
        text = @{ expr = @{ Literal = @{ Value = "'Adjustment bridge - FY2025 AOI reconciliation (EUR M)'" } } }
        fontSize = @{ expr = @{ Literal = @{ Value = "12D" } } }
        bold     = @{ expr = @{ Literal = @{ Value = "true" } } }
      }})
      background = @(@{ properties = [ordered]@{ show = @{ expr = @{ Literal = @{ Value = "true" } } }; color = @{ solid = @{ color = @{ expr = @{ Literal = @{ Value = "'#FFFFFF'" } } } } } }})
      border = @(@{ properties = [ordered]@{ show = @{ expr = @{ Literal = @{ Value = "true" } } }; radius = @{ expr = @{ Literal = @{ Value = "6D" } } } }})
    }
    drillFilterOtherVisuals = $true
  }
}
$visuals += @{ Folder = "bar_adjustments"; Json = $barJson }

# Bottom strategic narrative cards (y 500, h 120)
$visuals += @{ Folder = "card_strategic_reset"; Json = (Make-Card "card_strategic_reset" "Strategic Realignment Charges (2030 reset)" 20 500 290 120 4001 "AOI_FY2025" "Strategic Realignment Charges") }
$visuals += @{ Folder = "card_one_time";        Json = (Make-Card "card_one_time"        "One-Time Charges (gone in 2026+)"          320 500 290 120 4002 "AOI_FY2025" "One-Time Charges - Non-Recurring") }
$visuals += @{ Folder = "card_pro_forma";       Json = (Make-Card "card_pro_forma"       "AOI After VCP Save (Pro-Forma)"            620 500 290 120 4003 "AOI_FY2025" "AOI After VCP Save (FY2025 Pro-Forma)") }
$visuals += @{ Folder = "card_annual_lift";     Json = (Make-Card "card_annual_lift"     "Annual AOI Lift Required (2026-2030)"      920 500 290 120 4004 "AOI_FY2025" "Implied Annual AOI Lift Required (2026-2030)") }

# Write all visuals
foreach ($v in $visuals) {
    $vdir = Join-Path $visualsDir $v.Folder
    New-Item -ItemType Directory -Path $vdir -Force | Out-Null
    Write-Json (Join-Path $vdir "visual.json") $v.Json
}

# Update pages.json
$pagesJsonPath = Join-Path $pagesDir "pages.json"
$pagesObj = Get-Content -Raw $pagesJsonPath | ConvertFrom-Json
$existing = @($pagesObj.pageOrder)
if (-not ($existing -contains $pageId)) {
    # Insert AOIOverview right after the current AOI page (ef0b43dedcae9040717c)
    $aoiOldId = "ef0b43dedcae9040717c"
    $newOrder = @()
    foreach ($p in $existing) {
        $newOrder += $p
        if ($p -eq $aoiOldId) { $newOrder += $pageId }
    }
    if (-not ($newOrder -contains $pageId)) { $newOrder += $pageId }
    $pagesObj.pageOrder = $newOrder
    # Optional: make the new page active so user lands on it
    $pagesObj.activePageName = $pageId
    Write-Json $pagesJsonPath $pagesObj
    Write-Output "Added '$pageId' to pages.json"
} else {
    Write-Output "'$pageId' already present in pages.json"
}

Write-Output "Created page at: $pageDir"
Write-Output "Visuals: $($visuals.Count)"
