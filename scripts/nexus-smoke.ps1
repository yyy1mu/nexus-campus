param(
  [string] $BaseUrl,
  [string] $EnvFile,
  [switch] $SkipAuthenticated,
  [switch] $SkipWrites
)

$ErrorActionPreference = "Stop"

$Script:Failures = 0
$Script:Skips = 0

function Resolve-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Read-NexusEnv {
  param([string] $Path)

  $values = @{}

  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match "^\s*#" -or $line -notmatch "=") {
      continue
    }

    $parts = $line -split "=", 2
    $values[$parts[0].Trim()] = $parts[1]
  }

  return $values
}

function Join-Url {
  param(
    [string] $Base,
    [string] $Path
  )

  return $Base.TrimEnd("/") + "/" + $Path.TrimStart("/")
}

function Pass {
  param(
    [string] $Name,
    [string] $Detail = ""
  )

  if ($Detail) {
    Write-Host "[PASS] $Name - $Detail"
  } else {
    Write-Host "[PASS] $Name"
  }
}

function Fail {
  param(
    [string] $Name,
    [string] $Detail
  )

  $Script:Failures++
  Write-Host "[FAIL] $Name - $Detail"
}

function Skip {
  param(
    [string] $Name,
    [string] $Detail
  )

  $Script:Skips++
  Write-Host "[SKIP] $Name - $Detail"
}

