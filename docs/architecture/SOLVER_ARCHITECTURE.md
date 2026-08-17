# DynaElastomerSolver — Nonlineer Elastomer Solver Mimarisi v1.3

**Durum:** Kabul edilmiş uzmanlaşma yönü  
**Odak:** Büyük deformasyonlu, yaklaşık sıkıştırılamaz, hiperelastik elastomer problemlerinde üretim seviyesinde sağlam doğrusal olmayan çözüm

## 1. Amaç

DynaElastomerSolver genel amaçlı bir doğrusal olmayan çözücü olmaya çalışmaz. Solver geliştirmesi özellikle kauçuk ve elastomer mekaniğinin zorlandığı alanlarda derinleşir:

- sonlu şekil değiştirme / büyük deformasyon
- yaklaşık sıkıştırılamaz davranış
- karma displacement-pressure (`u-p`) formulasyonları
- hiperelastik bünye modelleri
- yüksek kayma ve distorsiyon
- eksenel simetrik analiz
- eksenel simetrik burulma / 2.5D
- tanımlı yer değiştirme ve dönme altında güçlü yakınsama
- tork–açı ve kuvvet–yer değiştirme geçmişleri
- fiziksel ürün testiyle doğrulama

Temel hedef, ANSYS Mechanical ve Hexagon Marc gibi olgun ticari sistemlerin doğrusal olmayan çözüm sağlamlığına yaklaşırken elastomer problemlerinde daha şeffaf, daha odaklı ve daha açıklanabilir bir solver davranışı oluşturmaktır.

## 2. Temel ilke

Solver yalnızca Newton iterasyonu çalıştıran bir sınıf değildir.

```text
AnalysisModel
    ↓
AnalysisPrecheck
    ↓
ValidatedSolverInput
    ↓
NonlinearSolutionManager
    ↓
Increment / Iteration / Recovery / State
    ↓
ILinearSolver
    ↓
ConvergedState veya AçıklanmışFailure
```

Başarısızlık durumunda sistem yalnız `convergence failed` mesajı üretmemelidir. Mümkün olduğunca başarısızlık nedenini sınıflandırmalı, güvenli otomatik recovery denemeleri yapmalı ve bunları kaydetmelidir.

## 3. NonlinearSolutionManager

```text
NonlinearSolutionManager
├── NonlinearStrategy
│   ├── FullNewton
│   ├── ModifiedNewton
│   └── QuasiNewton
│       ├── BFGS
│       └── Broyden
│
├── ConvergenceManager
│   ├── ForceCriterion
│   ├── MomentCriterion
│   ├── DisplacementCriterion
│   ├── RotationCriterion
│   ├── PressureCriterion
│   └── EnergyDiagnostic
│
├── IncrementController
│   ├── Predictor
│   ├── AdaptiveGrowth
│   ├── StepLimiter
│   └── RetryPolicy
│
├── LineSearchManager
│   ├── Disabled
│   ├── Backtracking
│   ├── SecantLike
│   └── Automatic
│
├── DivergenceMonitor
│   ├── ResidualGrowth
│   ├── Stagnation
│   ├── Oscillation
│   ├── NaNInf
│   ├── NegativeJ
│   ├── SevereDistortion
│   ├── SingularMatrix
│   └── LinearSolverFailure
│
├── RecoveryManager
│   ├── Cutback
│   ├── RebuildTangent
│   ├── EnableOrAdjustLineSearch
│   ├── ChangeNonlinearStrategy
│   ├── RetryIncrement
│   └── AbortWithReason
│
├── StateManager
│   ├── Trial
│   ├── Commit
│   ├── Revert
│   └── Checkpoint
│
└── SolverDiagnostics
    ├── ConvergenceReason
    ├── DivergenceReason
    ├── IncrementHistory
    ├── IterationHistory
    ├── LinearSolveReports
    └── PerformanceMetrics
```

`TrustRegion` ve `ArcLength/Continuation` mimaride genişleme noktaları olarak saklanır; ilk V1.0 elastomer akışının zorunlu algoritmaları değildir.

## 4. Elastomere özgü yakınsama yaklaşımı

Yakınsama yalnız residual force ile belirlenmemelidir. Analiz tipine göre uygun kanallar birlikte izlenir.

### Temel kriterler

- residual force normu
- displacement correction normu
- residual moment/tork normu
- rotation/twist correction normu
- mixed `u-p` problemlerinde pressure correction/residual ölçütleri

### Tanısal kriterler

- enerji değişimi
- residual trendi
- iterasyonlar arası çözüm salınımı
- deformation gradient ve `J` gelişimi
- eleman distorsiyonu

Tanısal kriterlerin tamamının yakınsamayı bloklaması gerekmez; ancak solver recovery ve kullanıcı açıklamaları için saklanır.

