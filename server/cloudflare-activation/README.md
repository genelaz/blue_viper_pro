# Tek cihaz aktivasyonu

## Hızlı yol (önerilen — Windows)

1. **Node.js** + **Flutter** + **Dart** hazır olsun.
2. PowerShell (gerekirse önce: `Set-ExecutionPolicy -Scope Process Bypass`):
   ```powershell
   cd C:\src\blue_viper_pro\server\cloudflare-activation
   .\quick-setup.ps1
   ```
3. Betik bittiğinde ekranda yazan **`flutter build apk ... --dart-define=ACTIVATION_API_URL=...`** satırını çalıştır.
4. Kodları paylaş: proje kökündeki **`activation_codes_PRIVATE.txt`**.

**Ne yapar?** Kod üretir → KV namespace yoksa oluşturup `wrangler.toml` id’yi yazar → KV’ye seed yükler → Worker deploy eder → APK komutunu önerir.

**Not:** `wrangler.toml` içinde hâlâ `BURAYA_KV_NAMESPACE_ID` varsa otomatik doldurulur; **zaten gerçek bir id yazdıysanız** namespace adımı atlanır (aynı betikle tekrar deploy/KV güncellemesi yapabilirsiniz).

**Worker kodunu değiştirdiniz, kod listesine dokunmayacaksınız:**  
`.\quick-setup.ps1 -SkipGenerate` → mevcut `activation_kv_seed.json` ile KV upload + deploy (daha hızlı).

**Sorun:** `npx` / `wrangler` bulunamazsa Node.js LTS kurun. Cloudflare girişi istenirse tarayıcıdan onaylayın.

---

## Uzun rehber (manuel, satır satır)

Aşağıdaki bölümler betiğin yaptığı işin manuel karşılığıdır; takılırsanız buradan bakın.

---

## Önkoşullar (bir kez)

1. **Node.js** yüklü olsun (LTS): https://nodejs.org  
   Terminalde kontrol: `node -v` ve `npx --version` yazınca sürüm görünsün.

2. **Flutter** projeniz bilgisayarda: `flutter doctor` yeşil / kritik hata olmasın.

3. **Cloudflare** hesabı: https://dash.cloudflare.com (ücretsiz planda yeterli).

---

## A — Kodları ve KV seed dosyasını üret

Bilgisayarda proje kökü örnek: `C:\src\blue_viper_pro`

1. PowerShell veya CMD açın.
2. Proje köküne girin:
   ```text
   cd C:\src\blue_viper_pro
   ```
3. Komutu çalıştırın:
   ```text
   dart run tool/generate_activation_codes.dart
   ```

**Çıktıda şunlar oluşur (aynı klasörde):**

| Dosya | Ne işe yarar |
|--------|----------------|
| `activation_codes_PRIVATE.txt` | Arkadaşlara vereceğiniz **12 haneli kodlar** (gizli tutun). |
| `activation_kv_seed.json` | Cloudflare KV’ye yüklenecek **hash anahtar listesi**. |
| `lib/core/licensing/activation_code_hashes.g.dart` | Sadece **çevrimdışı mod** için (Worker kullanıyorsanız sunucu asıl doğrulayıcıdır). |

**Önemli:** Bu komutu tekrar çalıştırırsanız **tüm kodlar ve KV hash’leri değişir**. Dağıttığınız eski kodlar geçersiz olur.

---

## B — Wrangler ile Cloudflare’e giriş

1. Terminal:
   ```text
   cd C:\src\blue_viper_pro\server\cloudflare-activation
   ```
2. Cloudflare hesabını bağlayın:
   ```text
   npx wrangler login
   ```
3. Tarayıcı açılır; Cloudflare’de **Allow** deyin. Terminal “Successfully logged in” benzeri mesaj verir.

---

## C — KV namespace oluştur ve `wrangler.toml` doldur

**Yöntem 1 — Komut satırı (önerilir)**

1. Şunu çalıştırın:
   ```text
   npx wrangler kv namespace create "bvp-activation"
   ```
2. Çıktıda **`id =` ile başlayan uzun bir kimlik** görürsünüz; kopyalayın.  
   Örnek (sahte): `a1b2c3d4e5f678901234567890123456`

3. Şu dosyayı bir metin düzenleyicide açın:
   ```text
   C:\src\blue_viper_pro\server\cloudflare-activation\wrangler.toml
   ```
4. Şu satırı bulun:
   ```text
   id = "BURAYA_KV_NAMESPACE_ID"
   ```
5. Tırnakların içine **kopyaladığınız id**’yi yapıştırın:
   ```text
   id = "a1b2c3d4e5f678901234567890123456"
   ```
6. Dosyayı kaydedin.

**Yöntem 2 — Cloudflare paneli**

1. Dashboard → **Workers & Pages** → **KV** → **Create a namespace** → isim: `bvp-activation`.
2. Oluşan namespace’e tıklayın → **Namespace ID**’yi kopyalayın.
3. Yukarıdaki gibi `wrangler.toml` içindeki `id = "..."` alanına yapıştırın.

