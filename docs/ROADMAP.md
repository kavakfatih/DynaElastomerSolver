# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. Hedef; büyük deformasyonlu ve yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat güçlü, doğrulanmış ve açıklanabilir bir çözüm zinciri oluşturmaktır.

---

## V0.1 — Material Core / Bünye Doğrulama Temeli

**Durum:** Tamamlandı.

- Fortran 2018 / CMake
- precision/status
- finite-strain helpers
- Neo-Hookean `W / P / Cauchy`
- analytic consistent tangent
- material-point + FD tangent tests

Kanıt: material tangent normalized FD error ≈ `1.26e-9`.

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

**Durum:** ✅ **TAMAMLANDI — V0.2.0**  
**Branch:** `release/v0.2`

Tamamlananlar:

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
- [x] FEniCSx/DOLFINx bağımsız dış FEM doğrulaması
- [x] 20-test compiler matrix

Compiler matrix:

- [x] Ubuntu 24.04 / gfortran 14
- [x] macOS 26 ARM64 / gfortran 14
- [x] Windows / gfortran 14
- [x] Windows 2022 / Intel ifx 2025.2

Bağımsız FEM farkları:

```text
lambda_y   ≈ 2.00e-15
reaction_x ≈ 6.66e-16
J          ≈ 4.88e-15
total W    ≈ 5.72e-15
```

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

**Durum:** 🚧 **AKTİF GELİŞTİRME — V0.3.0**  
**Branch:** `develop/v0.3`

Amaç: production elastomer element teknolojisini varsayımla değil benchmark ile seçmek.

Karşılaştırılacak adaylar:

1. displacement-only Q4 — baseline
2. mixed displacement-pressure (`u-p`)
3. F-bar veya eşdeğer locking-reduction formulation

### Tamamlanan ilk altyapı

- [x] Q4 reference-edge traction integrasyonu
- [x] eğik edge / kuvvet korunumu / invalid-edge testleri
- [x] InternalMesh global edge-load assembly
- [x] fixed-increment force-control Full Newton benchmark driverı
- [x] analitik homojen traction referans testi
- [x] Cook-benzeri displacement-Q4 locking baseline benchmarkı
- [x] V0.3 branch için dört-compiler status-context CI altyapısı

V0.3 CTest tanımı: **24 test**.

### Sıradaki işler

- [ ] 24-test V0.3 compiler matrix sonucunu sabitle
- [ ] Cook baseline değerlerini kalıcı benchmark kaydına yaz
- [ ] minimum mixed `u-p` prototipini oluştur
- [ ] pressure DOF / block residual-tangent
- [ ] pressure stability ve checkerboard diagnostics
- [ ] aynı Cook benchmarkında mixed `u-p` sonucu
- [ ] F-bar Q4 prototipi
- [ ] displacement / mixed `u-p` / F-bar ortak karşılaştırma tablosu
- [ ] production formulation ADR kararı

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
