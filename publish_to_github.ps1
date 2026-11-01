param(
    [Parameter(Mandatory = $false)]
    [string]$RepoUrl
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

Write-Host "=== Records Portal — GitHub Cloud APK Publisher ===" -ForegroundColor Cyan

# 1. Ensure Git is available (install via winget if missing)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitExe = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $gitExe) {
        $env:Path = "C:\Program Files\Git\cmd;$env:Path"
    } else {
        Write-Host "Installing Git for Windows via winget..." -ForegroundColor Yellow
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        $env:Path = "C:\Program Files\Git\cmd;$env:Path"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git installation not detected in PATH yet. Close and reopen PowerShell, then re-run this script."
}

# 2. Ask for GitHub Repository URL if not passed as parameter
if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    Write-Host ""
    Write-Host "Create a new PRIVATE repository on https://github.com/new (leave README unchecked)," -ForegroundColor Gray
    $RepoUrl = Read-Host "then paste your repository URL (e.g. https://github.com/yourname/records-portal.git)"
}
$RepoUrl = $RepoUrl.Trim()
if (-not $RepoUrl.StartsWith("https://github.com/")) {
    throw "Please provide a valid https://github.com/<owner>/<repo>.git URL."
}

# 3. Initialize repository & configure local identity if missing
if (-not (Test-Path ".git")) {
    git init -b main
} else {
    git branch -M main
}

$curName = git config user.name
if ([string]::IsNullOrWhiteSpace($curName)) {
    git config user.name "Records Portal Builder"
}
$curEmail = git config user.email
if ([string]::IsNullOrWhiteSpace($curEmail)) {
    git config user.email "builder@recordsportal.local"
}

# 4. Stage, commit & push to trigger GitHub Actions APK build
git add -A
$status = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($status)) {
    git commit -m "Build Records Portal Android app with offline QR/NFC sync"
}

$existingRemote = git remote
if ($existingRemote -contains "origin") {
    git remote set-url origin $RepoUrl
} else {
    git remote add origin $RepoUrl
}

Write-Host ""
Write-Host "Pushing project to GitHub (sign in via browser if prompted)..." -ForegroundColor Green
git push -u origin main

$actionsUrl = ($RepoUrl -replace '\.git$', '') + "/actions"
$releasesUrl = ($RepoUrl -replace '\.git$', '') + "/releases"
Write-Host ""
Write-Host "Done! GitHub Actions is now compiling your Android APK (~4 minutes)." -ForegroundColor Green
Write-Host "1. Watch build progress: $actionsUrl" -ForegroundColor Cyan
Write-Host "2. Download APK on your phone when finished: $releasesUrl" -ForegroundColor Yellow