---

## D — KV’ye kod hash’lerini toplu yükle

1. Hâlâ şu klasördesiniz:
   ```text
   C:\src\blue_viper_pro\server\cloudflare-activation
   ```
2. Proje kökünde `activation_kv_seed.json` **var** olmalı (A adımında ürettiniz).

3. Toplu yükleme:
   ```text
   npx wrangler kv bulk put ..\..\activation_kv_seed.json --binding=ACTIVATION_KV
   ```

**Beklenen:** Hata yok; birkaç satır “Success” / yazılan kayıt sayısı benzeri çıktı.

**Sorun giderme**

- `ENOENT` / dosya yok: `activation_kv_seed.json` gerçekten `C \src\blue_viper_pro\` altında mı kontrol edin.
- Binding hatası: `wrangler.toml` içinde `binding = "ACTIVATION_KV"` ve `id` doğru mu tekrar bakın.

---

## E — Worker’ı yayınla (deploy)

1. Aynı klasörde:
   ```text
   npx wrangler deploy
   ```
2. İlk seferde Worker adı sorulabilir; `wrangler.toml` içindeki `name = "blue-viper-activation"` kullanılır.

**Çıktının sonunda** bir **HTTPS URL** görürsünüz, örnek:
```text
https://blue-viper-activation.hesabiniz.workers.dev
```

3. Bu adresi **tamamen kopyalayın** (sonunda `/` olmasa da olur; uygulama `.trim()` kullanıyor).  
   **Not:** Uygulama `POST` isteğini bu adresin **köküne** gönderir; `/activate` path’i yok.

---

## F — (İsteğe bağlı) Özel salt

Varsayılan salt kodda `bvp_act_v1|` — Worker ve Dart aynı.

Kendi salt’ınızı kullanmak isterseniz:

1. `server/cloudflare-activation` içinde:
   ```text
   npx wrangler secret put ACTIVATION_SALT
   ```
2. İstendiğinde bir metin girin.
3. `lib/core/licensing/activation_validator.dart` ve `tool/generate_activation_codes.dart` içindeki salt sabitini **aynı** yapın.
4. **A adımını tekrar** çalıştırın, **D adımını tekrar** (KV seed), **E ile yeniden deploy**.

---

## G — Flutter APK derleme (Worker adresi ile)

1. Proje kökü:
   ```text
   cd C:\src\blue_viper_pro
   ```
2. **E adımında kopyaladığınız URL**’yi `ACTIVATION_API_URL` olarak verin (tırnak içinde, https ile):
   ```text
   flutter build apk --release --dart-define=ACTIVATION_API_URL=https://blue-viper-activation.hesabiniz.workers.dev
   ```
3. APK yolu (değişmez):
   ```text
   build\app\outputs\flutter-apk\app-release.apk
   ```

**Dikkat**

- `--dart-define` **olmadan** derlerseniz uygulama **çevrimdışı moda** düşer; her cihazda aynı kod çalışır.
- Worker URL’sini yanlış yazarsanız uygulama “sunucuya bağlanılamadı” benzeri hata verir.

---

## H — Telefonda test

1. APK’yı kurun.
2. **İnternet** açık olsun.
3. `activation_codes_PRIVATE.txt` dosyasından **bir** satırlık 12 haneli kodu girin → **Aktifleştir**.
4. Aynı kodu **başka bir telefonda** deneyin → “Bu kod başka bir telefonda zaten kullanıldı” mesajı beklenir.

---

## Özet komut zinciri (kopyala-yapıştır için)

Sıra ile; aralarda `wrangler.toml` düzenlemeyi unutmayın:

```text
cd C:\src\blue_viper_pro
dart run tool/generate_activation_codes.dart

cd C:\src\blue_viper_pro\server\cloudflare-activation
npx wrangler login
npx wrangler kv namespace create "bvp-activation"
REM ↑ çıkan id'yi wrangler.toml içine yazın

npx wrangler kv bulk put ..\..\activation_kv_seed.json --binding=ACTIVATION_KV
npx wrangler deploy

cd C:\src\blue_viper_pro
flutter build apk --release --dart-define=ACTIVATION_API_URL=https://BURAYA_WORKER_URL
```

Worker URL’sini **deploy çıktısındaki gerçek adresle** değiştirin.

---

## Dosya referansları (projede)

| Dosya | Açıklama |
|--------|-----------|
| `server/cloudflare-activation/src/index.js` | Worker mantığı (Kod + deviceId → KV). |
| `server/cloudflare-activation/wrangler.toml` | Worker adı + KV bağlantısı. |
| `lib/core/licensing/activation_api_client.dart` | Uygulamanın `POST` isteği. |
| `lib/core/licensing/activation_config.dart` | `ACTIVATION_API_URL` okuma. |
