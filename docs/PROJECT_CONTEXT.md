# DynaElastomerSolver — Proje Bağlamı

**Mevcut mimari temeli:** v1.2 — ANSYS / Hexagon Marc benchmark revizyonu

## Amaç

DynaElastomerSolver; kauçuk/elastomer malzemeler ve bu malzemeleri kullanan ürünler için uzmanlaşmış bilimsel bir mühendislik analiz platformu olarak geliştirilmektedir.

Proje bilinçli olarak genel amaçlı CAE paketlerinin geniş kapsamını hedeflemez. Bunun yerine mühendislik odağı; elastomer bünye davranışı, malzeme kalibrasyonu, yaklaşık sıkıştırılamaz sonlu eleman formulasyonları, eksenel simetrik ürün analizi, sağlam doğrusal olmayan çözüm, şeffaf integrasyon noktası sonuçları ve deneysel doğrulamadır.

## Birincil analiz kapsamı

Başlangıçta desteklenmesi planlanan fizik alanları:

- 2D düzlem şekil değiştirme
- ilerleyen aşamada 2D düzlem gerilme
- eksenel simetrik analiz
- eksenel simetrik burulma / 2.5D formulasyon
- çekme
- basma
- basit kayma
- tork–açı cevabı
- kuvvet–yer değiştirme cevabı
- sonlu şekil değiştirme / büyük deformasyon
- yaklaşık sıkıştırılamaz elastomer davranışı

## İlk malzeme kapsamı

V1.0 hedef bünye kütüphanesi:

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1
- Ogden N2
- Ogden N3
- Arruda-Boyce
- Gent

Gelecekte viskoelastisite, hız bağımlılığı, Mullins etkisi, histerezis, hasar ve kauçuk yorulma/ömür yöntemleri araştırma kapsamına eklenebilir.

## Malzeme yaklaşımı

Fiziksel bir malzeme ile onun matematiksel bünye uyumu farklı nesnelerdir.

```text
Fiziksel Malzeme
  ├── kimlik / polimer / reçete / tedarikçi / lot
  ├── deneysel veri kümeleri
  ├── kalibrasyon kayıtları
  ├── bir veya daha fazla bünye parametre kümesi
  └── doğrulama kayıtları
```

Deneysel veri, kalibre edilmiş parametreler, model doğrulaması ve kaynak/provenance bilgisi birbirinden bağımsız olarak korunur.

Material Core çözücüden bağımsızdır ve şu sistemler tarafından ortak kullanılır:

- kalibrasyon
- FEM
- material-point testleri
- gelecekteki harici çözücü/malzeme adaptörleri

Yeni malzeme modelleri FEM kaynak kodu değiştirilerek değil, kanonik material-model/plugin arayüzü üzerinden eklenir.

## Sıkıştırılamazlık yaklaşımı

Bünye yasası ile FE sıkıştırılamazlık uygulama yöntemi farklı konulardır.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Kauçuk/elastomer malzemeler yaklaşık sıkıştırılamaz olduğu için karma `u-p` yaklaşımı erken üretim gereksinimidir.

## Geometri yaklaşımı

DynaElastomerSolver genel amaçlı bir 2D eskiz veya CAD modülü içermez.

Geometri harici ortamda oluşturulur ve başlangıçta DXF üzerinden içeri alınır. Uygulamanın sorumlulukları yalnızca şunlardır:

- DXF yorumlama
- topoloji oluşturma
- kapalı döngü ve bölge tespiti
- sınır ve seçim kümesi tanımlama
- geometri doğrulama/iyileştirme
- eksen tanımlama
- analiz metadatası
- mesh hazırlığı

İç geometri temsili DynaElastomerSolver'a aittir ve herhangi bir harici DXF kütüphanesine bağımlı değildir.

## Mesh yaklaşımı

Mesh üretimi `IMeshProvider` üzerinden dışsallaştırılır.

İlk uygulama:

- Gmsh adaptörü

Olası gelecek uygulamaları:

- alternatif açık kaynak mesh üreticisi
- içe aktarılmış mesh adaptörü
- amaca özel `ElastomerMeshProvider`

Tüm sağlayıcılar çıktıyı DynaElastomerSolver'ın kendi `InternalMesh` modeline dönüştürür.

`InternalMesh`; düğüm/elemanların yanında bölge/sınır/malzeme kümelerini, eleman yönelimini, integrasyon metadatasını ve mesh kalite bilgisini içerir.

## Analiz ön kontrolü

Birinci sınıf `AnalysisPrecheck` aşaması çözüm başlamadan önce modeli doğrular.

Kontrol kapsamı:

- geometri tanıları
- mesh kalitesi/yönelimi/bağlantısı
- malzeme parametre ve geçerlilik kontrolleri
- eleman/formulasyon uyumluluğu
- sıkıştırılamazlık stratejisi uyumluluğu
- sınır şartlarının yeterliliği
- çözücü ayar kontrolleri

Kritik hatalar çözümü engeller; uyarılar mühendislik incelemesi için görünür kalır.

## Çözücü yaklaşımı

Doğrusal olmayan sonlu eleman çözücüsü DynaElastomerSolver'ın parçasıdır ve Modern Fortran ile geliştirilir.

