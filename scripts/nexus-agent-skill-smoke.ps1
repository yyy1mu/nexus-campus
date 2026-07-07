param(
  [string] $BaseUrl,
  [string] $ManifestUrl,
  [string] $EnvFile
)

$ErrorActionPreference = "Stop"

$Script:Failures = 0
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

function Resolve-AgentUrl {
  param(
    [string] $Base,
    [string] $Value
  )

  if ($Value -match "^https?://") {
    return $Value
  }

  return Join-Url $Base $Value
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

function Invoke-AgentHttp {
  param(
    [string] $Method,
    [string] $Url,
    [hashtable] $Headers = @{},
    $Body = $null
  )

  $params = @{
    Method = $Method
    Uri = $Url
    UseBasicParsing = $true
    TimeoutSec = 25
    Headers = $Headers
  }

  if ($null -ne $Body) {
    $json = $Body | ConvertTo-Json -Depth 32 -Compress
    $params["ContentType"] = "application/json; charset=utf-8"
    $params["Body"] = [System.Text.Encoding]::UTF8.GetBytes($json)
  }

  try {
    $response = Invoke-WebRequest @params
    return [pscustomobject] @{
      Status = [int] $response.StatusCode
      Content = Convert-ToUtf8Text $response.Content
      Headers = $response.Headers
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
      Headers = $webResponse.Headers
    }
  }
}

function Assert-StatusUrl {
  param(
    [string] $Name,
    [string] $Method,
    [string] $Url,
    [int[]] $Expected,
    [hashtable] $Headers = @{},
    $Body = $null
  )

  $response = Invoke-AgentHttp -Method $Method -Url $Url -Headers $Headers -Body $Body

  if ($Expected -contains $response.Status) {
    Pass $Name "$Method $Url -> $($response.Status)"
  } else {
    Fail $Name "$Method $Url returned $($response.Status), expected $($Expected -join ",")"
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

function Decode-Base64Utf8 {
  param([string] $Value)

  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
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

if (-not $ManifestUrl) {
  $ManifestUrl = Join-Url $BaseUrl "/.well-known/nexus-agent.json"
}

$authHeader = $envValues["NEXUS_AGENT_AUTH"]

Write-Host "Nexus agent skill smoke manifest: $ManifestUrl"
Write-Host "Repo root: $repoRoot"
Write-Host ""

$rootLlms = Assert-StatusUrl "agent probes root llms.txt" "GET" (Join-Url $BaseUrl "/llms.txt") @(200)
Assert-Contains "root llms points to manifest" $rootLlms.Content "/.well-known/nexus-agent.json"
Assert-Contains "root llms points to OpenAPI" $rootLlms.Content "/docs/openapi.json"
Assert-Contains "root llms points to agent tools" $rootLlms.Content "/docs/agent-tools.json"
Assert-Contains "root llms points to quickstart" $rootLlms.Content "/docs/agent-quickstart.md"
Assert-Contains "root llms points to full llms" $rootLlms.Content "/docs/llms.txt"
Assert-Contains "root llms points to agent recipes" $rootLlms.Content "/docs/agent-recipes.md"
Assert-Contains "root llms points to agent health" $rootLlms.Content "/api/nexus/agent-health"
Assert-Contains "root llms explains optional LLM for local agents" $rootLlms.Content "LLM provider settings are optional for local agents"
Assert-Contains "root llms explains skill candidate routing runbook" $rootLlms.Content "skillInstructions.candidateRouting"
Assert-Contains "root llms explains candidate dispatch template" $rootLlms.Content "create_dispatch.bodyTemplate"
Assert-Contains "root llms explains helper target verification" $rootLlms.Content "target.helperUserId"
Assert-Contains "root llms explains runtime OpenAPI tooling" $rootLlms.Content "openApiTooling.coreOperationIds"
Assert-Contains "root llms explains runtime agent tool contract" $rootLlms.Content "openApiTooling.agentToolContract"
Assert-Contains "root llms explains runtime core tool matrix" $rootLlms.Content "openApiTooling.coreToolMatrix"
Assert-Contains "root llms explains runtime forum tool matrix" $rootLlms.Content "openApiTooling.forumToolMatrix"
Assert-Contains "root llms explains forum open operationId" $rootLlms.Content "nexusForumDiscussionShow"
Assert-Contains "root llms explains forum open endpoint" $rootLlms.Content "/api/nexus/forum/discussions/{id}"
Assert-Contains "root llms explains OpenAPI agent tools" $rootLlms.Content "x-nexus-agent-skill.agent_tools"
Assert-Contains "root llms explains OpenAPI core tool matrix" $rootLlms.Content "x-nexus-agent-skill.core_tool_matrix"
Assert-Contains "root llms explains OpenAPI forum tool matrix" $rootLlms.Content "x-nexus-agent-skill.forum_tool_matrix"
Assert-Contains "root llms explains manifest core tool matrix" $rootLlms.Content "api.openapi_tooling.core_tool_matrix"
Assert-Contains "root llms explains manifest agent tool contract" $rootLlms.Content "api.openapi_tooling.agent_tool_contract"
Assert-Contains "root llms explains manifest forum tool matrix" $rootLlms.Content "api.openapi_tooling.forum_tool_matrix"
Assert-Contains "root llms explains endpoint map schema" $rootLlms.Content "AgentEndpointMap"

$manifestResponse = Assert-StatusUrl "agent discovers manifest" "GET" $ManifestUrl @(200)

try {
  $manifest = $manifestResponse.Content | ConvertFrom-Json
  Pass "manifest parses as JSON"
  Assert-JsonPath "manifest has schema" $manifest "schema"
  Assert-JsonPath "manifest has docs" $manifest "docs"
  Assert-JsonPath "manifest has api" $manifest "api"
  Assert-JsonPath "manifest docs has root agent entry" $manifest.docs "root_agent_entry"
  Assert-JsonPath "manifest docs has agent tools" $manifest.docs "agent_tools"
  Assert-JsonPath "manifest docs has quickstart" $manifest.docs "agent_quickstart"
  Assert-JsonPath "manifest docs has skill" $manifest.docs "nexus_skill"
  Assert-JsonPath "manifest docs has agent recipes" $manifest.docs "agent_recipes"
  if ([string] $manifest.docs.root_agent_entry -eq "/llms.txt" -and [string] $manifest.docs.agent_tools -eq "/docs/agent-tools.json" -and [string] $manifest.docs.agent_recipes -eq "/docs/agent-recipes.md") {
    Pass "manifest docs are same-origin"
  } else {
    Fail "manifest docs are same-origin" "root_agent_entry=$($manifest.docs.root_agent_entry) agent_tools=$($manifest.docs.agent_tools) agent_recipes=$($manifest.docs.agent_recipes)"
  }
  Assert-JsonPath "manifest has endpoint map" $manifest "nexus_endpoints"
  Assert-JsonPath "manifest endpoint map has agent health" $manifest.nexus_endpoints "agent_health"
  Assert-JsonPath "manifest endpoint map has agent context" $manifest.nexus_endpoints "my_agent_context"
  Assert-JsonPath "manifest endpoint map has preflight" $manifest.nexus_endpoints "agent_preflight"
  Assert-JsonPath "manifest endpoint map has work items" $manifest.nexus_endpoints "my_work_items"
  Assert-JsonPath "manifest api has structured OpenAPI tooling" $manifest.api "openapi_tooling"
  Assert-JsonPath "manifest OpenAPI tooling has agent tool contract" $manifest.api.openapi_tooling "agent_tool_contract"
  Assert-JsonPath "manifest OpenAPI tooling has core operationIds" $manifest.api.openapi_tooling "core_operation_ids"
  Assert-JsonPath "manifest OpenAPI tooling has core tool matrix" $manifest.api.openapi_tooling "core_tool_matrix"
  if ([string] $manifest.api.openapi_tooling.agent_tool_contract -eq "/docs/agent-tools.json") {
    Pass "manifest OpenAPI tooling links agent tool contract"
  } else {
    Fail "manifest OpenAPI tooling links agent tool contract" "agent_tool_contract=$($manifest.api.openapi_tooling.agent_tool_contract)"
  }
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
  if ($manifest.capabilities.agent_task_recipes -eq $true -and $manifest.capabilities.agent_tools_contract -eq $true -and $manifest.capabilities.openapi_core_tool_matrix -eq $true -and $manifest.capabilities.openapi_forum_tool_matrix -eq $true -and $manifest.capabilities.forum_gateway_tool_matrix -eq $true) {
    Pass "manifest exposes task recipe capabilities"
  } else {
    Fail "manifest exposes task recipe capabilities" "agent_task_recipes=$($manifest.capabilities.agent_task_recipes) agent_tools_contract=$($manifest.capabilities.agent_tools_contract) openapi_core_tool_matrix=$($manifest.capabilities.openapi_core_tool_matrix) openapi_forum_tool_matrix=$($manifest.capabilities.openapi_forum_tool_matrix) forum_gateway_tool_matrix=$($manifest.capabilities.forum_gateway_tool_matrix)"
  }
  $manifestWorkflow = [string] ($manifest.workflow -join "`n")
  if ($manifestWorkflow.Contains("/docs/agent-tools.json") -and $manifestWorkflow.Contains("/docs/agent-recipes.md") -and $manifestWorkflow.Contains("openApiTooling.coreToolMatrix") -and $manifestWorkflow.Contains("api.openapi_tooling.core_tool_matrix")) {
    Pass "manifest workflow mentions core task recipe sources"
  } else {
    Fail "manifest workflow mentions core task recipe sources" "missing /docs/agent-tools.json//docs/agent-recipes.md/openApiTooling.coreToolMatrix/api.openapi_tooling.core_tool_matrix"
  }
  if ($manifestWorkflow.Contains("openApiTooling.forumToolMatrix") -and $manifestWorkflow.Contains("api.openapi_tooling.forum_tool_matrix") -and $manifestWorkflow.Contains("x-nexus-agent-skill.forum_tool_matrix")) {
    Pass "manifest workflow mentions forum task recipe sources"
  } else {
    Fail "manifest workflow mentions forum task recipe sources" "missing openApiTooling.forumToolMatrix/api.openapi_tooling.forum_tool_matrix/x-nexus-agent-skill.forum_tool_matrix"
  }
  $manifestToolingRuntimeSources = [string] (@(As-Array $manifest.api.openapi_tooling.runtime_sources) -join "`n")
  if ($manifestToolingRuntimeSources.Contains("GET /api/nexus/agent-health") -and $manifestToolingRuntimeSources.Contains("GET /api/nexus/me/agent-context")) {
    Pass "manifest links runtime OpenAPI tooling sources"
  } else {
    Fail "manifest links runtime OpenAPI tooling sources" "runtime_sources=$manifestToolingRuntimeSources"
  }
  if ([string] $manifest.schema -eq "/schemas/nexus-agent-manifest.v1.json") {
    Pass "manifest schema is same-origin"
  } else {
    Fail "manifest schema is same-origin" "schema=$($manifest.schema)"
  }
  if ([string] $manifest.base_url -and [string] $manifest.base_url -ne "/") {
    $BaseUrl = Resolve-AgentUrl $BaseUrl ([string] $manifest.base_url)
  }
} catch {
  Fail "manifest parses as JSON" $_.Exception.Message
  $manifest = $null
}

if ($manifest) {
  $manifestSchema = Assert-StatusUrl "agent reads manifest schema" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.schema)) @(200)
  try {
    $manifestSchemaJson = $manifestSchema.Content | ConvertFrom-Json
    Assert-JsonPath "manifest schema has properties" $manifestSchemaJson "properties"
    Assert-JsonPath "manifest schema describes endpoint map" $manifestSchemaJson.properties "nexus_endpoints"
    Assert-JsonPath "manifest schema describes OpenAPI tooling" $manifestSchemaJson.properties.api.properties "openapi_tooling"
    Assert-JsonPath "manifest schema describes docs agent tools" $manifestSchemaJson.properties.docs.properties "agent_tools"
    Assert-JsonPath "manifest schema describes docs agent recipes" $manifestSchemaJson.properties.docs.properties "agent_recipes"
    Assert-JsonPath "manifest schema describes OpenAPI agent tool contract" $manifestSchemaJson.properties.api.properties.openapi_tooling.properties "agent_tool_contract"
    Assert-JsonPath "manifest schema describes OpenAPI core tool matrix" $manifestSchemaJson.properties.api.properties.openapi_tooling.properties "core_tool_matrix"
    Assert-JsonPath "manifest schema describes OpenAPI forum operationIds" $manifestSchemaJson.properties.api.properties.openapi_tooling.properties "forum_operation_ids"
    Assert-JsonPath "manifest schema describes OpenAPI forum tool matrix" $manifestSchemaJson.properties.api.properties.openapi_tooling.properties "forum_tool_matrix"
    $manifestDocsRequired = @(As-Array $manifestSchemaJson.properties.docs.required | ForEach-Object { [string] $_ })
    if ($manifestDocsRequired -contains "root_agent_entry") {
      Pass "manifest schema requires root agent entry"
    } else {
      Fail "manifest schema requires root agent entry" "required=$($manifestDocsRequired -join ",")"
    }
  } catch {
    Fail "manifest schema parses as JSON" $_.Exception.Message
  }

  $agentToolsResponse = Assert-StatusUrl "agent reads agent tools" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.agent_tools)) @(200)
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
    $dispatchMustVerify = @(As-Array $dispatchTool.preflight.mustVerify | ForEach-Object { [string] $_ }) -contains "preflight response data.attributes.target.helperUserId equals selected candidate data.attributes.helperUserId"
    if ($dispatchTool.write.operationId -eq "nexusHelpDispatchCreate" -and $dispatchTool.preflight.operationId -eq "nexusAgentPreflightCreate" -and $dispatchTool.write.bodySource -like "*create_dispatch*bodyTemplate*" -and $dispatchMustVerify) {
      Pass "agent tools dispatch task is executable without guessing"
    } else {
      Fail "agent tools dispatch task is executable without guessing" "write=$($dispatchTool.write.operationId) preflight=$($dispatchTool.preflight.operationId) bodySource=$($dispatchTool.write.bodySource) mustVerify=$dispatchMustVerify"
    }
    $forumOpenTool = $agentTools.forumTasks.open_forum_discussion
    if ($forumOpenTool.read.operationId -eq "nexusForumDiscussionShow" -and $forumOpenTool.read.endpoint -like "*include=user,tags,posts,posts.user*") {
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
  }

  $agentHealthPath = ([string] $manifest.nexus_endpoints.agent_health -replace "^GET\s+", "")
  $agentHealth = Assert-StatusUrl "agent public health check" "GET" (Join-Url $BaseUrl $agentHealthPath) @(200)
  try {
    $agentHealthJson = $agentHealth.Content | ConvertFrom-Json
    $agentHealthAttrs = $agentHealthJson.data.attributes
    if ($agentHealthJson.data.type -eq "nexus-agent-health" -and $agentHealthAttrs.status -eq "ok") {
      Pass "agent health reports ok"
    } else {
      Fail "agent health reports ok" "type=$($agentHealthJson.data.type) status=$($agentHealthAttrs.status)"
    }
    Assert-JsonPath "agent health has docs" $agentHealthAttrs "docs"
    Assert-JsonPath "agent health docs has root agent entry" $agentHealthAttrs.docs "rootAgentEntry"
    Assert-JsonPath "agent health docs has agent tools" $agentHealthAttrs.docs "agentTools"
    Assert-JsonPath "agent health docs has agent recipes" $agentHealthAttrs.docs "agentRecipes"
    Assert-JsonPath "agent health has OpenAPI tooling" $agentHealthAttrs "openApiTooling"
    Assert-JsonPath "agent health has endpoints" $agentHealthAttrs "endpoints"
    Assert-JsonPath "agent health has nextActions" $agentHealthAttrs "nextActions"
    Assert-JsonPath "agent health tooling has agent tool contract" $agentHealthAttrs.openApiTooling "agentToolContract"
    Assert-JsonPath "agent health tooling has core operationIds" $agentHealthAttrs.openApiTooling "coreOperationIds"
    Assert-JsonPath "agent health tooling has core tool matrix" $agentHealthAttrs.openApiTooling "coreToolMatrix"
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
    Assert-JsonPath "agent health tooling has forum operationIds" $agentHealthAttrs.openApiTooling "forumOperationIds"
    Assert-JsonPath "agent health tooling has forum tool matrix" $agentHealthAttrs.openApiTooling "forumToolMatrix"
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
    if ($agentHealthAttrs.openApiTooling.forumToolMatrix.searchForumDiscussions.readOperationId -eq "nexusForumDiscussionsList" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.openForumDiscussion.readOperationId -eq "nexusForumDiscussionShow" -and ($agentHealthReplyReadFirst -contains "open_forum_discussion") -and $agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.writeOperationId -eq "nexusForumDiscussionCreate" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.writeOperationId -eq "nexusForumDiscussionPostCreate" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.recoverMyForumPosts.readOperationId -eq "nexusMyForumPostsList" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.hideOwnForumPost.writeOperationId -eq "nexusForumPostDelete") {
      Pass "agent health exposes runtime forum tool matrix"
    } else {
      Fail "agent health exposes runtime forum tool matrix" "unexpected forumToolMatrix"
    }
    if ($agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.responseSchemaRef -eq "#/components/schemas/FlarumDiscussionDocument" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument" -and $agentHealthAttrs.openApiTooling.forumToolMatrix.editOwnForumPost.responseSchemaRef -eq "#/components/schemas/FlarumPostDocument") {
      Pass "agent health forum write tasks use concrete response schemas"
    } else {
      Fail "agent health forum write tasks use concrete response schemas" "create=$($agentHealthAttrs.openApiTooling.forumToolMatrix.createForumDiscussion.responseSchemaRef) reply=$($agentHealthAttrs.openApiTooling.forumToolMatrix.replyToForumDiscussion.responseSchemaRef) edit=$($agentHealthAttrs.openApiTooling.forumToolMatrix.editOwnForumPost.responseSchemaRef)"
    }
    if ([string] $agentHealthAttrs.docs.rootAgentEntry -eq (Join-Url $BaseUrl "/llms.txt") -and [string] $agentHealthAttrs.docs.agentTools -eq (Join-Url $BaseUrl "/docs/agent-tools.json") -and [string] $agentHealthAttrs.docs.agentRecipes -eq (Join-Url $BaseUrl "/docs/agent-recipes.md") -and [string] $agentHealthAttrs.docs.openapi -eq (Join-Url $BaseUrl "/docs/openapi.json") -and [string] $agentHealthAttrs.docs.manifest -eq (Join-Url $BaseUrl "/.well-known/nexus-agent.json")) {
      Pass "agent health docs use discovered origin"
    } else {
      Fail "agent health docs use discovered origin" "root=$($agentHealthAttrs.docs.rootAgentEntry) tools=$($agentHealthAttrs.docs.agentTools) recipes=$($agentHealthAttrs.docs.agentRecipes) openapi=$($agentHealthAttrs.docs.openapi) manifest=$($agentHealthAttrs.docs.manifest)"
    }
    if ([string] $agentHealthAttrs.openApiTooling.agentToolContract -eq "/docs/agent-tools.json") {
      Pass "agent health tooling exposes agent tool contract"
    } else {
      Fail "agent health tooling exposes agent tool contract" "agentToolContract=$($agentHealthAttrs.openApiTooling.agentToolContract)"
    }
    if ($agentHealthAttrs.capabilities.llmProviderOptionalForLocalAgents -eq $true) {
      Pass "agent health says LLM optional for local agents"
    } else {
      Fail "agent health says LLM optional for local agents" "llmProviderOptionalForLocalAgents=$($agentHealthAttrs.capabilities.llmProviderOptionalForLocalAgents)"
    }
    if ($agentHealthAttrs.notes.doesNotReturnPrivateState -eq $true -and $agentHealthAttrs.notes.doesNotReplaceAgentContext -eq $true) {
      Pass "agent health does not replace agent context"
    } else {
      Fail "agent health does not replace agent context" "unexpected notes"
    }
  } catch {
    Fail "agent health parses as JSON" $_.Exception.Message
  }

  $quickstart = Assert-StatusUrl "agent reads quickstart" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.agent_quickstart)) @(200)
  Assert-Contains "quickstart explains discover" $quickstart.Content "## 1. Discover"
  Assert-Contains "quickstart explains root llms" $quickstart.Content "/llms.txt"
  Assert-Contains "quickstart explains agent tools" $quickstart.Content "/docs/agent-tools.json"
  Assert-Contains "quickstart explains agent health" $quickstart.Content "/api/nexus/agent-health"
  Assert-Contains "quickstart explains bootstrap" $quickstart.Content "/api/nexus/me/agent-context"
  Assert-Contains "quickstart explains preflight" $quickstart.Content "/api/nexus/agent-preflight"
  Assert-Contains "quickstart explains work queue" $quickstart.Content "/api/nexus/me/work-items"
  Assert-Contains "quickstart explains discoveryPlan" $quickstart.Content "discoveryPlan"
  Assert-Contains "quickstart explains labelReuse" $quickstart.Content "labelReuse"
  Assert-Contains "quickstart explains label search" $quickstart.Content "/api/nexus/capability-labels?inname=repair"
  Assert-Contains "quickstart explains skillInstructions" $quickstart.Content "skillInstructions"
  Assert-Contains "quickstart explains skill label reuse runbook" $quickstart.Content "skillInstructions.labelReuse"
  Assert-Contains "quickstart explains skill candidate routing runbook" $quickstart.Content "skillInstructions.candidateRouting"
  Assert-Contains "quickstart explains candidate dispatch template" $quickstart.Content "create_dispatch.bodyTemplate"
  Assert-Contains "quickstart explains helper target verification" $quickstart.Content "target.helperUserId"
  Assert-Contains "quickstart explains skill error recovery runbook" $quickstart.Content "skillInstructions.errorRecovery"
  Assert-Contains "quickstart explains preflight recovery" $quickstart.Content "attributes.recovery"
  Assert-Contains "quickstart explains nextAction catalogAction" $quickstart.Content "catalogAction"
  Assert-Contains "quickstart explains side effects" $quickstart.Content "sideEffects"
  Assert-Contains "quickstart explains optional LLM for local agents" $quickstart.Content "LLM provider settings are optional"
  Assert-Contains "quickstart explains OpenAPI operationId" $quickstart.Content "operationId"
  Assert-Contains "quickstart explains core operationId" $quickstart.Content "nexusAgentPreflightCreate"
  Assert-Contains "quickstart explains runtime OpenAPI tooling" $quickstart.Content "openApiTooling.coreOperationIds"
  Assert-Contains "quickstart explains runtime agent tool contract" $quickstart.Content "openApiTooling.agentToolContract"
  Assert-Contains "quickstart explains agent recipes" $quickstart.Content "/docs/agent-recipes.md"
  Assert-Contains "quickstart explains runtime core tool matrix" $quickstart.Content "openApiTooling.coreToolMatrix"
  Assert-Contains "quickstart explains runtime forum tool matrix" $quickstart.Content "openApiTooling.forumToolMatrix"
  Assert-Contains "quickstart explains task recipes" $quickstart.Content "skillInstructions.taskRecipes"
  Assert-Contains "quickstart explains forum task recipes" $quickstart.Content "skillInstructions.taskRecipes.forumMatrix"
  Assert-Contains "quickstart explains OpenAPI root agent entry" $quickstart.Content "x-nexus-agent-skill.root_agent_entry"
  Assert-Contains "quickstart explains OpenAPI agent tools" $quickstart.Content "x-nexus-agent-skill.agent_tools"
  Assert-Contains "quickstart explains OpenAPI Nexus skill extension" $quickstart.Content "x-nexus-agent-skill.core_operation_ids"
  Assert-Contains "quickstart explains OpenAPI core tool matrix" $quickstart.Content "x-nexus-agent-skill.core_tool_matrix"
  Assert-Contains "quickstart explains OpenAPI forum tool matrix" $quickstart.Content "x-nexus-agent-skill.forum_tool_matrix"
  Assert-Contains "quickstart explains manifest root agent entry" $quickstart.Content "docs.root_agent_entry"
  Assert-Contains "quickstart explains manifest agent tools" $quickstart.Content "docs.agent_tools"
  Assert-Contains "quickstart explains manifest agent tool contract" $quickstart.Content "api.openapi_tooling.agent_tool_contract"
  Assert-Contains "quickstart explains manifest OpenAPI tooling" $quickstart.Content "api.openapi_tooling.core_operation_ids"
  Assert-Contains "quickstart explains manifest core tool matrix" $quickstart.Content "api.openapi_tooling.core_tool_matrix"
  Assert-Contains "quickstart explains manifest forum tool matrix" $quickstart.Content "api.openapi_tooling.forum_tool_matrix"

  $llms = Assert-StatusUrl "agent reads llms.txt" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.agent_entry)) @(200)
  Assert-Contains "llms points to root llms" $llms.Content "/llms.txt"
  Assert-Contains "llms points to agent tools" $llms.Content "/docs/agent-tools.json"
  Assert-Contains "llms points to agent health" $llms.Content "/api/nexus/agent-health"
  Assert-Contains "llms points to quickstart" $llms.Content "/docs/agent-quickstart.md"
  Assert-Contains "llms points to skill" $llms.Content "/docs/nexus-skill.md"
  Assert-Contains "llms points to agent recipes" $llms.Content "/docs/agent-recipes.md"
  Assert-Contains "llms explains discoveryPlan" $llms.Content "discoveryPlan"
  Assert-Contains "llms explains labelReuse" $llms.Content "labelReuse"
  Assert-Contains "llms explains label search" $llms.Content "/api/nexus/capability-labels?inname=<keyword>"
  Assert-Contains "llms explains skillInstructions" $llms.Content "skillInstructions"
  Assert-Contains "llms explains task recipes" $llms.Content "skillInstructions.taskRecipes"
  Assert-Contains "llms explains skill label reuse runbook" $llms.Content "skillInstructions.labelReuse"
  Assert-Contains "llms explains skill candidate routing runbook" $llms.Content "skillInstructions.candidateRouting"
  Assert-Contains "llms explains candidate dispatch template" $llms.Content "create_dispatch.bodyTemplate"
  Assert-Contains "llms explains helper target verification" $llms.Content "target.helperUserId"
  Assert-Contains "llms explains skill error recovery runbook" $llms.Content "skillInstructions.errorRecovery"
  Assert-Contains "llms explains preflight recovery" $llms.Content "attributes.recovery"
  Assert-Contains "llms explains self-describing nextActions" $llms.Content "self-describing recovery recipes"
  Assert-Contains "llms explains optional LLM for local agents" $llms.Content "LLM provider settings are optional for local agents"
  Assert-Contains "llms explains OpenAPI operationIds" $llms.Content "OpenAPI operationIds"
  Assert-Contains "llms explains core operationId" $llms.Content "nexusAgentPreflightCreate"
  Assert-Contains "llms explains forum operationId" $llms.Content "nexusForumDiscussionCreate"
  Assert-Contains "llms explains forum open operationId" $llms.Content "nexusForumDiscussionShow"
  Assert-Contains "llms explains forum open endpoint" $llms.Content "/api/nexus/forum/discussions/{id}"
  Assert-Contains "llms explains runtime OpenAPI tooling" $llms.Content "openApiTooling.coreOperationIds"
  Assert-Contains "llms explains runtime agent tool contract" $llms.Content "openApiTooling.agentToolContract"
  Assert-Contains "llms explains runtime core tool matrix" $llms.Content "openApiTooling.coreToolMatrix"
  Assert-Contains "llms explains runtime forum tool matrix" $llms.Content "openApiTooling.forumToolMatrix"
  Assert-Contains "llms explains OpenAPI root agent entry" $llms.Content "x-nexus-agent-skill.root_agent_entry"
  Assert-Contains "llms explains OpenAPI agent tools" $llms.Content "x-nexus-agent-skill.agent_tools"
  Assert-Contains "llms explains OpenAPI Nexus skill extension" $llms.Content "x-nexus-agent-skill.core_operation_ids"
  Assert-Contains "llms explains OpenAPI core tool matrix" $llms.Content "x-nexus-agent-skill.core_tool_matrix"
  Assert-Contains "llms explains OpenAPI forum tool matrix" $llms.Content "x-nexus-agent-skill.forum_tool_matrix"
  Assert-Contains "llms explains manifest root agent entry" $llms.Content "docs.root_agent_entry"
  Assert-Contains "llms explains manifest agent tools" $llms.Content "docs.agent_tools"
  Assert-Contains "llms explains manifest agent tool contract" $llms.Content "api.openapi_tooling.agent_tool_contract"
  Assert-Contains "llms explains manifest OpenAPI tooling" $llms.Content "api.openapi_tooling.core_operation_ids"
  Assert-Contains "llms explains manifest core tool matrix" $llms.Content "api.openapi_tooling.core_tool_matrix"
  Assert-Contains "llms explains manifest forum tool matrix" $llms.Content "api.openapi_tooling.forum_tool_matrix"

  $agentRecipes = Assert-StatusUrl "agent reads recipes" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.agent_recipes)) @(200)
  Assert-Contains "agent recipes includes agent tools" $agentRecipes.Content "/docs/agent-tools.json"
  Assert-Contains "agent recipes includes core tool matrix" $agentRecipes.Content "Core Tool Matrix"
  Assert-Contains "agent recipes includes forum tool matrix" $agentRecipes.Content "Forum Gateway Tool Matrix"
  Assert-Contains "agent recipes includes forum operationId" $agentRecipes.Content "nexusForumDiscussionCreate"
  Assert-Contains "agent recipes includes forum open operationId" $agentRecipes.Content "nexusForumDiscussionShow"
  Assert-Contains "agent recipes includes forum open endpoint" $agentRecipes.Content "/api/nexus/forum/discussions/{id}"
  Assert-Contains "agent recipes includes candidate dispatch template" $agentRecipes.Content "create_dispatch.bodyTemplate"
  Assert-Contains "agent recipes includes helper target verification" $agentRecipes.Content "target.helperUserId"
  Assert-Contains "agent recipes includes forum recovery read" $agentRecipes.Content "nexusMyForumPostsList"
  Assert-Contains "agent recipes includes forum post hide" $agentRecipes.Content "nexusForumPostDelete"

  $skill = Assert-StatusUrl "agent reads Nexus skill" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.nexus_skill)) @(200)
  Assert-Contains "Nexus skill includes agent tools" $skill.Content "/docs/agent-tools.json"
  Assert-Contains "Nexus skill includes forum matrix schema" $skill.Content "AgentForumToolMatrix"
  Assert-Contains "Nexus skill includes forum operationId" $skill.Content "nexusForumDiscussionCreate"
  Assert-Contains "Nexus skill includes forum open operationId" $skill.Content "nexusForumDiscussionShow"
  Assert-Contains "Nexus skill includes forum open endpoint" $skill.Content "/api/nexus/forum/discussions/{id}"
  Assert-Contains "Nexus skill includes candidate dispatch template" $skill.Content "create_dispatch.bodyTemplate"
  Assert-Contains "Nexus skill includes helper target verification" $skill.Content "target.helperUserId"
  Assert-Contains "Nexus skill includes runtime agent tool contract" $skill.Content "openApiTooling.agentToolContract"
  Assert-Contains "Nexus skill includes runtime forum tool matrix" $skill.Content "openApiTooling.forumToolMatrix"
  Assert-Contains "Nexus skill includes skill forum task recipes" $skill.Content "skillInstructions.taskRecipes.forumMatrix"
  Assert-Contains "Nexus skill includes OpenAPI agent tools" $skill.Content "x-nexus-agent-skill.agent_tools"
  Assert-Contains "Nexus skill includes OpenAPI forum tool matrix" $skill.Content "x-nexus-agent-skill.forum_tool_matrix"
  Assert-Contains "Nexus skill includes manifest agent tools" $skill.Content "docs.agent_tools"
  Assert-Contains "Nexus skill includes manifest agent tool contract" $skill.Content "api.openapi_tooling.agent_tool_contract"
  Assert-Contains "Nexus skill includes manifest forum tool matrix" $skill.Content "api.openapi_tooling.forum_tool_matrix"

  $openApi = Assert-StatusUrl "agent reads OpenAPI" "GET" (Resolve-AgentUrl $BaseUrl ([string] $manifest.docs.openapi)) @(200)
  try {
    $openApiJson = $openApi.Content | ConvertFrom-Json
    Pass "OpenAPI parses as JSON" $openApiJson.info.version
    Assert-JsonPath "OpenAPI includes agent health path" $openApiJson.paths "/api/nexus/agent-health"
    Assert-JsonPath "OpenAPI includes agent context path" $openApiJson.paths "/api/nexus/me/agent-context"
    Assert-JsonPath "OpenAPI includes preflight path" $openApiJson.paths "/api/nexus/agent-preflight"
    Assert-JsonPath "OpenAPI includes work items path" $openApiJson.paths "/api/nexus/me/work-items"
    $openApiOperations = @()
    foreach ($pathProperty in $openApiJson.paths.PSObject.Properties) {
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
    $openApiOperationIds = @($openApiOperations | ForEach-Object { $_.OperationId })
    foreach ($requiredOperationId in @("nexusAgentHealthShow", "nexusMyAgentContextShow", "nexusAgentPreflightCreate", "nexusNeedDraftCreate", "nexusHelpRequestsList", "nexusHelpRequestShow", "nexusHelpRequestCreate", "nexusHelpCandidatesList", "nexusHelpDispatchCreate", "nexusDispatchUpdate", "nexusHelpMatchCreate", "nexusMatchUpdate", "nexusMatchMessageCreate", "nexusMyWorkItemsList", "nexusForumDiscussionsList", "nexusForumDiscussionShow", "nexusForumDiscussionCreate", "nexusForumDiscussionPostCreate", "nexusMyForumDiscussionsList", "nexusMyForumPostsList", "nexusForumPostUpdate", "nexusForumPostDelete")) {
      if ($openApiOperationIds -contains $requiredOperationId) {
        Pass "OpenAPI operationId" $requiredOperationId
      } else {
        Fail "OpenAPI operationId" "missing $requiredOperationId"
      }
    }
    Assert-JsonPath "OpenAPI includes discoveryPlan schema" $openApiJson.components.schemas "NeedDraftDiscoveryPlan"
    Assert-JsonPath "OpenAPI includes labelReuse schema" $openApiJson.components.schemas "NeedDraftLabelReuse"
    Assert-JsonPath "OpenAPI includes labelReuse search schema" $openApiJson.components.schemas "NeedDraftLabelReuseSearch"
    Assert-JsonPath "OpenAPI includes agent health schema" $openApiJson.components.schemas "AgentHealth"
    Assert-JsonPath "OpenAPI includes endpoint map schema" $openApiJson.components.schemas "AgentEndpointMap"
    Assert-JsonPath "OpenAPI includes OpenApiTooling schema" $openApiJson.components.schemas "OpenApiTooling"
    Assert-JsonPath "OpenAPI includes Nexus agent skill extension" $openApiJson "x-nexus-agent-skill"
    $openApiNexusSkill = $openApiJson.PSObject.Properties["x-nexus-agent-skill"].Value
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
    Assert-JsonPath "OpenAPI AgentHealth has OpenAPI tooling" $openApiJson.components.schemas.AgentHealth.properties "openApiTooling"
    Assert-JsonPath "OpenAPI AgentContext has OpenAPI tooling" $openApiJson.components.schemas.AgentContext.properties "openApiTooling"
    Assert-JsonPath "OpenAPI endpoint map has helpCandidates" $openApiJson.components.schemas.AgentEndpointMap.properties "helpCandidates"
    Assert-JsonPath "OpenAPI endpoint map has matchMessages" $openApiJson.components.schemas.AgentEndpointMap.properties "matchMessages"
    Assert-JsonPath "OpenAPI endpoint map has myDeviceSignals" $openApiJson.components.schemas.AgentEndpointMap.properties "myDeviceSignals"
    if (($openApiJson.components.schemas.AgentHealth.properties.endpoints.'$ref') -eq "#/components/schemas/AgentEndpointMap" -and ($openApiJson.components.schemas.AgentContext.properties.endpoints.'$ref') -eq "#/components/schemas/AgentEndpointMap") {
      Pass "OpenAPI endpoint fields use AgentEndpointMap"
    } else {
      Fail "OpenAPI endpoint fields use AgentEndpointMap" "health=$($openApiJson.components.schemas.AgentHealth.properties.endpoints.'$ref') context=$($openApiJson.components.schemas.AgentContext.properties.endpoints.'$ref')"
    }
    if ($openApiJson.components.schemas.AgentEndpointMap.additionalProperties.type -eq "string" -and $openApiJson.components.schemas.AgentEndpointMap.properties.helpCandidates.example -eq "/api/nexus/help-requests/{id}/candidates") {
      Pass "OpenAPI endpoint map documents known keys"
    } else {
      Fail "OpenAPI endpoint map documents known keys" "unexpected endpoint map schema"
    }
    Assert-JsonPath "OpenAPI has Flarum discussion document schema" $openApiJson.components.schemas "FlarumDiscussionDocument"
    Assert-JsonPath "OpenAPI has Flarum post document schema" $openApiJson.components.schemas "FlarumPostDocument"
    if (($openApiJson.paths."/api/nexus/forum/discussions".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumDiscussionDocument" -and ($openApiJson.paths."/api/nexus/forum/discussions/{id}/posts".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumPostDocument" -and ($openApiJson.paths."/api/nexus/forum/posts/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/FlarumPostDocument") {
      Pass "OpenAPI forum write responses use concrete documents"
    } else {
      Fail "OpenAPI forum write responses use concrete documents" "discussion=$($openApiJson.paths."/api/nexus/forum/discussions".post.responses."201".content."application/vnd.api+json".schema.'$ref') reply=$($openApiJson.paths."/api/nexus/forum/discussions/{id}/posts".post.responses."201".content."application/vnd.api+json".schema.'$ref') edit=$($openApiJson.paths."/api/nexus/forum/posts/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref')"
    }
    if ([string] $agentHealthAttrs.openApiTooling.openApiVersion -eq [string] $openApiJson.info.version) {
      Pass "agent health tooling version matches OpenAPI" $openApiJson.info.version
    } else {
      Fail "agent health tooling version matches OpenAPI" "healthTooling=$($agentHealthAttrs.openApiTooling.openApiVersion) openapi=$($openApiJson.info.version)"
    }
    if ([string] $openApiNexusSkill.openapi_version -eq [string] $openApiJson.info.version) {
      Pass "OpenAPI Nexus skill extension version matches OpenAPI" $openApiJson.info.version
    } else {
      Fail "OpenAPI Nexus skill extension version matches OpenAPI" "extension=$($openApiNexusSkill.openapi_version) openapi=$($openApiJson.info.version)"
    }
    if ([string] $openApiNexusSkill.root_agent_entry -eq "/llms.txt" -and [string] $openApiNexusSkill.agent_tools -eq "/docs/agent-tools.json" -and [string] $openApiNexusSkill.manifest -eq "/.well-known/nexus-agent.json" -and [string] $openApiNexusSkill.agent_quickstart -eq "/docs/agent-quickstart.md" -and [string] $openApiNexusSkill.nexus_skill -eq "/docs/nexus-skill.md" -and [string] $openApiNexusSkill.agent_recipes -eq "/docs/agent-recipes.md") {
      Pass "OpenAPI Nexus skill extension links public docs"
    } else {
      Fail "OpenAPI Nexus skill extension links public docs" "root=$($openApiNexusSkill.root_agent_entry) tools=$($openApiNexusSkill.agent_tools) manifest=$($openApiNexusSkill.manifest) quickstart=$($openApiNexusSkill.agent_quickstart) skill=$($openApiNexusSkill.nexus_skill) recipes=$($openApiNexusSkill.agent_recipes)"
    }
    if ([string] $manifest.api.openapi_tooling.openapi_version -eq [string] $openApiJson.info.version) {
      Pass "manifest OpenAPI tooling version matches OpenAPI" $openApiJson.info.version
    } else {
      Fail "manifest OpenAPI tooling version matches OpenAPI" "manifest=$($manifest.api.openapi_tooling.openapi_version) openapi=$($openApiJson.info.version)"
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
      Pass "manifest core operationIds match health runtime tooling"
    } else {
      Fail "manifest core operationIds match health runtime tooling" "manifestAgentPreflight=$($manifest.api.openapi_tooling.core_operation_ids.agent_preflight) runtimeAgentPreflight=$($agentHealthAttrs.openApiTooling.coreOperationIds.agentPreflight)"
    }
    if ($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show -eq $agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow -and $manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create -eq $agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate -and $manifest.api.openapi_tooling.forum_operation_ids.my_forum_posts -eq $agentHealthAttrs.openApiTooling.forumOperationIds.myForumPosts) {
      Pass "manifest forum operationIds match health runtime tooling"
    } else {
      Fail "manifest forum operationIds match health runtime tooling" "manifestForumShow=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_show) runtimeForumShow=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionShow) manifestForumCreate=$($manifest.api.openapi_tooling.forum_operation_ids.forum_discussion_create) runtimeForumCreate=$($agentHealthAttrs.openApiTooling.forumOperationIds.forumDiscussionCreate)"
    }
    $openApiToolingRequired = @(As-Array $openApiJson.components.schemas.OpenApiTooling.required | ForEach-Object { [string] $_ })
    if ($openApiToolingRequired -contains "agentToolContract" -and [string] $openApiJson.components.schemas.OpenApiTooling.properties.agentToolContract.const -eq "/docs/agent-tools.json") {
      Pass "OpenAPI tooling schema includes agent tool contract"
    } else {
      Fail "OpenAPI tooling schema includes agent tool contract" "required=$($openApiToolingRequired -join ",") agentToolContract=$($openApiJson.components.schemas.OpenApiTooling.properties.agentToolContract.const)"
    }
    Assert-JsonPath "OpenAPI includes skillInstructions schema" $openApiJson.components.schemas "AgentSkillInstructions"
    Assert-JsonPath "OpenAPI skillInstructions has labelReuse" $openApiJson.components.schemas.AgentSkillInstructions.properties "labelReuse"
    Assert-JsonPath "OpenAPI skillInstructions has candidateRouting" $openApiJson.components.schemas.AgentSkillInstructions.properties "candidateRouting"
    Assert-JsonPath "OpenAPI skillInstructions has errorRecovery" $openApiJson.components.schemas.AgentSkillInstructions.properties "errorRecovery"
    Assert-JsonPath "OpenAPI skillInstructions has taskRecipes" $openApiJson.components.schemas.AgentSkillInstructions.properties "taskRecipes"
    Assert-JsonPath "OpenAPI includes AgentCoreToolMatrix schema" $openApiJson.components.schemas "AgentCoreToolMatrix"
    Assert-JsonPath "OpenAPI includes need draft document schema" $openApiJson.components.schemas "NeedDraftDocument"
    Assert-JsonPath "OpenAPI includes help request document schema" $openApiJson.components.schemas "HelpRequestDocument"
    Assert-JsonPath "OpenAPI includes help request collection schema" $openApiJson.components.schemas "HelpRequestCollectionDocument"
    Assert-JsonPath "OpenAPI includes help candidate collection schema" $openApiJson.components.schemas "HelpCandidateCollectionDocument"
    Assert-JsonPath "OpenAPI includes work item collection schema" $openApiJson.components.schemas "WorkItemCollectionDocument"
    if ($openApiJson.components.schemas.OpenApiTooling.properties.coreToolMatrix.'$ref' -eq "#/components/schemas/AgentCoreToolMatrix") {
      Pass "OpenAPI tooling schema uses AgentCoreToolMatrix"
    } else {
      Fail "OpenAPI tooling schema uses AgentCoreToolMatrix" "coreToolMatrix=$($openApiJson.components.schemas.OpenApiTooling.properties.coreToolMatrix.'$ref')"
    }
    if ($openApiJson.components.schemas.OpenApiTooling.properties.forumToolMatrix.'$ref' -eq "#/components/schemas/AgentForumToolMatrix") {
      Pass "OpenAPI tooling schema uses AgentForumToolMatrix"
    } else {
      Fail "OpenAPI tooling schema uses AgentForumToolMatrix" "forumToolMatrix=$($openApiJson.components.schemas.OpenApiTooling.properties.forumToolMatrix.'$ref')"
    }
    if ($openApiJson.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.forumDiscussionShow.example -eq "nexusForumDiscussionShow" -and $openApiJson.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.forumDiscussionCreate.example -eq "nexusForumDiscussionCreate" -and $openApiJson.components.schemas.OpenApiTooling.properties.forumOperationIds.properties.myForumPosts.example -eq "nexusMyForumPostsList") {
      Pass "OpenAPI tooling schema includes forum operationId examples"
    } else {
      Fail "OpenAPI tooling schema includes forum operationId examples" "unexpected forum operationId examples"
    }
    Assert-JsonPath "OpenAPI includes AgentForumToolRecipe schema" $openApiJson.components.schemas "AgentForumToolRecipe"
    Assert-JsonPath "OpenAPI includes AgentForumToolMatrix schema" $openApiJson.components.schemas "AgentForumToolMatrix"
    Assert-JsonPath "OpenAPI includes readiness schema" $openApiJson.components.schemas "AgentReadiness"
    Assert-JsonPath "OpenAPI includes preflight catalog schema" $openApiJson.components.schemas "AgentPreflightCatalog"
    Assert-JsonPath "OpenAPI includes preflight catalog action schema" $openApiJson.components.schemas "AgentPreflightCatalogAction"
    Assert-JsonPath "OpenAPI includes preflight recovery schema" $openApiJson.components.schemas "AgentPreflightRecovery"
    Assert-JsonPath "OpenAPI includes side effects schema" $openApiJson.components.schemas "AgentActionSideEffects"
    Assert-JsonPath "OpenAPI includes preflight template schema" $openApiJson.components.schemas "AgentPreflightTemplate"
    Assert-JsonPath "OpenAPI includes error document schema" $openApiJson.components.schemas "JsonApiErrorDocument"
    Assert-JsonPath "OpenAPI includes agent profile document schema" $openApiJson.components.schemas "AgentProfileDocument"
    Assert-JsonPath "OpenAPI includes capability label collection schema" $openApiJson.components.schemas "CapabilityLabelCollectionDocument"
    Assert-JsonPath "OpenAPI NeedDraftAttributes has labelReuse" $openApiJson.components.schemas.NeedDraftAttributes.properties "labelReuse"
    Assert-JsonPath "OpenAPI CapabilityLabelAttributes has reuseGuidance" $openApiJson.components.schemas.CapabilityLabelAttributes.properties "reuseGuidance"
    Assert-JsonPath "OpenAPI CapabilityLabelAttributes has nextActions" $openApiJson.components.schemas.CapabilityLabelAttributes.properties "nextActions"
    Assert-JsonPath "OpenAPI includes LLM settings document schema" $openApiJson.components.schemas "LlmSettingsDocument"
    Assert-JsonPath "OpenAPI includes dispatch collection schema" $openApiJson.components.schemas "HelpDispatchCollectionDocument"
    Assert-JsonPath "OpenAPI includes match message collection schema" $openApiJson.components.schemas "HelpMatchMessageCollectionDocument"
    Assert-JsonPath "OpenAPI includes reusable nextAction schema" $openApiJson.components.schemas "AgentNextAction"
    Assert-JsonPath "OpenAPI nextAction has catalogAction" $openApiJson.components.schemas.AgentNextAction.properties "catalogAction"
    Assert-JsonPath "OpenAPI nextAction has writeBodySchemaRef" $openApiJson.components.schemas.AgentNextAction.properties "writeBodySchemaRef"
    Assert-JsonPath "OpenAPI nextAction has sideEffects" $openApiJson.components.schemas.AgentNextAction.properties "sideEffects"
    Assert-JsonPath "OpenAPI includes preflight input schema" $openApiJson.components.schemas "AgentPreflightInput"
    Assert-JsonPath "OpenAPI includes preflight target schema" $openApiJson.components.schemas "AgentPreflightTarget"
    if ([string] $openApiJson.components.schemas.AgentPreflightTarget.properties.helperUserId.description -like "*echoes target.helperUserId*" -and [string] $openApiJson.components.schemas.AgentNextAction.properties.bodyTemplate.description -like "*create_dispatch.bodyTemplate*" -and [string] $openApiJson.paths."/api/nexus/help-requests/{id}/candidates".get.description -like "*target.helperUserId*") {
      Pass "OpenAPI documents candidate dispatch template verification"
    } else {
      Fail "OpenAPI documents candidate dispatch template verification" "helperUserId=$($openApiJson.components.schemas.AgentPreflightTarget.properties.helperUserId.description) bodyTemplate=$($openApiJson.components.schemas.AgentNextAction.properties.bodyTemplate.description)"
    }
    Assert-JsonPath "OpenAPI includes work item attributes schema" $openApiJson.components.schemas "WorkItemAttributes"
    Assert-JsonPath "OpenAPI includes dispatch attributes schema" $openApiJson.components.schemas "HelpDispatchAttributes"
    Assert-JsonPath "OpenAPI includes match attributes schema" $openApiJson.components.schemas "HelpMatchAttributes"
    if (($openApiJson.paths."/api/nexus/matches/{id}/messages".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpMatchMessageCollectionDocument") {
      Pass "OpenAPI match messages use concrete document"
    } else {
      Fail "OpenAPI match messages use concrete document" "unexpected schema"
    }
    if (($openApiJson.paths."/api/nexus/need-drafts".post.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/NeedDraftDocument") {
      Pass "OpenAPI need drafts use concrete document"
    } else {
      Fail "OpenAPI need drafts use concrete document" "unexpected schema"
    }
    if (($openApiJson.paths."/api/nexus/help-requests".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestCollectionDocument" -and ($openApiJson.paths."/api/nexus/help-requests".post.responses."201".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument") {
      Pass "OpenAPI help request collection/create use concrete documents"
    } else {
      Fail "OpenAPI help request collection/create use concrete documents" "unexpected schema"
    }
    if (($openApiJson.paths."/api/nexus/help-requests/{id}".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument" -and ($openApiJson.paths."/api/nexus/help-requests/{id}".patch.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpRequestDocument") {
      Pass "OpenAPI help request show/update use concrete document"
    } else {
      Fail "OpenAPI help request show/update use concrete document" "unexpected schema"
    }
    if (($openApiJson.paths."/api/nexus/help-requests/{id}/candidates".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/HelpCandidateCollectionDocument") {
      Pass "OpenAPI help candidates use concrete document"
    } else {
      Fail "OpenAPI help candidates use concrete document" "unexpected schema"
    }
    if (($openApiJson.paths."/api/nexus/me/work-items".get.responses."200".content."application/vnd.api+json".schema.'$ref') -eq "#/components/schemas/WorkItemCollectionDocument") {
      Pass "OpenAPI work items use concrete document"
    } else {
      Fail "OpenAPI work items use concrete document" "unexpected schema"
    }
  } catch {
    Fail "OpenAPI parses as JSON" $_.Exception.Message
  }

  $agentLabelDirectory = Assert-StatusUrl "agent public capability labels" "GET" (Join-Url $BaseUrl "/api/nexus/capability-labels?sort=popular&page%5Blimit%5D=5") @(200)
  try {
    $agentLabelDirectoryJson = $agentLabelDirectory.Content | ConvertFrom-Json
    $agentLabelItems = As-Array $agentLabelDirectoryJson.data
    if ($agentLabelItems.Count -gt 0) {
      $agentLabelAttrs = $agentLabelItems[0].attributes
      Assert-JsonPath "agent public label has reuseGuidance" $agentLabelAttrs "reuseGuidance"
      Assert-JsonPath "agent public label has nextActions" $agentLabelAttrs "nextActions"
    } else {
      Pass "agent public labels parse" "empty directory"
    }
  } catch {
    Fail "agent public capability labels parse" $_.Exception.Message
  }
  $agentForumSearch = Assert-StatusUrl "agent public forum gateway search" "GET" (Join-Url $BaseUrl "/api/nexus/forum/discussions?q=Nexus&page%5Blimit%5D=3") @(200)
  try {
    $agentForumSearchJson = $agentForumSearch.Content | ConvertFrom-Json
    $agentForumSearchItems = @(As-Array $agentForumSearchJson.data)
    if ($agentForumSearchItems.Count -gt 0) {
      $agentForumDiscussionId = [string] $agentForumSearchItems[0].id
      $agentForumShow = Assert-StatusUrl "agent public forum gateway opens discussion" "GET" (Join-Url $BaseUrl "/api/nexus/forum/discussions/${agentForumDiscussionId}?include=user,tags,posts,posts.user&page%5Blimit%5D=5") @(200)
      try {
        $agentForumShowJson = $agentForumShow.Content | ConvertFrom-Json
        if ($agentForumShowJson.data.type -eq "discussions" -and [string] $agentForumShowJson.data.id -eq $agentForumDiscussionId) {
          Pass "agent public forum gateway open discussion type" $agentForumDiscussionId
        } else {
          Fail "agent public forum gateway open discussion type" "type=$($agentForumShowJson.data.type) id=$($agentForumShowJson.data.id)"
        }
      } catch {
        Fail "agent public forum gateway open discussion parses" $_.Exception.Message
      }
    } else {
      Pass "agent public forum gateway open discussion skipped" "no public discussions returned by Nexus search"
    }
  } catch {
    Fail "agent public forum gateway search parses" $_.Exception.Message
  }
}

if (-not $authHeader) {
  Fail "authenticated agent simulation" "missing NEXUS_AGENT_AUTH in $EnvFile"
} else {
  $authHeaders = @{ Authorization = $authHeader }

  $contextPath = "/api/nexus/me/agent-context"
  $preflightPath = "/api/nexus/agent-preflight"
  $needDraftPath = "/api/nexus/need-drafts"
  $workItemsPath = "/api/nexus/me/work-items?page%5Blimit%5D=5"

  if ($manifest) {
    $contextPath = ([string] $manifest.nexus_endpoints.my_agent_context -replace "^GET\s+", "")
    $preflightPath = ([string] $manifest.nexus_endpoints.agent_preflight -replace "^POST\s+", "")
    $needDraftPath = ([string] $manifest.nexus_endpoints.need_drafts -replace "^POST\s+", "")
    $workItemsPath = ([string] $manifest.nexus_endpoints.my_work_items -replace "^GET\s+", "") + "?page%5Blimit%5D=5"
  }

  $agentContext = Assert-StatusUrl "agent bootstrap context" "GET" (Join-Url $BaseUrl $contextPath) @(200) $authHeaders
  try {
    $agentContextJson = $agentContext.Content | ConvertFrom-Json
    $agentContextAttrs = $agentContextJson.data.attributes
    Assert-JsonPath "agent context docs has root agent entry" $agentContextAttrs.docs "rootAgentEntry"
    Assert-JsonPath "agent context docs has agent tools" $agentContextAttrs.docs "agentTools"
    Assert-JsonPath "agent context docs has agent recipes" $agentContextAttrs.docs "agentRecipes"
    if ([string] $agentContextAttrs.docs.rootAgentEntry -eq (Join-Url $BaseUrl "/llms.txt") -and [string] $agentContextAttrs.docs.agentTools -eq (Join-Url $BaseUrl "/docs/agent-tools.json") -and [string] $agentContextAttrs.docs.agentRecipes -eq (Join-Url $BaseUrl "/docs/agent-recipes.md") -and [string] $agentContextAttrs.docs.openapi -eq (Join-Url $BaseUrl "/docs/openapi.json") -and [string] $agentContextAttrs.docs.manifest -eq (Join-Url $BaseUrl "/.well-known/nexus-agent.json")) {
      Pass "agent context docs use discovered origin"
    } else {
      Fail "agent context docs use discovered origin" "root=$($agentContextAttrs.docs.rootAgentEntry) tools=$($agentContextAttrs.docs.agentTools) recipes=$($agentContextAttrs.docs.agentRecipes) openapi=$($agentContextAttrs.docs.openapi) manifest=$($agentContextAttrs.docs.manifest)"
    }
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
    if ($agentContextAttrs.openApiTooling.coreOperationIds.agentPreflight -eq "nexusAgentPreflightCreate" -and $agentContextAttrs.openApiTooling.coreOperationIds.myWorkItems -eq "nexusMyWorkItemsList") {
      Pass "agent context exposes runtime core operationIds"
    } else {
      Fail "agent context exposes runtime core operationIds" "agentPreflight=$($agentContextAttrs.openApiTooling.coreOperationIds.agentPreflight) myWorkItems=$($agentContextAttrs.openApiTooling.coreOperationIds.myWorkItems)"
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
    Assert-JsonPath "agent context has endpoint map" $agentContextAttrs "endpoints"
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
      Assert-JsonPath "agent context endpoint map includes $($entry.Key)" $agentContextAttrs.endpoints $entry.Key
      $actualEndpoint = [string] $agentContextAttrs.endpoints.PSObject.Properties[$entry.Key].Value
      if ($actualEndpoint -eq $entry.Value) {
        Pass "agent context endpoint map value $($entry.Key)" $actualEndpoint
      } else {
        Fail "agent context endpoint map value $($entry.Key)" "expected $($entry.Value), got $actualEndpoint"
      }
    }
    Assert-JsonPath "agent context has preflight catalog" $agentContextAttrs "agentPreflight"
    Assert-JsonPath "agent context has readiness" $agentContextAttrs "agentReadiness"
    Assert-JsonPath "agent context has work queue" $agentContextAttrs "workQueue"
    Assert-JsonPath "agent context has skill instructions" $agentContextAttrs "skillInstructions"
    Assert-JsonPath "agent context preflight includes help request create" $agentContextAttrs.agentPreflight.actions "help_request.create"
    Assert-JsonPath "agent context preflight includes dispatch create" $agentContextAttrs.agentPreflight.actions "dispatch.create"
    Assert-JsonPath "agent context preflight includes device signal create" $agentContextAttrs.agentPreflight.actions "device_signal.create"
    Assert-JsonPath "agent context preflight dispatch has purpose" $agentContextAttrs.agentPreflight.actions."dispatch.create" "purpose"
    Assert-JsonPath "agent context preflight dispatch has target type" $agentContextAttrs.agentPreflight.actions."dispatch.create" "targetType"
    Assert-JsonPath "agent context preflight dispatch has target aliases" $agentContextAttrs.agentPreflight.actions."dispatch.create" "targetIdAliases"
    Assert-JsonPath "agent context preflight dispatch has proposed fields" $agentContextAttrs.agentPreflight.actions."dispatch.create" "proposedFields"
    Assert-JsonPath "agent context preflight dispatch has schema ref" $agentContextAttrs.agentPreflight.actions."dispatch.create" "writeBodySchemaRef"
    Assert-JsonPath "agent context preflight dispatch has side effects" $agentContextAttrs.agentPreflight.actions."dispatch.create" "sideEffects"
    Assert-JsonPath "agent context preflight dispatch has example body" $agentContextAttrs.agentPreflight.actions."dispatch.create" "examplePreflightBody"
    if ($agentContextAttrs.agentPreflight.actions."help_request.create".sideEffects.createsPublicDiscussion -eq $true -and [string] $agentContextAttrs.agentPreflight.actions."help_request.create".sideEffects.serverAppendedFooter) {
      Pass "agent context help request side effects explain public discussion"
    } else {
      Fail "agent context help request side effects explain public discussion" "missing createsPublicDiscussion/serverAppendedFooter"
    }
    $deviceSignalFields = @(As-Array $agentContextAttrs.agentPreflight.actions."device_signal.create".proposedFields)
    if (($deviceSignalFields -contains "purpose") -and ($deviceSignalFields -contains "coarseGeohash") -and ($deviceSignalFields -contains "bluetoothSeen") -and ($deviceSignalFields -notcontains "signalType")) {
      Pass "agent context device signal recipe uses runtime fields"
    } else {
      Fail "agent context device signal recipe uses runtime fields" "fields=$($deviceSignalFields -join ",")"
    }
    Assert-JsonPath "agent readiness has physical help flag" $agentContextAttrs.agentReadiness "physicalHelpReady"
    Assert-JsonPath "agent skill instructions have read-before-write" $agentContextAttrs.skillInstructions "readBeforeWrite"
    Assert-JsonPath "agent skill instructions have label reuse runbook" $agentContextAttrs.skillInstructions "labelReuse"
    Assert-JsonPath "agent skill instructions have candidate routing runbook" $agentContextAttrs.skillInstructions "candidateRouting"
    Assert-JsonPath "agent skill instructions have error recovery runbook" $agentContextAttrs.skillInstructions "errorRecovery"
    Assert-JsonPath "agent skill instructions have write recipes" $agentContextAttrs.skillInstructions "writeRecipes"
    Assert-JsonPath "agent skill instructions have task recipes" $agentContextAttrs.skillInstructions "taskRecipes"
    Assert-JsonPath "agent skill instructions include help request recipe" $agentContextAttrs.skillInstructions.writeRecipes "create_physical_help_request"
    if ($agentContextAttrs.schemaVersion -eq "0.7") {
      Pass "agent context schema version" $agentContextAttrs.schemaVersion
    } else {
      Fail "agent context schema version" "expected 0.7, got $($agentContextAttrs.schemaVersion)"
    }
    if ($agentContextAttrs.skillInstructions.schemaVersion -eq "0.5") {
      Pass "agent skill instructions schema version" $agentContextAttrs.skillInstructions.schemaVersion
    } else {
      Fail "agent skill instructions schema version" "expected 0.5, got $($agentContextAttrs.skillInstructions.schemaVersion)"
    }
    if ($agentContextAttrs.skillInstructions.taskRecipes.publicDocs -eq "/docs/agent-recipes.md" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.createHelpRequest.writeOperationId -eq "nexusHelpRequestCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.findCandidateHelpers.readOperationId -eq "nexusHelpCandidatesList" -and $agentContextAttrs.skillInstructions.taskRecipes.matrix.pollWorkQueue.readOperationId -eq "nexusMyWorkItemsList") {
      Pass "agent skill task recipes expose core matrix"
    } else {
      Fail "agent skill task recipes expose core matrix" "unexpected taskRecipes"
    }
    $agentContextTaskReplyReadFirst = @(As-Array $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.replyToForumDiscussion.readFirst | ForEach-Object { [string] $_.name })
    if ($agentContextAttrs.skillInstructions.taskRecipes.schemaVersion -eq "0.2" -and $agentContextAttrs.skillInstructions.taskRecipes.forumSource -eq "OpenApiTooling::forumToolMatrix" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.openForumDiscussion.readOperationId -eq "nexusForumDiscussionShow" -and ($agentContextTaskReplyReadFirst -contains "open_forum_discussion") -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.createForumDiscussion.writeOperationId -eq "nexusForumDiscussionCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.replyToForumDiscussion.writeOperationId -eq "nexusForumDiscussionPostCreate" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.recoverMyForumPosts.readOperationId -eq "nexusMyForumPostsList" -and $agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.hideOwnForumPost.writeOperationId -eq "nexusForumPostDelete") {
      Pass "agent skill task recipes expose forum matrix"
    } else {
      Fail "agent skill task recipes expose forum matrix" "unexpected forumMatrix"
    }
    $agentContextTaskForumMatrixKeys = @($agentContextAttrs.skillInstructions.taskRecipes.forumMatrix.PSObject.Properties | ForEach-Object { $_.Name })
    $missingAgentContextTaskForumMatrixKeys = @($forumMatrixKeysCamel | Where-Object { $agentContextTaskForumMatrixKeys -notcontains $_ })
    if ($missingAgentContextTaskForumMatrixKeys.Count -eq 0) {
      Pass "agent skill task recipes forum matrix has all forum tasks"
    } else {
      Fail "agent skill task recipes forum matrix has all forum tasks" "missing=$($missingAgentContextTaskForumMatrixKeys -join ",")"
    }
    $skillCandidateRouting = $agentContextAttrs.skillInstructions.candidateRouting
    if ($skillCandidateRouting.schemaVersion -eq "0.1" -and $skillCandidateRouting.endpoint -eq "/api/nexus/help-requests/{id}/candidates") {
      Pass "agent skill candidateRouting schema and endpoint"
    } else {
      Fail "agent skill candidateRouting schema and endpoint" "schema=$($skillCandidateRouting.schemaVersion) endpoint=$($skillCandidateRouting.endpoint)"
    }
    $skillCandidateRunbook = As-Array $skillCandidateRouting.runbook
    $skillCandidateSteps = @($skillCandidateRunbook | ForEach-Object { [string] $_.step })
    $requiredCandidateSteps = @("rank_candidates", "preflight_dispatch", "confirm_and_dispatch")
    $missingCandidateSteps = @($requiredCandidateSteps | Where-Object { $skillCandidateSteps -notcontains $_ })
    if ($missingCandidateSteps.Count -eq 0) {
      Pass "agent skill candidateRouting has dispatch runbook steps"
    } else {
      Fail "agent skill candidateRouting has dispatch runbook steps" "missing=$($missingCandidateSteps -join ",") steps=$($skillCandidateSteps -join ",")"
    }
    Assert-JsonPath "agent skill candidateRouting responseFields include dispatch rationale" $skillCandidateRouting.responseFields "dispatchRationaleTemplate"
    if ([string] $skillCandidateRouting.responseFields.nextActions -like "*create_dispatch.bodyTemplate*" -and [string] $skillCandidateRouting.responseFields.nextActions -like "*target.helperUserId*") {
      Pass "agent skill candidateRouting explains dispatch body template"
    } else {
      Fail "agent skill candidateRouting explains dispatch body template" "nextActions=$($skillCandidateRouting.responseFields.nextActions)"
    }
    $candidatePreflightStep = @($skillCandidateRunbook | Where-Object { [string] $_.step -eq "preflight_dispatch" } | Select-Object -First 1)
    $candidateDispatchStep = @($skillCandidateRunbook | Where-Object { [string] $_.step -eq "confirm_and_dispatch" } | Select-Object -First 1)
    if ($candidatePreflightStep.Count -eq 1 -and [string] $candidatePreflightStep[0].instruction -like "*target.helperUserId*" -and $candidateDispatchStep.Count -eq 1 -and [string] $candidateDispatchStep[0].instruction -like "*create_dispatch.bodyTemplate*") {
      Pass "agent skill candidateRouting runbook uses verified dispatch template"
    } else {
      Fail "agent skill candidateRouting runbook uses verified dispatch template" "preflight=$($candidatePreflightStep[0].instruction) dispatch=$($candidateDispatchStep[0].instruction)"
    }
    $skillCandidateSelectionRules = [string] (@(As-Array $skillCandidateRouting.selectionRules) -join "`n")
    if ($skillCandidateSelectionRules.Contains("target.helperUserId")) {
      Pass "agent skill candidateRouting guards helper mismatch"
    } else {
      Fail "agent skill candidateRouting guards helper mismatch" "selectionRules=$skillCandidateSelectionRules"
    }
    $skillCandidateConfirmFields = @(As-Array $skillCandidateRouting.confirmationMustShow | ForEach-Object { [string] $_ })
    if ($skillCandidateConfirmFields -contains "sideEffects") {
      Pass "agent skill candidateRouting confirmation shows sideEffects"
    } else {
      Fail "agent skill candidateRouting confirmation shows sideEffects" "fields=$($skillCandidateConfirmFields -join ",")"
    }
    $skillCandidateFallbacks = As-Array $skillCandidateRouting.fallbackReads
    $hasWorkQueueFallback = @($skillCandidateFallbacks | Where-Object { [string] $_.name -eq "recover_work_queue" -or [string] $_.endpoint -eq "/api/nexus/me/work-items" }).Count -gt 0
    if ($hasWorkQueueFallback) {
      Pass "agent skill candidateRouting has work queue fallback"
    } else {
      Fail "agent skill candidateRouting has work queue fallback" "missing recover_work_queue fallback"
    }
    $skillLabelReuse = $agentContextAttrs.skillInstructions.labelReuse
    $skillLabelReuseRunbook = As-Array $skillLabelReuse.runbook
    $skillLabelSearch = @($skillLabelReuseRunbook | Where-Object { [string] $_.step -eq "search_label_directory" } | Select-Object -First 1)
    if ($skillLabelSearch.Count -eq 1 -and $skillLabelSearch[0].endpoint -eq "/api/nexus/capability-labels" -and $skillLabelSearch[0].query.inname -eq "<keyword>" -and $skillLabelSearch[0].query.sort -eq "popular" -and $skillLabelSearch[0].writesState -eq $false) {
      Pass "agent skill labelReuse has executable label search"
    } else {
      Fail "agent skill labelReuse has executable label search" "unexpected label reuse runbook"
    }
    $skillLabelHelperSearch = @($skillLabelReuseRunbook | Where-Object { [string] $_.step -eq "inspect_helpers" } | Select-Object -First 1)
    if ($skillLabelHelperSearch.Count -eq 1 -and $skillLabelHelperSearch[0].endpoint -eq "/api/nexus/capabilities" -and $skillLabelHelperSearch[0].query."filter[label]" -eq "<attributes.label>" -and $skillLabelHelperSearch[0].writesState -eq $false) {
      Pass "agent skill labelReuse has helper inspection"
    } else {
      Fail "agent skill labelReuse has helper inspection" "unexpected helper search"
    }
    $skillReadBeforeWrite = As-Array $agentContextAttrs.skillInstructions.readBeforeWrite
    $skillLabelReadAction = @($skillReadBeforeWrite | Where-Object { [string] $_.name -eq "search_capability_labels_by_keyword" } | Select-Object -First 1)
    if ($skillLabelReadAction.Count -eq 1 -and $skillLabelReadAction[0].query.inname -eq "<keyword>" -and $skillLabelReadAction[0].query.sort -eq "popular" -and $skillLabelReadAction[0].writesState -eq $false) {
      Pass "agent skill read-before-write has query-bearing label search"
    } else {
      Fail "agent skill read-before-write has query-bearing label search" "unexpected readBeforeWrite label action"
    }
    $skillErrorRecovery = $agentContextAttrs.skillInstructions.errorRecovery
    if ($skillErrorRecovery.schemaVersion -eq "0.1" -and $skillErrorRecovery.httpStatusPolicy."422".retrySameBody -eq $false -and $skillErrorRecovery.blockingCheckPolicy.allowAgentMatching) {
      Pass "agent skill errorRecovery has retry policy"
    } else {
      Fail "agent skill errorRecovery has retry policy" "unexpected errorRecovery"
    }

    if ($agentContext.Content -match '"soulMd"\s*:') {
      Fail "agent context redacts raw soulMd" "response contains raw soulMd key"
    } else {
      Pass "agent context redacts raw soulMd"
    }
  } catch {
    Fail "agent context parses as JSON" $_.Exception.Message
  }

  $draftBody = @{
    data = @{
      type = "nexus-need-drafts"
      attributes = @{
        rawUserNeed = "My laptop will not boot near the library. I need nearby computer repair help."
        intent = "auto"
        locationHint = "library public desk"
      }
    }
  }
  $draft = Assert-StatusUrl "agent drafts need without publish" "POST" (Join-Url $BaseUrl $needDraftPath) @(200) $authHeaders $draftBody
  try {
    $draftJson = $draft.Content | ConvertFrom-Json
    $draftAttrs = $draftJson.data.attributes
    if ($draftJson.data.type -eq "nexus-need-drafts" -and $draftAttrs.publish.body.data.attributes.userConfirmed -eq $false) {
      Pass "need draft publish body remains unconfirmed"
    } else {
      Fail "need draft publish body remains unconfirmed" "unexpected draft response"
    }

    Assert-JsonPath "need draft has labelReuse" $draftAttrs "labelReuse"
    $labelReuse = $draftAttrs.labelReuse
    if ($labelReuse.readOnly -eq $true) {
      Pass "need draft labelReuse is read-only"
    } else {
      Fail "need draft labelReuse is read-only" "expected true"
    }
    $labelReuseSearches = As-Array $labelReuse.searches
    $labelReuseEndpoints = @($labelReuseSearches | ForEach-Object { [string] $_.endpoint })
    if ($labelReuseEndpoints -contains "/api/nexus/capability-labels") {
      Pass "need draft labelReuse includes label directory search"
    } else {
      Fail "need draft labelReuse includes label directory search" "endpoints=$($labelReuseEndpoints -join ",")"
    }

    Assert-JsonPath "need draft has discoveryPlan" $draftAttrs "discoveryPlan"
    $discoveryPlan = $draftAttrs.discoveryPlan
    if ($discoveryPlan.readOnly -eq $true) {
      Pass "need draft discoveryPlan is read-only"
    } else {
      Fail "need draft discoveryPlan is read-only" "expected true"
    }

    $discoverySteps = As-Array $discoveryPlan.steps
    $discoveryEndpoints = @($discoverySteps | ForEach-Object { [string] $_.endpoint })
    if ($discoveryEndpoints -contains "/api/nexus/capability-labels" -and $discoveryEndpoints -contains "/api/nexus/forum/discussions") {
      Pass "need draft discoveryPlan includes core read searches" ($discoveryEndpoints -join ",")
    } else {
      Fail "need draft discoveryPlan includes core read searches" "endpoints=$($discoveryEndpoints -join ",")"
    }

    $reuseExistingLabelStep = @($discoverySteps | Where-Object { [string] $_.name -eq "reuse_existing_labels" } | Select-Object -First 1)
    if ($reuseExistingLabelStep.Count -eq 1 -and $reuseExistingLabelStep[0].endpoint -eq "/api/nexus/capability-labels" -and $reuseExistingLabelStep[0].query.inname -and $reuseExistingLabelStep[0].query.sort -eq "popular" -and $reuseExistingLabelStep[0].writesState -eq $false) {
      Pass "need draft discoveryPlan has label reuse query"
    } else {
      Fail "need draft discoveryPlan has label reuse query" "unexpected reuse step"
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

  $chineseDraftCases = @(
    @{
      Name = "Chinese umbrella help"
      RawBase64 = "5oiR5Zyo5Zu+5Lmm6aaG6Zeo5Y+j77yM5LiL6Zuo5LqG5rKh5bim5Lye77yM6IO95LiN6IO95om+5Lq65biu5oiR6YCB5Lye77yf"
      ExpectedIntent = "help"
      ExpectedLabel = "umbrella-help"
      ExpectedUrgency = "soon"
      ExpectedLocationBase64 = "5Zu+5Lmm6aaG6Zeo5Y+j"
      ShouldEnterForum = $true
      ExpectedPublishEndpoint = "POST /api/nexus/help-requests"
    },
    @{
      Name = "Chinese computer repair"
      RawBase64 = "5oiR55qE56yU6K6w5pys5Zyo5a6/6IiN5byA5LiN5LqG5py677yM6JOd5bGP77yM5oOz5om+55S16ISR57u05L+u44CC"
      ExpectedIntent = "help"
      ExpectedLabel = "computer-repair"
      ExpectedUrgency = "normal"
      ExpectedLocationBase64 = "5a6/6IiN"
      ShouldEnterForum = $true
      ExpectedPublishEndpoint = "POST /api/nexus/help-requests"
    },
    @{
      Name = "Chinese direct answer"
      RawBase64 = "5biu5oiR5YaZ5LiA5Lu9UFBU5aSn57qy77yM6Kej6YeKTmV4dXPorrrlnZtBUEnmgI7kuYjmjqXlhaXjgII="
      ExpectedIntent = "direct-answer"
      ExpectedLabel = "direct-answer"
      ExpectedUrgency = "normal"
      ExpectedLocationBase64 = $null
      ShouldEnterForum = $false
      ExpectedPublishEndpoint = $null
    },
    @{
      Name = "Chinese team request"
      RawBase64 = "5oiR5Zyo5Yib5paw5qW877yM5oOz5om+6Zif5Y+L5LiA6LW35Y+C5Yqg6buR5a6i5p2+6aG555uu44CC"
      ExpectedIntent = "team"
      ExpectedLabel = "team-up"
      ExpectedUrgency = "normal"
      ExpectedLocationBase64 = "5Yib5paw5qW8"
      ShouldEnterForum = $true
      ExpectedPublishEndpoint = "POST /api/nexus/forum/discussions"
      ExpectedTargetTagSlug = "team"
    },
    @{
      Name = "Chinese friend request"
      RawBase64 = "5oiR5Zyo5Lic5Yy677yM5oOz5om+6aWt5pCt5a2Q5ZGo5pyr5LiA6LW35ZCD6aWt44CC"
      ExpectedIntent = "friend"
      ExpectedLabel = "social-match"
      ExpectedUrgency = "normal"
      ExpectedLocationBase64 = "5Lic5Yy6"
      ShouldEnterForum = $true
      ExpectedPublishEndpoint = "POST /api/nexus/forum/discussions"
      ExpectedTargetTagSlug = "friend"
    }
  )

  foreach ($case in $chineseDraftCases) {
    $caseBody = @{
      data = @{
        type = "nexus-need-drafts"
        attributes = @{
          rawUserNeed = Decode-Base64Utf8 $case.RawBase64
          intent = "auto"
        }
      }
    }
    $caseResponse = Assert-StatusUrl "agent drafts $($case.Name)" "POST" (Join-Url $BaseUrl $needDraftPath) @(200) $authHeaders $caseBody

    try {
      $caseJson = $caseResponse.Content | ConvertFrom-Json
      $caseAttrs = $caseJson.data.attributes
      $caseLabels = As-Array $caseAttrs.neededLabels

      if ($caseJson.data.type -eq "nexus-need-drafts" -and $caseAttrs.intent -eq $case.ExpectedIntent) {
        Pass "$($case.Name) intent" $caseAttrs.intent
      } else {
        Fail "$($case.Name) intent" "expected $($case.ExpectedIntent), got type=$($caseJson.data.type) intent=$($caseAttrs.intent)"
      }

      if ($caseLabels -contains $case.ExpectedLabel) {
        Pass "$($case.Name) label" $case.ExpectedLabel
      } else {
        Fail "$($case.Name) label" "expected $($case.ExpectedLabel), labels=$($caseLabels -join ",")"
      }

      if ($caseAttrs.urgency -eq $case.ExpectedUrgency) {
        Pass "$($case.Name) urgency" $caseAttrs.urgency
      } else {
        Fail "$($case.Name) urgency" "expected $($case.ExpectedUrgency), got $($caseAttrs.urgency)"
      }

      if ($case.ExpectedLocationBase64) {
        $expectedLocation = Decode-Base64Utf8 $case.ExpectedLocationBase64
        if ($caseAttrs.locationHint -eq $expectedLocation) {
          Pass "$($case.Name) location" $caseAttrs.locationHint
        } else {
          Fail "$($case.Name) location" "expected $expectedLocation, got $($caseAttrs.locationHint)"
        }
      } elseif ($null -eq $caseAttrs.locationHint) {
        Pass "$($case.Name) has no location"
      } else {
        Fail "$($case.Name) has no location" "unexpected location $($caseAttrs.locationHint)"
      }

      if ($caseAttrs.shouldEnterForum -eq $case.ShouldEnterForum) {
        Pass "$($case.Name) forum routing" "shouldEnterForum=$($caseAttrs.shouldEnterForum)"
      } else {
        Fail "$($case.Name) forum routing" "expected $($case.ShouldEnterForum), got $($caseAttrs.shouldEnterForum)"
      }

      if ($case.ExpectedPublishEndpoint) {
        if ($caseAttrs.publish.endpoint -eq $case.ExpectedPublishEndpoint -and $caseAttrs.publish.body.data.attributes.userConfirmed -eq $false) {
          Pass "$($case.Name) publish draft" $caseAttrs.publish.endpoint
        } else {
          Fail "$($case.Name) publish draft" "endpoint=$($caseAttrs.publish.endpoint) userConfirmed=$($caseAttrs.publish.body.data.attributes.userConfirmed)"
        }

        if ($case.ExpectedTargetTagSlug) {
          $publishTags = As-Array $caseAttrs.publish.body.data.attributes.tags
          if ($caseAttrs.targetTagSlug -eq $case.ExpectedTargetTagSlug -and $publishTags -contains $case.ExpectedTargetTagSlug) {
            Pass "$($case.Name) target forum tag" $case.ExpectedTargetTagSlug
          } else {
            Fail "$($case.Name) target forum tag" "targetTagSlug=$($caseAttrs.targetTagSlug) publishTags=$($publishTags -join ",")"
          }
        }
      } elseif ($null -eq $caseAttrs.publish.endpoint -and $null -eq $caseAttrs.publish.body) {
        Pass "$($case.Name) stays local"
      } else {
        Fail "$($case.Name) stays local" "endpoint=$($caseAttrs.publish.endpoint)"
      }
    } catch {
      Fail "$($case.Name) parses as JSON" $_.Exception.Message
    }
  }

  $preflightBody = @{
    data = @{
      type = "nexus-agent-preflights"
      attributes = @{
        action = "help_request.create"
        userConfirmed = $false
      }
    }
  }
  $preflight = Assert-StatusUrl "agent preflights help request" "POST" (Join-Url $BaseUrl $preflightPath) @(200) $authHeaders $preflightBody
  try {
    $preflightJson = $preflight.Content | ConvertFrom-Json
    $preflightAttrs = $preflightJson.data.attributes
    Assert-JsonPath "preflight checks confirmation" $preflightAttrs.checks "userConfirmed"
    Assert-JsonPath "preflight checks matching permission" $preflightAttrs.checks "allowAgentMatching"
    Assert-JsonPath "preflight exposes proposed fields" $preflightAttrs "proposedFields"
    Assert-JsonPath "preflight exposes write schema ref" $preflightAttrs "writeBodySchemaRef"
    Assert-JsonPath "preflight exposes side effects" $preflightAttrs "sideEffects"
    Assert-JsonPath "preflight exposes recovery" $preflightAttrs "recovery"

    if ($preflightAttrs.allowed -eq $false) {
      Pass "preflight blocks unconfirmed write"
    } else {
      Fail "preflight blocks unconfirmed write" "expected allowed=false"
    }

    if ($preflightAttrs.notes.noDatabaseWrite -eq $true) {
      Pass "preflight says no database write"
    } else {
      Fail "preflight says no database write" "expected true"
    }
    if ($preflightAttrs.recovery.status -eq "blocked_needs_recovery" -and $preflightAttrs.recovery.retryPolicy.retrySameBody -eq $false) {
      Pass "preflight recovery blocks same-body retry"
    } else {
      Fail "preflight recovery blocks same-body retry" "status=$($preflightAttrs.recovery.status)"
    }
    $preflightRecoverySteps = As-Array $preflightAttrs.recovery.steps
    $confirmRecovery = @($preflightRecoverySteps | Where-Object { [string] $_.name -eq "ask_user_to_confirm_exact_action" } | Select-Object -First 1)
    if ($confirmRecovery.Count -eq 1 -and $confirmRecovery[0].requiresUserConfirmation -eq $true) {
      Pass "preflight recovery includes confirmation step"
    } else {
      Fail "preflight recovery includes confirmation step" "unexpected recovery steps"
    }
  } catch {
    Fail "preflight parses as JSON" $_.Exception.Message
  }

  Assert-StatusUrl "agent reads work queue" "GET" (Join-Url $BaseUrl $workItemsPath) @(200) $authHeaders | Out-Null
}

Write-Host ""
Write-Host "Agent skill smoke complete: failures=$Script:Failures"

if ($Script:Failures -gt 0) {
  exit 1
}
