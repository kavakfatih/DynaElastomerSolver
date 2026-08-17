# DynaElastomerSolver

DynaElastomerSolver; kauçuk/elastomer malzemeler ve elastomer tabanlı ürünler için doğrusal olmayan sonlu eleman analizi, malzeme karakterizasyonu ve doğrulama odaklı bilimsel bir mühendislik platformudur.

**Ana ürün yönü:** nonlineer elastomer solver uzmanlaşması  
**Geliştirme disiplini:** implementasyon öncelikli doğrulama — ADR-0006  
**Aktif geliştirme sürümü:** `V0.2-dev — Nonlinear FEM Robustness`  
**Ana ve sürekli güncellenen branch:** `main`  
**UI hedefi:** Qt 6 / Qt Quick-QML, değiştirilebilir frontend sınırı arkasında

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
Adaptive Increment
   ↓
Rollback / Cutback / Retry
   ↓
Mesh + Patch Benchmark
```

Bu zincir doğrulanmadan geniş material library, kapsamlı calibration, binary plugin sistemi, tam UI veya çoklu Quasi-Newton implementasyonları öncelik değildir.

## Fortran kütüphane politikası

Dyna'nın bilimsel fiziği ve ürün davranışı kendi çekirdeğinde kalır; açık kaynak Fortran kütüphaneleri genel amaçlı sayısal altyapı, veri yapıları, optimizasyon ve I/O gibi alanlarda adapter/API üzerinden kullanılır.

### Aktif dependency — Fortran stdlib

**Repo:** `https://github.com/kavakfatih/stdlib`  
**Sürüm:** `0.8.1`  
**Pinlenen commit:** `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

CMake build zinciri bu fork'u pinlenmiş commit üzerinden kullanır. `stdlib` kaynak üretimi için `fypp` gerektirir.

İlk gerçek kullanım:

```text
des_dense_linear
      ↓
stdlib_linalg::solve
      ↓
LAPACK *GESV backend
```

Önceki elle yazılmış Gaussian-elimination doğrulama çözücüsü kaldırılmıştır. Küçük/dense solver yolu artık stdlib lineer cebir arayüzünü kullanır.

Kütüphane ve kaynak-kod referans envanteri:

- `docs/references/FORTRAN_LIBRARIES.md`

Bu envanterde stdlib yanında MUMPS, Reference LAPACK/BLAS, modernized MINPACK, HDF5, JSON-Fortran, NLESolver-Fortran, FrontISTR, test-drive ve fftpack gibi adayların repo bağlantıları, kullanım amacı ve dependency durumu takip edilir.

## Nearly-incompressible formulation yaklaşımı

Production elastomer eleman formulasyonu peşinen sabitlenmez. V0.3 benchmark dalgasında en az şu adaylar karşılaştırılacaktır:

```text
Displacement-only Q4
        vs
Mixed u-p adayı
        vs
