# DynaElastomerSolver

DynaElastomerSolver; kauçuk/elastomer malzemeler ve elastomer tabanlı ürünler için doğrusal olmayan sonlu eleman analizi, malzeme karakterizasyonu ve doğrulama odaklı bilimsel bir mühendislik platformudur.

**Ana ürün yönü:** nonlineer elastomer solver uzmanlaşması  
**Geliştirme disiplini:** implementation-first validation — ADR-0006  
**Aktif geliştirme sürümü:** `V0.3.0 — Nearly-Incompressible Plane-Strain`  
**Production formulation:** `F-bar Q4` — ADR-0007  
**Aktif geliştirme branch'i:** `develop/v0.3`  
**Kararlı sürüm:** `V0.2.0` — `release/v0.2`  
**UI hedefi:** Qt 6 / Qt Quick-QML, değiştirilebilir frontend sınırı arkasında

## Proje odağı

Proje genel amaçlı CAE paketlerinin özellik sayısını kopyalamayı hedeflemez. Ana hedef, aşağıdaki dar problem sınıfında yüksek doğruluk, sağlam nonlinear çözüm ve bağımsız doğrulamadır:

- quasi-static büyük deformasyon
- hiperelastik elastomer
- yaklaşık sıkıştırılamaz davranış
- bonded metal–elastomer sistemleri
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- tork–açı ve kuvvet–yer değiştirme cevabı

ANSYS Mechanical ve Hexagon Marc genel kapsam parity hedefi değildir; seçilmiş elastomer problemlerinde doğruluk ve nonlinear robustness benchmark'ıdır.

## Geliştirme ilkesi

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.

İlk doğrulanmış dikey zincir:

```text
Neo-Hookean Material Core
→ material-point validation
→ energy / stress / consistent tangent
→ finite-difference tangent check
→ Q4 plane strain
→ global assembly
→ Full Newton
→ adaptive increment / rollback / cutback
→ InternalMesh + raw integration-point results
→ independent external reference
→ nearly-incompressible formulation bake-off
```

## Nearly-incompressible formulation kararı

V0.3 içinde aynı problem ve ölçüm sözleşmesi altında üç formulation karşılaştırıldı:

```text
Displacement-only Q4
vs
Mixed Q4/P0 u-p
vs
F-bar Q4
```

ADR-0007 kararı:

```text
V0.3 plane-strain nearly-incompressible production default = F-bar Q4
Displacement-only Q4 = baseline / regression
Mixed Q4/P0 = experimental / verification; production değil
```

Kararın temel kanıtları:

- displacement-only Q4 nearly-incompressible limite giderken belirgin volumetric locking gösterdi,
- mixed Q4/P0 güçlü displacement doğruluğuna rağmen checkerboard pressure null-mode riski gösterdi,
- F-bar Q4 dış FEniCSx Q2 referansına göre en düşük 8x8 tip-displacement hatasını verdi,
- F-bar residualı energy-consistent, tangent analitik ve FD ile doğrulandı,
- dedicated severe-distortion benchmarkı dört compiler/platform hattında geçti.

### Dış referansa göre 8x8 sonuç

Referans: FEniCSx/DOLFINx Q2 32x32 tip displacement = `0.0201973648361`.

| Formulation | Tip displacement | Relative error | Equations | Newton/Linear |
|---|---:|---:|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% | 144 | 10 / 10 |
| Mixed Q4/P0 | 0.01915555105 | 5.16% | 208 | 10 / 10 |
| F-bar Q4 | 0.01940548609 | **3.92%** | 144 | 15 / 15 |

## V0.3 doğrulama durumu

Güncel correctness paketi: **38 CTest**.

- Windows 2022 / Intel ifx 2025.2 — 38/38 ✅
- Windows / gfortran 14 — 38/38 ✅
- macOS ARM64 / gfortran 14 — 38/38 ✅
- Linux / gfortran 14 — 38/38 ✅
- FEniCSx/DOLFINx Q2 external reference — ✅
- Linux F-bar performance benchmark — ✅

Platform numerical reproducibility:

```text
Cook maksimum bağıl fark   ≈ 3.65e-14
Sweep maksimum bağıl fark  ≈ 1.39e-13
```

FEniCSx Q2 refinement:

```text
Q2 8x8   = 0.0195456636855
Q2 16x16 = 0.0200264312978
Q2 32x32 = 0.0201973648361
16 -> 32 = 0.846316%
```

Configured convergence-aday eşiği `%1` geçildi.

## Mixed Q4/P0 stability sonucu

CTest:

`benchmark.v0.3.mixed_up.checkerboard_null_mode`

```text
Checkerboard normalized coupling = 6.223551e-17
Probe normalized coupling        = 1.581139e-01
```

Bu nedenle mevcut Q4/P0 mixed formulation silinmez; pressure diagnostics ve araştırma/doğrulama yolu olarak korunur. Bağımsız pressure DOF gereken gelecekteki production mixed formulation, stabilizasyonlu veya inf-sup kararlı interpolation ile ayrı benchmark ve ADR gerektirir.

