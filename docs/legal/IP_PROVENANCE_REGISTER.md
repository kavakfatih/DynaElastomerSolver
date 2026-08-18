# DynaElastomerSolver — IP / Provenance Register

**Repository:** `kavakfatih/DynaElastomerSolver`  
**Hak sahibi kaydı:** Muhammet Fatih Kavak  
**Amaç:** Dyna özgün içeriğini, üçüncü taraf bileşenleri, dış katkıları ve public-disclosure durumunu release bazında izlemek.

Bu sicil hukuki hakları yaratmaz; mevcut hak sahipliği ve provenance delillerini düzenli kaydetmek için kullanılır. Hak sahipliği yalnız hukuken sahip olunan içerik bakımından ileri sürülür.

## 1. Dyna özgün proje içeriği

Aşağıdaki alanlar Dyna proje kapsamıdır ve üçüncü taraf bileşenler hariç `LICENSE` / `COPYRIGHT.md` politikasıyla yönetilir:

- `src/` içindeki Dyna scientific core ve solver implementasyonları,
- Dyna'ya özgü `tests/` ve benchmark sözleşmeleri,
- Dyna'ya özgü `tools/verification/` yardımcıları,
- proje mimarisi, ADR'ler ve özgün dokümantasyon,
- Dyna GitHub Actions workflow/configuration dosyaları,
- Dyna'ya özgü result semantics ve application contracts.

Her release öncesi dış kaynak/copied code/provenance incelemesi yapılır.

## 2. Doğrudan üçüncü taraf dependency

### Fortran stdlib

```text
repository: kavakfatih/stdlib
pinned commit: 9a15c7772f1a76a6c497b9f3abb793841fc81f74
upstream copyright: stdlib contributors
license: MIT
integration: CMake FetchContent / stdlib_linalg
ownership: third-party; Dyna hak sahibine atfedilmez
```

Tam notice: `THIRD_PARTY_NOTICES.md`.

## 3. External reference / tooling

FEniCSx/DOLFINx, PETSc, compilerlar, BLAS/LAPACK implementasyonları, GitHub Actions ve diğer dış araçlar kendi hak sahipleri ve lisanslarında kalır.

FEniCSx reference container:

```text
dolfinx/dolfinx:v0.11.0@sha256:58b27e84a2f26b98ce2d9ccc537b0ee6a59e2fcfdf386626d5ed9ddf43425ece
```

Bu araçların Dyna workflow'larında çağrılması onların fikrî mülkiyetinin Dyna'ya ait olduğu anlamına gelmez.

## 4. Dış contributor kuralı

Yeni dış contributor için merge öncesinde aşağıdaki kayıt açılır:

```text
Contributor:
GitHub identity:
Contribution/PR:
Employer/institution claim check:
Third-party source declaration:
AI-assisted development declaration:
Required assignment/license agreement:
Agreement status:
Merge authorization:
```

Gerekli yazılı hak devri/lisans/izin tamamlanmadan contribution production koduna merge edilmez.

## 5. AI-assisted geliştirme provenance notu

AI-assisted geliştirme kullanılması halinde insan tarafından verilen proje yönü, teknik kararlar, review, seçimler ve özgün katkılar release provenance'ında korunur. AI-assisted materyal, üçüncü taraf kod kaynağı veya hak devri varmış gibi varsayılmaz.

Bir içeriğin telif veya başka fikrî mülkiyet korumasına uygunluğu hukuken değişebileceğinden, bu sicil yalnız **Muhammet Fatih Kavak'ın hukuken sahip olduğu hakları** ileri sürer; üçüncü taraf veya korunamayan materyal üzerinde hak iddiası oluşturmaz.

## 6. Public-disclosure kayıt şablonu

Önemli yeni teknik yöntem için:

```text
Feature / yöntem:
Private review reference:
Patent classification: PUBLIC-SAFE / PRIVATE-REVIEW / PATENT-CANDIDATE
First public commit SHA:
First public date:
Rights holder / authorized contributors:
Third-party references:
Patent review outcome:
Trade-secret/NDA review:
```

## 7. Mevcut ana teknik kayıtlar

### V0.1 Material Core

- Neo-Hookean material core
- analytic tangent
- material-point FD verification
- Dyna project implementation

### V0.2 nonlinear FEM

- Q4 plane strain
- Full Newton / adaptive increment / rollback / cutback
- InternalMesh / integration-point result path
- stdlib/LAPACK adapter
- independent FEniCSx validation

### V0.3 nearly-incompressible bake-off

- displacement-only Q4 baseline
- mixed Q4/P0 research/verification formulation
- F-bar Q4 plane-strain production default — ADR-0007
- checkerboard null-mode benchmark
- severe-distortion affine benchmark
- performance baseline
- pressure-result semantics

**Not:** Bu kayıt patentlenebilirlik kararı değildir. Repository public olduğu için mevcut tekniklerin public-disclosure etkisi ayrı patent uzmanı incelemesine tabidir.

## 8. Release provenance kapısı

Her release için:

- [ ] `LICENSE` / `COPYRIGHT.md` güncel
- [ ] `THIRD_PARTY_NOTICES.md` güncel
- [ ] yeni dependency lisansları incelendi
- [ ] dış contributor agreement/provenance kontrol edildi
- [ ] patent/public-disclosure review yapıldı
- [ ] trade-secret/NDA kontrolü yapıldı
- [ ] secret/credential kontrolü yapıldı
- [ ] release commit/tag kaydı oluşturuldu

İlişkili politika: `docs/legal/PRE_DISCLOSURE_IP_GATE.md`.
