# DynaElastomerSolver Yol Haritası

**Geliştirme yaklaşımı:** implementasyon öncelikli doğrulama  
**Ana karar:** ADR-0006 — önce çalışan fizik, sonra mimari genişleme

Aşağıdaki sürüm numaraları geliştirme kilometre taşlarıdır; yayın taahhüdü değildir.

## Temel geliştirme ilkesi

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamaz. İlk hedef; büyük deformasyonlu, yaklaşık sıkıştırılamaz elastomer problemlerinde dar fakat kanıtlanmış bir çözüm zinciri oluşturmaktır.

Yeni mimari katmanlar veya algoritmalar yalnız çalışan implementasyonun gösterdiği ihtiyaç doğrultusunda eklenir.

---

## V0.1 — Material Core / Bünye Doğrulama Temeli

Amaç: ilk hiperelastik material-point hesabını taşınabilir ve doğrulanabilir şekilde çalıştırmak.

Teslimatlar:

- CMake tabanlı cross-platform proje
- Fortran 2018 temeli
- precision / constants / status modülleri
- matris/tensör ve deformasyon gradyanı yardımcıları
- `material_kinematics_t`
- `material_response_t`
- minimal material-model arayüzü
- Neo-Hookean model
- strain-energy hesabı
- stress hesabı
- consistent tangent
- material-point test driver
- finite-difference tangent checker
- macOS gfortran ve Windows ifx/gfortran build doğrulaması

Çıkış kriteri:

Neo-Hookean enerji, stress ve tangent sonuçları analitik referanslarla tanımlı tolerans içinde eşleşmeli; sayısal tangent kontrolü geçmelidir.

---

## V0.2 — İlk Çalışan Nonlinear FEM Dikey Dilimi

Amaç: mimari ile çalışan fizik arasındaki mesafeyi mümkün olan en erken aşamada kapatmak.

Teslimatlar:

- `Node` / `Element` / minimal `InternalMesh`
- Q4 plane-strain baseline eleman
- shape function ve Gauss integration
- finite-strain kinematics
- eleman residual'ı
- eleman consistent tangent'i
- global assembly
- temel displacement boundary condition
- Full Newton
- increment tabanlı yükleme
- minimal cutback / retry
- committed/trial çözüm state'i
- dense/LAPACK linear solver yolu
- convergence history
- ham integration-point sonuçları

Doğrulama:

```text
Neo-Hookean
→ material point
→ tek Q4 eleman
→ küçük mesh
→ Full Newton
→ analitik/reference çözüm
```

Çıkış kriteri:

Seçilmiş plane-strain Neo-Hookean benchmark'ları analitik veya bağımsız referans çözümle tanımlı tolerans içinde uyuşmalı ve mesh refinement altında beklenen davranışı göstermelidir.

---

## V0.3 — Nearly-Incompressible Formulation Bake-off

Amaç: production elastomer eleman teknolojisini varsayımla değil benchmark ile seçmek.

Karşılaştırılacak adaylar:

1. displacement-only Q4 — baseline/doğrulama
2. mixed displacement-pressure (`u-p`) adayı
3. F-bar veya eşdeğer locking azaltıcı aday

Ölçütler:

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- DOF ve assembly maliyeti
- axisymmetric genişletilebilirlik
- axisymmetric torsion genişletilebilirliği

Ek teslimatlar:

- pressure field altyapısı gereken adaylar için mixed DOF desteği
- block residual/tangent desteği
- formulation diagnostics
- locking benchmark seti

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

Çıkış kriteri:

Analitik ve bağımsız solver benchmark'larıyla mesh-convergent ve tekrarlanabilir sonuçlar.

---

## V0.5 — Axisymmetric Torsion / 2.5D

Bu kilometre taşı projenin ana farklılaştırıcılarından biridir.

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

Çıkış kriteri:

Seçilmiş torsion problemlerinde Dyna sonuçları bağımsız solver ve uygun fiziksel testlerle önceden tanımlanan mühendislik toleransları içinde uyuşmalıdır.

---

## V0.6 — Hedef Hiperelastik Model Kütüphanesi

İlk FEM zinciri çalıştıktan sonra Material Core genişletilir.

Öncelik sırası:

1. Mooney-Rivlin
2. Yeoh
3. Ogden N1
4. Ogden N2/N3 ihtiyaç halinde
5. Arruda-Boyce / Gent ihtiyaç halinde

Her model için zorunlu zincir:

```text
Energy
→ Stress
→ Consistent Tangent
→ FD Tangent Diagnostic
→ Material-point Benchmark
→ FEM Benchmark
```

Çıkış kriteri:

V1.0 problem sınıfında kullanılacak her model aynı doğrulama zincirini geçmelidir.

