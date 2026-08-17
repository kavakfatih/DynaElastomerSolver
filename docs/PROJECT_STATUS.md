# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Ana ve sürekli güncellenen branch:** `main`

## Güncel geliştirme sürümü

**V0.2-dev — Nonlinear FEM Robustness**

Bu sürüm yayınlanmış ürün sürümü değil; aktif geliştirme kilometre taşıdır.

## Çalışan bilimsel çekirdek

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
- `convergence_history_t`
- minimum `J` takibi
- okunabilir solver/material hata açıklamaları

## V0.2 veri modeli

### Minimal `InternalMesh`

`internal_mesh_t` bilimsel çekirdeğin ilk kanonik mesh modelidir. Şimdilik yalnız 2B düğüm koordinatları, Q4 connectivity, node/element sayıları ve connectivity doğrulamasını taşır. Harici mesher/CAD tipleri bu sınıra geçirilmez.

### Ham integration-point sonuçları

`integration_point_result_t` / `integration_point_results_t` ile her Q4 Gauss noktasında:

- `element_id`, `point_id`
- `xi / eta`
- reference integration weight
- `F`
- `J`
- First Piola-Kirchhoff `P`
- Cauchy stress
- strain-energy density
- status / valid

saklanabilir. V0.2'de nodal extrapolation/averaging yapılmaz.

### InternalMesh solver adapteri

```text
InternalMesh
    ↓
Q4 Newton Solver Adapter
    ↓
mevcut doğrulanmış Full Newton solver
    ↓
Raw Integration-Point Results
```

Mevcut `X + connectivity` yolu regression amacıyla korunur.

## Lineer solver altyapısı

V0.2'de ilk backend-bağımsız Dyna lineer solver sınırı eklendi:

```text
Nonlinear Solver / FEM
        ↓
solve_linear_system(...)
        ↓
linear_solver_settings_t
linear_solver_report_t
        ↓
Backend
        └── stdlib/LAPACK dense  ← aktif
```

Yeni `des_linear_solver` modülü:

- backend kimliği
- denklem sayısı
- lineer residual infinity normu
- status
- converged bilgisi

taşır.

İlk backend `DES_LINEAR_BACKEND_STDLIB_DENSE` olup `stdlib_linalg::solve` üzerinden LAPACK `*GESV` ailesini kullanır.

`des_dense_linear` artık yalnız geriye dönük uyumluluk wrapper'ıdır; doğrudan stdlib ayrıntısı taşımaz. İleride MUMPS ve iterative/GMRES çözücüleri aynı Dyna sınırının arkasına eklenecektir.

Desteklenmeyen backend için `DES_ERROR_UNSUPPORTED_LINEAR_BACKEND` status kodu eklendi.

## Fortran kütüphane altyapısı

### Aktif dependency — Fortran stdlib

- Dyna fork: `https://github.com/kavakfatih/stdlib`
- upstream: `https://github.com/fortran-lang/stdlib`
- sürüm: `0.8.1`
- pinlenen commit: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`
- lisans: MIT; BLAS/LAPACK backend bölümlerinde ilgili modified-BSD koşulları
- build gereksinimi: `fypp`

### Planlanan/araştırılan kütüphaneler

- Reference-LAPACK/lapack — dense lineer cebir backend/referansı
- MUMPS — production sparse direct solver adayı
- stdlib GMRES — iterative solver benchmark/adayı
- fortran-lang/minpack — nonlinear least-squares / Levenberg-Marquardt
- libprima/prima — BOBYQA/COBYLA bounded/constrained optimization
- jacobwilliams/PCHIP — deneysel eğri interpolation/resampling
- HDF5 — büyük ResultDatabase/checkpoint
- JSON-Fortran — metadata/config
- FrontISTR — Fortran FEM/MUMPS entegrasyon referansı

Ayrıntılı envanter: `docs/references/FORTRAN_LIBRARIES.md`

## V0.7 calibration planı

```text
Raw Experimental Data
        ↓
PCHIP
        ↓
Objective + physical admissibility
        ↓
PRIMA BOBYQA / COBYLA
        ↓
MINPACK Levenberg–Marquardt
        ↓
Material validation
```

## Kanıtlanmış doğrulamalar

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- iki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- solver API final free residual: yaklaşık `5.4e-15`
- distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh refinement reaksiyonu: `1.605586`
- adaptive failure benchmark: `2 commit / 1 revert`
- cutback exhaustion sonrası committed state korunuyor
- InternalMesh ve eski assembly yolu residual/tangent açısından eşdeğer
- affine `F = diag(1.10, 0.95, 1.0)` için dört Gauss noktasında `J = 1.045`
- geçersiz duplicate-node Q4 mesh oluşturma aşamasında reddediliyor

Mevcut CTest tanımı **19 test** içerir. Yeni lineer solver interface testi normal çözümü, residual raporunu ve desteklenmeyen backend failure yolunu kapsar.

## Önemli doğrulama notu

`kavakfatih/stdlib` tabanlı tam dependency build ortamı bu çalışma ortamında henüz tam hazır olmadığı için 19/19 CTest toplu compiler-matrix doğrulaması V0.2 kapanış maddesi olarak korunmaktadır.

## V0.2 kapanışından önce kalan işler

1. stdlib tabanlı tam build'i GNU Fortran üzerinde 19/19 CTest ile doğrulamak.
2. Newton `newton_report_t` içine son lineer solver raporunu taşımak.
3. Ek nonlinear distortion / robustness benchmark'ları.
4. Bağımsız solver/reference karşılaştırmasını genişletmek.
5. macOS Apple Silicon + gfortran build/test.
6. Windows x64 + Intel ifx build/test.
7. Windows x64 + gfortran build/test.
8. Compiler matrisi üzerinde regression testlerini çalıştırmak.
9. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

### Bu turda tamamlanan V0.2 maddeleri

- backend-bağımsız `des_linear_solver`
- `linear_solver_settings_t`
- `linear_solver_report_t`
- aktif stdlib/LAPACK dense backend
- lineer residual raporlama
- unsupported-backend status/failure yolu
- eski `des_dense_linear` yolunun compatibility wrapper'a dönüştürülmesi
- lineer solver interface regression testi

---

## Sıradaki geliştirme sürümü

**V0.3 — Nearly-Incompressible Formulation Bake-off**

```text
Displacement-only Q4
        vs
Mixed u-p
        vs
F-bar / eşdeğer locking azaltıcı formulation
```

Karar; locking, pressure stability, mesh convergence, Newton convergence, distortion sensitivity, conditioning ve axisymmetric/torsion genişletilebilirliği üzerinden verilecektir.

## Branch güncelleme kuralı

Bu dosya ve diğer sürekli proje kayıtları varsayılan olarak yalnız `main` branch'inde güncellenir.

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
