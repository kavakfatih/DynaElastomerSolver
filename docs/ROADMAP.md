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

Material tangent normalized FD error ≈ `1.26e-9`.

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
- 20-test dört-compiler matrix

Compiler matrix:

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS 26 ARM64 / gfortran 14
- [x] Windows / gfortran 14
- [x] Windows 2022 / Intel ifx 2025.2

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

**Durum:** 🚧 **AKTİF — V0.3.0**  
**Branch:** `develop/v0.3`  
**Draft PR:** `#1 — V0.3 — Nearly-Incompressible Formulation Bake-off`

PR #1 V0.3 exit criteria tamamlanmadan `main`e merge edilmez.

### Platform önceliği

- **Windows x64 / Intel ifx — birincil**
- **Windows x64 / gfortran — birincil portability**
- **macOS Apple Silicon / gfortran — birincil**
- Linux / gfortran — ikincil bilimsel CI
- Linux / FEniCSx — bağımsız FEM reference

Karşılaştırma:

1. displacement-only Q4
2. mixed Q4/P0 `u-p`
3. F-bar Q4

Production formulation henüz seçilmemiştir.

### Ortak benchmark altyapısı

- [x] Q4 reference-edge traction
- [x] skew-edge / force conservation tests
- [x] InternalMesh edge-load assembly
- [x] fixed-increment force-control Full Newton
- [x] homogeneous analytic traction benchmark
- [x] Cook-benzeri 2×2 / 4×4 / 8×8 benchmark
- [x] final-state `J` / historical Newton minimum `J` ayrımı
- [x] Newton / lineer solve / equation-count diagnostics
- [x] birleşik üçlü Cook benchmark executable'ı
- [x] doğrudan `V0.3_COOK_BAKEOFF_RESULTS.json` üretimi
- [x] JSON schema v3
- [x] her compiler job'unda doğrudan benchmark artifact'i
- [x] platform sonuç karşılaştırıcısı: `compare_v03_platform_results.py`
- [x] 4x4 Cook incompressibility sweep: `lambda/mu = 10/100/1000`

### Displacement-only baseline

- [x] near-incompressible Cook baseline
- [x] coarse-to-fine convergence trendi test yolu
- [x] bağımsız precheck'te güçlü locking sinyali
- [x] incompressibility sweep precheck: lambda10→1000 tip drop ≈ `55.08%`
- [ ] converged dış Q2/FEniCSx referansına göre gerçek relative error

**Karar kuralı:** coarse-to-8x8 gap tek başına locking metriği değildir; 8x8 Q4 çözümü de locked olabilir.

### Mixed Q4/P0

```text
Psi(F,p) = mu/2(I1-3) - mu ln(J) + p ln(J) - p^2/(2 lambda)
```

- [x] 8 displacement + 1 P0 pressure element DOF
- [x] `Kuu/Kup/Kpu/Kpp`
- [x] 9×9 tangent FD validation
- [x] local tangent error ≈ `1.74e-9`
- [x] homogeneous residual equivalence
- [x] global mixed assembly
- [x] mixed Full Newton force solver
- [x] analytic homogeneous traction benchmark
- [x] mixed Cook 2×2 / 4×4 / 8×8
- [x] incompressibility sweep precheck: lambda10→1000 tip drop ≈ `8.45%`

Pressure stability diagnostics:

- [x] min/max/mean/std/RMS
- [x] edge-neighbor graph
- [x] neighbor jump RMS/max
- [x] pressure-RMS normalized jump
- [x] mean-free `neighbor_jump_to_std`
- [x] `graph_roughness = (jump_rms/std)^2`
- [x] manufactured homojen zero-roughness benchmark
- [x] bağımsız precheck'te roughness trendi `2.874 -> 0.976 -> 0.321`
- [ ] independent continuum pressure-field reference comparison

### F-bar Q4

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

- [x] energy-consistent element residual
- [x] `J_bar` Gauss coupling'i residualda
- [x] analitik consistent tangent
- [x] homogeneous residual-equivalence test
- [x] independent cross-FD tangent doğrulaması
- [x] local GNU Fortran cross-FD error ≈ `1.20e-9`
- [x] local tangent symmetry error ≈ `2.45e-16`
- [x] global F-bar assembly
- [x] F-bar force-control Newton solver
- [x] homogeneous analytic traction benchmark
- [x] F-bar Cook 2×2 / 4×4 / 8×8
- [x] incompressibility sweep precheck: lambda10→1000 tip drop ≈ `8.38%`
- [x] lambda/mu=1000 mixed–F-bar relative tip farkı ≈ `3.75%`
- [ ] Windows/ifx platform doğrulaması
- [ ] Windows/gfortran platform doğrulaması
- [ ] macOS ARM64/gfortran platform doğrulaması

### Bağımsız Cook ve sweep precheck

Kayıtlar:

