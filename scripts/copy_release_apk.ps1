# Release APK'yi share_apk/ altina kopyalar (WhatsApp, USB, bulut paylasimi icin).
# Google Drive sabit klasor: scripts/stage_apk_google_drive.ps1 -> share_apk/GoogleDriveUpload/
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
$destDir = Join-Path $root "share_apk"
if (-not (Test-Path $src)) {
    Write-Error "Once derleyin: cd `"$root`"; flutter build apk --release"
    exit 1
}
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$verLine = Select-String -Path (Join-Path $root "pubspec.yaml") -Pattern "^version:\s*" | Select-Object -First 1
$ver = if ($verLine) { ($verLine.Line -replace '^version:\s*', '').Trim() } else { "unknown" }
$safe = $ver -replace '\+', '_build'
Copy-Item -Force $src (Join-Path $destDir "blue_viper_pro_$safe.apk")
Copy-Item -Force $src (Join-Path $destDir "blue_viper_pro_latest.apk")
Write-Host "Tamam:" (Join-Path $destDir "blue_viper_pro_latest.apk")
