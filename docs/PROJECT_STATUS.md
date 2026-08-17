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
- rollback / cutback / retry
- reusable `solution_state_t`
- açık `trial → commit / revert` çözüm state akışı
- `convergence_history_t`
- minimum `J` takibi
- okunabilir solver/material hata açıklamaları

## V0.2 veri modeli

### Minimal `InternalMesh`

`internal_mesh_t` bilimsel çekirdeğin ilk kanonik mesh modelidir. Şimdilik yalnız 2B düğüm koordinatları, Q4 connectivity, node/element sayıları ve connectivity doğrulamasını taşır. Harici mesher/CAD tipleri bu sınıra geçirilmez.

### Ham integration-point sonuçları

`integration_point_result_t` / `integration_point_results_t` ile her Q4 Gauss noktasında `F`, `J`, First Piola-Kirchhoff `P`, Cauchy stress, strain-energy density, element/point kimliği, doğal koordinatlar ve status saklanabilir. V0.2'de nodal extrapolation/averaging yapılmaz.

### InternalMesh solver adapteri

```text
InternalMesh
    ↓
Q4 Newton Solver Adapter
    ↓
Full Newton / Adaptive Newton
    ↓
Dyna Linear Solver API
    ↓
Raw Integration-Point Results
```

Mevcut `X + connectivity` yolu regression amacıyla korunur.

## Lineer solver altyapısı

Backend-bağımsız Dyna lineer solver sınırı:

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

`newton_report_t` artık lineer çözüm katmanını da doğrudan raporlar:

- `linear_solve_count`
- `max_linear_equation_count`
- `max_linear_residual_inf_norm`
- `last_linear_report`

Hem fixed-step hem adaptive Newton doğrudan `solve_linear_system(...)` kullanır. `InternalMesh` solver adapterleri opsiyonel `linear_solver_settings_t` kabul eder. Desteklenmeyen backend gibi terminal konfigürasyon hataları Newton raporunda aynen korunur ve adaptive cutback ile tekrar denenmez.

## Fortran kütüphane altyapısı

### Aktif dependency — Fortran stdlib

- Dyna fork: `https://github.com/kavakfatih/stdlib`
- upstream: `https://github.com/fortran-lang/stdlib`
- sürüm: `0.8.1`
- pinlenen commit: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`
- build gereksinimi: `fypp`

Planlanan/araştırılan diğer araçlar: Reference LAPACK, MUMPS, stdlib GMRES, MINPACK, PRIMA, PCHIP, HDF5, JSON-Fortran ve FrontISTR. Ayrıntılı envanter: `docs/references/FORTRAN_LIBRARIES.md`.

## Kanıtlanmış / tanımlanmış doğrulamalar

Önceden geçen başlıca doğrulamalar:

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- iki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- solver API final free residual: yaklaşık `5.4e-15`
- distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh refinement reaksiyonu: `1.605586`
- InternalMesh ve eski assembly yolu residual/tangent açısından eşdeğer
- affine `F = diag(1.10, 0.95, 1.0)` için dört Gauss noktasında `J = 1.045`
- lineer solver interface normal çözüm, residual raporu ve unsupported-backend failure yolunu kapsıyor

### Yeni severe-distortion benchmark

Yeni `test_q4_severe_distortion_solver` şu senaryoyu tanımlar:

- 2×2 Q4 mesh
- merkez düğüm `X5 = (1.45, 0.55)` ile ciddi geometrik skew
- reference Gauss ağırlığı/Jacobian aralığı yaklaşık `0.07255 ... 0.42745`
- min/max oranı yaklaşık `0.1697`
- büyük affine finite-strain alanı:
  - `F11 = 1.35`
  - `F12 = 0.28`
  - `F21 = 0.12`
  - `F22 = 0.78`
  - beklenen `J = 1.0194`

Benchmark; merkez displacement'in affine referansı yeniden üretmesini, global kuvvet dengesini, 16 Gauss noktasındaki `F/J` değerlerini, `min J` davranışını ve Newton lineer residual diagnostics bilgisini kontrol eder.

Aynı denklemler bağımsız sayısal ön kontrolde 6 increment ve toplam 24 Newton düzeltmesiyle çözüldü; merkez displacement hatası yaklaşık `1.9e-14`, global kuvvet toplamları yaklaşık `1e-16` mertebesinde çıktı. Bu ön kontrol Dyna CTest'in yerine geçmez; yalnız benchmark tanımının matematiksel tutarlılığını kontrol eder.

Mevcut CTest tanımı artık **20 test** içerir.

## Önemli doğrulama notu

`kavakfatih/stdlib` tabanlı tam dependency build ortamı bu çalışma ortamında henüz tam hazır olmadığı için 20/20 CTest toplu compiler-matrix doğrulaması V0.2 kapanış maddesi olarak korunmaktadır.

## V0.2 kapanışından önce kalan işler

1. stdlib tabanlı tam build'i GNU Fortran üzerinde 20/20 CTest ile doğrulamak.
2. Bağımsız solver/reference karşılaştırmasını genişletmek.
3. Gerekirse severe-distortion/cutback benchmark setini bir örnek daha genişletmek.
4. macOS Apple Silicon + gfortran build/test.
5. Windows x64 + Intel ifx build/test.
6. Windows x64 + gfortran build/test.
7. Compiler matrisi üzerinde regression testlerini çalıştırmak.
8. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

### Son tamamlanan V0.2 maddeleri

- backend-bağımsız lineer solver sınırı
- Newton lineer solver diagnostics entegrasyonu
- InternalMesh üzerinden lineer backend seçimi
- terminal backend hatalarının adaptive cutback dışında tutulması
- severe geometrik distorsiyon için yeni nonlinear Q4 benchmark tanımı

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
