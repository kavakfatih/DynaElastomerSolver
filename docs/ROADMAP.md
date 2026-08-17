# DynaElastomerSolver Yol Haritası

**Mimari temeli:** v1.2 — ANSYS / Hexagon Marc benchmark revizyonu

Aşağıdaki sürüm numaraları geliştirme kilometre taşlarıdır; yayın taahhüdü değildir.

## V0.1 — Hesaplama Temeli

Amaç: FEM uygulamasından önce taşınabilir ve test edilebilir bir Modern Fortran bilimsel çekirdeği oluşturmak.

Teslimatlar:

- CMake tabanlı cross-platform proje
- Fortran 2018 temeli
- macOS üzerinde gfortran build
- Windows üzerinde ifx build
- Windows üzerinde gfortran doğrulama build'i
- precision / constants / status modülleri
- matris ve tensör yardımcıları
- deformasyon gradyanı yardımcıları
- invariant hesapları
- malzeme modeli soyut arayüzleri
- malzeme kinematiği / cevap tipleri
- Neo-Hookean uygulaması
- material-point test sürücüsü
- analitik enerji/gerilme testleri
- sayısal tanjant kontrolü

Çıkış kriteri: Neo-Hookean malzeme cevabı tanımlı toleranslar içinde derleyiciden bağımsız olmalı ve bünye doğrulamasını geçmelidir.

## V0.2 — Hiperelastik Malzeme Kütüphanesi

Teslimatlar:

- Mooney-Rivlin
- Yeoh
- Ogden N1
- Ogden N2
- Ogden N3
- Arruda-Boyce
- Gent
- parametre metadatası
- kanonik parametre kuralları
- parametre doğrulama
- bünye kararlılığı/fiziksel kabul edilebilirlik kontrolleri
- her model için tanjant tanıları

Çıkış kriteri: her model, Material Core üretim uygunluk zincirinde material-point doğrulamasına kadar tüm aşamaları geçmelidir.

## V0.3 — Kalibrasyon Motoru / Material Lab Temeli

Teslimatlar:

- fiziksel malzeme kaydı
- deneysel veri kümesi modeli
- ham ve işlenmiş test verisi izlenebilirliği
- tek eksenli çekme veri yolu
- mühendislik gerilme/şekil değiştirme dönüşüm yardımcıları
- amaç fonksiyonu API'si
- optimizer arayüzü
- ilk optimizer uygulamaları
- parametre sınırları
- RMSE / R² / residual metrikleri
- kalibrasyon provenance/kaynak takibi
- malzeme parametre kümesi depolama
- model karşılaştırma
- doğrulama durum modeli

Daha sonra şu veri türlerine genişletilecek:

- basma
- basit kayma
- düzlemsel çekme
- iki eksenli çekme
- hacimsel/sıkıştırılabilirlik verisi

Çıkış kriteri: kalibrasyon round-trip testleri bilinen sentetik parametre kümelerini tolerans içinde yeniden üretmeli ve provenance bilgisi korunmalıdır.

## V0.4 — FEM Doğrulama Temeli

Amaç: basit bir doğrulama elemanıyla ilk tam doğrusal olmayan FEM zincirini oluşturmak.

Teslimatlar:

- düğüm / eleman / `InternalMesh` modeli
- genelleştirilmiş DOF yöneticisi
- Q4 düzlem şekil değiştirme doğrulama elemanı
- shape function'lar
- Gauss integrasyonu
- deformasyon gradyanı hesabı
- eleman residual'ı
- consistent tangent
- global assembly
- yer değiştirme sınır şartları
- temel Newton çözücüsü
- yakınsama izleme
- küçük testler için basit dense/LAPACK doğrusal çözücü yolu
- ilk `AnalysisPrecheck` altyapısı
- ilk ham integrasyon noktası sonuç depolaması

Çıkış kriteri: Neo-Hookean düzlem şekil değiştirme benchmark'ları ve mesh yakınsama testleri geçmeli; geçersiz temel modeller çözümden önce reddedilmelidir.

