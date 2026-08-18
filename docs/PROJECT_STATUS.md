# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı sürüm — V0.2.0

- Branch: `release/v0.2`
- CMake sürümü: `0.2.0`
- Release metadata commit: `d9a960fb2b8cd9aac0018deb5b099cf68ddc062f`
- Son bilimsel/compiler doğrulama kaynak commit'i: `eb30cd0997ff9329b508f43e8d5606af5ec5865a`

V0.2 kapanış kriterleri tamamlanmıştır.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake sürümü: `0.3.0`
- Hedef: **Nearly-Incompressible Formulation Bake-off**

```text
Displacement-only Q4
        vs
Mixed u-p
        vs
F-bar / eşdeğer locking azaltıcı formulation
```

`main` doğrulanmış ana hattır; yeni fizik kodu doğrudan `main` üzerinde geliştirilmez. Sürekli proje kayıtları ise kullanıcı kuralı gereği `main` üzerinde güncel tutulur.

---

## V0.2.0 — Kapanış doğrulaması

Bilimsel çekirdek:

- Modern Fortran 2018 + CMake
- finite strain kinematics
- compressible Neo-Hookean
- strain energy, First Piola-Kirchhoff ve Cauchy stress
- analitik consistent `dP/dF`
- Q4 plane-strain + 2×2 Gauss
- Total-Lagrangian residual/tangent
- global assembly
- Full Newton
- adaptive increment, rollback, cutback/retry
- committed/trial state
- convergence history
- `InternalMesh`
- raw integration-point results
- backend-bağımsız lineer solver sınırı
- `kavakfatih/stdlib` / LAPACK dense backend
- Newton lineer-solver diagnostics

Ana sayısal kanıtlar:

- material tangent FD normalize hata ≈ `1.26e-9`
- Q4 element tangent FD normalize hata ≈ `1.16e-9`
- iki elemanlı reaction relative error ≈ `1e-15`
- solver final free residual ≈ `5.4e-15`
- nonlinear patch merkez displacement error ≈ `3.9e-17`
- adaptive cutback final residual ≈ `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh reaction = `1.605586`
- severe-distortion kapalı-form `F/J/P/W` benchmarkı

### Bağımsız dış FEM doğrulaması

FEniCSx / DOLFINx `0.11.0.post0` ile bağımsız çözüm:

```text
Dyna lambda_y       = 0.8314690882666784
FEniCSx lambda_y    = 0.8314690882666764
abs fark            ≈ 2.00e-15

