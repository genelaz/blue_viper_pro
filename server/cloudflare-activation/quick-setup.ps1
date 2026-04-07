# Tek cihaz aktivasyonu: kod üret + KV doldur + Worker yayınla
# Kullanım (PowerShell):
#   cd C:\src\blue_viper_pro\server\cloudflare-activation
#   .\quick-setup.ps1
#   .\quick-setup.ps1 -SkipGenerate   # Kodlari yeniden uretmeden sadece KV+deploy (Worker kodu degistiysen)
#
# Calismazsa: Set-ExecutionPolicy -Scope Process Bypass
# İlk sefer: npx wrangler login (tarayıcı) gerekir.

param([switch]$SkipGenerate)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
$tomlPath = Join-Path $here "wrangler.toml"
$seedPath = Join-Path $repoRoot "activation_kv_seed.json"

function Write-Step([string]$msg) {
    Write-Host "`n== $msg ==" -ForegroundColor Cyan
}

if (-not $SkipGenerate) {
    Write-Step "1/4 Kod listesi + KV seed (dart)"
    Push-Location $repoRoot
    try {
        dart run tool/generate_activation_codes.dart
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step "1/4 Atlandi (-SkipGenerate)"
}

if (-not (Test-Path $seedPath)) {
    Write-Host "HATA: $seedPath yok. Once .\quick-setup.ps1 (SkipGenerate olmadan) calistirin." -ForegroundColor Red
    exit 1
}

$tomlLines = Get-Content $tomlPath
$needsId = $tomlLines | Where-Object { $_ -match "BURAYA_KV_NAMESPACE_ID" }

if ($needsId) {
    Write-Step "2/4 KV namespace + wrangler.toml (otomatik)"
    $createOut = npx wrangler kv namespace create "bvp-activation" 2>&1 | Out-String
    if ($createOut -match "not authenticated|login required|Unauthorized") {
        Write-Host "Cloudflare oturumu gerekli; tarayici aciliyor..." -ForegroundColor Yellow
        npx wrangler login
        $createOut = npx wrangler kv namespace create "bvp-activation" 2>&1 | Out-String
    }
    # Cikti icinde 32 hane hex namespace id ara
    if ($createOut -notmatch "([0-9a-f]{32})") {
        Write-Host "KV namespace id ciktidan okunamadi. Manuel: wrangler.toml icine id yazin.`n$createOut" -ForegroundColor Red
        exit 1
    }
    $newId = $Matches[1]
    $newLines = $tomlLines | ForEach-Object {
        if ($_ -match "BURAYA_KV_NAMESPACE_ID") {
            'id = "' + $newId + '"'
        }
        else { $_ }
    }
    [System.IO.File]::WriteAllLines($tomlPath, $newLines)
    Write-Host "wrangler.toml guncellendi (KV id)." -ForegroundColor Green
}
else {
    Write-Step "2/4 KV id zaten dolu, namespace adimi atlandi"
}

Write-Step "3/4 KV bulk put"
Push-Location $here
try {
    npx wrangler kv bulk put $seedPath --binding=ACTIVATION_KV
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}

Write-Step "4/4 wrangler deploy"
Push-Location $here
$deployText = ""
try {
    $deployText = (npx wrangler deploy 2>&1 | Out-String)
    Write-Host $deployText
}
finally {
    Pop-Location
}

Write-Host ""
if ($deployText -match "(https://[a-zA-Z0-9.\-]+\.workers\.dev)") {
    $url = $Matches[1]
    Write-Host "SON ADIM (APK):" -ForegroundColor Green
    Write-Host "cd `"$repoRoot`""
    Write-Host "flutter build apk --release --dart-define=ACTIVATION_API_URL=$url"
}
else {
    Write-Host "Worker URL ciktida yok. Cloudflare Dashboard > Workers > blue-viper-activation > URL`ni kopyalayin, sonra:" -ForegroundColor Yellow
    Write-Host "flutter build apk --release --dart-define=ACTIVATION_API_URL=https://....workers.dev"
}

Write-Host "`nKodlar (dagitim): $repoRoot\\activation_codes_PRIVATE.txt" -ForegroundColor DarkGray
