# DynaElastomerSolver — Results Mimarisi v1.0

**Durum:** Kabul edildi  
**Amaç:** Sonuçların bilimsel doğruluğunu korurken ANSYS Mechanical kadar anlaşılır, elastomer mühendisliğine özel ve framework'ten bağımsız bir Results deneyimi oluşturmak.

## 1. Temel ilke

DynaElastomerSolver sonuç sistemi iki hedefi aynı anda sağlamalıdır:

1. Kullanıcı sonucu hızlı ve açık biçimde bulabilmelidir.
2. Görüntülenen değerin kaynağı ve dönüşümü bilimsel olarak izlenebilir olmalıdır.

Bu nedenle:

> Ham integrasyon noktası sonucu, görüntüleme sonucu ve mühendislik sonucu aynı şey değildir.

Kanonik zincir:

```text
ResultDatabase
      ↓
ResultDefinition
      ↓
ResultOperation
      ↓
ResultObject
      ↓
ResultViewModel
      ↓
Contour / Chart / Table / Inspector
```

`ResultDatabase` bilimsel gerçeği saklar. `ResultObject` kullanıcının proje içinde oluşturduğu ve kaydettiği sonuç nesnesidir.

## 2. ANSYS'ten alınan kullanım ilkesi

ANSYS Mechanical'ın güçlü yönlerinden biri, sonuçları `Solution` altında ayrı nesneler olarak kullanıcıya sunmasıdır. Dyna aynı temel kullanım fikrini daha sade ve elastomer odaklı biçimde uygular.

Kullanıcı matematiksel veri boru hattını elle kurmak zorunda kalmaz.

Örnek:

```text
Sonuçlar
  ↓
Elastomer
  ↓
Asal Uzama λ1
  ↓
ResultObject oluşturulur
  ↓
Viewport contour gösterir
  ↓
Inspector kaynak, kapsam ve görüntüleme yöntemini açıklar
```

ParaView benzeri işlem zinciri arka planda bulunabilir; kullanıcıya gereksiz teknik pipeline karmaşıklığı yüklenmez.

## 3. Results Navigator

Results modülüne girildiğinde Navigator modüle özgü hale gelir.

Önerilen V1.0 hiyerarşisi:

```text
Sonuçlar
│
├── Deformasyon
│   ├── Toplam Yer Değiştirme
│   ├── Radyal Yer Değiştirme
│   ├── Eksenel Yer Değiştirme
│   └── Burulma / Twist
│
├── Elastomer
│   ├── Asal Uzama λ1
│   ├── Asal Uzama λ2
│   ├── Asal Uzama λ3
│   ├── Jacobian J
│   ├── Hidrostatik Basınç
│   ├── Kayma
│   └── Şekil Değiştirme Enerjisi Yoğunluğu
│
├── Gerilme
│   ├── Cauchy Stress
│   ├── Normal Bileşenler
│   ├── Kayma Bileşenleri
│   └── Türetilmiş Gerilme
│
├── Reaksiyonlar
│   ├── Reaksiyon Kuvveti
│   └── Reaksiyon Torku
│
├── Mühendislik Sonuçları
│   ├── Tork–Açı
│   ├── Kuvvet–Yer Değiştirme
│   ├── Tangent Rijitlik
│   ├── Sekant Rijitlik
│   ├── Enerji
│   └── Dış İş
│
├── İnceleme
│   ├── Probe
│   ├── Node Probe
│   ├── Element Probe
│   ├── Gauss Point Inspector
│   └── Path
│
└── Doğrulama
    ├── Deneysel Overlay
    ├── Hata Eğrisi
    ├── RMSE
    ├── Maksimum Hata
    ├── Ortalama Hata
    └── Rijitlik Hatası
```

Bu hiyerarşi genel amaçlı FEA yazılımlarındaki çok büyük result kataloğunu kopyalamaz. Elastomer mühendisliğinde doğrudan anlamlı büyüklükler öne alınır.

## 4. ResultDefinition

`ResultDefinition`, bir sonucun mühendislik anlamını tanımlar; görsel durum veya Qt nesnesi içermez.

Örnek alanlar:

```text
ResultDefinition
├── id
├── name
├── category
├── sourceField
├── valueType
├── tensorComponent
├── canonicalUnit
├── supportedLocations
├── defaultProjection
├── defaultRangeMode
├── allowedScopes
├── validityRules
└── description
```

Örnek:

