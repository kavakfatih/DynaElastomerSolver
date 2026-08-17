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

`newton_report_t` lineer çözüm katmanını da doğrudan raporlar:

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

## GitHub Actions compiler matrisi

Yeni workflow:

`/.github/workflows/fortran-ci.yml`

Matris:

1. Ubuntu 24.04 — gfortran 14
2. macOS 26 ARM64 — gfortran 14
3. Windows 2025 — gfortran 14
4. Windows 2025 — Intel ifx 2025.2

Workflow ayrıca:

- Python 3.12
- `fypp 3.2`
- pinlenmiş `kavakfatih/stdlib`
- Ninja
- CMake
- tüm CTest paketi

kullanır.

Reproducibility için GitHub Actions bağımlılıkları tam commit SHA ile sabitlenmiştir:

- `actions/checkout` v7.0.1 → `3d3c42e5aac5ba805825da76410c181273ba90b1`
- `actions/setup-python` v6.2.0 → `a309ff8b426b58ec0e2a45f0f869d46889d02405`
- `fortran-lang/setup-fortran` v1.9.0 → `2a1b9c55897d827a9dfeb114408f3615e53b2b72`

Workflow GitHub üzerinde aktif hale gelmiş ve gerçek matrix run'ları başlamıştır. **Compiler matrisi ancak tüm ilgili job'lar yeşil olduğunda tamamlanmış kabul edilecektir.**

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

### Severe-distortion + kapalı-form continuum benchmark

`test_q4_severe_distortion_solver`:

- 2×2 Q4 mesh
- merkez düğüm `X5 = (1.45, 0.55)` ile ciddi geometrik skew
- reference Gauss ağırlığı/Jacobian aralığı yaklaşık `0.07255 ... 0.42745`
- min/max oranı yaklaşık `0.1697`
- exact affine finite-strain:
  - `F11 = 1.35`
  - `F12 = 0.28`
  - `F21 = 0.12`
  - `F22 = 0.78`
  - `J = 1.0194`

Test artık FEM/material-response yolundan bağımsız kapalı-form Neo-Hookean referansı da hesaplar:

```text
W = mu/2 (I1 - 3) - mu ln(J) + lambda/2 [ln(J)]²
P = mu F + [lambda ln(J) - mu] F^{-T}
```

Referans yaklaşık değerler:

```text
P11 =  1.94662573
P12 =  1.01728835
P21 =  0.93367281
P22 = -0.83349393
P33 =  0.48035547
W   =  0.6597314365
```

Toplam referans alanı `4.0` olduğundan exact toplam strain energy yaklaşık `2.6389257461`.

Benchmark artık:

- merkez affine displacement
- global kuvvet dengesi
- 16 Gauss noktasındaki `F/J`
- weighted-average `P`
- toplam referans alanı
- toplam strain energy
- minimum `J`
- Newton/lineer solver diagnostics

kontrollerini birlikte yapar.

Ayrıntılı benchmark kataloğu:

`docs/verification/V0.2_REFERENCE_BENCHMARKS.md`

Mevcut CTest tanımı **20 test** içerir.

## V0.2 kapanışından önce kalan işler

1. GitHub Actions compiler matrisini tüm aktif job'larda yeşile getirmek.
2. 20/20 CTest'i gfortran/ifx matrisinde doğrulamak.
3. En az bir benchmarkı bağımsız dış FEM solver ile karşılaştırmak ve sürüm/ayarları kaydetmek.
4. Gerekirse severe-distortion/cutback benchmark setini bir örnek daha genişletmek.
5. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

### Son tamamlanan V0.2 maddeleri

- backend-bağımsız lineer solver sınırı
- Newton lineer solver diagnostics entegrasyonu
- InternalMesh üzerinden lineer backend seçimi
- terminal backend hatalarının adaptive cutback dışında tutulması
- severe geometrik distorsiyon nonlinear Q4 benchmarkı
- severe-distortion testine bağımsız kapalı-form `P/W/J` continuum referansı
- V0.2 benchmark kataloğu
- Linux/macOS/Windows gfortran + Windows ifx GitHub Actions compiler matrisi tanımı
- CI tool/action sürümlerinin pinlenmesi

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
