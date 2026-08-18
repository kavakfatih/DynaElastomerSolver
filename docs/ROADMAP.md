# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana mimari karar:** ADR-0008 — Herrmann / stable mixed `u-p` ana production yolu  
**İkincil formulation:** F-bar — bağımsız cross-check ve nearly-incompressible alternatif

DynaElastomerSolver genel amaçlı bir CAE kopyası değildir. Hedef; büyük deformasyonlu elastomer problemlerinde dar fakat güçlü, doğrulanmış ve açıklanabilir bir çözüm zinciri kurmaktır. Axisymmetric-with-torsion bu ana hedeflerden biridir; projenin tek hedefi değildir.

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

**Durum:** ✅ TAMAMLANDI — V0.2.0  
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
- backend-independent linear solver API
- severe-distortion doğrulaması
- FEniCSx/DOLFINx bağımsız FEM referansı

---

## V0.3 — Nearly-Incompressible Formulation Foundation

**Durum:** 🟡 GELİŞTİRME YENİDEN AÇILDI  
**Branch:** `develop/v0.3`  
**CMake:** `0.3.0`  
**Draft PR:** `#1`

### Tarihsel V0.3 bake-off — geçerli kanıt

İlk V0.3 çalışmasında aynı Cook problemi üzerinde:

| Formulation | 8×8 tip | Q2 32×32 göre hata |
|---|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% |
| Mixed Q4/P0 | 0.01915555105 | 5.16% |
| F-bar Q4 | 0.01940548609 | 3.92% |

F-bar daha sonra mesh incelmesiyle:

```text
8×8 relative error  ≈ 3.9207%
16×16 relative error ≈ 0.9083%
```

seviyesine inmiştir. Bu sonuç F-bar'ın güçlü ve geçerli bir formulation olduğunu gösterir ve regression/cross-check hattında korunur.

Mevcut Q4/P0 mixed prototip ise checkerboard pressure coupling riskini göstermiştir:

```text
checkerboard normalized K_up coupling ≈ 6.22e-17
mean-zero probe coupling              ≈ 1.58e-01
```

Bu nedenle mevcut Q4/P0 **as-is production değildir**.

### ADR-0008 ile yeni ana yön

```text
PRIMARY:
  Herrmann / stable mixed u-P element family

FIRST HIGH-ORDER CANDIDATE:
  Q8 serendipity displacement
  + 3 element-internal linear pressure DOF

SECONDARY / CROSS-CHECK:
  F-bar element family

BASELINE / REGRESSION:
  displacement-only family
```

ANSYS PLANE183 ve Hexagon Marc Herrmann element yaklaşımı davranış/benchmark referansıdır. Dyna'nın residual, tangent, interpolation, assembly ve solver kodu bağımsız geliştirilir.

### H0 — Q8 + pressure interpolation + block/DOF foundation

- [x] Q8 serendipity displacement shape functions
- [x] 3-DOF lineer pressure-space ilk adayı
- [x] partition-of-unity / Kronecker / derivative identity testleri
- [ ] Q8 isoparametric geometry/Jacobian/gradient contract
- [ ] discontinuous element-pressure global DOF layout
- [ ] plane-strain 19-local-unknown mapping (`16u + 3p`)
- [ ] torsion-compatible generic mapping (`24u + 3p`)
- [ ] global `Nd/Np` precheck metriği

Pressure basis production kabulü değildir; stability testlerinden sonra sabitlenecektir.

### H1 — Plane-Strain Q8/P1 Herrmann Element

- finite-strain `F`, `J`, `F^{-T}`
- deviatoric hyperelastic response
- independent hydrostatic pressure unknown
- nearly-incompressible compatibility
- fully-incompressible `J=1` constraint
- `R_u`, `R_p`
- `K_uu`, `K_up`, `K_pu`, `K_pp`
- analytic consistent tangent
- element FD cross-check
- pressure patch test
- rank/null-mode diagnostics
- checkerboard / spurious pressure scan
- severe-distortion test

**Kural:** Q8/P1 stability kanıtı olmadan production etiketi almaz.

### H2 — Global Mixed Assembly + Nonlinear Solver

- element-internal pressure equation map
- `InternalMesh` mixed adapter
- Full Newton
- displacement + pressure convergence norms
- volumetric constraint convergence metriği
- trial/commit/revert
- adaptive increment
- cutback/retry
- independent-pressure Results semantics

