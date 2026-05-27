param(
    [Parameter(Mandatory=$true)][int]$Port,
    [string]$OutputPath = "$(Resolve-Path '..\..\..\').Path + 'tmp\model_snapshot.json'"
)

$ErrorActionPreference = 'Stop'

$tomBase = Join-Path $env:TEMP 'tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45'
Add-Type -Path (Join-Path $tomBase 'Microsoft.AnalysisServices.Core.dll')
Add-Type -Path (Join-Path $tomBase 'Microsoft.AnalysisServices.Tabular.dll')
Add-Type -Path (Join-Path $tomBase 'Microsoft.AnalysisServices.Tabular.Json.dll')

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=localhost:$Port")
$db = $server.Databases[0]
$model = $db.Model

function Get-Annotations($obj) {
    $list = @()
    foreach ($a in $obj.Annotations) { $list += @{ name = $a.Name; value = $a.Value } }
    return $list
}

function Get-ExtendedProperties($obj) {
    $list = @()
    try {
        foreach ($p in $obj.ExtendedProperties) { $list += @{ name = $p.Name; value = $p.Value } }
    } catch {}
    return $list
}

$snapshot = [ordered]@{}

$snapshot.database = [ordered]@{
    name = $db.Name
    id   = $db.ID
    compatibilityLevel = $db.CompatibilityLevel
    compatibilityMode  = "$($db.CompatibilityMode)"
    modelName = $model.Name
    modelDescription = $model.Description
    culture = $model.Culture
    defaultMode = "$($model.DefaultMode)"
    discourageImplicitMeasures = $model.DiscourageImplicitMeasures
    sourceQueryCulture = $model.SourceQueryCulture
    storageLocation = $model.StorageLocation
    annotations = Get-Annotations $model
}

# Query Groups
$snapshot.queryGroups = @()
foreach ($qg in $model.QueryGroups) {
    $snapshot.queryGroups += [ordered]@{
        folder = $qg.Folder
        description = $qg.Description
        annotations = Get-Annotations $qg
    }
}

# Shared M Expressions
$snapshot.expressions = @()
foreach ($e in $model.Expressions) {
    $snapshot.expressions += [ordered]@{
        name = $e.Name
        kind = "$($e.Kind)"
        queryGroup = if ($e.QueryGroup) { $e.QueryGroup.Folder } else { $null }
        description = $e.Description
        expression = $e.Expression
        annotations = Get-Annotations $e
    }
}

# Tables
$snapshot.tables = @()
foreach ($t in $model.Tables) {
    $tableObj = [ordered]@{
        name = $t.Name
        description = $t.Description
        isHidden = $t.IsHidden
        isPrivate = $t.IsPrivate
        lineageTag = $t.LineageTag
        dataCategory = $t.DataCategory
        showAsVariationsOnly = $t.ShowAsVariationsOnly
        excludeFromModelRefresh = $t.ExcludeFromModelRefresh
        queryGroup = if ($t.Partitions.Count -gt 0 -and $t.Partitions[0].QueryGroup) { $t.Partitions[0].QueryGroup.Folder } else { $null }
        annotations = Get-Annotations $t
    }

    # Partitions
    $tableObj.partitions = @()
    foreach ($p in $t.Partitions) {
        $srcKind = "$($p.Source.GetType().Name)"
        $expr = ""
        if ($p.Source -is [Microsoft.AnalysisServices.Tabular.MPartitionSource]) {
            $expr = $p.Source.Expression
        } elseif ($p.Source -is [Microsoft.AnalysisServices.Tabular.CalculatedPartitionSource]) {
            $expr = $p.Source.Expression
        } elseif ($p.Source -is [Microsoft.AnalysisServices.Tabular.EntityPartitionSource]) {
            $expr = "EntityName=$($p.Source.EntityName); ExpressionSource=$($p.Source.ExpressionSource)"
        }
        $tableObj.partitions += [ordered]@{
            name = $p.Name
            mode = "$($p.Mode)"
            sourceKind = $srcKind
            state = "$($p.State)"
            expression = $expr
        }
    }

    # Columns
    $tableObj.columns = @()
    foreach ($c in $t.Columns) {
        $colObj = [ordered]@{
            name = $c.Name
            type = "$($c.Type)"
            dataType = "$($c.DataType)"
            isHidden = $c.IsHidden
            isKey = $c.IsKey
            isNullable = $c.IsNullable
            isUnique = $c.IsUnique
            summarizeBy = "$($c.SummarizeBy)"
            sortByColumn = if ($c.SortByColumn) { $c.SortByColumn.Name } else { $null }
            formatString = $c.FormatString
            displayFolder = $c.DisplayFolder
            description = $c.Description
            lineageTag = $c.LineageTag
            dataCategory = $c.DataCategory
        }
        if ($c -is [Microsoft.AnalysisServices.Tabular.DataColumn]) {
            $colObj.sourceColumn = $c.SourceColumn
        }
        if ($c -is [Microsoft.AnalysisServices.Tabular.CalculatedColumn]) {
            $colObj.expression = $c.Expression
        }
        if ($c -is [Microsoft.AnalysisServices.Tabular.CalculatedTableColumn]) {
            $colObj.columnOrigin = $c.ColumnOriginName
            $colObj.expression = $c.SourceColumn
        }
        $tableObj.columns += $colObj
    }

    # Measures
    $tableObj.measures = @()
    foreach ($m in $t.Measures) {
        $tableObj.measures += [ordered]@{
            name = $m.Name
            expression = $m.Expression
            formatString = $m.FormatString
            displayFolder = $m.DisplayFolder
            description = $m.Description
            isHidden = $m.IsHidden
            lineageTag = $m.LineageTag
            dataCategory = $m.DataCategory
            kpi = if ($m.KPI) { @{ statusGraphic = $m.KPI.StatusGraphic; targetExpression = $m.KPI.TargetExpression; statusExpression = $m.KPI.StatusExpression } } else { $null }
        }
    }

    # Hierarchies
    $tableObj.hierarchies = @()
    foreach ($h in $t.Hierarchies) {
        $levels = @()
        foreach ($l in $h.Levels) { $levels += @{ name = $l.Name; ordinal = $l.Ordinal; column = $l.Column.Name } }
        $tableObj.hierarchies += [ordered]@{
            name = $h.Name
            isHidden = $h.IsHidden
            description = $h.Description
            levels = $levels
        }
    }

    $snapshot.tables += $tableObj
}

