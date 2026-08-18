# DynaElastomerSolver — Public Repository IP ve Güvenlik Politikası

**Hak sahibi / Licensor:** Muhammet Fatih Kavak  
**Repository:** `kavakfatih/DynaElastomerSolver`  
**Lisans:** DynaElastomerSolver Proprietary Source-Available License v1.1  
**Model:** Proprietary / source-available / All Rights Reserved  
**Açık kaynak durumu:** Açık kaynak değildir

Bu politika, public durumdaki DynaElastomerSolver repository'si için fikrî mülkiyet, telif, patent, ticari sır, katkı, üçüncü taraf lisans, secret, CI/CD ve GitHub yönetişim kurallarını tanımlar.

## 1. Hak sahipliği ve lisans

Muhammet Fatih Kavak'ın sahip olduğu özgün DynaElastomerSolver materyalleri `LICENSE` ve `COPYRIGHT.md` kapsamındadır. Public görünürlük mülkiyet devri, kamu malına terk veya açık kaynak lisansı oluşturmaz.

GitHub Terms of Service'den doğrudan kaynaklanan platform hakları ve emredici hukuk hükümleri saklıdır; Dyna lisansı bu hakları genişletmez.

Ayrı yazılı izin olmadan genel olarak ticari/production kullanım, kurum içi kullanım, değiştirme, türev eser, redistribution, sublicensing, ürün/servis entegrasyonu, patent lisansı, marka lisansı ve üçüncü taraf AI/ML eğitim/dataset kullanımı verilmez. Bağlayıcı kapsam `LICENSE` içindedir.

## 2. Üçüncü taraf hakları

Üçüncü taraf bileşenler Dyna proprietary lisansına dönüştürülmez. Kendi telif sahipleri ve lisansları geçerlidir.

Mevcut doğrudan Fortran dependency örneği:

```text
kavakfatih/stdlib
commit: 9a15c7772f1a76a6c497b9f3abb793841fc81f74
license: MIT
copyright: stdlib contributors
```

Ayrıntılar `THIRD_PARTY_NOTICES.md` içinde tutulur.

## 3. Katkı ve provenance

Unsolicited dış kod katkıları varsayılan olarak merge edilmez. Teknik review veya PR açılması hak devri oluşturmaz.

Gerekli olduğunda merge öncesi:

- IP/mali hak devir sözleşmesi,
- contributor assignment/license agreement,
- işveren/kurum izni,
- üçüncü taraf kaynak/lisans beyanı,
- AI-assisted provenance incelemesi

istenir. Ayrıntı `CONTRIBUTING.md` ve `.github/pull_request_template.md` içindedir.

## 4. Patent ve kamuya açıklama

Repository public olduğundan patentlenebilir teknik unsurlar için kamuya açıklama tarihi dikkate alınmalıdır. Özellikle özgün formulation, F-bar varyasyonları, axisymmetric/2.5D torsion yöntemleri, nonlinear solver/recovery, calibration ve product-level teknik çözümler patent vekili/uzmanıyla ayrı değerlendirilmelidir.

Bu repository politikası patent başvurusu veya patentlenebilirlik görüşü yerine geçmez.

## 5. Ticari sır / NDA

Public repository içinde müşteri verisi, gerçek gizli test datası, şirket içi reçete/proses/tolerans, NDA materyali, özel CAD/mesh/geometri, gizli endpoint, credential, private key veya açıklanmaması gereken teknik öğretim tutulmaz.

Bir secret geçmişte commitlendiyse yalnız dosyadan silmek yeterli değildir; credential revoke/rotate edilir ve gerekiyorsa history temizliği uygulanır.

## 6. Secret ve credential denetimi

Kontrol kapsamı:

- current tree,
- tüm commit history,
- deleted files,
- branches/tags,
- Actions logs,
- workflow artifacts,
- test fixtures,
- generated/build/config çıktıları.

Current-tree hızlı keyword kontrolünde belirgin secret eşleşmesi bulunmamıştır; bu full-history audit yerine geçmez.

## 7. CI/CD ve supply-chain

- GitHub Actions minimum token permission kullanır.
- Third-party actions mümkün olduğunda immutable commit SHA ile pinlenir.
- Container image'ları mümkün olduğunda digest ile pinlenir.
- FEniCSx reference image:

```text
dolfinx/dolfinx:v0.11.0@sha256:58b27e84a2f26b98ce2d9ccc537b0ee6a59e2fcfdf386626d5ed9ddf43425ece
```

- `.github/dependabot.yml` GitHub Actions dependency güncellemelerini izler.
- Fork PR'lar privileged secret/write-token erişimi almamalıdır.

## 8. GitHub security hardening

Repository hardening tamamlanmış sayılmadan aşağıdakiler doğrulanır:

- [ ] `main` branch protection/ruleset aktif
- [ ] zorunlu CI status checks aktif
- [ ] force push kapalı
- [ ] branch deletion kapalı
- [ ] Private Vulnerability Reporting aktif
- [ ] repository-level Push Protection aktif
- [ ] Secret scanning / Secret Protection durumu doğrulandı
- [ ] Dependabot alerts durumu doğrulandı
- [x] Dependency graph — public repository platform özelliği
- [ ] uygun code scanning aktif
- [x] `SECURITY.md`
- [x] `COPYRIGHT.md`
- [x] `CODEOWNERS`
- [x] PR IP/security checklist
- [x] Dependabot config
- [x] SHA/digest pinning baseline

## 9. Ana branch politikası

`main` için hedef:

- PR üzerinden merge,
- CI geçmeden merge yok,
- conversation resolution,
- force push yok,
- branch deletion yok.

Solo-owner yapı nedeniyle bağımsız ikinci reviewer bulunmadan Code Owner approval zorunluluğu merge akışını kilitleyecek biçimde yapılandırılmaz; yine de `CODEOWNERS` hak sahipliği/reviewer kaydı olarak korunur.

## 10. Release bütünlüğü

Public release için minimum:

- versioned immutable tag,
- release notes,
- `LICENSE`, `COPYRIGHT.md`, `THIRD_PARTY_NOTICES.md`,
- SHA-256 checksum,
- mümkünse signed tag/release.

## 11. Açık kalan güvenlik/hukuk maddeleri

- full-history secret/credential audit,
- historical Actions logs/artifacts audit,
- `main` branch protection ve required checks,
- PVR / Push Protection / alerts / code scanning ayar teyidi,
- patent/public-disclosure uzman incelemesi,
- ticari sır/NDA/provenance incelemesi,
- GitHub Archive Program tercihi.

Takip: Issue `#2 — Security: Public repository hardening`.

## 12. Temel ilke

> Public görünürlük şeffaflık sağlar; mülkiyet devri yapmaz. Muhammet Fatih Kavak tarafından açıkça ve yazılı olarak verilmeyen haklar, GitHub'ın zorunlu platform hakları ve emredici hukuk dışında saklıdır.
