# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı sürüm — V0.2.0

- Branch: `release/v0.2`
- CMake sürümü: `0.2.0`
- Release metadata commit: `d9a960fb2b8cd9aac0018deb5b099cf68ddc062f`
- Bilimsel/compiler doğrulama kaynak commit'i: `eb30cd0997ff9329b508f43e8d5606af5ec5865a`
- Durum: **tamamlandı**

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

`main` doğrulanmış ana hat + sürekli proje kayıtlarıdır. Yeni fizik kodu `develop/v0.3` üzerinde geliştirilir.

---

## V0.2.0 kapanış özeti

V0.2 ile doğrulanan ana zincir:

- finite-strain Neo-Hookean material core
- analitik consistent material tangent
- Q4 plane-strain / 2×2 Gauss
- Total-Lagrangian residual/tangent
- global assembly
- Full Newton
- adaptive increment / rollback / cutback / retry
- committed/trial state + convergence history
- `InternalMesh`
- raw integration-point `F/J/P/Cauchy/W`
- backend-independent lineer solver API
- `kavakfatih/stdlib` / LAPACK dense backend
- Newton lineer diagnostics
- severe-distortion kapalı-form benchmark
- FEniCSx/DOLFINx bağımsız dış FEM doğrulaması

Ana kanıt seviyeleri:

```text
material tangent FD error ≈ 1.26e-9
element tangent FD error  ≈ 1.16e-9
2-element reaction error  ≈ 1e-15
final free residual       ≈ 5.4e-15
nonlinear patch error     ≈ 3.9e-17
```

FEniCSx karşılaştırması:

```text
lambda_y abs fark   ≈ 2.00e-15
reaction abs fark   ≈ 6.66e-16
J closed-form fark  ≈ 4.88e-15
energy farkı        ≈ 5.72e-15
```

V0.2 compiler matrix 20 CTest ile tamamlandı:

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS 26 ARM64 / gfortran 14
- [x] Windows / gfortran 14
- [x] Windows 2022 / Intel ifx 2025.2

Intel için `dyna/ifx-v02` status context'i success oldu; setup-fortran, smoke compile, configure, build ve CTest'in tamamı geçti.

---

# V0.3.0 — Aktif geliştirme

## A. Reference edge traction ve force-control altyapısı

Eklenenler:

- `des_q4_edge_traction.f90`
- `des_q4_mesh_edge_traction.f90`
- `des_q4_plane_strain_force_solver.f90`

Özellikler:

- Q4 dört yerel kenarı
- 2-point Gauss edge integration
- reference-configuration nominal traction
- skew edge desteği
- total force conservation
- element-edge → global-force scatter
- fixed-increment force-control Full Newton
- mevcut Dyna lineer solver API'si ve diagnostics

Yerel GNU Fortran 14.2 testlerinde element edge traction ve global edge-load assembly geçti.

## B. Displacement-only locking baseline

`test_v03_displacement_q4_locking_baseline.f90`

Cook-benzeri trapez panel:

- sol kenar ankastre
- sağ kenarda yukarı nominal traction
- `mu=1`
- `lambda=1000`
- 2×2 / 4×4 / 8×8 Q4

Amaç; displacement-only Q4'ün near-incompressible coarse-mesh stiffness davranışını aynı problemde sabitlemek.

## C. Mixed Q4/P0 prototipi

İlk mixed prototype artık elementten global Newton çözümüne kadar uygulanmıştır.

### Mixed enerji

Mevcut V0.2 Neo-Hookean fiziğini değiştirmeden pressure bağımsız değişkeni eklenmiştir:

```text
Psi(F,p) = mu/2 (I1 - 3)
         - mu ln(J)
         + p ln(J)
         - p^2/(2 lambda)
```

Pressure stationarity:

```text
ln(J) - p/lambda = 0
p = lambda ln(J)
```

Bu değer enerjiye geri koyulduğunda V0.2 compressible Neo-Hookean enerjisi aynen elde edilir. Böylece displacement-only ve mixed karşılaştırması farklı material law'lar arasında değildir.

### Mixed DOF yapısı

```text
[u1x,u1y,...,unx,uny | p1,p2,...,p_nelem]
```

- Q4 displacement: 8 element DOF
- P0 pressure: 1 element DOF

Block sistem:

```text
[ Kuu  Kup ] [du] = -[Ru]
[ Kpu  Kpp ] [dp]    [Rp]
```

### Eklenen mixed modüller

- `des_q4_plane_strain_mixed_up_neo_hookean.f90`
- `des_q4_plane_strain_mixed_up_mesh.f90`
- `des_q4_plane_strain_mixed_up_force_solver.f90`

### Mixed doğrulamalar

- 9×9 element consistent tangent merkezi finite-difference kontrolü
- yerel GNU Fortran 14.2 normalized tangent FD error ≈ **`1.74e-9`**
- homojen `p=lambda ln(J)` durumunda displacement residualının V0.2 Neo-Hookean residualını geri üretme testi
- global mixed assembly
- tangent symmetry kontrolü
- analitik homojen traction mixed force-control testi
- mixed Cook 2×2 / 4×4 / 8×8 baseline
- pressure `min/max/std` ölçümleri

Q4/P0 bu aşamada **production formulation değildir**. Pressure stability / oscillation ayrıca ölçülmeden herhangi bir seçim yapılmayacaktır.

## D. V0.3 benchmark dokümanı

`docs/verification/V0.3_INCOMPRESSIBILITY_BAKEOFF.md`

Bu dosyada:

- üç aday formulation
- ortak material law
- Cook geometry
- ortak metrikler
- pressure stability
- V0.3 çıkış kriterleri

sabitlenmiştir.

Resmi algoritmik referanslar arasında MOOSE volumetric-locking belgeleri ve MFEM incompressible nonlinear elasticity örneği kullanılmaktadır; Dyna kodu kendi implementasyonumuzdur.

## V0.3 test durumu

CTest tanımı artık **28 test** içerir.

Yerelde kesin doğrulanan yeni sonuç:

```text
Q4-P0 mixed 9x9 tangent FD error ≈ 1.74e-9
```

Tam `develop/v0.3` dört-compiler CI sonucu henüz kapanmış olarak işaretlenmemiştir.

---

## Aktif Fortran dependency

### Zorunlu

- `https://github.com/kavakfatih/stdlib`
- stdlib `0.8.1`
- pin: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

### Araştırılan / planlanan

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

1. 28-test dört-compiler matrix'i kesinleştir.
2. Displacement ve mixed Cook gerçek CI benchmark değerlerini kalıcı sonuç dosyasına yaz.
3. Pressure stability metriğini tanımla ve Q4/P0 sonucunu bağımsız referansla değerlendir.
4. Mixed formulation kabul/red kararını henüz vermeden F-bar türevini ortak material law üzerinde hazırla.
5. F-bar element tangent FD testini geçir.
6. Displacement / mixed / F-bar sonuçlarını aynı mesh ve metrik tablosunda karşılaştır.
7. Seçilen production formulation'ı bağımsız FEM solver ile yeniden doğrula.
8. Yalnız bundan sonra ADR ile production formulation kararını sabitle.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli proje kayıtları
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
