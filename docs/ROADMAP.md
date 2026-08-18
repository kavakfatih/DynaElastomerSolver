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
- element tangent FD
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
- [x] dört-compiler develop CI status contexts
- [x] branch concurrency / obsolete-run cancellation
- [x] CTest `LastTest.log` benchmark artifact yolu
- [x] başarılı Fortran benchmark stdout → ortak JSON parser

### Displacement-only baseline

- [x] near-incompressible Cook baseline
- [x] coarse-to-fine stiffness / locking trendi test yolu

### Mixed Q4/P0

Ortak V0.2 material law'u koruyan mixed potential:

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

Pressure stability diagnostics:

- [x] min/max/mean/std/RMS
- [x] edge-neighbor graph
- [x] neighbor jump RMS
- [x] maximum neighbor jump
- [x] pressure-RMS normalized neighbor jump
- [x] mean-free `neighbor_jump_to_std`
- [x] `graph_roughness = (jump_rms/std)^2`
- [x] **manufactured homojen zero-roughness benchmark**
  - exact `J = 1.0316`
  - exact `p = 0.5911089`
  - max pressure residual ≈ `1.11e-16`
  - graph roughness = `0`
- [ ] mesh-refinement roughness trendini gerçek Cook sonuçlarıyla sabitle
- [ ] independent pressure-field reference comparison

Q4/P0 hâlâ yalnız ilk mixed prototiptir.

### F-bar Q4

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

- [x] energy-consistent element residual
- [x] `J_bar` Gauss coupling'i residualda
- [x] **analitik consistent tangent**
- [x] homogeneous residual-equivalence test
- [x] independent cross-FD tangent doğrulaması
- [x] local GNU Fortran cross-FD error ≈ `1.20e-9`
- [x] local tangent symmetry error ≈ `2.45e-16`
- [x] global F-bar assembly
- [x] F-bar force-control Newton solver
- [x] homogeneous analytic traction benchmark
- [x] F-bar Cook 2×2 / 4×4 / 8×8 benchmark
- [ ] Windows/ifx platform doğrulaması
- [ ] Windows/gfortran platform doğrulaması
- [ ] macOS ARM64/gfortran platform doğrulaması

F-bar artık sayısal tangent prototipi değildir; analitik ikinci varyasyon uygulanmıştır. Production kararı yine yalnız ortak benchmark sonuçlarıyla verilecektir.

### Bağımsız V0.3 dış referans

FEniCSx / DOLFINx Q2 Cook reference yolu eklendi:

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

Bu Q2 çözüm production formulation değildir; Dyna'nın düşük dereceli Q4 formulationlarından bağımsız dış benchmarktır.

### CI engeli

Draft PR mergeable durumdadır. Ancak GitHub-hosted job'lar şu anda runner step'leri başlamadan failure olmaktadır. Tek Linux job rerun'ı da aynı pre-step failure davranışını göstermiştir.

Bu nedenle mevcut hata build/CTest seviyesine ulaşmamaktadır. GitHub Actions account/repository kullanımı veya runner provisioning engeli ayrıca çözülmelidir.

### Güncel test sayısı

**33 CTest tanımı**.

### Sıradaki V0.3 işleri

- [ ] GitHub-hosted Actions pre-step engelini çöz
- [ ] önce Windows + macOS birincil compiler matrix'i kapat
- [ ] F-bar analitik tangent ve mixed pressure uniformity testini üç birincil compiler hattında doğrula
- [ ] displacement / mixed / F-bar Cook gerçek Fortran değerlerini JSON olarak sabitle
- [ ] FEniCSx Q2 2/4/8/16 dış referans artifactini al
- [ ] Dyna tip displacement mesh trendini Q2 16x16 referansına göre değerlendir
- [ ] mixed pressure mean/std/RMS + graph roughness davranışını dış continuum pressure ile kıyasla
- [ ] üç formulation ortak mesh/convergence/robustness/maliyet tablosunu oluştur
- [ ] seçilen aday için bağımsız dış solver doğrulaması
- [ ] production formulation ADR kararı

Karar ölçütleri:

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- minimum `J`
- DOF / matrix maliyeti
- lineer solve davranışı
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