Üretim seviyesinde doğrusal olmayan çözüm tek bir Newton sınıfıyla temsil edilmez. Mimari şu yapıyı kullanır:

```text
NonlinearSolutionManager
├── NewtonSolver
├── ConvergenceManager
├── IncrementController
├── CutbackManager
├── LineSearch
├── Predictor
├── FailureRecovery
└── StateCommitManager
```

Başlangıçta planlanan tek harici çözücü bileşeni, şu tür sistemleri çözen düşük seviyeli seyrek doğrusal denklem çözücüsüdür:

`K * Δu = -R`

Bu bileşen `ILinearSolver` arkasında gizlenir. İlk aday: MUMPS.

## Sonuç yaklaşımı

Integrasyon noktalarında hesaplanan bünye alanları sessizce nodal sonuç olarak ele alınmaz.

```text
ResultDatabase
├── RawResults
│   ├── nodal birincil değerler
│   └── integrasyon noktası değerleri
├── DisplayResults
│   └── ekstrapole / ortalanmış alanlar
└── GlobalHistories
```

V1.0; contour, probe, path ve history araçlarının yanında birinci sınıf `GaussPointInspector` hedefler.

Elastomere özgü öncelikler; asal uzamalar, kayma büyüklükleri, hidrostatik basınç, `J`, şekil değiştirme enerjisi yoğunluğu, reaksiyon torku/kuvveti, tork–açı ve rijitliktir.

## Deneysel doğrulama yaklaşımı

Platform kapalı bir mühendislik zinciri hedefler:

```text
Deneysel Malzeme Verisi
        ↓
Kalibrasyon
        ↓
Bünye Modeli
        ↓
Doğrusal Olmayan FEM
        ↓
Fiziksel Ürün Testi
        ↓
Karşılaştırma / Hata Metrikleri
        ↓
Doğrulama Kaydı
```

Simülasyon/test üst üste bindirme ve hata metrikleri yalnız harici elektronik tablo işi değil, yerleşik ürün özellikleridir.

## Çözücü kontrolleri yaklaşımı

Kullanıcıya iki seviye sunulması planlanır:

- **Automatic:** uygulamanın seçtiği elastomer odaklı varsayılanlar
- **Advanced:** uzman kullanıcılar için açık Newton, yakınsama, increment, cutback, line-search ve doğrusal çözücü kontrolleri

## Dil ve platform politikası

- Modern Fortran
- Fortran 2018 temeli
- yalnız desteklenen derleyiciler arasında taşınabilir olduğunda Fortran 2023 özellikleri
- macOS / Apple Silicon: GNU gfortran
- Windows x64: Intel ifx ve GNU gfortran doğrulaması
- gelecekte Linux: GNU gfortran
- ana build sistemi olarak CMake
- public native API için `ISO_C_BINDING`

## Bilimsel sahiplik

Aşağıdakiler projenin temel bilimsel varlıklarıdır:

- kanonik malzeme modeli tanımları
- malzeme kalibrasyon motoru
- material-point altyapısı
- bünye gerilme/tanjant uygulaması
- Material Plugin API kuralları
- FEM kinematiği
- karma yaklaşık sıkıştırılamaz formulasyon
- eleman formulasyonları
- doğrusal olmayan çözüm yönetimi
- eksenel simetrik burulma formulasyonu
- sonuç anlamı ve ekstrapolasyon kuralları
- doğrulama altyapısı
- deneysel doğrulama iş akışı

Harici kütüphaneler değiştirilebilir uygulama ayrıntıları olarak kalır.

## Ticari çözücü benchmark politikası

ANSYS Mechanical ve Hexagon Marc; olgun mühendislik davranışı, çözücü sağlamlığı, sonuç yorumlama ve doğrulama için referans sistemlerdir.

Bunlar özellik sayısı hedefi değildir ve DynaElastomerSolver'ın iç mimarisini tanımlamaz.

## Depo dili politikası

17 Ağustos 2026 itibarıyla DynaElastomerSolver GitHub deposundaki insan tarafından okunan proje içeriği Türkçe tutulacaktır.

Türkçe kullanılacak alanlar:

- mimari ve tasarım dokümantasyonu
- ADR karar kayıtları
- roadmap ve proje bağlamı açıklamaları
- README
- issue/PR açıklamaları
- kod içi açıklamalar ve geliştirici notları
- kullanıcıya dönük metinler

Teknik uyumluluk ve yazılım ekosistemi nedeniyle aşağıdaki öğeler gerektiğinde İngilizce kalabilir:

- kaynak kod sembolleri ve public API adları
- sınıf, arayüz, modül ve fonksiyon isimleri
- `des_*` C ABI isimleri
- standart mühendislik terimleri ve standartların resmi adları
- üçüncü taraf kütüphane ve ürün adları
- teknik fayda sağlamıyorsa mevcut dosya/klasör isimleri

Temel ilke: **insan tarafından okunan proje açıklamaları Türkçe; makine/ABI/ekosistem uyumluluğu gerektiren teknik tanımlayıcılar gerektiğinde İngilizce** olacaktır.