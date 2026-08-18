# DynaElastomerSolver — Public Repository IP ve Güvenlik Politikası

**Belge türü:** Zorunlu yayın öncesi kontrol politikası  
**Hak sahibi:** Fatih KAVAK  
**Repository:** `kavakfatih/DynaElastomerSolver`  
**Lisans modeli:** Proprietary / source-available / All Rights Reserved  
**Açık kaynak durumu:** Açık kaynak değildir

Bu politika, DynaElastomerSolver repository'si private durumdan public duruma geçirilmeden önce uygulanacak fikrî mülkiyet, patent, ticari sır, üçüncü taraf lisans, güvenlik ve GitHub yapılandırma kontrollerini tanımlar.

---

## 1. Temel yayın ilkesi

Public repository kararı yalnız **kaynak kodunun görüntülenebilir olması** anlamına gelir.

DynaElastomerSolver için public görünürlük:

- MIT / Apache / GPL / BSD veya başka bir açık kaynak lisansı verilmesi anlamına gelmez,
- genel kullanım izni vermez,
- ticari kullanım izni vermez,
- değiştirme veya türev eser üretme izni vermez,
- redistribution / sublicensing izni vermez,
- patent lisansı vermez,
- marka kullanım izni vermez.

Repository'nin özgün Dyna içeriğinde `LICENSE` dosyası geçerlidir. Üçüncü taraf bileşenlerde kendi lisansları geçerlidir.

---

## 2. GitHub public-repository hak sınırı

GitHub üzerinde repository public yapıldığında GitHub Terms of Service uyarınca GitHub ve GitHub kullanıcıları platformun çalışması için belirli sınırlı haklar elde edebilir; public repository kullanıcılar tarafından görüntülenebilir ve GitHub işlevleri kapsamında fork edilebilir.

Dyna lisansı bu zorunlu/platform kaynaklı hakları genişletmez.

**Kural:** GitHub'ın platform sözleşmesinden doğan haklar dışında hiçbir ek kullanım hakkı varsayılmaz.

---

## 3. Patent yayın öncesi kapısı — ZORUNLU

Repository public yapılmadan önce patentlenebilir teknik unsurlar için ayrı inceleme yapılır.

Özellikle şu alanlar kontrol edilir:

- özgün nearly-incompressible formulation türetmeleri,
- özgün F-bar varyasyonları,
- axisymmetric / 2.5D torsion yöntemleri,
- nonlinear recovery / solver algoritmaları,
- özgün calibration yöntemleri,
- özgün result semantics veya veri işleme yöntemleri,
- ürün seviyesinde yeni teknik çözüm oluşturan solver/ölçüm kombinasyonları.

Public source disclosure patent yeniliğini etkileyebileceğinden:

> Patent başvurusu düşünülüyorsa, ilgili teknik içerik **public yapılmadan önce** patent vekili / uzmanıyla değerlendirilir ve gerekiyorsa başvuru yapılır.

Patent incelemesi tamamlanmadan repository visibility `public` yapılmaz.

---

## 4. Ticari sır kapısı — ZORUNLU

Public repository içinde yayınlanan bilgi artık fiilen herkese erişilebilir olacağından, gizli tutulması gereken ticari sır niteliğindeki bilgiler source tree ve Git geçmişinden çıkarılmalıdır.

Public'e çıkmaması gereken örnekler:

- müşteri verileri,
- gerçek test datasının gizli bölümleri,
- şirket içi reçete / proses / tolerans bilgileri,
- NDA kapsamındaki teknik dokümanlar,
- lisans anahtarları,
- API tokenları,
- credentiallar,
- özel endpointler,
- kurum içi IP / kullanıcı / sistem bilgileri,
- gizli CAD / mesh / ürün geometrileri,
- patent başvurusu yapılmamış gizli teknik öğretim.

**Kural:** Sadece current tree değil, **tüm Git history** incelenir.