```text
id: elastomer.principal_stretch.lambda1
name: Asal Uzama λ1
sourceField: principal_stretches
valueType: scalar
canonicalUnit: dimensionless
supportedLocations:
  - IntegrationPoint
defaultProjection: AveragedToNodes
```

Sonuç tanımlarının anlamı QML dosyalarında hard-code edilmez.

## 5. ResultObject

`ResultObject`, kullanıcının projede kaydettiği somut sonuç nesnesidir.

```text
ResultObject
├── id
├── name
├── definitionId
├── scope
├── sourceLocation
├── projectionMethod
├── component
├── unit
├── step
├── increment
├── displaySettings
├── rangeSettings
├── minValue
├── maxValue
├── status
└── provenance
```

Örnek:

```text
Asal Uzama λ1 — Dış Kauçuk Bölgesi

Definition     elastomer.principal_stretch.lambda1
Scope          OUTER_RUBBER
Source         Integration Point
Projection     Averaged to Nodes
Increment      Final
Unit           —
```

Aynı `ResultDefinition` kullanılarak farklı scope veya görüntüleme yöntemlerine sahip birden fazla `ResultObject` oluşturulabilir.

## 6. ResultOperation

Veri dönüşümleri açık ve izlenebilir işlem nesneleriyle yapılır.

```text
ResultOperation
├── Extrapolation
├── Averaging
├── PrincipalValue
├── ComponentExtraction
├── PathExtraction
├── HistoryExtraction
├── Derivative
├── Difference
├── ExperimentalAlignment
└── ErrorMetric
```

Örnek arka plan zinciri:

```text
Raw Gauss Point Stress
        ↓
ComponentExtraction
        ↓
Averaging
        ↓
Region Scope
        ↓
Contour
```

Kullanıcı çoğu durumda bu pipeline'ı elle kurmaz. Dyna seçilen `ResultDefinition` için uygun varsayılan zinciri oluşturur.

Advanced modda kaynak ve dönüşüm ayrıntıları incelenebilir.

## 7. Ham sonuç ve görüntüleme sonucu ayrımı

Kanonik veri yapısı:

```text
ResultDatabase
├── RawResults
│   ├── NodalPrimaryResults
│   └── IntegrationPointResults
│
├── DisplayResults
│   └── projected / extrapolated / averaged
│
├── DerivedResults
└── GlobalHistories
```

Kurallar:

- Raw sonuçlar hiçbir zaman display sonucu tarafından overwrite edilmez.
- Display sonucu hangi raw alanlardan üretildiğini kaydeder.
- Projection/averaging yöntemi her `ResultObject` için saklanır.
- Kullanıcı isterse ham Gauss-point değerine geri dönebilir.
- Min/max değeri hesaplanırken hangi veri konumunun kullanıldığı görünür olmalıdır.

## 8. Results Workspace

Sonuç seçildiğinde merkez Workspace sonuç türüne göre değişir.

### Field sonucu

```text
Navigator │             Workspace              │ Inspector
          │                                    │
Sonuçlar  │             Contour                │ Asal Uzama λ1
          │                                    │ Scope
          │         Deformed / Undeformed       │ Source
          │                                    │ Projection
          │                                    │ Range
          │                                    │ Unit
```

### Global history sonucu

```text
Navigator │             Workspace              │ Inspector
          │                                    │
Sonuçlar  │           Tork–Açı Chart           │ X Axis
          │                                    │ Y Axis
          │                                    │ Scope
          │                                    │ Filtering
```

### Validation sonucu

```text
Navigator │             Workspace              │ Inspector
          │                                    │
Sonuçlar  │      FEA + Deney Overlay           │ Alignment
          │                                    │ Valid Range
          │      Error Curve / Metrics          │ Error Metric
```

## 9. Inspector

Inspector seçili `ResultObject` hakkında üç seviyede bilgi sunar.

### Basic

```text
Sonuç             Asal Uzama λ1
Kapsam            ELASTOMER_REGION
Adım              Son
Birim              —
Minimum           0.982
Maksimum          1.437
```

### Veri kaynağı

```text
Kaynak             Integration Point
Görüntüleme        Averaged to Nodes
Gauss Point        51,360
Eleman             12,840
Durum              Geçerli
```

### Advanced

```text
Projection Method
Averaging Domain
Component
Step / Increment
Range Method
Smoothing
Deformed Scale
Result Operation Chain
Provenance
```

