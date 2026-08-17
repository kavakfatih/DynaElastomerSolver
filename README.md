# DynaElastomerSolver

DynaElastomerSolver; kauçuk/elastomer malzemeler ve elastomer tabanlı ürünler için doğrusal olmayan sonlu eleman analizi, malzeme karakterizasyonu ve doğrulama odaklı bilimsel bir mühendislik platformudur.

**Mevcut mimari temeli:** `v1.2 — ANSYS / Hexagon Marc benchmark revizyonu`  
**Solver mimarisi temeli:** `v1.3 — nonlineer elastomer solver uzmanlaşması`  
**UI mimarisi temeli:** `v1.1 — değiştirilebilir UI sınırı arkasında Qt frontend`  
**Results mimarisi temeli:** `v1.0 — ANSYS kadar anlaşılır, elastomer odaklı ve bilimsel olarak izlenebilir sonuç sistemi`

## Proje odağı

Proje bilinçli olarak genel amaçlı bir CAE paketi **değildir**. Ana hedefler:

- büyük deformasyonlu doğrusal olmayan elastomer analizi
- yaklaşık sıkıştırılamaz mixed `u-p` formulasyonları
- hiperelastik bünye modelleri ve deneysel kalibrasyon
- düzlem şekil değiştirme, eksenel simetri ve eksenel simetrik burulma
- tork–açı ve kuvvet–yer değiştirme tahmini
- bağımsız çözücü ve fiziksel ürün testi doğrulaması

## Temel iş akışı

```text
Deneysel Veri / Material Lab
        ↓
Material Core
        ↓
AnalysisGeometry → InternalMesh → AnalysisPrecheck
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

Bilimsel çekirdek **Modern Fortran** ile geliştirilmektedir. Harici mesh üreticileri, seyrek doğrusal çözücüler ve UI framework'leri arayüz/adaptör sınırları arkasında tutulur.

## Nonlineer elastomer solver yaklaşımı

DynaElastomerSolver solver geliştirmesinde genel amaçlı özellik sayısına değil; büyük deformasyonlu ve yaklaşık sıkıştırılamaz elastomer problemlerinde sağlamlığa odaklanır.

```text
NonlinearSolutionManager
├── NonlinearStrategy
│   ├── FullNewton
│   ├── ModifiedNewton
│   └── QuasiNewton
│       ├── BFGS
│       └── Broyden
├── ConvergenceManager
├── IncrementController
├── LineSearchManager
├── DivergenceMonitor
├── RecoveryManager
├── StateManager
└── SolverDiagnostics
```

Birinci sınıf solver davranışları:

- adaptive increment, cutback ve retry
- trial / commit / revert / checkpoint state yönetimi
- residual force, displacement, moment/tork, rotation ve pressure convergence
- mixed `u-p` tanıları
- negative `J` ve ciddi eleman distorsiyonu tespiti
- açık `ConvergenceReason` / `DivergenceReason`
- linear solver raporlarını kullanan recovery kararları
- elastomer problem sınıflarına özel Automatic solver profilleri

Ayrıntılı tanım: `docs/architecture/SOLVER_ARCHITECTURE.md`

## Malzeme modelleri — V1.0 hedefi

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1 / N2 / N3
- Arruda-Boyce
- Gent

Material Core solver'dan bağımsızdır; FEM, kalibrasyon ve material-point doğrulaması aynı kanonik bünye uygulamasını kullanır.

## UI yaklaşımı

Bilgi mimarisi ANSYS'ten esinlenir, elastomer mühendisliği için sadeleştirilir ve Apple/macOS esintili Dyna Design System ile sunulur.

İlk üretim frontend'i:

```text
Qt 6 + Qt Quick/QML + Dyna Design System
```

Qt değiştirilebilir frontend/platform bağımlılığıdır. Bilimsel/domain modelleri, uygulama servisleri, sonuç anlamı ve presentation contracts Qt'den bağımsız kalır.

## Results yaklaşımı

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

Ham integration-point fiziği görüntüleme için ekstrapole/ortalama alınmış sonuçlardan ayrı tutulur. V1.0; elastomer odaklı Results Navigator, `GaussPointInspector`, tork–açı, kuvvet–yer değiştirme, tangent/secant rijitlik ve deneysel overlay hedefler.

## Dokümantasyon

- `docs/PROJECT_CONTEXT.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/architecture/SOLVER_ARCHITECTURE.md`
- `docs/architecture/UI_ARCHITECTURE.md`
- `docs/architecture/RESULTS_ARCHITECTURE.md`
- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/decisions/ADR-0002-ANSYS-MARC-BENCHMARK-REVISION.md`
- `docs/decisions/ADR-0003-OWNED-UI-ARCHITECTURE.md`
- `docs/decisions/ADR-0004-QT-FRONTEND-BOUNDARY.md`
- `docs/decisions/ADR-0005-NONLINEAR-ELASTOMER-SOLVER-SPECIALIZATION.md`
- `docs/benchmarks/ANSYS_MARC_COMPARISON.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`
- `docs/ROADMAP.md`

## Mevcut durum

Mimari ve bilimsel temeller tanımlanmıştır; gerçek implementasyon henüz başlamamıştır. İlk uygulama kilometre taşı Material Core ve bünye doğrulama altyapısıdır. Solver mimarisi v1.3 ile proje odağı nonlineer elastomer çözüm sağlamlığına sıkı biçimde bağlanmıştır.
