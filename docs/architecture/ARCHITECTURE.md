# DynaElastomerSolver Mimarisi v1.2

**Revizyon:** ANSYS / Hexagon Marc benchmark revizyonu  
**Durum:** Kabul edilmiş mimari temel

## 1. Mimari amaç

DynaElastomerSolver; kauçuk ve elastomer ürünler için uzmanlaşmış doğrusal olmayan FEM ve malzeme mühendisliği platformudur. Genel amaçlı CAE sistemlerinin kapsam genişliğini kopyalamak hedeflenmez. Derinlik; bünye malzeme bilimi, deneysel kalibrasyon, yaklaşık sıkıştırılamaz sonlu şekil değiştirme FEM'i, eksenel simetrik analiz, eksenel simetrik burulma, sağlam doğrusal olmayan çözüm ve deneysel doğrulama üzerinde yoğunlaşır.

Mimari bilinçli olarak modülerdir:

```text
Material Lab / Deneysel Veri
             ↓
        Material Core
             │
             ├──────────────┐
             │              │
Harici CAD / DXF        Kalibrasyon
       ↓
AnalysisGeometry
       ↓
Geometri Doğrulama
       ↓
IMeshProvider
       ↓
InternalMesh
       ↓
AnalysisPrecheck
       ↓
Finite Element Model
       ↓
NonlinearSolutionManager
       ↓
ILinearSolver
       ↓
ResultDatabase
       ↓
Postprocessor / Deneysel Karşılaştırma
```

## 2. Değiştirilemez ayrım kuralları

```text
Fizik ≠ Geometri ≠ Mesh Üretimi ≠ Doğrusal Solver ≠ UI
```

v1.2 ek kuralları:

1. Bünye yasası ile sıkıştırılamazlığın uygulanması ayrı konulardır.
2. Newton iterasyonu ile doğrusal olmayan çözüm yönetimi ayrı konulardır.
3. Ham integrasyon noktası sonuçları ile görüntüleme/ekstrapolasyon sonuçları ayrı saklanır.
4. Malzeme bilgisi solver'dan bağımsızdır; FEM, kalibrasyon, point-test ve gelecekteki harici adaptörler tarafından kullanılabilir.
5. Analiz geçerliliği çözümden önce birinci sınıf `AnalysisPrecheck` aşamasında kontrol edilir.
6. Harici kütüphaneler kanonik iç veri modeli haline gelemez.
7. FEM, Gmsh native nesnelerini veya DXF native entity'lerini doğrudan tüketmez.
8. Kalibrasyon ve FEM aynı bünye uygulamasını kullanır.
9. Seyrek doğrusal çözücülere yalnız `ILinearSolver` üzerinden erişilir.
10. Mesh üreticilerine yalnız `IMeshProvider` üzerinden erişilir.

## 3. Ana arayüzler

```text
IDxfImporter
IMeshProvider
ILinearSolver
IMaterialModel
IMaterialPlugin
IOptimizer
IElementFormulation
IKinematicsFormulation
IIncompressibilityStrategy
IBoundaryCondition
IResultExtrapolator
```

Bu arayüzler bilimsel çekirdeği harici uygulama ayrıntılarından korur.

## 4. Geometri alt sistemi

DynaElastomerSolver bir CAD/eskiz uygulaması değildir.

```text
Harici CAD
   ↓
DXF
   ↓
IDxfImporter
   ↓
AnalysisGeometry
   ↓
GeometryValidator
   ↓
Topology / Regions / Boundaries / SelectionSets
```

Kanonik model:

```text
AnalysisGeometry
├── Curve
│   ├── Line
│   ├── Arc
│   └── Spline
├── Loop
├── Region
├── Boundary
├── BoundarySet
├── SelectionSet
├── LayerMetadata
└── AxisDefinition
```

Zorunlu geometri kontrolleri:

- açık contour'lar
- yinelenen kenarlar
- çok küçük kenarlar
- boşluklar
- kesişimler / self-intersection
- loop yönü
- delik tespiti
- sıfır alanlı bölgeler
- eksenel simetri geçerliliği
- bölge bağlantısı

Geometri araçları yalnız analiz hazırlığı ile sınırlıdır:

```text
Geometry Check
├── Validate
├── Detect
├── Controlled Heal
└── Recheck
```

Genel amaçlı çizim, trim, fillet, parametrik modelleme ve CAD düzenleme kapsam dışıdır.

