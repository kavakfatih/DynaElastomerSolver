# DynaElastomerSolver

DynaElastomerSolver; kauçuk/elastomer malzemeler ve elastomer tabanlı ürünler için doğrusal olmayan sonlu eleman analizi, malzeme karakterizasyonu ve doğrulama odaklı bilimsel bir mühendislik platformudur.

**Mevcut mimari temeli:** `v1.2 — ANSYS / Hexagon Marc benchmark revizyonu`  
**UI mimarisi temeli:** `v1.1 — değiştirilebilir UI sınırı arkasında Qt frontend`  
**Results mimarisi temeli:** `v1.0 — ANSYS kadar anlaşılır, elastomer odaklı ve bilimsel olarak izlenebilir sonuç sistemi`

## Proje odağı

Proje bilinçli olarak genel amaçlı bir CAE paketi **değildir**. Amaç, elastomer mekaniğinde uzmanlaşmak ve şu alanlar için odaklı bir mühendislik zinciri sağlamaktır:

- büyük deformasyonlu doğrusal olmayan analiz
- düzlem şekil değiştirme analizi
- eksenel simetrik analiz
- eksenel simetrik burulma
- çekme, basma ve kayma
- yaklaşık sıkıştırılamaz karma formulasyonlar
- hiperelastik bünye modelleri
- deneysel malzeme kalibrasyonu
- tork–açı ve kuvvet–yer değiştirme tahmini
- şeffaf integrasyon noktası sonuçları
- bağımsız çözücü doğrulaması
- fiziksel ürün testi doğrulaması

## Temel iş akışı

```text
Fiziksel Malzeme / Deneysel Veri
              ↓
      Kalibrasyon / Material Core
              ↓
Harici CAD → DXF
              ↓
      AnalysisGeometry
              ↓
 Geometri Doğrulama / Topoloji
              ↓
        IMeshProvider
              ↓
         InternalMesh
              ↓
       AnalysisPrecheck
              ↓
 Modern Fortran FEM Çekirdeği
              ↓
 NonlinearSolutionManager
              ↓
        ILinearSolver
              ↓
        ResultDatabase
              ↓
 Son İşleme / Test Karşılaştırması
```

Bilimsel çekirdek **Modern Fortran** ile geliştirilmektedir. Mesh üreticileri, seyrek doğrusal çözücüler ve UI framework'leri gibi harici sistemler arayüz/adaptör sınırları arkasında tutulur; böylece proje mimarisi tek bir uygulamaya bağımlı hale gelmez.

## Sayısal teknoloji yığını

- **Dil temeli:** Fortran 2018
- **Taşınabilir yeni özellikler:** hedef derleyicilerin desteklediği seçilmiş Fortran 2023 özellikleri
- **macOS / Apple Silicon:** GNU gfortran
- **Windows x64:** Intel ifx + GNU gfortran doğrulaması
- **Build sistemi:** CMake
- **İlk mesh sağlayıcısı:** Gmsh adaptörü
- **İlk seyrek doğrusal çözücü:** MUMPS adaptörü

## Malzeme modelleri — V1.0 hedefi

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1 / N2 / N3
- Arruda-Boyce
- Gent

Material Core çözücüden bağımsızdır. FEM, kalibrasyon, material-point doğrulaması ve gelecekteki harici çözücü adaptörleri aynı kanonik bünye uygulamasını kullanır.

Bünye davranışı ile FE sıkıştırılamazlık uygulama yöntemi birbirinden ayrı mimari konulardır.

## Doğrusal olmayan çözüm mimarisi

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

Düşük seviyeli seyrek çözücü yalnızca kurulmuş cebirsel sistemi çözer; doğrusal olmayan FEM fiziği ve çözüm yönetimi projeye ait kalır.

## Geometri yaklaşımı

DynaElastomerSolver bir CAD/eskiz uygulaması **değildir**. Geometri harici bir CAD sisteminde hazırlanır ve öncelikle DXF üzerinden içeri alınır. Uygulama bu geometrileri analiz bölgelerine, sınırlara ve seçim kümelerine dönüştürür, doğrular ve yorumlar.

## UI yaklaşımı

DynaElastomerSolver mühendislik kullanıcı deneyiminin tamamına kendisi sahip olur. Başka bir CAE uygulamasının kullanıcı arayüzünü gömmez.