Bir secret geçmişte commitlendiyse yalnız dosyadan silmek yeterli değildir; credential iptal edilir/rotate edilir ve gerekiyorsa history temizliği uygulanır.

---

## 5. Telif ve hak sahipliği kapısı

Public öncesinde şu sorular yanıtlanmış olmalıdır:

- Dyna özgün kodunun hak sahipliği açık mı?
- Başka çalışan/şirket/üniversite/müşteri hak iddia edebilir mi?
- dış katkı var mı?
- üçüncü taraf kodu kopyalanmış mı?
- AI-assisted kodun provenance'ı incelenmiş mi?
- kod veya doküman başka lisanslardan türemiş mi?

Dış contributor katkısı bulunuyorsa gerekli IP assignment / yazılı izin tamamlanmadan public release yapılmaz.

Türkiye'de isteğe bağlı kayıt-tescil hak yaratmasa da eser sahipliği ispatını kolaylaştırmak için ayrıca değerlendirilebilir.

---

## 6. Üçüncü taraf lisans kapısı

Her dependency şu bilgilerle kayıt altında tutulur:

```text
Dependency
├── upstream repository
├── pinlenen version / commit
├── copyright owner
├── license
├── kullanım biçimi
├── vendored / fetched / linked durumu
└── notice yükümlülüğü
```

Mevcut doğrudan Fortran dependency:

```text
kavakfatih/stdlib
commit: 9a15c7772f1a76a6c497b9f3abb793841fc81f74
license: MIT
copyright: stdlib contributors
```

Üçüncü taraf lisans metinleri `THIRD_PARTY_NOTICES.md` içinde korunur.

**Yasak:** Üçüncü taraf açık kaynak kodunu Dyna proprietary telif hakkıymış gibi işaretlemek.

---

## 7. Katkı politikası

Public repository dışarıdan pull request alabilir; ancak bu, katkının kabul edileceği anlamına gelmez.

Varsayılan politika:

```text
Unsolicited external code contribution
→ merge edilmez
→ IP/provenance incelemesi gerekir
→ gerekiyorsa yazılı hak devri gerekir
→ sonra teknik review + CI
```

Ayrıntı: `CONTRIBUTING.md`.

---

## 8. Secret ve credential güvenliği — ZORUNLU

Public öncesi aşağıdakiler taranır:

- current source tree,
- tüm commit history,
- deleted files,
- git tags,
- branch history,
- GitHub Actions logs,
- workflow artifacts,
- test fixtures,
- `.env` benzeri dosyalar,
- config örnekleri,
- build logs ve generated outputs.

Aranacak sınıflar:

- GitHub tokenları,
- cloud API keys,
- SSH/private keys,
- passwords,
- connection strings,
- package registry credentials,
- signing keys,
- VPN / internal host bilgileri,
- e-posta veya kişisel veri içeren debug dump'ları.

Bir credential public olmuşsa **rotate/revoke** yapılmadan yalnız history temizliğiyle güvenli kabul edilmez.

---

## 9. GitHub Actions ve CI güvenliği

Public olduktan sonra workflow güvenliği aşağıdaki ilkelere göre yönetilir:

### Minimum permission

Varsayılan hedef:

```yaml
permissions:
  contents: read
```

Write yetkisi yalnız gerçekten gerekli job/workflow'a verilir.

### Third-party actions

- mümkünse commit SHA ile pinlenir,
- major tag tek başına güven zinciri kabul edilmez,
- action publisher ve dependency chain incelenir.

### Fork PR güvenliği

Fork'tan gelen kod:

- repository secretlarına doğrudan erişmemeli,
- privileged workflow ile otomatik çalıştırılmamalı,
- maintainer review olmadan write token almamalı.

---

## 10. GitHub güvenlik özellikleri — PUBLIC ÖNCESİ / SONRASI

Public repository için aşağıdakiler doğrulanır:

- [ ] Secret scanning aktif
- [ ] Push protection aktif
- [ ] Dependabot alerts aktif
- [ ] Dependency graph aktif
- [ ] Code scanning uygun kapsamda aktif
- [ ] Private Vulnerability Reporting aktif
- [ ] `SECURITY.md` görünür
- [ ] Actions token permissions minimum
- [ ] default branch korunuyor
- [ ] force push kapalı
- [ ] zorunlu CI check'leri tanımlı
- [ ] release/tag politikası tanımlı

---

## 11. Visibility değişiminden sonra branch koruması

GitHub private → public visibility değişiminde mevcut push ruleset'ler devre dışı kalabileceğinden visibility değişiminden **hemen sonra** branch/ruleset durumu tekrar kontrol edilir.

Minimum `main` politikası:

- direct push sınırlı,
- PR review zorunlu veya owner-controlled merge,
- CI checks zorunlu,
- force push kapalı,
- branch deletion kapalı,
- mümkünse signed commit/tag politikası.

---

## 12. Actions geçmişi ve artifact görünürlüğü

Repository public olduğunda GitHub Actions history ve logları public olarak görüntülenebilir.

Visibility değişiminden önce:

- eski workflow run logları incelenir,
- secret veya internal path sızıntıları aranır,
- hassas artifactler silinir,
- gerekli credentiallar rotate edilir.

---

## 13. GitHub Archive Program

Public repository'nin GitHub Archive Program kapsamında uzun süreli üçüncü taraf arşivlerine alınabileceği dikkate alınır.

Maksimum kontrol isteniyorsa public geçiş öncesinde repository'nin Archive Program opt-out seçeneği değerlendirilir.

**Not:** Public'e çıktıktan sonra fork, clone veya üçüncü taraf arşiv kopyalarının tamamen geri alınabileceği varsayılmaz.

---

## 14. Public README lisans uyarısı

README içinde görünür biçimde şu anlam korunmalıdır:

```text
This repository is source-available, not open source.
Copyright © 2026 Fatih KAVAK. All Rights Reserved.
See LICENSE and THIRD_PARTY_NOTICES.md.
```

---

## 15. Release ve bütünlük

Public binary/release üretildiğinde önerilen minimum bütünlük katmanı:

- versioned release,
- immutable tag,
- SHA-256 checksum,
- mümkünse signed tag/release,
- release notes,
- third-party notices,
- license notice.

---

## 16. Nihai PUBLIC kararı — GO / NO-GO

Repository yalnız aşağıdaki tüm zorunlu kapılar kapandığında public yapılabilir:

### IP
- [ ] Hak sahipliği doğrulandı
- [ ] LICENSE final
- [ ] THIRD_PARTY_NOTICES final
- [ ] Contribution policy final
- [ ] Patent incelemesi tamamlandı
- [ ] Ticari sır incelemesi tamamlandı

### Security
- [ ] Full-history secret scan tamamlandı
- [ ] Actions logs/artifacts kontrol edildi
- [ ] Gerekli credential rotation tamamlandı
- [ ] SECURITY.md final
- [ ] Private Vulnerability Reporting aktif
- [ ] Secret scanning / push protection doğrulandı

### Repository governance
- [ ] README proprietary/source-available uyarısı içeriyor
- [ ] Branch/ruleset planı hazır
- [ ] Public değişiminden sonra ruleset yeniden etkinleştirme adımı hazır
- [ ] Archive Program kararı verildi

Herhangi bir zorunlu madde açıksa:

> **NO-GO — repository public yapılmaz.**

---

## 17. Temel ilke

> Public görünürlük şeffaflık sağlar; mülkiyet devri yapmaz. Ancak bir kez kamuya açıklanan kaynak kodu, ticari sır ve patent stratejisi açısından geri döndürülemez sonuçlar doğurabilir. Bu nedenle lisans, güvenlik ve patent kontrolleri görünürlük değişiminden önce tamamlanır.
