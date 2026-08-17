# ADR-0004 — Değiştirilebilir UI Sınırı Arkasında Qt Frontend

**Durum:** Kabul edildi  
**Proje:** DynaElastomerSolver

## Bağlam

DynaElastomerSolver, hem macOS hem Windows üzerinde çalışabilen tek bir profesyonel masaüstü frontend'e ihtiyaç duyar. Ürün; Apple/macOS esintili görsel dili korurken CAE tipi navigasyon, Inspector'lar, mühendislik grafikleri, özel 2D/eksenel simetrik viewport, solver izleme ve gelecekte yüksek performanslı görselleştirme gereksinimlerini desteklemelidir.

Qt 6 / Qt Quick bu ihtiyaçlar için olgun bir cross-platform masaüstü ve grafik altyapısı sağlar. Buna rağmen DynaElastomerSolver içeride Qt biçiminde şekillenmiş bir uygulamaya dönüşmemelidir. Gelecekte farklı bir UI teknolojisine geçiş; bilimsel çekirdeği, proje modelini, uygulama davranışını veya mühendislik etkileşim modelini yeniden yazmayı gerektirmemelidir.

Bu karar ADR-0003'ün yalnız framework adayı bölümünü günceller. DynaElastomerSolver'ın UI mimarisine ve kullanıcı deneyimine sahip olduğu temel ilke geçerliliğini korur.

## Karar

İlk üretim masaüstü frontend'i:

```text
Qt 6
+ Qt Quick / QML
+ Dyna Design System
```

Qt, domain veya application bağımlılığı değil **değiştirilebilir frontend/platform bağımlılığı** olarak sınıflandırılır.

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

## Katı bağımlılık sınırı

Qt tipleri Qt frontend uygulama sınırı dışına çıkamaz.

Aşağıdaki tip ve kavramlar bilimsel çekirdekte, kanonik proje modelinde, application servislerinde veya framework-neutral presentation sözleşmelerinde bulunamaz:

- `QObject`
- `QString`
- `QVector`
- `QVariant`
- `QModelIndex`
- `QAbstractItemModel`
- `QQuickItem`
- QML nesne referansları
- domain event olarak Qt signals/slots
- kanonik proje formatı olarak Qt serialization

Qt'ye özgü kod şu sınırda tutulur:

```text
src/ui/frontends/qt/
```

## Framework-neutral presentation sözleşmeleri

DynaElastomerSolver UI ile ilişkili application state için tarafsız modellerin sahibidir:

```text
NavigationNode
SelectionState
InspectorSchema
InspectorProperty
CommandDescriptor
WorkspaceDescriptor
JobStatus
ConvergenceSample
ResultViewModel
ViewportSceneModel
DesignTokenSet
```

Qt adaptörü bu modelleri Qt/QML nesnelerine dönüştürür. Aynı neutral modeller daha sonra Avalonia, native veya başka frontend tarafından çizilebilir.

## Uygulama davranışı sahipliği

Aşağıdaki davranış Qt dışında kalır:

- proje state'i ve proje dosyası anlamı
- modül tanımları
- navigasyon hiyerarşisi
- selection semantics
- command enable/disable kuralları
- undo/redo niyeti
- validation ve precheck kuralları
- solver job state
- sonuç tanımları
- Inspector metadatası
- mühendislik birimleri ve doğrulama kuralları
- viewport scene verisi
- material, mesh, analysis ve result iş akışları

Qt yalnız render eder ve kullanıcı etkileşimini iletir; bu anlamların sahibi değildir.

## Design system sahipliği

Apple/macOS esintili Dyna görsel dili projeye aittir.

```text
Color
Typography
Spacing
Radius
Stroke
ControlSize
Motion
Elevation
SemanticState
```

QML bu spesifikasyonları uygular; QML dosyaları görsel dilin kanonik tanımı değildir.

## Görselleştirme sınırı

```text
ViewportSceneModel
├── geometry primitives
├── mesh primitives
├── contour field data
├── selection state
├── boundaries
├── annotations
├── vectors
├── probes
└── camera state
```

Rendering:

```text
ViewportSceneModel
        ↓
IViewportRenderer
        ↓
QtViewportBackend
```

Qt renderer nesneleri `InternalMesh`, `ResultDatabase`, `AnalysisGeometry`, selection state veya result-processing koduna sızamaz. Gelecekte Metal, Vulkan, VTK, Avalonia veya başka bir backend kanonik mühendislik modelleri değiştirilmeden eklenebilir.

## Repository sınırı

```text
src/
├── fortran/                 # bilimsel çekirdek; Qt yok
├── application/             # application/domain servisleri; Qt yok
├── presentation/            # neutral UI contracts; Qt yok
└── ui/
    ├── design/              # kanonik Dyna design specification
    └── frontends/
        └── qt/
            ├── app/
            ├── adapters/
            ├── models/
            ├── qml/
            └── viewport/
```

## Build sınırı

```text
DynaCoreFortran        -> Qt yok
DynaApplication        -> Qt yok
DynaPresentation       -> Qt yok
DynaQtFrontend         -> Qt bağımlılığına izin var
DynaDesktopApp         -> DynaQtFrontend linkler
```

Alt katmanlarda Qt header'ı veya Qt-linked library görülürse build/architecture testleri başarısız olmalıdır.

## Platform stratejisi

İlk Qt frontend hedefleri:

- macOS / Apple Silicon
- Windows x64
- gerektiğinde ileride Windows ARM64

macOS ve Windows aynı Dyna bilgi mimarisini ve design system'i kullanır. Window chrome, menu, keyboard conventions ve OS entegrasyonu host platforma göre uyarlanabilir; mühendislik workflow'u değişmez.

## Lisans politikası

Qt lisansı açık bir altyapı konusu olarak yönetilir.

- yalnız bilinçli olarak onaylanmış Qt modülleri kullanılacak
- dağıtılan her Qt modülü için dependency/license registry tutulacak
- açık ürün/lisans kararı olmadan GPL-only modül eklenmeyecek
- lisans, ticari, teknik veya stratejik gereksinimler değişirse Qt'nin değiştirilebilme kabiliyeti korunacak

Ticari dağıtım modeli yayın öncesi ayrıca incelenmelidir.

## Sonuçlar

### Olumlu

- macOS ve Windows için tek frontend kod tabanı
- güçlü desktop ve grafik yetenekleri
- native seviyede engineering viewport yolu
- Apple/macOS esintili görünüm projeye ait kalır
- bilimsel ve application mimarisi Qt'den bağımsız kalır
- gelecekte frontend değişimi solver veya kanonik mühendislik modelleri yeniden yazılmadan mümkündür

### Maliyetler

- neutral presentation modelleri ile Qt/QML arasında adaptör bakımı gerekir
- frontend framework değişirse UI kodunun bir bölümü yeniden yazılır
- Qt tiplerinin alt katmanlara sızmasını engelleyen katı architecture testleri gerekir
- Qt modül/lisans seçimleri bilinçli olarak izlenmelidir

## Değiştirme testi

> `src/ui/frontends/qt` klasörünü kaldırmak mevcut masaüstü UI'yi kaldırabilir; ancak DynaElastomerSolver'ın bilimsel çekirdeğini, proje modelini, application servislerini, presentation sözleşmelerini, result database'i veya mühendislik iş akışlarını ortadan kaldırmamalı ya da geçersiz kılmamalıdır.

## Yönlendirici ilke

> Qt, DynaElastomerSolver'ın ilk frontend uygulamasıdır; Qt, DynaElastomerSolver'ın mimarisi değildir.