# ADR-0002 — ANSYS / Hexagon Marc Benchmark Revizyonu

**Durum:** Kabul edildi  
**Proje:** DynaElastomerSolver  
**Mimari hedef:** v1.2

## Bağlam

Temel mimari; ANSYS Mechanical ve Hexagon Marc/Mentat'ın elastomer/doğrusal olmayan analiz iş akışlarıyla karşılaştırıldı. Amaç özellik eşitliği değildi. Benchmark, kauçuk/elastomer mühendisliğini doğrudan etkileyen olgun mimari kalıpları belirlemek için kullanıldı.

Karşılaştırma şu alanlara odaklandı:

- malzeme tanımı
- hiperelastik malzeme modelleri
- deneysel curve fitting
- geometri ve geometri hazırlığı
- mesh üretimi ve kontrolleri
- yaklaşık sıkıştırılamaz formulasyonlar
- doğrusal olmayan çözüm stratejisi
- seyrek doğrusal çözüm
- solver kontrolleri
- integrasyon noktası sonuçları
- post-processing
- deney/simülasyon doğrulaması

## Karar 1 — Uzmanlaşmış ürün sınırını koru

DynaElastomerSolver genel amaçlı bir ANSYS/Marc klonu değil, elastomer mühendisliği platformu olarak kalacaktır.

Genel CAD, geniş multiphysics, CFD, elektromanyetik, büyük beam/shell katalogları ve genel metal plastisitesi yalnız ticari CAE sistemlerinde bulunduğu için kapsamımıza alınmaz.

## Karar 2 — Birinci sınıf AnalysisPrecheck ekle

Olgun CAE iş akışları çözüm öncesi veya setup sırasında model tutarlılığını doğrular. Bu nedenle:

```text
AnalysisModel
    ↓
AnalysisPrecheck
    ↓
Validated SolverInput
    ↓
Solve
```

Precheck; geometri, mesh, malzeme, formulasyon ve sınır şartı tanılarını birleştirir.

Kritik hatalar çözümü engeller. Mühendislik uyarıları görünür kalır ve ileride kontrollü expert workflow altında override edilebilir.

## Karar 3 — Native material-plugin mimarisi ekle

Marc user-material genişletilebilirliği ve açık kaynak sistemlerde incelenen solver-independent malzeme kavramları kararlı bir material sözleşmesinin gerekliliğini desteklemektedir.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Yeni bir malzeme modeli FEM kaynak değişikliği gerektirmemelidir.

## Karar 4 — Sıkıştırılamazlık uygulamasını bünye yasasından ayır

Hiperelastik bünye bilimi ile FE kısıt uygulaması açıkça ayrılır.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Karma `u-p` bir FE formulasyon teknolojisidir; Yeoh, Ogden veya başka malzeme sınıflarına hard-code edilmez.

## Karar 5 — Monolitik nonlinear solver tasarımını değiştir

Eski `NonlinearSolver` soyutlaması şu yapıya dönüştürülür:

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

Üretim seviyesinde doğrusal olmayan sağlamlığın yalnız Newton iterasyonundan değil, birden fazla mekanizmanın koordinasyonundan geldiği kabul edilir.

## Karar 6 — Automatic ve Advanced solver kontrol modları ekle

Ticari solver'lar çok sayıda doğrusal olmayan kontrol sunar; ancak DynaElastomerSolver bu karmaşıklığı normal kullanıcıya zorunlu kılmaz.

### Automatic

Yazılım increment, yakınsama, Newton stratejisi ve linear solver için elastomer odaklı uygun varsayılanları seçer.

### Advanced

Uzman kullanıcı Newton tipi, yakınsama toleransları, increment sınırları, line search, cutback ve backend seçimini kontrol edebilir.

## Karar 7 — InternalMesh metadatasını genişlet

`InternalMesh` artık yalnız nodes/elements içermez:

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

Yönelim, integrasyon ve kalite güvenilir analiz ve tanılar için gereklidir.

