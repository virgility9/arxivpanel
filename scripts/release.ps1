#Requires -Version 5.1
<#
.SYNOPSIS
  Publish an Arxiv release live: tag the version, create the GitHub
  release, and upload the release APK. The app checks GitHub Releases
  for updates, so the moment this release exists, users see the Update
  prompt (download with progress in the notification, then installer).

.DESCRIPTION
  Run AFTER bumping the version and building the APK:
    1. pubspec.yaml: version: 1.0.1+2  (and lib/data/constants.dart
       AppConstants.currentVersion = '1.0.1' - must match, no +build)
    2. flutter build apk --release
    3. From the repo root (C:\Projects\Flutter\arxivpanel):
         .\scripts\release.ps1 1.0.1

  Needs the GitHub CLI once: winget install GitHub.cli, then
  `gh auth login` (browser) and `gh auth status` to confirm.

  The release notes are generated automatically by GitHub
  (--generate-notes) from the commits since the previous release.

.PARAMETER Version
  The version to release, e.g. 1.0.1 (no leading v, no +build).
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Version
)

$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  Write-Host "Version must look like 1.0.1 (got '$Version')." -ForegroundColor Red
  exit 1
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

# 1. GitHub CLI present and logged in?
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "gh is not installed. Run: winget install GitHub.cli" -ForegroundColor Red
  Write-Host "Then close this terminal, open a new one, and run: gh auth login" -ForegroundColor Red
  exit 1
}
gh auth status --hostname github.com 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "gh is not logged in. Run: gh auth login" -ForegroundColor Red
  exit 1
}

# 2. Version bumped before the build?
$pubspec = Get-Content pubspec.yaml -Raw
if ($pubspec -notmatch "(?m)^version:\s*$([regex]::Escape($Version))\+\d+\s*$") {
  Write-Host "pubspec.yaml is not version $Version yet. Bump version: $Version+<build> there and in lib/data/constants.dart (currentVersion = '$Version'), then rebuild." -ForegroundColor Red
  exit 1
}

# 3. APK built?
$apk = 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
  Write-Host "APK not found at $apk. Run: flutter build apk --release" -ForegroundColor Red
  exit 1
}

# 3b. The in-app version constant must match too. The app reports
# AppConstants.currentVersion, not pubspec, so a mismatch makes the
# Update prompt loop forever (phone says the old version after install).
$constants = Get-Content lib\data\constants.dart -Raw
if ($constants -notmatch "currentVersion\s*=\s*'$([regex]::Escape($Version))'") {
  Write-Host "lib/data/constants.dart currentVersion is not '$Version'. Set it to '$Version', rebuild, then re-run this script." -ForegroundColor Red
  exit 1
}

# 3c. The APK must be a fresh build, not a stale file from an older
# release. A stale APK uploads fine and the phone then installs the old
# version while the release says a new one exists (1.0.4 shipped the
# 1.0.3 APK this way because the rebuild was skipped).
$headTime = [int]((git log -1 --format="%ct").Trim())
$apkTime = [int]([System.DateTimeOffset](Get-Item $apk).LastWriteTimeUtc).ToUnixTimeSeconds()
if ($apkTime -lt $headTime) {
  Write-Host "The APK at $apk is older than the latest commit. Run: flutter build apk --release" -ForegroundColor Red
  exit 1
}

# 4. Tag once, push the tag.
$tag = "v$Version"
$existingTag = git tag --list $tag
if ($existingTag) {
  Write-Host "Tag $tag already exists. Pick a new version - a release cannot be re-published under the same tag." -ForegroundColor Red
  exit 1
}
git tag $tag
git push origin $tag

# 5. Create the release with auto-generated notes and the APK.
# The asset is renamed to arxiv-1.0.1.apk on the release page.
$assetName = "arxiv-$Version.apk"
gh release create $tag `
  --title $tag `
  --generate-notes `
  "$apk#$assetName"

Write-Host ""
Write-Host "Live: $tag is published with $assetName. Users will see the Update prompt next time they open the app." -ForegroundColor Green
