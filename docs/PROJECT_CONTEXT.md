# DynaElastomerSolver — Proje Bağlamı

**Ana ürün yönü:** nonlineer elastomer solver uzmanlaşması  
**Geliştirme yaklaşımı:** implementasyon öncelikli doğrulama  
**Temel kararlar:** ADR-0005 ve ADR-0006

## Amaç

DynaElastomerSolver; kauçuk/elastomer malzemeler ve bonded elastomer tabanlı ürünler için uzmanlaşmış bilimsel bir mühendislik analiz platformudur.

Genel amaçlı CAE kapsamı hedeflenmez. Öncelik:

- finite strain / large deformation
- hyperelastic constitutive behavior
- nearly-incompressible elastomer formulations
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- sağlam nonlinear solution
- reaction force / torque
- torque–angle ve force–displacement
- material calibration
- bağımsız solver ve fiziksel test doğrulaması

## Geliştirme disiplini

Mevcut mimari yön yeterince tanımlanmıştır. Bundan sonra yeni soyutlama ve özellikler çalışan kodun gösterdiği ihtiyaca göre eklenir.

Temel ilke:

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.

İlk bilimsel dikey dilim:

```text
Neo-Hookean
→ material-point
→ energy / stress / consistent tangent
→ finite-difference tangent checker
→ Q4 plane-strain
→ element residual / tangent
→ global assembly
→ Full Newton
→ dense/LAPACK
→ analitik + bağımsız solver benchmark
```

Bu zincir doğrulanmadan kapsamlı calibration, geniş material library, tam UI, binary plugin sistemi veya çoklu gelişmiş nonlinear strategy implementasyonları öncelik değildir.

## Birincil V1.0 problem sınıfı

- quasi-static
- hyperelastic elastomer
- finite strain
- bonded metal–elastomer
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- prescribed displacement / rotation
- force / reaction force
- torque / reaction torque
- nearly-incompressible response

ANSYS Mechanical ve Hexagon Marc özellik sayısı hedefi değildir; bu problem sınıfında doğruluk ve solver robustness benchmark'ıdır.

## Material Core

Material Core solver'dan bağımsızdır. Aynı constitutive implementation şu zincirde yeniden kullanılır:

- material-point validation
- FEM
- calibration
- gelecekteki external adapters

İlk model Neo-Hookean'dır. Genişleme sırası çalışan FEM zincirinden sonra Mooney-Rivlin, Yeoh ve Ogden ağırlıklı olacaktır. Arruda-Boyce ve Gent gerçek gereksinim/doğrulama ihtiyacına göre eklenir.

## Nearly-incompressible formulation

Constitutive law ile incompressibility enforcement ayrı tutulur.

Production element technology henüz sabitlenmemiştir. İlk formulation bake-off:

```text
Displacement-only Q4
        vs
Mixed u-p adayı
        vs
F-bar / eşdeğer aday
```

Karar şu kanıtlarla verilir:

- volumetric locking
- pressure stability
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- computational cost
- axisymmetric compatibility
- axisymmetric torsion extensibility

Seçim benchmark sonrasında ayrı ADR ile sabitlenir.

## Solver yaklaşımı

Hedef mimari `NonlinearSolutionManager` altında genişleyebilir; fakat ilk referans implementasyon:

```text
Full Newton
+ correct consistent tangent
+ increment stepping
+ cutback / retry
+ trial / commit / revert
+ convergence diagnostics
```

Line search, Modified Newton, BFGS/Broyden ve gelişmiş recovery ancak benchmark veya gerçek ürün problemleri ihtiyaç gösterirse implementasyon sırasına alınır.

Solver başarısızlıklarında mümkün olduğunca açık reason/diagnostic üretmek uzun vadeli ürün hedefidir.

## Contact kapsamı

V1.0 bonded elastomer-metal sistemlerini hedefler.

V1.0 zorunlu değildir:

- separation
- frictional sliding
- general contact
- self-contact
- debonding / cohesive failure

Büyük deformasyon nedeniyle self-contact zorunlu hale gelen modeller doğrulanmış V1.0 kapsamı dışında kabul edilir.

## Plugin politikası

V1.0'da yeni material modelleri aynı source/build zincirinde native extension olarak eklenebilir.

Bağımsız binary User Material Plugin V1.0 zorunluluğu değildir. Gelecekte uygulanırsa public sınır native Fortran module/type ABI'si değil, sürümlenmiş `ISO_C_BINDING` / `BIND(C)` tabanlı C ABI olacaktır.

## Kalibrasyon

Calibration aynı Material Core implementation'ını kullanır. Ancak kapsamlı Material Lab ilk FEM dikey dilimin önüne geçirilmez.

İlk calibration kapsamı uniaxial data, objective function, parameter bounds, temel optimizer, residual/RMSE ve provenance ile sınırlı tutulabilir.

## Geometri ve mesh

Dyna genel amaçlı CAD uygulaması değildir.

- dış geometri başlangıçta DXF üzerinden alınır
- Dyna kendi `AnalysisGeometry` modelini kullanır
- meshing `IMeshProvider` arkasındadır
- ilk sağlayıcı Gmsh adaptörüdür
- FEM yalnız Dyna'nın `InternalMesh` modelini tüketir

Tam preprocessing workflow'u solver doğrulamasından sonra genişletilir.

## Results

Ham integration-point fiziği display/projection sonuçlarından ayrı tutulur.

Öncelikli elastomer sonuçları:

- displacement
- principal stretch
- Cauchy stress
- shear measures
- hydrostatic pressure
- `J`
- strain-energy density
- reaction force
- reaction torque
- torque–angle
- force–displacement
- tangent/secant stiffness

`GaussPointInspector` birinci sınıf sonuç aracıdır.

## V1.0 terminoloji sınırı

V1.0 **nonlinear structural response** hesaplar.

Stress, stretch ve energy sonuçları doğrudan failure/life prediction anlamına gelmez. Aşağıdakiler ayrı gelecek araştırma/doğrulama kapsamıdır:

- Mullins effect
- tearing energy
- damage
- fatigue
- crack initiation
- life prediction

## UI

Cross-platform frontend kararı Qt 6 + Qt Quick/QML'dir; fakat Qt scientific/application architecture değildir.

Core ve presentation contracts Qt'den bağımsız tutulur. Tam UI geliştirmesi bilimsel doğrulamanın önüne geçirilmez; gerektiğinde minimal teknik shell/test harness ile başlanır.

## Dil ve platform

- insan tarafından okunan repo içeriği Türkçe
- Modern Fortran / Fortran 2018
- `ISO_C_BINDING` ile public C ABI
- macOS Apple Silicon: gfortran
- Windows: ifx + gfortran validation
- CMake ana build sistemi

## Başarı ölçütü

V1.0 ancak aşağıdaki doğrulama zinciri tamamlandığında mühendislik platformu olarak kabul edilir:

```text
Constitutive validation
→ Element benchmark
→ Mesh convergence
→ Incompressibility/locking benchmark
→ Nonlinear robustness benchmark
→ Independent solver comparison
→ Uygun fiziksel ürün testi
```

Her benchmark için tolerans, test çalıştırılmadan önce tanımlanır.
