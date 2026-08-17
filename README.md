# DynaElastomerSolver

DynaElastomerSolver; kauçuk/elastomer malzemeler ve elastomer tabanlı ürünler için doğrusal olmayan sonlu eleman analizi, malzeme karakterizasyonu ve doğrulama odaklı bilimsel bir mühendislik platformudur.

**Ana ürün yönü:** nonlineer elastomer solver uzmanlaşması  
**Geliştirme disiplini:** implementasyon öncelikli doğrulama — ADR-0006  
**UI:** Qt 6 / Qt Quick-QML, değiştirilebilir frontend sınırı arkasında  
**Results:** elastomer odaklı, ham integrasyon noktası verisini görüntüleme sonuçlarından ayıran sonuç sistemi

## Proje odağı

Proje genel amaçlı CAE paketlerinin özellik sayısını kopyalamayı hedeflemez. Ana hedef; aşağıdaki dar problem sınıfında yüksek doğruluk, sağlam nonlinear çözüm ve deneysel doğrulamadır:

- quasi-static büyük deformasyon
- hiperelastik elastomer
- yaklaşık sıkıştırılamaz davranış
- bonded metal–elastomer sistemleri
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- tork–açı ve kuvvet–yer değiştirme cevabı

ANSYS Mechanical ve Hexagon Marc genel kapsam parity hedefi değil; seçilmiş elastomer problemlerinde doğruluk ve nonlinear robustness benchmark'ıdır.

## Geliştirme ilkesi

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.

İlk çalışan dikey dilim:

```text
Neo-Hookean
   ↓
Material-point
   ↓
Energy / Stress / Consistent Tangent
   ↓
FD Tangent Checker
   ↓
Q4 Plane-Strain
   ↓
Element Residual + Tangent
   ↓
Global Assembly
   ↓
Full Newton
   ↓
Dense/LAPACK
   ↓
Analitik + Bağımsız Solver Benchmark
```

Bu zincir doğrulanmadan geniş material library, kapsamlı calibration, binary plugin sistemi, tam UI veya çoklu Quasi-Newton implementasyonları öncelik değildir.

## Nearly-incompressible formulation yaklaşımı

Production elastomer eleman formulasyonu peşinen sabitlenmez. İlk benchmark dalgasında en az şu adaylar karşılaştırılacaktır:

```text
Displacement-only Q4
        vs
Mixed u-p adayı
        vs
F-bar / eşdeğer locking azaltıcı aday
```

Karar; locking, pressure stability, mesh convergence, nonlinear convergence, distortion sensitivity, maliyet ve axisymmetric/torsion genişletilebilirliği üzerinden verilecek ve ayrı ADR ile sabitlenecektir.

## Solver yaklaşımı

Hedef mimari geniştir ancak implementasyon ihtiyaç kanıtlandıkça açılır.

İlk zorunlu solver yolu:

```text
Full Newton
+ consistent tangent
+ increment stepping
+ cutback / retry
+ trial / commit / revert
+ convergence diagnostics
```

Daha sonra gerçek benchmark ihtiyacına göre:

- line search
- Modified Newton
- BFGS / Broyden
- gelişmiş recovery
- elastomer Automatic profiles

eklenebilir.

`TrustRegion` ve `ArcLength/Continuation` V1.0 zorunluluğu değildir.

Ayrıntılı hedef mimari: `docs/architecture/SOLVER_ARCHITECTURE.md`

## Material Core

Material Core FEM'den bağımsızdır ve aynı kanonik constitutive implementation şu sistemler tarafından kullanılır:

- material-point doğrulaması
- FEM
- calibration
- gelecekteki adaptörler

İlk model Neo-Hookean'dır. Mooney-Rivlin, Yeoh ve Ogden ailesi ilk FEM zinciri doğrulandıktan sonra eklenir.

## V1.0 kapsam sınırı

### Dahil

- bonded/tied elastomer-metal
- finite strain
- nearly incompressible elastomer
- plane strain
- axisymmetric
- axisymmetric torsion
- displacement / rotation control
- reaction force / torque
- seçilmiş doğrulanmış hiperelastik modeller

### Dahil değil

- separation/frictional contact
- self-contact
- debonding
- viskoelastisite
- Mullins effect
- damage / fatigue / life prediction
- transient/harmonic/explicit dynamics
- binary User Material Plugin
- genel amaçlı CAD

V1.0 sonuçları **nonlinear structural response** olarak tanımlanır; Cauchy stress, principal stretch veya strain-energy density doğrudan kopma/ömür tahmini olarak yorumlanmaz.

## UI yaklaşımı

İlk production frontend:

```text
Qt 6 + Qt Quick/QML + Dyna Design System
```

Qt yalnız frontend/platform katmanıdır. Scientific core, application model, presentation contracts ve result semantics Qt'den bağımsız kalır.

Tam UI geliştirmesi solver doğrulamasının önüne geçirilmez; erken aşamada yalnız gerekli minimal teknik shell/test harness kullanılabilir.

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

Ham integration-point sonuçları, ekstrapole/ortalama alınmış display sonuçlarından ayrı tutulur. `GaussPointInspector`, torque–angle, force–displacement ve stiffness sonuçları temel ürün özellikleridir.

## Dokümantasyon

- `docs/PROJECT_CONTEXT.md`
- `docs/ROADMAP.md`
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
- `docs/decisions/ADR-0006-IMPLEMENTATION-FIRST-VALIDATION-AND-V1-SCOPE.md`

## Mevcut durum

Mimari yön yeterince tanımlanmıştır ve yeni mimari genişleme bilinçli olarak sınırlandırılmıştır. Sıradaki iş dokümantasyon değil, **V0.1 Material Core ve hemen ardından V0.2 ilk çalışan nonlinear FEM dikey dilimidir**.