Küçük doğrulama problemlerinde dense LAPACK kullanılabilir. Production büyüme yönü block sparse assembly + sparse direct baseline + Schur/field-split'tir.

### H3 — Production Acceptance Benchmark

Aynı benchmark sözleşmesinde:

- Dyna Q4 displacement
- Dyna Q4 F-bar
- Dyna Q4/P0 mixed prototype
- Dyna Q8/P1 Herrmann
- FEniCSx mixed/Q2 reference
- mümkün olduğunda ANSYS PLANE183 mixed u-P
- mümkün olduğunda Hexagon Marc Herrmann

karşılaştırılır.

Metrikler:

- displacement error
- pressure quality
- volumetric constraint error
- mesh convergence
- nonlinear convergence
- equation count
- wall time / memory
- distortion robustness

**V0.3 release kapısı:** H0-H3 bilimsel minimumları tamamlanmadan V0.3 `main`e merge edilmez ve `v0.3.0` yayınlanmaz.

---

## V0.4 — Axisymmetric Herrmann / Mixed u-P

**Ana yol:** Q8/P1 Herrmann

- `u_r, u_z`
- full 3D axisymmetric deformation gradient
- hoop stretch
- `2*pi*R` reference-volume integration
- independent pressure constraint
- consistent block tangent
- reaction force
- pressure/constraint diagnostics
- homogeneous + patch benchmarks
- mesh refinement
- independent external reference

F-bar axisymmetric formulation paralel cross-check olarak geliştirilebilir fakat ana Herrmann hattını bloke etmez.

---

## V0.5 — Axisymmetric With Torsion / 2.5D Herrmann

Ana local element unknown düzeni:

```text
8 node × (u_r, u_z, u_theta / phi) = 24 displacement DOF
+ 3 element-internal pressure DOF
= 27 local unknown
```

Gereksinimler:

- prescribed rotation
- circumferential finite-strain kinematics
- hoop + torsional shear coupling
- full `J`
- mixed volumetric constraint
- consistent tangent
- reaction torque
- torque-angle curve
- torsional stiffness
- ANSYS/Marc independent benchmark
- fiziksel ürün torque-angle validation

**Production kapısı:** fiziksel ürün testi ile solver sonucu birlikte doğrulanmadan tamamlandı sayılmaz.

---

## V0.6 — Hyperelastic Model Library

Öncelik:

1. Mooney-Rivlin
2. Yeoh
3. Ogden N1
4. Ogden N2/N3
5. Arruda-Boyce / Gent ihtiyaç halinde

Her model:

```text
Energy
→ Stress
→ Consistent Tangent
→ FD
→ Material Benchmark
→ Herrmann FEM Benchmark
→ F-bar cross-check (uygunsa)
```

Mixed incompressibility formulation bünye yasasından bağımsız kalır.

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

V0.3-V0.5 içinde çalışan minimum mekanizmalar burada ortak ve tam production yöneticisine birleştirilir:

- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- divergence reasons
- displacement/pressure/constraint convergence
- `J` / distortion / pressure diagnostics
- backend-independent linear reports
- automatic / advanced controls

Benchmark ihtiyacı gösterirse line search / Modified Newton / BFGS-Broyden eklenir.

---

## V0.9 — Minimum Engineering Workflow

- geometry adapters
- Gmsh → `InternalMesh`
- named boundaries
- AnalysisPrecheck
- mixed `Nd/Np` ve pressure-space precheck
- result database
- pressure / stress / stretch / `J` / energy
- force/torque histories
- minimum Qt shell

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Başarı özellik sayısıyla değil şu kanıtlarla ölçülür:

```text
material-point
+ element tangent
+ pressure stability
+ mesh convergence
+ incompressibility
+ nonlinear robustness
+ independent solver benchmark
+ fiziksel test
```

### Kalıcı formulation hiyerarşisi

```text
Herrmann / stable mixed u-P  → ana production yol
F-bar                         → güçlü alternatif / cross-check
Displacement-only             → compressible baseline / regression
Q4/P0 mixed prototype         → araştırma / stability regression
```

> Ticari solverları kopyalama; onların olgun mühendislik ilkelerini bağımsız ve doğrulanabilir Dyna mimarisine dönüştür.
