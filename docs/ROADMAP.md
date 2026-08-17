# DynaElastomerSolver Yol Haritası

**Yaklaşım:** Implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. Hedef; büyük deformasyonlu ve yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat güçlü, doğrulanmış ve açıklanabilir bir çözüm zinciri oluşturmaktır.

---

## V0.1 — Material Core / Bünye Doğrulama Temeli

**Durum:** Bilimsel çekirdek tamamlandı.

Tamamlananlar:
- Fortran 2018 + CMake
- precision/status katmanı
- tensör ve finite-strain yardımcıları
- Neo-Hookean enerji, `P`, Cauchy stress
- analitik consistent tangent `dP/dF`
- material-point testleri
- merkezi finite-difference tangent kontrolü

Kanıt:
- material tangent normalize FD hatası yaklaşık `1.26e-9`.

Cross-platform compiler doğrulaması V0.2 kapanışına taşındı.

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

**Güncel durum:** `V0.2-dev — Nonlinear FEM Robustness`

### Tamamlanan implementasyon

- [x] Q4 plane-strain baseline element
- [x] 2×2 Gauss integration
- [x] Total-Lagrangian residual
- [x] consistent element tangent
- [x] element tangent FD doğrulaması
- [x] çok elemanlı global assembly
- [x] displacement-control Full Newton
- [x] increment stepping
- [x] adaptive increment
- [x] rollback / cutback / retry
- [x] `solution_state_t` ile trial/commit/revert
- [x] convergence history
- [x] failure/status diagnostics
- [x] nonlinear patch benchmark
- [x] 1×1 / 2×2 / 4×4 mesh refinement
- [x] pinlenmiş `kavakfatih/stdlib`
- [x] stdlib/LAPACK dense lineer solve
- [x] minimal `internal_mesh_t`
- [x] connectivity validation
- [x] InternalMesh assembly
- [x] eski `X + connectivity` yolu ile regression eşdeğerliği
- [x] ham integration-point result modeli
- [x] Gauss-point `F / J / P / Cauchy / W`
- [x] InternalMesh Newton solver adapteri
- [x] backend-bağımsız `des_linear_solver`
- [x] `linear_solver_settings_t` / `linear_solver_report_t`
- [x] lineer backend/residual diagnostics
- [x] `newton_report_t` içinde lineer solver diagnostics
- [x] terminal backend hatalarının cutback dışında tutulması
- [x] severe-distortion nonlinear Q4 benchmark
- [x] severe-distortion için FEM'den bağımsız kapalı-form `J / P / W` continuum referansı
- [x] V0.2 benchmark kataloğu
- [x] GitHub Actions compiler matrix tanımı
- [x] CI action/tool sürümlerinin commit SHA ile pinlenmesi

### Doğrulama zinciri

```text
Neo-Hookean material point
        ↓
Material tangent FD
        ↓
Q4 element tangent FD
        ↓
Global assembly
        ↓
Full Newton
        ↓
Adaptive cutback/retry
        ↓
InternalMesh
        ↓
Raw Gauss results
        ↓
Linear solver diagnostics
        ↓
Patch + mesh refinement
        ↓
Severe distortion
        ↓
Closed-form continuum P/W/J
        ↓
Cross-compiler CI
        ↓
Independent external FEM solver
```

Detaylı katalog:
`docs/verification/V0.2_REFERENCE_BENCHMARKS.md`

### Compiler matrix

Workflow: `.github/workflows/fortran-ci.yml`

Hedef:
1. Ubuntu 24.04 / gfortran 14
2. macOS 26 ARM64 / gfortran 14
3. Windows 2025 / gfortran 14
4. Windows 2025 / Intel ifx 2025.2

Doğrulanmış ilk sonuçlar:
- [x] Ubuntu 24.04 / gfortran 14 — configure + build + CTest başarılı
- [x] macOS 26 ARM64 / gfortran 14 — configure + build + CTest başarılı
- [ ] Windows 2025 / gfortran 14 — aktif doğrulama
- [ ] Windows 2025 / Intel ifx 2025.2 — aktif doğrulama

### V0.2 kapanışından önce kalanlar

- [ ] Güncel `main` üzerinde compiler matrixin tüm job'larını yeşile getirmek
- [ ] 20/20 CTest'i hedef compiler matrisinde doğrulamak
- [ ] en az bir benchmarkı bağımsız dış FEM solver ile çözmek
- [ ] dış solver sürümü, energy formu, element/integration ayarı ve sonuçlarını kaydetmek
- [ ] yalnız ihtiyaç çıkarsa ek robustness benchmarkı

