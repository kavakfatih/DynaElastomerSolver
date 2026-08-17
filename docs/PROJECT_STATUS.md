# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-17  
**Ana ve sürekli güncellenen branch:** `main`

## Güncel geliştirme sürümü

**V0.2-dev — Nonlinear FEM Robustness**

Bu sürüm yayınlanmış bir ürün sürümü değil; aktif geliştirme kilometre taşıdır.

## Çalışan çekirdek

- Modern Fortran bilimsel çekirdek
- CMake build altyapısı
- finite-strain kinematics
- sıkıştırılabilir Neo-Hookean material model
- strain energy
- First Piola-Kirchhoff stress
- Cauchy stress
- analitik consistent material tangent `dP/dF`
- finite-difference tangent doğrulaması
- Q4 plane-strain element
- 2×2 Gauss integration
- Total-Lagrangian element residual
- consistent element tangent
- çok elemanlı Q4 global assembly
- incremental Full Newton displacement-control solver
- adaptive displacement-control solver
- rollback
- cutback / retry
- reusable `solution_state_t`
- açık `trial → commit / revert` çözüm state akışı
- `convergence_history_t` ile attempt/iteration geçmişi
- load factor / increment size / residual / minimum `J` history kaydı
- accepted increment kayıtları
- cutback exhaustion tanısı
- açık material/FEM/solver status kodları
- `des_status_message()` ile okunabilir hata açıklamaları
- minimum `J` takibi
- Newton iteration/increment raporlaması

## Fortran kütüphane altyapısı

### Aktif kullanılan dependency

**Fortran stdlib — `kavakfatih/stdlib`**

- repo: `https://github.com/kavakfatih/stdlib`
- sürüm: `0.8.1`
- pinlenen commit: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`
- lisans: MIT; BLAS/LAPACK backend bölümlerinde ilgili modified-BSD koşulları da geçerlidir
- build gereksinimi: `fypp`

Dyna CMake zinciri stdlib'i pinlenmiş commit üzerinden `FetchContent` ile alacak şekilde güncellenmiştir.

İlk gerçek kullanım:

```text
des_dense_linear
      ↓
stdlib_linalg::solve
      ↓
LAPACK *GESV backend
```

Önceki elle yazılmış Gaussian-elimination doğrulama çözücüsü kaldırılmıştır. `test_dense_linear` artık hem normal çözümü hem de singular sistemde stdlib error-state yolunun Dyna tarafından kontrollü biçimde `ok=.false.` olarak ele alınmasını test eder.

Ayrıntılı kütüphane envanteri:
- `docs/references/FORTRAN_LIBRARIES.md`

### Sonraki güçlü adaylar

- `stdlib_sparse` — COO/CSR/CSC ve sparse veri yapıları
- stdlib GMRES — benchmark/iterative solver araştırması
- MUMPS 5.9.1 — production sparse direct solver adayı
- modernized MINPACK — Material Calibration / Levenberg–Marquardt adayı
- HDF5 — büyük `ResultDatabase` / integration-point verisi / checkpoint adayı
- JSON-Fortran — metadata/config adayı
- FrontISTR — permissive MIT lisanslı FEM/MUMPS entegrasyon kod referansı

## Kanıtlanmış doğrulamalar

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- İki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- Solver API final free residual: yaklaşık `5.4e-15`
- Distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- Adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh refinement reaksiyonu: `1.605586`
- Adaptive failure benchmark'ında 2 commit / 1 revert beklenen akışla eşleşti
- Convergence history içinde non-positive `J` failure olayı korunarak kaydedildi
- `max_cutbacks=0` testinde trial state dışarı sızmadan committed state'e rollback doğrulandı
- Cutback exhaustion sırasında alt failure nedeni `DES_ERROR_NONPOSITIVE_J` olarak korundu
- `des_status_message()` durum açıklama testi geçti

State/history ve durum mesajı değişiklikleri GNU Fortran **14.2.0** ile yerel olarak doğrulanmıştır.

**Önemli doğrulama notu:** stdlib dependency entegrasyonu bu turda kaynak/API ve build-konfigürasyonu seviyesinde uygulanmıştır; bu çalışma ortamında `fypp` ve dış ağ erişimi bulunmadığı için yeni stdlib tabanlı build henüz tam CTest/compiler matrisi üzerinde çalıştırılmış sayılmaz. Bu doğrulama V0.2 kapanışının zorunlu maddesidir.

## Adaptive failure senaryosu

```text
%100 ilk increment
      ↓