## F-bar robustness

Dedicated CTest:

`benchmark.v0.3.fbar.severe_distortion_affine`

Ciddi distorsiyonlu 2x2 Q4 mesh üzerinde bağımsız kapalı-form Neo-Hookean `P*N0` traction ile tam izokorik affine finite-strain alanı geri kazanıldı.

```text
Reference weight ratio      = 1.697222e-01
Exact affine free residual  = 1.518785e-13
Recovered displacement err  = 1.267320e-12
Final J / J_bar             = 1.0 / 1.0
```

## Results pressure contract

V0.3 Results katmanı gerçek kinematik state ile constitutive state'i ayırır:

```text
F, J                           = gerçek Gauss kinematiği
constitutive_F, constitutive_J = malzeme modelinin kullandığı state
```

Pressure scalar sözleşmesi:

```text
p_logJ = lambda * ln(constitutive_J)
```

Bu değer `-tr(sigma)/3` hidrostatik Cauchy basıncı değildir; `ln(J)` ile eşlenik volumetric constitutive diagnostic'tir.

Kaynak ayrımı:

```text
DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE
DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN
```

F-bar için `constitutive_F=F_bar`, `constitutive_J=J_bar`; solver integration Results yalnız başarıyla yakınsamış final state için üretilir.

## Performans baseline'ı

`benchmark_v03_fbar_performance`, normal CTest correctness paketinden ayrıdır. Wall-clock süreleri yalnız raporlanır; sabit süre pass/fail eşiği yoktur.

Linux/gfortran14 Debug baseline:

| Cook mesh | Serbest denklem | Wall-clock | Bilinen dense matris alt sınırı |
|---:|---:|---:|---:|
| 4x4 | 40 | 0.090 s | 0.043 MiB |
| 8x8 | 144 | 0.375 s | 0.517 MiB |
| 12x12 | 312 | 1.129 s | 2.357 MiB |
| 16x16 | 544 | 3.242 s | 7.064 MiB |

Peak RSS ≈ `11.48 MiB`.

Bu ölçüm dense backend'in ölçeklenme baseline'ıdır; daha büyük modeller için sparse backend ihtiyacı ayrıca değerlendirilecektir.

## Fortran kütüphane politikası

Dyna'nın bilimsel fiziği ve ürün davranışı kendi çekirdeğinde kalır. Açık kaynak Fortran kütüphaneleri genel amaçlı sayısal altyapı, veri yapıları, optimizasyon ve I/O gibi alanlarda adapter/API üzerinden kullanılır.

### Aktif dependency — Fortran stdlib

**Repo:** `https://github.com/kavakfatih/stdlib`  
**Sürüm:** `0.8.1`  
**Pinlenen commit:** `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

```text
des_dense_linear
→ stdlib_linalg::solve
→ LAPACK *GESV backend
```

Aday ve referans kütüphaneler:

- `docs/references/FORTRAN_LIBRARIES.md`

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

## Axisymmetric geçiş kuralı

ADR-0007 yalnız **plane-strain** production baseline kararıdır. F-bar plane-strain implementasyonu axisymmetric probleme doğrudan kopyalanmaz.

```text
axisymmetric kinematics
→ hoop stretch
→ full J / J_bar
→ 2*pi*R reference-volume weighting
→ energy-consistent residual
→ analytic tangent + FD
→ homogeneous/patch benchmark
→ mesh refinement
→ independent external reference
→ product-level force/torque validation
```

Axisymmetric doğrulanmadan axisymmetric torsion / 2.5D production implementasyonuna geçilmez.

## UI yaklaşımı

İlk production frontend:

```text
Qt 6 + Qt Quick/QML + Dyna Design System
```

Qt yalnız frontend/platform katmanıdır. Scientific core, application model, presentation contracts ve result semantics Qt'den bağımsız kalır.

## Release durumu

V0.3 ana teknik exit criteria tamamlanmıştır. PR #1 **draft** kalır; final entegrasyon/release kontrolü tamamlanmadan `main`e merge edilmez.

Release hazırlığı:

- `docs/release/V0.3_RELEASE_CHECKLIST.md`
- `docs/release/V0.3_RELEASE_NOTES.md`

## Sürekli proje kayıtları

- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_RULES.md`
- `docs/ROADMAP.md`
- `docs/sohbetler/ChatGPT Sohbet 1.md`

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.

## Temel dokümantasyon

- `docs/PROJECT_CONTEXT.md`
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_RULES.md`
- `docs/ROADMAP.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/architecture/SOLVER_ARCHITECTURE.md`
- `docs/architecture/UI_ARCHITECTURE.md`
- `docs/architecture/RESULTS_ARCHITECTURE.md`
- `docs/decisions/ADR-0006-IMPLEMENTATION-FIRST-VALIDATION-AND-V1-SCOPE.md`
- `docs/decisions/ADR-0007-NEARLY-INCOMPRESSIBLE-PRODUCTION-FORMULATION.md`
- `docs/references/FORTRAN_LIBRARIES.md`