## 5. Seçim ve kapsamlandırma

Mühendislik anlamı mesh düğüm numaralarına değil geometri seviyesindeki seçimlere bağlanır.

Tipik kümeler:

```text
INNER_BOND
OUTER_BOND
FREE_SURFACE
AXIS
ELASTOMER_REGION
```

Selection set'ler remesh sonrasında korunur ve şu amaçlarla kullanılır:

- malzeme atama
- sınır şartları
- yükler
- sonuç kapsamlandırma
- doğrulama karşılaştırma bölgeleri

## 6. Mesh alt sistemi

```text
IMeshProvider
├── GmshMeshProvider
├── ImportedMeshProvider
├── AlternativeMeshProvider
└── ElastomerMeshProvider   [gelecek]
```

Tüm sağlayıcılar projeye ait modeli üretir:

```text
InternalMesh
├── Nodes
├── Elements
├── ElementSets
├── BoundarySets
├── RegionSets
├── MaterialRegions
├── ElementOrientation
├── IntegrationScheme
├── MeshQuality
└── Metadata
```

İlk mesh sağlayıcısı: Gmsh adaptörü.

Mühendislik preprocessor'ü için hedeflenen asgari kullanıcı kontrolleri:

- global eleman boyutu
- kenar boyutu
- kenar bölme sayısı
- bölgesel sizing
- lokal refinement
- topoloji uygunsa mapped/structured quadrilateral talebi
- uygun yerde quad-dominant mod
- mesh kalite raporu

Uzun vadede ince bağlı kauçuk katmanları, yüksek kayma bölgeleri, eksenel simetrik quad'lar ve karma `u-p` gereksinimleri için elastomere özgü mesh üreticisi eklenebilir.

## 7. Mesh doğrulama

`MeshPrecheck`, `AnalysisPrecheck` sistemine katkı sağlar ve en az şunları kontrol eder:

- Jacobian işareti/kalitesi
- connectivity
- node ordering
- eleman yönelimi
- degeneracy
- aspect ratio / distortion
- sınır ve bölge eşleme
- integrasyon şeması uyumluluğu
- malzeme/eleman uyumluluğu

## 8. Modern Fortran hesaplama çekirdeği

```text
src/fortran
├── core
├── math
├── materials
├── calibration
├── fem
├── solvers
├── results
└── api
```

Dil/build politikası:

- Fortran 2018 temeli
- yalnız hedef derleyicilerde taşınabilir olan Fortran 2023 özellikleri
- kind tanımları için `iso_fortran_env`
- public ABI için `iso_c_binding`
- CMake build sistemi
- macOS/Apple Silicon: GNU gfortran
- Windows: Intel ifx + GNU gfortran doğrulaması
- ileride Linux: GNU gfortran

## 9. Malzeme alt sistemi

Hiperelastik malzemeler enerji tabanlı ve solver'dan bağımsızdır.

V1.0 başlangıç/hedef model ailesi:

```text
Hyperelastic
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden N1/N2/N3
├── Arruda-Boyce
└── Gent
```

Gelecek fiziği:

- viskoelastisite
- hız bağımlılığı
- Mullins etkisi
- histerezis
- hasar
- yorulma ile ilişkili malzeme büyüklükleri

Bir malzeme cevabı şunları içerebilir:

- strain energy
- first Piola-Kirchhoff stress
- Cauchy stress
- consistent tangent
- Jacobian `J`
- uygun olduğunda basınçla ilişkili bünye büyüklükleri
- state/status bilgisi

## 10. Material Plugin API

Olgun doğrusal olmayan solver'ların genişletilebilirliğinden esinlenerek DynaElastomerSolver native bir material-plugin yaklaşımı sağlar.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Kanonik sözleşme:

```text
evaluate(kinematics, state, parameters)
    ↓
MaterialResponse
├── W
├── stress measures
├── consistent tangent
├── updated trial state
└── status
```

Yeni malzeme modeli eklendiğinde FEM değişmez.

## 11. Material-point state

Her integrasyon noktasının açık state altyapısı vardır:

```text
MaterialPointState
├── committed
├── trial
└── history variables
```

Yakınsayan increment'lerde trial state commit edilir. Başarısız/cutback increment'lerde trial state discard/revert edilir.

## 12. Bünye yasası ve sıkıştırılamazlık stratejisi

Bu ayrım v1.2'de açık ve zorunludur.