Dyna reaction       = 1.7423183105139586
FEniCSx reaction    = 1.7423183105139580
abs fark            ≈ 6.66e-16
```

Kapalı-form karşılaştırması:

```text
J farkı             ≈ 4.88e-15
total energy farkı  ≈ 5.72e-15
```

Kayıtlar:

- `docs/verification/V0.2_REFERENCE_BENCHMARKS.md`
- `docs/verification/V0.2_EXTERNAL_FEM_VALIDATION.md`
- `docs/verification/results/FENICSX_V0.2_HOMOGENEOUS_EXTENSION.json`

### Compiler matrix — TAMAMLANDI

V0.2 test paketi 20 CTest içerir.

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS 26 ARM64 / gfortran 14
- [x] Windows / gfortran 14
- [x] Windows 2022 / Intel ifx 2025.2

Intel doğrulaması için `dyna/ifx-v02` commit status context'i `success` üretmiştir. Bu context yalnız aşağıdaki adımların tamamı başarılı olduğunda `success` olur:

1. `setup-fortran` Intel ifx 2025.2
2. doğrudan ifx smoke compile
3. CMake configure
4. build
5. CTest

V0.2 böylece compiler kriteri dahil kapanmıştır.

---

## V0.3.0 — İlk implementasyon

Aktif branch: `develop/v0.3`

### 1. Q4 reference-edge traction

Yeni modül:

`src/fortran/fem/des_q4_edge_traction.f90`

Özellikler:

- dört Q4 yerel kenarı
- 2 noktalı Gauss edge integration
- referans-konfigürasyon nominal traction
- birim kalınlık
- eğik kenar geometrisi
- toplam kuvvet korunumu
- geçersiz edge ve sıfır uzunluklu edge diagnostics

Yeni durum kodu:

`DES_ERROR_INVALID_ELEMENT_EDGE = -203`

### 2. InternalMesh edge-load assembly

Yeni modül:

`src/fortran/fem/des_q4_mesh_edge_traction.f90`

Tek bir eleman kenarındaki traction global kuvvet vektörüne scatter edilir; birden fazla boundary edge ardışık çağrılarla biriktirilebilir.

### 3. Force-control Full Newton benchmark driver

Yeni modül:

`src/fortran/solvers/des_q4_plane_strain_force_solver.f90`

İlk kapsam bilinçli olarak küçüktür:

- reference external-force vector
- sıfır displacement fixed DOF'ları
- fixed increment load stepping
- Full Newton
- mevcut Dyna lineer solver API'si
- `newton_report_t` diagnostics
- reaction residual çıktısı

V0.2 displacement solver değiştirilmemiştir.

### 4. Analitik force-control referansı

`test_q4_force_control_solver.f90`

Tek Q4 homojen çekme probleminde traction değeri kapalı-form Neo-Hookean çözümden üretilir. Solver displacement, lateral contraction ve reaction ile aynı analitik çözüme dönmelidir.

### 5. Displacement-Q4 locking baseline

`test_v03_displacement_q4_locking_baseline.f90`

Cook-benzeri trapez panel:

- `mu = 1`
- `lambda = 1000`
- sağ kenarda yukarı nominal traction
- sol kenar ankastre
- 2×2 / 4×4 / 8×8 Q4 mesh

Amaç; displacement-only Q4'ün near-incompressible coarse-mesh stiffness davranışını ölçmek ve daha sonra mixed `u-p` ile F-bar sonuçlarını **aynı problem** üzerinde karşılaştırmaktır.

V0.3 CTest tanımı şu anda **24 testtir**.

Yerel GNU Fortran 14.2 doğrulamasında:

- Q4 element edge-traction testi geçti
- InternalMesh global edge-load assembly testi geçti

Force-control ve Cook benchmarkının tam stdlib/compiler-matrix sonucu `develop/v0.3` CI ile kesinleştirilecektir.

---

## Aktif Fortran dependency

### Zorunlu

- Dyna fork: `https://github.com/kavakfatih/stdlib`
- upstream: `https://github.com/fortran-lang/stdlib`
- stdlib: `0.8.1`
- pin: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

### Planlanan / incelenen

- Reference LAPACK
- MUMPS
- stdlib sparse / GMRES
- MINPACK
- PRIMA
- PCHIP
- HDF5
- JSON-Fortran
- FrontISTR

Ayrıntı: `docs/references/FORTRAN_LIBRARIES.md`

---

## Sıradaki V0.3 adımları

1. 24-test `develop/v0.3` compiler matrix sonucunu kapat.
2. Cook displacement-Q4 baseline sayısal değerlerini kalıcı benchmark kaydına yaz.
3. Minimum mixed displacement-pressure (`u-p`) element prototipini oluştur.
4. Aynı Cook benchmarkında pressure stability, displacement ve convergence ölç.
5. F-bar Q4 prototipini ekle.
6. Üç formulation'ı aynı metriklerle karşılaştır.
7. Production formulation kararını ancak benchmark sonucundan sonra ADR ile sabitle.

Karar ölçütleri:

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- Newton convergence
- distortion sensitivity
- minimum `J`
- lineer sistem conditioning / çözüm davranışı
- DOF maliyeti
- axisymmetric ve torsion genişletilebilirliği

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli proje kayıtları
- `release/v0.2`: geri dönülebilir V0.2.0 sürümü
- `develop/v0.3`: aktif V0.3 geliştirmesi
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
