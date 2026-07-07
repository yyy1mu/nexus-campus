param(
  [string] $BaseUrl,
  [string] $EnvFile,
  [switch] $KeepFixture
)

$ErrorActionPreference = "Stop"

$Script:Failures = 0

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

function Require-True {
  param(
    [string] $Name,
    [bool] $Condition,
    [string] $Detail
  )

  if ($Condition) {
    Pass $Name $Detail
  } else {
    Fail $Name $Detail
    throw "Required smoke assertion failed: $Name"
  }
}

function Invoke-NexusHttp {
  param(
    [string] $Method,
    [string] $Path,
    [hashtable] $Headers = @{},
    $Body = $null
  )

  $params = @{
    Method = $Method
    Uri = (Join-Url $Script:BaseUrl $Path)
    UseBasicParsing = $true
    TimeoutSec = 30
    Headers = $Headers
  }

  if ($null -ne $Body) {
    $params["ContentType"] = "application/json"
    $params["Body"] = ($Body | ConvertTo-Json -Depth 32 -Compress)
  }

  try {
    $response = Invoke-WebRequest @params
    return [pscustomobject] @{
      Status = [int] $response.StatusCode
      Content = Convert-ToUtf8Text $response.Content
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

function Assert-Status {
  param(
    [string] $Name,
    [string] $Method,
    [string] $Path,
    [int[]] $Expected,
    [hashtable] $Headers = @{},
    $Body = $null
  )

  $response = Invoke-NexusHttp -Method $Method -Path $Path -Headers $Headers -Body $Body

  if ($Expected -contains $response.Status) {
    Pass $Name "$Method $Path -> $($response.Status)"
  } else {
    Fail $Name "$Method $Path returned $($response.Status), expected $($Expected -join ","). Body: $($response.Content.Substring(0, [Math]::Min(500, $response.Content.Length)))"
    throw "Unexpected HTTP status for $Name"
  }

  return $response
}

function ConvertFrom-NexusJson {
  param(
    [string] $Name,
    [string] $Content
  )

  try {
    return $Content | ConvertFrom-Json
  } catch {
    Fail $Name $_.Exception.Message
    throw
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

function Copy-NexusJsonObject {
  param($Value)

  return ($Value | ConvertTo-Json -Depth 32 -Compress) | ConvertFrom-Json
}

function Assert-RichNextAction {
  param(
    [string] $Name,
    $Action,
    [string] $CatalogAction,
    [string] $SchemaRef,
    [string] $SideEffectField
  )

  Require-True "$Name has catalogAction" ([string] $Action.catalogAction -eq $CatalogAction) "catalogAction=$($Action.catalogAction)"
  Require-True "$Name has writeBodySchemaRef" ([string] $Action.writeBodySchemaRef -eq $SchemaRef) "writeBodySchemaRef=$($Action.writeBodySchemaRef)"

  $proposedFields = As-Array $Action.proposedFields
  Require-True "$Name has proposedFields" ($proposedFields.Count -gt 0) "proposedFields=$($proposedFields -join ",")"
  Require-True "$Name has sideEffects.$SideEffectField" ($Action.sideEffects.$SideEffectField -eq $true) "sideEffects.$SideEffectField=$($Action.sideEffects.$SideEffectField)"
}

function Set-AgentMatchingAllowed {
  param(
    [string] $Name,
    [hashtable] $Headers,
    [bool] $Allowed
  )

  $body = @{
    data = @{
      type = "nexus-agent-profiles"
      attributes = @{
        userConfirmed = $true
        permissions = @{
          allowAgentMatching = $Allowed
        }
      }
    }
  }

  $response = Assert-Status "$Name sets allowAgentMatching=$Allowed" "PATCH" "/api/nexus/me/agent-profile" @(200) $Headers $body
  $json = ConvertFrom-NexusJson "$Name allowAgentMatching response parses" $response.Content
  Require-True "$Name allowAgentMatching round trips" ($json.data.attributes.permissions.allowAgentMatching -eq $Allowed) "allowAgentMatching=$Allowed"
}

function Convert-WindowsPathToWsl {
  param([string] $Path)

  if ($Path -match "^([A-Za-z]):\\(.*)$") {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace "\\", "/"
    return "/mnt/$drive/$rest"
  }

  return $Path -replace "\\", "/"
}

function Quote-Bash {
  param([string] $Value)

  return "'" + ($Value -replace "'", "'`"`"'") + "'"
}

function Invoke-Fixture {
  param(
    [string] $Action,
    [string] $RunId,
    [string] $FixtureRel
  )

  $repoWsl = Convert-WindowsPathToWsl $Script:RepoRoot

  if ($Action -eq "create") {
    $command = "cd $(Quote-Bash $repoWsl) && php scripts/nexus-core-flow-fixture.php create $(Quote-Bash $RunId) $(Quote-Bash $FixtureRel)"
  } elseif ($Action -eq "cleanup") {
    $command = "cd $(Quote-Bash $repoWsl) && php scripts/nexus-core-flow-fixture.php cleanup $(Quote-Bash $FixtureRel)"
  } else {
    throw "Unknown fixture action: $Action"
  }

  & wsl -e bash -lc $command
}

$Script:RepoRoot = Resolve-RepoRoot

if (-not $EnvFile) {
  $EnvFile = Join-Path $Script:RepoRoot "storage\nexus\agent-api.env"
}

$envValues = Read-NexusEnv -Path $EnvFile

if (-not $BaseUrl) {
  $BaseUrl = $envValues["NEXUS_BASE_URL"]
}

if (-not $BaseUrl) {
  $BaseUrl = "http://10.98.65.32:8080"
}

$Script:BaseUrl = $BaseUrl.TrimEnd("/")
$runId = ("core-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)).ToLowerInvariant()
$fixtureRel = "storage/nexus/core-flow-$runId.json"
$fixturePath = Join-Path $Script:RepoRoot $fixtureRel
$label = "smoke-$runId"

Write-Host "Nexus core flow smoke target: $Script:BaseUrl"
Write-Host "Repo root: $Script:RepoRoot"
Write-Host "Run id: $runId"
Write-Host ""

$fixtureCreated = $false

try {
  Invoke-Fixture -Action "create" -RunId $runId -FixtureRel $fixtureRel | ForEach-Object { Write-Host $_ }
  $fixtureCreated = $true

  $fixture = [System.IO.File]::ReadAllText($fixturePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $requester = $fixture.users.requester
  $helper = $fixture.users.helper
  $outsider = $fixture.users.outsider
  $requesterHeaders = @{ Authorization = [string] $requester.auth }
  $requesterAgentHeaders = @{ Authorization = [string] $requester.agentAuth }
  $helperHeaders = @{ Authorization = [string] $helper.auth }
  $helperAgentHeaders = @{ Authorization = [string] $helper.agentAuth }
  $outsiderHeaders = @{ Authorization = [string] $outsider.auth }

  Write-Host "Requester user id: $($requester.id)"
  Write-Host "Helper user id: $($helper.id)"
  Write-Host "Outsider user id: $($outsider.id)"
  Write-Host ""

  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $false

  $disabledHelpBody = @{
    data = @{
      type = "nexus-help-requests"
      attributes = @{
        userConfirmed = $true
        title = "Nexus disabled matching smoke $runId"
        summary = "This confirmed write should be rejected because allowAgentMatching is false."
        content = "This confirmed write should be rejected because allowAgentMatching is false."
        categoryLabel = "help"
        neededLabels = @("computer-repair")
        urgency = "normal"
        meetingSafetyState = "public_place_suggested"
      }
    }
  }

  Assert-Status "requester local agent cannot create help request when allowAgentMatching is false" "POST" "/api/nexus/help-requests" @(422) $requesterAgentHeaders $disabledHelpBody | Out-Null

  $requesterSoulMd = "Requester smoke soul $runId. This private profile text should not appear in action-log summaries."
  $helperSoulMd = "Helper smoke soul $runId. This private profile text should not appear in action-log summaries."

  foreach ($profileTarget in @(
    @{
      Name = "requester"
      Headers = $requesterHeaders
      AgentName = "Requester Smoke Agent"
      SoulMd = $requesterSoulMd
      SkillTags = @("requester-coordination")
      HelpTags = @("safe-meetup")
      AllowAgentPosting = $true
      AllowAgentReplying = $true
    },
    @{
      Name = "helper"
      Headers = $helperHeaders
      AgentName = "Helper Smoke Agent"
      SoulMd = $helperSoulMd
      SkillTags = @($label, "computer-repair")
      HelpTags = @($label)
      AllowAgentPosting = $false
      AllowAgentReplying = $false
    }
  )) {
    $agentProfileBody = @{
      data = @{
        type = "nexus-agent-profiles"
        attributes = @{
          userConfirmed = $true
          agentName = $profileTarget.AgentName
          soulMd = $profileTarget.SoulMd
          interestTags = @("nexus-core-flow", "campus-help")
          skillTags = @($profileTarget.SkillTags)
          helpTags = @($profileTarget.HelpTags)
          matchPreferences = @{
            preferPublicMeetingPlaces = $true
            maxServiceRadiusM = 5000
            smokeRunId = $runId
          }
          permissions = @{
            allowAgentPosting = [bool] $profileTarget.AllowAgentPosting
            allowAgentReplying = [bool] $profileTarget.AllowAgentReplying
            allowAgentMatching = $true
            allowLocationMatching = $false
            locationVisibility = "off"
          }
        }
      }
    }

    $agentProfileResponse = Assert-Status "$($profileTarget.Name) sets agent profile" "PATCH" "/api/nexus/me/agent-profile" @(200) $profileTarget.Headers $agentProfileBody
    $agentProfileJson = ConvertFrom-NexusJson "$($profileTarget.Name) agent profile response parses" $agentProfileResponse.Content
    Require-True "$($profileTarget.Name) agent profile type" ($agentProfileJson.data.type -eq "nexus-agent-profiles") "type=$($agentProfileJson.data.type)"
    Require-True "$($profileTarget.Name) agent profile soulMd round trips" ($agentProfileJson.data.attributes.soulMd -eq $profileTarget.SoulMd) "profile=$($profileTarget.Name)"
    Require-True "$($profileTarget.Name) agent profile allows matching" ($agentProfileJson.data.attributes.permissions.allowAgentMatching -eq $true) "profile=$($profileTarget.Name)"
  }

  $gatewayTitle = "Nexus gateway core flow smoke $runId"
  $gatewayDiscussionContent = "Gateway smoke discussion body $runId. This should only appear in public forum content, not in sanitized action-log summaries."
  $gatewayReplyContent = "Gateway smoke reply body $runId. This should only appear in public forum content, not in sanitized action-log summaries."
  $gatewayEditedReplyContent = "Gateway smoke edited reply body $runId. This should only appear in public forum content, not in sanitized action-log summaries."

  $unconfirmedGatewayDiscussionBody = @{
    data = @{
      type = "discussions"
      attributes = @{
        userConfirmed = $false
        title = $gatewayTitle
        content = $gatewayDiscussionContent
        tags = @("team")
      }
    }
  }
  Assert-Status "forum gateway rejects unconfirmed discussion" "POST" "/api/nexus/forum/discussions" @(422) $requesterHeaders $unconfirmedGatewayDiscussionBody | Out-Null
  Assert-Status "Nexus agent token cannot bypass gateway with raw Flarum discussion write" "POST" "/api/discussions" @(403) $requesterAgentHeaders $unconfirmedGatewayDiscussionBody | Out-Null
  Assert-Status "helper Nexus agent token cannot bypass gateway with raw Flarum discussion write" "POST" "/api/discussions" @(403) $helperAgentHeaders $unconfirmedGatewayDiscussionBody | Out-Null

  $confirmedGatewayDiscussionBody = @{
    data = @{
      type = "discussions"
      attributes = @{
        userConfirmed = $true
        title = $gatewayTitle
        content = $gatewayDiscussionContent
        tags = @("team")
      }
    }
  }
  $gatewayDiscussionResponse = Assert-Status "forum gateway creates discussion with Nexus agent token" "POST" "/api/nexus/forum/discussions?include=firstPost,tags" @(201) $requesterAgentHeaders $confirmedGatewayDiscussionBody
  $gatewayDiscussionJson = ConvertFrom-NexusJson "gateway discussion response parses" $gatewayDiscussionResponse.Content
  $gatewayDiscussionId = [int] $gatewayDiscussionJson.data.id
  $gatewayFirstPostId = [int] $gatewayDiscussionJson.data.relationships.firstPost.data.id
  Require-True "gateway discussion has ids" ($gatewayDiscussionId -gt 0 -and $gatewayFirstPostId -gt 0) "discussionId=$gatewayDiscussionId firstPostId=$gatewayFirstPostId"
  Require-True "gateway discussion title round trips" ($gatewayDiscussionJson.data.attributes.title -eq $gatewayTitle) "title=$($gatewayDiscussionJson.data.attributes.title)"

  $unconfirmedGatewayReplyBody = @{
    data = @{
      type = "posts"
      attributes = @{
        userConfirmed = $false
        content = $gatewayReplyContent
      }
    }
  }
  Assert-Status "forum gateway rejects unconfirmed reply" "POST" "/api/nexus/forum/discussions/$gatewayDiscussionId/posts" @(422) $requesterHeaders $unconfirmedGatewayReplyBody | Out-Null

  $confirmedGatewayReplyBody = @{
    data = @{
      type = "posts"
      attributes = @{
        userConfirmed = $true
        content = $gatewayReplyContent
      }
    }
  }
  Assert-Status "Nexus agent token cannot bypass gateway with raw Flarum reply write" "POST" "/api/posts" @(403) $requesterAgentHeaders $confirmedGatewayReplyBody | Out-Null
  Assert-Status "helper Nexus agent token cannot bypass gateway with raw Flarum reply write" "POST" "/api/posts" @(403) $helperAgentHeaders $confirmedGatewayReplyBody | Out-Null

  $gatewayReplyResponse = Assert-Status "forum gateway creates reply with Nexus agent token" "POST" "/api/nexus/forum/discussions/$gatewayDiscussionId/posts" @(201) $requesterAgentHeaders $confirmedGatewayReplyBody
  $gatewayReplyJson = ConvertFrom-NexusJson "gateway reply response parses" $gatewayReplyResponse.Content
  $gatewayReplyPostId = [int] $gatewayReplyJson.data.id
  Require-True "gateway reply has id" ($gatewayReplyPostId -gt 0) "postId=$gatewayReplyPostId"

  $myForumDiscussionsResponse = Assert-Status "requester lists own forum discussions" "GET" "/api/nexus/me/discussions?page%5Blimit%5D=10&include=firstPost,tags" @(200) $requesterHeaders
  $myForumDiscussionsJson = ConvertFrom-NexusJson "my forum discussions response parses" $myForumDiscussionsResponse.Content
  $myForumDiscussions = As-Array $myForumDiscussionsJson.data
  $myGatewayDiscussion = @($myForumDiscussions | Where-Object { [int] $_.id -eq $gatewayDiscussionId -and $_.attributes.title -eq $gatewayTitle } | Select-Object -First 1)
  Require-True "own forum discussions include gateway discussion" ($myGatewayDiscussion.Count -eq 1) "discussionId=$gatewayDiscussionId"

  $myForumPostsResponse = Assert-Status "requester lists own forum posts" "GET" "/api/nexus/me/posts?page%5Blimit%5D=20" @(200) $requesterHeaders
  $myForumPostsJson = ConvertFrom-NexusJson "my forum posts response parses" $myForumPostsResponse.Content
  $myForumPosts = As-Array $myForumPostsJson.data
  $myGatewayReply = @($myForumPosts | Where-Object { [int] $_.id -eq $gatewayReplyPostId } | Select-Object -First 1)
  Require-True "own forum posts include gateway reply" ($myGatewayReply.Count -eq 1) "postId=$gatewayReplyPostId"

  $gatewayEditBody = @{
    data = @{
      type = "posts"
      attributes = @{
        userConfirmed = $true
        content = $gatewayEditedReplyContent
      }
    }
  }
  Assert-Status "Nexus agent token cannot bypass gateway with raw Flarum post edit" "PATCH" "/api/posts/$gatewayReplyPostId" @(403) $requesterAgentHeaders $gatewayEditBody | Out-Null

  $gatewayEditResponse = Assert-Status "forum gateway edits own reply with Nexus agent token" "PATCH" "/api/nexus/forum/posts/$gatewayReplyPostId" @(200) $requesterAgentHeaders $gatewayEditBody
  $gatewayEditJson = ConvertFrom-NexusJson "gateway edit response parses" $gatewayEditResponse.Content
  Require-True "gateway edit returns same post" ([int] $gatewayEditJson.data.id -eq $gatewayReplyPostId) "postId=$gatewayReplyPostId"

  $gatewayDeleteBody = @{
    data = @{
      type = "posts"
      attributes = @{
        userConfirmed = $true
        reason = "core-flow smoke cleanup"
      }
    }
  }
  Assert-Status "Nexus agent token cannot bypass gateway with raw Flarum post delete" "DELETE" "/api/posts/$gatewayReplyPostId" @(403) $requesterAgentHeaders $gatewayDeleteBody | Out-Null

  Assert-Status "forum gateway hides own reply with Nexus agent token" "DELETE" "/api/nexus/forum/posts/$gatewayReplyPostId" @(204) $requesterAgentHeaders $gatewayDeleteBody | Out-Null

  $capabilityBody = @{
    data = @{
      type = "nexus-user-capabilities"
      attributes = @{
        userConfirmed = $true
        capabilities = @(
          @{
            label = $label
            name = "Smoke campus repair helper"
            summary = "Temporary helper capability for Nexus core-flow smoke $runId."
            availability = "smoke-test-only"
            serviceRadiusM = 5000
            isActive = $true
          }
        )
      }
    }
  }

  $capabilityResponse = Assert-Status "helper local agent publishes capability label" "PATCH" "/api/nexus/me/capabilities" @(200) $helperAgentHeaders $capabilityBody
  $capabilityJson = ConvertFrom-NexusJson "capability response parses" $capabilityResponse.Content
  $capabilities = As-Array $capabilityJson.data
  $hasCapability = @($capabilities | Where-Object { $_.attributes.label -eq $label }).Count -gt 0
  Require-True "helper capability returned" $hasCapability "label=$label"

  $labelDirectoryResponse = Assert-Status "public capability label directory searches helper label" "GET" "/api/nexus/capability-labels?inname=$label&page%5Blimit%5D=10" @(200)
  $labelDirectoryJson = ConvertFrom-NexusJson "capability label directory parses" $labelDirectoryResponse.Content
  $labelDirectoryItems = As-Array $labelDirectoryJson.data
  $labelDirectoryItem = @($labelDirectoryItems | Where-Object { $_.attributes.label -eq $label -and [int] $_.attributes.helperCount -ge 1 } | Select-Object -First 1)
  Require-True "capability label directory includes helper label" ($labelDirectoryItem.Count -eq 1) "label=$label"
  $labelDirectoryAttrs = $labelDirectoryItem[0].attributes
  Require-True "capability label directory has reuseGuidance" ($null -ne $labelDirectoryAttrs.reuseGuidance -and $labelDirectoryAttrs.reuseGuidance.recommendedForReuse -eq $true -and $labelDirectoryAttrs.reuseGuidance.normalizedLabel -eq $label) "label=$label helperCount=$($labelDirectoryAttrs.helperCount)"
  $labelDirectoryActions = As-Array $labelDirectoryAttrs.nextActions
  $labelDirectoryActionNames = @($labelDirectoryActions | ForEach-Object { [string] $_.name })
  Require-True "capability label nextActions include helper search" ($labelDirectoryActionNames -contains "find_helpers_with_label") "actions=$($labelDirectoryActionNames -join ",")"
  $useLabelAction = @($labelDirectoryActions | Where-Object { [string] $_.name -eq "use_label_for_help_request" } | Select-Object -First 1)
  Require-True "capability label nextActions include confirmed help body" ($useLabelAction.Count -eq 1 -and $useLabelAction[0].catalogAction -eq "help_request.create" -and $useLabelAction[0].bodyTemplate.data.attributes.neededLabels[0] -eq $label) "catalogAction=$($useLabelAction[0].catalogAction)"

  $needDraftBody = @{
    data = @{
      type = "nexus-need-drafts"
      attributes = @{
        rawUserNeed = "I am at the public campus library desk and my laptop will not boot. I need nearby computer repair help for Nexus core flow smoke $runId."
        intent = "auto"
        locationHint = "Public campus library desk"
      }
    }
  }

  $needDraftResponse = Assert-Status "requester local agent drafts raw need" "POST" "/api/nexus/need-drafts" @(200) $requesterAgentHeaders $needDraftBody
  $needDraftJson = ConvertFrom-NexusJson "need draft response parses" $needDraftResponse.Content
  $needDraftAttrs = $needDraftJson.data.attributes
  Require-True "need draft has type" ($needDraftJson.data.type -eq "nexus-need-drafts") "type=$($needDraftJson.data.type)"
  Require-True "need draft classifies help" ($needDraftAttrs.intent -eq "help") "intent=$($needDraftAttrs.intent)"
  Require-True "need draft points to help request publish" ($needDraftAttrs.publish.endpoint -eq "POST /api/nexus/help-requests") "endpoint=$($needDraftAttrs.publish.endpoint)"
  Require-True "need draft publish body starts unconfirmed" ($needDraftAttrs.publish.body.data.attributes.userConfirmed -eq $false) "userConfirmed=false"
  Require-True "need draft has read-only labelReuse" ($needDraftAttrs.labelReuse.readOnly -eq $true) "readOnly=$($needDraftAttrs.labelReuse.readOnly)"
  $draftLabelReuseSearches = As-Array $needDraftAttrs.labelReuse.searches
  $draftComputerRepairReuse = @($draftLabelReuseSearches | Where-Object { [string] $_.label -eq "computer-repair" } | Select-Object -First 1)
  Require-True "need draft labelReuse searches proposed label" ($draftComputerRepairReuse.Count -eq 1 -and $draftComputerRepairReuse[0].endpoint -eq "/api/nexus/capability-labels" -and $draftComputerRepairReuse[0].query.inname -eq "computer-repair" -and $draftComputerRepairReuse[0].writesState -eq $false) "labelReuseSearches=$($draftLabelReuseSearches.Count)"
  Require-True "need draft has read-only discoveryPlan" ($needDraftAttrs.discoveryPlan.readOnly -eq $true) "readOnly=$($needDraftAttrs.discoveryPlan.readOnly)"
  $draftDiscoverySteps = As-Array $needDraftAttrs.discoveryPlan.steps
  $draftDiscoveryEndpoints = @($draftDiscoverySteps | ForEach-Object { [string] $_.endpoint })
  Require-True "need draft discoveryPlan includes labels and forum search" (($draftDiscoveryEndpoints -contains "/api/nexus/capability-labels") -and ($draftDiscoveryEndpoints -contains "/api/nexus/forum/discussions")) "endpoints=$($draftDiscoveryEndpoints -join ",")"
  $draftReuseStep = @($draftDiscoverySteps | Where-Object { [string] $_.name -eq "reuse_existing_labels" } | Select-Object -First 1)
  Require-True "need draft discoveryPlan has concrete label reuse step" ($draftReuseStep.Count -eq 1 -and $draftReuseStep[0].endpoint -eq "/api/nexus/capability-labels" -and $draftReuseStep[0].query.sort -eq "popular" -and $draftReuseStep[0].requiredBeforePublish -eq $true -and $draftReuseStep[0].writesState -eq $false) "endpoint=$($draftReuseStep[0].endpoint)"

  $draftLabels = As-Array $needDraftAttrs.neededLabels
  Require-True "need draft suggests computer repair" ($draftLabels -contains "computer-repair") "labels=$($draftLabels -join ",")"

  $draftedNeededLabels = @($draftLabels + $label | Select-Object -Unique)
  $helpBody = $needDraftAttrs.publish.body
  $helpBody.data.attributes.userConfirmed = $true
  $helpBody.data.attributes.title = "Nexus core flow smoke $runId"
  $helpBody.data.attributes.summary = "Temporary real-world help request for core-flow smoke $runId."
  $helpBody.data.attributes.content = "This temporary request verifies requester agent to helper agent dispatch, match, and private coordination. Drafted from raw user need: $($needDraftAttrs.summary)"
  $helpBody.data.attributes.categoryLabel = "help"
  $helpBody.data.attributes.neededLabels = $draftedNeededLabels
  $helpBody.data.attributes.urgency = "soon"
  $helpBody.data.attributes.locationHint = "Public campus library desk"
  $helpBody.data.attributes.meetingSafetyState = "public_place_suggested"
  $helpBody.data.attributes.agentContext = @{
    smoke = $true
    runId = $runId
    script = "scripts/nexus-core-flow-smoke.ps1"
    draftedBy = "POST /api/nexus/need-drafts"
  }

  $helpResponse = Assert-Status "requester local agent creates help request" "POST" "/api/nexus/help-requests" @(201) $requesterAgentHeaders $helpBody
  $helpJson = ConvertFrom-NexusJson "help request response parses" $helpResponse.Content
  $helpRequestId = [int] $helpJson.data.id
  $discussionId = [int] $helpJson.data.attributes.discussionId
  Require-True "help request has ids" ($helpRequestId -gt 0 -and $discussionId -gt 0) "helpRequestId=$helpRequestId discussionId=$discussionId"
  $helpNextActions = As-Array $helpJson.data.attributes.nextActions
  $helpNextActionNames = @($helpNextActions | ForEach-Object { [string] $_.name })
  Require-True "help request nextActions include candidate search" ($helpNextActionNames -contains "find_candidates") "nextActions=$($helpNextActionNames -join ",")"
  Require-True "help request nextActions include match preflight" ($helpNextActionNames -contains "preflight_match_offer") "nextActions=$($helpNextActionNames -join ",")"
  Require-True "help request nextActions include offer match" ($helpNextActionNames -contains "offer_match") "nextActions=$($helpNextActionNames -join ",")"
  $offerMatchPreflightAction = @($helpNextActions | Where-Object { [string] $_.name -eq "preflight_match_offer" } | Select-Object -First 1)
  Require-True "help request standalone match offer preflight targets request" ([int] $offerMatchPreflightAction[0].body.data.attributes.target.id -eq $helpRequestId) "targetId=$($offerMatchPreflightAction[0].body.data.attributes.target.id)"
  $offerMatchAction = @($helpNextActions | Where-Object { [string] $_.name -eq "offer_match" } | Select-Object -First 1)
  Require-True "help request offer action targets match endpoint" ([string] $offerMatchAction[0].endpoint -eq "/api/nexus/help-requests/$helpRequestId/matches") "endpoint=$($offerMatchAction[0].endpoint)"
  Assert-RichNextAction "help request offer action" $offerMatchAction[0] "match.offer" "#/components/schemas/MatchInput" "createsMatchOffer"
  Assert-RichNextAction "help request offer preflight action" $offerMatchPreflightAction[0] "match.offer" "#/components/schemas/MatchInput" "createsMatchOffer"

  Assert-Status "public help request list rejects coordination includes" "GET" "/api/nexus/help-requests?include=matches,dispatches" @(400,422) | Out-Null
  Assert-Status "public help request show rejects coordination includes" "GET" "/api/nexus/help-requests/${helpRequestId}?include=matches,matches.helper,dispatches,dispatches.helper" @(400,422) | Out-Null

  $myHelpRequestsResponse = Assert-Status "requester local agent lists own help requests" "GET" "/api/nexus/me/help-requests?page%5Blimit%5D=10&include=discussion,matches,matches.helper,dispatches,dispatches.helper" @(200) $requesterAgentHeaders
  $myHelpRequestsJson = ConvertFrom-NexusJson "my help requests response parses" $myHelpRequestsResponse.Content
  $myHelpRequests = As-Array $myHelpRequestsJson.data
  $myHelpRequest = @($myHelpRequests | Where-Object { [int] $_.id -eq $helpRequestId -and [int] $_.attributes.discussionId -eq $discussionId } | Select-Object -First 1)
  Require-True "own help requests include created request" ($myHelpRequest.Count -eq 1) "helpRequestId=$helpRequestId"

  $requesterOpenWorkResponse = Assert-Status "requester local agent work queue lists open request" "GET" "/api/nexus/me/work-items?filter%5Brole%5D=requester&filter%5Bkind%5D=help_request&page%5Blimit%5D=20" @(200) $requesterAgentHeaders
  $requesterOpenWorkJson = ConvertFrom-NexusJson "requester open work queue parses" $requesterOpenWorkResponse.Content
  $requesterOpenWorkItems = As-Array $requesterOpenWorkJson.data
  $requesterOpenWork = @($requesterOpenWorkItems | Where-Object { $_.attributes.kind -eq "help_request" -and [int] $_.attributes.helpRequestId -eq $helpRequestId -and $_.attributes.action -eq "route_help_request" } | Select-Object -First 1)
  Require-True "requester work queue includes open request" ($requesterOpenWork.Count -eq 1) "helpRequestId=$helpRequestId"
  $requesterOpenWorkNextActions = As-Array $requesterOpenWork[0].attributes.nextActions
  $requesterOpenWorkNextActionNames = @($requesterOpenWorkNextActions | ForEach-Object { [string] $_.name })
  Require-True "requester work item includes dispatch preflight" ($requesterOpenWorkNextActionNames -contains "preflight_dispatch") "nextActions=$($requesterOpenWorkNextActionNames -join ",")"
  Require-True "requester work item includes dispatch template" ($requesterOpenWorkNextActionNames -contains "create_dispatch") "nextActions=$($requesterOpenWorkNextActionNames -join ",")"
  $requesterOpenWorkPreflight = @($requesterOpenWorkNextActions | Where-Object { [string] $_.name -eq "preflight_dispatch" } | Select-Object -First 1)
  Require-True "requester work item dispatch preflight targets request" ([int] $requesterOpenWorkPreflight[0].body.data.attributes.target.id -eq $helpRequestId) "targetId=$($requesterOpenWorkPreflight[0].body.data.attributes.target.id)"
  $requesterOpenWorkCreateDispatch = @($requesterOpenWorkNextActions | Where-Object { [string] $_.name -eq "create_dispatch" } | Select-Object -First 1)
  Require-True "requester work item create dispatch has body template" ([string] $requesterOpenWorkCreateDispatch[0].bodyTemplate.data.type -eq "nexus-help-dispatches") "type=$($requesterOpenWorkCreateDispatch[0].bodyTemplate.data.type)"
  Require-True "requester work item create dispatch has preflight template" ([int] $requesterOpenWorkCreateDispatch[0].preflight.body.data.attributes.target.id -eq $helpRequestId) "targetId=$($requesterOpenWorkCreateDispatch[0].preflight.body.data.attributes.target.id)"
  Assert-RichNextAction "requester work item dispatch preflight" $requesterOpenWorkPreflight[0] "dispatch.create" "#/components/schemas/HelpDispatchInput" "createsDispatch"
  Assert-RichNextAction "requester work item create dispatch" $requesterOpenWorkCreateDispatch[0] "dispatch.create" "#/components/schemas/HelpDispatchInput" "createsDispatch"

  $candidateResponse = Assert-Status "requester local agent lists candidates" "GET" "/api/nexus/help-requests/$helpRequestId/candidates" @(200) $requesterAgentHeaders
  $candidateJson = ConvertFrom-NexusJson "candidate response parses" $candidateResponse.Content
  $candidates = As-Array $candidateJson.data
  $candidate = @($candidates | Where-Object { [int] $_.attributes.userId -eq [int] $helper.id } | Select-Object -First 1)
  Require-True "candidate includes helper" ($candidate.Count -eq 1) "helperUserId=$($helper.id)"
  $candidateAttrs = $candidate[0].attributes
  $candidateLabels = As-Array $candidateAttrs.matchedLabels
  Require-True "candidate matched label" ($candidateLabels -contains $label) "matchedLabels=$($candidateLabels -join ",")"
  $candidateNeededLabels = As-Array $candidateAttrs.neededLabels
  Require-True "candidate explainability includes needed labels" (($candidateNeededLabels -contains $label) -and ($candidateNeededLabels -contains "computer-repair")) "neededLabels=$($candidateNeededLabels -join ",")"
  $candidateMissingLabels = As-Array $candidateAttrs.missingLabels
  Require-True "candidate explainability includes missing label" ($candidateMissingLabels -contains "computer-repair") "missingLabels=$($candidateMissingLabels -join ",")"
  Require-True "candidate scoreBreakdown counts matched labels" ([int] $candidateAttrs.scoreBreakdown.matchedLabelCount -ge 1 -and [int] $candidateAttrs.scoreBreakdown.neededLabelCount -ge 2 -and [int] $candidateAttrs.scoreBreakdown.missingLabelCount -ge 1) "breakdown=$($candidateAttrs.scoreBreakdown | ConvertTo-Json -Depth 8 -Compress)"
  Require-True "candidate scoreBreakdown explains rank" ([string] $candidateAttrs.scoreBreakdown.rankReason -like "*$label*") "rankReason=$($candidateAttrs.scoreBreakdown.rankReason)"
  Require-True "candidate recommendation is dispatchable" ($candidateAttrs.recommendation.recommended -eq $true -and [string] $candidateAttrs.recommendation.nextBestAction -eq "preflight_dispatch") "recommended=$($candidateAttrs.recommendation.recommended) nextBestAction=$($candidateAttrs.recommendation.nextBestAction)"
  $candidateRecommendationCaveats = As-Array $candidateAttrs.recommendation.caveats
  Require-True "candidate recommendation caveats mention missing label" (($candidateRecommendationCaveats -join " ") -like "*computer-repair*") "caveats=$($candidateRecommendationCaveats -join " | ")"
  Require-True "candidate dispatch rationale template is reusable" ([string] $candidateAttrs.dispatchRationaleTemplate -like "*#$label*" -and [string] $candidateAttrs.dispatchRationaleTemplate -like "*computer-repair*") "dispatchRationaleTemplate=$($candidateAttrs.dispatchRationaleTemplate)"
  $candidateMustShowFields = As-Array $candidateAttrs.confirmationPromptHints.mustShowFields
  Require-True "candidate confirmation hints require showing safety fields" ($candidateAttrs.confirmationPromptHints.requiresUserConfirmation -eq $true -and ($candidateMustShowFields -contains "helperUserId") -and ($candidateMustShowFields -contains "missingLabels") -and ($candidateMustShowFields -contains "sideEffects")) "mustShowFields=$($candidateMustShowFields -join ",")"
  $candidateCapabilities = As-Array $candidateAttrs.capabilities
  $matchedCapability = @($candidateCapabilities | Where-Object { [string] $_.label -eq $label -and $_.isMatched -eq $true } | Select-Object -First 1)
  Require-True "candidate capabilities mark matched label" ($matchedCapability.Count -eq 1) "capabilities=$($candidateCapabilities.Count)"
  $candidateNextActions = As-Array $candidateAttrs.nextActions
  $candidateNextActionNames = @($candidateNextActions | ForEach-Object { [string] $_.name })
  Require-True "candidate nextActions include dispatch preflight" ($candidateNextActionNames -contains "preflight_dispatch") "nextActions=$($candidateNextActionNames -join ",")"
  Require-True "candidate nextActions include create dispatch" ($candidateNextActionNames -contains "create_dispatch") "nextActions=$($candidateNextActionNames -join ",")"
  $createDispatchAction = @($candidateNextActions | Where-Object { [string] $_.name -eq "create_dispatch" } | Select-Object -First 1)
  Require-True "candidate create dispatch action targets helper" ([int] $createDispatchAction[0].bodyTemplate.data.attributes.helperUserId -eq [int] $helper.id) "helperUserId=$($createDispatchAction[0].bodyTemplate.data.attributes.helperUserId)"
  $candidatePreflightAction = @($candidateNextActions | Where-Object { [string] $_.name -eq "preflight_dispatch" } | Select-Object -First 1)
  Require-True "candidate preflight action includes target help request" ([int] $candidatePreflightAction[0].body.data.attributes.target.id -eq $helpRequestId) "targetId=$($candidatePreflightAction[0].body.data.attributes.target.id)"
  Require-True "candidate preflight action includes helper target" ([int] $candidatePreflightAction[0].body.data.attributes.target.helperUserId -eq [int] $helper.id) "helperUserId=$($candidatePreflightAction[0].body.data.attributes.target.helperUserId)"
  Require-True "candidate create dispatch action endpoint targets request" ([string] $createDispatchAction[0].endpoint -eq "/api/nexus/help-requests/$helpRequestId/dispatches") "endpoint=$($createDispatchAction[0].endpoint)"
  Require-True "candidate create dispatch action has target preflight" ([int] $createDispatchAction[0].preflight.body.data.attributes.target.id -eq $helpRequestId -and [int] $createDispatchAction[0].preflight.body.data.attributes.target.helperUserId -eq [int] $helper.id) "targetId=$($createDispatchAction[0].preflight.body.data.attributes.target.id) helperUserId=$($createDispatchAction[0].preflight.body.data.attributes.target.helperUserId)"
  Assert-RichNextAction "candidate dispatch preflight" $candidatePreflightAction[0] "dispatch.create" "#/components/schemas/HelpDispatchInput" "createsDispatch"
  Assert-RichNextAction "candidate create dispatch" $createDispatchAction[0] "dispatch.create" "#/components/schemas/HelpDispatchInput" "createsDispatch"
  $targetDispatchCreatePreflight = Assert-Status "requester local agent target-preflights dispatch create" "POST" "/api/nexus/agent-preflight" @(200) $requesterAgentHeaders $candidatePreflightAction[0].body
  $targetDispatchCreateJson = ConvertFrom-NexusJson "target dispatch create preflight parses" $targetDispatchCreatePreflight.Content
  Require-True "dispatch create preflight sees requester role" ($targetDispatchCreateJson.data.attributes.target.viewerRole -eq "requester") "viewerRole=$($targetDispatchCreateJson.data.attributes.target.viewerRole)"
  Require-True "dispatch create preflight sees open request" (($targetDispatchCreateJson.data.attributes.target.status -eq "open") -or ($targetDispatchCreateJson.data.attributes.target.status -eq "matching")) "status=$($targetDispatchCreateJson.data.attributes.target.status)"
  $targetDispatchCreateActionPreflight = Assert-Status "requester local agent target-preflights dispatch create action" "POST" "/api/nexus/agent-preflight" @(200) $requesterAgentHeaders $createDispatchAction[0].preflight.body
  $targetDispatchCreateActionJson = ConvertFrom-NexusJson "target dispatch create action preflight parses" $targetDispatchCreateActionPreflight.Content
  Require-True "dispatch create action preflight sees helper target" ([int] $targetDispatchCreateActionJson.data.attributes.target.helperUserId -eq [int] $helper.id) "helperUserId=$($targetDispatchCreateActionJson.data.attributes.target.helperUserId)"

  $disabledHelpUpdateBody = @{
    data = @{
      type = "nexus-help-requests"
      attributes = @{
        userConfirmed = $true
        meetingSafetyState = "public_place_confirmed"
      }
    }
  }

  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $false
  Assert-Status "requester local agent cannot update help request when allowAgentMatching is false" "PATCH" "/api/nexus/help-requests/$helpRequestId" @(422) $requesterAgentHeaders $disabledHelpUpdateBody | Out-Null

  $dispatchBody = Copy-NexusJsonObject $createDispatchAction[0].bodyTemplate
  $dispatchBody.data.attributes.userConfirmed = $true
  $dispatchBody.data.attributes.message = "Can you help with smoke request $runId?"
  $dispatchBody.data.attributes.rationale = [string] $candidateAttrs.dispatchRationaleTemplate
  $dispatchBody.data.attributes.meetingHint = "Public campus library desk"
  $dispatchBody.data.attributes.meetingSafetyState = "public_place_suggested"
  $dispatchEndpoint = [string] $createDispatchAction[0].endpoint
  Require-True "local agent dispatch body comes from candidate nextAction" ([string] $dispatchBody.data.type -eq "nexus-help-dispatches" -and [int] $dispatchBody.data.attributes.helperUserId -eq [int] $helper.id -and [string] $dispatchBody.data.attributes.rationale -eq [string] $candidateAttrs.dispatchRationaleTemplate) "endpoint=$dispatchEndpoint helperUserId=$($dispatchBody.data.attributes.helperUserId)"

  Assert-Status "requester local agent cannot dispatch when allowAgentMatching is false" "POST" $dispatchEndpoint @(422) $requesterAgentHeaders $dispatchBody | Out-Null
  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $true

  $dispatchResponse = Assert-Status "requester local agent dispatches to helper from candidate nextAction" "POST" $dispatchEndpoint @(201) $requesterAgentHeaders $dispatchBody
  $dispatchJson = ConvertFrom-NexusJson "dispatch response parses" $dispatchResponse.Content
  $dispatchId = [int] $dispatchJson.data.id
  Require-True "dispatch is pending" ($dispatchId -gt 0 -and $dispatchJson.data.attributes.status -eq "pending") "dispatchId=$dispatchId"
  Require-True "requester dispatch response has viewer role" ($dispatchJson.data.attributes.viewerRole -eq "requester") "viewerRole=$($dispatchJson.data.attributes.viewerRole)"
  $requesterDispatchNextActions = As-Array $dispatchJson.data.attributes.nextActions
  $requesterDispatchNextActionNames = @($requesterDispatchNextActions | ForEach-Object { [string] $_.name })
  Require-True "requester dispatch nextActions include cancel preflight" ($requesterDispatchNextActionNames -contains "preflight_dispatch_cancel") "nextActions=$($requesterDispatchNextActionNames -join ",")"
  Require-True "requester dispatch nextActions include cancel dispatch" ($requesterDispatchNextActionNames -contains "cancel_dispatch") "nextActions=$($requesterDispatchNextActionNames -join ",")"

  $outsiderDispatchResponse = Assert-Status "outsider sees no dispatches for request" "GET" "/api/nexus/help-requests/$helpRequestId/dispatches" @(200) $outsiderHeaders
  $outsiderDispatchJson = ConvertFrom-NexusJson "outsider dispatch response parses" $outsiderDispatchResponse.Content
  $outsiderDispatches = As-Array $outsiderDispatchJson.data
  $outsiderDispatch = @($outsiderDispatches | Where-Object { [int] $_.id -eq $dispatchId } | Select-Object -First 1)
  Require-True "outsider dispatch list excludes private dispatch" ($outsiderDispatch.Count -eq 0) "dispatchId=$dispatchId"

  $myDispatchResponse = Assert-Status "helper local agent polls pending dispatches" "GET" "/api/nexus/me/dispatches?filter%5Bstatus%5D=pending" @(200) $helperAgentHeaders
  $myDispatchJson = ConvertFrom-NexusJson "my dispatch response parses" $myDispatchResponse.Content
  $pendingDispatches = As-Array $myDispatchJson.data
  $pendingDispatch = @($pendingDispatches | Where-Object { [int] $_.id -eq $dispatchId } | Select-Object -First 1)
  Require-True "pending dispatch visible to helper" ($pendingDispatch.Count -eq 1) "dispatchId=$dispatchId"
  Require-True "helper dispatch response has viewer role" ($pendingDispatch[0].attributes.viewerRole -eq "helper") "viewerRole=$($pendingDispatch[0].attributes.viewerRole)"
  $helperDispatchNextActions = As-Array $pendingDispatch[0].attributes.nextActions
  $helperDispatchNextActionNames = @($helperDispatchNextActions | ForEach-Object { [string] $_.name })
  Require-True "helper dispatch nextActions include response preflight" ($helperDispatchNextActionNames -contains "preflight_dispatch_response") "nextActions=$($helperDispatchNextActionNames -join ",")"
  Require-True "helper dispatch nextActions include accept" ($helperDispatchNextActionNames -contains "accept_dispatch") "nextActions=$($helperDispatchNextActionNames -join ",")"
  Require-True "helper dispatch nextActions include decline" ($helperDispatchNextActionNames -contains "decline_dispatch") "nextActions=$($helperDispatchNextActionNames -join ",")"
  $helperDispatchStandalonePreflight = @($helperDispatchNextActions | Where-Object { [string] $_.name -eq "preflight_dispatch_response" } | Select-Object -First 1)
  Require-True "helper dispatch standalone preflight targets dispatch" ([int] $helperDispatchStandalonePreflight[0].body.data.attributes.target.id -eq $dispatchId) "targetId=$($helperDispatchStandalonePreflight[0].body.data.attributes.target.id)"
  $acceptDispatchAction = @($helperDispatchNextActions | Where-Object { [string] $_.name -eq "accept_dispatch" } | Select-Object -First 1)
  Require-True "accept dispatch action has target preflight template" ([int] $acceptDispatchAction[0].preflight.body.data.attributes.target.id -eq $dispatchId) "targetId=$($acceptDispatchAction[0].preflight.body.data.attributes.target.id)"
  Assert-RichNextAction "helper dispatch response preflight" $helperDispatchStandalonePreflight[0] "dispatch.update" "#/components/schemas/HelpDispatchUpdateInput" "updatesDispatch"
  Assert-RichNextAction "helper accept dispatch action" $acceptDispatchAction[0] "dispatch.update" "#/components/schemas/HelpDispatchUpdateInput" "updatesDispatch"
  $targetDispatchAcceptPreflight = Assert-Status "helper local agent target-preflights dispatch accept" "POST" "/api/nexus/agent-preflight" @(200) $helperAgentHeaders $acceptDispatchAction[0].preflight.body
  $targetDispatchAcceptJson = ConvertFrom-NexusJson "target dispatch accept preflight parses" $targetDispatchAcceptPreflight.Content
  Require-True "dispatch accept preflight sees helper role" ($targetDispatchAcceptJson.data.attributes.target.viewerRole -eq "helper") "viewerRole=$($targetDispatchAcceptJson.data.attributes.target.viewerRole)"
  Require-True "dispatch accept preflight sees pending status" ($targetDispatchAcceptJson.data.attributes.target.status -eq "pending") "status=$($targetDispatchAcceptJson.data.attributes.target.status)"
  Require-True "dispatch accept preflight sees proposed accepted" ($targetDispatchAcceptJson.data.attributes.target.proposedStatus -eq "accepted") "proposedStatus=$($targetDispatchAcceptJson.data.attributes.target.proposedStatus)"

  $outsiderDispatchPreflight = Assert-Status "outsider target-preflights dispatch accept" "POST" "/api/nexus/agent-preflight" @(200) $outsiderHeaders $acceptDispatchAction[0].preflight.body
  $outsiderDispatchPreflightJson = ConvertFrom-NexusJson "outsider dispatch preflight parses" $outsiderDispatchPreflight.Content
  $outsiderDispatchBlocking = As-Array $outsiderDispatchPreflightJson.data.attributes.blocking
  Require-True "outsider dispatch preflight blocks target access" ($outsiderDispatchBlocking -contains "targetAccessible") "blocking=$($outsiderDispatchBlocking -join ",")"

  $helperDispatchWorkResponse = Assert-Status "helper local agent work queue lists pending dispatch" "GET" "/api/nexus/me/work-items?filter%5Brole%5D=helper&filter%5Bkind%5D=dispatch&page%5Blimit%5D=20" @(200) $helperAgentHeaders
  $helperDispatchWorkJson = ConvertFrom-NexusJson "helper dispatch work queue parses" $helperDispatchWorkResponse.Content
  $helperDispatchWorkItems = As-Array $helperDispatchWorkJson.data
  $helperDispatchWork = @($helperDispatchWorkItems | Where-Object { $_.attributes.kind -eq "dispatch" -and [int] $_.attributes.dispatchId -eq $dispatchId -and $_.attributes.action -eq "respond_to_dispatch" } | Select-Object -First 1)
  Require-True "helper work queue includes pending dispatch" ($helperDispatchWork.Count -eq 1) "dispatchId=$dispatchId"
  $helperDispatchWorkNextActions = As-Array $helperDispatchWork[0].attributes.nextActions
  $helperDispatchWorkNextActionNames = @($helperDispatchWorkNextActions | ForEach-Object { [string] $_.name })
  Require-True "helper dispatch work item includes response preflight" ($helperDispatchWorkNextActionNames -contains "preflight_dispatch_response") "nextActions=$($helperDispatchWorkNextActionNames -join ",")"
  Require-True "helper dispatch work item includes accept template" ($helperDispatchWorkNextActionNames -contains "accept_dispatch") "nextActions=$($helperDispatchWorkNextActionNames -join ",")"
  Require-True "helper dispatch work item includes decline template" ($helperDispatchWorkNextActionNames -contains "decline_dispatch") "nextActions=$($helperDispatchWorkNextActionNames -join ",")"
  $helperDispatchWorkPreflight = @($helperDispatchWorkNextActions | Where-Object { [string] $_.name -eq "preflight_dispatch_response" } | Select-Object -First 1)
  Require-True "helper dispatch work item preflight targets dispatch" ([int] $helperDispatchWorkPreflight[0].body.data.attributes.target.id -eq $dispatchId) "targetId=$($helperDispatchWorkPreflight[0].body.data.attributes.target.id)"
  $helperDispatchWorkAccept = @($helperDispatchWorkNextActions | Where-Object { [string] $_.name -eq "accept_dispatch" } | Select-Object -First 1)
  Require-True "helper dispatch work item accept has preflight template" ([int] $helperDispatchWorkAccept[0].preflight.body.data.attributes.target.id -eq $dispatchId) "targetId=$($helperDispatchWorkAccept[0].preflight.body.data.attributes.target.id)"
  Require-True "helper dispatch work item accept has body template" ([string] $helperDispatchWorkAccept[0].bodyTemplate.data.attributes.status -eq "accepted") "status=$($helperDispatchWorkAccept[0].bodyTemplate.data.attributes.status)"
  Assert-RichNextAction "helper dispatch work item accept" $helperDispatchWorkAccept[0] "dispatch.update" "#/components/schemas/HelpDispatchUpdateInput" "updatesDispatch"

  $notificationResponse = Assert-Status "helper local agent sees Flarum notifications" "GET" "/api/notifications" @(200) $helperAgentHeaders
  $notificationJson = ConvertFrom-NexusJson "notification response parses" $notificationResponse.Content
  $notifications = As-Array $notificationJson.data
  $dispatchNotification = @(
    $notifications | Where-Object {
      $_.attributes.contentType -eq "nexusHelpDispatch" -and
      [int] $_.attributes.content.dispatchId -eq $dispatchId
    } | Select-Object -First 1
  )
  Require-True "dispatch notification visible to helper" ($dispatchNotification.Count -eq 1) "contentType=nexusHelpDispatch dispatchId=$dispatchId"

  $acceptBody = @{
    data = @{
      type = "nexus-help-dispatches"
      attributes = @{
        userConfirmed = $true
        status = "accepted"
        responseMessage = "Accepted smoke dispatch $runId."
        meetingHint = "Public campus library desk, front desk area"
        meetingSafetyState = "public_place_confirmed"
      }
    }
  }

  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $false
  Assert-Status "helper local agent cannot accept dispatch when allowAgentMatching is false" "PATCH" "/api/nexus/dispatches/$dispatchId" @(422) $helperAgentHeaders $acceptBody | Out-Null
  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $true

  $acceptResponse = Assert-Status "helper local agent accepts dispatch" "PATCH" "/api/nexus/dispatches/$dispatchId" @(200) $helperAgentHeaders $acceptBody
  $acceptJson = ConvertFrom-NexusJson "accepted dispatch response parses" $acceptResponse.Content
  $matchId = [int] $acceptJson.data.attributes.matchId
  Require-True "accepted dispatch creates match" ($acceptJson.data.attributes.status -eq "accepted" -and $matchId -gt 0) "matchId=$matchId"
  $acceptedDispatchNextActions = As-Array $acceptJson.data.attributes.nextActions
  $acceptedDispatchNextActionNames = @($acceptedDispatchNextActions | ForEach-Object { [string] $_.name })
  Require-True "accepted dispatch nextActions include list match messages" ($acceptedDispatchNextActionNames -contains "list_match_messages") "nextActions=$($acceptedDispatchNextActionNames -join ",")"
  Require-True "accepted dispatch nextActions include send match message" ($acceptedDispatchNextActionNames -contains "send_match_message") "nextActions=$($acceptedDispatchNextActionNames -join ",")"
  $acceptedDispatchSendMessage = @($acceptedDispatchNextActions | Where-Object { [string] $_.name -eq "send_match_message" } | Select-Object -First 1)
  Assert-RichNextAction "accepted dispatch send message action" $acceptedDispatchSendMessage[0] "match_message.create" "#/components/schemas/MatchMessageInput" "createsPrivateMessage"

  $matchesResponse = Assert-Status "requester local agent lists matches" "GET" "/api/nexus/help-requests/$helpRequestId/matches" @(200) $requesterAgentHeaders
  $matchesJson = ConvertFrom-NexusJson "matches response parses" $matchesResponse.Content
  $matches = As-Array $matchesJson.data
  $match = @($matches | Where-Object { [int] $_.id -eq $matchId } | Select-Object -First 1)
  Require-True "accepted match visible to requester" ($match.Count -eq 1 -and $match[0].attributes.status -eq "accepted") "matchId=$matchId"
  Require-True "requester match response has viewer role" ($match[0].attributes.viewerRole -eq "requester") "viewerRole=$($match[0].attributes.viewerRole)"
  $acceptedMatchNextActions = As-Array $match[0].attributes.nextActions
  $acceptedMatchNextActionNames = @($acceptedMatchNextActions | ForEach-Object { [string] $_.name })
  Require-True "accepted match nextActions include list messages" ($acceptedMatchNextActionNames -contains "list_messages") "nextActions=$($acceptedMatchNextActionNames -join ",")"
  Require-True "accepted match nextActions include message preflight" ($acceptedMatchNextActionNames -contains "preflight_match_message") "nextActions=$($acceptedMatchNextActionNames -join ",")"
  Require-True "accepted match nextActions include send message" ($acceptedMatchNextActionNames -contains "send_match_message") "nextActions=$($acceptedMatchNextActionNames -join ",")"
  Require-True "accepted match nextActions include complete match" ($acceptedMatchNextActionNames -contains "complete_match") "nextActions=$($acceptedMatchNextActionNames -join ",")"
  $standaloneMatchMessagePreflight = @($acceptedMatchNextActions | Where-Object { [string] $_.name -eq "preflight_match_message" } | Select-Object -First 1)
  Require-True "accepted match standalone message preflight targets match" ([int] $standaloneMatchMessagePreflight[0].body.data.attributes.target.id -eq $matchId) "targetId=$($standaloneMatchMessagePreflight[0].body.data.attributes.target.id)"
  $sendMatchMessageAction = @($acceptedMatchNextActions | Where-Object { [string] $_.name -eq "send_match_message" } | Select-Object -First 1)
  Assert-RichNextAction "accepted match send message action" $sendMatchMessageAction[0] "match_message.create" "#/components/schemas/MatchMessageInput" "createsPrivateMessage"
  $targetMatchMessagePreflight = Assert-Status "requester local agent target-preflights match message" "POST" "/api/nexus/agent-preflight" @(200) $requesterAgentHeaders $sendMatchMessageAction[0].preflight.body
  $targetMatchMessageJson = ConvertFrom-NexusJson "target match message preflight parses" $targetMatchMessagePreflight.Content
  Require-True "match message preflight sees accepted match" ($targetMatchMessageJson.data.attributes.target.status -eq "accepted") "status=$($targetMatchMessageJson.data.attributes.target.status)"
  Require-True "match message preflight sees requester role" ($targetMatchMessageJson.data.attributes.target.viewerRole -eq "requester") "viewerRole=$($targetMatchMessageJson.data.attributes.target.viewerRole)"

  $outsiderMatchesResponse = Assert-Status "outsider sees no matches for request" "GET" "/api/nexus/help-requests/$helpRequestId/matches" @(200) $outsiderHeaders
  $outsiderMatchesJson = ConvertFrom-NexusJson "outsider matches response parses" $outsiderMatchesResponse.Content
  $outsiderMatches = As-Array $outsiderMatchesJson.data
  $outsiderMatch = @($outsiderMatches | Where-Object { [int] $_.id -eq $matchId } | Select-Object -First 1)
  Require-True "outsider match list excludes private match" ($outsiderMatch.Count -eq 0) "matchId=$matchId"

  $reopenAcceptedMatchBody = @{
    data = @{
      type = "nexus-help-matches"
      attributes = @{
        userConfirmed = $true
        status = "offered"
      }
    }
  }
  Assert-Status "requester local agent cannot move accepted match back to offered" "PATCH" "/api/nexus/matches/$matchId" @(422) $requesterAgentHeaders $reopenAcceptedMatchBody | Out-Null

  foreach ($matchViewer in @(
    @{ Name = "requester local agent"; Headers = $requesterAgentHeaders; Role = "requester" },
    @{ Name = "helper local agent"; Headers = $helperAgentHeaders; Role = "helper" }
  )) {
    $myMatchesResponse = Assert-Status "$($matchViewer.Name) lists accepted match inbox" "GET" "/api/nexus/me/matches?filter%5Bstatus%5D=accepted&filter%5Brole%5D=$($matchViewer.Role)" @(200) $matchViewer.Headers
    $myMatchesJson = ConvertFrom-NexusJson "$($matchViewer.Name) match inbox parses" $myMatchesResponse.Content
    $myMatches = As-Array $myMatchesJson.data
    $myMatch = @($myMatches | Where-Object { [int] $_.id -eq $matchId } | Select-Object -First 1)
    Require-True "$($matchViewer.Name) match inbox includes accepted match" ($myMatch.Count -eq 1 -and $myMatch[0].attributes.status -eq "accepted") "matchId=$matchId"
    Require-True "$($matchViewer.Name) match inbox has viewer role" ($myMatch[0].attributes.viewerRole -eq $matchViewer.Role) "viewerRole=$($myMatch[0].attributes.viewerRole)"

    $workQueueResponse = Assert-Status "$($matchViewer.Name) work queue lists accepted match" "GET" "/api/nexus/me/work-items?filter%5Brole%5D=$($matchViewer.Role)&filter%5Bkind%5D=match&page%5Blimit%5D=20" @(200) $matchViewer.Headers
    $workQueueJson = ConvertFrom-NexusJson "$($matchViewer.Name) match work queue parses" $workQueueResponse.Content
    $workQueueItems = As-Array $workQueueJson.data
    $workQueueMatch = @($workQueueItems | Where-Object { $_.attributes.kind -eq "match" -and [int] $_.attributes.matchId -eq $matchId -and $_.attributes.action -eq "coordinate_match" } | Select-Object -First 1)
    Require-True "$($matchViewer.Name) work queue includes accepted match" ($workQueueMatch.Count -eq 1) "matchId=$matchId"
    $workQueueMatchNextActions = As-Array $workQueueMatch[0].attributes.nextActions
    $workQueueMatchNextActionNames = @($workQueueMatchNextActions | ForEach-Object { [string] $_.name })
    Require-True "$($matchViewer.Name) match work item uses canonical message action" ($workQueueMatchNextActionNames -contains "send_match_message") "nextActions=$($workQueueMatchNextActionNames -join ",")"
    Require-True "$($matchViewer.Name) match work item does not use old send_message action" (-not ($workQueueMatchNextActionNames -contains "send_message")) "nextActions=$($workQueueMatchNextActionNames -join ",")"
    Require-True "$($matchViewer.Name) match work item includes message preflight" ($workQueueMatchNextActionNames -contains "preflight_match_message") "nextActions=$($workQueueMatchNextActionNames -join ",")"
    Require-True "$($matchViewer.Name) match work item includes completion template" ($workQueueMatchNextActionNames -contains "complete_match") "nextActions=$($workQueueMatchNextActionNames -join ",")"
    $workQueueSendMessage = @($workQueueMatchNextActions | Where-Object { [string] $_.name -eq "send_match_message" } | Select-Object -First 1)
    Require-True "$($matchViewer.Name) match work item send message targets match" ([int] $workQueueSendMessage[0].preflight.body.data.attributes.target.id -eq $matchId) "targetId=$($workQueueSendMessage[0].preflight.body.data.attributes.target.id)"
    Require-True "$($matchViewer.Name) match work item send message has body template" ([string] $workQueueSendMessage[0].bodyTemplate.data.type -eq "nexus-help-match-messages") "type=$($workQueueSendMessage[0].bodyTemplate.data.type)"
    Assert-RichNextAction "$($matchViewer.Name) match work item send message" $workQueueSendMessage[0] "match_message.create" "#/components/schemas/MatchMessageInput" "createsPrivateMessage"
  }

  $requesterMessage = "Requester private coordination message $runId."
  $helperMessage = "Helper private coordination reply $runId."

  $requesterMessageBody = @{
    data = @{
      type = "nexus-help-match-messages"
      attributes = @{
        userConfirmed = $true
        content = $requesterMessage
        agentContext = @{
          smoke = $true
          runId = $runId
          side = "requester"
        }
      }
    }
  }

  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $false
  Assert-Status "requester local agent cannot send match message when allowAgentMatching is false" "POST" "/api/nexus/matches/$matchId/messages" @(422) $requesterAgentHeaders $requesterMessageBody | Out-Null
  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $true

  $requesterMessageResponse = Assert-Status "requester local agent sends match message" "POST" "/api/nexus/matches/$matchId/messages" @(201) $requesterAgentHeaders $requesterMessageBody
  $requesterMessageJson = ConvertFrom-NexusJson "requester message response parses" $requesterMessageResponse.Content
  Require-True "requester message has id" ([int] $requesterMessageJson.data.id -gt 0) "messageId=$($requesterMessageJson.data.id)"

  $helperMessageBody = @{
    data = @{
      type = "nexus-help-match-messages"
      attributes = @{
        userConfirmed = $true
        content = $helperMessage
        agentContext = @{
          smoke = $true
          runId = $runId
          side = "helper"
        }
      }
    }
  }

  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $false
  Assert-Status "helper local agent cannot send match message when allowAgentMatching is false" "POST" "/api/nexus/matches/$matchId/messages" @(422) $helperAgentHeaders $helperMessageBody | Out-Null
  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $true

  $helperMessageResponse = Assert-Status "helper local agent sends match message" "POST" "/api/nexus/matches/$matchId/messages" @(201) $helperAgentHeaders $helperMessageBody
  $helperMessageJson = ConvertFrom-NexusJson "helper message response parses" $helperMessageResponse.Content
  Require-True "helper message has id" ([int] $helperMessageJson.data.id -gt 0) "messageId=$($helperMessageJson.data.id)"

  foreach ($viewer in @(
    @{ Name = "requester local agent"; Headers = $requesterAgentHeaders },
    @{ Name = "helper local agent"; Headers = $helperAgentHeaders }
  )) {
    $messagesResponse = Assert-Status "$($viewer.Name) lists match messages" "GET" "/api/nexus/matches/$matchId/messages" @(200) $viewer.Headers
    $messagesJson = ConvertFrom-NexusJson "$($viewer.Name) message list parses" $messagesResponse.Content
    $messages = As-Array $messagesJson.data
    $contents = @($messages | ForEach-Object { [string] $_.attributes.content })
    Require-True "$($viewer.Name) sees requester message" ($contents -contains $requesterMessage) "matchId=$matchId"
    Require-True "$($viewer.Name) sees helper message" ($contents -contains $helperMessage) "matchId=$matchId"
  }

  Assert-Status "outsider cannot read match messages" "GET" "/api/nexus/matches/$matchId/messages" @(403) $outsiderHeaders | Out-Null

  $directHelpBody = @{
    data = @{
      type = "nexus-help-requests"
      attributes = @{
        userConfirmed = $true
        title = "Nexus direct offer smoke $runId"
        summary = "Temporary direct-offer help request for core-flow smoke $runId."
        content = "This temporary request verifies helper-initiated match offers and requester acceptance."
        categoryLabel = "help"
        neededLabels = @($label)
        urgency = "normal"
        locationHint = "Public campus service desk"
        meetingSafetyState = "public_place_suggested"
        agentContext = @{
          smoke = $true
          runId = $runId
          script = "scripts/nexus-core-flow-smoke.ps1"
          path = "direct-offer"
        }
      }
    }
  }

  $directHelpResponse = Assert-Status "requester local agent creates direct-offer help request" "POST" "/api/nexus/help-requests" @(201) $requesterAgentHeaders $directHelpBody
  $directHelpJson = ConvertFrom-NexusJson "direct-offer help request response parses" $directHelpResponse.Content
  $directHelpRequestId = [int] $directHelpJson.data.id
  Require-True "direct-offer help request has id" ($directHelpRequestId -gt 0) "helpRequestId=$directHelpRequestId"

  $offerBody = @{
    data = @{
      type = "nexus-help-matches"
      attributes = @{
        userConfirmed = $true
        message = "Helper offers direct help for smoke request $runId."
        meetingHint = "Public campus service desk"
        meetingSafetyState = "public_place_suggested"
      }
    }
  }

  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $false
  Assert-Status "helper local agent cannot offer direct match when allowAgentMatching is false" "POST" "/api/nexus/help-requests/$directHelpRequestId/matches" @(422) $helperAgentHeaders $offerBody | Out-Null
  Set-AgentMatchingAllowed "helper local agent simulation" $helperHeaders $true

  $offerResponse = Assert-Status "helper local agent offers direct match" "POST" "/api/nexus/help-requests/$directHelpRequestId/matches" @(201) $helperAgentHeaders $offerBody
  $offerJson = ConvertFrom-NexusJson "direct match offer response parses" $offerResponse.Content
  $offerMatchId = [int] $offerJson.data.id
  Require-True "direct match starts offered" ($offerMatchId -gt 0 -and $offerJson.data.attributes.status -eq "offered") "matchId=$offerMatchId"
  Require-True "helper offer response has viewer role" ($offerJson.data.attributes.viewerRole -eq "helper") "viewerRole=$($offerJson.data.attributes.viewerRole)"
  $helperOfferNextActions = As-Array $offerJson.data.attributes.nextActions
  $helperOfferNextActionNames = @($helperOfferNextActions | ForEach-Object { [string] $_.name })
  Require-True "helper offer nextActions include cancel offer" ($helperOfferNextActionNames -contains "cancel_offer") "nextActions=$($helperOfferNextActionNames -join ",")"

  $offerMatchesResponse = Assert-Status "requester local agent lists direct offers" "GET" "/api/nexus/help-requests/$directHelpRequestId/matches" @(200) $requesterAgentHeaders
  $offerMatchesJson = ConvertFrom-NexusJson "direct offer matches response parses" $offerMatchesResponse.Content
  $offerMatches = As-Array $offerMatchesJson.data
  $offeredMatch = @($offerMatches | Where-Object { [int] $_.id -eq $offerMatchId } | Select-Object -First 1)
  Require-True "direct offer visible to requester" ($offeredMatch.Count -eq 1 -and $offeredMatch[0].attributes.status -eq "offered") "matchId=$offerMatchId"
  Require-True "requester offer response has viewer role" ($offeredMatch[0].attributes.viewerRole -eq "requester") "viewerRole=$($offeredMatch[0].attributes.viewerRole)"
  $requesterOfferNextActions = As-Array $offeredMatch[0].attributes.nextActions
  $requesterOfferNextActionNames = @($requesterOfferNextActions | ForEach-Object { [string] $_.name })
  Require-True "requester offer nextActions include accept preflight" ($requesterOfferNextActionNames -contains "preflight_match_accept") "nextActions=$($requesterOfferNextActionNames -join ",")"
  Require-True "requester offer nextActions include accept match" ($requesterOfferNextActionNames -contains "accept_match") "nextActions=$($requesterOfferNextActionNames -join ",")"
  Require-True "requester offer nextActions include decline match" ($requesterOfferNextActionNames -contains "decline_match") "nextActions=$($requesterOfferNextActionNames -join ",")"
  $standaloneAcceptMatchPreflight = @($requesterOfferNextActions | Where-Object { [string] $_.name -eq "preflight_match_accept" } | Select-Object -First 1)
  Require-True "requester offer standalone accept preflight targets match" ([int] $standaloneAcceptMatchPreflight[0].body.data.attributes.target.id -eq $offerMatchId) "targetId=$($standaloneAcceptMatchPreflight[0].body.data.attributes.target.id)"
  Require-True "requester offer standalone accept preflight proposes accepted" ([string] $standaloneAcceptMatchPreflight[0].body.data.attributes.proposed.status -eq "accepted") "proposedStatus=$($standaloneAcceptMatchPreflight[0].body.data.attributes.proposed.status)"
  $acceptMatchAction = @($requesterOfferNextActions | Where-Object { [string] $_.name -eq "accept_match" } | Select-Object -First 1)
  $targetMatchAcceptPreflight = Assert-Status "requester local agent target-preflights direct offer accept" "POST" "/api/nexus/agent-preflight" @(200) $requesterAgentHeaders $acceptMatchAction[0].preflight.body
  $targetMatchAcceptJson = ConvertFrom-NexusJson "target direct offer accept preflight parses" $targetMatchAcceptPreflight.Content
  Require-True "direct offer accept preflight sees offered status" ($targetMatchAcceptJson.data.attributes.target.status -eq "offered") "status=$($targetMatchAcceptJson.data.attributes.target.status)"
  Require-True "direct offer accept preflight sees requester role" ($targetMatchAcceptJson.data.attributes.target.viewerRole -eq "requester") "viewerRole=$($targetMatchAcceptJson.data.attributes.target.viewerRole)"
  Require-True "direct offer accept preflight sees proposed accepted" ($targetMatchAcceptJson.data.attributes.target.proposedStatus -eq "accepted") "proposedStatus=$($targetMatchAcceptJson.data.attributes.target.proposedStatus)"

  $requesterOfferWorkResponse = Assert-Status "requester local agent work queue lists direct offer" "GET" "/api/nexus/me/work-items?filter%5Brole%5D=requester&filter%5Bkind%5D=match&page%5Blimit%5D=20" @(200) $requesterAgentHeaders
  $requesterOfferWorkJson = ConvertFrom-NexusJson "requester offer work queue parses" $requesterOfferWorkResponse.Content
  $requesterOfferWorkItems = As-Array $requesterOfferWorkJson.data
  $requesterOfferWork = @($requesterOfferWorkItems | Where-Object { $_.attributes.kind -eq "match" -and [int] $_.attributes.matchId -eq $offerMatchId -and $_.attributes.action -eq "review_match_offer" } | Select-Object -First 1)
  Require-True "requester work queue includes direct offer" ($requesterOfferWork.Count -eq 1) "matchId=$offerMatchId"
  $requesterOfferWorkNextActions = As-Array $requesterOfferWork[0].attributes.nextActions
  $requesterOfferWorkNextActionNames = @($requesterOfferWorkNextActions | ForEach-Object { [string] $_.name })
  Require-True "requester offer work item includes accept preflight" ($requesterOfferWorkNextActionNames -contains "preflight_match_accept") "nextActions=$($requesterOfferWorkNextActionNames -join ",")"
  Require-True "requester offer work item includes accept template" ($requesterOfferWorkNextActionNames -contains "accept_match") "nextActions=$($requesterOfferWorkNextActionNames -join ",")"
  $requesterOfferWorkAccept = @($requesterOfferWorkNextActions | Where-Object { [string] $_.name -eq "accept_match" } | Select-Object -First 1)
  Require-True "requester offer work item accept targets match" ([int] $requesterOfferWorkAccept[0].preflight.body.data.attributes.target.id -eq $offerMatchId) "targetId=$($requesterOfferWorkAccept[0].preflight.body.data.attributes.target.id)"
  Require-True "requester offer work item accept proposes accepted" ([string] $requesterOfferWorkAccept[0].preflight.body.data.attributes.proposed.status -eq "accepted") "proposedStatus=$($requesterOfferWorkAccept[0].preflight.body.data.attributes.proposed.status)"

  $preAcceptMessageBody = @{
    data = @{
      type = "nexus-help-match-messages"
      attributes = @{
        userConfirmed = $true
        content = "This message should be rejected until the direct offer is accepted $runId."
      }
    }
  }
  Assert-Status "helper local agent cannot message before match is accepted" "POST" "/api/nexus/matches/$offerMatchId/messages" @(422) $helperAgentHeaders $preAcceptMessageBody | Out-Null
  $preAcceptMessagePreflightBody = @{
    data = @{
      type = "nexus-agent-preflights"
      attributes = @{
        action = "match_message.create"
        userConfirmed = $false
        target = @{
          type = "help_match"
          id = $offerMatchId
        }
      }
    }
  }
  $preAcceptMessagePreflight = Assert-Status "helper local agent target-preflights message before acceptance" "POST" "/api/nexus/agent-preflight" @(200) $helperAgentHeaders $preAcceptMessagePreflightBody
  $preAcceptMessagePreflightJson = ConvertFrom-NexusJson "message before acceptance preflight parses" $preAcceptMessagePreflight.Content
  $preAcceptMessageBlocking = As-Array $preAcceptMessagePreflightJson.data.attributes.blocking
  Require-True "message before acceptance preflight blocks target status" ($preAcceptMessageBlocking -contains "targetStatus") "blocking=$($preAcceptMessageBlocking -join ",")"

  $acceptOfferBody = @{
    data = @{
      type = "nexus-help-matches"
      attributes = @{
        userConfirmed = $true
        status = "accepted"
        meetingHint = "Public campus service desk, visible seating area"
        meetingSafetyState = "public_place_confirmed"
      }
    }
  }

  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $false
  Assert-Status "requester local agent cannot accept direct offer when allowAgentMatching is false" "PATCH" "/api/nexus/matches/$offerMatchId" @(422) $requesterAgentHeaders $acceptOfferBody | Out-Null
  Set-AgentMatchingAllowed "requester local agent simulation" $requesterHeaders $true

  $acceptOfferResponse = Assert-Status "requester local agent accepts direct offer" "PATCH" "/api/nexus/matches/$offerMatchId" @(200) $requesterAgentHeaders $acceptOfferBody
  $acceptOfferJson = ConvertFrom-NexusJson "accepted direct offer response parses" $acceptOfferResponse.Content
  Require-True "direct offer becomes accepted" ($acceptOfferJson.data.attributes.status -eq "accepted") "matchId=$offerMatchId"
  $acceptedOfferNextActions = As-Array $acceptOfferJson.data.attributes.nextActions
  $acceptedOfferNextActionNames = @($acceptedOfferNextActions | ForEach-Object { [string] $_.name })
  Require-True "accepted direct offer nextActions include private coordination" (($acceptedOfferNextActionNames -contains "list_messages") -and ($acceptedOfferNextActionNames -contains "send_match_message")) "nextActions=$($acceptedOfferNextActionNames -join ",")"

  $directHelpShowResponse = Assert-Status "requester local agent shows accepted direct-offer request" "GET" "/api/nexus/help-requests/$directHelpRequestId" @(200) $requesterAgentHeaders
  $directHelpShowJson = ConvertFrom-NexusJson "accepted direct-offer request parses" $directHelpShowResponse.Content
  Require-True "direct-offer request becomes matched" ($directHelpShowJson.data.attributes.status -eq "matched") "helpRequestId=$directHelpRequestId"

  foreach ($auditViewer in @(
    @{
      Name = "requester"
      Headers = $requesterAgentHeaders
      ExpectedActions = @("agent_profile.update", "forum_discussion.create", "forum_post.reply", "forum_post.edit", "forum_post.delete", "help_request.create", "dispatch.create", "match_message.create", "match.update")
    },
    @{
      Name = "helper"
      Headers = $helperAgentHeaders
      ExpectedActions = @("agent_profile.update", "capabilities.update", "dispatch.update", "match_message.create", "match.offer")
    }
  )) {
    $actionLogResponse = Assert-Status "$($auditViewer.Name) lists action logs" "GET" "/api/nexus/me/action-logs?page%5Blimit%5D=50" @(200) $auditViewer.Headers
    $actionLogJson = ConvertFrom-NexusJson "$($auditViewer.Name) action log response parses" $actionLogResponse.Content
    $actionLogItems = As-Array $actionLogJson.data
    $actionTypes = @($actionLogItems | ForEach-Object { [string] $_.attributes.actionType })

    foreach ($expectedAction in $auditViewer.ExpectedActions) {
      Require-True "$($auditViewer.Name) action log includes $expectedAction" ($actionTypes -contains $expectedAction) "actions=$($actionTypes -join ",")"
    }

    Require-True "$($auditViewer.Name) action logs redact private messages" (-not $actionLogResponse.Content.Contains($requesterMessage) -and -not $actionLogResponse.Content.Contains($helperMessage)) "private message bodies absent"
    Require-True "$($auditViewer.Name) action logs redact private profiles" (-not $actionLogResponse.Content.Contains($requesterSoulMd) -and -not $actionLogResponse.Content.Contains($helperSoulMd)) "private soulMd bodies absent"
    Require-True "$($auditViewer.Name) action logs redact gateway post bodies" (-not $actionLogResponse.Content.Contains($gatewayDiscussionContent) -and -not $actionLogResponse.Content.Contains($gatewayReplyContent) -and -not $actionLogResponse.Content.Contains($gatewayEditedReplyContent)) "gateway public body text absent from logs"
  }

  Write-Host ""
  Write-Host "Core flow smoke complete: failures=$Script:Failures"
} catch {
  if ($Script:Failures -eq 0) {
    Fail "core flow smoke" $_.Exception.Message
  }

  Write-Host ""
  Write-Host "Core flow smoke failed: failures=$Script:Failures"
  throw
} finally {
  if ($fixtureCreated -and -not $KeepFixture) {
    Write-Host ""
    Write-Host "Cleaning smoke fixture..."
    Invoke-Fixture -Action "cleanup" -RunId $runId -FixtureRel $fixtureRel | ForEach-Object { Write-Host $_ }
  } elseif ($fixtureCreated) {
    Write-Host ""
    Write-Host "Keeping smoke fixture at: $fixturePath"
  }
}

if ($Script:Failures -gt 0) {
  exit 1
}
