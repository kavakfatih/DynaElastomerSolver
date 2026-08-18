# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. Hedef; büyük deformasyonlu ve yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat güçlü, doğrulanmış ve açıklanabilir bir çözüm zinciri oluşturmaktır.

---

## V0.1 — Material Core

**Durum:** ✅ Tamamlandı

- Fortran 2018 / CMake
- finite-strain yardımcıları
- Neo-Hookean `W / P / Cauchy`
- analytic consistent tangent
- material-point + FD tangent

```text
Material tangent normalized FD error ≈ 1.26e-9
```

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

**Durum:** ✅ **TAMAMLANDI — V0.2.0**  
**Branch:** `release/v0.2`

- Q4 plane strain / 2×2 Gauss
- Total-Lagrangian residual/tangent
- global assembly
- Full Newton
- adaptive increment / cutback / rollback
- trial/commit/revert + convergence history
- nonlinear patch + mesh refinement
- `InternalMesh`
- raw integration-point results
- `kavakfatih/stdlib` / LAPACK dense solve
- backend-independent lineer solver API
- Newton lineer diagnostics
- severe-distortion + closed-form `J/P/W`
- FEniCSx/DOLFINx bağımsız dış FEM doğrulaması

Compiler matrix:

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS ARM64 / gfortran 14
- [x] Windows / gfortran 14
- [x] Windows 2022 / Intel ifx 2025.2

---

## V0.3 — Nearly-Incompressible Plane-Strain Production Baseline

**Durum:** 🟡 **TEKNİK EXIT CRITERIA TAMAMLANDI — RELEASE HAZIRLIĞI**  
**Branch:** `develop/v0.3`  
**CMake:** `0.3.0`  
**Draft PR:** `#1 — V0.3 — Nearly-Incompressible Formulation Bake-off`

PR #1 final entegrasyon/release kontrolü tamamlanmadan `main`e merge edilmez.

### Production formulation — ADR-0007

V0.3 bake-off üç formulationı karşılaştırdı:

1. displacement-only Q4
2. mixed Q4/P0 `u-p`
3. F-bar Q4

Karar:

```text
V0.3 plane-strain nearly-incompressible production default = F-bar Q4
Displacement-only Q4 = baseline / regression
Mixed Q4/P0 = experimental / verification; production değil
```

Gerekçe özeti:

- displacement-only Q4 volumetric locking gösterdi,
- mixed Q4/P0 displacement doğruluğuna rağmen checkerboard pressure null-mode riski gösterdi,
- F-bar Q4 dış Q2 referansa göre en düşük 8x8 displacement hatasını verdi,
- F-bar energy-consistent residual + analytic consistent tangent ile doğrulandı,
- dedicated severe-distortion benchmarkı dört platformda geçti,
- pressure/result semantics kod seviyesinde ayrıştırıldı.

### Platform önceliği ve resmi matrix

- **Windows x64 / Intel ifx — PRIMARY**
- **Windows x64 / gfortran — PRIMARY portability**
- **macOS Apple Silicon / gfortran — PRIMARY**
- Linux / gfortran — SECONDARY scientific CI
- Linux / FEniCSx — independent external reference

Güncel correctness paketi: **38 CTest**.

- [x] Windows 2022 / Intel ifx 2025.2 — 38/38
- [x] Windows / gfortran 14 — 38/38
- [x] macOS ARM64 / gfortran 14 — 38/38
- [x] Linux / gfortran 14 — 38/38
- [x] Linux F-bar performance benchmark
- [x] FEniCSx/DOLFINx external reference

Platform numerical reproducibility:

```text
Cook maksimum bağıl fark   ≈ 3.65e-14
Sweep maksimum bağıl fark  ≈ 1.39e-13
```

### Resmi Cook formulation bake-off

FEniCSx/DOLFINx Q2 32x32 dış referans:

```text
Tip displacement = 0.0201973648361
16x16 -> 32x32 = 0.846316%
configured convergence-aday threshold = 1.0%
```

Dyna 8x8:

| Formulation | Tip | Relative error | Equations | Newton/Linear |
|---|---:|---:|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% | 144 | 10/10 |
| Mixed Q4/P0 | 0.01915555105 | 5.16% | 208 | 10/10 |
| F-bar Q4 | 0.01940548609 | **3.92%** | 144 | 15/15 |

### Incompressibility sweep

Sabit 4x4 Cook mesh, `lambda/mu = 10 -> 1000` tip displacement kaybı:

```text
Displacement Q4 = 55.08%
Mixed Q4/P0     =  8.45%
F-bar Q4        =  8.38%
```

- [x] displacement locking davranışı ayrıştırıldı
- [x] mixed ve F-bar near-incompressible trendi doğrulandı
- [x] sonuçlar dört platformda numerical reproducibility kontrolünden geçti

### Mixed Q4/P0 stability kararı

CTest:

`benchmark.v0.3.mixed_up.checkerboard_null_mode`

```text
Checkerboard normalized coupling = 6.223551e-17
Probe normalized coupling        = 1.581139e-01
```

- [x] manufactured uniform-pressure doğrulaması
- [x] pressure roughness mesh trendi
- [x] checkerboard null-mode regression/decision testi
- [x] current Q4/P0 production default olmaktan çıkarıldı

Gelecekte bağımsız pressure unknown gerekiyorsa stabilizasyonlu veya inf-sup kararlı mixed interpolation ayrı benchmark ve ADR ile seçilecektir.

### F-bar Q4 production doğrulaması

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