## 5. Yaklaşık sıkıştırılamaz elastomerler

Mixed `u-p` üretim formulasyonu birinci sınıf solver gereksinimidir.

Solver aşağıdaki durumları ayırt edebilmelidir:

- displacement alanı yakınsıyor, pressure alanı yakınsamıyor
- pressure salınımı / checkerboard belirtisi
- volumetric locking şüphesi
- aşırı bulk response
- mixed tangent bloklarında sayısal problem

`IIncompressibilityStrategy` constitutive modelden ayrıdır ve solver tanıları formulasyon bilgisini kullanabilir.

```text
MaterialResponse
      ↓
IIncompressibilityStrategy
      ↓
ElementResidual / Tangent Blocks
      ↓
NonlinearSolutionManager
```

## 6. Negative J ve eleman distorsiyonu

Elastomer analizlerinde `J <= 0` veya ciddi geometri bozulması yalnız generic floating-point hata olarak ele alınmamalıdır.

Her increment/iterasyonda uygun seviyede şu tanılar üretilebilir:

```text
ElementKinematicsReport
├── minJ
├── maxJ
├── distortionMeasure
├── principalStretchRange
├── integrationPointId
└── elementId
```

Politika:

1. Kritik olmayan erken bozulma → warning/diagnostic.
2. Güvenli sınırı aşan distorsiyon → increment cutback.
3. `J <= 0` → trial state reddi, revert ve daha küçük increment ile retry.
4. Tekrarlanan negative-J → açık `DivergenceReason` ile çözümü durdurma.

## 7. Adaptive increment kontrolü

Increment büyüklüğü yalnız sabit growth/cutback katsayısıyla yönetilmez.

`IncrementController` şu sinyalleri kullanabilir:

- son yakınsayan increment'in iterasyon sayısı
- residual azalma hızı
- line search kullanımı
- cutback geçmişi
- `J` ve distorsiyon eğilimi
- pressure-field convergence
- nonlinear strategy davranışı

Örnek davranış:

```text
Kolay yakınsama
    ↓
increment büyüt

Orta zorluk
    ↓
increment koru

Yavaş yakınsama / line-search bağımlılığı
    ↓
increment küçült

Divergence / negative J
    ↓
revert → cutback → retry
```

## 8. RecoveryManager

Recovery sırası açık, deterministik ve kaydedilebilir olmalıdır.

Önerilen ilk politika:

1. Trial state'i reddet ve converged checkpoint'e dön.
2. Tangent'in güncelliğini kontrol et; gerekirse yeniden oluştur.
3. Increment'i azalt.
4. Automatic mod izin veriyorsa line search etkinleştir/ayarla.
5. Uygunsa Modified/Quasi-Newton'dan Full Newton'a dön.
6. Linear solver raporunu değerlendir.
7. Belirlenen retry limiti içinde yeniden çöz.
8. Hâlâ başarısızsa açık `DivergenceReason` ile durdur.

Recovery fiziksel olarak geçersiz bir state'i zorla kabul etmek için kullanılmaz.

## 9. State yönetimi

Her integrasyon noktasında:

```text
MaterialPointState
├── committed
├── trial
└── history
```

Her global increment seviyesinde:

```text
SolutionState
├── committed DOFs
├── trial DOFs
├── committed material states
├── trial material states
├── load/time parameter
└── solver metadata
```

Yakınsama:

```text
trial → commit
```

Başarısızlık/cutback:

```text
trial → discard
committed → restore
```

State commit/revert davranışı viskoelastisite, Mullins, hasar ve çevrimsel modeller eklenmeden önce güvenilir hale getirilmelidir.

## 10. Linear solver sözleşmesi

`ILinearSolver` yalnız başarı/başarısızlık döndürmez.

```text
LinearSolveReport
├── status
├── residualNorm
├── iterationCount
├── factorizationStatus
├── pivotStatus
├── symmetryStatus
├── conditioningEstimate       [destekleniyorsa]
├── memoryUsage                [destekleniyorsa]
└── backendDiagnostics
```

Nonlinear solver bu raporu recovery kararlarında kullanabilir.

Harici sparse solver, FEM formulasyonuna veya nonlinear algoritmaya sahip değildir.

## 11. Automatic ve Advanced

### Automatic — Elastomer odaklı

Kullanıcıdan algoritmik ayrıntı istemeden solver şu kararları yönetir:

- nonlinear strategy
- başlangıç increment'i
- increment büyütme/küçültme
- cutback
- yakınsama toleransları
- line search aktivasyonu
- tangent rebuild
- retry limiti
- linear solver backend seçimi

Automatic mod generic varsayılanlar değil, doğrulanmış elastomer problem sınıflarına göre oluşturulmuş profiller kullanmalıdır.

Örnek profiller:

```text
ElastomerAutomaticProfile
├── UniaxialLike
├── CompressionLike
├── Axisymmetric
├── AxisymmetricTorsion
└── NearlyIncompressibleMixedUP
```

### Advanced

Uzman kullanıcı şunları açıkça değiştirebilir:

- Full / Modified / Quasi-Newton
- BFGS / Broyden seçimi
- tangent update politikası
- maksimum iterasyon
- yakınsama toleransları
- başlangıç/min/maks increment
- growth/cutback limitleri
- line search
- predictor
- retry/recovery davranışı
- linear solver
- diagnostic verbosity

## 12. Açıklanabilir solver durumu

Solver UI'ye makine tarafından okunabilir status/reason kodları verir.

Örnek:

```text
Increment 18 — Retry 2/5

Durum:
Yakınsama başarısız; otomatik recovery uygulanıyor.

Ana neden:
Residual moment 6 iterasyondur azalmıyor.

Tanılar:
✓ Material state geçerli
✓ min(J) = 0.91
⚠ Tangent matrix ill-conditioned
⚠ Linear solver pivot uyarısı

Uygulanan işlem:
Increment 0.125° → 0.0625°
Tangent yeniden oluşturuldu
Line search etkinleştirildi
```

Bu bilgi hem Solver panelinde gösterilebilir hem regression/benchmark kayıtlarında saklanabilir.

## 13. Nonlinear strategy önceliği

V1.0 için uygulama sırası:

1. Full Newton — referans/doğrulama algoritması
2. Modified Newton — kontrollü performans alternatifi
3. Line Search — zor yakınsama desteği
4. Adaptive Increment + Cutback + Retry
5. BFGS / Broyden Quasi-Newton
6. Elastomer Automatic Profiles
7. Gelişmiş divergence/recovery politikaları

Daha sonra:

- trust-region
- arc-length / continuation
- gerektiğinde stabilization

## 14. Doğrulama matrisi

Solver gücü yalnız algoritma sayısıyla ölçülmez. Her özellik benchmark ile doğrulanmalıdır.

### A. Bünye seviyesi

- enerji
- stress
- consistent tangent
- finite-difference tangent diagnostic

### B. Tek eleman

- uniaxial-like deformation
- shear
- compression
- nearly incompressible response
- mixed `u-p`

### C. Mesh seviyesi

- patch testleri
- mesh convergence
- volumetric locking karşılaştırması
- distortion sensitivity

### D. Nonlinear robustness

- büyük deformation increment serileri
- zor başlangıç increment'i
- intentional cutback benchmark'ları
- negative-J recovery benchmark'ı
- line-search benchmark'ı
- quasi-Newton karşılaştırması
- rollback/commit determinism

### E. Ürün seviyesi

- eksenel simetrik elastomer ürün
- eksenel simetrik burulma
- tork–açı
- reaksiyon torku
- fiziksel test karşılaştırması

### F. Bağımsız çözücü karşılaştırması

Seçilmiş problemlerde:

- ANSYS Mechanical
- Hexagon Marc
- FEBio
- uygun olduğunda CalculiX / FEniCSx referansları

Amaç bit-for-bit eşitlik değil; tanımlı mühendislik toleransları içinde aynı fiziksel eğilim ve güvenilir yakınsama davranışıdır.

## 15. Gelecek elastomer fiziği için hazırlık

Solver state ve increment mimarisi şu modelleri sonradan ekleyebilecek şekilde tasarlanmalıdır:

- viskoelastisite
- strain-rate bağımlılığı
- Mullins etkisi
- histerezis
- hasar
- çevrimsel yükleme
- kauçuk yorulma/ömür metrikleri
- transient/harmonic dinamik

Bu nedenle V1.0 state yönetimi yalnız saf hiperelastik malzemenin bugünkü ihtiyacına göre dar tasarlanmamalıdır.

## 16. Ürün farklılaştırması

DynaElastomerSolver'ın solver açısından farklılaştırıcı hedefi:

> Genel amaçlı CAE sistemlerinin özellik sayısını kopyalamak yerine, yaklaşık sıkıştırılamaz büyük deformasyonlu elastomer problemlerini daha şeffaf, daha açıklanabilir ve daha otomatik biçimde çözmek.

Başarı ölçütü yalnız `converged` değildir. Solver şu sorulara da cevap verebilmelidir:

- Neden yakınsadı?
- Neden yakınsamıyor?
- Hangi recovery adımları uygulandı?
- Hangi eleman/integrasyon noktası problemi başlattı?
- Mixed pressure alanı sağlıklı mı?
- Material state ve `J` fiziksel olarak kabul edilebilir mi?
- Sonuç seçilmiş bağımsız çözücü ve fiziksel test benchmark'larıyla uyuşuyor mu?
