# Google Drive yuklemesi icin APK'yi sabit bir klasore kopyalar.
# Drive masaustu uygulamasi veya drive.google.com uzerinden bu klasoru senkronlayin / yukleyin.
# Kaynak: flutter build apk --release -> build\app\outputs\flutter-apk\app-release.apk
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
$destDir = Join-Path $root "share_apk\GoogleDriveUpload"
if (-not (Test-Path $src)) {
    Write-Error "APK yok. Once: cd `"$root`"; flutter build apk --release"
    exit 1
}
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$verLine = Select-String -Path (Join-Path $root "pubspec.yaml") -Pattern "^version:\s*" | Select-Object -First 1
$ver = if ($verLine) { ($verLine.Line -replace '^version:\s*', '').Trim() } else { "unknown" }
$safe = $ver -replace '\+', '_build'
$dated = Get-Date -Format "yyyyMMdd_HHmm"
$versioned = Join-Path $destDir "blue_viper_pro_${safe}.apk"
$latest = Join-Path $destDir "blue_viper_pro_latest.apk"
$stamp = Join-Path $destDir "blue_viper_pro_${safe}_${dated}.apk"
Copy-Item -Force $src $versioned
Copy-Item -Force $src $latest
Copy-Item -Force $src $stamp
$note = @"
Blue Viper Pro - Android APK (release)
Versiyon (pubspec): $ver
Kopyalanma: $(Get-Date -Format "yyyy-MM-dd HH:mm")
Kaynak: flutter build apk --release

Google Drive:
- Bu klasoru (GoogleDriveUpload) Drive'da paylasilan bir klasore tasiyin veya
  Google Drive masausti istemcisinde 'Add folder' ile senkronlayin.
- Yuklenen APK linki: Paylas -> Herkesi linke sahip olanlar -> Goruntuleyebilir (veya organizasyon politikasi).
"@
$note | Out-File -FilePath (Join-Path $destDir "GOOGLE_DRIVE_README.txt") -Encoding utf8
Write-Host ""
Write-Host "=== Google Drive icin hazir ===" -ForegroundColor Green
Write-Host $destDir
Write-Host "  - $(Split-Path -Leaf $versioned)"
Write-Host "  - $(Split-Path -Leaf $latest)"
Write-Host "  - $(Split-Path -Leaf $stamp)"
Write-Host "  - GOOGLE_DRIVE_README.txt"
Write-Host ""
