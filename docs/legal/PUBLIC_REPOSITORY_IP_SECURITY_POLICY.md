# DynaElastomerSolver — Public Repository IP ve Güvenlik Politikası

**Belge türü:** Public repository fikrî mülkiyet ve güvenlik politikası  
**Repository:** `kavakfatih/DynaElastomerSolver`  
**Lisans modeli:** Proprietary / source-available / All Rights Reserved  
**Açık kaynak durumu:** Açık kaynak değildir

Bu politika DynaElastomerSolver repository'sinin public görünürlük altında fikrî mülkiyet, patent, ticari sır, üçüncü taraf lisans, güvenlik ve GitHub yönetişim kontrollerini tanımlar.

---

## 1. Temel yayın ilkesi

Public repository yalnız kaynak kodunun herkes tarafından görüntülenebilir olmasını ifade eder.

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

GitHub Terms of Service uyarınca GitHub ve GitHub kullanıcıları platformun çalışması için belirli sınırlı haklar elde edebilir; public repository kullanıcılar tarafından görüntülenebilir ve GitHub işlevleri kapsamında fork edilebilir.

Dyna lisansı bu platform haklarını genişletmez.

**Kural:** GitHub'ın platform sözleşmesinden doğan haklar dışında hiçbir ek kullanım hakkı varsayılmaz.

---

## 3. Patent/public-disclosure kontrolü — ZORUNLU

Repository artık public olduğundan patentlenebilir teknik unsurlar için public-disclosure tarihi dikkate alınarak ayrı uzman incelemesi yapılmalıdır.

Özellikle şu alanlar kontrol edilir:

- özgün nearly-incompressible formulation türetmeleri,
- özgün F-bar varyasyonları,
- axisymmetric / 2.5D torsion yöntemleri,
- nonlinear recovery / solver algoritmaları,
- özgün calibration yöntemleri,
- özgün result semantics veya veri işleme yöntemleri,
- ürün seviyesinde yeni teknik çözüm oluşturan solver/ölçüm kombinasyonları.

Patent başvurusu düşünülüyorsa kamuya açıklanmış ve açıklanmamış teknik içerik patent vekili / uzmanıyla ayrıca değerlendirilir.

---

## 4. Ticari sır / NDA kontrolü — ZORUNLU

Public repository içinde yayınlanan bilgi fiilen herkese erişilebilir olduğundan gizli tutulması gereken içerik current tree ve Git geçmişinden çıkarılmalıdır.

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
- açıklanmaması gereken teknik öğretim.

Bir secret geçmişte commitlendiyse yalnız dosyadan silmek yeterli değildir; credential iptal edilir/rotate edilir ve gerekiyorsa history temizliği uygulanır.

---

## 5. Telif ve hak sahipliği

Aşağıdaki sorular her release ve önemli contribution öncesinde kontrol edilir:

- Dyna özgün kodunun hak sahipliği açık mı?
- başka çalışan/şirket/üniversite/müşteri hak iddia edebilir mi?
- dış katkı var mı?
- üçüncü taraf kodu kopyalanmış mı?
- AI-assisted kodun provenance'ı incelenmiş mi?
- kod veya doküman başka lisanslardan türemiş mi?

Dış contributor katkısı bulunuyorsa gerekli IP assignment / yazılı izin tamamlanmadan merge/release yapılmaz.

Hak sahibi adı hukuki tam ad biçiminde `LICENSE`, `NOTICE`, README ve bu politika üzerinde tutarlı kullanılmalıdır.

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

Public repository dışarıdan pull request alabilir; ancak bu katkının kabul edileceği anlamına gelmez.

Varsayılan politika:

```text
Unsolicited external code contribution
→ merge edilmez
→ IP/provenance incelemesi gerekir
→ gerekiyorsa yazılı hak devri gerekir
→ sonra teknik review + CI
```

Ayrıntı: `CONTRIBUTING.md` ve `.github/pull_request_template.md`.

---

## 8. Secret ve credential güvenliği

Aşağıdaki alanlar taranır:

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

