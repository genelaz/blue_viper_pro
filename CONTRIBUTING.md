# Katkı ve ekip senkronu

Bu depoda `main` dalı güncel ürün kodudur. GitHub, bilgisayarınızdaki klasörü **otomatik güncellemez**; herkesin düzenli olarak uzak depodan çekmesi gerekir.

## Güncel kalmak (her gün / görev öncesi)

```bash
git checkout main
git pull origin main
flutter pub get
```

Fork veya yan dal kullanıyorsanız, birleştirmeden önce `main` ile güncelleyin.

## “Güncel miyim?” kontrolü

Önce uzak referansları güncelleyin:

```bash
git fetch origin
```

**main ile aynı mısınız** (arkada kalma yok mu):

```bash
git status
```

Çıktıda `Your branch is up to date with 'origin/main'` görürseniz `main` dalında güncelsiniz.

**Kaç commit geridesiniz** (sayı 0 olmalı):

```bash
git rev-list HEAD..origin/main --count
```

**Son sürüm etiketi** (ör. v1.1.0) ile karşılaştırma:

```bash
git fetch origin --tags
git describe --tags --always
```

## GitHub tarafında (depo ayarları — ayrı dosya değil)

| Ne | Nereden |
|----|--------|
| Yeni sürüm / tag bildirimi | Depo sayfası üst menü **Watch** → *Custom* → *Releases* işaretleyin |
| Kim ne zaman push etmiş | **Insights** → *Network* veya **Commits** |
| Dal koruması (isteğe bağlı) | **Settings** → *Branches* → *Branch protection rules* (`main` için PR zorunluluğu vb.) |

Tek bir “sihirli” YAML dosyası, ekip üyelerinin PC’sindeki projeyi tek başına güncellemez; süreç `git pull` + yukarıdaki kontrollerdir.

## Yararlı dosya yolları (bu repoda)

| Dosya | Amaç |
|-------|------|
| `CONTRIBUTING.md` (bu dosya) | Ekip senkron ve kontrol komutları |
| `pubspec.yaml` → `version:` | Uygulama sürümü (ör. `1.1.0+6`) |
| `.github/workflows/` | CI otomasyonu (varsa derleme/test her push’ta) |

PR açarken GitHub bu `CONTRIBUTING.md` dosyasına bağlantı gösterebilir (reponun kökünde olduğu için).