```text
Constitutive Law
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Bünye modeli FE sisteminin karma `u-p`, penalty veya başka bir kısıt uygulama yöntemi kullanıp kullanmadığını bilmemelidir.

Kavramsal yapı:

```text
IsochoricConstitutiveModel
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden
├── Arruda-Boyce
└── Gent

IIncompressibilityStrategy
├── Compressible
├── NearlyIncompressible
└── MixedUP
```

Bu ayrım aynı malzeme modelinin farklı FE formulasyonlarında yeniden kullanılmasını sağlar.

## 13. Kalibrasyon ve malzeme provenance bilgisi

Kalibrasyon Modern Fortran bilimsel çekirdeğinin parçasıdır ve FEM ile birebir aynı bünye uygulamasını kullanır.

```text
Deneysel Veri Kümesi
       ↓
Test Kinematics Driver
       ↓
Material Core
       ↓
Tahmin Edilen Cevap
       ↓
Objective Function
       ↓
IOptimizer
       ↓
Parameter Set + Metrics + Provenance
```

Hedef veri kümeleri:

- tek eksenli çekme
- basma
- basit kayma
- düzlemsel çekme
- iki eksenli çekme
- hacimsel veri

Bir fiziksel compound birden fazla bünye uyumuna sahip olabilir. Parametre kümeleri dataset ID'lerini, optimizer'ı, objective function'ı, kalibrasyon sürümünü, geçerlilik aralıklarını ve doğrulama durumunu kaydeder.

## 14. Kinematik ve genelleştirilmiş alanlar

```text
IKinematicsFormulation
├── PlaneStrain
├── PlaneStress        [sonra]
├── Axisymmetric
└── AxisymmetricTorsion
```

Alanlar tek tek elemanların içine hard-code edilmez:

```text
Field
├── Displacement
├── Twist φ
└── Pressure p
```

Hedef DOF'lar:

- plane strain: `ux, uy` veya karma `ux, uy, p`
- axisymmetric: `ur, uz` veya karma `ur, uz, p`
- axisymmetric torsion: `ur, uz, φ` veya karma `ur, uz, φ, p`

Eksenel simetrik burulma temel ürün farklılaştırıcısıdır; dönel simetrik ürünlerde tam 3D ayrıklaştırma yerine meridyen mesh'iyle tork–açı davranışını tahmin edebilir.

## 15. Eleman stratejisi

Temel/doğrulama elemanları:

- Q4 plane strain
- Q4 axisymmetric
- Q4 axisymmetric torsion

Yalnız yer değiştirme tabanlı Q4 teknoloji nihai üretim elastomer formulasyonu değildir.

Üretim geliştirmesi yaklaşık sıkıştırılamaz davranış için karma displacement-pressure teknolojisini önceliklendirir. Doğrulama sonrasında Q8/Q9 türevi daha yüksek dereceli/karma aileler araştırılabilir.

## 16. AnalysisPrecheck

Çözüm zinciri doğrulanmamış modelle başlamamalıdır.

```text
AnalysisModel
    ↓
AnalysisPrecheck
    ↓
Validated SolverInput
    ↓
Solve
```

Kontroller şu alanlardan gelen raporları birleştirir:

### Geometri
- geçerli kapalı bölgeler
- geçerli eksen tanımı
- çözülmemiş kritik topoloji hatası olmaması

### Mesh
- kalite/Jacobian/yönelim
- eşleme ve integrasyon uyumluluğu

### Malzeme
- parametre geçerliliği
- gerekli parametrelerin mevcut olması
- kalibrasyon/doğrulama durumu
- bilinen geçerlilik aralığı
- formulasyon uyumluluğu

### Sınır şartları
- yeterli kısıt
- rigid-body mode kontrolü
- yük/dönme tanımları
- selection-set geçerliliği

### Formulasyon
- malzeme/eleman uyumluluğu
- sıkıştırılamazlık stratejisi uyumluluğu
- gerekli pressure field mevcutluğu

Uyarı ve hata ayrılır; kritik hatalar çözümü engeller.

## 17. Doğrusal olmayan çözüm mimarisi

Doğrusal olmayan çözüm sistemi projeye aittir. v1.2, orkestrasyon ile Newton iterasyonunu ayırır.

```text
NonlinearSolutionManager
├── NewtonSolver
│   ├── FullNewton
│   └── ModifiedNewton
├── ConvergenceManager
├── IncrementController
├── CutbackManager
├── LineSearch
├── Predictor
├── FailureRecovery
└── StateCommitManager
```

Denge:

`R(u) = 0`

Newton artımı:

`K_T Δu = -R`

Manager; increment kabulü, yeniden deneme ve state commit/revert davranışını yönetir.

## 18. Yakınsama kriterleri

Mimari birden fazla yakınsama kanalına izin verir:

- residual force
- ilgili yerlerde residual moment/tork
- displacement correction
- rotation/twist correction
- uygun olduğunda pressure-field convergence
- araştırma/debug için enerji/residual tanıları

Üretim varsayılanları bunların bir alt kümesini kullanabilir; tüm kriterler yakınsama geçmişinde saklanır.

## 19. Increment ve cutback kontrolü

Büyük deformasyon artımlı çözülür.

```text
Başlangıç increment'i
      ↓