Bir credential bulunursa **revoke/rotate** yapılmadan yalnız history temizliğiyle güvenli kabul edilmez.

Current-tree hızlı keyword taramasında belirgin secret eşleşmesi bulunmamıştır; bu sonuç full-history audit yerine geçmez.

---

## 9. GitHub Actions ve CI güvenliği

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

### Container images

FEniCSx reference image public-repo hardening kapsamında linux/amd64 immutable digest ile pinlenmiştir:

```text
dolfinx/dolfinx:v0.11.0@sha256:58b27e84a2f26b98ce2d9ccc537b0ee6a59e2fcfdf386626d5ed9ddf43425ece
```

### Fork PR güvenliği

Fork'tan gelen kod:

- repository secretlarına doğrudan erişmemeli,
- privileged workflow ile otomatik çalıştırılmamalı,
- maintainer review olmadan write token almamalı.

---

## 10. GitHub güvenlik özellikleri — POST-PUBLIC HARDENING

Doğrulanması/etkinleştirilmesi gerekenler:

- [ ] Secret scanning / Secret Protection
- [ ] Push protection
- [ ] Dependabot alerts
- [ ] Dependency graph
- [ ] uygun code scanning
- [ ] Private Vulnerability Reporting
- [x] `SECURITY.md` görünür
- [x] Actions token permissions minimum
- [ ] default branch korunuyor
- [ ] force push kapalı
- [ ] zorunlu CI check'leri tanımlı
- [x] supply-chain update config (`.github/dependabot.yml`)
- [x] PR IP/security checklist
- [x] FEniCSx image digest pin

---

## 11. `main` branch protection — ACİL

Public sonrası kontrolde:

```text
main protected = false
required status checks = off
```

Minimum `main` politikası `docs/legal/GITHUB_PUBLIC_SECURITY_CONFIGURATION.md` içinde tanımlanmıştır.

Özet:

- PR üzerinden merge,
- V0.3 CI status context'leri zorunlu,
- conversation resolution,
- force push kapalı,
- branch deletion kapalı.

Solo-owner yapı nedeniyle bağımsız ikinci reviewer olmadan Code Owner approval zorunlu hale getirilmez.

---

## 12. Actions geçmişi ve artifact görünürlüğü

Public repository'de Actions history ve logları görünür olabilir.

Kontrol:

- eski workflow run logları incelenir,
- secret veya internal path sızıntıları aranır,
- hassas artifactler silinir,
- gerekli credentiallar rotate edilir.

---

## 13. GitHub Archive Program

Public repository'nin uzun süreli üçüncü taraf arşivlerine alınabileceği dikkate alınır.

Maksimum kontrol isteniyorsa Archive Program opt-out seçeneği ayrıca değerlendirilir.

**Not:** Public'e çıktıktan sonra fork, clone veya üçüncü taraf arşiv kopyalarının tamamen geri alınabileceği varsayılmaz.

---

## 14. Public README lisans uyarısı

README içinde görünür biçimde şu anlam korunmalıdır:

```text
This repository is source-available, not open source.
All Rights Reserved.
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

## 16. Post-public hardening durum özeti

Tamamlananlar:

- proprietary/source-available LICENSE
- NOTICE / SECURITY / CONTRIBUTING
- third-party notices
- CODEOWNERS
- README rights banner
- PR IP/security template
- GitHub Actions Dependabot update config
- minimum workflow permissions
- SHA-pinned GitHub Actions
- FEniCSx image digest pin
- current-tree hızlı secret keyword kontrolü

Açık kalanlar:

- full-history secret audit
- historical Actions logs/artifacts audit
- `main` branch protection
- required CI status checks
- Private Vulnerability Reporting
- Secret scanning / Push protection / Dependabot alerts / code scanning UI teyidi
- patent/public-disclosure review
- ticari sır/NDA/provenance review
- Archive Program kararı
- hak sahibinin tam hukuki adının tüm telif metinlerinde tek biçime geçirilmesi

Takip issue: `#2 — Security: Public repository hardening`.
