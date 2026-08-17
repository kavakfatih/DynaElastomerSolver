# DynaElastomerSolver — UI Mimarisi v1.1

## 1. Amaç

DynaElastomerSolver; kullanıcı deneyiminin, bilgi mimarisinin, mühendislik etkileşim modelinin ve görsel kimliğinin sahibidir.

İlk üretim masaüstü frontend'i **Qt 6 + Qt Quick/QML** kullanır ve hem macOS hem Windows'u hedefler. Qt bilinçli olarak değiştirilebilir bir frontend/platform bağımlılığı olarak ele alınır. Bilimsel çekirdek, uygulama davranışı, kanonik proje modeli ve framework'ten bağımsız presentation sözleşmeleri; ileride UI framework'ü değiştirilse bile kullanılabilir kalmalıdır.

ANSYS Mechanical ana bilgi-mimarisi referansıdır. FEBio Studio, SALOME, PrePoMax, Gmsh, ParaView, ElmerGUI, FEniCSx ve MFront ikincil mimari fikirler sağlar.

Görsel dil geleneksel CAE yazılımlarından bilinçli olarak farklıdır: minimal, hassas, teknik ve Apple/macOS esintili; beyaz/açık gri/koyu gri yüzeyler, sınırlı system-blue vurgu, küçük radius ve ağır dekorasyondan kaçınma temel prensiplerdir.

## 2. Sahiplik kuralı

```text
Dyna Scientific Core        PROJEYE AİT
Dyna Application Model      PROJEYE AİT
Dyna Presentation Contracts PROJEYE AİT
Dyna UI Architecture        PROJEYE AİT
Dyna Design System          PROJEYE AİT
Navigation / Selection      PROJEYE AİT
Inspector / Commands        PROJEYE AİT
Workspace behavior          PROJEYE AİT
Result interaction          PROJEYE AİT
Visualization data model    PROJEYE AİT

Qt 6 / Qt Quick / QML
        ↓
değiştirilebilir frontend/platform uygulaması
```

Hiçbir harici CAE uygulaması veya UI framework'ü DynaElastomerSolver'ın kanonik mühendislik durumunu tanımlayamaz.

## 3. Bağımlılık yönü

Bağımlılık yalnız tek yönde ilerler:

```text
Modern Fortran Scientific Core
              ↓
          `des_*` C ABI
              ↓
UI-independent Application Core
              ↓
Framework-neutral Presentation Contracts
              ↓
        Qt Frontend Adapters
              ↓
       Qt Quick / QML UI
```

Alt katmanlar Qt tiplerini import etmez, referans etmez veya dışarı açmaz.

### Katı sınır kuralı

Aşağıdaki tip ve kavramlar yalnızca Qt frontend uygulaması içinde kalmalıdır:

- `QObject`
- `QString`
- `QVector`
- `QVariant`
- `QModelIndex`
- `QAbstractItemModel`
- `QQuickItem`
- sunum altyapısında kullanılan Qt signals/slots
- QML nesne referansları
- Qt'ye özgü serialization
- Qt renderer handle'ları

Domain ve application kodu; framework'ten bağımsız yapılar, kararlı kimlikler, standart C/C++ tipleri ve kanonik Dyna modellerini kullanır.

## 4. Ana UX modeli

ANSYS'ten esinlenen ancak elastomer mühendisliği için sadeleştirilmiş bilgi mimarisi:

```text
┌──────────────────────────────────────────────────────────────┐
│ Bağlamsal Araç Çubuğu                                       │
├──────────────┬─────────────────────────────┬─────────────────┤
│ Navigator    │ Workspace                   │ Inspector       │
│              │                             │                 │
│ Proje        │ Geometri / Mesh             │ Özellikler      │
│ Malzemeler   │ Malzeme Eğrileri            │ Doğrulama       │
│ Analiz       │ Sonuçlar / Grafikler        │ Gelişmiş        │
│ Sonuçlar     │                             │                 │
├──────────────┴─────────────────────────────┴─────────────────┤
│ Yardımcı Panel: Mesajlar | Jobs | Solver | Yakınsama | Veri │
└──────────────────────────────────────────────────────────────┘
```