function Invoke-NexusHttp {
  param(
    [string] $Method,
    [string] $Path,
    [hashtable] $Headers = @{},
    $Body = $null,
    [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession = $null
  )

  $params = @{
    Method = $Method
    Uri = (Join-Url $Script:BaseUrl $Path)
    UseBasicParsing = $true
    TimeoutSec = 25
    Headers = $Headers
  }

  if ($null -ne $WebSession) {
    $params["WebSession"] = $WebSession
  }

  if ($null -ne $Body) {
    $params["ContentType"] = "application/json"
    $params["Body"] = ($Body | ConvertTo-Json -Depth 32 -Compress)
  }

  try {
    $response = Invoke-WebRequest @params
    $content = Convert-ToUtf8Text $response.Content

    return [pscustomobject] @{
      Status = [int] $response.StatusCode
      Content = $content
      Length = [int] $response.RawContentLength
    }
  } catch [System.Net.WebException] {
    $webResponse = $_.Exception.Response

    if (-not $webResponse) {
      throw
    }

    $reader = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
    $content = $reader.ReadToEnd()

    return [pscustomobject] @{
      Status = [int] $webResponse.StatusCode
      Content = [string] $content
      Length = [int] $content.Length
    }
  }
}

function Convert-ToUtf8Text {
  param($Content)

  if ($null -eq $Content) {
    return ""
  }

  if ($Content -is [byte[]]) {
    return [System.Text.Encoding]::UTF8.GetString($Content)
  }

  if ($Content -is [System.Array] -and $Content.Length -gt 0 -and $Content[0] -is [byte]) {
    return [System.Text.Encoding]::UTF8.GetString([byte[]] $Content)
  }

  return [string] $Content
}

function Assert-Status {
  param(
    [string] $Name,
    [string] $Method,
    [string] $Path,
    [int[]] $Expected,
    [hashtable] $Headers = @{},
    $Body = $null,
    [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession = $null
  )

  $response = Invoke-NexusHttp -Method $Method -Path $Path -Headers $Headers -Body $Body -WebSession $WebSession

  if ($Expected -contains $response.Status) {
    Pass $Name "$Method $Path -> $($response.Status)"
  } else {
    Fail $Name "$Method $Path returned $($response.Status), expected $($Expected -join ",")"
  }

  return $response
}

function Assert-Contains {
  param(
    [string] $Name,
    [string] $Content,
    [string] $Needle
  )

  if ($Content.Contains($Needle)) {
    Pass $Name
  } else {
    Fail $Name "missing expected text: $Needle"
  }
}

function Assert-HeaderContains {
  param(
    [string] $Name,
    [string] $Path,
    [string] $HeaderName,
    [string] $Needle
  )

  try {
    $response = Invoke-WebRequest -Method "HEAD" -Uri (Join-Url $Script:BaseUrl $Path) -UseBasicParsing -TimeoutSec 25
    $value = [string] $response.Headers[$HeaderName]

    if ($value.Contains($Needle)) {
      Pass $Name $value
    } else {
      Fail $Name "header $HeaderName was '$value', expected to contain '$Needle'"
    }
  } catch {
    Fail $Name $_.Exception.Message
  }
}

function Assert-JsonPath {
  param(
    [string] $Name,
    $Object,
    [string] $PropertyName
  )

  $names = @($Object.PSObject.Properties | ForEach-Object { $_.Name })

  if ($names -contains $PropertyName) {
    Pass $Name $PropertyName
  } else {
    Fail $Name "missing JSON property: $PropertyName"
  }
}

function As-Array {
  param($Value)

  if ($null -eq $Value) {
    return @()
  }

  if ($Value -is [System.Array]) {
    return @($Value)
  }

  return @($Value)
}

$repoRoot = Resolve-RepoRoot

if (-not $EnvFile) {
  $EnvFile = Join-Path $repoRoot "storage\nexus\agent-api.env"
}

$envValues = Read-NexusEnv -Path $EnvFile

if (-not $BaseUrl) {
  $BaseUrl = $envValues["NEXUS_BASE_URL"]
}

if (-not $BaseUrl) {
  $BaseUrl = "http://10.98.65.32:8080"
}

$Script:BaseUrl = $BaseUrl.TrimEnd("/")
$authHeader = $envValues["NEXUS_AGENT_AUTH"]
$coreMatrixKeysSnake = @(
  "create_help_request",
  "find_candidate_helpers",
  "dispatch_to_helper",
  "respond_to_dispatch",
  "respond_to_match_offer",
  "send_match_message",
  "poll_work_queue"
)
$coreMatrixKeysCamel = @(
  "createHelpRequest",
  "findCandidateHelpers",
  "dispatchToHelper",
  "respondToDispatch",
  "respondToMatchOffer",
  "sendMatchMessage",
  "pollWorkQueue"
)
$forumMatrixKeysSnake = @(
  "search_forum_discussions",
  "open_forum_discussion",
  "create_forum_discussion",
  "reply_to_forum_discussion",
  "recover_my_forum_discussions",
  "recover_my_forum_posts",
  "edit_own_forum_post",
  "hide_own_forum_post"
)
$forumMatrixKeysCamel = @(
  "searchForumDiscussions",
  "openForumDiscussion",
  "createForumDiscussion",
  "replyToForumDiscussion",
  "recoverMyForumDiscussions",
  "recoverMyForumPosts",
  "editOwnForumPost",
  "hideOwnForumPost"
)

Write-Host "Nexus smoke target: $Script:BaseUrl"
Write-Host "Repo root: $repoRoot"
Write-Host "Authenticated checks: $(-not $SkipAuthenticated)"
Write-Host "Write checks: $(-not $SkipWrites)"
Write-Host ""

$publicPaths = @(
  "/",
  "/assets/forum.js",
  "/assets/forum.css",
  "/api/nexus/agent-health",
  "/llms.txt",
  "/docs/",
  "/docs/agent-tools.json",
  "/docs/agent-quickstart.md",
  "/docs/agent-recipes.md",
  "/docs/index.md",
  "/docs/llms.txt",
  "/docs/nexus-skill.md",
  "/.well-known/nexus-agent.json",
  "/schemas/nexus-agent-manifest.v1.json",
  "/docs/openapi.json"
)

foreach ($path in $publicPaths) {
  $response = Assert-Status "public $path" "GET" $path @(200)

  if ($response.Length -le 0) {
    Fail "public $path content" "empty response"
  }
}

$agentHealthResponse = Invoke-NexusHttp -Method "GET" -Path "/api/nexus/agent-health"
try {
  $agentHealth = $agentHealthResponse.Content | ConvertFrom-Json
  if ($agentHealth.data.type -eq "nexus-agent-health") {
    Pass "agent health type"
  } else {
    Fail "agent health type" "unexpected type: $($agentHealth.data.type)"
  }

  $agentHealthAttrs = $agentHealth.data.attributes
  Assert-JsonPath "agent health has status" $agentHealthAttrs "status"
  Assert-JsonPath "agent health has docs" $agentHealthAttrs "docs"
  Assert-JsonPath "agent health docs has root agent entry" $agentHealthAttrs.docs "rootAgentEntry"
  Assert-JsonPath "agent health docs has agent tools" $agentHealthAttrs.docs "agentTools"
  Assert-JsonPath "agent health docs has agent recipes" $agentHealthAttrs.docs "agentRecipes"
  Assert-JsonPath "agent health has OpenAPI tooling" $agentHealthAttrs "openApiTooling"
  Assert-JsonPath "agent health has endpoints" $agentHealthAttrs "endpoints"
  Assert-JsonPath "agent health has checks" $agentHealthAttrs "checks"
  Assert-JsonPath "agent health has nextActions" $agentHealthAttrs "nextActions"
  Assert-JsonPath "agent health endpoints has agent context" $agentHealthAttrs.endpoints "agentContext"
  Assert-JsonPath "agent health endpoints has preflight" $agentHealthAttrs.endpoints "agentPreflight"
  Assert-JsonPath "agent health tooling has core operationIds" $agentHealthAttrs.openApiTooling "coreOperationIds"
  Assert-JsonPath "agent health tooling has agent tool contract" $agentHealthAttrs.openApiTooling "agentToolContract"
  Assert-JsonPath "agent health tooling has core tool matrix" $agentHealthAttrs.openApiTooling "coreToolMatrix"
  Assert-JsonPath "agent health tooling has forum operationIds" $agentHealthAttrs.openApiTooling "forumOperationIds"
  Assert-JsonPath "agent health tooling has forum tool matrix" $agentHealthAttrs.openApiTooling "forumToolMatrix"
  if ($agentHealthAttrs.openApiTooling.coreOperationIds.agentPreflight -eq "nexusAgentPreflightCreate" -and $agentHealthAttrs.openApiTooling.coreOperationIds.myWorkItems -eq "nexusMyWorkItemsList") {
    Pass "agent health exposes runtime core operationIds"
  } else {
    Fail "agent health exposes runtime core operationIds" "agentPreflight=$($agentHealthAttrs.openApiTooling.coreOperationIds.agentPreflight) myWorkItems=$($agentHealthAttrs.openApiTooling.coreOperationIds.myWorkItems)"
  }
  if ($agentHealthAttrs.openApiTooling.coreToolMatrix.createHelpRequest.writeOperationId -eq "nexusHelpRequestCreate" -and $agentHealthAttrs.openApiTooling.coreToolMatrix.findCandidateHelpers.readOperationId -eq "nexusHelpCandidatesList" -and $agentHealthAttrs.openApiTooling.coreToolMatrix.pollWorkQueue.readOperationId -eq "nexusMyWorkItemsList") {
    Pass "agent health exposes runtime core tool matrix"
  } else {
    Fail "agent health exposes runtime core tool matrix" "unexpected coreToolMatrix"
  }
  $agentHealthMatrixKeys = @($agentHealthAttrs.openApiTooling.coreToolMatrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingAgentHealthMatrixKeys = @($coreMatrixKeysCamel | Where-Object { $agentHealthMatrixKeys -notcontains $_ })
  if ($missingAgentHealthMatrixKeys.Count -eq 0) {
    Pass "agent health core tool matrix has all core tasks"
  } else {
    Fail "agent health core tool matrix has all core tasks" "missing=$($missingAgentHealthMatrixKeys -join ",")"
  }
  if ($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow -eq "nexusForumDiscussionShow" -and $agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate -eq "nexusForumDiscussionCreate" -and $agentHealthAttrs.openApiTooling.forumOperationIds.myForumPosts -eq "nexusMyForumPostsList") {
    Pass "agent health exposes runtime forum operationIds"
  } else {
    Fail "agent health exposes runtime forum operationIds" "forumDiscussionShow=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow) forumDiscussionCreate=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate) myForumPosts=$($agentHealthAttrs.openApiTooling.forumOperationIds.myForumPosts)"
  }
  $agentHealthForumMatrixKeys = @($agentHealthAttrs.openApiTooling.forumToolMatrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingAgentHealthForumMatrixKeys = @($forumMatrixKeysCamel | Where-Object { $agentHealthForumMatrixKeys -notcontains $_ })
  if ($missingAgentHealthForumMatrixKeys.Count -eq 0) {
    Pass "agent health forum tool matrix has all forum tasks"
  } else {
    Fail "agent health forum tool matrix has all forum tasks" "missing=$($missingAgentHealthForumMatrixKeys -join ",")"
  }
  $agentHealthReplyReadFirst = @(As-Array $agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.readFirst | ForEach-Object { [string] $_.name })
  if ($agentHealthAttrs.openApiTooling.forumToolMatrix.openForumDiscussion.readOperationId -eq "nexusForumDiscussionShow" -and ($agentHealthReplyReadFirst -contains "open_forum_discussion") -and $agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.writeOperationId -eq "nexusForumDiscussionCreate" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.writeOperationId -eq "nexusForumDiscussionPostCreate" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.recoverMyForumPosts.readOperationId -eq "nexusMyForumPostsList" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.hideOwnForumPost.writeOperationId -eq "nexusForumPostDelete") {
    Pass "agent health exposes runtime forum tool matrix"
  } else {
    Fail "agent health exposes runtime forum tool matrix" "unexpected forumToolMatrix"
  }
  if ($agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.responseSchemaRef -eq "#/components/schemas/FlarumDiscussionDocument" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.editOwnForumPost.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument") {
    Pass "agent health forum write tasks use concrete response schemas"
  } else {
    Fail "agent health forum write tasks use concrete response schemas" "create=$($agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.responseSchemaRef) reply=$($agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.responseSchemaRef) edit=$($agentHealthAttrs.openApiTooling.forumToolMatrix.editOwnForumPost.responseSchemaRef)"
  }
  $agentHealthToolingTags = @(As-Array $agentHealthAttrs.openApiTooling.tags | ForEach-Object { [string] $_ })
  if ($agentHealthToolingTags -contains "Nexus Agent Skill") {
    Pass "agent health exposes OpenAPI tool tags"
  } else {
    Fail "agent health exposes OpenAPI tool tags" "tags=$($agentHealthToolingTags -join ",")"
  }
  if ([string] $agentHealthAttrs.docs.rootAgentEntry -eq (Join-Url $Script:BaseUrl "/llms.txt") -and [string] $agentHealthAttrs.docs.agentTools -eq (Join-Url $Script:BaseUrl "/docs/agent-tools.json") -and [string] $agentHealthAttrs.docs.agentRecipes -eq (Join-Url $Script:BaseUrl "/docs/agent-recipes.md") -and [string] $agentHealthAttrs.docs.openapi -eq (Join-Url $Script:BaseUrl "/docs/openapi.json") -and [string] $agentHealthAttrs.docs.manifest -eq (Join-Url $Script:BaseUrl "/.well-known/nexus-agent.json")) {
    Pass "agent health docs use request origin"
  } else {
    Fail "agent health docs use request origin" "root=$($agentHealthAttrs.docs.rootAgentEntry) tools=$($agentHealthAttrs.docs.agentTools) recipes=$($agentHealthAttrs.docs.agentRecipes) openapi=$($agentHealthAttrs.docs.openapi) manifest=$($agentHealthAttrs.docs.manifest)"
  }
  if ([string] $agentHealthAttrs.openApiTooling.agentToolContract -eq "/docs/agent-tools.json") {
    Pass "agent health tooling exposes agent tool contract"
  } else {
    Fail "agent health tooling exposes agent tool contract" "agentToolContract=$($agentHealthAttrs.openApiTooling.agentToolContract)"
  }
  if ($agentHealthAttrs.capabilities.llmProviderOptionalForLocalAgents -eq $true) {
    Pass "agent health says LLM provider optional"
  } else {
    Fail "agent health says LLM provider optional" "llmProviderOptionalForLocalAgents=$($agentHealthAttrs.capabilities.llmProviderOptionalForLocalAgents)"
  }
  if ($agentHealthAttrs.status -eq "ok" -and $agentHealthAttrs.notes.doesNotReturnPrivateState -eq $true -and $agentHealthAttrs.notes.doesNotReplaceAgentContext -eq $true) {
    Pass "agent health is public diagnostic only"
  } else {
    Fail "agent health is public diagnostic only" "status=$($agentHealthAttrs.status)"
  }
} catch {
  Fail "agent health parses as JSON" $_.Exception.Message
}

$docsIndex = Invoke-NexusHttp -Method "GET" -Path "/docs/index.md"
Assert-HeaderContains "root llms content type" "/llms.txt" "Content-Type" "text/plain"
Assert-HeaderContains "docs markdown content type" "/docs/nexus-skill.md" "Content-Type" "text/markdown"
Assert-HeaderContains "quickstart markdown content type" "/docs/agent-quickstart.md" "Content-Type" "text/markdown"
Assert-HeaderContains "agent recipes markdown content type" "/docs/agent-recipes.md" "Content-Type" "text/markdown"
$agentToolsResponse = Invoke-NexusHttp -Method "GET" -Path "/docs/agent-tools.json"
$quickstart = Invoke-NexusHttp -Method "GET" -Path "/docs/agent-quickstart.md"
$agentRecipes = Invoke-NexusHttp -Method "GET" -Path "/docs/agent-recipes.md"
Assert-Contains "docs mention root llms" $docsIndex.Content "/llms.txt"
Assert-Contains "docs mention agent tools" $docsIndex.Content "/docs/agent-tools.json"
Assert-Contains "docs mention agent quickstart" $docsIndex.Content "/docs/agent-quickstart.md"
Assert-Contains "docs mention agent recipes" $docsIndex.Content "/docs/agent-recipes.md"
Assert-Contains "docs mention Nexus skill" $docsIndex.Content "/docs/nexus-skill.md"
Assert-Contains "docs mention LLM settings UI" $docsIndex.Content "Settings -> Nexus LLM provider"
Assert-Contains "docs mention optional LLM for local agents" $docsIndex.Content "LLM provider settings are optional"
Assert-Contains "docs mention write-only API key" $docsIndex.Content "write-only"
Assert-Contains "docs mention Developer Tokens" $docsIndex.Content "Developer Tokens"
Assert-Contains "docs mention Nexus local agent token prefix" $docsIndex.Content "Nexus local agent"
Assert-Contains "docs mention raw Flarum write boundary" $docsIndex.Content "raw Flarum writes"
Assert-Contains "docs mention Security token page" $docsIndex.Content "/u/<username>/security"
Assert-Contains "docs mention token endpoint" $docsIndex.Content "/api/token"
Assert-Contains "docs mention access tokens endpoint" $docsIndex.Content "/api/access-tokens"
Assert-Contains "docs mention agent health" $docsIndex.Content "/api/nexus/agent-health"
Assert-Contains "docs mention agent preflight" $docsIndex.Content "/api/nexus/agent-preflight"
Assert-Contains "docs mention need drafts" $docsIndex.Content "/api/nexus/need-drafts"
Assert-Contains "docs mention discoveryPlan" $docsIndex.Content "discoveryPlan"
Assert-Contains "docs mention labelReuse" $docsIndex.Content "labelReuse"
Assert-Contains "docs mention agent context" $docsIndex.Content "/api/nexus/me/agent-context"
Assert-Contains "docs mention agent readiness" $docsIndex.Content "agentReadiness"
Assert-Contains "docs mention skill instructions" $docsIndex.Content "skillInstructions"
Assert-Contains "docs mention skill label reuse runbook" $docsIndex.Content "skillInstructions.labelReuse"
Assert-Contains "docs mention skill candidate routing runbook" $docsIndex.Content "skillInstructions.candidateRouting"
Assert-Contains "docs mention skill error recovery runbook" $docsIndex.Content "skillInstructions.errorRecovery"
Assert-Contains "docs mention preflight recovery" $docsIndex.Content "attributes.recovery"
Assert-Contains "docs mention preflight action catalog" $docsIndex.Content "agentPreflight.actions"
Assert-Contains "docs mention preflight target type" $docsIndex.Content "targetType"
Assert-Contains "docs mention preflight proposed fields" $docsIndex.Content "proposedFields"
Assert-Contains "docs mention preflight schema refs" $docsIndex.Content "writeBodySchemaRef"
Assert-Contains "docs mention preflight side effects" $docsIndex.Content "sideEffects"
Assert-Contains "docs mention preflight example body" $docsIndex.Content "examplePreflightBody"
Assert-Contains "docs mention nextAction catalogAction" $docsIndex.Content "catalogAction"
Assert-Contains "docs mention self-describing nextActions" $docsIndex.Content "self-describing recovery recipes"
Assert-Contains "docs mention OpenAPI concrete schemas" $docsIndex.Content "AgentProfileDocument"
Assert-Contains "docs mention core tool matrix schema" $docsIndex.Content "AgentCoreToolMatrix"
Assert-Contains "docs mention help request document schema" $docsIndex.Content "HelpRequestDocument"
Assert-Contains "docs mention candidate collection schema" $docsIndex.Content "HelpCandidateCollectionDocument"
Assert-Contains "docs mention work item collection schema" $docsIndex.Content "WorkItemCollectionDocument"
Assert-Contains "docs mention endpoint map schema" $docsIndex.Content "AgentEndpointMap"
Assert-Contains "docs mention OpenAPI operationId" $docsIndex.Content "operationId"
Assert-Contains "docs mention core operationId" $docsIndex.Content "nexusAgentPreflightCreate"
Assert-Contains "docs mention work queue operationId" $docsIndex.Content "nexusMyWorkItemsList"
Assert-Contains "docs mention runtime OpenAPI tooling" $docsIndex.Content "openApiTooling"
Assert-Contains "docs mention runtime agent tool contract" $docsIndex.Content "openApiTooling.agentToolContract"
Assert-Contains "docs mention runtime docs agentTools" $docsIndex.Content "docs.agentTools"
Assert-Contains "docs mention runtime core operationIds" $docsIndex.Content "openApiTooling.coreOperationIds"
Assert-Contains "docs mention runtime core tool matrix" $docsIndex.Content "openApiTooling.coreToolMatrix"
Assert-Contains "docs mention runtime forum operationIds" $docsIndex.Content "openApiTooling.forumOperationIds"
Assert-Contains "docs mention runtime forum tool matrix" $docsIndex.Content "openApiTooling.forumToolMatrix"
Assert-Contains "docs mention forum open operationId" $docsIndex.Content "nexusForumDiscussionShow"
Assert-Contains "docs mention forum open endpoint" $docsIndex.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "docs mention skill task recipes" $docsIndex.Content "skillInstructions.taskRecipes"
Assert-Contains "docs mention skill forum task recipes" $docsIndex.Content "skillInstructions.taskRecipes.forumMatrix"
Assert-Contains "docs mention OpenAPI root agent entry" $docsIndex.Content "x-nexus-agent-skill.root_agent_entry"
Assert-Contains "docs mention OpenAPI agent tools" $docsIndex.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "docs mention OpenAPI Nexus skill extension" $docsIndex.Content "x-nexus-agent-skill.core_operation_ids"
Assert-Contains "docs mention OpenAPI core tool matrix" $docsIndex.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "docs mention OpenAPI forum tool matrix" $docsIndex.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "docs mention manifest root agent entry" $docsIndex.Content "docs.root_agent_entry"
Assert-Contains "docs mention manifest agent tools" $docsIndex.Content "docs.agent_tools"
Assert-Contains "docs mention manifest agent tool contract" $docsIndex.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "docs mention manifest OpenAPI tooling" $docsIndex.Content "api.openapi_tooling.core_operation_ids"
Assert-Contains "docs mention manifest core tool matrix" $docsIndex.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "docs mention manifest forum tool matrix" $docsIndex.Content "api.openapi_tooling.forum_tool_matrix"
Assert-Contains "quickstart mentions root llms" $quickstart.Content "/llms.txt"
Assert-Contains "quickstart mentions agent recipes" $quickstart.Content "/docs/agent-recipes.md"
Assert-Contains "quickstart explains core tool matrix" $quickstart.Content "openApiTooling.coreToolMatrix"
Assert-Contains "quickstart explains agent tools" $quickstart.Content "/docs/agent-tools.json"
Assert-Contains "quickstart explains runtime agent tool contract" $quickstart.Content "openApiTooling.agentToolContract"
Assert-Contains "quickstart explains forum tool matrix" $quickstart.Content "openApiTooling.forumToolMatrix"
Assert-Contains "quickstart explains forum open operationId" $quickstart.Content "nexusForumDiscussionShow"
Assert-Contains "quickstart explains forum open endpoint" $quickstart.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "quickstart explains task recipes" $quickstart.Content "skillInstructions.taskRecipes"
Assert-Contains "quickstart explains forum task recipes" $quickstart.Content "skillInstructions.taskRecipes.forumMatrix"
Assert-Contains "quickstart mentions skill candidate routing runbook" $quickstart.Content "skillInstructions.candidateRouting"
Assert-Contains "quickstart mentions OpenAPI root agent entry" $quickstart.Content "x-nexus-agent-skill.root_agent_entry"
Assert-Contains "quickstart mentions OpenAPI agent tools" $quickstart.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "quickstart mentions OpenAPI Nexus skill extension" $quickstart.Content "x-nexus-agent-skill.core_operation_ids"
Assert-Contains "quickstart mentions OpenAPI core tool matrix" $quickstart.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "quickstart mentions OpenAPI forum tool matrix" $quickstart.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "quickstart mentions manifest root agent entry" $quickstart.Content "docs.root_agent_entry"
Assert-Contains "quickstart mentions manifest OpenAPI tooling" $quickstart.Content "api.openapi_tooling.core_operation_ids"
Assert-Contains "quickstart mentions manifest agent tool contract" $quickstart.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "quickstart mentions manifest core tool matrix" $quickstart.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "quickstart mentions manifest forum tool matrix" $quickstart.Content "api.openapi_tooling.forum_tool_matrix"
Assert-Contains "agent recipes includes agent tools" $agentRecipes.Content "/docs/agent-tools.json"
Assert-Contains "agent recipes includes core tool matrix" $agentRecipes.Content "Core Tool Matrix"
Assert-Contains "agent recipes includes forum tool matrix" $agentRecipes.Content "Forum Gateway Tool Matrix"
Assert-Contains "agent recipes includes create help request" $agentRecipes.Content "Create help request"
Assert-Contains "agent recipes includes find candidates" $agentRecipes.Content "Find candidate helpers"
Assert-Contains "agent recipes includes dispatch" $agentRecipes.Content "Dispatch to helper"
Assert-Contains "agent recipes includes dispatch response" $agentRecipes.Content "Respond to dispatch"
Assert-Contains "agent recipes includes match response" $agentRecipes.Content "Respond to match"
Assert-Contains "agent recipes includes match message" $agentRecipes.Content "Send match message"
Assert-Contains "agent recipes includes work queue" $agentRecipes.Content "Poll work queue"
Assert-Contains "agent recipes includes core operationId" $agentRecipes.Content "nexusHelpRequestCreate"
Assert-Contains "agent recipes includes candidate operationId" $agentRecipes.Content "nexusHelpCandidatesList"
Assert-Contains "agent recipes includes work queue schema" $agentRecipes.Content "WorkItemCollectionDocument"

try {
  $agentTools = $agentToolsResponse.Content | ConvertFrom-Json
  Pass "agent tools parses as JSON"
  Assert-JsonPath "agent tools has kind" $agentTools "kind"
  Assert-JsonPath "agent tools has OpenAPI version" $agentTools "openapiVersion"
  Assert-JsonPath "agent tools has docs" $agentTools "docs"
  Assert-JsonPath "agent tools has startup" $agentTools "startup"
  Assert-JsonPath "agent tools has auth" $agentTools "auth"
  Assert-JsonPath "agent tools has core operationIds" $agentTools "coreOperationIds"
  Assert-JsonPath "agent tools has forum operationIds" $agentTools "forumOperationIds"
  Assert-JsonPath "agent tools has tasks" $agentTools "tasks"
  Assert-JsonPath "agent tools has forum tasks" $agentTools "forumTasks"

  if ($agentTools.kind -eq "nexus-agent-tools" -and $agentTools.openapiVersion -eq "0.7.43") {
    Pass "agent tools identity and version" $agentTools.openapiVersion
  } else {
    Fail "agent tools identity and version" "kind=$($agentTools.kind) openapiVersion=$($agentTools.openapiVersion)"
  }
  if ($agentTools.docs.agentTools -eq "/docs/agent-tools.json" -and $agentTools.docs.openapi -eq "/docs/openapi.json" -and $agentTools.docs.manifest -eq "/.well-known/nexus-agent.json") {
    Pass "agent tools docs are same-origin"
  } else {
    Fail "agent tools docs are same-origin" "agentTools=$($agentTools.docs.agentTools) openapi=$($agentTools.docs.openapi) manifest=$($agentTools.docs.manifest)"
  }
  $agentToolsStartupReads = @(As-Array $agentTools.startup.publicReadFirst | ForEach-Object { [string] $_ })
  if ($agentToolsStartupReads -contains "GET /docs/agent-tools.json" -and $agentTools.startup.llmProviderOptionalForLocalAgents -eq $true) {
    Pass "agent tools startup points to itself and keeps LLM optional"
  } else {
    Fail "agent tools startup points to itself and keeps LLM optional" "startup=$($agentToolsStartupReads -join ",") llmOptional=$($agentTools.startup.llmProviderOptionalForLocalAgents)"
  }
  if ($agentTools.coreOperationIds.help_dispatch_create -eq "nexusHelpDispatchCreate" -and $agentTools.forumOperationIds.forum_discussion_show -eq "nexusForumDiscussionShow") {
    Pass "agent tools exposes stable operationIds"
  } else {
    Fail "agent tools exposes stable operationIds" "dispatch=$($agentTools.coreOperationIds.help_dispatch_create) forumShow=$($agentTools.forumOperationIds.forum_discussion_show)"
  }
  $agentToolsTaskKeys = @($agentTools.tasks.PSObject.Properties | ForEach-Object { $_.Name })
  $missingAgentToolsTaskKeys = @($coreMatrixKeysSnake | Where-Object { $agentToolsTaskKeys -notcontains $_ })
  if ($missingAgentToolsTaskKeys.Count -eq 0) {
    Pass "agent tools has all core tasks"
  } else {
    Fail "agent tools has all core tasks" "missing=$($missingAgentToolsTaskKeys -join ",")"
  }
  $agentToolsForumTaskKeys = @($agentTools.forumTasks.PSObject.Properties | ForEach-Object { $_.Name })
  $missingAgentToolsForumTaskKeys = @($forumMatrixKeysSnake | Where-Object { $agentToolsForumTaskKeys -notcontains $_ })
  if ($missingAgentToolsForumTaskKeys.Count -eq 0) {
    Pass "agent tools has all forum tasks"
  } else {
    Fail "agent tools has all forum tasks" "missing=$($missingAgentToolsForumTaskKeys -join ",")"
  }
  $dispatchTool = $agentTools.tasks.dispatch_to_helper
  $dispatchMustVerify = [string] (@(As-Array $dispatchTool.preflight.mustVerify) -join "`n")
  $dispatchRules = [string] (@(As-Array $dispatchTool.agentRules) -join "`n")
  if ($dispatchTool.write.operationId -eq "nexusHelpDispatchCreate" -and $dispatchTool.preflight.operationId -eq "nexusAgentPreflightCreate" -and $dispatchMustVerify.Contains("target.helperUserId") -and [string] $dispatchTool.write.bodySource -like "*create_dispatch*bodyTemplate*" -and $dispatchRules.Contains("create_dispatch.bodyTemplate") -and $dispatchTool.requiresUserConfirmation -eq $true -and $dispatchTool.requiredPermission -eq "allowAgentMatching") {
    Pass "agent tools dispatch task is executable without guessing"
  } else {
    Fail "agent tools dispatch task is executable without guessing" "write=$($dispatchTool.write.operationId) preflight=$($dispatchTool.preflight.operationId) bodySource=$($dispatchTool.write.bodySource) mustVerify=$dispatchMustVerify"
  }
  $forumOpenTool = $agentTools.forumTasks.open_forum_discussion
  if ($forumOpenTool.read.operationId -eq "nexusForumDiscussionShow" -and [string] $forumOpenTool.read.endpoint -like "*include=user,tags,posts,posts.user*" -and $forumOpenTool.requiresAuthentication -eq $false -and $forumOpenTool.requiresUserConfirmation -eq $false) {
    Pass "agent tools forum open task reads posts without guessing"
  } else {
    Fail "agent tools forum open task reads posts without guessing" "operationId=$($forumOpenTool.read.operationId) endpoint=$($forumOpenTool.read.endpoint)"
  }
  $forumReplyReadFirst = @(As-Array $agentTools.forumTasks.reply_to_forum_discussion.readFirst | ForEach-Object { [string] $_.name })
  if ($forumReplyReadFirst -contains "open_forum_discussion") {
    Pass "agent tools forum reply requires opening discussion first"
  } else {
    Fail "agent tools forum reply requires opening discussion first" "readFirst=$($forumReplyReadFirst -join ",")"
  }
  if ($agentTools.forumTasks.create_forum_discussion.write.responseSchemaRef -eq "#/components/schemas/FlarumDiscussionDocument" -and $agentTools.forumTasks.reply_to_forum_discussion.write.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument" -and $agentTools.forumTasks.edit_own_forum_post.write.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument") {
    Pass "agent tools forum write tasks use concrete response schemas"
  } else {
    Fail "agent tools forum write tasks use concrete response schemas" "create=$($agentTools.forumTasks.create_forum_discussion.write.responseSchemaRef) reply=$($agentTools.forumTasks.reply_to_forum_discussion.write.responseSchemaRef) edit=$($agentTools.forumTasks.edit_own_forum_post.write.responseSchemaRef)"
  }
} catch {
  Fail "agent tools parses as JSON" $_.Exception.Message
  $agentTools = $null
}
Assert-Contains "docs mention JSON API error schema" $docsIndex.Content "JsonApiErrorDocument"
Assert-Contains "docs mention agent profile" $docsIndex.Content "/api/nexus/me/agent-profile"
Assert-Contains "docs mention capability labels" $docsIndex.Content "/api/nexus/capability-labels"
Assert-Contains "docs mention capability label search" $docsIndex.Content "/api/nexus/capability-labels?inname=repair"
Assert-Contains "docs mention label reuse guidance" $docsIndex.Content "reuseGuidance"
Assert-Contains "docs mention controlled forum gateway" $docsIndex.Content "/api/nexus/forum/discussions"
Assert-Contains "docs mention my forum discussions" $docsIndex.Content "/api/nexus/me/discussions"
Assert-Contains "docs mention my help requests" $docsIndex.Content "/api/nexus/me/help-requests"
Assert-Contains "docs mention my work items" $docsIndex.Content "/api/nexus/me/work-items"
Assert-Contains "docs mention my device signals" $docsIndex.Content "/api/nexus/me/device-signals"
Assert-Contains "docs mention candidate nextActions" $docsIndex.Content "nextActions"
Assert-Contains "docs mention candidate explainability" $docsIndex.Content "scoreBreakdown.rankReason"
Assert-Contains "docs mention candidate dispatch rationale template" $docsIndex.Content "dispatchRationaleTemplate"
Assert-Contains "docs mention help request offer nextAction" $docsIndex.Content "preflight_match_offer"
Assert-Contains "docs mention dispatch viewerRole" $docsIndex.Content "viewerRole"
Assert-Contains "docs mention dispatch response nextAction" $docsIndex.Content "preflight_dispatch_response"
Assert-Contains "docs mention match accept nextAction" $docsIndex.Content "preflight_match_accept"
Assert-Contains "docs mention target-aware preflight" $docsIndex.Content "Target-aware preflight"
Assert-Contains "docs mention target transition checks" $docsIndex.Content "targetTransition"

$rootLlms = Invoke-NexusHttp -Method "GET" -Path "/llms.txt"
Assert-Contains "root llms includes manifest" $rootLlms.Content "/.well-known/nexus-agent.json"
Assert-Contains "root llms includes OpenAPI" $rootLlms.Content "/docs/openapi.json"
Assert-Contains "root llms includes agent tools" $rootLlms.Content "/docs/agent-tools.json"
Assert-Contains "root llms includes agent quickstart" $rootLlms.Content "/docs/agent-quickstart.md"
Assert-Contains "root llms includes agent recipes" $rootLlms.Content "/docs/agent-recipes.md"
Assert-Contains "root llms includes full llms" $rootLlms.Content "/docs/llms.txt"
Assert-Contains "root llms includes Nexus skill" $rootLlms.Content "/docs/nexus-skill.md"
Assert-Contains "root llms includes agent health" $rootLlms.Content "/api/nexus/agent-health"
Assert-Contains "root llms includes agent context" $rootLlms.Content "/api/nexus/me/agent-context"
Assert-Contains "root llms includes agent preflight" $rootLlms.Content "/api/nexus/agent-preflight"
Assert-Contains "root llms includes optional LLM guidance" $rootLlms.Content "LLM provider settings are optional for local agents"
Assert-Contains "root llms includes user confirmation" $rootLlms.Content "userConfirmed=true"
Assert-Contains "root llms includes Nexus local agent token prefix" $rootLlms.Content "Nexus local agent"
Assert-Contains "root llms includes candidate explainability" $rootLlms.Content "dispatchRationaleTemplate"
Assert-Contains "root llms includes skill candidate routing runbook" $rootLlms.Content "skillInstructions.candidateRouting"
Assert-Contains "root llms includes runtime OpenAPI tooling" $rootLlms.Content "openApiTooling.coreOperationIds"
Assert-Contains "root llms includes runtime agent tool contract" $rootLlms.Content "openApiTooling.agentToolContract"
Assert-Contains "root llms includes runtime core tool matrix" $rootLlms.Content "openApiTooling.coreToolMatrix"
Assert-Contains "root llms includes runtime forum tool matrix" $rootLlms.Content "openApiTooling.forumToolMatrix"
Assert-Contains "root llms includes forum open operationId" $rootLlms.Content "nexusForumDiscussionShow"
Assert-Contains "root llms includes forum open endpoint" $rootLlms.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "root llms includes endpoint map schema" $rootLlms.Content "AgentEndpointMap"
Assert-Contains "root llms includes OpenAPI agent tools" $rootLlms.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "root llms includes OpenAPI Nexus skill extension" $rootLlms.Content "x-nexus-agent-skill.core_operation_ids"
Assert-Contains "root llms includes OpenAPI core tool matrix" $rootLlms.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "root llms includes OpenAPI forum tool matrix" $rootLlms.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "root llms includes manifest OpenAPI tooling" $rootLlms.Content "api.openapi_tooling.core_operation_ids"
Assert-Contains "root llms includes manifest agent tool contract" $rootLlms.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "root llms includes manifest core tool matrix" $rootLlms.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "root llms includes manifest forum tool matrix" $rootLlms.Content "api.openapi_tooling.forum_tool_matrix"

$llms = Invoke-NexusHttp -Method "GET" -Path "/docs/llms.txt"
Assert-Contains "llms.txt includes root llms" $llms.Content "/llms.txt"
Assert-Contains "llms.txt includes agent tools" $llms.Content "/docs/agent-tools.json"
Assert-Contains "llms.txt includes agent quickstart" $llms.Content "/docs/agent-quickstart.md"
Assert-Contains "llms.txt includes agent recipes" $llms.Content "/docs/agent-recipes.md"
Assert-Contains "llms.txt includes Nexus skill" $llms.Content "/docs/nexus-skill.md"
Assert-Contains "llms.txt includes human UI section" $llms.Content "Human UI:"
Assert-Contains "llms.txt explains optional LLM for local agents" $llms.Content "LLM provider settings are optional for local agents"
Assert-Contains "llms.txt includes agent health" $llms.Content "/api/nexus/agent-health"
Assert-Contains "llms.txt includes agent preflight" $llms.Content "/api/nexus/agent-preflight"
Assert-Contains "llms.txt includes need drafts" $llms.Content "/api/nexus/need-drafts"
Assert-Contains "llms.txt includes discoveryPlan" $llms.Content "discoveryPlan"
Assert-Contains "llms.txt includes labelReuse" $llms.Content "labelReuse"
Assert-Contains "llms.txt includes agent context" $llms.Content "/api/nexus/me/agent-context"
Assert-Contains "llms.txt includes agent profile" $llms.Content "/api/nexus/me/agent-profile"
Assert-Contains "llms.txt includes capability labels" $llms.Content "/api/nexus/capability-labels"
Assert-Contains "llms.txt includes capability label search" $llms.Content "/api/nexus/capability-labels?inname=<keyword>"
Assert-Contains "llms.txt includes helper label filter" $llms.Content "/api/nexus/capabilities?filter%5Blabel%5D=<label>"
Assert-Contains "llms.txt includes forum gateway" $llms.Content "/api/nexus/forum/discussions"
Assert-Contains "llms.txt includes my help requests" $llms.Content "/api/nexus/me/help-requests"
Assert-Contains "llms.txt includes my work items" $llms.Content "/api/nexus/me/work-items"
Assert-Contains "llms.txt includes my device signals" $llms.Content "/api/nexus/me/device-signals"
Assert-Contains "llms.txt includes candidate nextActions" $llms.Content "preflight_dispatch"
Assert-Contains "llms.txt includes candidate explainability" $llms.Content "scoreBreakdown.rankReason"
Assert-Contains "llms.txt includes candidate confirmation hints" $llms.Content "confirmationPromptHints"
Assert-Contains "llms.txt includes help request offer nextAction" $llms.Content "preflight_match_offer"
Assert-Contains "llms.txt includes dispatch resource nextActions" $llms.Content "preflight_dispatch_response"
Assert-Contains "llms.txt includes match resource nextActions" $llms.Content "preflight_match_accept"
Assert-Contains "llms.txt includes target-aware preflight" $llms.Content "target.viewerRole"
Assert-Contains "llms.txt includes Developer Token setup" $llms.Content "Developer Token"
Assert-Contains "llms.txt includes Nexus local agent token prefix" $llms.Content "Nexus local agent"
Assert-Contains "llms.txt includes raw Flarum write boundary" $llms.Content "raw Flarum writes"
Assert-Contains "llms.txt includes token endpoint" $llms.Content "/api/token"
Assert-Contains "llms.txt includes access tokens endpoint" $llms.Content "/api/access-tokens"
Assert-Contains "llms.txt includes agent readiness" $llms.Content "agentReadiness"
Assert-Contains "llms.txt includes skill instructions" $llms.Content "skillInstructions"
Assert-Contains "llms.txt includes skill label reuse runbook" $llms.Content "skillInstructions.labelReuse"
Assert-Contains "llms.txt includes skill candidate routing runbook" $llms.Content "skillInstructions.candidateRouting"
Assert-Contains "llms.txt includes skill task recipes" $llms.Content "skillInstructions.taskRecipes"
Assert-Contains "llms.txt includes skill error recovery runbook" $llms.Content "skillInstructions.errorRecovery"
Assert-Contains "llms.txt includes preflight recovery" $llms.Content "attributes.recovery"
Assert-Contains "llms.txt includes preflight action catalog" $llms.Content "agentPreflight.actions"
Assert-Contains "llms.txt includes preflight target type" $llms.Content "targetType"
Assert-Contains "llms.txt includes preflight proposed fields" $llms.Content "proposedFields"
Assert-Contains "llms.txt includes preflight schema refs" $llms.Content "writeBodySchemaRef"
Assert-Contains "llms.txt includes preflight side effects" $llms.Content "sideEffects"
Assert-Contains "llms.txt includes preflight example body" $llms.Content "examplePreflightBody"
Assert-Contains "llms.txt includes nextAction catalogAction" $llms.Content "catalogAction"
Assert-Contains "llms.txt includes self-describing nextActions" $llms.Content "self-describing recovery recipes"
Assert-Contains "llms.txt includes concrete schema list" $llms.Content "HelpMatchMessageCollectionDocument"
Assert-Contains "llms.txt includes core matrix schema" $llms.Content "AgentCoreToolMatrix"
Assert-Contains "llms.txt includes need draft document schema" $llms.Content "NeedDraftDocument"
Assert-Contains "llms.txt includes help candidate collection schema" $llms.Content "HelpCandidateCollectionDocument"
Assert-Contains "llms.txt includes work item collection schema" $llms.Content "WorkItemCollectionDocument"
Assert-Contains "llms.txt includes endpoint map schema" $llms.Content "AgentEndpointMap"
Assert-Contains "llms.txt includes OpenAPI operationId guidance" $llms.Content "OpenAPI operationIds"
Assert-Contains "llms.txt includes core operationId" $llms.Content "nexusAgentPreflightCreate"
Assert-Contains "llms.txt includes work queue operationId" $llms.Content "nexusMyWorkItemsList"
Assert-Contains "llms.txt includes forum operationId" $llms.Content "nexusForumDiscussionCreate"
Assert-Contains "llms.txt includes forum open operationId" $llms.Content "nexusForumDiscussionShow"
Assert-Contains "llms.txt includes forum open endpoint" $llms.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "llms.txt includes runtime OpenAPI tooling" $llms.Content "openApiTooling.coreOperationIds"
Assert-Contains "llms.txt includes runtime agent tool contract" $llms.Content "openApiTooling.agentToolContract"
Assert-Contains "llms.txt includes runtime core tool matrix" $llms.Content "openApiTooling.coreToolMatrix"
Assert-Contains "llms.txt includes runtime forum tool matrix" $llms.Content "openApiTooling.forumToolMatrix"
Assert-Contains "llms.txt includes OpenAPI root agent entry" $llms.Content "x-nexus-agent-skill.root_agent_entry"
Assert-Contains "llms.txt includes OpenAPI agent tools" $llms.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "llms.txt includes OpenAPI Nexus skill extension" $llms.Content "x-nexus-agent-skill.core_operation_ids"
Assert-Contains "llms.txt includes OpenAPI core tool matrix" $llms.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "llms.txt includes OpenAPI forum tool matrix" $llms.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "llms.txt includes manifest root agent entry" $llms.Content "docs.root_agent_entry"
Assert-Contains "llms.txt includes manifest agent tools" $llms.Content "docs.agent_tools"
Assert-Contains "llms.txt includes manifest agent tool contract" $llms.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "llms.txt includes manifest OpenAPI tooling" $llms.Content "api.openapi_tooling.core_operation_ids"
Assert-Contains "llms.txt includes manifest core tool matrix" $llms.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "llms.txt includes manifest forum tool matrix" $llms.Content "api.openapi_tooling.forum_tool_matrix"

$skill = Invoke-NexusHttp -Method "GET" -Path "/docs/nexus-skill.md"
Assert-Contains "Nexus skill includes root llms" $skill.Content "/llms.txt"
Assert-Contains "Nexus skill includes agent tools" $skill.Content "/docs/agent-tools.json"
Assert-Contains "Nexus skill includes agent quickstart" $skill.Content "/docs/agent-quickstart.md"
Assert-Contains "Nexus skill includes agent recipes" $skill.Content "/docs/agent-recipes.md"
Assert-Contains "Nexus skill explains optional LLM for local agents" $skill.Content "LLM provider settings are optional"
Assert-Contains "Nexus skill includes confirmation rule" $skill.Content "Required Confirmation"
Assert-Contains "Nexus skill includes dispatch flow" $skill.Content "Candidate And Dispatch Flow"
Assert-Contains "Nexus skill includes direct offer flow" $skill.Content "Direct Match Offer Flow"
Assert-Contains "Nexus skill includes agent health" $skill.Content "/api/nexus/agent-health"
Assert-Contains "Nexus skill includes agent preflight" $skill.Content "/api/nexus/agent-preflight"
Assert-Contains "Nexus skill includes need drafts" $skill.Content "/api/nexus/need-drafts"
Assert-Contains "Nexus skill includes discoveryPlan" $skill.Content "discoveryPlan"
Assert-Contains "Nexus skill includes labelReuse" $skill.Content "labelReuse"
Assert-Contains "Nexus skill includes agent context" $skill.Content "/api/nexus/me/agent-context"
Assert-Contains "Nexus skill includes agent profile" $skill.Content "/api/nexus/me/agent-profile"
Assert-Contains "Nexus skill includes capability labels" $skill.Content "/api/nexus/capability-labels"
Assert-Contains "Nexus skill includes capability label search" $skill.Content "/api/nexus/capability-labels?inname=<keyword>"
Assert-Contains "Nexus skill includes label reuse guidance" $skill.Content "reuseGuidance"
Assert-Contains "Nexus skill includes forum gateway" $skill.Content "Controlled Forum Gateway"
Assert-Contains "Nexus skill includes my help requests" $skill.Content "/api/nexus/me/help-requests"
Assert-Contains "Nexus skill includes my work items" $skill.Content "/api/nexus/me/work-items"
Assert-Contains "Nexus skill includes my device signals" $skill.Content "/api/nexus/me/device-signals"
Assert-Contains "Nexus skill includes candidate nextActions" $skill.Content "preflight_dispatch"
Assert-Contains "Nexus skill includes candidate explainability" $skill.Content "scoreBreakdown.rankReason"
Assert-Contains "Nexus skill includes candidate dispatch rationale template" $skill.Content "dispatchRationaleTemplate"
Assert-Contains "Nexus skill includes help request offer nextAction" $skill.Content "preflight_match_offer"
Assert-Contains "Nexus skill includes dispatch resource nextActions" $skill.Content "preflight_dispatch_response"
Assert-Contains "Nexus skill includes match resource nextActions" $skill.Content "preflight_match_accept"
Assert-Contains "Nexus skill includes target-aware preflight" $skill.Content "Target-aware preflight"
Assert-Contains "Nexus skill includes target transition checks" $skill.Content "targetTransition"
Assert-Contains "Nexus skill includes Developer Tokens" $skill.Content "Developer Tokens"
Assert-Contains "Nexus skill includes Nexus local agent token prefix" $skill.Content "Nexus local agent"
Assert-Contains "Nexus skill includes raw Flarum write boundary" $skill.Content "raw Flarum writes"
Assert-Contains "Nexus skill includes access token creation" $skill.Content "POST /api/access-tokens"
Assert-Contains "Nexus skill includes agent readiness" $skill.Content "agentReadiness"
Assert-Contains "Nexus skill includes skill instructions" $skill.Content "skillInstructions"
Assert-Contains "Nexus skill includes skill label reuse runbook" $skill.Content "skillInstructions.labelReuse"
Assert-Contains "Nexus skill includes skill candidate routing runbook" $skill.Content "skillInstructions.candidateRouting"
Assert-Contains "Nexus skill includes skill task recipes" $skill.Content "skillInstructions.taskRecipes"
Assert-Contains "Nexus skill includes skill error recovery runbook" $skill.Content "skillInstructions.errorRecovery"
Assert-Contains "Nexus skill includes preflight recovery" $skill.Content "attributes.recovery"
Assert-Contains "Nexus skill includes preflight action catalog" $skill.Content "agentPreflight.actions"
Assert-Contains "Nexus skill includes preflight target type" $skill.Content "targetType"
Assert-Contains "Nexus skill includes preflight proposed fields" $skill.Content "proposedFields"
Assert-Contains "Nexus skill includes preflight schema refs" $skill.Content "writeBodySchemaRef"
Assert-Contains "Nexus skill includes preflight side effects" $skill.Content "sideEffects"
Assert-Contains "Nexus skill includes preflight example body" $skill.Content "examplePreflightBody"
Assert-Contains "Nexus skill includes nextAction catalogAction" $skill.Content "catalogAction"
Assert-Contains "Nexus skill includes self-describing nextActions" $skill.Content "self-describing recovery recipes"
Assert-Contains "Nexus skill includes concrete schema list" $skill.Content "LlmSettingsDocument"
Assert-Contains "Nexus skill includes core matrix schema" $skill.Content "AgentCoreToolMatrix"
Assert-Contains "Nexus skill includes forum matrix schema" $skill.Content "AgentForumToolMatrix"
Assert-Contains "Nexus skill includes endpoint map schema" $skill.Content "AgentEndpointMap"
Assert-Contains "Nexus skill includes OpenAPI operationId guidance" $skill.Content "operationId"
Assert-Contains "Nexus skill includes core operationId" $skill.Content "nexusAgentPreflightCreate"
Assert-Contains "Nexus skill includes work queue operationId" $skill.Content "nexusMyWorkItemsList"
Assert-Contains "Nexus skill includes forum operationId" $skill.Content "nexusForumDiscussionCreate"
Assert-Contains "Nexus skill includes forum open operationId" $skill.Content "nexusForumDiscussionShow"
Assert-Contains "Nexus skill includes forum open endpoint" $skill.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "Nexus skill includes runtime OpenAPI tooling" $skill.Content "openApiTooling.coreOperationIds"
Assert-Contains "Nexus skill includes runtime agent tool contract" $skill.Content "openApiTooling.agentToolContract"
Assert-Contains "Nexus skill includes runtime core tool matrix" $skill.Content "openApiTooling.coreToolMatrix"
Assert-Contains "Nexus skill includes runtime forum tool matrix" $skill.Content "openApiTooling.forumToolMatrix"
Assert-Contains "Nexus skill includes skill forum task recipes" $skill.Content "skillInstructions.taskRecipes.forumMatrix"
Assert-Contains "Nexus skill includes OpenAPI root agent entry" $skill.Content "x-nexus-agent-skill.root_agent_entry"
Assert-Contains "Nexus skill includes OpenAPI agent tools" $skill.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "Nexus skill includes OpenAPI Nexus skill extension" $skill.Content "x-nexus-agent-skill.core_operation_ids"
Assert-Contains "Nexus skill includes OpenAPI core tool matrix" $skill.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "Nexus skill includes OpenAPI forum tool matrix" $skill.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "Nexus skill includes manifest root agent entry" $skill.Content "docs.root_agent_entry"
Assert-Contains "Nexus skill includes manifest agent tools" $skill.Content "docs.agent_tools"
Assert-Contains "Nexus skill includes manifest agent tool contract" $skill.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "Nexus skill includes manifest OpenAPI tooling" $skill.Content "api.openapi_tooling.core_operation_ids"
Assert-Contains "Nexus skill includes manifest core tool matrix" $skill.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "Nexus skill includes manifest forum tool matrix" $skill.Content "api.openapi_tooling.forum_tool_matrix"

$manifestResponse = Invoke-NexusHttp -Method "GET" -Path "/.well-known/nexus-agent.json"
try {
  $manifest = $manifestResponse.Content | ConvertFrom-Json
  Assert-JsonPath "manifest has schema" $manifest "schema"
  Assert-JsonPath "manifest has nexus endpoints" $manifest "nexus_endpoints"
  Assert-JsonPath "manifest has safety section" $manifest "safety"
  Assert-JsonPath "manifest has docs section" $manifest "docs"
  Assert-JsonPath "manifest api has auth metadata" $manifest.api "auth"
  Assert-JsonPath "manifest api has operationId policy" $manifest.api "operation_id_policy"
  Assert-JsonPath "manifest api has structured OpenAPI tooling" $manifest.api "openapi_tooling"
  Assert-JsonPath "manifest OpenAPI tooling has core operationIds" $manifest.api.openapi_tooling "core_operation_ids"
  Assert-JsonPath "manifest OpenAPI tooling has agent tool contract" $manifest.api.openapi_tooling "agent_tool_contract"
  Assert-JsonPath "manifest OpenAPI tooling has core tool matrix" $manifest.api.openapi_tooling "core_tool_matrix"
  Assert-JsonPath "manifest OpenAPI tooling has runtime sources" $manifest.api.openapi_tooling "runtime_sources"
  if ($manifest.api.openapi_tooling.core_operation_ids.agent_preflight -eq "nexusAgentPreflightCreate" -and $manifest.api.openapi_tooling.core_operation_ids.my_work_items -eq "nexusMyWorkItemsList") {
    Pass "manifest exposes structured core operationIds"
  } else {
    Fail "manifest exposes structured core operationIds" "agent_preflight=$($manifest.api.openapi_tooling.core_operation_ids.agent_preflight) my_work_items=$($manifest.api.openapi_tooling.core_operation_ids.my_work_items)"
  }
  $manifestMatrixKeys = @($manifest.api.openapi_tooling.core_tool_matrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingManifestMatrixKeys = @($coreMatrixKeysSnake | Where-Object { $manifestMatrixKeys -notcontains $_ })
  if ($missingManifestMatrixKeys.Count -eq 0) {
    Pass "manifest core tool matrix has all core tasks"
  } else {
    Fail "manifest core tool matrix has all core tasks" "missing=$($missingManifestMatrixKeys -join ",")"
  }
  if ($manifest.api.openapi_tooling.core_tool_matrix.create_help_request.write_operation_id -eq "nexusHelpRequestCreate" -and $manifest.api.openapi_tooling.core_tool_matrix.find_candidate_helpers.read_operation_id -eq "nexusHelpCandidatesList" -and $manifest.api.openapi_tooling.core_tool_matrix.dispatch_to_helper.write_operation_id -eq "nexusHelpDispatchCreate" -and $manifest.api.openapi_tooling.core_tool_matrix.respond_to_dispatch.write_operation_id -eq "nexusDispatchUpdate" -and $manifest.api.openapi_tooling.core_tool_matrix.respond_to_match_offer.write_operation_id -eq "nexusMatchUpdate" -and $manifest.api.openapi_tooling.core_tool_matrix.send_match_message.write_operation_id -eq "nexusMatchMessageCreate" -and $manifest.api.openapi_tooling.core_tool_matrix.poll_work_queue.read_operation_id -eq "nexusMyWorkItemsList") {
    Pass "manifest core tool matrix exposes core operationIds"
  } else {
    Fail "manifest core tool matrix exposes core operationIds" "unexpected core_tool_matrix operation ids"
  }
  Assert-JsonPath "manifest OpenAPI tooling has forum operationIds" $manifest.api.openapi_tooling "forum_operation_ids"
  Assert-JsonPath "manifest OpenAPI tooling has forum tool matrix" $manifest.api.openapi_tooling "forum_tool_matrix"
  if ($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show -eq "nexusForumDiscussionShow" -and $manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create -eq "nexusForumDiscussionCreate" -and $manifest.api.openapi_tooling.forum_operation_ids.my_forum_posts -eq "nexusMyForumPostsList") {
    Pass "manifest exposes structured forum operationIds"
  } else {
    Fail "manifest exposes structured forum operationIds" "forum_discussion_show=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show) forum_discussion_create=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create) my_forum_posts=$($manifest.api.openapi_tooling.forum_operation_ids.my_forum_posts)"
  }
  $manifestForumMatrixKeys = @($manifest.api.openapi_tooling.forum_tool_matrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingManifestForumMatrixKeys = @($forumMatrixKeysSnake | Where-Object { $manifestForumMatrixKeys -notcontains $_ })
  if ($missingManifestForumMatrixKeys.Count -eq 0) {
    Pass "manifest forum tool matrix has all forum tasks"
  } else {
    Fail "manifest forum tool matrix has all forum tasks" "missing=$($missingManifestForumMatrixKeys -join ",")"
  }
  $manifestReplyReadFirst = @(As-Array $manifest.api.openapi_tooling.forum_tool_matrix.reply_to_forum_discussion.read_first | ForEach-Object { [string] $_.name })
  if ($manifest.api.openapi_tooling.forum_tool_matrix.search_forum_discussions.read_operation_id -eq "nexusForumDiscussionsList" -and $manifest.api.openapi_tooling.forum_tool_matrix.open_forum_discussion.read_operation_id -eq "nexusForumDiscussionShow" -and ($manifestReplyReadFirst -contains "open_forum_discussion") -and $manifest.api.openapi_tooling.forum_tool_matrix.create_forum_discussion.write_operation_id -eq "nexusForumDiscussionCreate" -and $manifest.api.openapi_tooling.forum_tool_matrix.reply_to_forum_discussion.write_operation_id -eq "nexusForumDiscussionPostCreate" -and $manifest.api.openapi_tooling.forum_tool_matrix.recover_my_forum_posts.read_operation_id -eq "nexusMyForumPostsList" -and $manifest.api.openapi_tooling.forum_tool_matrix.hide_own_forum_post.write_operation_id -eq "nexusForumPostDelete") {
    Pass "manifest forum tool matrix exposes forum operationIds"
  } else {
    Fail "manifest forum tool matrix exposes forum operationIds" "unexpected forum_tool_matrix operation ids"
  }
  if ($manifest.api.openapi_tooling.forum_tool_matrix.create_forum_discussion.response_schema_ref -eq "#/components/schemas/FlarumDiscussionDocument" -and $manifest.api.openapi_tooling.forum_tool_matrix.reply_to_forum_discussion.response_schema_ref -eq "#/components/schemas/FlarumPostDocument" -and $manifest.api.openapi_tooling.forum_tool_matrix.edit_own_forum_post.response_schema_ref -eq "#/components/schemas/FlarumPostDocument") {
    Pass "manifest forum write tasks use concrete response schemas"
  } else {
    Fail "manifest forum write tasks use concrete response schemas" "create=$($manifest.api.openapi_tooling.forum_tool_matrix.create_forum_discussion.response_schema_ref) reply=$($manifest.api.openapi_tooling.forum_tool_matrix.reply_to_forum_discussion.response_schema_ref) edit=$($manifest.api.openapi_tooling.forum_tool_matrix.edit_own_forum_post.response_schema_ref)"
  }
  $manifestToolingTags = @(As-Array $manifest.api.openapi_tooling.tags | ForEach-Object { [string] $_ })
  if ($manifestToolingTags -contains "Nexus Agent Skill") {
    Pass "manifest exposes OpenAPI tool tags"
  } else {
    Fail "manifest exposes OpenAPI tool tags" "tags=$($manifestToolingTags -join ",")"
  }
  $manifestToolingRuntimeSources = [string] (@(As-Array $manifest.api.openapi_tooling.runtime_sources) -join "`n")
  if ($manifestToolingRuntimeSources.Contains("GET /api/nexus/agent-health") -and $manifestToolingRuntimeSources.Contains("GET /api/nexus/me/agent-context")) {
    Pass "manifest links runtime OpenAPI tooling sources"
  } else {
    Fail "manifest links runtime OpenAPI tooling sources" "runtime_sources=$manifestToolingRuntimeSources"
  }
  Assert-JsonPath "manifest auth has agent token prefix" $manifest.api.auth "agent_token_title_prefix"
  Assert-JsonPath "manifest auth has agent token write boundary" $manifest.api.auth "agent_token_write_boundary"
  Assert-JsonPath "manifest auth has token endpoint" $manifest.api.auth "token_endpoint"
  Assert-JsonPath "manifest auth has developer tokens endpoint" $manifest.api.auth "developer_tokens_endpoint"
  Assert-JsonPath "manifest docs has root agent entry" $manifest.docs "root_agent_entry"
  Assert-JsonPath "manifest docs has agent tools" $manifest.docs "agent_tools"
  Assert-JsonPath "manifest docs has quickstart" $manifest.docs "agent_quickstart"
  Assert-JsonPath "manifest docs has Nexus skill" $manifest.docs "nexus_skill"
  Assert-JsonPath "manifest docs has agent recipes" $manifest.docs "agent_recipes"
  if ([string] $manifest.docs.root_agent_entry -eq "/llms.txt" -and [string] $manifest.docs.agent_tools -eq "/docs/agent-tools.json" -and [string] $manifest.docs.agent_recipes -eq "/docs/agent-recipes.md" -and [string] $manifest.api.openapi_tooling.agent_tool_contract -eq "/docs/agent-tools.json") {
    Pass "manifest docs are same-origin"
  } else {
    Fail "manifest docs are same-origin" "root_agent_entry=$($manifest.docs.root_agent_entry) agent_tools=$($manifest.docs.agent_tools) agent_recipes=$($manifest.docs.agent_recipes) agent_tool_contract=$($manifest.api.openapi_tooling.agent_tool_contract)"
  }
  Assert-JsonPath "manifest api has public health" $manifest.api "public_health"
  Assert-JsonPath "manifest endpoints has agent health" $manifest.nexus_endpoints "agent_health"
  Assert-JsonPath "manifest endpoints has agent preflight" $manifest.nexus_endpoints "agent_preflight"
  Assert-JsonPath "manifest endpoints has need drafts" $manifest.nexus_endpoints "need_drafts"
  Assert-JsonPath "manifest endpoints has agent context" $manifest.nexus_endpoints "my_agent_context"
  Assert-JsonPath "manifest endpoints has capability labels" $manifest.nexus_endpoints "capability_labels"
  Assert-JsonPath "manifest endpoints has action logs" $manifest.nexus_endpoints "my_action_logs"
  Assert-JsonPath "manifest endpoints has my matches" $manifest.nexus_endpoints "my_matches"
  Assert-JsonPath "manifest endpoints has my help requests" $manifest.nexus_endpoints "my_help_requests"
  Assert-JsonPath "manifest endpoints has my work items" $manifest.nexus_endpoints "my_work_items"
  Assert-JsonPath "manifest endpoints has my device signals" $manifest.nexus_endpoints "my_device_signals"
  Assert-JsonPath "manifest endpoints has agent profile" $manifest.nexus_endpoints "my_agent_profile"
  Assert-JsonPath "manifest endpoints has forum discussions" $manifest.nexus_endpoints "forum_discussions"
  Assert-JsonPath "manifest endpoints has forum discussion show" $manifest.nexus_endpoints "forum_discussion"
  Assert-JsonPath "manifest endpoints has forum post" $manifest.nexus_endpoints "forum_post"
  Assert-JsonPath "manifest endpoints has my forum discussions" $manifest.nexus_endpoints "my_forum_discussions"
  if ($manifest.capabilities.local_agent_api_without_llm_provider -eq $true) {
    Pass "manifest says LLM provider optional for local agents"
  } else {
    Fail "manifest says LLM provider optional for local agents" "local_agent_api_without_llm_provider=$($manifest.capabilities.local_agent_api_without_llm_provider)"
  }
  if ($manifest.capabilities.openapi_stable_operation_ids -eq $true) {
    Pass "manifest says OpenAPI operationIds are stable"
  } else {
    Fail "manifest says OpenAPI operationIds are stable" "openapi_stable_operation_ids=$($manifest.capabilities.openapi_stable_operation_ids)"
  }
  if ($manifest.capabilities.openapi_runtime_tooling -eq $true) {
    Pass "manifest says runtime OpenAPI tooling is available"
  } else {
    Fail "manifest says runtime OpenAPI tooling is available" "openapi_runtime_tooling=$($manifest.capabilities.openapi_runtime_tooling)"
  }
  if ($manifest.capabilities.agent_task_recipes -eq $true) {
    Pass "manifest says agent task recipes are available"
  } else {
    Fail "manifest says agent task recipes are available" "agent_task_recipes=$($manifest.capabilities.agent_task_recipes)"
  }
  if ($manifest.capabilities.agent_tools_contract -eq $true) {
    Pass "manifest says agent tool contract is available"
  } else {
    Fail "manifest says agent tool contract is available" "agent_tools_contract=$($manifest.capabilities.agent_tools_contract)"
  }
  if ($manifest.capabilities.openapi_core_tool_matrix -eq $true) {
    Pass "manifest says OpenAPI core tool matrix is available"
  } else {
    Fail "manifest says OpenAPI core tool matrix is available" "openapi_core_tool_matrix=$($manifest.capabilities.openapi_core_tool_matrix)"
  }
  if ($manifest.capabilities.openapi_forum_tool_matrix -eq $true -and $manifest.capabilities.forum_gateway_tool_matrix -eq $true) {
    Pass "manifest says forum tool matrix is available"
  } else {
    Fail "manifest says forum tool matrix is available" "openapi_forum_tool_matrix=$($manifest.capabilities.openapi_forum_tool_matrix) forum_gateway_tool_matrix=$($manifest.capabilities.forum_gateway_tool_matrix)"
  }
  if ([string] $manifest.schema -eq "/schemas/nexus-agent-manifest.v1.json") {
    Pass "manifest schema is same-origin"
  } else {
    Fail "manifest schema is same-origin" "schema=$($manifest.schema)"
  }
  $manifestSchemaResponse = Invoke-NexusHttp -Method "GET" -Path ([string] $manifest.schema)
  try {
    $manifestSchema = $manifestSchemaResponse.Content | ConvertFrom-Json
    Assert-JsonPath "manifest schema parses and has properties" $manifestSchema "properties"
    Assert-JsonPath "manifest schema describes nexus endpoints" $manifestSchema.properties "nexus_endpoints"
    Assert-JsonPath "manifest schema describes OpenAPI tooling" $manifestSchema.properties.api.properties "openapi_tooling"
    Assert-JsonPath "manifest schema describes docs agent tools" $manifestSchema.properties.docs.properties "agent_tools"
    Assert-JsonPath "manifest schema describes docs agent recipes" $manifestSchema.properties.docs.properties "agent_recipes"
    Assert-JsonPath "manifest schema describes OpenAPI agent tool contract" $manifestSchema.properties.api.properties.openapi_tooling.properties "agent_tool_contract"
    Assert-JsonPath "manifest schema describes OpenAPI core tool matrix" $manifestSchema.properties.api.properties.openapi_tooling.properties "core_tool_matrix"
    Assert-JsonPath "manifest schema describes OpenAPI forum operationIds" $manifestSchema.properties.api.properties.openapi_tooling.properties "forum_operation_ids"
    Assert-JsonPath "manifest schema describes OpenAPI forum tool matrix" $manifestSchema.properties.api.properties.openapi_tooling.properties "forum_tool_matrix"
    $manifestDocsRequired = @(As-Array $manifestSchema.properties.docs.required | ForEach-Object { [string] $_ })
    if ($manifestDocsRequired -contains "root_agent_entry") {
      Pass "manifest schema requires root agent entry"
    } else {
      Fail "manifest schema requires root agent entry" "required=$($manifestDocsRequired -join ",")"
    }
  } catch {
    Fail "manifest schema parses as JSON" $_.Exception.Message
  }
  $manifestWorkflow = [string] ($manifest.workflow -join "`n")
  if ($manifestWorkflow.Contains("/llms.txt")) {
    Pass "manifest workflow mentions root llms"
  } else {
    Fail "manifest workflow mentions root llms" "missing /llms.txt"
  }
  if ($manifestWorkflow.Contains("/api/nexus/agent-health")) {
    Pass "manifest workflow mentions agent health"
  } else {
    Fail "manifest workflow mentions agent health" "missing /api/nexus/agent-health"
  }
  if ($manifestWorkflow.Contains("discoveryPlan")) {
    Pass "manifest workflow mentions discoveryPlan"
  } else {
    Fail "manifest workflow mentions discoveryPlan" "missing discoveryPlan"
  }
  if ($manifestWorkflow.Contains("labelReuse")) {
    Pass "manifest workflow mentions labelReuse"
  } else {
    Fail "manifest workflow mentions labelReuse" "missing labelReuse"
  }
  if ($manifestWorkflow.Contains("reuseGuidance")) {
    Pass "manifest workflow mentions label reuse guidance"
  } else {
    Fail "manifest workflow mentions label reuse guidance" "missing reuseGuidance"
  }
  if ($manifest.labels.reuse_policy -and ([string] $manifest.labels.reuse_policy).Contains("/api/nexus/capability-labels?inname=<keyword>")) {
    Pass "manifest labels include reuse policy"
  } else {
    Fail "manifest labels include reuse policy" "missing label reuse policy"
  }
  if ($manifestWorkflow.Contains("skillInstructions")) {
    Pass "manifest workflow mentions skillInstructions"
  } else {
    Fail "manifest workflow mentions skillInstructions" "missing skillInstructions"
  }
  if ($manifestWorkflow.Contains("skillInstructions.candidateRouting")) {
    Pass "manifest workflow mentions candidate routing runbook"
  } else {
    Fail "manifest workflow mentions candidate routing runbook" "missing skillInstructions.candidateRouting"
  }
  if ($manifestWorkflow.Contains("skillInstructions.errorRecovery") -and $manifestWorkflow.Contains("attributes.recovery")) {
    Pass "manifest workflow mentions recovery runbooks"
  } else {
    Fail "manifest workflow mentions recovery runbooks" "missing skillInstructions.errorRecovery/attributes.recovery"
  }
  if ($manifestWorkflow.Contains("preflight_dispatch") -and $manifestWorkflow.Contains("create_dispatch")) {
    Pass "manifest workflow mentions candidate dispatch nextActions"
  } else {
    Fail "manifest workflow mentions candidate dispatch nextActions" "missing candidate dispatch nextActions"
  }
  if ($manifestWorkflow.Contains("scoreBreakdown.rankReason") -and $manifestWorkflow.Contains("dispatchRationaleTemplate")) {
    Pass "manifest workflow mentions candidate explainability"
  } else {
    Fail "manifest workflow mentions candidate explainability" "missing candidate explainability fields"
  }
  if ($manifestWorkflow.Contains("preflight_match_offer") -and $manifestWorkflow.Contains("offer_match")) {
    Pass "manifest workflow mentions help request offer nextActions"
  } else {
    Fail "manifest workflow mentions help request offer nextActions" "missing help request offer nextActions"
  }
  if ($manifestWorkflow.Contains("preflight_dispatch_response") -and $manifestWorkflow.Contains("preflight_dispatch_cancel")) {
    Pass "manifest workflow mentions dispatch resource nextActions"
  } else {
    Fail "manifest workflow mentions dispatch resource nextActions" "missing dispatch resource nextActions"
  }
  if ($manifestWorkflow.Contains("preflight_match_accept") -and $manifestWorkflow.Contains("preflight_match_message")) {
    Pass "manifest workflow mentions match resource nextActions"
  } else {
    Fail "manifest workflow mentions match resource nextActions" "missing match resource nextActions"
  }
  if ($manifestWorkflow.Contains("target.viewerRole") -and $manifestWorkflow.Contains("targetTransition")) {
    Pass "manifest workflow mentions target-aware preflight"
  } else {
    Fail "manifest workflow mentions target-aware preflight" "missing target-aware preflight"
  }
  if ($manifestWorkflow.Contains("targetType") -and $manifestWorkflow.Contains("proposedFields") -and $manifestWorkflow.Contains("writeBodySchemaRef") -and $manifestWorkflow.Contains("sideEffects") -and $manifestWorkflow.Contains("examplePreflightBody")) {
    Pass "manifest workflow mentions rich preflight recipes"
  } else {
    Fail "manifest workflow mentions rich preflight recipes" "missing targetType/proposedFields/writeBodySchemaRef/sideEffects/examplePreflightBody"
  }
  if ($manifestWorkflow.Contains("operationId") -and $manifestWorkflow.Contains("nexusAgentPreflightCreate") -and $manifestWorkflow.Contains("nexusMyWorkItemsList")) {
    Pass "manifest workflow mentions OpenAPI operationIds"
  } else {
    Fail "manifest workflow mentions OpenAPI operationIds" "missing operationId/nexusAgentPreflightCreate/nexusMyWorkItemsList"
  }
  if ($manifestWorkflow.Contains("openApiTooling.coreOperationIds")) {
    Pass "manifest workflow mentions runtime OpenAPI tooling"
  } else {
    Fail "manifest workflow mentions runtime OpenAPI tooling" "missing openApiTooling.coreOperationIds"
  }
  if ($manifestWorkflow.Contains("/docs/agent-recipes.md") -and $manifestWorkflow.Contains("openApiTooling.coreToolMatrix") -and $manifestWorkflow.Contains("api.openapi_tooling.core_tool_matrix")) {
    Pass "manifest workflow mentions core task recipe sources"
  } else {
    Fail "manifest workflow mentions core task recipe sources" "missing /docs/agent-recipes.md/openApiTooling.coreToolMatrix/api.openapi_tooling.core_tool_matrix"
  }
  if ($manifestWorkflow.Contains("openApiTooling.forumToolMatrix") -and $manifestWorkflow.Contains("api.openapi_tooling.forum_tool_matrix") -and $manifestWorkflow.Contains("x-nexus-agent-skill.forum_tool_matrix")) {
    Pass "manifest workflow mentions forum task recipe sources"
  } else {
    Fail "manifest workflow mentions forum task recipe sources" "missing openApiTooling.forumToolMatrix/api.openapi_tooling.forum_tool_matrix/x-nexus-agent-skill.forum_tool_matrix"
  }
  if ($manifestWorkflow.Contains("catalogAction") -and $manifestWorkflow.Contains("self-describing recovery recipes")) {
    Pass "manifest workflow mentions self-describing nextActions"
  } else {
    Fail "manifest workflow mentions self-describing nextActions" "missing catalogAction/self-describing recovery recipes"
  }
  if ($manifest.capabilities.draft_need_before_confirmed_write -eq $true) {
    Pass "manifest says need drafting is supported"
  } else {
    Fail "manifest says need drafting is supported" "expected true"
  }
  if ($manifest.capabilities.user_agent_profile_settings -eq $true) {
    Pass "manifest says agent profile settings are supported"
  } else {
    Fail "manifest says agent profile settings are supported" "expected true"
  }
  if ($manifest.capabilities.controlled_forum_gateway -eq $true) {
    Pass "manifest says controlled forum gateway is supported"
  } else {
    Fail "manifest says controlled forum gateway is supported" "expected true"
  }
  if ($manifest.safety.drafting_does_not_publish -eq $true) {
    Pass "manifest says drafting does not publish"
  } else {
    Fail "manifest says drafting does not publish" "expected true"
  }
  if ($manifest.safety.confirmed_writes_are_audited -eq $true) {
    Pass "manifest says confirmed writes are audited"
  } else {
    Fail "manifest says confirmed writes are audited" "expected true"
  }
  if ($manifest.safety.nexus_agent_tokens_restrict_raw_flarum_writes -eq $true) {
    Pass "manifest says Nexus agent tokens restrict raw Flarum writes"
  } else {
    Fail "manifest says Nexus agent tokens restrict raw Flarum writes" "expected true"
  }
} catch {
  Fail "manifest parses as JSON" $_.Exception.Message
}

$openApiResponse = Invoke-NexusHttp -Method "GET" -Path "/docs/openapi.json"
try {
  $openApi = $openApiResponse.Content | ConvertFrom-Json
  if ($openApi.openapi -like "3.*") {
    Pass "OpenAPI version" $openApi.openapi
  } else {
    Fail "OpenAPI version" "unexpected value: $($openApi.openapi)"
  }

  $requiredPaths = @(
    "/api",
    "/api/token",
    "/api/access-tokens",
    "/api/access-tokens/{id}",
    "/api/tags",
    "/api/discussions",
    "/api/nexus/agent-health",
    "/api/nexus/me/agent-context",
    "/api/nexus/agent-preflight",
    "/api/nexus/capability-labels",
    "/api/nexus/capabilities",
    "/api/nexus/need-drafts",
    "/api/nexus/forum/discussions",
    "/api/nexus/forum/discussions/{id}/posts",
    "/api/nexus/forum/posts/{id}",
    "/api/nexus/me/agent-profile",
    "/api/nexus/me/capabilities",
    "/api/nexus/me/action-logs",
    "/api/nexus/me/discussions",
    "/api/nexus/me/posts",
    "/api/nexus/me/help-requests",
    "/api/nexus/help-requests",
    "/api/nexus/help-requests/{id}",
    "/api/nexus/help-requests/{id}/candidates",
    "/api/nexus/help-requests/{id}/dispatches",
    "/api/nexus/help-requests/{id}/matches",
    "/api/nexus/me/dispatches",
    "/api/nexus/me/matches",
    "/api/nexus/me/work-items",
    "/api/nexus/dispatches/{id}",
    "/api/nexus/matches/{id}",
    "/api/nexus/matches/{id}/messages",
    "/api/nexus/me/device-signals",
    "/api/nexus/device-signals",
    "/api/nexus/llm-settings"
  )

  $openApiPathNames = @($openApi.paths.PSObject.Properties | ForEach-Object { $_.Name })

  foreach ($requiredPath in $requiredPaths) {
    if ($openApiPathNames -contains $requiredPath) {
      Pass "OpenAPI path" $requiredPath
    } else {
      Fail "OpenAPI path" "missing $requiredPath"
    }
  }

  $openApiOperations = @()
  foreach ($pathProperty in $openApi.paths.PSObject.Properties) {
    foreach ($methodProperty in $pathProperty.Value.PSObject.Properties) {
      if ($methodProperty.Name -in @("get", "post", "patch", "delete")) {
        $operationTags = @(As-Array $methodProperty.Value.tags | ForEach-Object { [string] $_ })
        $openApiOperations += [pscustomobject] @{
          Method = $methodProperty.Name.ToUpper()
          Path = $pathProperty.Name
          OperationId = [string] $methodProperty.Value.operationId
          Tags = $operationTags
        }
      }
    }
  }
  $missingOperationIds = @($openApiOperations | Where-Object { -not $_.OperationId })
  if ($missingOperationIds.Count -eq 0) {
    Pass "OpenAPI operationIds complete" "count=$($openApiOperations.Count)"
  } else {
    Fail "OpenAPI operationIds complete" "missing $($missingOperationIds.Count)"
  }
  $duplicateOperationIds = @($openApiOperations | Where-Object { $_.OperationId } | Group-Object OperationId | Where-Object { $_.Count -gt 1 })
  if ($duplicateOperationIds.Count -eq 0) {
    Pass "OpenAPI operationIds unique"
  } else {
    Fail "OpenAPI operationIds unique" "duplicates=$(@($duplicateOperationIds | ForEach-Object { $_.Name }) -join ",")"
  }
  $untaggedOperations = @($openApiOperations | Where-Object { $_.Tags.Count -eq 0 -or -not $_.Tags[0] })
  if ($untaggedOperations.Count -eq 0) {
    Pass "OpenAPI operation tags complete"
  } else {
    Fail "OpenAPI operation tags complete" "untagged $($untaggedOperations.Count)"
  }
  $openApiTagNames = @($openApi.tags | ForEach-Object { [string] $_.name })
  foreach ($requiredTag in @("Nexus Discovery", "Nexus Agent Skill", "Nexus Help Requests", "Nexus Dispatches", "Nexus Matches", "Nexus Forum Gateway", "Flarum Auth")) {
    if ($openApiTagNames -contains $requiredTag) {
      Pass "OpenAPI tag" $requiredTag
    } else {
      Fail "OpenAPI tag" "missing $requiredTag"
    }
  }
  $openApiOperationIds = @($openApiOperations | ForEach-Object { $_.OperationId })
  foreach ($requiredOperationId in @("nexusAgentHealthShow", "nexusMyAgentContextShow", "nexusAgentPreflightCreate", "nexusNeedDraftCreate", "nexusHelpRequestsList", "nexusHelpRequestShow", "nexusHelpRequestCreate", "nexusHelpCandidatesList", "nexusHelpDispatchCreate", "nexusDispatchUpdate", "nexusHelpMatchCreate", "nexusMatchUpdate", "nexusMatchMessageCreate", "nexusMyWorkItemsList", "nexusForumDiscussionsList", "nexusForumDiscussionShow", "nexusForumDiscussionCreate", "nexusForumDiscussionPostCreate", "nexusMyForumDiscussionsList", "nexusMyForumPostsList", "nexusForumPostUpdate", "nexusForumPostDelete")) {
    if ($openApiOperationIds -contains $requiredOperationId) {
      Pass "OpenAPI operationId" $requiredOperationId
    } else {
      Fail "OpenAPI operationId" "missing $requiredOperationId"
    }
  }

  Assert-JsonPath "OpenAPI has NeedDraftDiscoveryPlan schema" $openApi.components.schemas "NeedDraftDiscoveryPlan"
  Assert-JsonPath "OpenAPI has NeedDraftLabelReuse schema" $openApi.components.schemas "NeedDraftLabelReuse"
  Assert-JsonPath "OpenAPI has NeedDraftLabelReuseSearch schema" $openApi.components.schemas "NeedDraftLabelReuseSearch"
  Assert-JsonPath "OpenAPI has AgentHealth schema" $openApi.components.schemas "AgentHealth"
  Assert-JsonPath "OpenAPI has AgentEndpointMap schema" $openApi.components.schemas "AgentEndpointMap"
  Assert-JsonPath "OpenAPI has OpenApiTooling schema" $openApi.components.schemas "OpenApiTooling"
  Assert-JsonPath "OpenAPI has Nexus agent skill extension" $openApi "x-nexus-agent-skill"
  $openApiNexusSkill = $openApi.PSObject.Properties["x-nexus-agent-skill"].Value
  Assert-JsonPath "OpenAPI Nexus skill extension has root agent entry" $openApiNexusSkill "root_agent_entry"
  Assert-JsonPath "OpenAPI Nexus skill extension has agent tools" $openApiNexusSkill "agent_tools"
  Assert-JsonPath "OpenAPI Nexus skill extension has manifest" $openApiNexusSkill "manifest"
  Assert-JsonPath "OpenAPI Nexus skill extension has core operationIds" $openApiNexusSkill "core_operation_ids"
  Assert-JsonPath "OpenAPI Nexus skill extension has agent recipes" $openApiNexusSkill "agent_recipes"
  Assert-JsonPath "OpenAPI Nexus skill extension has core tool matrix" $openApiNexusSkill "core_tool_matrix"
  Assert-JsonPath "OpenAPI Nexus skill extension has forum operationIds" $openApiNexusSkill "forum_operation_ids"
  Assert-JsonPath "OpenAPI Nexus skill extension has forum tool matrix" $openApiNexusSkill "forum_tool_matrix"
  $openApiMatrixKeys = @($openApiNexusSkill.core_tool_matrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingOpenApiMatrixKeys = @($coreMatrixKeysSnake | Where-Object { $openApiMatrixKeys -notcontains $_ })
  if ($missingOpenApiMatrixKeys.Count -eq 0) {
    Pass "OpenAPI Nexus skill core tool matrix has all core tasks"
  } else {
    Fail "OpenAPI Nexus skill core tool matrix has all core tasks" "missing=$($missingOpenApiMatrixKeys -join ",")"
  }
  if ($openApiNexusSkill.core_tool_matrix.create_help_request.write_operation_id -eq "nexusHelpRequestCreate" -and $openApiNexusSkill.core_tool_matrix.find_candidate_helpers.read_operation_id -eq "nexusHelpCandidatesList" -and $openApiNexusSkill.core_tool_matrix.poll_work_queue.read_operation_id -eq "nexusMyWorkItemsList") {
    Pass "OpenAPI Nexus skill core tool matrix exposes core operationIds"
  } else {
    Fail "OpenAPI Nexus skill core tool matrix exposes core operationIds" "unexpected core_tool_matrix operation ids"
  }
  $openApiForumMatrixKeys = @($openApiNexusSkill.forum_tool_matrix.PSObject.Properties | ForEach-Object { $_.Name })
  $missingOpenApiForumMatrixKeys = @($forumMatrixKeysSnake | Where-Object { $openApiForumMatrixKeys -notcontains $_ })
  if ($missingOpenApiForumMatrixKeys.Count -eq 0) {
    Pass "OpenAPI Nexus skill forum tool matrix has all forum tasks"
  } else {
    Fail "OpenAPI Nexus skill forum tool matrix has all forum tasks" "missing=$($missingOpenApiForumMatrixKeys -join ",")"
  }
  if ($openApiNexusSkill.forum_operation_ids.forum_discussion_show -eq "nexusForumDiscussionShow" -and $openApiNexusSkill.forum_operation_ids.forum_discussion_create -eq "nexusForumDiscussionCreate" -and $openApiNexusSkill.forum_operation_ids.my_forum_posts -eq "nexusMyForumPostsList") {
    Pass "OpenAPI Nexus skill extension exposes forum operationIds"
  } else {
    Fail "OpenAPI Nexus skill extension exposes forum operationIds" "forum_discussion_show=$($openApiNexusSkill.forum_operation_ids.forum_discussion_show) forum_discussion_create=$($openApiNexusSkill.forum_operation_ids.forum_discussion_create) my_forum_posts=$($openApiNexusSkill.forum_operation_ids.my_forum_posts)"
  }
  $openApiReplyReadFirst = @(As-Array $openApiNexusSkill.forum_tool_matrix.reply_to_forum_discussion.read_first | ForEach-Object { [string] $_.name })
  if ($openApiNexusSkill.forum_tool_matrix.search_forum_discussions.read_operation_id -eq "nexusForumDiscussionsList" -and $openApiNexusSkill.forum_tool_matrix.open_forum_discussion.read_operation_id -eq "nexusForumDiscussionShow" -and ($openApiReplyReadFirst -contains "open_forum_discussion") -and $openApiNexusSkill.forum_tool_matrix.create_forum_discussion.write_operation_id -eq "nexusForumDiscussionCreate" -and $openApiNexusSkill.forum_tool_matrix.reply_to_forum_discussion.write_operation_id -eq "nexusForumDiscussionPostCreate" -and $openApiNexusSkill.forum_tool_matrix.recover_my_forum_posts.read_operation_id -eq "nexusMyForumPostsList" -and $openApiNexusSkill.forum_tool_matrix.hide_own_forum_post.write_operation_id -eq "nexusForumPostDelete") {
    Pass "OpenAPI Nexus skill forum tool matrix exposes forum operationIds"
  } else {
    Fail "OpenAPI Nexus skill forum tool matrix exposes forum operationIds" "unexpected forum_tool_matrix operation ids"
  }
  if ($openApiNexusSkill.forum_tool_matrix.create_forum_discussion.response_schema_ref -eq "#/components/schemas/FlarumDiscussionDocument" -and $openApiNexusSkill.forum_tool_matrix.reply_to_forum_discussion.response_schema_ref -eq "#/components/schemas/FlarumPostDocument" -and $openApiNexusSkill.forum_tool_matrix.edit_own_forum_post.response_schema_ref -eq "#/components/schemas/FlarumPostDocument") {
    Pass "OpenAPI Nexus skill forum write tasks use concrete response schemas"
  } else {
    Fail "OpenAPI Nexus skill forum write tasks use concrete response schemas" "create=$($openApiNexusSkill.forum_tool_matrix.create_forum_discussion.response_schema_ref) reply=$($openApiNexusSkill.forum_tool_matrix.reply_to_forum_discussion.response_schema_ref) edit=$($openApiNexusSkill.forum_tool_matrix.edit_own_forum_post.response_schema_ref)"
  }
  Assert-JsonPath "OpenAPI AgentHealth has OpenAPI tooling" $openApi.components.schemas.AgentHealth.properties "openApiTooling"
  Assert-JsonPath "OpenAPI AgentContext has OpenAPI tooling" $openApi.components.schemas.AgentContext.properties "openApiTooling"
  Assert-JsonPath "OpenAPI AgentEndpointMap has forumDiscussion" $openApi.components.schemas.AgentEndpointMap.properties "forumDiscussion"
  Assert-JsonPath "OpenAPI AgentEndpointMap has helpCandidates" $openApi.components.schemas.AgentEndpointMap.properties "helpCandidates"
  Assert-JsonPath "OpenAPI AgentEndpointMap has matchMessages" $openApi.components.schemas.AgentEndpointMap.properties "matchMessages"
  Assert-JsonPath "OpenAPI AgentEndpointMap has myDeviceSignals" $openApi.components.schemas.AgentEndpointMap.properties "myDeviceSignals"
  if (($openApi.components.schemas.AgentHealth.properties.endpoints.'$ref') -eq "#/components/schemas/AgentEndpointMap" -and ($openApi.components.schemas.AgentContext.properties.endpoints.'$ref') -eq "#/components/schemas/AgentEndpointMap") {
    Pass "OpenAPI endpoint fields use AgentEndpointMap"
  } else {
    Fail "OpenAPI endpoint fields use AgentEndpointMap" "health=$($openApi.components.schemas.AgentHealth.properties.endpoints.'$ref') context=$($openApi.components.schemas.AgentContext.properties.endpoints.'$ref')"
  }
  if ($openApi.components.schemas.AgentEndpointMap.additionalProperties.type -eq "string" -and $openApi.components.schemas.AgentEndpointMap.properties.helpCandidates.example -eq "/api/nexus/help-requests/{id}/candidates") {
    Pass "OpenAPI AgentEndpointMap documents known keys"
  } else {
    Fail "OpenAPI AgentEndpointMap documents known keys" "unexpected endpoint map schema"
  }
  if ([string] $agentHealthAttrs.nexus.openApiVersion -eq [string] $openApi.info.version -and [string] $agentHealthAttrs.openApiTooling.openApiVersion -eq [string] $openApi.info.version) {
    Pass "agent health OpenAPI version matches contract" $openApi.info.version
  } else {
    Fail "agent health OpenAPI version matches contract" "health=$($agentHealthAttrs.nexus.openApiVersion) tooling=$($agentHealthAttrs.openApiTooling.openApiVersion) openapi=$($openApi.info.version)"
  }
  if ([string] $openApiNexusSkill.openapi_version -eq [string] $openApi.info.version) {
    Pass "OpenAPI Nexus skill extension version matches contract" $openApi.info.version
  } else {
    Fail "OpenAPI Nexus skill extension version matches contract" "extension=$($openApiNexusSkill.openapi_version) openapi=$($openApi.info.version)"
  }
  if ([string] $openApiNexusSkill.root_agent_entry -eq "/llms.txt" -and [string] $openApiNexusSkill.agent_tools -eq "/docs/agent-tools.json" -and [string] $openApiNexusSkill.manifest -eq "/.well-known/nexus-agent.json" -and [string] $openApiNexusSkill.agent_quickstart -eq "/docs/agent-quickstart.md" -and [string] $openApiNexusSkill.nexus_skill -eq "/docs/nexus-skill.md" -and [string] $openApiNexusSkill.agent_recipes -eq "/docs/agent-recipes.md") {
    Pass "OpenAPI Nexus skill extension links public docs"
  } else {
    Fail "OpenAPI Nexus skill extension links public docs" "root=$($openApiNexusSkill.root_agent_entry) tools=$($openApiNexusSkill.agent_tools) manifest=$($openApiNexusSkill.manifest) quickstart=$($openApiNexusSkill.agent_quickstart) skill=$($openApiNexusSkill.nexus_skill) recipes=$($openApiNexusSkill.agent_recipes)"
  }
  if ([string] $manifest.api.openapi_tooling.openapi_version -eq [string] $openApi.info.version) {
    Pass "manifest OpenAPI tooling version matches contract" $openApi.info.version
  } else {
    Fail "manifest OpenAPI tooling version matches contract" "manifest=$($manifest.api.openapi_tooling.openapi_version) openapi=$($openApi.info.version)"
  }
  if ($openApiNexusSkill.core_operation_ids.agent_preflight -eq $manifest.api.openapi_tooling.core_operation_ids.agent_preflight -and $openApiNexusSkill.core_operation_ids.my_work_items -eq $manifest.api.openapi_tooling.core_operation_ids.my_work_items) {
    Pass "OpenAPI Nexus skill extension core operationIds match manifest"
  } else {
    Fail "OpenAPI Nexus skill extension core operationIds match manifest" "openapiAgentPreflight=$($openApiNexusSkill.core_operation_ids.agent_preflight) manifestAgentPreflight=$($manifest.api.openapi_tooling.core_operation_ids.agent_preflight)"
  }
  if ($openApiNexusSkill.core_tool_matrix.create_help_request.write_operation_id -eq $manifest.api.openapi_tooling.core_tool_matrix.create_help_request.write_operation_id -and $openApiNexusSkill.core_tool_matrix.poll_work_queue.read_operation_id -eq $manifest.api.openapi_tooling.core_tool_matrix.poll_work_queue.read_operation_id) {
    Pass "OpenAPI Nexus skill core tool matrix matches manifest"
  } else {
    Fail "OpenAPI Nexus skill core tool matrix matches manifest" "openapiCreate=$($openApiNexusSkill.core_tool_matrix.create_help_request.write_operation_id) manifestCreate=$($manifest.api.openapi_tooling.core_tool_matrix.create_help_request.write_operation_id)"
  }
  if ($openApiNexusSkill.forum_operation_ids.forum_discussion_show -eq $manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show -and $openApiNexusSkill.forum_operation_ids.forum_discussion_create -eq $manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create -and $openApiNexusSkill.forum_operation_ids.my_forum_posts -eq $manifest.api.openapi_tooling.forum_operation_ids.my_forum_posts) {
    Pass "OpenAPI Nexus skill extension forum operationIds match manifest"
  } else {
    Fail "OpenAPI Nexus skill extension forum operationIds match manifest" "openapiForumShow=$($openApiNexusSkill.forum_operation_ids.forum_discussion_show) manifestForumShow=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show) openapiForumCreate=$($openApiNexusSkill.forum_operation_ids.forum_discussion_create) manifestForumCreate=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create)"
  }
  if ($openApiNexusSkill.forum_tool_matrix.open_forum_discussion.read_operation_id -eq $manifest.api.openapi_tooling.forum_tool_matrix.open_forum_discussion.read_operation_id -and $openApiNexusSkill.forum_tool_matrix.create_forum_discussion.write_operation_id -eq $manifest.api.openapi_tooling.forum_tool_matrix.create_forum_discussion.write_operation_id -and $openApiNexusSkill.forum_tool_matrix.hide_own_forum_post.write_operation_id -eq $manifest.api.openapi_tooling.forum_tool_matrix.hide_own_forum_post.write_operation_id) {
    Pass "OpenAPI Nexus skill forum tool matrix matches manifest"
  } else {
    Fail "OpenAPI Nexus skill forum tool matrix matches manifest" "openapiOpen=$($openApiNexusSkill.forum_tool_matrix.open_forum_discussion.read_operation_id) manifestOpen=$($manifest.api.openapi_tooling.forum_tool_matrix.open_forum_discussion.read_operation_id) openapiCreate=$($openApiNexusSkill.forum_tool_matrix.create_forum_discussion.write_operation_id) manifestCreate=$($manifest.api.openapi_tooling.forum_tool_matrix.create_forum_discussion.write_operation_id)"
  }
  if ($manifest.api.openapi_tooling.core_operation_ids.agent_preflight -eq $agentHealthAttrs.openApiTooling.coreOperationIds.agentPreflight -and $manifest.api.openapi_tooling.core_operation_ids.my_work_items -eq $agentHealthAttrs.openApiTooling.coreOperationIds.myWorkItems) {
    Pass "manifest core operationIds match runtime tooling"
  } else {
    Fail "manifest core operationIds match runtime tooling" "manifestAgentPreflight=$($manifest.api.openapi_tooling.core_operation_ids.agent_preflight) runtimeAgentPreflight=$($agentHealthAttrs.openApiTooling.coreOperationIds.agentPreflight)"
  }
  if ($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show -eq $agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow -and $manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create -eq $agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate -and $manifest.api.openapi_tooling.forum_operation_ids.my_forum_posts -eq $agentHealthAttrs.openApiTooling.forumOperationIds.myForumPosts) {
    Pass "manifest forum operationIds match runtime tooling"
  } else {
    Fail "manifest forum operationIds match runtime tooling" "manifestForumShow=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show) runtimeForumShow=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow) manifestForumCreate=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create) runtimeForumCreate=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate)"
  }
  if ($openApi.components.schemas.OpenApiTooling.properties.coreOperationIds.properties.agentPreflight.example -eq "nexusAgentPreflightCreate" -and $openApi.components.schemas.OpenApiTooling.properties.coreOperationIds.properties.myWorkItems.example -eq "nexusMyWorkItemsList") {
    Pass "OpenAPI tooling schema includes core operationId examples"
  } else {
    Fail "OpenAPI tooling schema includes core operationId examples" "unexpected core operationId examples"
  }
  $openApiToolingRequired = @(As-Array $openApi.components.schemas.OpenApiTooling.required | ForEach-Object { [string] $_ })
  if ($openApiToolingRequired -contains "agentToolContract" -and [string] $openApi.components.schemas.OpenApiTooling.properties.agentToolContract.const -eq "/docs/agent-tools.json") {
    Pass "OpenAPI tooling schema includes agent tool contract"
  } else {
    Fail "OpenAPI tooling schema includes agent tool contract" "required=$($openApiToolingRequired -join ",") agentToolContract=$($openApi.components.schemas.OpenApiTooling.properties.agentToolContract.const)"
  }
  if ($openApi.components.schemas.OpenApiTooling.properties.coreToolMatrix.'$ref' -eq "#/components/schemas/AgentCoreToolMatrix") {
    Pass "OpenAPI tooling schema uses AgentCoreToolMatrix"
  } else {
    Fail "OpenAPI tooling schema uses AgentCoreToolMatrix" "coreToolMatrix=$($openApi.components.schemas.OpenApiTooling.properties.coreToolMatrix.'$ref')"
  }
  if ($openApi.components.schemas.OpenApiTooling.properties.forumToolMatrix.'$ref' -eq "#/components/schemas/AgentForumToolMatrix") {
    Pass "OpenAPI tooling schema uses AgentForumToolMatrix"
  } else {
    Fail "OpenAPI tooling schema uses AgentForumToolMatrix" "forumToolMatrix=$($openApi.components.schemas.OpenApiTooling.properties.forumToolMatrix.'$ref')"
  }
  if ($openApi.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.forumDiscussionShow.example -eq "nexusForumDiscussionShow" -and $openApi.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.forumDiscussionCreate.example -eq "nexusForumDiscussionCreate" -and $openApi.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.myForumPosts.example -eq "nexusMyForumPostsList") {
    Pass "OpenAPI tooling schema includes forum operationId examples"
  } else {
    Fail "OpenAPI tooling schema includes forum operationId examples" "unexpected forum operationId examples"
  }
  Assert-JsonPath "OpenAPI has NeedDraftAttributes schema" $openApi.components.schemas "NeedDraftAttributes"
  Assert-JsonPath "OpenAPI has NeedDraft document schema" $openApi.components.schemas "NeedDraftDocument"
  Assert-JsonPath "OpenAPI has HelpRequest document schema" $openApi.components.schemas "HelpRequestDocument"
  Assert-JsonPath "OpenAPI has HelpRequest collection schema" $openApi.components.schemas "HelpRequestCollectionDocument"
  Assert-JsonPath "OpenAPI has HelpCandidate collection schema" $openApi.components.schemas "HelpCandidateCollectionDocument"
  Assert-JsonPath "OpenAPI has WorkItem collection schema" $openApi.components.schemas "WorkItemCollectionDocument"
  Assert-JsonPath "OpenAPI has Flarum discussion document schema" $openApi.components.schemas "FlarumDiscussionDocument"
  Assert-JsonPath "OpenAPI has Flarum post document schema" $openApi.components.schemas "FlarumPostDocument"
  Assert-JsonPath "OpenAPI has AgentCoreToolMatrix schema" $openApi.components.schemas "AgentCoreToolMatrix"
  Assert-JsonPath "OpenAPI has AgentForumToolRecipe schema" $openApi.components.schemas "AgentForumToolRecipe"
  Assert-JsonPath "OpenAPI has AgentForumToolMatrix schema" $openApi.components.schemas "AgentForumToolMatrix"
  Assert-JsonPath "OpenAPI has AgentSkillInstructions schema" $openApi.components.schemas "AgentSkillInstructions"
  Assert-JsonPath "OpenAPI AgentSkillInstructions has labelReuse" $openApi.components.schemas.AgentSkillInstructions.properties "labelReuse"
  Assert-JsonPath "OpenAPI AgentSkillInstructions has candidateRouting" $openApi.components.schemas.AgentSkillInstructions.properties "candidateRouting"
  Assert-JsonPath "OpenAPI AgentSkillInstructions has errorRecovery" $openApi.components.schemas.AgentSkillInstructions.properties "errorRecovery"
  Assert-JsonPath "OpenAPI AgentSkillInstructions has taskRecipes" $openApi.components.schemas.AgentSkillInstructions.properties "taskRecipes"
  Assert-JsonPath "OpenAPI has AgentReadiness schema" $openApi.components.schemas "AgentReadiness"
  Assert-JsonPath "OpenAPI has AgentPreflightCatalog schema" $openApi.components.schemas "AgentPreflightCatalog"
  Assert-JsonPath "OpenAPI has AgentPreflightCatalogAction schema" $openApi.components.schemas "AgentPreflightCatalogAction"
  Assert-JsonPath "OpenAPI has AgentPreflightRecovery schema" $openApi.components.schemas "AgentPreflightRecovery"
  Assert-JsonPath "OpenAPI has AgentActionSideEffects schema" $openApi.components.schemas "AgentActionSideEffects"
  Assert-JsonPath "OpenAPI has AgentPreflightTemplate schema" $openApi.components.schemas "AgentPreflightTemplate"
  Assert-JsonPath "OpenAPI has JSON API error schema" $openApi.components.schemas "JsonApiErrorDocument"
  Assert-JsonPath "OpenAPI has AgentProfile document schema" $openApi.components.schemas "AgentProfileDocument"
  Assert-JsonPath "OpenAPI has user capability collection schema" $openApi.components.schemas "UserCapabilityCollectionDocument"
  Assert-JsonPath "OpenAPI has capability label collection schema" $openApi.components.schemas "CapabilityLabelCollectionDocument"
  Assert-JsonPath "OpenAPI NeedDraftAttributes has labelReuse" $openApi.components.schemas.NeedDraftAttributes.properties "labelReuse"
  Assert-JsonPath "OpenAPI CapabilityLabelAttributes has reuseGuidance" $openApi.components.schemas.CapabilityLabelAttributes.properties "reuseGuidance"
  Assert-JsonPath "OpenAPI CapabilityLabelAttributes has nextActions" $openApi.components.schemas.CapabilityLabelAttributes.properties "nextActions"
  Assert-JsonPath "OpenAPI has action log collection schema" $openApi.components.schemas "AgentActionLogCollectionDocument"
  Assert-JsonPath "OpenAPI has device signal collection schema" $openApi.components.schemas "DeviceSignalCollectionDocument"
  Assert-JsonPath "OpenAPI has LLM settings document schema" $openApi.components.schemas "LlmSettingsDocument"
  Assert-JsonPath "OpenAPI has dispatch collection schema" $openApi.components.schemas "HelpDispatchCollectionDocument"
  Assert-JsonPath "OpenAPI has match collection schema" $openApi.components.schemas "HelpMatchCollectionDocument"
  Assert-JsonPath "OpenAPI has match message collection schema" $openApi.components.schemas "HelpMatchMessageCollectionDocument"
  Assert-JsonPath "OpenAPI has HelpCandidateAttributes schema" $openApi.components.schemas "HelpCandidateAttributes"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has neededLabels" $openApi.components.schemas.HelpCandidateAttributes.properties "neededLabels"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has missingLabels" $openApi.components.schemas.HelpCandidateAttributes.properties "missingLabels"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has scoreBreakdown" $openApi.components.schemas.HelpCandidateAttributes.properties "scoreBreakdown"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has recommendation" $openApi.components.schemas.HelpCandidateAttributes.properties "recommendation"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has dispatchRationaleTemplate" $openApi.components.schemas.HelpCandidateAttributes.properties "dispatchRationaleTemplate"
  Assert-JsonPath "OpenAPI HelpCandidateAttributes has confirmationPromptHints" $openApi.components.schemas.HelpCandidateAttributes.properties "confirmationPromptHints"
  Assert-JsonPath "OpenAPI has HelpRequestAttributes schema" $openApi.components.schemas "HelpRequestAttributes"
  Assert-JsonPath "OpenAPI has AgentNextAction schema" $openApi.components.schemas "AgentNextAction"
  Assert-JsonPath "OpenAPI AgentNextAction has catalogAction" $openApi.components.schemas.AgentNextAction.properties "catalogAction"
  Assert-JsonPath "OpenAPI AgentNextAction has writeBodySchemaRef" $openApi.components.schemas.AgentNextAction.properties "writeBodySchemaRef"
  Assert-JsonPath "OpenAPI AgentNextAction has sideEffects" $openApi.components.schemas.AgentNextAction.properties "sideEffects"
  Assert-JsonPath "OpenAPI has AgentPreflightInput schema" $openApi.components.schemas "AgentPreflightInput"
  Assert-JsonPath "OpenAPI has AgentPreflightTarget schema" $openApi.components.schemas "AgentPreflightTarget"
  Assert-JsonPath "OpenAPI has WorkItemAttributes schema" $openApi.components.schemas "WorkItemAttributes"
  Assert-JsonPath "OpenAPI has HelpDispatchAttributes schema" $openApi.components.schemas "HelpDispatchAttributes"
  Assert-JsonPath "OpenAPI has HelpMatchAttributes schema" $openApi.components.schemas "HelpMatchAttributes"
  if (($openApi.paths."/api/nexus/me/agent-profile".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/AgentProfileDocument") {
    Pass "OpenAPI agent profile uses concrete document"
  } else {
    Fail "OpenAPI agent profile uses concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/need-drafts".post.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/NeedDraftDocument") {
    Pass "OpenAPI need drafts use concrete document"
  } else {
    Fail "OpenAPI need drafts use concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/help-requests".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestCollectionDocument" -and ($openApi.paths."/api/nexus/help-requests".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument") {
    Pass "OpenAPI help request collection/create use concrete documents"
  } else {
    Fail "OpenAPI help request collection/create use concrete documents" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/help-requests/{id}".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument" -and ($openApi.paths."/api/nexus/help-requests/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument") {
    Pass "OpenAPI help request show/update use concrete document"
  } else {
    Fail "OpenAPI help request show/update use concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/help-requests/{id}/candidates".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpCandidateCollectionDocument") {
    Pass "OpenAPI help candidates use concrete document"
  } else {
    Fail "OpenAPI help candidates use concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/forum/discussions".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumDiscussionDocument" -and ($openApi.paths."/api/nexus/forum/discussions/{id}/posts".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumPostDocument" -and ($openApi.paths."/api/nexus/forum/posts/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumPostDocument") {
    Pass "OpenAPI forum write responses use concrete documents"
  } else {
    Fail "OpenAPI forum write responses use concrete documents" "discussion=$($openApi.paths."/api/nexus/forum/discussions".post.responses."201".content."application/vnd.api+json".schema.'$ref') reply=$($openApi.paths."/api/nexus/forum/discussions/{id}/posts".post.responses."201".content."application/vnd.api+json".schema.'$ref') edit=$($openApi.paths."/api/nexus/forum/posts/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref')"
  }
  if (($openApi.paths."/api/nexus/me/work-items".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/WorkItemCollectionDocument") {
    Pass "OpenAPI work items use concrete document"
  } else {
    Fail "OpenAPI work items use concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/me/dispatches".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpDispatchCollectionDocument") {
    Pass "OpenAPI dispatch inbox uses concrete document"
  } else {
    Fail "OpenAPI dispatch inbox uses concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/matches/{id}/messages".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpMatchMessageCollectionDocument") {
    Pass "OpenAPI match messages use concrete document"
  } else {
    Fail "OpenAPI match messages use concrete document" "unexpected schema"
  }
  if (($openApi.paths."/api/nexus/llm-settings".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/LlmSettingsDocument") {
    Pass "OpenAPI LLM settings uses concrete document"
  } else {
    Fail "OpenAPI LLM settings uses concrete document" "unexpected schema"
  }
} catch {
  Fail "OpenAPI parses as JSON" $_.Exception.Message
}

Assert-Status "public tags API" "GET" "/api/tags" @(200) | Out-Null
$publicLabelResponse = Assert-Status "public capability labels API" "GET" "/api/nexus/capability-labels?sort=popular&page%5Blimit%5D=5" @(200)
$publicLabelSearchResponse = Assert-Status "public capability labels search API" "GET" "/api/nexus/capability-labels?inname=repair&page%5Blimit%5D=5" @(200)
try {
  $publicLabelSearchJson = $publicLabelSearchResponse.Content | ConvertFrom-Json
  $publicLabelItems = As-Array $publicLabelSearchJson.data
  if ($publicLabelItems.Count -gt 0) {
    $firstPublicLabelAttrs = $publicLabelItems[0].attributes
    Assert-JsonPath "public capability label has label" $firstPublicLabelAttrs "label"
    Assert-JsonPath "public capability label has helperCount" $firstPublicLabelAttrs "helperCount"
    Assert-JsonPath "public capability label has capabilityCount" $firstPublicLabelAttrs "capabilityCount"
    Assert-JsonPath "public capability label has sampleCapabilities" $firstPublicLabelAttrs "sampleCapabilities"
    Assert-JsonPath "public capability label has reuseGuidance" $firstPublicLabelAttrs "reuseGuidance"
    Assert-JsonPath "public capability label has nextActions" $firstPublicLabelAttrs "nextActions"
    $publicLabelActions = As-Array $firstPublicLabelAttrs.nextActions
    $publicLabelActionNames = @($publicLabelActions | ForEach-Object { [string] $_.name })
    if ($publicLabelActionNames -contains "find_helpers_with_label") {
      Pass "public capability label nextActions include helper search"
    } else {
      Fail "public capability label nextActions include helper search" "actions=$($publicLabelActionNames -join ",")"
    }
  } else {
    Skip "public capability label response fields" "no public labels matched repair in current data"
  }
} catch {
  Fail "public capability label search parses" $_.Exception.Message
}
Assert-Status "public capabilities API" "GET" "/api/nexus/capabilities" @(200) | Out-Null
Assert-Status "public help requests API" "GET" "/api/nexus/help-requests" @(200) | Out-Null
$forumSearchResponse = Assert-Status "public forum gateway search" "GET" "/api/nexus/forum/discussions?q=Nexus&page%5Blimit%5D=3" @(200)
try {
  $forumSearchJson = $forumSearchResponse.Content | ConvertFrom-Json
  $forumSearchData = @(As-Array $forumSearchJson.data)
  if ($forumSearchData.Count -gt 0) {
    $firstForumDiscussionId = [string] $forumSearchData[0].id
    $forumShowResponse = Assert-Status "public forum gateway opens discussion" "GET" "/api/nexus/forum/discussions/${firstForumDiscussionId}?include=user,tags,posts,posts.user&page%5Blimit%5D=5" @(200)
    try {
      $forumShowJson = $forumShowResponse.Content | ConvertFrom-Json
      if ($forumShowJson.data.type -eq "discussions" -and [string] $forumShowJson.data.id -eq $firstForumDiscussionId) {
        Pass "public forum gateway open discussion type" $firstForumDiscussionId
      } else {
        Fail "public forum gateway open discussion type" "type=$($forumShowJson.data.type) id=$($forumShowJson.data.id)"
      }
    } catch {
      Fail "public forum gateway open discussion parses" $_.Exception.Message
    }
  } else {
    Skip "public forum gateway opens discussion" "no public discussions returned by Nexus search"
  }
} catch {
  Fail "public forum gateway search parses" $_.Exception.Message
}

Assert-Status "private endpoint rejects guest" "GET" "/api/nexus/me/capabilities" @(401) | Out-Null
Assert-Status "agent profile rejects guest" "GET" "/api/nexus/me/agent-profile" @(401) | Out-Null
Assert-Status "action logs reject guest" "GET" "/api/nexus/me/action-logs" @(401) | Out-Null
Assert-Status "my matches reject guest" "GET" "/api/nexus/me/matches" @(401) | Out-Null
Assert-Status "my help requests reject guest" "GET" "/api/nexus/me/help-requests" @(401) | Out-Null
Assert-Status "my work items reject guest" "GET" "/api/nexus/me/work-items" @(401) | Out-Null
Assert-Status "agent context rejects guest" "GET" "/api/nexus/me/agent-context" @(401) | Out-Null
Assert-Status "my forum discussions reject guest" "GET" "/api/nexus/me/discussions" @(401) | Out-Null
Assert-Status "my forum posts reject guest" "GET" "/api/nexus/me/posts" @(401) | Out-Null
Assert-Status "my device signals reject guest" "GET" "/api/nexus/me/device-signals" @(401) | Out-Null

$needDraftBody = @{
  data = @{
    type = "nexus-need-drafts"
    attributes = @{
      rawUserNeed = "I am at the library and my laptop will not boot. I need nearby computer repair help."
      intent = "auto"
      locationHint = "library public desk"
    }
  }
}
$guestSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$guestRoot = Invoke-NexusHttp -Method "GET" -Path "/" -WebSession $guestSession

if ($guestRoot.Content -match '"csrfToken":"([^"]+)"') {
  $guestCsrfHeaders = @{ "X-CSRF-Token" = $Matches[1] }
  $agentPreflightGuestBody = @{
    data = @{
      type = "nexus-agent-preflights"
      attributes = @{
        action = "need_draft"
      }
    }
  }
  Assert-Status "agent preflight rejects guest" "POST" "/api/nexus/agent-preflight" @(401) $guestCsrfHeaders $agentPreflightGuestBody -WebSession $guestSession | Out-Null
  Assert-Status "need draft rejects guest" "POST" "/api/nexus/need-drafts" @(401) $guestCsrfHeaders $needDraftBody -WebSession $guestSession | Out-Null
} else {
  Fail "guest csrf extraction" "could not extract guest csrf token from forum shell"
}

if ($SkipAuthenticated) {
  Skip "authenticated checks" "disabled by -SkipAuthenticated"
} elseif (-not $authHeader) {
  Fail "authenticated checks" "missing NEXUS_AGENT_AUTH in $EnvFile"
} else {
  $authHeaders = @{ Authorization = $authHeader }

  $agentProfileAttrs = $null
  $smokeSoulMd = "Smoke profile for scripts/nexus-smoke.ps1. This should not appear in action-log summaries."
  $preflightNeedDraftBody = @{
    data = @{
      type = "nexus-agent-preflights"
      attributes = @{
        action = "need_draft"
      }
    }
  }
  $preflightNeedDraft = Assert-Status "agent preflight need draft authenticated" "POST" "/api/nexus/agent-preflight" @(200) $authHeaders $preflightNeedDraftBody
  try {
    $preflightNeedDraftJson = $preflightNeedDraft.Content | ConvertFrom-Json
    $preflightNeedDraftAttrs = $preflightNeedDraftJson.data.attributes

    if ($preflightNeedDraftJson.data.type -eq "nexus-agent-preflights" -and $preflightNeedDraftAttrs.allowed -eq $true) {
      Pass "agent preflight allows need draft"
    } else {
      Fail "agent preflight allows need draft" "unexpected response"
    }

    if ($preflightNeedDraftAttrs.notes.noDatabaseWrite -eq $true) {
      Pass "agent preflight says no database write"
    } else {
      Fail "agent preflight says no database write" "expected true"
    }
  } catch {
    Fail "agent preflight need draft parses" $_.Exception.Message
  }

  $preflightHelpBody = @{
    data = @{
      type = "nexus-agent-preflights"
      attributes = @{
        action = "help_request.create"
        userConfirmed = $false
      }
    }
  }
  $preflightHelp = Assert-Status "agent preflight help request authenticated" "POST" "/api/nexus/agent-preflight" @(200) $authHeaders $preflightHelpBody
  try {
    $preflightHelpJson = $preflightHelp.Content | ConvertFrom-Json
    $preflightHelpAttrs = $preflightHelpJson.data.attributes
    $preflightBlocking = As-Array $preflightHelpAttrs.blocking

    if ($preflightHelpAttrs.allowed -eq $false -and ($preflightBlocking -contains "userConfirmed")) {
      Pass "agent preflight blocks unconfirmed help request"
    } else {
      Fail "agent preflight blocks unconfirmed help request" "blocking=$($preflightBlocking -join ",")"
    }

    Assert-JsonPath "agent preflight exposes matching permission check" $preflightHelpAttrs.checks "allowAgentMatching"
    Assert-JsonPath "agent preflight exposes proposed fields" $preflightHelpAttrs "proposedFields"
    Assert-JsonPath "agent preflight exposes write schema ref" $preflightHelpAttrs "writeBodySchemaRef"
    Assert-JsonPath "agent preflight exposes side effects" $preflightHelpAttrs "sideEffects"
    Assert-JsonPath "agent preflight exposes recovery" $preflightHelpAttrs "recovery"
    if ($preflightHelpAttrs.recovery.status -eq "blocked_needs_recovery" -and $preflightHelpAttrs.recovery.retryPolicy.retrySameBody -eq $false) {
      Pass "agent preflight recovery blocks same-body retry"
    } else {
      Fail "agent preflight recovery blocks same-body retry" "status=$($preflightHelpAttrs.recovery.status) retrySameBody=$($preflightHelpAttrs.recovery.retryPolicy.retrySameBody)"
    }
    $preflightRecoverySteps = As-Array $preflightHelpAttrs.recovery.steps
    $confirmRecovery = @($preflightRecoverySteps | Where-Object { [string] $_.name -eq "ask_user_to_confirm_exact_action" } | Select-Object -First 1)
    if ($confirmRecovery.Count -eq 1 -and $confirmRecovery[0].requiresUserConfirmation -eq $true) {
      Pass "agent preflight recovery includes confirmation step"
    } else {
      Fail "agent preflight recovery includes confirmation step" "unexpected recovery steps"
    }
    if ($preflightHelpAttrs.writeBodySchemaRef -eq "#/components/schemas/HelpRequestInput") {
      Pass "agent preflight help request schema ref"
    } else {
      Fail "agent preflight help request schema ref" "unexpected ref: $($preflightHelpAttrs.writeBodySchemaRef)"
    }
    if ($preflightHelpAttrs.sideEffects.createsPublicDiscussion -eq $true -and [string] $preflightHelpAttrs.sideEffects.serverAppendedFooter) {
      Pass "agent preflight help request side effects"
    } else {
      Fail "agent preflight help request side effects" "missing createsPublicDiscussion/serverAppendedFooter"
    }
  } catch {
    Fail "agent preflight help request parses" $_.Exception.Message
  }

  $agentContextRead = Assert-Status "agent context authenticated" "GET" "/api/nexus/me/agent-context" @(200) $authHeaders
  try {
    $agentContext = $agentContextRead.Content | ConvertFrom-Json
    $agentContextAttrs = $agentContext.data.attributes

    if ($agentContext.data.type -eq "nexus-agent-contexts") {
      Pass "agent context type"
    } else {
      Fail "agent context type" "unexpected type: $($agentContext.data.type)"
    }

    Assert-JsonPath "agent context has docs" $agentContextAttrs "docs"
    Assert-JsonPath "agent context docs has root agent entry" $agentContextAttrs.docs "rootAgentEntry"
    Assert-JsonPath "agent context docs has agent tools" $agentContextAttrs.docs "agentTools"
    Assert-JsonPath "agent context docs has agent recipes" $agentContextAttrs.docs "agentRecipes"
    if ([string] $agentContextAttrs.docs.rootAgentEntry -eq (Join-Url $Script:BaseUrl "/llms.txt") -and [string] $agentContextAttrs.docs.agentTools -eq (Join-Url $Script:BaseUrl "/docs/agent-tools.json") -and [string] $agentContextAttrs.docs.agentRecipes -eq (Join-Url $Script:BaseUrl "/docs/agent-recipes.md") -and [string] $agentContextAttrs.docs.openapi -eq (Join-Url $Script:BaseUrl "/docs/openapi.json") -and [string] $agentContextAttrs.docs.manifest -eq (Join-Url $Script:BaseUrl "/.well-known/nexus-agent.json")) {
      Pass "agent context docs use request origin"
    } else {
      Fail "agent context docs use request origin" "root=$($agentContextAttrs.docs.rootAgentEntry) tools=$($agentContextAttrs.docs.agentTools) recipes=$($agentContextAttrs.docs.agentRecipes) openapi=$($agentContextAttrs.docs.openapi) manifest=$($agentContextAttrs.docs.manifest)"
    }
    Assert-JsonPath "agent context has endpoints" $agentContextAttrs "endpoints"
    Assert-JsonPath "agent context has OpenAPI tooling" $agentContextAttrs "openApiTooling"
    Assert-JsonPath "agent context tooling has agent tool contract" $agentContextAttrs.openApiTooling "agentToolContract"
    Assert-JsonPath "agent context tooling has core operationIds" $agentContextAttrs.openApiTooling "coreOperationIds"
    Assert-JsonPath "agent context tooling has core tool matrix" $agentContextAttrs.openApiTooling "coreToolMatrix"
    Assert-JsonPath "agent context tooling has forum operationIds" $agentContextAttrs.openApiTooling "forumOperationIds"
    Assert-JsonPath "agent context tooling has forum tool matrix" $agentContextAttrs.openApiTooling "forumToolMatrix"
    if ([string] $agentContextAttrs.openApiTooling.agentToolContract -eq "/docs/agent-tools.json") {
      Pass "agent context tooling exposes agent tool contract"
    } else {
      Fail "agent context tooling exposes agent tool contract" "agentToolContract=$($agentContextAttrs.openApiTooling.agentToolContract)"
    }
    if ([string] $agentContextAttrs.openApiTooling.openApiVersion -eq [string] $openApi.info.version -and $agentContextAttrs.openApiTooling.coreOperationIds.agentPreflight -eq "nexusAgentPreflightCreate" -and $agentContextAttrs.openApiTooling.coreOperationIds.myWorkItems -eq "nexusMyWorkItemsList") {
      Pass "agent context exposes runtime OpenAPI tooling"
    } else {
      Fail "agent context exposes runtime OpenAPI tooling" "version=$($agentContextAttrs.openApiTooling.openApiVersion) agentPreflight=$($agentContextAttrs.openApiTooling.coreOperationIds.agentPreflight) myWorkItems=$($agentContextAttrs.openApiTooling.coreOperationIds.myWorkItems)"
    }
    if ($agentContextAttrs.openApiTooling.forumOperationIds.forumDiscussionShow -eq "nexusForumDiscussionShow" -and $agentContextAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate -eq "nexusForumDiscussionCreate" -and $agentContextAttrs.openApiTooling.forumOperationIds.myForumPosts -eq "nexusMyForumPostsList") {
      Pass "agent context exposes runtime forum operationIds"
    } else {
      Fail "agent context exposes runtime forum operationIds" "forumDiscussionShow=$($agentContextAttrs.openApiTooling.forumOperationIds.forumDiscussionShow) forumDiscussionCreate=$($agentContextAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate) myForumPosts=$($agentContextAttrs.openApiTooling.forumOperationIds.myForumPosts)"
    }
    $agentContextMatrixKeys = @($agentContextAttrs.openApiTooling.coreToolMatrix.PSObject.Properties | ForEach-Object { $_.Name })
    $missingAgentContextMatrixKeys = @($coreMatrixKeysCamel | Where-Object { $agentContextMatrixKeys -notcontains $_ })
    if ($missingAgentContextMatrixKeys.Count -eq 0) {
      Pass "agent context core tool matrix has all core tasks"
    } else {
      Fail "agent context core tool matrix has all core tasks" "missing=$($missingAgentContextMatrixKeys -join ",")"
    }
    if ($agentContextAttrs.openApiTooling.coreToolMatrix.createHelpRequest.writeOperationId -eq "nexusHelpRequestCreate" -and $agentContextAttrs.openApiTooling.coreToolMatrix.findCandidateHelpers.readOperationId -eq "nexusHelpCandidatesList" -and $agentContextAttrs.openApiTooling.coreToolMatrix.pollWorkQueue.readOperationId -eq "nexusMyWorkItemsList") {
      Pass "agent context exposes runtime core tool matrix"
    } else {
      Fail "agent context exposes runtime core tool matrix" "unexpected coreToolMatrix"
    }
    $agentContextForumMatrixKeys = @($agentContextAttrs.openApiTooling.forumToolMatrix.PSObject.Properties | ForEach-Object { $_.Name })
    $missingAgentContextForumMatrixKeys = @($forumMatrixKeysCamel | Where-Object { $agentContextForumMatrixKeys -notcontains $_ })
    if ($missingAgentContextForumMatrixKeys.Count -eq 0) {
      Pass "agent context forum tool matrix has all forum tasks"
    } else {
      Fail "agent context forum tool matrix has all forum tasks" "missing=$($missingAgentContextForumMatrixKeys -join ",")"
    }
    $agentContextReplyReadFirst = @(As-Array $agentContextAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.readFirst | ForEach-Object { [string] $_.name })
    if ($agentContextAttrs.openApiTooling.forumToolMatrix.searchForumDiscussions.readOperationId -eq "nexusForumDiscussionsList" -and $agentContextAttrs.openApiTooling.forumToolMatrix.openForumDiscussion.readOperationId -eq "nexusForumDiscussionShow" -and ($agentContextReplyReadFirst -contains "open_forum_discussion") -and $agentContextAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.writeOperationId -eq "nexusForumDiscussionCreate" -and $agentContextAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.writeOperationId -eq "nexusForumDiscussionPostCreate" -and $agentContextAttrs.openApiTooling.forumToolMatrix.recoverMyForumPosts.readOperationId -eq "nexusMyForumPostsList" -and $agentContextAttrs.openApiTooling.forumToolMatrix.hideOwnForumPost.writeOperationId -eq "nexusForumPostDelete") {
      Pass "agent context exposes runtime forum tool matrix"
    } else {
      Fail "agent context exposes runtime forum tool matrix" "unexpected forumToolMatrix"
    }
    Assert-JsonPath "agent context has profile summary" $agentContextAttrs "agentProfile"
    Assert-JsonPath "agent context has preflight catalog" $agentContextAttrs "agentPreflight"
    Assert-JsonPath "agent context has work queue" $agentContextAttrs "workQueue"
    Assert-JsonPath "agent context has readiness" $agentContextAttrs "agentReadiness"
    Assert-JsonPath "agent context has skill instructions" $agentContextAttrs "skillInstructions"
    Assert-JsonPath "agent context has operating rules" $agentContextAttrs "operatingRules"
    Assert-JsonPath "agent context endpoints include agent preflight" $agentContextAttrs.endpoints "agentPreflight"
    Assert-JsonPath "agent context endpoints include need drafts" $agentContextAttrs.endpoints "needDrafts"
    $expectedAgentContextEndpoints = @{
      "capabilities" = "/api/nexus/capabilities"
      "forumDiscussion" = "/api/nexus/forum/discussions/{id}"
      "forumDiscussionPosts" = "/api/nexus/forum/discussions/{id}/posts"
      "forumPost" = "/api/nexus/forum/posts/{id}"
      "helpRequest" = "/api/nexus/help-requests/{id}"
      "helpCandidates" = "/api/nexus/help-requests/{id}/candidates"
      "helpDispatches" = "/api/nexus/help-requests/{id}/dispatches"
      "helpMatches" = "/api/nexus/help-requests/{id}/matches"
      "dispatch" = "/api/nexus/dispatches/{id}"
      "match" = "/api/nexus/matches/{id}"
      "matchMessages" = "/api/nexus/matches/{id}/messages"
      "myForumDiscussions" = "/api/nexus/me/discussions"
      "myForumPosts" = "/api/nexus/me/posts"
      "myDeviceSignals" = "/api/nexus/me/device-signals"
      "deviceSignals" = "/api/nexus/device-signals"
    }
    foreach ($entry in $expectedAgentContextEndpoints.GetEnumerator()) {
      Assert-JsonPath "agent context endpoints include $($entry.Key)" $agentContextAttrs.endpoints $entry.Key
      $actualEndpoint = [string] $agentContextAttrs.endpoints.PSObject.Properties[$entry.Key].Value
      if ($actualEndpoint -eq $entry.Value) {
        Pass "agent context endpoint value $($entry.Key)" $actualEndpoint
      } else {
        Fail "agent context endpoint value $($entry.Key)" "expected $($entry.Value), got $actualEndpoint"
      }
    }
    Assert-JsonPath "agent context preflight catalog has actions" $agentContextAttrs.agentPreflight "actions"
    Assert-JsonPath "agent context preflight catalog has schema version" $agentContextAttrs.agentPreflight "catalogSchemaVersion"
    Assert-JsonPath "agent context preflight catalog has definition fields" $agentContextAttrs.agentPreflight "actionDefinitionFields"
    Assert-JsonPath "agent context preflight includes help request create" $agentContextAttrs.agentPreflight.actions "help_request.create"
    Assert-JsonPath "agent context preflight includes dispatch create" $agentContextAttrs.agentPreflight.actions "dispatch.create"
    Assert-JsonPath "agent context preflight includes match update" $agentContextAttrs.agentPreflight.actions "match.update"
    Assert-JsonPath "agent context preflight includes device signal create" $agentContextAttrs.agentPreflight.actions "device_signal.create"
    Assert-JsonPath "agent context dispatch create has target type" $agentContextAttrs.agentPreflight.actions."dispatch.create" "targetType"
    Assert-JsonPath "agent context dispatch create has proposed fields" $agentContextAttrs.agentPreflight.actions."dispatch.create" "proposedFields"
    Assert-JsonPath "agent context dispatch create has write schema ref" $agentContextAttrs.agentPreflight.actions."dispatch.create" "writeBodySchemaRef"
    Assert-JsonPath "agent context dispatch create has side effects" $agentContextAttrs.agentPreflight.actions."dispatch.create" "sideEffects"
    Assert-JsonPath "agent context dispatch create has example preflight body" $agentContextAttrs.agentPreflight.actions."dispatch.create" "examplePreflightBody"
    Assert-JsonPath "agent context match update has status enum" $agentContextAttrs.agentPreflight.actions."match.update" "allowedProposedStatus"
    if ($agentContextAttrs.agentPreflight.actions."dispatch.create".targetType -eq "help_request") {
      Pass "agent context dispatch create target type"
    } else {
      Fail "agent context dispatch create target type" "expected help_request"
    }
    if ($agentContextAttrs.agentPreflight.actions."dispatch.create".examplePreflightBody.data.attributes.action -eq "dispatch.create") {
      Pass "agent context dispatch create example body action"
    } else {
      Fail "agent context dispatch create example body action" "unexpected action"
    }
    $deviceSignalFields = @(As-Array $agentContextAttrs.agentPreflight.actions."device_signal.create".proposedFields)
    $expectedDeviceSignalFields = @("purpose", "coarseGeohash", "accuracyM", "bluetoothSeen", "shakeDetected", "gyroAvailable", "payload", "userConfirmed")
    $missingDeviceSignalFields = @($expectedDeviceSignalFields | Where-Object { $deviceSignalFields -notcontains $_ })
    if ($missingDeviceSignalFields.Count -eq 0 -and ($deviceSignalFields -notcontains "signalType") -and ($deviceSignalFields -notcontains "coarseLocation")) {
      Pass "agent context device signal recipe uses runtime field names"
    } else {
      Fail "agent context device signal recipe uses runtime field names" "missing=$($missingDeviceSignalFields -join ",") fields=$($deviceSignalFields -join ",")"
    }
    Assert-JsonPath "agent context profile has soulMdSet" $agentContextAttrs.agentProfile "soulMdSet"
    Assert-JsonPath "agent context profile has soulMdLength" $agentContextAttrs.agentProfile "soulMdLength"
    Assert-JsonPath "agent context readiness has physical help flag" $agentContextAttrs.agentReadiness "physicalHelpReady"
    Assert-JsonPath "agent context readiness has setup gaps" $agentContextAttrs.agentReadiness "setupGaps"
    Assert-JsonPath "agent context readiness has next setup actions" $agentContextAttrs.agentReadiness "nextSetupActions"
    Assert-JsonPath "agent context readiness has checks" $agentContextAttrs.agentReadiness "checks"
    Assert-JsonPath "agent context readiness checks include physical coordination" $agentContextAttrs.agentReadiness.checks "physicalHelpCoordination"
    Assert-JsonPath "agent context skill instructions include read-before-write" $agentContextAttrs.skillInstructions "readBeforeWrite"
    Assert-JsonPath "agent context skill instructions include label reuse" $agentContextAttrs.skillInstructions "labelReuse"
    Assert-JsonPath "agent context skill instructions include candidate routing" $agentContextAttrs.skillInstructions "candidateRouting"
    Assert-JsonPath "agent context skill instructions include error recovery" $agentContextAttrs.skillInstructions "errorRecovery"
    Assert-JsonPath "agent context skill instructions include write recipes" $agentContextAttrs.skillInstructions "writeRecipes"
    Assert-JsonPath "agent context skill instructions include task recipes" $agentContextAttrs.skillInstructions "taskRecipes"
    Assert-JsonPath "agent context skill instructions include confirmation template" $agentContextAttrs.skillInstructions "confirmationTemplate"
    Assert-JsonPath "agent context skill write recipes include help request" $agentContextAttrs.skillInstructions.writeRecipes "create_physical_help_request"
    if ($agentContextAttrs.schemaVersion -eq "0.7") {
      Pass "agent context schema version" $agentContextAttrs.schemaVersion
    } else {
      Fail "agent context schema version" "expected 0.7, got $($agentContextAttrs.schemaVersion)"
    }
    if ($agentContextAttrs.skillInstructions.schemaVersion -eq "0.5") {
      Pass "agent context skill instructions schema version" $agentContextAttrs.skillInstructions.schemaVersion
    } else {
      Fail "agent context skill instructions schema version" "expected 0.5, got $($agentContextAttrs.skillInstructions.schemaVersion)"
    }
    if ($agentContextAttrs.skillInstructions.taskRecipes.publicDocs -eq "/docs/agent-recipes.md" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.createHelpRequest.writeOperationId -eq "nexusHelpRequestCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.findCandidateHelpers.readOperationId -eq "nexusHelpCandidatesList" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.pollWorkQueue.readOperationId -eq "nexusMyWorkItemsList") {
      Pass "agent context skill task recipes expose core matrix"
    } else {
      Fail "agent context skill task recipes expose core matrix" "unexpected taskRecipes"
    }
    $agentContextTaskReplyReadFirst = @(As-Array $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.replyToForumDiscussion.readFirst | ForEach-Object { [string] $_.name })
    if ($agentContextAttrs.skillInstructions.taskRecipes.schemaVersion -eq "0.2" -and $agentContextAttrs.skillInstructions.taskRecipes.forumSource -eq "OpenApiTooling::forumToolMatrix" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.openForumDiscussion.readOperationId -eq "nexusForumDiscussionShow" -and ($agentContextTaskReplyReadFirst -contains "open_forum_discussion") -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.createForumDiscussion.writeOperationId -eq "nexusForumDiscussionCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.replyToForumDiscussion.writeOperationId -eq "nexusForumDiscussionPostCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.recoverMyForumPosts.readOperationId -eq "nexusMyForumPostsList" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.hideOwnForumPost.writeOperationId -eq "nexusForumPostDelete") {
      Pass "agent context skill task recipes expose forum matrix"
    } else {
      Fail "agent context skill task recipes expose forum matrix" "unexpected forumMatrix"
    }
    $agentContextTaskForumMatrixKeys = @($agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.PSObject.Properties | ForEach-Object { $_.Name })
    $missingAgentContextTaskForumMatrixKeys = @($forumMatrixKeysCamel | Where-Object { $agentContextTaskForumMatrixKeys -notcontains $_ })
    if ($missingAgentContextTaskForumMatrixKeys.Count -eq 0) {
      Pass "agent context skill task recipes forum matrix has all forum tasks"
    } else {
      Fail "agent context skill task recipes forum matrix has all forum tasks" "missing=$($missingAgentContextTaskForumMatrixKeys -join ",")"
    }
    $skillCandidateRouting = $agentContextAttrs.skillInstructions.candidateRouting
    if ($skillCandidateRouting.schemaVersion -eq "0.1" -and $skillCandidateRouting.endpoint -eq "/api/nexus/help-requests/{id}/candidates") {
      Pass "agent context candidateRouting schema and endpoint"
    } else {
      Fail "agent context candidateRouting schema and endpoint" "schema=$($skillCandidateRouting.schemaVersion) endpoint=$($skillCandidateRouting.endpoint)"
    }
    $skillCandidateRunbook = As-Array $skillCandidateRouting.runbook
    $skillCandidateSteps = @($skillCandidateRunbook | ForEach-Object { [string] $_.step })
    $requiredCandidateSteps = @("rank_candidates", "preflight_dispatch", "confirm_and_dispatch")
    $missingCandidateSteps = @($requiredCandidateSteps | Where-Object { $skillCandidateSteps -notcontains $_ })
    if ($missingCandidateSteps.Count -eq 0) {
      Pass "agent context candidateRouting has dispatch runbook steps"
    } else {
      Fail "agent context candidateRouting has dispatch runbook steps" "missing=$($missingCandidateSteps -join ",") steps=$($skillCandidateSteps -join ",")"
    }
    Assert-JsonPath "agent context candidateRouting responseFields include dispatch rationale" $skillCandidateRouting.responseFields "dispatchRationaleTemplate"
    $skillCandidateConfirmFields = @(As-Array $skillCandidateRouting.confirmationMustShow | ForEach-Object { [string] $_ })
    if ($skillCandidateConfirmFields -contains "sideEffects") {
      Pass "agent context candidateRouting confirmation shows sideEffects"
    } else {
      Fail "agent context candidateRouting confirmation shows sideEffects" "fields=$($skillCandidateConfirmFields -join ",")"
    }
    $skillCandidateFallbacks = As-Array $skillCandidateRouting.fallbackReads
    $hasWorkQueueFallback = @($skillCandidateFallbacks | Where-Object { [string] $_.name -eq "recover_work_queue" -or [string] $_.endpoint -eq "/api/nexus/me/work-items" }).Count -gt 0
    if ($hasWorkQueueFallback) {
      Pass "agent context candidateRouting has work queue fallback"
    } else {
      Fail "agent context candidateRouting has work queue fallback" "missing recover_work_queue fallback"
    }
    $skillLabelReuse = $agentContextAttrs.skillInstructions.labelReuse
    $skillLabelReuseRunbook = As-Array $skillLabelReuse.runbook
    $skillLabelSearch = @($skillLabelReuseRunbook | Where-Object { [string] $_.step -eq "search_label_directory" } | Select-Object -First 1)
    if ($skillLabelSearch.Count -eq 1 -and $skillLabelSearch[0].endpoint -eq "/api/nexus/capability-labels" -and $skillLabelSearch[0].query.inname -eq "<keyword>" -and $skillLabelSearch[0].query.sort -eq "popular" -and $skillLabelSearch[0].query."page[limit]" -eq 10 -and $skillLabelSearch[0].writesState -eq $false) {
      Pass "agent context labelReuse has executable label search"
    } else {
      Fail "agent context labelReuse has executable label search" "unexpected labelReuse runbook"
    }
    $skillLabelHelperSearch = @($skillLabelReuseRunbook | Where-Object { [string] $_.step -eq "inspect_helpers" } | Select-Object -First 1)
    if ($skillLabelHelperSearch.Count -eq 1 -and $skillLabelHelperSearch[0].endpoint -eq "/api/nexus/capabilities" -and $skillLabelHelperSearch[0].query."filter[label]" -eq "<attributes.label>" -and $skillLabelHelperSearch[0].writesState -eq $false) {
      Pass "agent context labelReuse has helper inspection"
    } else {
      Fail "agent context labelReuse has helper inspection" "unexpected helper search"
    }
    $skillReadBeforeWrite = As-Array $agentContextAttrs.skillInstructions.readBeforeWrite
    $skillLabelReadAction = @($skillReadBeforeWrite | Where-Object { [string] $_.name -eq "search_capability_labels_by_keyword" } | Select-Object -First 1)
    if ($skillLabelReadAction.Count -eq 1 -and $skillLabelReadAction[0].query.inname -eq "<keyword>" -and $skillLabelReadAction[0].query.sort -eq "popular" -and $skillLabelReadAction[0].writesState -eq $false) {
      Pass "agent context read-before-write has query-bearing label search"
    } else {
      Fail "agent context read-before-write has query-bearing label search" "unexpected readBeforeWrite label action"
    }
    $skillErrorRecovery = $agentContextAttrs.skillInstructions.errorRecovery
    if ($skillErrorRecovery.schemaVersion -eq "0.1" -and $skillErrorRecovery.httpStatusPolicy."422".retrySameBody -eq $false -and $skillErrorRecovery.blockingCheckPolicy.allowAgentMatching) {
      Pass "agent context errorRecovery has retry policy"
    } else {
      Fail "agent context errorRecovery has retry policy" "unexpected errorRecovery"
    }

    if ($agentContextRead.Content -match '"soulMd"\s*:') {
      Fail "agent context redacts raw soulMd field" "response contains raw soulMd key"
    } else {
      Pass "agent context redacts raw soulMd field"
    }
  } catch {
    Fail "agent context parses as JSON" $_.Exception.Message
  }
  $agentProfileRead = Assert-Status "agent profile authenticated" "GET" "/api/nexus/me/agent-profile" @(200) $authHeaders
  try {
    $agentProfile = $agentProfileRead.Content | ConvertFrom-Json
    $agentProfileAttrs = $agentProfile.data.attributes

    if ($agentProfile.data.type -eq "nexus-agent-profiles") {
      Pass "agent profile type"
    } else {
      Fail "agent profile type" "unexpected type: $($agentProfile.data.type)"
    }

    Assert-JsonPath "agent profile has permissions" $agentProfileAttrs "permissions"
    Assert-JsonPath "agent profile permissions has location visibility" $agentProfileAttrs.permissions "locationVisibility"
  } catch {
    Fail "agent profile parses as JSON" $_.Exception.Message
  }

  Assert-Status "my capabilities authenticated" "GET" "/api/nexus/me/capabilities" @(200) $authHeaders | Out-Null
  Assert-Status "my matches authenticated" "GET" "/api/nexus/me/matches?page%5Blimit%5D=5" @(200) $authHeaders | Out-Null
  Assert-Status "my matches rejects invalid role" "GET" "/api/nexus/me/matches?filter%5Brole%5D=bad" @(422) $authHeaders | Out-Null
  Assert-Status "my help requests authenticated" "GET" "/api/nexus/me/help-requests?page%5Blimit%5D=5&include=discussion" @(200) $authHeaders | Out-Null
  $workItemsResponse = Assert-Status "my work items authenticated" "GET" "/api/nexus/me/work-items?page%5Blimit%5D=5" @(200) $authHeaders
  Assert-Status "my work items rejects invalid role" "GET" "/api/nexus/me/work-items?filter%5Brole%5D=bad" @(422) $authHeaders | Out-Null
  Assert-Status "my work items rejects invalid kind" "GET" "/api/nexus/me/work-items?filter%5Bkind%5D=bad" @(422) $authHeaders | Out-Null
  Assert-Status "my forum discussions authenticated" "GET" "/api/nexus/me/discussions?page%5Blimit%5D=5" @(200) $authHeaders | Out-Null
  Assert-Status "my forum posts authenticated" "GET" "/api/nexus/me/posts?page%5Blimit%5D=5" @(200) $authHeaders | Out-Null
  Assert-Status "my device signals authenticated" "GET" "/api/nexus/me/device-signals?page%5Blimit%5D=5" @(200) $authHeaders | Out-Null
  try {
    $workItems = $workItemsResponse.Content | ConvertFrom-Json
    $workItemData = As-Array $workItems.data
    Pass "my work items parse" "count=$($workItemData.Count)"
  } catch {
    Fail "my work items parse" $_.Exception.Message
  }
  $needDraftResponse = Assert-Status "need draft authenticated" "POST" "/api/nexus/need-drafts" @(200) $authHeaders $needDraftBody

  try {
    $needDraft = $needDraftResponse.Content | ConvertFrom-Json
    $needDraftAttrs = $needDraft.data.attributes

    if ($needDraft.data.type -eq "nexus-need-drafts") {
      Pass "need draft type"
    } else {
      Fail "need draft type" "unexpected type: $($needDraft.data.type)"
    }

    if ($needDraftAttrs.intent -eq "help") {
      Pass "need draft intent" $needDraftAttrs.intent
    } else {
      Fail "need draft intent" "expected help, got $($needDraftAttrs.intent)"
    }

    if ($needDraftAttrs.publish.endpoint -eq "POST /api/nexus/help-requests") {
      Pass "need draft publish endpoint"
    } else {
      Fail "need draft publish endpoint" "unexpected endpoint: $($needDraftAttrs.publish.endpoint)"
    }

    if ($needDraftAttrs.publish.body.data.attributes.userConfirmed -eq $false) {
      Pass "need draft publish body is unconfirmed"
    } else {
      Fail "need draft publish body is unconfirmed" "expected false"
    }

    $needDraftLabels = As-Array $needDraftAttrs.neededLabels
    if ($needDraftLabels -contains "computer-repair") {
      Pass "need draft suggests computer-repair"
    } else {
      Fail "need draft suggests computer-repair" "labels=$($needDraftLabels -join ",")"
    }

    Assert-JsonPath "need draft has labelReuse" $needDraftAttrs "labelReuse"
    $labelReuse = $needDraftAttrs.labelReuse
    if ($labelReuse.readOnly -eq $true) {
      Pass "need draft labelReuse is read-only"
    } else {
      Fail "need draft labelReuse is read-only" "expected true"
    }
    $labelReuseProposed = As-Array $labelReuse.proposedLabels
    if ($labelReuseProposed -contains "computer-repair") {
      Pass "need draft labelReuse proposes computer-repair"
    } else {
      Fail "need draft labelReuse proposes computer-repair" "labels=$($labelReuseProposed -join ",")"
    }
    $labelReuseSearches = As-Array $labelReuse.searches
    $computerRepairReuseSearch = @($labelReuseSearches | Where-Object { [string] $_.label -eq "computer-repair" } | Select-Object -First 1)
    if ($computerRepairReuseSearch.Count -eq 1 -and $computerRepairReuseSearch[0].endpoint -eq "/api/nexus/capability-labels" -and $computerRepairReuseSearch[0].query.inname -eq "computer-repair" -and $computerRepairReuseSearch[0].query.sort -eq "popular" -and $computerRepairReuseSearch[0].query."page[limit]" -eq 10 -and $computerRepairReuseSearch[0].writesState -eq $false) {
      Pass "need draft labelReuse has executable label search"
    } else {
      Fail "need draft labelReuse has executable label search" "unexpected labelReuse search"
    }

    Assert-JsonPath "need draft has discoveryPlan" $needDraftAttrs "discoveryPlan"
    $discoveryPlan = $needDraftAttrs.discoveryPlan
    if ($discoveryPlan.readOnly -eq $true) {
      Pass "need draft discoveryPlan is read-only"
    } else {
      Fail "need draft discoveryPlan is read-only" "expected true"
    }

    $discoverySteps = As-Array $discoveryPlan.steps
    $discoveryEndpoints = @($discoverySteps | ForEach-Object { [string] $_.endpoint })
    if ($discoveryEndpoints -contains "/api/nexus/capability-labels") {
      Pass "need draft discoveryPlan includes capability labels"
    } else {
      Fail "need draft discoveryPlan includes capability labels" "endpoints=$($discoveryEndpoints -join ",")"
    }

    if ($discoveryEndpoints -contains "/api/nexus/forum/discussions") {
      Pass "need draft discoveryPlan includes forum discussions"
    } else {
      Fail "need draft discoveryPlan includes forum discussions" "endpoints=$($discoveryEndpoints -join ",")"
    }

    $reuseExistingLabelStep = @($discoverySteps | Where-Object { [string] $_.name -eq "reuse_existing_labels" } | Select-Object -First 1)
    if ($reuseExistingLabelStep.Count -eq 1 -and $reuseExistingLabelStep[0].method -eq "GET" -and $reuseExistingLabelStep[0].endpoint -eq "/api/nexus/capability-labels" -and $reuseExistingLabelStep[0].query.inname -and $reuseExistingLabelStep[0].query.sort -eq "popular" -and $reuseExistingLabelStep[0].query."page[limit]" -eq 10 -and $reuseExistingLabelStep[0].requiredBeforePublish -eq $true -and $reuseExistingLabelStep[0].writesState -eq $false) {
      Pass "need draft discoveryPlan has concrete label reuse step"
    } else {
      Fail "need draft discoveryPlan has concrete label reuse step" "unexpected reuse_existing_labels step"
    }

    $findHelpersStep = @($discoverySteps | Where-Object { [string] $_.name -eq "find_capable_helpers" } | Select-Object -First 1)
    if ($findHelpersStep.Count -eq 1 -and $findHelpersStep[0].endpoint -eq "/api/nexus/capabilities" -and $findHelpersStep[0].query."filter[label]" -eq "computer-repair") {
      Pass "need draft discoveryPlan feeds selected label into helper search"
    } else {
      Fail "need draft discoveryPlan feeds selected label into helper search" "unexpected find_capable_helpers step"
    }

    $nonReadOnlySteps = @($discoverySteps | Where-Object { [string] $_.method -ne "GET" -or $_.writesState -ne $false })
    if ($nonReadOnlySteps.Count -eq 0) {
      Pass "need draft discoveryPlan steps are GET-only"
    } else {
      Fail "need draft discoveryPlan steps are GET-only" "non-read-only count=$($nonReadOnlySteps.Count)"
    }
  } catch {
    Fail "need draft parses as JSON" $_.Exception.Message
  }

  $actionLogsBefore = Assert-Status "my action logs authenticated" "GET" "/api/nexus/me/action-logs?page%5Blimit%5D=5" @(200) $authHeaders

  try {
    $actionLogsBeforeJson = $actionLogsBefore.Content | ConvertFrom-Json
    $actionLogsBeforeCount = @(As-Array $actionLogsBeforeJson.data).Count
    Pass "action logs parse before writes" "count=$actionLogsBeforeCount"
  } catch {
    Fail "action logs parse before writes" $_.Exception.Message
    $actionLogsBeforeCount = $null
  }

  $llmRead = Assert-Status "LLM settings read" "GET" "/api/nexus/llm-settings" @(200) $authHeaders

  if ($llmRead.Content -match '"apiKey"\s*:') {
    Fail "LLM settings raw API key redaction" "response contains raw apiKey"
  } else {
    Pass "LLM settings raw API key redaction"
  }

  try {
    $llm = $llmRead.Content | ConvertFrom-Json
    $attrs = $llm.data.attributes
    Assert-JsonPath "LLM settings has provider" $attrs "provider"
    Assert-JsonPath "LLM settings has apiKeySet" $attrs "apiKeySet"
    Assert-JsonPath "LLM settings has apiKeyPreview" $attrs "apiKeyPreview"
  } catch {
    Fail "LLM settings parses as JSON" $_.Exception.Message
    $attrs = $null
  }

  $missingLlmConfirmation = @{
    data = @{
      type = "nexus-llm-settings"
      attributes = @{
        provider = "builtin"
      }
    }
  }
  Assert-Status "LLM settings requires confirmation" "PATCH" "/api/nexus/llm-settings" @(422) $authHeaders $missingLlmConfirmation | Out-Null

  $missingAgentProfileConfirmation = @{
    data = @{
      type = "nexus-agent-profiles"
      attributes = @{
        agentName = "Nexus smoke unconfirmed agent"
      }
    }
  }
  Assert-Status "agent profile requires confirmation" "PATCH" "/api/nexus/me/agent-profile" @(422) $authHeaders $missingAgentProfileConfirmation | Out-Null

  $missingCapabilityConfirmation = @{
    data = @{
      type = "nexus-user-capabilities"
      attributes = @{
        capabilities = @()
      }
    }
  }
  Assert-Status "capabilities require confirmation" "PATCH" "/api/nexus/me/capabilities" @(422) $authHeaders $missingCapabilityConfirmation | Out-Null

  $missingHelpConfirmation = @{
    data = @{
      type = "nexus-help-requests"
      attributes = @{
        title = "Nexus smoke unconfirmed request"
        summary = "This request should be rejected because userConfirmed is absent."
        content = "This request should be rejected because userConfirmed is absent."
      }
    }
  }
  Assert-Status "help request creation requires confirmation" "POST" "/api/nexus/help-requests" @(422) $authHeaders $missingHelpConfirmation | Out-Null

  $missingForumConfirmation = @{
    data = @{
      type = "discussions"
      attributes = @{
        title = "Nexus smoke unconfirmed forum post"
        content = "This discussion should be rejected because userConfirmed is absent."
        tags = @("team")
      }
    }
  }
  Assert-Status "forum gateway discussion requires confirmation" "POST" "/api/nexus/forum/discussions" @(422) $authHeaders $missingForumConfirmation | Out-Null

  $missingDeviceConfirmation = @{
    data = @{
      type = "nexus-device-signals"
      attributes = @{
        purpose = "presence"
      }
    }
  }
  Assert-Status "device signal requires confirmation" "POST" "/api/nexus/device-signals" @(422) $authHeaders $missingDeviceConfirmation | Out-Null

  if ($SkipWrites) {
    Skip "confirmed write checks" "disabled by -SkipWrites"
  } else {
    if ($agentProfileAttrs) {
      $restoreAgentProfile = @{
        data = @{
          type = "nexus-agent-profiles"
          attributes = @{
            userConfirmed = $true
            agentName = $agentProfileAttrs.agentName
            agentAvatarUrl = $agentProfileAttrs.agentAvatarUrl
            soulMd = $agentProfileAttrs.soulMd
            interestTags = @(As-Array $agentProfileAttrs.interestTags | ForEach-Object { [string] $_ })
            skillTags = @(As-Array $agentProfileAttrs.skillTags | ForEach-Object { [string] $_ })
            helpTags = @(As-Array $agentProfileAttrs.helpTags | ForEach-Object { [string] $_ })
            matchPreferences = $agentProfileAttrs.matchPreferences
            permissions = @{
              allowAgentPosting = [bool] $agentProfileAttrs.permissions.allowAgentPosting
              allowAgentReplying = [bool] $agentProfileAttrs.permissions.allowAgentReplying
              allowAgentMatching = [bool] $agentProfileAttrs.permissions.allowAgentMatching
              allowLocationMatching = [bool] $agentProfileAttrs.permissions.allowLocationMatching
              locationVisibility = [string] $agentProfileAttrs.permissions.locationVisibility
            }
          }
        }
      }

      $confirmedAgentProfile = @{
        data = @{
          type = "nexus-agent-profiles"
          attributes = @{
            userConfirmed = $true
            agentName = "Nexus Smoke Agent"
            soulMd = $smokeSoulMd
            interestTags = @("nexus-smoke", "campus-life")
            skillTags = @("computer-repair")
            helpTags = @("umbrella-help")
            matchPreferences = @{
              preferPublicMeetingPlaces = $true
              maxServiceRadiusM = 2000
              smoke = $true
            }
            permissions = @{
              allowAgentPosting = $false
              allowAgentReplying = $false
              allowAgentMatching = $true
              allowLocationMatching = $false
              locationVisibility = "off"
            }
          }
        }
      }

      $agentProfilePatch = Assert-Status "agent profile confirmed patch" "PATCH" "/api/nexus/me/agent-profile" @(200) $authHeaders $confirmedAgentProfile
      try {
        $agentProfilePatchJson = $agentProfilePatch.Content | ConvertFrom-Json
        $patchedAttrs = $agentProfilePatchJson.data.attributes

        if ($patchedAttrs.agentName -eq "Nexus Smoke Agent") {
          Pass "agent profile patch agentName"
        } else {
          Fail "agent profile patch agentName" "unexpected value: $($patchedAttrs.agentName)"
        }

        if ($patchedAttrs.soulMd -eq $smokeSoulMd) {
          Pass "agent profile patch soulMd"
        } else {
          Fail "agent profile patch soulMd" "soulMd did not round-trip"
        }

        $patchedSkillTags = As-Array $patchedAttrs.skillTags
        if ($patchedSkillTags -contains "computer-repair") {
          Pass "agent profile patch skillTags"
        } else {
          Fail "agent profile patch skillTags" "skillTags=$($patchedSkillTags -join ",")"
        }

        if ($patchedAttrs.permissions.allowAgentMatching -eq $true -and $patchedAttrs.permissions.locationVisibility -eq "off") {
          Pass "agent profile patch permissions"
        } else {
          Fail "agent profile patch permissions" "permissions did not round-trip"
        }
      } catch {
        Fail "agent profile patch parses as JSON" $_.Exception.Message
      }

      Assert-Status "agent profile restore after smoke patch" "PATCH" "/api/nexus/me/agent-profile" @(200) $authHeaders $restoreAgentProfile | Out-Null
    } else {
      Skip "agent profile confirmed patch" "read response did not parse"
    }

    if ($attrs) {
      $patchAttributes = @{
        userConfirmed = $true
        provider = [string] $attrs.provider
        baseUrl = [string] $attrs.baseUrl
        chatModel = [string] $attrs.chatModel
        responsesModel = [string] $attrs.responsesModel
        supportsChatCompletions = [bool] $attrs.supportsChatCompletions
        supportsResponses = [bool] $attrs.supportsResponses
      }

      $idempotentLlmPatch = @{
        data = @{
          type = "nexus-llm-settings"
          attributes = $patchAttributes
        }
      }

      $llmPatch = Assert-Status "LLM settings confirmed idempotent patch" "PATCH" "/api/nexus/llm-settings" @(200) $authHeaders $idempotentLlmPatch

      if ($llmPatch.Content -match '"apiKey"\s*:') {
        Fail "LLM patch raw API key redaction" "response contains raw apiKey"
      } else {
        Pass "LLM patch raw API key redaction"
      }
    } else {
      Skip "LLM settings confirmed idempotent patch" "read response did not parse"
    }

    $confirmedDeviceSignal = @{
      data = @{
        type = "nexus-device-signals"
        attributes = @{
          userConfirmed = $true
          purpose = "presence"
          bluetoothSeen = $false
          shakeDetected = $false
          gyroAvailable = $false
          payload = @{
            smoke = $true
            source = "scripts/nexus-smoke.ps1"
          }
        }
      }
    }

    $deviceSignalWrite = Assert-Status "device signal confirmed write" "POST" "/api/nexus/device-signals" @(201) $authHeaders $confirmedDeviceSignal
    $deviceSignalId = $null

    try {
      $deviceSignalJson = $deviceSignalWrite.Content | ConvertFrom-Json
      $deviceSignalId = [string] $deviceSignalJson.data.id

      if ($deviceSignalJson.data.type -eq "nexus-device-signals" -and $deviceSignalId) {
        Pass "device signal write response type" $deviceSignalId
      } else {
        Fail "device signal write response type" "unexpected response"
      }
    } catch {
      Fail "device signal write response parses" $_.Exception.Message
    }

    $myDeviceSignals = Assert-Status "my device signals include confirmed write" "GET" "/api/nexus/me/device-signals?filter%5Bpurpose%5D=presence&filter%5BincludeExpired%5D=true&page%5Blimit%5D=20" @(200) $authHeaders
    try {
      $myDeviceSignalsJson = $myDeviceSignals.Content | ConvertFrom-Json
      $signalIds = @(As-Array $myDeviceSignalsJson.data | ForEach-Object { [string] $_.id })

      if ($deviceSignalId -and ($signalIds -contains $deviceSignalId)) {
        Pass "my device signals readback" $deviceSignalId
      } else {
        Fail "my device signals readback" "created signal id not found. Saw: $($signalIds -join ",")"
      }
    } catch {
      Fail "my device signals readback parses" $_.Exception.Message
    }

    $actionLogsAfter = Assert-Status "action logs after confirmed writes" "GET" "/api/nexus/me/action-logs?page%5Blimit%5D=10" @(200) $authHeaders
    try {
      $actionLogsAfterJson = $actionLogsAfter.Content | ConvertFrom-Json
      $actionLogsAfterItems = As-Array $actionLogsAfterJson.data
      $actionTypes = @($actionLogsAfterItems | ForEach-Object { [string] $_.attributes.actionType })
      if (($actionTypes -contains "llm_settings.update") -or ($actionTypes -contains "device_signal.create") -or ($actionTypes -contains "agent_profile.update")) {
        Pass "action logs include confirmed write" ($actionTypes -join ",")
      } else {
        Fail "action logs include confirmed write" "missing expected action type. Saw: $($actionTypes -join ",")"
      }

      if ($actionLogsAfter.Content -match "sk-" -or $actionLogsAfter.Content -match '"apiKey"\s*:') {
        Fail "action logs redact secrets" "response appears to include raw key material"
      } elseif ($actionLogsAfter.Content.Contains($smokeSoulMd)) {
        Fail "action logs redact secrets" "response appears to include raw soulMd content"
      } else {
        Pass "action logs redact secrets"
      }
    } catch {
      Fail "action logs after confirmed writes parse" $_.Exception.Message
    }
  }
}

Write-Host ""
Write-Host "Smoke complete: failures=$Script:Failures skipped=$Script:Skips"

if ($Script:Failures -gt 0) {
  exit 1
}