non-positive J
      ↓
trial state reddedildi
      ↓
revert → committed state
      ↓
%50 cutback
      ↓
retry
      ↓
commit
      ↓
ikinci kabul edilmiş increment
      ↓
commit
      ↓
%100 final yük seviyesi
```

Bu zincir reusable `solution_state_t` üzerinden çalışır.

## Convergence history yapısı

Her Newton değerlendirmesinde aşağıdaki bilgiler saklanabilir:

- attempt numarası
- iteration numarası
- target load factor
- increment size
- residual norm
- minimum `J`
- status code
- increment'in kabul edilip edilmediği

Bu kayıt, ileride Results/Solver paneli ile `DivergenceReason` ve otomatik recovery kararlarının veri kaynağı olacaktır.

## V0.2 kapanışından önce kalan işler

1. Yeni stdlib tabanlı build'i GNU Fortran üzerinde tam CTest ile doğrulamak.
2. Ek nonlinear distortion ve robustness benchmark'ları.
3. Minimal `Node / Element / InternalMesh` veri modelini gerçek mesh akışına taşımak.
4. Ham integration-point result saklama yolunu eklemek.
5. V0.2 için bağımsız solver/reference karşılaştırmasını genişletmek.
6. macOS Apple Silicon + gfortran doğrulaması.
7. Windows x64 + Intel ifx doğrulaması.
8. Windows x64 + gfortran doğrulaması.
9. Tüm CTest paketini compiler matrisi üzerinde çalıştırmak.
10. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

### Tamamlanmış V0.2 sağlamlık maddeleri

- committed/trial çözüm state'i
- convergence history
- cutback exhaustion / retry limit tanısı
- başarısız trial state'in güvenli rollback'i
- failure status için okunabilir açıklama katmanı
- stdlib'in Dyna dependency sistemine pinlenmiş entegrasyonu
- dense doğrulama solver yolunun `stdlib_linalg` arayüzüne taşınması

---

## Sıradaki geliştirme sürümü

**V0.3 — Nearly-Incompressible Formulation Bake-off**

Amaç: elastomer için production element formulasyonunu varsayımla değil, aynı benchmark setinde karşılaştırarak seçmek.

### Karşılaştırılacak yollar

```text
Displacement-only Q4
        vs
Mixed u-p
        vs
F-bar / eşdeğer locking azaltıcı formulasyon
```

### Karar ölçütleri

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear Newton convergence
- distortion sensitivity
- minimum `J` davranışı
- DOF maliyeti
- assembly karmaşıklığı
- linear-system conditioning
- axisymmetric'e genişletilebilirlik
- axisymmetric torsion / 2.5D'ye genişletilebilirlik

### V0.3 çıkış kriteri

Production nearly-incompressible elastomer formulation, ölçülmüş benchmark sonuçlarıyla seçilecek ve yeni bir ADR ile sabitlenecektir.

---

## V0.3 sonrasındaki ana sıra

1. **V0.4 — Axisymmetric Nonlinear Elastomer**
2. **V0.5 — Axisymmetric Torsion / 2.5D**
3. **V0.6 — Hedef Hyperelastic Model Library**
   - Mooney-Rivlin
   - Yeoh
   - Ogden
4. Material calibration / Material Lab
5. Production solver robustness genişlemesi
6. Results pipeline uygulaması
7. Gerekli seviyede Qt frontend implementasyonu

## V1.0 ana hedefi

DynaElastomerSolver V1.0'ın hedefi genel amaçlı ANSYS/Marc feature parity değildir.

Hedef:

> Bonded metal–elastomer sistemlerinde, büyük deformasyonlu quasi-static plane-strain / axisymmetric / axisymmetric-torsion problemlerini seçilmiş ve doğrulanmış hiperelastik modeller ile güvenilir şekilde çözmek; sonuçları bağımsız solver ve fiziksel ürün testleriyle tanımlı mühendislik toleransları içinde doğrulamak.

## V1.0 kapsam dışı

- frictional contact
- separation
- self-contact
- debonding
- viskoelastisite
- Mullins effect
- fatigue / life prediction
- damage mechanics
- transient / harmonic / explicit dynamics
- binary User Material Plugin
- genel amaçlı CAD

## Branch güncelleme kuralı

Bu dosya ve diğer sürekli proje kayıtları varsayılan olarak yalnız `main` branch'inde güncellenir.

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