Newton iterasyonları
  ┌───┴────────────┐
yakınsadı       başarısız
   │                │
kabul           cutback
   │                │
adım büyüt       yeniden dene
```

Hedef kontroller:

- başlangıç increment'i
- minimum increment
- maksimum increment
- growth factor
- cutback factor
- maksimum retry
- otomatik increment kontrolü

## 20. Solver kontrolleri — Automatic ve Advanced

Kullanıcıya sunulan kontroller genel amaçlı CAE sistemlerinden bilinçli olarak daha sade olacaktır.

### Automatic

Uygulama şunları seçer:

- Newton stratejisi
- başlangıç increment'i
- growth/cutback davranışı
- yakınsama toleransları
- linear-solver backend
- uygun olduğunda line-search aktivasyonu

### Advanced

Uzman kullanıcılar şunları kontrol edebilir:

- Full / Modified Newton
- tangent update stratejisi
- maksimum iterasyon
- yakınsama toleransları
- increment sınırları
- cutback ayarları
- line search
- predictor seçenekleri
- linear solver seçimi

## 21. Doğrusal solver soyutlaması

```text
ILinearSolver
├── Dense/LAPACK        [küçük testler]
├── MumpsSolver         [ilk üretim adayı]
├── PardisoSolver       [gelecek]
├── PetscSolver         [gelecek]
└── InternalSolver      [gelecek]
```

Harici seyrek cebir FEM formulasyonunun veya doğrusal olmayan algoritmanın sahibi değildir; yalnız kurulmuş cebirsel sistemi çözer.

## 22. Sınır şartları

```text
IBoundaryCondition
├── Displacement
├── Rotation
├── Force
├── Pressure
├── Symmetry
└── Constraint
```

BC'ler ham node ID'leri yerine geometri/mesh kümeleri üzerinden kapsamlandırılır.

## 23. Result database

v1.2 fizik sonuçlarını görselleştirme projeksiyonlarından açıkça ayırır.

```text
ResultDatabase
├── RawResults
│   ├── Nodal primary DOFs
│   └── IntegrationPoint results
│
├── DisplayResults
│   └── Nodal extrapolated / averaged fields
│
└── GlobalHistories
```

### Ham integrasyon noktası sonuçları

Hedef alanlar:

- deformasyon gradyanı `F`
- Jacobian `J`
- asal uzamalar
- Cauchy stress
- basınç
- strain-energy density
- shear stress
- malzeme state variables

### Nodal/birincil sonuçlar

- displacement
- twist
- uygun olduğunda pressure DOF
- reactions

### Global histories

- force-displacement
- torque-angle
- secant/tangent torsional stiffness
- strain energy
- external work
- convergence history

## 24. Sonuç ekstrapolasyonu ve görüntüleme

Gauss-point verisi sessizce nodal veri kabul edilmez.

```text
IntegrationPoint Result
       ↓
IResultExtrapolator
       ↓
Display/Nodal Result
       ↓