## V0.5 — Karma u-p / Sıkıştırılamazlık Temeli

Amaç: yalnız doğrulama amaçlı yer değiştirme elemanlarından üretim odaklı yaklaşık sıkıştırılamaz elastomer teknolojisine geçmek.

Teslimatlar:

- basınç alanı
- genelleştirilmiş karma DOF altyapısı
- `IIncompressibilityStrategy`
- karma residual/tanjant blokları
- karma eleman formulasyonu araştırma/uygulaması
- sıkıştırılamazlık doğrulaması
- yalnız yer değiştirme formulasyonuna karşı volumetric locking karşılaştırması
- `AnalysisPrecheck` içinde malzeme/formulasyon uyumluluk kontrolleri

Çıkış kriteri: benchmark problemleri kabul edilemez locking olmadan kararlı yaklaşık sıkıştırılamaz davranış göstermelidir.

## V0.6 — Eksenel Simetrik Analiz

Teslimatlar:

- eksenel simetrik kinematik
- `ur, uz` formulasyonu
- karma `ur, uz, p` formulasyonu
- `2πR` integrasyonu
- eksenel simetrik sınır/seçim kümeleri
- eksenel simetrik geometri kontrolleri
- eksenel simetrik benchmark seti

Çıkış kriteri: analitik/referans eksenel simetrik benchmark'lar ve mesh yakınsama testleri geçmelidir.

## V0.7 — Eksenel Simetrik Burulma

Bu özellik projenin temel farklılaştırıcılarından biridir.

Teslimatlar:

- genelleştirilmiş burulma alanı `φ`
- `ur, uz, φ` kinematiği
- karma `ur, uz, φ, p` formulasyonu
- tanımlı dönme sınır şartı
- reaksiyon torku
- tork–açı geçmişi
- burulma rijitliği hesabı
- gerektiğinde burulmaya özgü yakınsama büyüklükleri
- burulma benchmark seti

Çıkış kriteri: DynaElastomerSolver sonuçları, tanımlı mühendislik toleransları içinde bağımsız referans çözücüler ve seçilmiş fiziksel burulma testleriyle uyuşmalıdır.

## V0.8 — NonlinearSolutionManager / Sağlamlık

Amaç: temel Newton döngüsünü üretim odaklı bir doğrusal olmayan çözüm alt sistemine dönüştürmek.

Teslimatlar:

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

Ek gereksinimler:

- otomatik yük adımlama
- başlangıç/minimum/maksimum increment kontrolleri
- adım büyütme
- cutback ve yeniden deneme politikası
- çoklu yakınsama kriterleri
- residual kuvvet izleme
- uygun olduğunda moment/tork izleme
- yer değiştirme/dönme düzeltmesi izleme
- negatif `J` / ağır eleman bozulması tespiti
- sağlam state rollback / commit
- ayrıntılı yakınsama geçmişi
- Automatic ve Advanced çözücü kontrol modları

Gelecek araştırmaları:

- arc-length / continuation yöntemleri
- stabilizasyon teknikleri
- gelişmiş predictor stratejileri

Çıkış kriteri: tanımlı zor doğrusal olmayan benchmark'lar belgelenmiş step/cutback geçmişleriyle tekrarlanabilir biçimde yakınsamalıdır.

## V0.9 — Mühendislik Pre/Post Processor

### Geometri

- DXF import adaptörü
- projeye ait `AnalysisGeometry`
- line / arc / spline yorumlama
- loop/region oluşturma
- geometri doğrulama/iyileştirme
- Geometry Check → Repair → Recheck iş akışı
- katman metadatası
- eksen tanımı
- adlandırılmış sınırlar
- `SelectionSet`

Genel amaçlı eskiz/CAD araçları planlanmamaktadır.

### Mesh

