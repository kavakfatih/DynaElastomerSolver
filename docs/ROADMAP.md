# DynaElastomerSolver Yol Haritası

**Geliştirme yaklaşımı:** implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

Aşağıdaki sürüm numaraları geliştirme kilometre taşlarıdır; yayın taahhüdü değildir.

## Temel geliştirme ilkesi

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. İlk hedef; büyük deformasyonlu, yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat kanıtlanmış bir çözüm zinciri oluşturmaktır.

Yeni mimari katman veya algoritmalar yalnız çalışan implementasyonun gösterdiği ihtiyaç doğrultusunda eklenir.

---

## V0.1 — Material Core / Bünye Doğrulama Temeli

Amaç: ilk hiperelastik material-point hesabını taşınabilir ve doğrulanabilir şekilde çalıştırmak.

Tamamlanan temel teslimatlar:

- Fortran 2018 / CMake temeli
- precision/status katmanı
- 3×3 tensör ve finite-strain yardımcıları
- `material_kinematics_t`
- `material_response_t`
- Neo-Hookean enerji/stress
- analitik consistent tangent
- material-point testleri
- finite-difference tangent checker

Bilimsel çekirdek ve tangent doğrulaması tamamlanmıştır. Cross-platform compiler matrisi V0.2 kapanış kontrolünde tamamlanacaktır.

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

Amaç: mimari ile çalışan fizik arasındaki mesafeyi erken kapatmak.

### Tamamlananlar — 2026-08-18

- [x] Q4 plane-strain baseline element
- [x] Q4 shape functions ve 2×2 Gauss integration
- [x] finite-strain Total-Lagrangian residual
- [x] consistent element tangent
- [x] tangent finite-difference doğrulaması
- [x] çok elemanlı global assembly
- [x] displacement-control Full Newton
- [x] increment stepping
- [x] adaptive increment
- [x] rollback / cutback / retry
- [x] reusable `solution_state_t`
- [x] `trial → commit / revert`
- [x] convergence history
- [x] cutback exhaustion tanısı
- [x] okunabilir status/failure açıklamaları
- [x] nonlinear patch benchmark
- [x] 1×1 / 2×2 / 4×4 mesh refinement benchmark
- [x] `kavakfatih/stdlib` pinlenmiş dependency entegrasyonu
- [x] dense doğrulama solver yolunun `stdlib_linalg::solve` üzerine taşınması
- [x] minimal `internal_mesh_t`
- [x] Q4 connectivity validation
- [x] `InternalMesh` tabanlı assembly yolu
- [x] eski `X + connectivity` assembly yolu ile regression eşdeğerliği
- [x] ham `integration_point_result_t`
- [x] Gauss-point `F / J / P / Cauchy / strain-energy` saklama
- [x] `InternalMesh` Newton solver adapteri
- [x] başarılı final state'ten ham integration-point sonuçlarını toplama
- [x] backend-bağımsız `des_linear_solver`
- [x] `linear_solver_settings_t` / `linear_solver_report_t`
- [x] aktif stdlib/LAPACK dense backend
- [x] lineer residual ve backend status raporlama
- [x] unsupported-backend failure yolu
- [x] eski `des_dense_linear` yolunun compatibility wrapper'a dönüştürülmesi
- [x] `newton_report_t` içine lineer solver diagnostics
- [x] Newton solver içinde doğrudan `solve_linear_system(...)` kullanımı
- [x] `InternalMesh` solver adapterinde lineer backend seçimi
- [x] terminal backend konfigürasyon hatalarının adaptive cutback dışında tutulması
- [x] severe geometrik distorsiyonlu Q4 nonlinear benchmark tanımı

### V0.2 doğrulama zinciri

```text
Neo-Hookean
→ material point
→ Q4 element
→ small mesh
→ global assembly
→ Full Newton
→ adaptive cutback/retry
→ InternalMesh
→ raw Gauss-point results
→ Dyna linear solver boundary
→ Newton linear diagnostics
→ patch / mesh refinement
→ severe-distortion benchmark
```

### Kalanlar

- [ ] stdlib tabanlı full build + 20/20 CTest doğrulaması
- [ ] bağımsız solver/reference karşılaştırmasının genişletilmesi
- [ ] gerekirse ek severe-distortion/cutback benchmark
- [ ] macOS Apple Silicon + gfortran build/test
- [ ] Windows x64 + Intel ifx build/test
- [ ] Windows x64 + gfortran build/test

### V0.2 çıkış kriteri

Seçilmiş plane-strain Neo-Hookean benchmark'ları analitik/bağımsız referanslarla tolerans içinde uyuşmalı; mesh refinement ve robustness testleri geçmeli; lineer solver sınırı ve diagnostics raporlanabilir olmalı ve compiler matrisi doğrulanmalıdır.

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

Amaç: production elastomer element teknolojisini varsayımla değil benchmark ile seçmek.

Karşılaştırılacak adaylar:

1. displacement-only Q4 — baseline
2. mixed displacement-pressure (`u-p`) adayı
3. F-bar veya eşdeğer locking azaltıcı aday

Ölçütler:

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- minimum `J`
- DOF ve assembly maliyeti
- linear-system conditioning
- axisymmetric genişletilebilirlik
- axisymmetric torsion genişletilebilirliği

Ek teslimatlar:

- pressure field altyapısı gereken adaylar için mixed DOF desteği
- block residual/tangent desteği
- formulation diagnostics
- locking benchmark seti
- `InternalMesh` ve raw integration-point result modelinin mixed formulation'a genişletilmesi
- Dyna lineer solver sınırı üzerinden mixed sistem solver benchmark'ı

Çıkış kriteri:

Production nearly-incompressible formulation benchmark kanıtıyla seçilir ve ayrı ADR ile sabitlenir.