- Navigator: **Neredeyim ve hangi nesne üzerinde çalışıyorum?**
- Workspace: **Hangi mühendislik içeriğini görüntülüyor veya düzenliyorum?**
- Inspector: **Seçili nesnenin özellikleri ve doğrulama durumu nedir?**
- Context Toolbar: **Şu anda hangi işlemler anlamlı?**
- Utility Panel: **Sistem/solver şu anda ne yapıyor?**

## 5. Modül mimarisi

```text
DynaElastomerShell
        │
        ├── ProjectModule
        ├── GeometryModule
        ├── MaterialLabModule
        ├── MeshModule
        ├── AnalysisModule
        ├── SolveModule
        ├── ResultsModule
        └── ValidationModule
```

Her modül framework'ten bağımsız bir `ModuleDefinition` sunar:

```text
ModuleDefinition
├── NavigatorProvider
├── WorkspaceProvider
├── InspectorProvider
├── CommandProvider
├── ContextToolbarProvider
└── ValidationProvider
```

Gelecekte yorulma, viskoelastik karakterizasyon veya dinamik gibi yeni modüller AppShell yeniden tasarlanmadan eklenebilir.

## 6. Framework'ten bağımsız presentation sözleşmeleri

Presentation anlamı QML'e değil DynaElastomerSolver'a aittir.

```text
NavigationNode
SelectionState
InspectorSchema
InspectorSection
InspectorProperty
CommandDescriptor
WorkspaceDescriptor
ModuleDefinition
JobStatus
ConvergenceSample
NotificationModel
ResultViewModel
ViewportSceneModel
DesignTokenSet
```

Örnek:

```text
NavigationNode
      ↓
QtNavigationModel
      ↓
QML Navigator
```

Gelecekte aynı sözleşme farklı frontend tarafından tüketilebilir. Amaç UI markup'ını değil, **mühendislik davranışını ve uygulama durumunu taşınabilir kılmaktır**.

## 7. Ana uygulama servisleri

```text
ProjectDocument
ModuleRegistry
NavigationService
SelectionService
CommandRegistry
UndoRedoService
InspectorService
WorkspaceManager
JobManager
NotificationService
VisualizationService
ApplicationServices
```

### SelectionService

Seçim merkezi yönetilir ve Dyna entity kimliklerini saklar; `QModelIndex`, QML nesneleri veya renderer pointer'ları kanonik seçim modeline girmez.

### CommandRegistry

`Import DXF`, `Validate`, `Generate Mesh`, `Run Calibration`, `Solve`, `Probe` ve `Compare Test` gibi işlemler kayıtlı komutlardır. Böylece klavye kısayolları, native menüler, bağlamsal araç çubuğu, ileride command palette, undo/redo ve frontend değişimi desteklenebilir.

## 8. Workspace modeli

Merkez alan kalıcı bir geometri viewport'u değildir.

```text
Workspace
├── ProjectWorkspace
├── GeometryWorkspace
├── MaterialWorkspace
├── CalibrationWorkspace
├── MeshWorkspace
├── AnalysisWorkspace
├── SolveMonitorWorkspace
├── ResultsWorkspace
└── ValidationWorkspace
```

## 9. Bağlamsal Navigator

DynaElastomerSolver sonsuza büyüyen tek global tree kullanmaz.

```text
Project
Geometry
Materials
Mesh
Analysis
Solve
Results
Validation
```

Bir modüle girildiğinde Navigator o modüle özgü hale gelir. Geometry için Regions/Boundaries/Selection Sets/Axis; Material Lab için Library/Experimental Data/Material Models/Calibration/Validation; Analysis için Formulation/Material Assignment/Boundary Conditions/Solver Controls/Precheck örnek yapıları kullanılır.

## 10. Inspector mimarisi

