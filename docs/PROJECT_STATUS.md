# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı — V0.2.0

- Branch: `release/v0.2`
- CMake: `0.2.0`
- Release metadata commit: `d9a960fb2b8cd9aac0018deb5b099cf68ddc062f`
- Durum: **tamamlandı**

V0.2, 20 CTest ile Ubuntu/gfortran14, macOS ARM64/gfortran14, Windows/gfortran14 ve Windows 2022/Intel ifx 2025.2 üzerinde doğrulandı. FEniCSx/DOLFINx bağımsız FEM karşılaştırması da geçti.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake: `0.3.0`
- Draft entegrasyon PR: **#1 — `V0.3 — Nearly-Incompressible Formulation Bake-off`**
- PR V0.3 exit criteria tamamlanmadan `main`e merge edilmeyecek.

Karşılaştırılan formulationlar:

```text
Displacement-only Q4
        vs
Mixed Q4/P0 u-p
        vs
F-bar Q4
```

**Production formulation henüz seçilmemiştir.**

---

## Hedef platform önceliği

1. **Windows x64 — birincil**
   - Intel ifx
   - gfortran portability
2. **macOS Apple Silicon — birincil**
   - gfortran
3. **Linux — ikincil bilimsel/CI ortamı**
   - gfortran
   - FEniCSx/DOLFINx dış referans

Linux ürün dağıtım önceliği değildir.

---

## V0.3 ortak benchmark ve ölçüm altyapısı

Tamamlananlar:

- Q4 reference-edge traction / 2-point Gauss
- skew-edge ve total-force conservation
- InternalMesh edge-load global assembly
- fixed-increment force-control Full Newton
- homogeneous analytic traction benchmark
- normalize Cook-benzeri 2x2 / 4x4 / 8x8 meshler
- final-state `J` ile historical Newton minimum `J` ayrımı
- Newton iteration / lineer solve / equation-count diagnostics
- mixed pressure diagnostics
- F-bar `J_bar` min/max diagnostics

### Birleşik üçlü Cook benchmarkı

`tests/test_v03_cook_bakeoff_compare.f90`

Üç formulation aynı executable içinde aynı mesh/material/yük/sınır şartı ile çözülür ve doğrudan:

`V0.3_COOK_BAKEOFF_RESULTS.json`

üretir.

JSON schema v3:

- tip displacement
- final minimum `J`
- Newton iteration
- lineer solve sayısı
- equation count
- mixed pressure mean/std/RMS/jump/graph roughness
- F-bar `J_bar` min/max
- coarse-to-8x8 convergence gap

`LastTest.log` parser artık ana sonuç üretim yolu değildir.

### Incompressibility sweep

Yeni test:

`tests/test_v03_incompressibility_sweep.f90`

Sabit 4x4 Cook mesh üzerinde:

```text
lambda/mu = 10 -> 100 -> 1000
```

sweep yapılır.

Bağımsız Python/NumPy precheck:

```text
lambda/mu      10          100         1000
Displacement   0.0132610   0.00744673  0.00595658
Mixed          0.0184132   0.01702588  0.01685744
F-bar          0.0191167   0.01768588  0.01751507
```

`lambda/mu=10 -> 1000` displacement kaybı:

```text
Displacement Q4 ≈ 55.08%
Mixed Q4/P0     ≈ 8.45%
F-bar Q4        ≈ 8.38%
```

`lambda/mu=1000` mixed–F-bar relative farkı ≈ `3.75%`.

Ham kayıt:

`docs/verification/results/V0.3_INCOMPRESSIBILITY_SWEEP_INDEPENDENT_PRECHECK.json`

Bu sonuç resmi Fortran CTest sonucu değildir; sweep regression eşiklerinin bağımsız ön doğrulamasıdır.

CTest tanımı artık **35 test**.

---

## Aday A — Displacement-only Q4

V0.2'den gelen full-integration baseline.

```text
mu = 1
lambda = 1000
traction_y = 0.01
```

Bağımsız Cook precheck, 8x8 displacement Q4 sonucunun F-bar displacementının yalnız yaklaşık `%33.8`'i seviyesinde kaldığını gösteriyor.

**Karar kuralı:** coarse-to-8x8 gap tek başına locking şiddeti değildir; 8x8 displacement Q4 çözümü de locked olabilir. Asıl hata converged dış Q2/FEniCSx referansına göre ölçülecek.

---

## Aday B — Mixed Q4/P0

```text
Psi(F,p) = mu/2(I1-3)
         - mu ln(J)
         + p ln(J)
         - p^2/(2 lambda)
```

Stationarity:

```text
p = lambda ln(J)
```

Tamamlanan zincir:

- 8 displacement + 1 P0 pressure DOF / element
- `Kuu/Kup/Kpu/Kpp`
- 9x9 consistent tangent
- local tangent FD error ≈ `1.74e-9`
- global mixed assembly
- mixed Full Newton force-control
- homogeneous analytic traction benchmark
- Cook 2x2 / 4x4 / 8x8
- incompressibility sweep

Pressure diagnostics:

- min/max/mean/std/RMS
- edge-neighbor graph
- neighbor jump RMS/max
- pressure-RMS normalized jump
- mean-free `neighbor_jump_to_std`
- `graph_roughness = (jump_rms/std)^2`

Manufactured homojen pressure benchmarkı:

```text
Exact J                   = 1.031600
Exact pressure            = 0.5911089
maximum pressure residual = 1.11e-16
pressure graph roughness  = 0.0
```

Bağımsız Cook precheck'te graph roughness:

```text
2.874 -> 0.976 -> 0.321
```

---

## Aday C — F-bar Q4

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Residual enerjinin ilk varyasyonu, tangent aynı enerjinin analitik ikinci varyasyonudur.

Doğrulama:

```text
Python derivation cross-FD ≈ 8.73e-10
Python symmetry            ≈ 1.90e-16
GNU Fortran cross-FD       ≈ 1.20e-9
GNU Fortran symmetry       ≈ 2.45e-16
```

Tamamlanan zincir:

- energy-consistent residual
- analitik consistent tangent
- homogeneous residual equivalence
- independent cross-FD + symmetry
- global F-bar assembly
- force-control Full Newton
- homogeneous traction benchmark
- Cook 2x2 / 4x4 / 8x8
- incompressibility sweep

---

## Bağımsız Cook precheck

Ham veri:

`docs/verification/results/V0.3_COOK_INDEPENDENT_PRECHECK.json`

Analiz:

`docs/verification/V0.3_COOK_PRECHECK_ANALYSIS.md`

Tip displacement:

| Mesh | Displacement Q4 | Mixed Q4/P0 | F-bar Q4 |
|---|---:|---:|---:|
| 2x2 | 0.00569117 | 0.01224824 | 0.01347320 |
| 4x4 | 0.00595658 | 0.01685744 | 0.01751507 |
| 8x8 | 0.00656453 | 0.01915555 | 0.01940549 |

Mixed ile F-bar relative tip farkı:

```text
2x2 -> 9.09%
4x4 -> 3.75%
8x8 -> 1.29%
```

Bu sonuç resmi Dyna Fortran/CTest sonucu değildir.

---

## Platform numerical reproducibility

Her compiler job'u kendi birleşik bake-off JSON artifactini saklayacak:

- Windows / Intel ifx
- Windows / gfortran
- macOS ARM64 / gfortran
- Linux / gfortran

`tools/verification/compare_v03_platform_results.py`:

- tip/final `J`/pressure/`J_bar` sonuçlarını tolerans içinde karşılaştırır
- equation count'u exact kontrol eder
- iteration/linear solve farklarını bilgi olarak raporlar

Amaç platformları yalnız build/CTest değil, **sayısal sonuç reproducibility** açısından da doğrulamaktır.

---

## Bağımsız V0.3 dış referans

`tools/reference/fenicsx_v03_cook_q2_reference.py`

Hedef:

- aynı Cook geometry/material/traction
- Q2 quadrilateral
- 2x2 / 4x4 / 8x8 / 16x16
- UFL automatic residual/Jacobian
- PETSc SNES + LU/MUMPS
- tip displacement
- continuum `p=lambda ln(J)` mean/std/RMS
- average `J`
- total energy

Workflow hazır; GitHub-hosted Actions pre-step engeli nedeniyle gerçek artifact henüz alınamadı.

---

## Açık CI engeli

GitHub-hosted Actions job'ları Windows, macOS, Linux ve FEniCSx workflow'unda runner step'leri başlamadan failure olmaktadır. Tek Linux rerun'ı da aynı davranışı gösterdi.

Bu nedenle mevcut hata Fortran/CMake/CTest seviyesine ulaşmış kod hatası olarak değerlendirilmemektedir.

---

## Sıradaki V0.3 adımları

1. GitHub-hosted Actions pre-step engelini çöz.
2. Windows/ifx + Windows/gfortran + macOS ARM64/gfortran **35-test** matrix'ini kapat.
3. Üç birincil platformun birleşik bake-off JSON'larını numerical reproducibility açısından karşılaştır.
4. FEniCSx Q2 2/4/8/16 dış referans artifactini al.
5. Dyna üç formulation'ı converged Q2 reference error ile değerlendir.
6. Mixed pressure roughness/continuum pressure karşılaştırmasını tamamla.
7. Convergence/robustness/maliyet tablosunu oluştur.
8. Production formulation ADR kararını ver.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: V0.3 draft entegrasyon görünürlüğü; exit criteria öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
