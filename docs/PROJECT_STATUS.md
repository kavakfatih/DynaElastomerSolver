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
- birleşik üçlü Cook benchmark executable'ı
- `lambda/mu = 10/100/1000` incompressibility sweep benchmarkı

### Birleşik üçlü Cook benchmarkı

`tests/test_v03_cook_bakeoff_compare.f90`

Displacement Q4, mixed Q4/P0 ve F-bar aynı executable içinde aynı mesh/boundary/material/yük altında çözülür.

Test doğrudan:

`V0.3_COOK_BAKEOFF_RESULTS.json`

üretir. JSON schema v3:

- tip displacement
- final minimum `J`
- Newton iteration
- lineer solve sayısı
- equation count
- mixed pressure mean/std/RMS/jump/graph roughness
- F-bar `J_bar` min/max
- coarse-to-8x8 convergence gap

`tools/verification/parse_v03_bakeoff_log.py` yedek log-parser yoludur. F-bar metadata'sı güncel formulation ile eşitlendi:

```text
formulation = fbar_q4
tangent = analytic_energy_consistent_second_variation
```

CTest tanımı artık **35 test**.

---

## Aday A — Displacement-only Q4

V0.2'den gelen doğrulanmış full-integration baseline.

```text
mu = 1
lambda = 1000
traction_y = 0.01
```

Amaç displacement-only Q4'ün nearly-incompressible durumda volumetric-locking davranışını ölçmek.

**Önemli:** coarse-to-8x8 gap tek başına locking şiddeti kabul edilmeyecek. 8x8 displacement Q4 çözümü de locked olabilir. Asıl hata dış converged Q2/FEniCSx referansına göre ölçülecek.

---

## Aday B — Mixed Q4/P0

Mixed potential:

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
- Cook çözümünde element pressure consistency: `p_e = lambda <ln J>_e`

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

Bu exact sıfır-roughness referansıdır; Cook dış pressure doğrulamasının yerine geçmez.

---

## Aday C — F-bar Q4

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Element enerjisi:

```text
E(u) = sum_g W(F_bar_g(u)) w_g
```

Residual enerjinin ilk varyasyonu, tangent ise aynı enerjinin analitik ikinci varyasyonudur.

Analitik consistent tangent doğrulaması:

```text
Python derivation/reference:
normalized cross-FD error ≈ 8.73e-10
symmetry error            ≈ 1.90e-16

GNU Fortran 14.2 local:
max normalized cross-FD   ≈ 1.20e-9
symmetry error            ≈ 2.45e-16
```

Tamamlanan zincir:

- energy-consistent residual
- analitik consistent tangent
- homogeneous residual equivalence
- independent cross-FD + symmetry
- global F-bar assembly
- force-control Full Newton
- analytic homogeneous traction benchmark
- Cook 2x2 / 4x4 / 8x8

Windows/macOS platform doğrulaması GitHub Actions engeli çözüldükten sonra ayrıca yapılacak.

---

## Bağımsız Cook precheck

CI engelinden bağımsız ikinci bir Python/NumPy FEM implementasyonu ile aynı Cook problemi çözüldü.

Ham veri:

`docs/verification/results/V0.3_COOK_INDEPENDENT_PRECHECK.json`

Analiz:

`docs/verification/V0.3_COOK_PRECHECK_ANALYSIS.md`

Tip displacement precheck:

| Mesh | Displacement Q4 | Mixed Q4/P0 | F-bar Q4 |
|---|---:|---:|---:|
| 2x2 | 0.00569117 | 0.01224824 | 0.01347320 |
| 4x4 | 0.00595658 | 0.01685744 | 0.01751507 |
| 8x8 | 0.00656453 | 0.01915555 | 0.01940549 |

Sinyaller:

- 8x8 displacement Q4, F-bar displacementının yaklaşık `%33.8`'i seviyesinde.
- mixed ile F-bar relative tip farkı `9.09% -> 3.75% -> 1.29%` azalıyor.
- mixed pressure graph roughness `2.874 -> 0.976 -> 0.321` azalıyor.

Bu sonuçlar **resmi Dyna Fortran/CTest sonucu değildir** ve production kararını tek başına belirlemez.

### Precheck düzeltme kaydı