Bu sayede kullanıcı sonucu görürken aynı zamanda verinin nasıl üretildiğini anlayabilir.

## 10. Contour sistemi

Contour görünümü elastomer analizine özgü ve sade olmalıdır.

V1.0 özellikleri:

- smooth / element-boundary görünümü
- deformed / undeformed overlay
- otomatik ve manuel renk aralığı
- min/max işaretleri
- selection highlight
- boundary overlay
- mesh overlay
- legend
- unit gösterimi
- step/increment seçimi
- scope bilgisi
- raw/display data indicator

Contour paleti mühendislik okunabilirliğini önceliklendirir. Dyna Design System'ın genel Apple/macOS görsel dili korunurken bilimsel contour renkleri UI accent renklerinden bağımsız yönetilir.

## 11. Chart sistemi

Chart, genel purpose plotting aracı değil mühendislik sonuç arayüzüdür.

V1.0:

- Torque–Angle
- Force–Displacement
- Tangent Stiffness
- Secant Stiffness
- Energy
- Convergence History
- Experimental Overlay
- Error Curve

Chart davranışı:

- zoom/pan
- data cursor
- point probe
- legend
- units
- CSV export
- selected range
- comparison overlay
- printable/report-ready görünüm

## 12. Table sistemi

Her sonuç gerektiğinde sayısal tabloya açılabilir.

Örnek:

```text
Element | Gauss Point | r | z | λ1 | λ2 | λ3 | J | p | W
```

veya:

```text
Açı [deg] | Tork [Nm] | Tangent Rijitlik [Nm/deg]
```

Tablo ile viewport/chart seçimi iki yönlü senkronize edilebilir.

## 13. GaussPointInspector

`GaussPointInspector` V1.0'ın bilimsel ayırt edici özelliklerinden biridir.

Kullanıcı bir elemanı ve integrasyon noktasını seçtiğinde en az şu bilgiler gösterilir:

```text
Element ID
Integration Point ID
Koordinatlar
F
J
λ1, λ2, λ3
Cauchy stress
Pressure
Shear
Strain energy density
Material state
Status
```

Gauss Point Inspector, debug ekranı değildir; production mühendislik aracıdır.

## 14. Probe ve Path

### Probe

- node
- element
- Gauss point
- yakın konum
- seçili result field

Probe sonucu viewport ve Inspector içinde görünür.

### Path

Path; geometri veya sonuç alanı üzerinde tanımlanabilir.

Örnek kullanım:

- bağlı kauçuk kalınlığı boyunca λ1
- radyal doğrultuda basınç
- yüksek kayma bölgesinde shear stress

Path sonucu otomatik chart/table oluşturabilir.

## 15. Engineering Results

Dyna'nın temel farklılaştırıcısı generic field sonuçlarını doğrudan mühendislik büyüklüklerine dönüştürmesidir.

### Torque–Angle

```text
Prescribed Rotation
      ↓
Reaction Torque
      ↓
Torque–Angle History
```

### Tangent stiffness

```text
Kt = dT / dθ
```

Türev yöntemi ve smoothing/filter bilgisi provenance içinde tutulmalıdır.

### Secant stiffness

```text
Ksec = T / θ
```

### Force–Displacement

Reaksiyon kuvveti ile prescribed displacement eşleştirilir.

Mühendislik sonuçları kullanıcı tarafından ayrıca spreadsheet kurulmadan üretilebilmelidir.

## 16. Deneysel doğrulama

Doğrulama Results sisteminin native parçasıdır.

```text
FEA History
    +
Fiziksel Test History
        ↓
Alignment
        ↓
Overlay
        ↓
Error Metrics
```

V1.0 hedefleri:

- RMSE
- maximum absolute error
- mean error
- relative error
- stiffness error
- valid comparison range

Kullanıcı aynı workspace içinde FEA eğrisi, test eğrisi ve hata eğrisini görebilmelidir.

## 17. Durum ve güven göstergeleri

Bir `ResultObject` yalnız değer değil durum bilgisi de taşır.

Örnek status:

```text
VALID
WARNING
OUT_OF_VALIDATED_MATERIAL_RANGE
EXTRAPOLATED
STALE
UNAVAILABLE
ERROR
```

Örnek uyarı:

> Sonuç, kalibre edilmiş malzeme verisinin doğrulanmış uzama aralığının dışındaki bölgeleri içeriyor.

