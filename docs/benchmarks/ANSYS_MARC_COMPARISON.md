# DynaElastomerSolver — ANSYS / Hexagon Marc Mimari Benchmark

**Amaç:** DynaElastomerSolver'ı, özellikle elastomer analiz zinciri açısından olgun ticari doğrusal olmayan FEA sistemleriyle karşılaştırmak.  
**Kapsam:** Malzemeler, geometri, mesh, formulasyonlar, doğrusal olmayan çözüm, sonuç anlamı ve doğrulama.  
**Amaç dışı:** Genel amaçlı CAE platformlarıyla özellik sayısı eşitliği.

---

## 1. Yönetici özeti karşılaştırması

| Alan | ANSYS Mechanical | Hexagon Marc / Mentat | DynaElastomerSolver yönü |
|---|---|---|---|
| Ürün kapsamı | Genel amaçlı CAE | Güçlü doğrusal olmayan/genel amaçlı FEA | Uzmanlaşmış elastomer platformu |
| Malzeme yönetimi | Engineering Data / kütüphaneler / Granta ekosistemi | Dahili malzeme tanımları, fitting ve user material | Material Lab + solver-independent Material Core |
| Hiperelastisite | Geniş dahili model ailesi | Güçlü doğrusal olmayan kauçuk malzeme yeteneği | Odaklı native aile + plugin API |
| Deneysel fitting | Engineering Data iş akışlarında yerleşik | Deneysel elastomer fitting iş akışları | Merkezi ürün iş akışı |
| Malzeme provenance | Genel material-data altyapısı | Genel material-data altyapısı | Açık parametre provenance + doğrulama durumları |
| Geometri | Geniş CAD/import ekosistemi | Mentat/CAD import ve model setup | DXF → projeye ait AnalysisGeometry |
| Sketch/CAD araçları | Geniş | İhtiyacımızdan geniş | Bilinçli olarak kapsam dışı |
| Geometri kontrolü | Olgun doğrulama/repair iş akışları | Preprocessing/model check yetenekleri | Geometry Check → Heal → Recheck |
| Mesh | Geniş kontroller ve eleman aileleri | Olgun mesh/preprocessor ortamı | Değiştirilebilir IMeshProvider; ilk Gmsh |
| Yaklaşık sıkıştırılamaz elastomer | Karma displacement-pressure formulasyonları | Özel incompressible/Herrmann tipi formulasyonlar | Karma `u-p` erken roadmap aşamasında |
| Eksenel simetrik burulma | İlgili 2D eleman teknolojisinde destek | Doğrusal olmayan eksenel simetrik yetenekler | Temel uzman formulasyon |
| Nonlinear solver | Olgun Newton/step/convergence kontrolleri | Temel güçlü yönlerinden biri | Projeye ait NonlinearSolutionManager |
| Linear solver | Direct/iterative seçenekleri | Olgun backend | `ILinearSolver`, ilk aday MUMPS |
| Ham integrasyon noktası verisi | Solver/result altyapısıyla erişilebilir | Integrasyon noktalarında hesaplanır, postprocess çoğu zaman ekstrapole eder | Açık RawResults + GaussPointInspector |
| Display result alanları | Zengin contour/probe/path | Mentat postprocessing | Elastomer odaklı contour/probe/path/history |
| Deney karşılaştırması | Daha geniş workflow'larla mümkün | Daha geniş workflow'larla mümkün | Native simülasyon ↔ fiziksel test karşılaştırması |

---

## 2. Malzeme tanımı

### ANSYS yaklaşımı

ANSYS, Engineering Data'yı ana proje malzeme tanım ortamı olarak kullanır. Malzemeler kütüphanelerden alınabilir veya projede oluşturulup düzenlenebilir. Hiperelastik veri doğrudan parametrelerle veya deneysel curve-fitting iş akışıyla tanımlanabilir.

### Marc yaklaşımı

Marc/Mentat dahili doğrusal olmayan malzeme modelleri, deneysel veri fitting yolları ve user-material genişletilebilirliği sağlar.

### DynaElastomerSolver kararı

Dyna üç ayrı kavram kullanır:

```text
Fiziksel Malzeme
       ↓
Deneysel Veri
       ↓
Bünye Parametre Kümeleri
       ↓
Doğrulama Kayıtları
```

Bir compound adı tek başına bünye modeli değildir. Aynı fiziksel malzeme Yeoh ve Ogden gibi birden fazla uyuma sahip olabilir. Her parametre kümesinin kaynağı kaydedilir.

---

## 3. Hiperelastik malzeme ailesi

V1.0 hedef Dyna kütüphanesi:

```text
Hyperelastic
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden N1/N2/N3
├── Arruda-Boyce
└── Gent
```

Ticari solver'lar daha geniş kataloglara sahiptir. Dyna önce daha küçük ancak yüksek düzeyde doğrulanmış elastomer setini hedefler.

Ana mimari fark:

```text
Constitutive Law
        ≠
Incompressibility Strategy
        ≠
Element Formulation
```

Malzeme sınıfı FE kısıt yöntemini belirlemez.

---

## 4. Malzeme genişletilebilirliği

Marc user-material mekanizmaları, genişletilebilir bünye arayüzünün değerini gösterir. MFront ve FEBio gibi açık kaynak referanslar da aynı prensibi destekler.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Kanonik material çağrısı enerji/stress/tangent/state bilgisini projeye ait veri modeliyle döndürür.

---

## 5. Deneysel kalibrasyon

Ticari referans sistemler deneysel test verisinden hiperelastik fitting destekler.

Dyna kalibrasyonu yardımcı araç değil, ana sistem olarak ele alır:

```text
Deneysel Veri Kümesi
        ↓
Veri Dönüşümü
        ↓
Material Core
        ↓
Optimizer
        ↓
Parametre Kümesi
        ↓
Uyum Metrikleri + Provenance
```

Model seçimi tek bir goodness-of-fit değerine dayanmaz. Sistem şu ölçütleri destekleyecek şekilde tasarlanır:

- RMSE / residual'lar
- açıklayıcı metrik olarak R²
- parametre sınırları
- fiziksel kabul edilebilirlik
- kararlılık kontrolleri
- çoklu test modu tutarlılığı
- geçerli şekil değiştirme aralığı
- ekstrapolasyon davranışı
- ürün testi doğrulaması

---

## 6. Geometri

ANSYS ve Marc birçok fizik ve eleman ailesine hizmet ettiği için daha geniş geometri/preprocessing iş akışlarına sahiptir.

Dyna kararı:

```text
Harici CAD
   ↓
DXF
   ↓
IDxfImporter
   ↓
AnalysisGeometry
```

Dahili sketch ortamı planlanmaz. `AnalysisGeometry`; yalnız analiz hazırlığı için curve, loop, region, boundary, selection set ve axis definition içerir.

---

## 7. Geometri araçları

Dyna ticari sistemlerin CAD genişliğini değil olgun workflow fikrini alır:

```text
Geometry Check
├── Açık contour
├── Gap
├── Duplicate
├── Tiny edge
├── Intersection
├── Invalid loop
├── Zero area
└── Axisymmetric validity

         ↓
Controlled Heal
         ↓
Recheck
```

Named/selection set'ler mühendislik anlamını mesh numaralandırmasından bağımsız temsil eder.

---

## 8. Mesh

ANSYS ve Marc olgun mesh ortamları sağlar. Dyna başlangıçta değiştirilebilir provider mimarisi kullanır:

```text
AnalysisGeometry
       ↓
IMeshProvider
       ↓
GmshMeshProvider
       ↓
InternalMesh
```

`InternalMesh` şunları korur:

- nodes
- elements
- element sets
- boundary sets
- region/material sets
- element orientation
- integration scheme
- mesh-quality metadata

Kullanıcı kontrolleri global size, edge divisions, local/region sizing, mapped quad talepleri ve mesh-quality inspection içerecektir.

---

## 9. Yaklaşık sıkıştırılamaz elastomer formulasyonu

Ticari doğrusal olmayan FEA sistemleri, düşük dereceli yalnız-displacement elemanların yaklaşık sıkıştırılamaz kauçukta locking yaratabilmesi nedeniyle özel formulasyonlar kullanır.

Dyna bu nedenle karma teknolojiyi erken üretim gereksinimi kabul eder:

```text
Plane strain          ux, uy, p
Axisymmetric          ur, uz, p
Axisymmetric torsion  ur, uz, φ, p
```

Yalnız displacement Q4 teknoloji öğrenme/doğrulama temelidir, nihai üretim elastomer formulasyonu değildir.

---

## 10. Doğrusal olmayan çözüm

Benchmark, sağlam nonlinear analizin yalnız Newton-Raphson uygulamakla eşdeğer olmadığını gösterdi.

Dyna v1.2:

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

FEM ve nonlinear çözüm mantığı projeye aittir.

---

## 11. Solver kontrol yaklaşımı

Ticari sistemler çok geniş problem sınıfı çözdükleri için çok sayıda kontrol sunar.

Dyna iki seviye kullanır:

### Automatic

Uygulamanın seçtiği elastomer odaklı varsayılanlar.

### Advanced

Uzman kontrolü:

- Full/Modified Newton
- tangent update davranışı
- maksimum iterasyon
- yakınsama toleransları
- başlangıç/min/max increment
- cutback
- line search
- predictor
- linear solver backend

Bu yaklaşım normal workflow'u gereksiz karmaşıklaştırmadan teknik derinlik sağlar.

---

## 12. Doğrusal çözüm

Nonlinear FEM solver projeye aittir. Düşük seviyeli seyrek sistem değiştirilebilir altyapıyla çözülebilir:

`K Δu = -R`

