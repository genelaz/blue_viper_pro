# Tam akis: analiz + test + release APK + Google Drive yukleme klasorune kopya.
# Kullanim (proje kokunden):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_release_apk_for_google_drive.ps1
# Test atlamak icin:  ... -File scripts/build_release_apk_for_google_drive.ps1 -SkipTests
param(
    [switch] $SkipTests
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "=== flutter analyze ===" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter analyze basarisiz (uyarilar bazen 0 doner; hatalari kontrol edin)."
    exit $LASTEXITCODE
}

if (-not $SkipTests) {
    Write-Host "=== flutter test ===" -ForegroundColor Cyan
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter test basarisiz."
        exit $LASTEXITCODE
    }
} else {
    Write-Host "=== flutter test atlandi (-SkipTests) ===" -ForegroundColor Yellow
}

Write-Host "=== flutter build apk --release ===" -ForegroundColor Cyan
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Derleme basarisiz."
    exit $LASTEXITCODE
}

& "$PSScriptRoot\stage_apk_google_drive.ps1"