- `docs/verification/results/V0.3_COOK_INDEPENDENT_PRECHECK.json`
- `docs/verification/V0.3_COOK_PRECHECK_ANALYSIS.md`
- `docs/verification/results/V0.3_INCOMPRESSIBILITY_SWEEP_INDEPENDENT_PRECHECK.json`

8x8 tip displacement precheck:

```text
Displacement Q4 = 0.00656453
Mixed Q4/P0    = 0.01915555
F-bar Q4       = 0.01940549
```

Mixed–F-bar relative tip farkı:

```text
2x2 -> 9.09%
4x4 -> 3.75%
8x8 -> 1.29%
```

Bu precheck'ler resmi Fortran/CTest sonucu değildir; regression tasarımı ve beklenen fiziksel trend için bağımsız kanıttır.

### Platform numerical reproducibility

Her compiler job'u kendi birleşik bake-off JSON artifactini saklar:

- Windows / ifx
- Windows / gfortran
- macOS ARM64 / gfortran
- Linux / gfortran

`tools/verification/compare_v03_platform_results.py`:

- tip/final `J`/pressure/`J_bar` sonuçlarını tolerans içinde karşılaştırır
- equation count'u exact kontrol eder
- iteration/linear solve farklarını bilgi olarak raporlar

### Bağımsız V0.3 dış referans

FEniCSx / DOLFINx Q2 Cook reference:

- [x] `tools/reference/fenicsx_v03_cook_q2_reference.py`
- [x] aynı Neo-Hookean `mu=1`, `lambda=1000`
- [x] aynı normalize Cook geometry / traction
- [x] Q2 quadrilateral, meshler 2/4/8/16
- [x] UFL automatic residual/Jacobian
- [x] PETSc SNES + LU/MUMPS
- [x] tip displacement
- [x] continuum `p=lambda ln(J)` mean/std/RMS
- [x] `J` average / total energy / Newton iterations
- [x] `.github/workflows/fenicsx-v03-reference.yml`
- [ ] gerçek Actions sonucunu artifact olarak al
- [ ] Dyna Cook sonuçlarıyla ortak karşılaştırmayı kaydet

### CI engeli

GitHub-hosted job'lar şu anda runner step'leri başlamadan failure olmaktadır. Tek Linux rerun'ı da aynı pre-step failure davranışını göstermiştir.

Bu nedenle mevcut hata build/CTest seviyesine ulaşmamaktadır. GitHub Actions account/repository kullanımı veya runner provisioning engeli ayrıca çözülmelidir.

### Güncel test sayısı

**35 CTest tanımı**.

### Sıradaki V0.3 işleri

- [ ] GitHub-hosted Actions pre-step engelini çöz
- [ ] Windows/ifx + Windows/gfortran + macOS ARM64/gfortran 35-test matrix'i kapat
- [ ] üç birincil platform bake-off JSON'larını numerical reproducibility açısından karşılaştır
- [ ] FEniCSx Q2 2/4/8/16 dış referans artifactini al
- [ ] Dyna üçlü sonuçlarını converged Q2 referansına göre relative error ile değerlendir
- [ ] mixed pressure mean/std/RMS + graph roughness davranışını dış continuum pressure ile kıyasla
- [ ] üç formulation ortak mesh/convergence/robustness/maliyet tablosunu tamamla
- [ ] production formulation ADR kararı

Karar ölçütleri:

- dış referansa göre displacement hatası
- volumetric locking
- pressure stability / oscillation
- mesh convergence
- incompressibility-sweep sensitivity
- nonlinear convergence
- distortion sensitivity
- minimum final-state `J`
- DOF / matrix maliyeti
- lineer solve davranışı
- platform numerical reproducibility
- axisymmetric extensibility
- axisymmetric torsion extensibility

---

## V0.4 — Axisymmetric Nonlinear Elastomer

- `ur, uz`
- `2πR` integration
- seçilmiş incompressibility formulation
- reaction force
- bağımsız benchmark

## V0.5 — Axisymmetric Torsion / 2.5D

- `ur, uz, φ`
- prescribed rotation
- reaction torque
- torque-angle
- torsional stiffness
- bağımsız solver + fiziksel test

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

## V0.7 — Material Calibration

```text
Experimental Data
→ PCHIP
→ Physical Objective
→ PRIMA BOBYQA / COBYLA
→ MINPACK Levenberg-Marquardt
→ Material Validation
```

## V0.8 — Production NonlinearSolutionManager

- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- divergence reasons
- `J` / distortion / pressure diagnostics
- backend-independent linear reports

Benchmark ihtiyacı gösterirse line search / Modified Newton / BFGS-Broyden.

## V0.9 — Minimum Engineering Workflow

- geometry adapters
- Gmsh → `InternalMesh`
- named boundaries
- mesh precheck
- result database
- pressure / stress / stretch / `J` / energy
- force/torque histories
- minimum Qt shell

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Başarı özellik sayısıyla değil; material-point, element, mesh convergence, incompressibility, robustness, bağımsız solver ve fiziksel test kanıtlarıyla ölçülür.

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