Inspector içeriği seçili nesnenin metadatası ve gerektiğinde özel editörler tarafından belirlenir.

```text
Seçili Nesne
      ↓
InspectorService
      ↓
InspectorSchema / Editor Provider
      ↓
Frontend adapter
      ↓
Inspector UI
```

Qt/QML bir özelliğin nasıl çizileceğini belirler; mühendislik tanımına veya doğrulama kurallarına sahip olmaz.

## 11. Basic / Advanced modeli

Teknik güç, tüm solver parametrelerinin varsayılan olarak gösterilmesini gerektirmez. Basic mod sade mühendislik ayarları sunar; Advanced mod Newton stratejisi, yakınsama toleransları, maksimum iterasyon, line search, increment sınırları, mesh algoritması, integrasyon ve ekstrapolasyon ayarlarını açabilir.

Bilimsel varsayılanlar QML kontrollerine değil application katmanına aittir.

## 12. Deferred Apply

Mesh üretimi, geometri iyileştirme, kalibrasyon, çözüm ve maliyetli sonuç dönüşümleri her property değişikliğinde otomatik çalışmaz. Değişiklikler bekleyen state olarak tutulur ve açık bir Apply/Run komutuyla uygulanır.

## 13. AnalysisPrecheck UI

`AnalysisPrecheck` birinci sınıf workspace/panel'dir. Geometri, malzeme, mesh, kısıtlar ve solver durumu tek yerde gösterilir. Her problem ilgili nesne/modüle geri bağlanır. Kritik hata çözümü engeller.

## 14. Solve Monitor

Solver GUI'den bağımsız kalır; GUI yalnız yapılandırılmış job event'lerini gösterir.

```text
Solve Monitor
├── Geçerli step
├── Geçerli increment
├── Newton iterasyonu
├── Residual normu
├── Increment boyutu
├── Cutback olayları
├── Doğrusal çözücü durumu
├── Uyarılar
└── Yakınsama grafiği
```

Console text parse etmek birincil veri yolu değildir.

## 15. Sonuç mimarisi

```text
ResultDatabase
      ↓
ResultOperation
      ↓
ResultViewModel
      ↓
Visualization
```

Ham integrasyon noktası verileri ile ekstrapole/ortalanmış/türetilmiş görüntüleme sonuçları ayrı tutulur.

## 16. Native Gauss Point Inspector

Kullanıcı `F`, `J`, asal uzamalar, Cauchy stress, pressure, strain energy ve state variables gibi ham integrasyon noktası değerlerini doğrudan inceleyebilmelidir.

## 17. Görselleştirme sahipliği

Kanonik görselleştirme modeli projeye aittir:

```text
ViewportSceneModel
├── geometry primitives
├── mesh primitives
├── contour fields
├── selection state
├── boundaries
├── annotations
├── vectors
├── probes
└── camera state
```

Rendering sınırı:

```text
ViewportSceneModel
        ↓
IViewportRenderer
        ↓
QtViewportBackend
```

Qt renderer nesneleri `AnalysisGeometry`, `InternalMesh`, `ResultDatabase` veya presentation sözleşmelerine sızamaz. Gelecekte başka renderer/backend mühendislik modelleri değiştirilmeden eklenebilir.

## 18. UI framework politikası

Seçilen ilk frontend:

```text
Qt 6
+ Qt Quick / QML
+ Dyna Design System
```

Nedenler:

- macOS ve Windows için tek desktop frontend kod tabanı
- güçlü C++/QML ayrımı
- olgun desktop/input/graphics altyapısı
- yüksek performanslı özel mühendislik viewport'u için uygun yol
- kararlı Dyna C ABI'ye doğrudan native entegrasyon
- güçlü Apple Silicon/macOS desteği ve Windows uyumu

Qt bir frontend teknolojisidir; kanonik model değildir.

### Değiştirme testi

> `src/ui/frontends/qt` kaldırıldığında mevcut masaüstü UI kaybolabilir; ancak bilimsel çekirdek, proje modeli, application servisleri, presentation sözleşmeleri, result database veya mühendislik iş akışları geçersiz hale gelmemelidir.

