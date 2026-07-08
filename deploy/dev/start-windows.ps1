$ErrorActionPreference = "Stop"

$flarumDir = "/mnt/d/Nexus/workspace/flarum"
$repoDir = "D:\Nexus\workspace\flarum"
$nodeExe = "C:\Users\server02\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$lanIp = "10.98.65.32"

Write-Host "Updating Flarum base URL..."
$configPath = Join-Path $repoDir "config.php"
$config = Get-Content -Raw -Path $configPath
$config = $config -replace "'url'\s*=>\s*'[^']+'", "'url' => 'http://$lanIp`:8080'"
[System.IO.File]::WriteAllText($configPath, $config, [System.Text.UTF8Encoding]::new($false))

Write-Host "Starting Nexus Flarum services in WSL..."
wsl -u root -e bash -lc "$flarumDir/deploy/dev/start-nginx.sh"

Write-Host "Starting WSL keepalive process..."
$keepalive = Start-Process -FilePath "wsl.exe" `
  -ArgumentList '-e bash -lc "while true; do sleep 3600; done"' `
  -WindowStyle Hidden `
  -PassThru

Write-Host "Starting Windows proxy on 0.0.0.0:8080..."
$proxyLog = Join-Path $repoDir "storage\logs\windows-proxy.log"
$proxyErrLog = Join-Path $repoDir "storage\logs\windows-proxy.err.log"
$proxyPidFile = Join-Path $repoDir "storage\logs\windows-proxy.pid"
if (Test-Path $proxyPidFile) {
  $oldProxyPid = Get-Content $proxyPidFile -ErrorAction SilentlyContinue
  if ($oldProxyPid) {
    Stop-Process -Id ([int]$oldProxyPid) -Force -ErrorAction SilentlyContinue
  }
}
$proxy = Start-Process -FilePath $nodeExe `
  -ArgumentList @((Join-Path $repoDir "deploy/dev/proxy.js")) `
  -WorkingDirectory $repoDir `
  -RedirectStandardOutput $proxyLog `
  -RedirectStandardError $proxyErrLog `
  -WindowStyle Hidden `
  -PassThru
Set-Content -Path $proxyPidFile -Value $proxy.Id

Write-Host "Waiting for Windows proxy and WSL backend..."
$ready = $false
for ($i = 1; $i -le 30; $i++) {
  try {
    $response = Invoke-WebRequest -Uri "http://$lanIp`:8080/" -UseBasicParsing -TimeoutSec 5
    $asset = Invoke-WebRequest -Uri "http://$lanIp`:8080/assets/forum.js" -UseBasicParsing -TimeoutSec 5
    if ($response.StatusCode -eq 200 -and $asset.StatusCode -eq 200 -and $asset.RawContentLength -gt 0) {
      $ready = $true
      break
    }
  } catch {
    Start-Sleep -Seconds 2
  }
}

if (-not $ready) {
  Write-Warning "Services started, but Windows could not reach http://127.0.0.1:8080/ yet."
  Write-Warning "Check WSL with: wsl -u root -e bash -lc `"service nginx status; ss -ltnp | grep 18080`""
  Write-Warning "Check proxy log: $proxyLog"
  exit 1
}

Write-Host "Nexus Flarum is ready:"
Write-Host "  http://$lanIp`:8080/  (recommended)"
Write-Host "  http://127.0.0.1:8080/  (local fallback)"
Write-Host "Keepalive PID: $($keepalive.Id)"
Write-Host "Proxy PID: $($proxy.Id)"