Bu bilgi contour'un kendisini gizlemez; Inspector ve status badge ile açıkça gösterilir.

## 18. Sonuç yeniden hesaplama ve stale state

Model, mesh, material veya analysis setup değiştiğinde eski sonuçlar otomatik olarak güncel kabul edilmez.

```text
Model değişti
    ↓
ResultObject = STALE
    ↓
Solve gerekli
```

Sadece görüntüleme ayarı değişiklikleri solver sonucunu stale yapmaz.

## 19. Selection ve scoping entegrasyonu

Result scope ham node ID listesiyle değil kanonik `SelectionSet`, `BoundarySet`, `RegionSet` veya ilgili result scope nesneleriyle tanımlanır.

Bu sayede remesh sonrası mühendislik anlamı korunabilir.

## 20. Framework bağımsızlığı

Results mimarisinin kanonik katmanlarında Qt tipi bulunmaz.

```text
ResultDatabase       # Qt yok
ResultDefinition     # Qt yok
ResultOperation      # Qt yok
ResultObject         # Qt yok
ResultViewModel      # Qt yok
ViewportSceneModel   # Qt yok
        ↓
Qt Results Adapter
        ↓
QML Results UI
```

Qt yalnız mevcut frontend'i render eder. Gelecekte başka bir UI framework'ü aynı sonuç modelini kullanabilir.

## 21. Açık kaynak sistemlerden alınan mimari dersler

### FEBio / FEBio Studio

- material ve integration-point sonuçlarının bilimsel şeffaflığı
- postprocessing'in ayrı bir alt sistem olarak ele alınması
- model/result ayrımı

### PrePoMax / CalculiX

- sade FEA sonuç ağacı
- viewport ile sonuç seçiminin doğrudan ilişkisi
- solver/result data ile UI katmanının ayrılması

### ParaView

- veri dönüşümlerinin açık operation/pipeline mantığı
- field → operation → view ayrımı
- Basic/Advanced property yaklaşımı

Dyna bu sistemlerin UI'sini kopyalamaz; ilgili mimari ilkeleri elastomer odaklı bir product experience içinde birleştirir.

## 22. ANSYS ile hedeflenen kullanıcı deneyimi kıyası

Dyna'nın hedefi:

```text
ANSYS Mechanical
  → sonuç nesnesi kadar anlaşılır

FEBio
  → integration-point fiziği kadar şeffaf

ParaView
  → veri dönüşümü kadar düzenli

PrePoMax
  → gereksiz karmaşadan uzak

Dyna
  → elastomer mühendisliğine özel
```

Dyna, general-purpose result kataloğu yerine doğrudan elastomer kararlarını destekleyen sonuçları önceliklendirir.

## 23. V1.0 kullanıcı araçları

Zorunlu:

- ResultObject
- Results Navigator
- Contour
- Min / Max
- Node Probe
- Element Probe
- Gauss Point Inspector
- Path
- Chart
- History
- Reaction Force
- Reaction Torque
- Torque–Angle
- Force–Displacement
- Tangent / Secant Stiffness
- Result Scoping
- Derived Results
- Experimental Overlay
- Error Metrics
- Table
- CSV Export
- Engineering Report

## 24. Kabul kriterleri

Results V1.0 tamamlanmış sayılabilmesi için:

1. Raw integration-point data kayıpsız saklanmalıdır.
2. Display data raw data'yı overwrite etmemelidir.
3. Her görüntülenen derived result kaynağını ve operation zincirini kaydetmelidir.
4. Kullanıcı standard result'ları üç adımdan az etkileşimle oluşturabilmelidir.
5. Result Navigator elastomer mühendisliği terminolojisiyle anlaşılır olmalıdır.
6. Contour, Chart ve Table aynı ResultObject üzerinde senkronize çalışabilmelidir.
7. Gauss Point Inspector ham değerleri doğrudan gösterebilmelidir.
8. Torque–Angle ve Force–Displacement spreadsheet olmadan üretilebilmelidir.
9. FEA ve fiziksel deney sonucu aynı workspace içinde karşılaştırılabilmelidir.
10. Qt frontend kaldırıldığında kanonik result modeli geçerliliğini korumalıdır.

## 25. Yönlendirici ilke

> DynaElastomerSolver sonuçları yalnızca renklendirmez; fiziksel verinin nereden geldiğini, nasıl dönüştürüldüğünü ve elastomer mühendisliği açısından ne anlama geldiğini açıkça gösterir.
