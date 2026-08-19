# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana mimari karar:** ADR-0008 — Herrmann / stable mixed `u-p` ana production yolu  
**Aktif element kararı:** ADR-0009 — Q9/P1 plane-strain production adayı  
**İkincil formulation:** F-bar — bağımsız cross-check ve nearly-incompressible alternatif

DynaElastomerSolver genel amaçlı bir CAE kopyası değildir. Hedef; büyük deformasyonlu elastomer problemlerinde dar fakat güçlü, düşük hata oranlı, doğrulanabilir ve açıklanabilir bir çözüm zinciri kurmaktır. Hexagon Marc ve ANSYS davranış/benchmark referanslarıdır; kaynak kodları kopyalanmaz ve parity yalnız tekrarlanabilir benchmark kanıtı ile ifade edilir.

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

## V0.3 — Stable Mixed u-P / Herrmann Plane-Strain Foundation

**Durum:** 🟡 AKTİF GELİŞTİRME  
**Branch:** `develop/v0.3`  
**CMake:** `0.3.0`  
**Draft PR:** `#1`

### Tarihsel V0.3 bake-off — korunacak regression kanıtı

İlk V0.3 bake-off aynı Cook problemi üzerinde displacement Q4, mixed Q4/P0 ve F-bar Q4'ü karşılaştırdı. Q4/P0 checkerboard pressure null-mode riski gösterdi; F-bar ise güçlü nearly-incompressible cross-check olarak kaldı.

```text
Q4 displacement  -> locking baseline
Q4/P0 mixed      -> experimental / checkerboard regression
Q4 F-bar         -> secondary production-quality cross-check
```

### ADR-0008 — formulation ailesi

```text
PRIMARY:
  Herrmann / stable mixed u-P

SECONDARY / CROSS-CHECK:
  F-bar

BASELINE / REGRESSION:
  displacement-only
```

### ADR-0009 — Q8/P1 → Q9/P1 kararı

İlk araştırma adayı Q8 serendipity + element-internal P1 pressure idi. Mesh-refinement inf-sup proxy tanısı Q8/P1'de stability kaybı gösterdiği için Q8/P1 production-safe ilan edilmedi ve regression/araştırma hattında tutuldu.

Aktif plane-strain adayı:

```text
Q9 biquadratic displacement
+ 3 element-internal complete-linear pressure DOF [1, xi, eta]
+ Herrmann / mixed u-P finite-strain formulation
```

Yerel bilinmeyen sayısı:

```text
18 displacement DOF + 3 pressure DOF = 21
```

Primary quadrature şimdilik `3x3 Gauss`; `2x2` diagnostic/cross-check olarak tutulur. Bu karar external mixed reference ve mesh convergence ile tekrar değerlendirilebilir.

### H0 — Mixed interpolation / DOF foundation ✅

- [x] Q8 historical interpolation ve stability diagnostics
- [x] Q9 biquadratic interpolation / geometry
- [x] 3-DOF discontinuous P1 pressure space
- [x] global displacement/pressure equation mapping
- [x] `Nd/Np` precheck
- [x] Q9 `InternalMesh` topology

### H1 — Plane-Strain Q9/P1 Herrmann Element ✅ / doğrulama genişliyor

- [x] isochoric Neo-Hookean response
- [x] independent hydrostatic pressure, `p > 0` compression
- [x] `sigma = sigma_iso - p I`
- [x] nearly-incompressible compliance form
- [x] fully-incompressible `J=1`, `K_pp=0` saddle-point limit
- [x] `R_u`, `R_p`
- [x] `K_uu`, `K_up`, `K_pu`, `K_pp`
- [x] analytic consistent tangent
- [x] central finite-difference tangent cross-check
- [x] block/tangent symmetry checks
- [x] pressure coupling rank / checkerboard gate
- [x] Q9 mesh-refinement inf-sup proxy plateau gate
- [x] distorted pressure-stability gate
- [x] 2x2 / 3x3 quadrature comparison
- [x] severe-distortion manufactured-state test
- [x] dedicated P1 pressure patch paketi eklendi — CI doğrulaması sürüyor

### H2 — Global Mixed Assembly + Nonlinear Solver ✅

- [x] element-internal pressure global equations
- [x] Q9 `InternalMesh` mixed assembly
- [x] Full Newton
- [x] fixed + adaptive force control
- [x] displacement residual norm
- [x] pressure weak residual norm
- [x] pointwise volumetric diagnostic
- [x] trial/commit/revert
- [x] adaptive increment
- [x] cutback/retry
- [x] displacement + pressure birlikte rollback
- [x] independent-pressure Results semantics
- [x] fully-incompressible saddle-point solve

Dense LAPACK küçük doğrulama problemlerinde korunur. Büyük-model production yönü:

```text
block DOF contract
→ sparse assembly
→ sparse direct baseline
→ Schur-complement / field-split
→ conditioning/scaling diagnostics
```

### H3 — Production Acceptance / düşük hata zinciri 🟡

Tamamlanan/aktif kapılar:

- [x] incompressibility sweep: `K/mu = 10,100,1000,∞`
- [x] `K/mu=1000` → fully-incompressible limit displacement farkı düşük
- [x] severe-distortion exact-state recovery
- [x] 2x2 vs 3x3 quadrature bake-off
- [x] Q9/P1 dedicated Cook `1x1 -> 2x2 -> 4x4` mesh-refinement testi eklendi — CI doğrulaması sürüyor
- [x] FEniCSx mixed Q2/DPC1 external-reference script/workflow eklendi — CI doğrulaması sürüyor
- [ ] Dyna Q9/P1 ile FEniCSx mixed referansını otomatik tek acceptance raporunda karşılaştır
- [ ] pressure field L2-type error karşılaştırması
- [ ] fully-incompressible external mixed reference
- [ ] aynı contract ile ANSYS PLANE183 mixed u-P benchmarkı — erişim olduğunda
- [ ] aynı contract ile Hexagon Marc Herrmann benchmarkı — erişim olduğunda

ADR-0009 hedefleri:

```text
analytic-vs-FD tangent normalized error  <= 1e-7  (nominal hedef <= 1e-8)
pressure patch displacement recovery     <= 1e-7
pressure patch pressure recovery         <= 1e-7
pressure weak residual                   <= 1e-9
K/mu=1000 -> incompressible tip gap      <= 0.5%
external mixed displacement error        <= 1.0%
external pressure L2-type error           <= 2.0%  [aynı pressure convention]
```

Bu eşikler solver'ın Marc/ANSYS seviyesinde olduğunu peşinen ilan etmez; bu seviyeye yönelik ölçülebilir acceptance kapılarıdır.

**V0.3 release kapısı:** Q9/P1 external mixed reference, dedicated mesh/pressure gates ve release hardening tamamlanmadan `main`e merge edilmez ve `v0.3.0` yayınlanmaz.

---

## V0.4 — Axisymmetric Q9/P1 Herrmann / Mixed u-P

**Ana yol:** Q9/P1 Herrmann

- `u_r, u_z`
- full 3D axisymmetric deformation gradient
- hoop stretch
- `2*pi*R` reference-volume integration
- axis `R -> 0` regularity handling
- independent pressure constraint
- consistent block tangent
- reaction force
- pressure/constraint diagnostics
- homogeneous + pressure patch benchmarks
- mesh refinement
- severe distortion
- independent mixed external reference

F-bar axisymmetric formulation paralel cross-check olabilir; ana Herrmann hattını bloke etmez.

---

## V0.5 — Axisymmetric With Torsion / 2.5D Q9/P1 Herrmann

Ana local unknown düzeni:

```text
9 node × (u_r, u_z, u_theta / phi) = 27 displacement DOF
+ 3 element-internal pressure DOF    =  3 pressure DOF
------------------------------------------------------
30 local unknown
```

Gereksinimler:

- prescribed rotation
- circumferential finite-strain kinematics
- hoop + torsional shear coupling
- full `J`
- mixed volumetric constraint
- consistent tangent + FD
- reaction torque
- torque-angle curve
- torsional stiffness
- mesh/distortion convergence
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
→ Q9/P1 Herrmann FEM Benchmark
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

Uniaxial tek başına yeterli kabul edilmez; modele göre uniaxial + planar + biaxial veri kombinasyonları desteklenir.

---

## V0.8 — Production NonlinearSolutionManager + Sparse Mixed Linear Algebra

- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- divergence reasons
- displacement/pressure/constraint convergence
- `J` / distortion / pressure diagnostics
- backend-independent block linear reports
- sparse direct solver baseline
- Schur/field-split seçeneği
- automatic / advanced controls

Benchmark gerektirirse line search / Modified Newton / BFGS-Broyden eklenir.

---

## V0.9 — Minimum Engineering Workflow

- geometry adapters
- Gmsh → `InternalMesh`
- named boundaries
- AnalysisPrecheck
- mixed `Nd/Np` / pressure-space / BC uniqueness precheck
- result database
- pressure / stress / stretch / `J` / energy
- force/torque histories
- minimum Qt shell

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Başarı özellik sayısıyla değil kanıt zinciriyle ölçülür:

```text
material point
+ analytic/FD tangent
+ pressure patch
+ pressure stability / inf-sup diagnostics
+ mesh convergence
+ nearly/fully incompressibility
+ nonlinear cutback/rollback robustness
+ independent mixed solver benchmark
+ commercial solver benchmark
+ fiziksel test
```

### Kalıcı formulation hiyerarşisi

```text
Q9/P1 Herrmann / stable mixed u-P  → ana production yol
F-bar                              → güçlü alternatif / cross-check
Displacement-only                  → compressible baseline / regression
Q8/P1                              → stability research/regression
Q4/P0 mixed                        → checkerboard research/regression
```

> Ticari solverları kopyalama; onların olgun mühendislik davranışlarını bağımsız, ölçülebilir ve regression-test ile korunan Dyna mimarisine dönüştür.