### V0.2 çıkış kriteri

Plane-strain Neo-Hookean benchmarkları kapalı-form ve bağımsız referanslarla tolerans içinde uyuşmalı; robustness/mesh testleri geçmeli; lineer diagnostics raporlanabilir olmalı; compiler matrix yeşil olmalı ve en az bir dış FEM karşılaştırması belgelenmelidir.

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

Amaç: production elastomer element teknolojisini varsayımla değil benchmark ile seçmek.

Karşılaştırılacak yollar:
1. displacement-only Q4 — baseline
2. mixed displacement-pressure (`u-p`)
3. F-bar veya eşdeğer locking azaltıcı formulation

Karar ölçütleri:
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

Gerekli altyapı:
- mixed DOF
- block residual/tangent
- pressure diagnostics
- locking benchmark seti
- InternalMesh/results modelinin pressure alanına genişlemesi
- mevcut Dyna lineer solver sınırı üzerinden mixed-system benchmark

**Çıkış:** Production nearly-incompressible formulation ölçülmüş benchmark kanıtıyla seçilir ve ADR ile sabitlenir.

---

## V0.4 — Axisymmetric Nonlinear Elastomer

- `ur, uz` kinematics
- `2πR` integration
- seçilmiş incompressibility formulation'ın axisymmetric türevi
- axisymmetric BC
- reaction force
- analitik ve bağımsız solver benchmarkları

---

## V0.5 — Axisymmetric Torsion / 2.5D

Projenin ana farklılaştırıcı kilometre taşlarından biridir.

- twist field `φ`
- `ur, uz, φ` kinematics
- gerekiyorsa pressure coupling
- prescribed rotation
- reaction torque
- torque–angle history
- secant/tangent torsional stiffness
- torsion convergence quantities
- bağımsız solver ve fiziksel test doğrulaması

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

Amaç: kullanılan material modellerini deneysel veriye güvenilir biçimde fit etmek.

Planlanan araç zinciri:

```text
Experimental Data
    ↓
PCHIP
shape-preserving interpolation
    ↓
Objective + physical admissibility
    ↓
PRIMA BOBYQA / COBYLA
    ↓
MINPACK Levenberg–Marquardt
    ↓
Material validation
    ↓
Parameters + metrics + provenance
```

Kütüphaneler:
- `https://github.com/jacobwilliams/PCHIP`
- `https://github.com/libprima/prima`
- `https://github.com/fortran-lang/minpack`

---

## V0.8 — Production NonlinearSolutionManager

V0.2'de gerçek ihtiyaçtan doğan mekanizmalar formulation-independent production seviyesine taşınır:
- Full Newton
- adaptive increment
- commit/revert
- cutback/retry
- convergence/divergence reason
- negative `J`
- severe distortion diagnostics
- mixed pressure diagnostics
- backend-independent linear solver report
- solver history

Yalnız benchmark ihtiyacı gösterirse:
- line search
- Modified Newton
- BFGS/Broyden
- predictor/recovery

---

## V0.9 — Minimum Mühendislik İş Akışı

Geometri/Mesh:
- DXF adapter
- `AnalysisGeometry`
- named boundaries
- Gmsh `IMeshProvider`
- harici mesh → `InternalMesh`
- mesh precheck

Results:
- raw integration-point database
- displacement
- principal stretch
- Cauchy stress
- pressure
- `J`
- strain-energy
- reaction force/torque
- torque–angle
- force–displacement
- `GaussPointInspector`

UI:
- Qt sınırı korunur
- yalnız doğrulanmış workflow için minimum shell

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
- prescribed displacement/rotation
- reaction force/torque
- nearly-incompressible formulation
- seçilmiş doğrulanmış hiperelastik modeller

Başarı; özellik sayısıyla değil material-point, element, mesh convergence, incompressibility, robustness, bağımsız solver ve fiziksel test kanıtlarıyla ölçülür.

V1.0 dışında:
- separation/frictional contact
- self-contact
- debonding
- viscoelasticity
- Mullins/hysteresis
- damage/fatigue/life
- transient/harmonic/explicit dynamics
- binary material plugin
- genel amaçlı CAD
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
Uygun olduğunda fiziksel test
 ↓
Production kapsamı
```

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
