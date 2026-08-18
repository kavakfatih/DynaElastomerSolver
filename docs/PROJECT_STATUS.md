# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı — V0.2.0

- Branch: `release/v0.2`
- CMake: `0.2.0`
- Release metadata commit: `d9a960fb2b8cd9aac0018deb5b099cf68ddc062f`
- Durum: **tamamlandı**

V0.2 20 CTest ile Ubuntu/gfortran14, macOS ARM64/gfortran14, Windows/gfortran14 ve Windows 2022/Intel ifx 2025.2 üzerinde doğrulandı. FEniCSx/DOLFINx bağımsız FEM karşılaştırması da geçti.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake: `0.3.0`
- Hedef: **Nearly-Incompressible Formulation Bake-off**

```text
Displacement-only Q4
        vs
Mixed Q4/P0 u-p
        vs
F-bar Q4
```

Production formulation henüz seçilmemiştir.

---

## V0.3 ortak benchmark altyapısı

Tamamlananlar:

- Q4 reference-edge traction / 2-point Gauss
- skew-edge ve total-force conservation testleri
- InternalMesh edge-load global assembly
- fixed-increment force-control Full Newton driver
- homogeneous analytic traction benchmark
- Cook-benzeri 2x2 / 4x4 / 8x8 locking benchmark geometrisi
- develop branch için dört-compiler CI status context'leri
- CI concurrency: yalnız en güncel `develop/v0.3` commit'i test edilir

## Aday A — Displacement-only Q4

V0.2'den gelen full-integration baseline Cook problemine bağlandı.

Material:

```text
mu = 1
lambda = 1000
```

BC:
- sol kenar ankastre
- sağ kenarda yukarı reference nominal traction

Amaç: near-incompressible coarse-mesh stiffness / volumetric-locking eğrisini sabitlemek.

## Aday B — Mixed Q4/P0

Ortak material law'u koruyan mixed potential:

```text
Psi(F,p) = mu/2 (I1-3)
         - mu ln(J)
         + p ln(J)
         - p^2/(2 lambda)
```

Stationarity:

```text
p = lambda ln(J)
```

Böylece V0.2 Neo-Hookean enerjisi geri elde edilir; karşılaştırmada material law değiştirilmez.

DOF:

```text
[u1x,u1y,...,unx,uny | p1,...,p_nelem]
```

Tamamlanan mixed zincir:

- 9x9 element residual/tangent
- merkezi FD tangent doğrulaması
- yerel GNU Fortran 14.2 tangent error ≈ `1.74e-9`
- global `Kuu/Kup/Kpu/Kpp` assembly
- mixed Full Newton force-control
- homogeneous analytic traction benchmark
- Cook 2x2 / 4x4 / 8x8 benchmark

### Pressure stability diagnostics

Yeni modül:

`src/fortran/results/des_pressure_diagnostics.f90`

Metrikler:

- min / max / mean
- standard deviation / RMS
- edge-neighbor pair count
- neighbor pressure-jump RMS
- maximum neighbor jump
- normalized neighbor-jump RMS

Yerel GNU Fortran 14.2 kontrolünde bilinen 2x2 pressure alanında neighbor graph ve jump RMS doğru üretildi; sabit pressure alanında jump sıfırlandı.

Bu metrikler tek başına checkerboard kararı değildir; mesh refinement ve bağımsız pressure-field reference ile birlikte değerlendirilecektir.

## Aday C — F-bar verification prototype

İlk F-bar prototipi artık elementten Cook benchmarkına kadar uygulanmıştır.

Volumetric correction:

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Dyna 3x3 deformation-gradient temsili kullanır; bu nedenle determinant düzeltmesi üç boyutlu volumetrik scaling ile yapılır.

### Energy-consistent residual

```text
E(u) = sum_g W(F_bar_g(u)) w_g
```

Residual bu enerjinin ilk varyasyonundan türetilmiştir; `J_bar` nedeniyle Gauss noktaları arasındaki coupling residualda korunur.

### Tangent durumu

İlk F-bar tangent'i merkezi finite-difference ile üretilmektedir. Bu **verification prototype** kararıdır; production seçimi F-bar yönünde çıkarsa analitik consistent tangent ayrıca türetilecektir.

Eklenen F-bar zincir:

- `des_q4_plane_strain_fbar_neo_hookean.f90`
- homogeneous residual equivalence testi
- cross-FD tangent + symmetry testi
- `des_q4_plane_strain_fbar_mesh.f90`
- global assembly
- `des_q4_plane_strain_fbar_force_solver.f90`
- homogeneous analytic traction benchmark
- F-bar Cook 2x2 / 4x4 / 8x8 benchmark

Algoritmik referans olarak MOOSE finite-strain volumetric-locking correction kaynakları incelendi; Dyna residual/tangent kodu kendi implementasyonumuzdur.

## V0.3 test durumu

CTest tanımı artık **32 test** içerir.

Kesin yerel doğrulamalar:

```text
Mixed Q4/P0 9x9 tangent FD error ≈ 1.74e-9
Pressure diagnostics unit test: geçti
Edge traction / global edge-load: geçti
```

F-bar için bağımsız sayısal ön kontrol olumlu yöndedir fakat Fortran dört-compiler CI sonucu görülmeden doğrulanmış Dyna sonucu olarak kaydedilmeyecektir.

Tam `develop/v0.3` dört-compiler CI sonucu henüz kapanmış olarak işaretlenmemiştir.

---

## V0.3 ayrıntılı tanım

`develop/v0.3`:

`docs/verification/V0.3_INCOMPRESSIBILITY_BAKEOFF.md`

Bu doküman:

- ortak material law
- displacement/mixed/F-bar varsayımları
- Cook geometry
- pressure diagnostics
- ortak karar metrikleri
- V0.3 exit criteria

içerir.

---

## Aktif Fortran dependency

Zorunlu:

- `https://github.com/kavakfatih/stdlib`
- stdlib `0.8.1`
- pin: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

Araştırılan/planlanan:

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

1. 32-test dört-compiler CI sonucunu kesinleştir.
2. Üç Cook formulation'ın gerçek Fortran sonuçlarını kalıcı JSON/tabloya yaz.
3. Mixed pressure neighbor-jump refinement trendini çıkar.
4. Mixed pressure alanını bağımsız FEM reference ile karşılaştır.
5. F-bar element tangent davranışını CI ve bağımsız FD ile doğrula.
6. Gerekirse F-bar analitik consistent tangent'i türet.
7. Displacement / mixed / F-bar için ortak mesh-convergence ve nonlinear-diagnostics tablosu oluştur.
8. Seçilen aday için bağımsız external solver doğrulaması yap.
9. Yalnız bundan sonra production formulation ADR kararını ver.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