- [x] energy-consistent element residual
- [x] Gauss-point volumetric coupling
- [x] analytic consistent tangent
- [x] Python cross-FD ≈ `8.73e-10`
- [x] GNU Fortran cross-FD ≈ `1.20e-9`
- [x] symmetry ≈ `2.45e-16`
- [x] global F-bar assembly
- [x] force-control Full Newton
- [x] Cook 2×2 / 4×4 / 8×8
- [x] independent FEniCSx Q2 comparison
- [x] dedicated severe-distortion affine benchmark

Severe-distortion resmi sonuç:

```text
Reference weight ratio      = 1.697222e-01
Exact affine free residual  = 1.518785e-13
Recovered displacement err  = 1.267320e-12
Final J / J_bar             = 1.0 / 1.0
```

### Results pressure semantics

- [x] gerçek kinematik `F,J` ile constitutive `F,J` ayrıldı
- [x] F-bar için `constitutive_F=F_bar`, `constitutive_J=J_bar`
- [x] derived pressure ve independent mixed pressure unknown source enumları ayrıldı
- [x] solver integration results yalnız yakınsamış final state için üretiliyor
- [x] non-affine contract regression testi eklendi

Pressure scalar:

```text
p_logJ = lambda * ln(constitutive_J)
```

Bu değer `-tr(sigma)/3` hidrostatik Cauchy basıncı değildir.

CTest:

`benchmark.v0.3.fbar.pressure_result_contract`

```text
local J range          = 4.272392e-02
J vs constitutive J    = 2.136196e-02
J_bar                  = 1.149200
Derived p_logJ         = 2.642255
```

### Büyük-mesh performans baseline'ı

Performans benchmarkı normal CTest correctness paketinden ayrıdır.

Linux/gfortran14 Debug baseline:

| Mesh | Free eq | Wall | Known dense matrix |
|---:|---:|---:|---:|
| 4x4 | 40 | 0.090 s | 0.043 MiB |
| 8x8 | 144 | 0.375 s | 0.517 MiB |
| 12x12 | 312 | 1.129 s | 2.357 MiB |
| 16x16 | 544 | 3.242 s | 7.064 MiB |

```text
Peak RSS ≈ 11.48 MiB
```

Wall-clock report-only'dir; sabit süre pass/fail eşiği uygulanmaz.

### V0.3 technical exit criteria

- [x] formulation bake-off
- [x] ADR-0007 production formulation kararı
- [x] 4-platform compiler matrix
- [x] platform numerical reproducibility
- [x] FEniCSx Q2 external reference
- [x] incompressibility sweep
- [x] mixed checkerboard risk kararı
- [x] F-bar severe-distortion robustness
- [x] wall-clock / bellek baseline altyapısı
- [x] Results pressure semantics

### V0.3 kalan işler — release hazırlığı

- [x] README güncel V0.3 kararlarıyla senkronize et
- [x] ROADMAP güncel V0.3 kararlarıyla senkronize et
- [ ] `V0.3_RELEASE_CHECKLIST.md` oluştur ve tamamla
- [ ] `V0.3_RELEASE_NOTES.md` oluştur
- [ ] PR #1 branch'ini güncel `main` ile senkronla
- [ ] PR #1 mergeability durumunu yeniden kontrol et
- [ ] release branch/tag stratejisini son kez doğrula
- [ ] final merge/release kararını kullanıcı onayından önce uygulama

---

## V0.4 — Axisymmetric Nonlinear Elastomer

**Başlangıç koşulu:** V0.3 release tamamlanmış olmalı.

- `ur, uz`
- full 3D axisymmetric deformation gradient
- hoop stretch
- `2πR` reference-volume integration
- axisymmetric `J / J_bar`
- energy-consistent F-bar residual
- analytic consistent tangent
- FD tangent validation
- homogeneous/patch benchmark
- mesh refinement
- reaction force
- independent external reference

**Kural:** plane-strain F-bar implementasyonu axisymmetric probleme doğrudan kopyalanmayacak; yeniden türetilecek ve bağımsız doğrulanacaktır.

---

## V0.5 — Axisymmetric Torsion / 2.5D

**Başlangıç koşulu:** V0.4 axisymmetric temel formulation doğrulanmış olmalı.

- `ur, uz, u_phi / φ`
- prescribed rotation
- full torsional kinematics
- `J / J_bar`
- reaction torque
- torque-angle
- torsional stiffness
- independent solver/reference benchmark
- fiziksel product-level torque/angle validation

---

## V0.6 — Hyperelastic Model Library

Öncelik:

1. Mooney-Rivlin
2. Yeoh
3. Ogden N1
4. Ogden N2/N3 ihtiyaç halinde
5. Arruda-Boyce / Gent ihtiyaç halinde

Her model:

```text
Energy → Stress → Consistent Tangent → FD → Material Benchmark → FEM Benchmark
```

---

## V0.7 — Material Calibration

```text
Experimental Data
→ PCHIP
→ Physical Objective
→ PRIMA BOBYQA / COBYLA
→ MINPACK Levenberg-Marquardt
→ Material Validation
```

---

## V0.8 — Production NonlinearSolutionManager

- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- divergence reasons
- `J` / distortion / pressure diagnostics
- backend-independent linear reports

Benchmark ihtiyacı gösterirse line search / Modified Newton / BFGS-Broyden.

---

## V0.9 — Minimum Engineering Workflow

- geometry adapters
- Gmsh → `InternalMesh`
- named boundaries
- mesh precheck
- result database
- pressure / stress / stretch / `J` / energy
- force/torque histories
- minimum Qt shell

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Başarı özellik sayısıyla değil; material-point, element, mesh convergence, incompressibility, robustness, bağımsız solver ve fiziksel test kanıtlarıyla ölçülür.

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
