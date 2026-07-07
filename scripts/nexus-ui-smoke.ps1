param(
  [string] $BaseUrl,
  [string] $ChromePath
)

$ErrorActionPreference = "Stop"

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

function Find-Chrome {
  $candidates = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return $null
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

  Write-Host "[FAIL] $Name - $Detail"
  exit 1
}

$repoRoot = Resolve-RepoRoot
$envFile = Join-Path $repoRoot "storage\nexus\agent-api.env"
$envValues = Read-NexusEnv -Path $envFile

if (-not $BaseUrl) {
  $BaseUrl = $envValues["NEXUS_BASE_URL"]
}

if (-not $BaseUrl) {
  $BaseUrl = "http://10.98.65.32:8080"
}

if (-not $ChromePath) {
  $ChromePath = Find-Chrome
}

if (-not $ChromePath) {
  Fail "browser available" "Chrome or Edge was not found"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$outFile = Join-Path $env:TEMP ("nexus-ui-smoke-" + [Guid]::NewGuid().ToString("N") + ".html")
$errFile = Join-Path $env:TEMP ("nexus-ui-smoke-" + [Guid]::NewGuid().ToString("N") + ".err")

Write-Host "Nexus UI smoke target: $BaseUrl"
Write-Host "Browser: $ChromePath"
Write-Host ""

try {
  $args = @(
    "--headless=new",
    "--disable-gpu",
    "--no-first-run",
    "--disable-extensions",
    "--virtual-time-budget=5000",
    "--dump-dom",
    "$BaseUrl/"
  )

  $process = Start-Process `
    -FilePath $ChromePath `
    -ArgumentList $args `
    -NoNewWindow `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile `
    -Wait `
    -PassThru

  if ($process.ExitCode -ne 0) {
    $errorText = ""
    if (Test-Path -LiteralPath $errFile) {
      $errorText = [System.IO.File]::ReadAllText($errFile, [System.Text.Encoding]::UTF8)
    }

    Fail "browser exited cleanly" "exit=$($process.ExitCode) $($errorText.Substring(0, [Math]::Min(400, $errorText.Length)))"
  }

  $dom = [System.IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8)

  if ($dom.Contains('id="flarum-loading-error" style="display: none"')) {
    Pass "Flarum loading error hidden"
  } else {
    Fail "Flarum loading error hidden" "fallback warning appears visible or missing expected hidden state"
  }

  if ($dom.Contains('class="TagsPage"')) {
    Pass "Flarum app mounted" "TagsPage"
  } else {
    Fail "Flarum app mounted" "TagsPage marker missing"
  }

  if (-not $dom.Contains("<h2>Tags</h2>")) {
    Pass "fallback tag list not rendered"
  } else {
    Fail "fallback tag list not rendered" "basic HTML fallback is still visible"
  }

  if ($dom.Contains("Start a Discussion") -and $dom.Contains('class="Hero WelcomeHero"') -and $dom.Contains('class="TagTiles"')) {
    Pass "homepage content rendered"
  } else {
    Fail "homepage content rendered" "expected Flarum homepage text missing"
  }

  if ($dom.Contains("Nexus Agent Docs") -and ($dom.Contains('href="/docs/"') -or $dom.Contains("href=`"$BaseUrl/docs/`""))) {
    Pass "Nexus docs link rendered"
  } else {
    Fail "Nexus docs link rendered" "header docs link missing"
  }

  Write-Host ""
  Write-Host "Nexus UI smoke complete: failures=0"
} finally {
  Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
}