---

## V0.7 — Minimum Calibration / Material Lab Çekirdeği

Amaç: solver'da gerçekten kullanılacak malzeme modellerini deneysel veriye fit edebilmek.

İlk kapsam:

- physical material record
- experimental dataset
- uniaxial tension data path
- engineering/true quantity transformations
- objective function
- parameter bounds
- ilk güvenilir optimizer
- RMSE / residual metrics
- provenance
- fitted parameter set
- model comparison

Basma, shear, planar ve biaxial testler sonraki gereksinime göre eklenir.

---

## V0.8 — Solver Robustness / NonlinearSolutionManager

Amaç: çalışan Full Newton solver'ı gerçek elastomer problemlerinin gösterdiği ihtiyaçlara göre üretim seviyesine taşımak.

İlk zorunlu özellikler:

- Full Newton referans yolu
- adaptive increment
- cutback / retry
- deterministic state revert / commit
- convergence reason
- divergence reason
- negative `J` detection
- severe distortion diagnostics
- mixed pressure diagnostics
- linear solver report
- solver history

İhtiyaç kanıtlanırsa eklenecek özellikler:

- line search
- Modified Newton
- BFGS / Broyden
- gelişmiş predictor
- otomatik recovery politikaları

V1.0 zorunlu değildir:

- trust-region
- arc-length / continuation
- generic stabilization ailesi

Çıkış kriteri:

Tanımlı zor elastomer benchmark'ları belgelenmiş increment/cutback geçmişleriyle tekrarlanabilir şekilde çözülmelidir.

---

## V0.9 — Minimum Mühendislik İş Akışı

Solver bilimsel olarak doğrulandıktan sonra tam kullanıcı workflow'u genişletilir.

### Geometri / Mesh

- DXF import adaptörü
- `AnalysisGeometry`
- named boundaries / selections
- Gmsh üzerinden `IMeshProvider`
- mesh precheck

### AnalysisPrecheck

- geometry
- mesh
- material
- formulation
- boundary condition
- solver settings

### Results

- displacement
- principal stretch
- Cauchy stress
- pressure
- `J`
- strain-energy density
- reaction force / torque
- torque–angle
- force–displacement
- `GaussPointInspector`
- contour / chart / table

### UI

- Qt frontend sınırı korunur
- yalnız doğrulanmış solver workflow'unu destekleyen minimum shell ile başlanır
- tam UI kapsamı bilimsel çekirdeğin önüne geçirilmez

---

## V1.0 — Doğrulanmış Nonlineer Elastomer Solver

### Birincil doğrulanmış problem sınıfı

- quasi-static
- finite strain / large deformation
- hyperelastic elastomer
- bonded metal–elastomer
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- prescribed displacement / prescribed rotation
- reaction force / reaction torque
- nearly-incompressible formulation
- seçilmiş ve doğrulanmış hiperelastik modeller

### Başarı tanımı

V1.0, özellik sayısı ile değil aşağıdaki kanıtlarla kabul edilir:

1. material-point doğrulaması
2. element benchmark
3. patch/mesh convergence
4. incompressibility/locking benchmark
5. nonlinear robustness testleri
6. bağımsız solver karşılaştırması
7. uygun fiziksel ürün testi karşılaştırması
8. önceden tanımlanmış toleransların karşılanması

ANSYS Mechanical ve Hexagon Marc kalite/robustness benchmark'ıdır; genel kapsam parity hedefi değildir.

---

## V1.0 Kapsam Dışı

- separation / frictional contact
- self-contact
- debonding / cohesive failure
- viscoelasticity
- strain-rate dependence
- Mullins effect
- hysteresis
- damage
- rubber fatigue / life prediction
- tearing-energy life models
- transient / harmonic dynamics
- explicit dynamics
- binary User Material Plugin
- plugin marketplace
- genel amaçlı CAD
- yüzlerce eleman ailesi
- full ANSYS/Marc feature parity

### Binary plugin politikası

V1.0'da yeni native material modelleri aynı kaynak/build zincirinde eklenebilir.

Gelecekte bağımsız `.dll` / `.dylib` / `.so` material plugin desteklenirse sözleşme native Fortran module ABI'si değil, sürümlenmiş `BIND(C)` / C ABI olacaktır.

---

## Bilimsel geliştirme kuralı

Her yeni bilimsel özellik:

```text
Teori
 ↓
Minimal uygulama
 ↓
Unit / constitutive doğrulama
 ↓
Element benchmark
 ↓
Mesh convergence
 ↓
Bağımsız solver karşılaştırması
 ↓
Uygun olduğunda fiziksel test
 ↓
Ancak sonra production kapsamına alma
```

## Ürün ilkesi

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.