Geçici ikinci cross-check sırasında parent→reference gradient dönüşümünde `J^{-1}` yönü yanlış uygulanmıştı. Bu geçici sonuçlar repodan kaldırıldı. Doğru dönüşüm Fortran `reference_gradient` ile aynı `J^{-T}` yönündedir ve yukarıdaki mevcut independent-precheck sonuçlarını yeniden üretmiştir.

---

## Incompressibility sweep

Yeni regression:

`tests/test_v03_incompressibility_sweep.f90`

4x4 Cook meshinde:

```text
lambda/mu = 10, 100, 1000
```

üç formulation aynı yük altında çözülür.

Bağımsız doğru-gradient precheck:

| lambda/mu | Displacement Q4 | Mixed Q4/P0 | F-bar Q4 |
|---:|---:|---:|---:|
| 10 | 0.01326101 | 0.01841319 | 0.01911670 |
| 100 | 0.00744673 | 0.01702588 | 0.01768588 |
| 1000 | 0.00595658 | 0.01685744 | 0.01751507 |

`lambda/mu = 10 -> 1000`:

```text
Displacement tip drop ≈ 55.08 %
Mixed tip drop        ≈  8.45 %
F-bar tip drop        ≈  8.38 %
Mixed/F-bar farkı @1000 ≈ 3.75 %
```

Ham precheck:

`docs/verification/results/V0.3_INCOMPRESSIBILITY_SWEEP_PRECHECK.json`

Bu benchmark displacement-only Q4'ün nearly-incompressible sınıra giderken belirgin yapay rijitleşmesini doğrudan `lambda/mu` ekseninde ölçer.

---

## Platform sonuç artifactleri

`.github/workflows/fortran-ci.yml` birleşik Fortran benchmark JSON'unu her compiler job'unda artifact olarak saklayacak şekilde düzenlenmiştir:

- Windows / Intel ifx
- Windows / gfortran
- macOS ARM64 / gfortran
- Linux / gfortran

Karşılaştırıcı:

`tools/verification/compare_v03_platform_results.py`

Amaç platformlar arasında `tip`, final `J`, pressure ve `J_bar` sayısal reproducibility kontrolüdür.

---

## Bağımsız V0.3 dış referans

`tools/reference/fenicsx_v03_cook_q2_reference.py`

Hedef:

- aynı Cook geometri/material/yük
- Q2 quadrilateral displacement
- 2x2 / 4x4 / 8x8 / 16x16
- UFL automatic residual/Jacobian
- PETSc SNES + LU/MUMPS
- tip displacement
- continuum `p=lambda ln(J)` mean/std/RMS
- average `J`
- total energy

Workflow hazır; fakat GitHub-hosted Actions job'ları şu an runner step'leri başlamadan failure olduğu için gerçek dış referans artifact'i henüz alınamadı.

---

## Açık CI engeli

GitHub-hosted Actions job'ları Windows, macOS, Linux ve FEniCSx workflow'unda runner step'leri başlamadan failure olmaktadır. Tek Linux rerun'ı da aynı pre-step failure davranışını gösterdi.

Bu nedenle mevcut hata Fortran/CMake/CTest seviyesine ulaşmış bir kod hatası olarak değerlendirilmemektedir. Repository/account Actions kullanımı veya runner provisioning tarafı ayrıca çözülmelidir.

---

## Sıradaki V0.3 adımları

1. GitHub-hosted Actions pre-step engelini çöz.
2. Önce Windows/ifx + Windows/gfortran + macOS ARM64/gfortran **35-test** matrix'ini kapat.
3. Üç birincil platformun birleşik bake-off JSON'larını `compare_v03_platform_results.py` ile karşılaştır.
4. Incompressibility sweep regressionını üç birincil platformda doğrula.
5. FEniCSx Q2 2/4/8/16 Cook dış referans artifactini al.
6. Dyna displacement/mixed/F-bar sonuçlarını converged Q2 referansına göre hata metriğiyle değerlendir.
7. Mixed pressure mean/std/RMS + graph roughness trendini continuum pressure reference ile kıyasla.
8. Üç formulation için ortak convergence/robustness/maliyet tablosunu tamamla.
9. Seçilen adayı bağımsız solver ile son kez doğrula.
10. Production formulation ADR kararını ver.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: V0.3 draft entegrasyon görünürlüğü; exit criteria öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
