# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. Hedef; büyük deformasyonlu ve yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat güçlü, doğrulanmış ve açıklanabilir bir çözüm zinciri oluşturmaktır.

---

## V0.1 — Material Core / Bünye Doğrulama Temeli

**Durum:** Bilimsel çekirdek tamamlandı.

Tamamlananlar:
- Fortran 2018 / CMake
- precision/status
- finite-strain helpers
- Neo-Hookean `W / P / Cauchy`
- analytic consistent tangent
- material-point + FD tangent tests

Kanıt:
- material tangent normalized FD error ≈ `1.26e-9`.

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

**Durum:** `V0.2-dev — kapanış doğrulaması`

### Tamamlanan implementasyon

- [x] Q4 plane-strain baseline
- [x] 2×2 Gauss integration
- [x] Total-Lagrangian residual/tangent
- [x] element tangent FD
- [x] global assembly
- [x] Full Newton
- [x] adaptive increment
- [x] rollback / cutback / retry
- [x] trial / commit / revert
- [x] convergence history
- [x] status/failure diagnostics
- [x] nonlinear patch
- [x] mesh refinement
- [x] pinlenmiş `kavakfatih/stdlib`
- [x] stdlib/LAPACK dense solve
- [x] `InternalMesh`
- [x] connectivity validation
- [x] raw integration-point results
- [x] `F / J / P / Cauchy / W` Gauss outputs
- [x] InternalMesh Newton adapter
- [x] backend-independent linear solver API
- [x] Newton linear-solver diagnostics
- [x] severe-distortion benchmark
- [x] independent closed-form `J / P / W` reference
- [x] V0.2 benchmark catalogue
- [x] GitHub Actions compiler matrix
- [x] FEniCSx/DOLFINx independent external FEM validation

### Doğrulama zinciri

```text
Material point
→ material tangent FD
→ Q4 tangent FD
→ global assembly
→ Full Newton
→ adaptive recovery
→ InternalMesh
→ raw Gauss results
→ linear diagnostics
→ patch / mesh refinement
→ severe distortion
→ closed-form continuum
→ cross-compiler CI
→ independent FEniCSx FEM
```

### Bağımsız dış FEM

**Durum: GEÇTİ**

FEniCSx / DOLFINx `0.11.0.post0` ile homojen plane-strain extension yeniden çözüldü.

Dyna ↔ FEniCSx mutlak farkları:

```text
lambda_y   ≈ 2.00e-15
reaction_x ≈ 6.66e-16
```

FEniCSx ↔ closed-form:

```text
J            ≈ 4.88e-15
total energy ≈ 5.72e-15
```

Kayıt:
- `docs/verification/V0.2_EXTERNAL_FEM_VALIDATION.md`
- `docs/verification/results/FENICSX_V0.2_HOMOGENEOUS_EXTENSION.json`

### Compiler matrix

20 CTest:

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS 26 ARM64 / gfortran 14
- [x] Windows 2025 / gfortran 14
- [ ] Windows 2022 / Intel ifx 2025.2

ifx için Windows 2025 runner'ın VS2026'ya yönlendirilmesi nedeniyle job, GitHub'ın VS2022 uyumluluk yolu olan Windows 2022 runner'a taşındı ve CMake Visual Studio generator `-T fortran=ifx` ile doğrulanıyor.

### V0.2 kapanışında kalan tek büyük madde

- [ ] Windows 2022 / Intel ifx 2025.2 configure + build + 20 CTest

Bu tamamlandığında compiler matrix ve external FEM kriterleri birlikte kapanmış olacak; ardından V0.2 son exit-criteria kontrolü yapılacak.

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

Amaç: production elastomer element teknolojisini varsayımla değil benchmark ile seçmek.

Karşılaştırılacak adaylar:
1. displacement-only Q4 — baseline
2. mixed displacement-pressure (`u-p`)
3. F-bar veya eşdeğer locking-reduction formulation

Karar ölçütleri:
- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- minimum `J`
- DOF / assembly maliyeti
- linear-system conditioning
- axisymmetric extensibility
- axisymmetric torsion extensibility

Gerekli altyapı:
- mixed DOF
- block residual/tangent
- pressure diagnostics
- locking benchmark seti
- InternalMesh/results pressure extension
- Dyna linear-solver boundary üzerinden mixed-system benchmark

**Çıkış:** Production nearly-incompressible formulation benchmark kanıtıyla seçilir ve ADR ile sabitlenir.

---

## V0.4 — Axisymmetric Nonlinear Elastomer

- `ur, uz` kinematics
- `2πR` integration
- seçilmiş incompressibility formulation'ın axisymmetric türevi
- axisymmetric BC
- reaction force
- analitik + bağımsız solver benchmarkları

---

## V0.5 — Axisymmetric Torsion / 2.5D

Ana farklılaştırıcı kilometre taşlarından biri:
- `ur, uz, φ`
- prescribed rotation
- reaction torque
- torque–angle
- torsional stiffness
- pressure coupling gerektiğinde
- bağımsız solver + fiziksel test doğrulaması

---

## V0.6 — Hedef Hiperelastik Model Kütüphanesi

Öncelik:
1. Mooney-Rivlin
2. Yeoh
3. Ogden N1
4. Ogden N2/N3 ihtiyaç halinde
5. Arruda-Boyce / Gent ihtiyaç halinde

Her model:

```text
Energy
→ Stress
→ Consistent Tangent
→ FD Tangent
→ Material-point Benchmark
→ FEM Benchmark
```

---

## V0.7 — Minimum Calibration / Material Lab

Planlanan açık kaynak zincir:

```text
Experimental Data
→ PCHIP
→ Objective + Physical Admissibility
→ PRIMA BOBYQA / COBYLA
→ MINPACK Levenberg–Marquardt
→ Material Validation
→ Parameters + Metrics + Provenance
```

---

## V0.8 — Production NonlinearSolutionManager

V0.2'de gerçek ihtiyaçtan doğan mekanizmaların formulation-independent production seviyesi:
- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- convergence/divergence reason
- negative `J`
- distortion diagnostics
- mixed pressure diagnostics
- backend-independent linear report
- solver history

Benchmark ihtiyacı gösterirse:
- line search
- Modified Newton
- BFGS/Broyden
- predictor/recovery

---

## V0.9 — Minimum Mühendislik İş Akışı

- DXF / geometry adapters
- named boundaries
- Gmsh → `InternalMesh`
- mesh precheck
- raw results database
- displacement / stretch / stress / pressure / `J` / energy
- reaction force/torque
- torque–angle / force–displacement
- GaussPointInspector
- minimum Qt shell

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Birincil kapsam:
- quasi-static
- finite strain
- hyperelastic elastomer
- bonded metal–elastomer
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- prescribed displacement/rotation
- reaction force/torque
- validated nearly-incompressible formulation
- selected hyperelastic models

V1.0 dışında:
- general contact/friction
- self-contact
- debonding
- viscoelasticity
- Mullins/hysteresis
- fatigue/life/damage
- dynamics
- binary material plugin
- general CAD
- ANSYS/Marc feature parity

## Bilimsel geliştirme kuralı

```text
Teori
 ↓
Minimal implementation
 ↓
Unit / constitutive validation
 ↓
Element benchmark
 ↓
Mesh convergence
 ↓
Independent solver comparison
 ↓
Uygun olduğunda physical test
 ↓
Production scope
```

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
