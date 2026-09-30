[CmdletBinding()]
param(
    [int]$Port = 8000,
    [switch]$SkipInstall,
    [switch]$RunSmokeTests,
    [switch]$NoBrowser,
    [switch]$Reload
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

function Step([string]$m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Fail([string]$m) { Write-Host "[ERROR] $m" -ForegroundColor Red; exit 1 }

Write-Host "OmniTransform local chat frontend" -ForegroundColor Green
Write-Host "Same FastAPI + web/ interface used on Render." -ForegroundColor DarkGray

if (-not (Test-Path ".env")) {
    if (-not (Test-Path ".env.example")) { Fail ".env.example is missing." }
    Copy-Item ".env.example" ".env"
    Write-Host "[WARN] Created .env from .env.example. Fill in HF_TOKEN and Chroma values, then rerun." -ForegroundColor Yellow
    exit 2
}

$VenvDir = Join-Path $RepoRoot ".venv_local"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Step "Creating Python virtual environment"
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $python) { Fail "Python 3.11+ was not found on PATH." }
    & $python.Source -m venv $VenvDir
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $VenvPython)) { Fail "Could not create .venv_local." }
}

if (-not $SkipInstall) {
    Step "Installing local web dependencies"
    & $VenvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { Fail "pip upgrade failed." }
    & $VenvPython -m pip install -r requirements-local-web.txt
    if ($LASTEXITCODE -ne 0) { Fail "Dependency installation failed." }
}

$env:SESSION_STORE_BACKEND = "memory"
$env:PYTHONPATH = $RepoRoot
$env:PYTHONUNBUFFERED = "1"

Step "Validating configuration"
$preflight = @'
from dotenv import load_dotenv
load_dotenv(".env", override=False)
from app.config import Settings
s = Settings.from_env()
print("Config OK")
print("VLM:", s.multimodal_model)
print("LLM:", s.llm_model)
print("Session backend:", s.session_store_backend)
'@
& $VenvPython -c $preflight
if ($LASTEXITCODE -ne 0) { Fail "Configuration validation failed. Check .env." }

Step "Compiling project"
& $VenvPython -m compileall -q app agents artifacts core database evaluation generation ingestion providers retrieval scripts verification
if ($LASTEXITCODE -ne 0) { Fail "Python compile check failed." }

if ($RunSmokeTests) {
    Step "Running smoke tests"
    & $VenvPython -m pytest -q tests/test_phase2_ingestion.py tests/test_hf_token_config.py tests/test_hf_vlm_reranker.py tests/test_phase5_verification.py tests/test_phase6_artifacts.py
    if ($LASTEXITCODE -ne 0) { Fail "Smoke tests failed." }
}

try {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listener) { Fail "Port $Port is already in use by PID $($listener.OwningProcess)." }
} catch {}

$logDir = Join-Path $RepoRoot ".runtime_logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$stdout = Join-Path $logDir "uvicorn.stdout.log"
$stderr = Join-Path $logDir "uvicorn.stderr.log"
Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
$args = @("-m","uvicorn","app.web_server:app","--host","127.0.0.1","--port","$Port")
if ($Reload) { $args += "--reload" }

Step "Starting http://127.0.0.1:$Port"
$proc = Start-Process -FilePath $VenvPython -ArgumentList $args -WorkingDirectory $RepoRoot -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$ready = $false
$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) { break }
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/api/health" -UseBasicParsing -TimeoutSec 2
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch { Start-Sleep -Milliseconds 600 }
}
if (-not $ready) {
    if (Test-Path $stderr) { Get-Content $stderr -Tail 80 }
    Fail "FastAPI server did not become healthy."
}
Write-Host "[OK] Frontend ready: http://127.0.0.1:$Port" -ForegroundColor Green
Write-Host "PID: $($proc.Id)"
Write-Host "Stop with: Stop-Process -Id $($proc.Id)" -ForegroundColor DarkGray
if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$Port" }