Bilgi mimarisi ANSYS'ten esinlenir ancak elastomer mühendisliği için sadeleştirilir:

```text
Bağlamsal Araç Çubuğu
      ↓
Navigator | Workspace | Inspector
      ↓
Yardımcı / Solver / Yakınsama Paneli
```

Üst seviye çalışma alanları:

```text
Proje → Geometri → Material Lab → Mesh → Analiz → Çöz → Sonuçlar → Doğrulama
```

Görsel dil geleneksel CAE yazılımlarından bilinçli olarak farklıdır: minimal, teknik ve Apple/macOS esintili.

İlk üretim masaüstü frontend'i:

```text
Qt 6
+ Qt Quick / QML
+ Dyna Design System
```

Qt, **değiştirilebilir bir frontend/platform bağımlılığıdır**. Bilimsel/domain modelleri, uygulama servisleri, navigasyon anlamı, seçim durumu, Inspector şemaları, sonuç tanımları, viewport scene verisi ve proje dosyası anlamı Qt'den bağımsız kalır.

```text
Modern Fortran Core
        ↓
`des_*` C ABI
        ↓
Dyna Application Core       # Qt yok
        ↓
Dyna Presentation Contracts # Qt yok
        ↓
Qt Frontend Adapters
        ↓
Qt Quick / QML
```

Bu nedenle gelecekte Avalonia, SwiftUI/AppKit, WinUI veya başka bir frontend; bilimsel çözücü ya da kanonik mühendislik modelleri yeniden yazılmadan eklenebilir.

## Sonuç yaklaşımı

Dyna Results sistemi ANSYS Mechanical'daki anlaşılır sonuç nesnesi kullanımını; FEBio'nun integrasyon noktası şeffaflığı, ParaView'in veri dönüşüm disiplini ve PrePoMax'ın sadeliği ile birleştirir.

Kanonik yapı:

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

Ham integrasyon noktası fiziği, ekstrapole/ortalama alınmış görüntüleme sonuçlarından ayrı tutulur.

```text
ResultDatabase
├── RawResults
│   ├── NodalPrimaryResults
│   └── IntegrationPointResults
├── DisplayResults
├── DerivedResults
└── GlobalHistories
```

V1.0 hedefleri arasında:

- ANSYS benzeri anlaşılır `ResultObject` yapısı
- elastomer odaklı Results Navigator
- Contour / Chart / Table görünümü
- Min/Max ve Probe araçları
- birinci sınıf `GaussPointInspector`
- Tork–Açı ve Kuvvet–Yer Değiştirme
- Tangent ve Sekant Rijitlik
- deneysel test overlay ve hata metrikleri
- sonuç kaynağı/projection/provenance şeffaflığı

bulunur.

Qt yalnız Results frontend'ini render eder; `ResultDatabase`, `ResultDefinition`, `ResultOperation`, `ResultObject`, `ResultViewModel` ve `ViewportSceneModel` Qt'den bağımsız kalır.

## Dokümantasyon

- `docs/PROJECT_CONTEXT.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/architecture/UI_ARCHITECTURE.md`
- `docs/architecture/RESULTS_ARCHITECTURE.md`
- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/decisions/ADR-0002-ANSYS-MARC-BENCHMARK-REVISION.md`
- `docs/decisions/ADR-0003-OWNED-UI-ARCHITECTURE.md`
- `docs/decisions/ADR-0004-QT-FRONTEND-BOUNDARY.md`
- `docs/benchmarks/ANSYS_MARC_COMPARISON.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`
- `docs/ROADMAP.md`

## Mevcut durum

Kodlamaya geçmeden önce mimari ve bilimsel temeller tanımlanmaktadır. İlk uygulama kilometre taşı, tam FEM çözücüsünden önce bünye malzeme motorunu ve doğrulama altyapısını oluşturacaktır.

UI teknoloji yığını mimari olarak Qt 6 / Qt Quick-QML şeklinde seçilmiştir ve katı bir değiştirme sınırı bulunmaktadır. Results mimarisi de kullanıcı-facing `ResultObject` yapısı ve elastomer odaklı Navigator dahil olmak üzere v1.0 seviyesinde tanımlanmıştır.

Geniş ekran uygulamasına geçmeden önce macOS Apple Silicon ve Windows üzerinde UI bağımlılık sınırını doğrulayan küçük bir shell/viewport/native-ABI teknik prototipi oluşturulacaktır.