F-bar / eşdeğer locking azaltıcı aday
```

Karar; locking, pressure stability, mesh convergence, nonlinear convergence, distortion sensitivity, maliyet ve axisymmetric/torsion genişletilebilirliği üzerinden verilecek ve ayrı ADR ile sabitlenecektir.

## Solver yaklaşımı

Çalışan minimal solver yolu şu anda:

```text
Full Newton
+ consistent tangent
+ increment stepping
+ adaptive displacement control
+ trial / commit / revert
+ rollback
+ cutback / retry
+ convergence history
+ minimum J tracking
+ açık failure status
```

Adaptive yol, başarısız increment'te trial state'i reddeder, son committed state'e döner ve daha küçük increment ile yeniden dener.

`newton_report_t` artık:

- increment/attempt sayıları
- Newton iteration sayıları
- residual norm
- minimum `J`
- cutback sayısı
- son failure status
- commit/revert sayaçları
- convergence history

bilgilerini taşır.

`convergence_history_t` her Newton değerlendirmesi için attempt, iteration, load factor, increment size, residual, minimum `J`, status ve accepted bilgisini saklar.

`des_status_message()` sayısal çekirdek status kodlarını okunabilir mühendislik açıklamalarına dönüştürür.

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

Tam UI geliştirmesi solver doğrulamasının önüne geçirilmez.

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

## Mevcut implementasyon durumu

V0.1 Material Core'un temel bilimsel zinciri çalışıyor ve V0.2 nonlinear plane-strain FEM dikey dilimi gerçek kodla doğrulanıyor.

Şu anda çalışan temel parçalar:

- Modern Fortran scientific core
- precision ve açık status/error kodları
- 3×3 tensör ve finite-strain/invariant yardımcıları
- `material_kinematics_t` / `material_response_t`
- sıkıştırılabilir Neo-Hookean enerji, First Piola-Kirchhoff, Cauchy ve analitik `dP/dF` tangent
- parametre, singular `F` ve non-positive `J` tanıları
- Q4 shape function ve 2×2 Gauss integrasyonu
- Total-Lagrangian Q4 plane-strain residual ve consistent element tangent
- çok elemanlı Q4 global assembly
- stdlib/LAPACK tabanlı küçük dense lineer çözüm adaptörü
- fixed-step ve adaptive displacement-control Full Newton solver
- reusable `solution_state_t`
- convergence history
- rollback / cutback / retry
- cutback exhaustion tanısı
- okunabilir status message katmanı

Mevcut CTest paketi **16 test** içerir.

Öne çıkan, stdlib entegrasyonundan önce ve mevcut solver fiziğini doğrulayan sonuçlar:

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- iki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- solver API final free residual normu: yaklaşık `5.4e-15`
- distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh-refinement reaksiyonu: `1.605586`
- adaptive failure benchmark: `2 commit / 1 revert`
- cutback exhaustion sonrası committed state korunuyor

State/history ve status-message değişiklikleri GNU Fortran **14.2.0** ile yerel olarak doğrulandı.

**Doğrulama notu:** stdlib dependency ve `stdlib_linalg::solve` entegrasyonu kaynak/API/build-konfigürasyonu seviyesinde uygulanmıştır. Bu çalışma ortamında `fypp` ve dış ağ erişimi olmadığı için stdlib tabanlı yeni build henüz tam CTest/compiler matrisi üzerinde doğrulanmış sayılmaz.

## Sıradaki V0.2 işleri

1. stdlib tabanlı build'i GNU Fortran ile tam CTest üzerinde doğrulamak.
2. Ek nonlinear distortion ve robustness benchmark'ları.
3. Minimal `Node / Element / InternalMesh` veri modelini gerçek mesh akışına taşımak.
4. Ham integration-point result saklama yolunu eklemek.
5. Bağımsız solver/reference karşılaştırmasını genişletmek.
6. macOS Apple Silicon + gfortran doğrulaması.
7. Windows x64 + Intel ifx doğrulaması.
8. Windows x64 + gfortran doğrulaması.
9. Tüm compiler matrisi üzerinde CTest çalıştırmak.

Bunlar tamamlandıktan sonra V0.3 nearly-incompressible formulation bake-off'a geçilecektir.

## Sürekli proje kayıtları

`main` üzerinde sürekli güncel tutulur:

- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_RULES.md`
- `docs/ROADMAP.md`
- `docs/sohbetler/ChatGPT Sohbet 1.md`

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.

## Dokümantasyon

- `docs/PROJECT_CONTEXT.md`
- `docs/PROJECT_STATUS.md`
- `docs/PROJECT_RULES.md`
- `docs/ROADMAP.md`
- `docs/sohbetler/ChatGPT Sohbet 1.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/architecture/SOLVER_ARCHITECTURE.md`
- `docs/architecture/UI_ARCHITECTURE.md`
- `docs/architecture/RESULTS_ARCHITECTURE.md`
- `docs/benchmarks/ANSYS_MARC_COMPARISON.md`
- `docs/references/FORTRAN_LIBRARIES.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`
- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/decisions/ADR-0002-ANSYS-MARC-BENCHMARK-REVISION.md`
- `docs/decisions/ADR-0003-OWNED-UI-ARCHITECTURE.md`
- `docs/decisions/ADR-0004-QT-FRONTEND-BOUNDARY.md`
- `docs/decisions/ADR-0005-NONLINEAR-ELASTOMER-SOLVER-SPECIALIZATION.md`
- `docs/decisions/ADR-0006-IMPLEMENTATION-FIRST-VALIDATION-AND-V1-SCOPE.md`