```text
ILinearSolver
├── Dense/LAPACK
├── MUMPS
├── PARDISO   [gelecek]
├── PETSc     [gelecek]
└── Internal  [gelecek]
```

Harici sparse solver kullanmak FEM fiziğini dışarı devretmek anlamına gelmez.

---

## 13. Sonuç anlamı

Ticari FEM sistemleri birçok bünye büyüklüğünü integrasyon noktalarında hesaplar ve görselleştirme için dönüştürür/ekstrapole eder.

Dyna bu ayrımı açık yapar:

```text
ResultDatabase
├── RawResults
│   ├── Primary nodal DOFs
│   └── IntegrationPoint fields
├── DisplayResults
│   └── Extrapolated / averaged fields
└── GlobalHistories
```

Uygulama görüntüleme alanının nasıl türetildiğini kaydeder.

---

## 14. Gauss-point inceleme

Doğrudan integrasyon noktası erişimi V1.0 gereksinimidir.

```text
Element 1042
Gauss Point 1

λ1
λ2
λ3
J
σ12
W
p
state variables
```

Bu özellik bünye debug/doğrulama ve kritik yüksek şekil değiştirmeli kauçuk bölgelerinin incelenmesini destekler.

---

## 15. Elastomere özgü sonuç öncelikleri

Dyna şunları öne çıkarır:

- principal stretches
- shear measures
- hydrostatic pressure
- Jacobian `J`
- strain-energy density
- reaction torque/force
- torque-angle
- force-displacement
- tangent/secant stiffness

Genel sonuçlar bulunabilir; ancak ürün elastomer mühendisliği yorumuna göre optimize edilir.

---

## 16. Sonuç araçları

V1.0 hedefleri:

- contour
- result scoping
- min/max
- node probe
- element probe
- Gauss-point probe
- path
- chart/history
- reaction force/torque
- derived results
- CSV export
- mühendislik raporu

Gelecekte deforme profil DXF export eklenebilir.

---

## 17. Deney ↔ simülasyon doğrulaması

Bu, Dyna'nın temel farklılaştırıcılarından biridir.

```text
FEA Torque-Angle / Force-Displacement
                +
Fiziksel Ürün Testi
                ↓
Overlay / Alignment
                ↓
Hata Metrikleri
                ↓
Doğrulama Kaydı
```

Hedef metrikler:

- RMSE
- maksimum mutlak hata
- ortalama hata
- bağıl hata
- rijitlik hatası
- karşılaştırma geçerlilik aralığı

Bu yapı malzeme test verisinden ürün doğrulamasına kapalı bir zincir oluşturur.

---

## 18. Dyna'nın bilinçli olarak kopyalamadığı alanlar

İlk ürün şu alanları hedeflemez:

- geniş dahili CAD
- CFD
- elektromanyetik
- genel multiphysics
- geniş metal plastisite kataloğu
- genel beam/shell kataloğu
- topology optimization
- ilk sürümde geniş 3D contact yeteneği

Bunlar eksik mimari değil stratejik kapsam dışı kararlardır.

---

## 19. Mimari sonuç

ANSYS; engineering-data yönetimi, preprocessing, mesh, solver controls ve postprocessing genişliği için değerli referans sağlar.

Marc; nonlinear elastomer davranışı, malzeme genişletilebilirliği, sıkıştırılamazlık ve sağlam nonlinear çözüm workflow'ları için özellikle önemli benchmark'tır.

DynaElastomerSolver ilgili mühendislik ilkelerini benimser ancak daha dar ürün kimliğini korur:

```text
Malzeme Karakterizasyonu
        ↓
Kalibrasyon
        ↓
Doğrulanmış Bünye Modeli
        ↓
2D / Eksenel Simetrik / Burulma FEM
        ↓
Şeffaf Doğrusal Olmayan Çözüm
        ↓
Ham + Mühendislik Sonuçları
        ↓
Fiziksel Test Doğrulaması
```

---

## 20. Referans dokümantasyon

### ANSYS

- ANSYS Mechanical / Engineering Data dokümantasyonu
- ANSYS hyperelastic material ve curve-fitting dokümantasyonu
- ANSYS PLANE182 eleman dokümantasyonu
- ANSYS nonlinear Static Structural / solver-control dokümantasyonu
- ANSYS Mechanical result/postprocessing dokümantasyonu

Ana dokümantasyon alanı: `https://ansyshelp.ansys.com/`

### Hexagon Marc

- Hexagon Marc ürün/release bilgileri
- Hexagon Nexus Marc dokümantasyonu ve material, incompressibility, user material, nonlinear solution ve postprocessing teknik tartışmaları

Ana ürün/topluluk alanları:

- `https://nexus.hexagon.com/home/product/marc/`
- `https://nexus.hexagon.com/community/public/marc/`

Bu benchmark dokümanı mimari sonuçları kaydeder; ANSYS veya Marc ile uyumluluk sertifikası değildir.