## Karar 8 — Ham sonuçları görüntüleme sonuçlarından ayır

Stress ve benzeri bünye büyüklükleri integrasyon noktalarında oluşur. Görüntüleme sistemleri bunları nodal değerlere ekstrapole/ortalama yapabilir.

```text
ResultDatabase
├── RawResults
│   └── IntegrationPoint
└── DisplayResults
    └── Extrapolated/Averaged
```

Görüntülenen contour verisinin kökeni ve dönüşümü gizlenmemelidir.

## Karar 9 — GaussPointInspector V1.0 mühendislik özelliğidir

Doğrudan integrasyon noktası incelemesi; bünye doğrulaması, karma formulasyonlar ve yüksek şekil değiştirmeli kauçuk bölgelerinin araştırılması için değerlidir.

V1.0 postprocessor bu nedenle birinci sınıf Gauss-point inceleme yolu içerir.

## Karar 10 — Native deney/FEA karşılaştırması

DynaElastomerSolver fiziksel doğrulamayı harici spreadsheet işi değil ürünün parçası kabul eder.

```text
FEA Sonucu
   +
Fiziksel Ürün Testi
        ↓
Overlay
        ↓
Hata Metrikleri
        ↓
Doğrulama Kaydı
```

Hedef metrikler RMSE, maksimum/ortalama hata, bağıl hata ve rijitlik hatasını içerir.

## Karar 11 — İlk hiperelastik kütüphaneyi genişlet

V1.0 hedef malzeme ailesi:

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1/N2/N3
- Arruda-Boyce
- Gent

Bu kapsam genel ticari kütüphanelerden bilinçli olarak daha küçüktür ancak pratik elastomer analizleri için güçlü bir temel sağlar.

## Karar 12 — Projeye ait doğrusal olmayan FEM çekirdeğini koru

ANSYS ve Marc karşılaştırmaları sahiplik sınırını değiştirmez.

DynaElastomerSolver şunların sahibidir:

- kinematik
- malzeme modelleri
- eleman formulasyonları
- assembly
- karma formulasyon mantığı
- doğrusal olmayan çözüm yönetimi
- yakınsama/cutback mantığı
- sonuç anlamı

Değiştirilebilir harici seyrek solver yalnız cebirsel sistemi çözebilir.

## Karar 13 — Geometri kapsamını dar tut

Ticari sistemler geniş CAD/geometri araçları içerir. DynaElastomerSolver bu kapsamı benimsemez.

Geometri alt sistemi yalnız şunları sağlar:

- DXF import
- topoloji yorumlama
- region/boundary/selection tanımları
- doğrulama
- kontrollü iyileştirme
- eksen tanımı
- mesh hazırlığı

Dahili sketcher eklenmez.

## Sonuçlar

### Olumlu

- mimari üretim seviyesinde nonlinear solver ihtiyaçlarını daha iyi yansıtır
- integrasyon noktası fiziği şeffaflaşır
- malzeme genişletilebilirliği artar
- solver kontrolleri normal ve uzman kullanıcılar için kullanılabilir kalır
- karma sıkıştırılamazlık altyapısı daha temiz olur
- deneysel doğrulama native iş akışına dönüşür
- mesh ve solver tanıları denetlenebilir hale gelir

### Maliyet

- daha fazla arayüz ve state-management kodu
- daha fazla doğrulama senaryosu
- sonuç ekstrapolasyon/ortalama yöntemlerinin bağımsız test edilmesi gerekir
- doğrusal olmayan kontrol mantığı önemli bir mühendislik alt sistemine dönüşür
- Material Plugin API için sıkı ABI/sürüm disiplini gerekir

## Benchmark ilkesi

ANSYS ve Marc; olgun davranış ve doğrulama için referans sistemlerdir, körü körüne kopyalanacak uygulama şablonları değildir.

> Elastomer analizini güçlendiren olgun mühendislik ilkelerini benimse; uzmanlaşmış ürüne hizmet etmeyen kapsam genişliğini alma.