Gelecekte Avalonia, SwiftUI/AppKit, WinUI veya başka bir frontend aynı alt katmanları kullanabilir.

## 19. Core bridge

```text
Qt/QML Frontend
      ↓
Qt Presentation Adapters
      ↓
Presentation Contracts
      ↓
Application Services
      ↓
Dyna Native Client
      ↓
`des_*` C ABI
      ↓
Modern Fortran Core
```

C ABI ayrıntılarını yalnız native client/interoperability katmanı bilir.

## 20. Dyna Design System

Dyna Design System projeye ait kanonik spesifikasyondur.

```text
DesignTokenSet
├── Color
├── Typography
├── Spacing
├── Radius
├── Stroke
├── ControlSize
├── Motion
├── Elevation
└── SemanticState
```

Görsel kimlik Apple/macOS esintili, minimal ve tekniktir. Beyaz/açık gri yüzeyler, koyu tipografi, sınırlı system-blue, dengeli boşluk, kompakt kontroller, küçük radius, hassas hizalama ve light/dark desteği kullanılır. Turuncu vurgu, ağır gölge, aşırı büyük kart, yoğun gradient ve sürekli görünür yoğun ribbon kullanılmaz.

## 21. Platform uyarlaması

macOS ve Windows aynı mühendislik UX'ini paylaşır. Native/global menü, klavye kuralları, titlebar ve deployment gibi shell ayrıntıları host işletim sistemine uyarlanabilir; application semantics çatallanmaz.

## 22. Repository sınırı

```text
src/
├── fortran/                     # Qt yok
├── application/                 # Qt yok
├── presentation/                # Qt yok
│   ├── navigation/
│   ├── inspector/
│   ├── commands/
│   ├── results/
│   └── viewport/
└── ui/
    ├── design/
    └── frontends/
        └── qt/
            ├── app/
            ├── adapters/
            ├── models/
            ├── qml/
            └── viewport/
```

## 23. Build sınırı

```text
DynaCoreFortran        -> Qt yok
DynaApplication        -> Qt yok
DynaPresentation       -> Qt yok
DynaQtFrontend         -> Qt kullanımına izin var
DynaDesktopApp         -> DynaQtFrontend linkler
```

Alt katmanlarda Qt include veya Qt-linked kütüphane tespit edilirse build/lint testi başarısız olmalıdır.

## 24. Qt lisans/bağımlılık politikası

Yalnız bilinçli olarak onaylanmış Qt modülleri kullanılır. Dağıtılan her modül için dependency/license registry tutulur. Açık ürün/lisans kararı olmadan GPL-only modül eklenmez. Desteklenen Qt sürümleri sabitlenir ve doğrulanır. Ticari dağıtım lisanslaması yayın öncesi ayrıca incelenir.

## 25. Harici UI bağımlılık kuralı

Kontrollü sınırlar arkasında Qt frontend/platform servisleri, düşük seviyeli renderer, font/text shaping ve OS entegrasyonuna izin verilir.

Mimari sahibi olmasına izin verilmez:

- gömülü ParaView veya FEBio Studio uygulaması
- host shell olarak FreeCAD/SALOME
- harici proje yöneticisi
- kanonik editör olarak harici material UI
- domain/application modellerinde Qt tipleri
- kanonik proje state'i olarak QML

> Harici UI teknolojileri kontrolleri render edebilir ve host edebilir; mühendislik deneyimi, uygulama durumu ve bilimsel etkileşim modeli DynaElastomerSolver'a aittir.

## 26. İlk ekran sırası

1. Project
2. Geometry
3. Material Lab
4. Mesh
5. Analysis
6. Precheck / Solve
7. Results
8. Validation

Bu ekranlar tek AppShell ve tek proje modelini paylaşır.

## 27. Geçerli karar kayıtları

- ADR-0003 — Owned UI Architecture
- ADR-0004 — Qt Frontend Behind a Replaceable UI Boundary