Contour
```

Uygulama her görüntülenen türetilmiş alan için kullanılan ekstrapolasyon/ortalama yöntemini kaydeder.

Aday yöntemler:

- extrapolated
- averaged
- nearest/integration-point inspection

## 25. Sonuç inceleme araçları

V1.0 post-processing hedefi:

```text
Result Tools
├── Contour
├── Min / Max
├── Node Probe
├── Element Probe
├── GaussPointInspector
├── Path
├── Chart
├── History
├── Reaction
├── Result Scoping
├── Derived Result
├── CSV Export
└── Report
```

`GaussPointInspector` debug aracı değil, birinci sınıf mühendislik aracıdır.

## 26. Elastomere özgü mühendislik sonuçları

Genel stress contour'larının ötesinde şu büyüklükler önceliklidir:

- principal stretches
- shear measures
- hydrostatic pressure
- `J`
- strain-energy density
- reaksiyon kuvveti/torku
- tork–açı eğrisi
- kuvvet–yer değiştirme eğrisi
- tangent stiffness
- secant stiffness

Von Mises stress türetilmiş görüntüleme büyüklüğü olarak bulunabilir ancak ana elastomer tasarım metriği değildir.

## 27. Deneysel karşılaştırma ve ürün doğrulama

Deneysel karşılaştırma result sisteminin native parçasıdır.

```text
FEA History
    +
Fiziksel Test History
        ↓
Overlay / Alignment
        ↓
Error Metrics
```

Hedef metrikler:

- RMSE
- maksimum mutlak hata
- ortalama hata
- bağıl hata
- rijitlik hatası
- geçerli karşılaştırma aralığı

Merkezi ürün zinciri böyle kapanır:

```text
Deneysel Malzeme Verisi
→ Kalibrasyon
→ Malzeme Modeli
→ FEM
→ Fiziksel Ürün Testi
→ Doğrulama
```

## 28. Türetilmiş sonuçlar

Result mimarisi yerleşik ve gelecekte kullanıcı tanımlı türetilmiş büyüklükleri destekler:

- `Kt = dT/dθ`
- `Ksec = T/θ`
- maksimum asal uzama
- normalize tork hatası
- enerji yoğunluğu büyüklükleri

Türetilmiş sonuçlar kaynak alanlarını ve expression/version bilgisini izlenebilirlik için kaydetmelidir.

## 29. Public API

İç Fortran OOP yapıları doğrudan dışarı açılmaz.

C ABI prefix: `des_`.

Örnekler:

```text
des_solver_create
des_solver_run
des_solver_get_result
des_solver_destroy

des_calibration_create
des_calibration_add_dataset
des_calibration_run
des_calibration_get_result
```

Native kütüphaneler:

- Windows: `DynaElastomerCore.dll`
- macOS: `libDynaElastomerCore.dylib`
- Linux: `libDynaElastomerCore.so`

## 30. Doğrulama yaklaşımı

Bir özellik uygun seviyelerde doğrulanmadan tamamlanmış sayılmaz:

1. matematiksel unit testler
2. bünye benchmark'ları
3. sayısal tanjant tanıları
4. material-point testleri
5. tek eleman testleri
6. karma formulasyon / locking benchmark'ları
7. mesh yakınsaması
8. bağımsız solver karşılaştırması
9. deneysel doğrulama

Referans ortamları; uygun olduğunda FEBio, FEniCSx, CalculiX ve ticari ANSYS/Marc benchmark'larını içerebilir.

## 31. Harici bağımlılık politikası

```text
Harici Bileşen
       ↓
Interface / Adapter
       ↓
DynaElastomerSolver Internal Model
```

Açık kaynak ve ticari sistemler uygulama ve doğrulamaya referans olabilir; ancak kanonik bilimsel modeli tanımlamaz.

## 32. Ürün sınırları

İlk üründen bilinçli olarak hariç tutulanlar:

- genel amaçlı 2D/3D CAD
- geniş metal plastisite kütüphanesi
- CFD
- elektromanyetik
- genel multiphysics
- geniş beam/shell/genel eleman katalogları
- topology optimization

Bu sınırlar elastomer uzmanlığını korur.

## 33. Bilimsel kimlik

DynaElastomerSolver şu bileşenlerle tanımlanır:

```text
Elastomer Constitutive Science
+
Experimental Material Calibration
+
Solver-Independent Material Core
+
Finite-Strain Nearly-Incompressible FEM
+
Axisymmetric / Axisymmetric-Torsion Technology
+
Robust Nonlinear Solution Management
+
Transparent Integration-Point Results
+
Experimental Product Validation
```

Merkezi kural:

> DynaElastomerSolver elastomer biliminin, kanonik mühendislik modellerinin ve doğrusal olmayan FEM mantığının sahibidir; geometri parser'ları, mesh üreticileri ve düşük seviyeli seyrek çözücüler değiştirilebilir altyapı olarak kalır.