- `IMeshProvider`
- Gmsh adaptörü
- genişletilmiş `InternalMesh`
- eleman/sınır/bölge/malzeme kümeleri
- eleman yönelim metadatası
- integrasyon şeması metadatası
- mesh kalite metadatası
- sınır/bölge eşleme
- `MeshPrecheck`
- global boyut
- kenar boyutu / bölme kontrolleri
- lokal/bölgesel refinement
- desteklendiğinde mapped/structured quad talebi

### Analiz ön kontrolü

Şu alanlardan gelen doğrulamalar birleştirilecek:

- geometri
- mesh
- malzeme
- eleman/formulasyon
- sınır şartları
- çözücü konfigürasyonu

Kritik hatalar çözümü engeller; kritik olmayan konular uyarı olarak gösterilir.

### Sonuçlar

Açık ayrım uygulanacak:

```text
ResultDatabase
├── RawResults
│   ├── nodal birincil sonuçlar
│   └── integrasyon noktası sonuçları
├── DisplayResults
│   └── ekstrapole/ortalanmış nodal alanlar
└── GlobalHistories
```

Kullanıcı araçları:

- yer değiştirme/uzama/gerilme/basınç/J/enerji contour'ları
- sonuç kapsamlandırma
- min/max
- node probe
- element probe
- `GaussPointInspector`
- path
- chart/history
- reaksiyon kuvveti/torku
- kuvvet–yer değiştirme
- tork–açı
- tangent/secant rijitlik
- türetilmiş sonuçlar
- CSV export
- mühendislik raporu

### Deneysel karşılaştırma

- ürün test geçmişi içe aktarma
- simülasyon/test overlay
- RMSE
- maksimum/ortalama/bağıl hata
- rijitlik hatası
- karşılaştırma geçerlilik aralığı

Çıkış kriteri: DXF → mesh → solve → inspect → testle karşılaştır zinciri harici post-processing yazılımı olmadan tamamlanabilmelidir.

## V1.0 — Doğrulanmış Elastomer Analiz Platformu

Hedef iş akışı:

```text
Fiziksel Malzeme / Deneysel Veri
 ↓
Kalibrasyon / Malzeme Doğrulama
 ↓
DXF
 ↓
AnalysisGeometry
 ↓
Mesh
 ↓
AnalysisPrecheck
 ↓
Sonlu Şekil Değiştirmeli Doğrusal Olmayan FEM
 ↓
Düzlem / Eksenel Simetrik / Eksenel Simetrik Burulma
 ↓
Ham + Mühendislik Sonuçları
 ↓
Bağımsız Çözücü Benchmark'ları
 ↓
Fiziksel Ürün Testi Karşılaştırması
 ↓
Doğrulama
```

V1.0, gerekli doğrulama matrisi tamamlanmadan mühendislik platformu olarak kabul edilmez.

## Gelecek araştırma alanları

İlk V1.0 kapsamına bağlı değildir:

- viskoelastisite
- hız bağımlılığı
- Mullins etkisi
- histerezis
- malzeme hasarı
- çevrimsel elastomer davranışı
- kauçuk yorulma/ömür yöntemleri
- harmonik/dinamik analiz
- transient dinamik
- temas
- rigid-body tanımları
- elastomere özgü otomatik mesh üreticisi
- deforme profil DXF export
- ANSYS material/user-material adaptörleri
- Marc UMATERIAL adaptörü
- CalculiX material adaptörü
- alternatif seyrek çözücü backend'leri

## Geliştirme kuralı

Her bilimsel özellik şu zinciri izler:

```text
Teori
 ↓
Uygulama
 ↓
Unit / Bünye Doğrulaması
 ↓
Material-Point / Eleman Benchmark
 ↓
Mesh Yakınsaması
 ↓
Bağımsız Çözücü Karşılaştırması
 ↓
Uygun Olduğunda Deneysel Doğrulama
```

## Ürün ilkesi

DynaElastomerSolver genel amaçlı CAE sistemleriyle kapsam genişliğinde yarışmaz. Amaç; elastomer malzeme karakterizasyonu, doğrusal olmayan ürün analizi ve deneysel doğrulama için daha doğrudan ve şeffaf bir mühendislik zinciri sağlamaktır.