# Relationships
$snapshot.relationships = @()
foreach ($r in $model.Relationships) {
    $snapshot.relationships += [ordered]@{
        name = $r.Name
        fromTable  = $r.FromTable.Name
        fromColumn = $r.FromColumn.Name
        toTable    = $r.ToTable.Name
        toColumn   = $r.ToColumn.Name
        fromCardinality = "$($r.FromCardinality)"
        toCardinality   = "$($r.ToCardinality)"
        crossFilteringBehavior = "$($r.CrossFilteringBehavior)"
        securityFilteringBehavior = "$($r.SecurityFilteringBehavior)"
        isActive = $r.IsActive
        joinOnDateBehavior = "$($r.JoinOnDateBehavior)"
        relyOnReferentialIntegrity = $r.RelyOnReferentialIntegrity
    }
}

# Roles
$snapshot.roles = @()
foreach ($role in $model.Roles) {
    $tablePerms = @()
    foreach ($tp in $role.TablePermissions) {
        $tablePerms += @{ table = $tp.Table.Name; filterExpression = $tp.FilterExpression }
    }
    $members = @()
    foreach ($member in $role.Members) {
        $members += @{ name = $member.Name; type = "$($member.GetType().Name)" }
    }
    $snapshot.roles += [ordered]@{
        name = $role.Name
        modelPermission = "$($role.ModelPermission)"
        description = $role.Description
        tablePermissions = $tablePerms
        members = $members
    }
}

# Cultures
$snapshot.cultures = @()
foreach ($cu in $model.Cultures) {
    $snapshot.cultures += [ordered]@{
        name = $cu.Name
        translationCount = $cu.ObjectTranslations.Count
    }
}

# Perspectives
$snapshot.perspectives = @()
foreach ($pe in $model.Perspectives) {
    $snapshot.perspectives += [ordered]@{
        name = $pe.Name
        description = $pe.Description
        tableCount = $pe.PerspectiveTables.Count
    }
}

# Data Sources (legacy)
$snapshot.dataSources = @()
foreach ($ds in $model.DataSources) {
    $snapshot.dataSources += [ordered]@{
        name = $ds.Name
        type = "$($ds.Type)"
        description = $ds.Description
    }
}

$snapshot.counts = [ordered]@{
    tables = $model.Tables.Count
    visibleTables = ($model.Tables | Where-Object { -not $_.IsHidden }).Count
    measures = ($model.Tables | ForEach-Object { $_.Measures.Count } | Measure-Object -Sum).Sum
    relationships = $model.Relationships.Count
    expressions = $model.Expressions.Count
    queryGroups = $model.QueryGroups.Count
    roles = $model.Roles.Count
    cultures = $model.Cultures.Count
    perspectives = $model.Perspectives.Count
}

# Write
$outDir = Split-Path $OutputPath -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$json = $snapshot | ConvertTo-Json -Depth 20
$json | Out-File -FilePath $OutputPath -Encoding utf8

Write-Output "Wrote snapshot to $OutputPath"
Write-Output "Counts: $($snapshot.counts | ConvertTo-Json -Compress)"

$server.Disconnect()