---

## V0.4 — Axisymmetric Nonlinear Elastomer

Teslimatlar:

- `ur, uz` kinematics
- `2πR` integration
- seçilmiş nearly-incompressible formulation'ın axisymmetric türevi
- axisymmetric boundary conditions
- reaction force
- axisymmetric benchmark seti

Çıkış kriteri: analitik ve bağımsız solver benchmark'larında mesh-convergent, tekrarlanabilir sonuç.

---

## V0.5 — Axisymmetric Torsion / 2.5D

Ana farklılaştırıcı kilometre taşlarından biridir.

Teslimatlar:

- twist field `φ`
- `ur, uz, φ` kinematics
- gerekli pressure field ile coupled formulation
- prescribed rotation
- reaction torque
- torque–angle history
- secant/tangent torsional stiffness
- torsion convergence quantities
- torsion benchmark seti

Çıkış kriteri: bağımsız solver ve uygun fiziksel testlerle önceden tanımlanmış mühendislik toleranslarında eşleşme.

---

## V0.6 — Hedef Hiperelastik Model Kütüphanesi

Öncelik:

1. Mooney-Rivlin
2. Yeoh
3. Ogden N1
4. Ogden N2/N3 ihtiyaç halinde
5. Arruda-Boyce / Gent ihtiyaç halinde

Her model için:

```text
Energy
→ Stress
→ Consistent Tangent
→ FD Tangent Diagnostic
→ Material-point Benchmark
→ FEM Benchmark
```

---

## V0.7 — Minimum Calibration / Material Lab Çekirdeği

Amaç: solver'da kullanılan material modellerini deneysel veriye güvenilir biçimde fit etmek.

İlk kapsam:

- physical material record
- experimental dataset
- uniaxial tension data path
- engineering/true quantity transformations
- objective function
- parameter bounds
- RMSE / residual metrics
- provenance
- fitted parameter set
- model comparison

### Planlanan açık kaynak calibration araçları

**PCHIP** — `https://github.com/jacobwilliams/PCHIP`

- shape-preserving interpolation/resampling
- deney eğrilerini ortak strain grid'ine taşıma
- cubic-spline overshoot riskini azaltma

**PRIMA** — `https://github.com/libprima/prima`

- BOBYQA ile bound-constrained derivative-free fit
- COBYLA ile nonlinear constraint içeren fitler
- başlangıç değerine hassas modeller için sağlam ilk arama

PRIMA global optimizer olarak değil, bounded/constrained derivative-free optimizer olarak kullanılacaktır.

**Modernized MINPACK** — `https://github.com/fortran-lang/minpack`

- Levenberg–Marquardt nonlinear least-squares
- analitik veya finite-difference Jacobian
- PRIMA başlangıcından sonra hassas local refinement

İlk hedef pipeline:

```text
Raw Experimental Data
        ↓
PCHIP
        ↓
Canonical Test Quantities
        ↓
Objective + Physical Admissibility
        ↓
PRIMA BOBYQA / COBYLA
        ↓
MINPACK Levenberg–Marquardt
        ↓
Material Validation
        ↓
Parameter Set + Metrics + Provenance
```

Çıkış kriteri: en az bir hiperelastik modelin deneysel uniaxial dataset üzerinde tekrarlanabilir fit edilmesi ve aynı Material Core ile bağımsız validation testini geçmesi.

---

## V0.8 — Solver Robustness / NonlinearSolutionManager

V0.2'de gerçek ihtiyaçtan doğan adaptive increment, cutback/retry, state management, history ve lineer solver raporlama mekanizmaları formulation-independent production seviyesine taşınacaktır.

Zorunlu hedefler:

- Full Newton referans yolu
- adaptive increment
- deterministic commit/revert
- convergence/divergence reason
- negative `J`
- severe distortion diagnostics
- mixed pressure diagnostics
- backend-independent linear solver report
- solver history

İhtiyaç kanıtlanırsa:

- line search
- Modified Newton
- BFGS / Broyden
- predictor
- otomatik recovery

Trust-region ve arc-length V1.0 zorunluluğu değildir.

---

## V0.9 — Minimum Mühendislik İş Akışı

### Geometri / Mesh

- DXF import adaptörü
- `AnalysisGeometry`
- named boundaries/selections
- Gmsh `IMeshProvider`
- harici mesh → `InternalMesh`
- mesh precheck

### Results

- raw integration-point database
- displacement
- principal stretch
- Cauchy stress
- pressure
- `J`
- strain-energy density
- reaction force/torque
- torque–angle
- force–displacement
- `GaussPointInspector`
- contour/chart/table

### UI

- Qt frontend sınırı korunur
- yalnız doğrulanmış solver workflow'unu destekleyen minimum shell

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

Birincil problem sınıfı:

- quasi-static
- finite strain / large deformation
- hyperelastic elastomer
- bonded metal–elastomer
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- displacement / rotation control
- reaction force / torque
- nearly-incompressible formulation
- seçilmiş doğrulanmış hiperelastik modeller

Başarı; özellik sayısıyla değil material-point, element, mesh convergence, incompressibility, robustness, bağımsız solver ve fiziksel test doğrulamalarıyla ölçülür.

ANSYS Mechanical ve Hexagon Marc kalite/robustness benchmark'ıdır; genel feature parity hedefi değildir.

## V1.0 kapsam dışı

- separation / frictional contact
- self-contact
- debonding
- viscoelasticity
- strain-rate dependence
- Mullins effect
- hysteresis
- damage/fatigue/life prediction
- transient/harmonic/explicit dynamics
- binary User Material Plugin
- genel amaçlı CAD
- full ANSYS/Marc feature parity

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
Uygun olduğunda fiziksel test
 ↓
Production kapsamı
```

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
