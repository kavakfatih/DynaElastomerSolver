# ADR-0006 — Implementasyon Öncelikli Doğrulama ve V1.0 Kapsam Disiplini

**Durum:** Kabul edildi  
**Tarih:** 2026-08-17

## Bağlam

DynaElastomerSolver için Material Core, solver, UI, Results ve doğrulama mimarileri ayrıntılı biçimde tanımlandı. Bu mimari yön tutarlı olmakla birlikte gerçek bir sonlu eleman residual'ı, consistent tangent, Newton iterasyonu, volumetric locking ve büyük deformasyon problemi üzerinde henüz uygulanarak sınanmadı.

En büyük kısa vadeli risk mimari eksikliği değil, mimari ile çalışan fizik arasındaki mesafedir.

## Karar

### 1. Mimari genişleme dondurulur

İlk çalışan nonlinear FEM dikey dilimi doğrulanana kadar yeni soyutlama, framework, plugin, optimizer veya solver-strategy ailesi yalnız mevcut implementasyonu doğrudan engelleyen somut bir ihtiyaç varsa eklenir.

Mimari dokümanlar hedef yönü tarif etmeye devam eder; ancak kodun kanıtlamadığı özellikler V1.0 zorunlu implementasyonu kabul edilmez.

### 2. İlk çalışan FEM dikey dilimi öne alınır

İlk bilimsel hedef:

```text
Neo-Hookean
   ↓
Material-point doğrulaması
   ↓
Analitik stress / consistent tangent
   ↓
Finite-difference tangent checker
   ↓
Q4 plane-strain eleman
   ↓
Eleman residual + tangent
   ↓
Global assembly
   ↓
Full Newton
   ↓
Dense/LAPACK linear solve
   ↓
Analitik + bağımsız solver benchmark
```

Bu zincir çalışmadan geniş hiperelastik model kütüphanesi, kapsamlı calibration, gelişmiş Quasi-Newton çeşitleri veya tam UI geliştirmesi öncelik değildir.

### 3. Sıkıştırılamazlık formulasyonu kanıtla seçilir

Production nearly-incompressible eleman ailesi dokümantasyon üzerinden peşinen sabitlenmez.

İlk formulation bake-off en az şu adayları karşılaştırır:

- displacement-only Q4 — doğrulama/baseline
- mixed displacement-pressure (`u-p`) adayı
- F-bar veya eşdeğer locking azaltıcı aday

Karşılaştırma ölçütleri:

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear convergence
- distortion sensitivity
- DOF ve assembly maliyeti
- axisymmetric uyumluluk
- axisymmetric torsion'a genişletilebilirlik

Production formulation ayrı bir ADR ile benchmark sonuçlarından sonra seçilir.

### 4. V1.0 problem sınıfı dar ve kanıtlanabilir tutulur

V1.0'ın birincil doğrulanmış problem sınıfı:

- quasi-static
- finite strain / large deformation
- hyperelastic elastomer
- bonded metal–elastomer arayüzleri
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- prescribed displacement / prescribed rotation
- force / reaction force
- torque / reaction torque
- nearly incompressible davranış

V1.0 başarısı özellik sayısıyla değil, önceden tanımlanmış benchmark ve fiziksel testlerde belirlenmiş toleranslar içinde doğruluk, mesh yakınsaması ve tekrar üretilebilir nonlinear çözüm davranışıyla ölçülür.

### 5. Contact V1.0 dışında kalır

V1.0 için:

- bonded/tied arayüzler desteklenir
- separation, frictional sliding, general contact ve self-contact zorunlu değildir
- debonding/cohesive failure kapsam dışıdır

Analiz geometrisi büyük deformasyonda self-contact gerektirecek hale geliyorsa model doğrulanmış V1.0 kapsamının dışında kabul edilir ve kullanıcıya açık uyarı verilmesi hedeflenir.

### 6. Binary User Material Plugin V1.0 zorunluluğu değildir

İlk aşamada yeni malzeme modelleri aynı kaynak ağacında ve aynı build zincirinde native extension olarak eklenebilir.

Gelecekte bağımsız `.dll` / `.dylib` / `.so` material plugin desteklenirse sınır native Fortran module/type ABI'si üzerinden kurulmaz. Harici plugin sözleşmesi `ISO_C_BINDING` / `BIND(C)` tabanlı, sürümlenmiş C ABI üzerinden tasarlanır.

### 7. Solver algoritmaları ihtiyaç kanıtlandıkça açılır

İlk referans nonlinear çözüm yolu:

```text
Full Newton
+ doğru consistent tangent
+ increment kontrolü
+ cutback / retry
+ state revert / commit
```

Modified Newton, line search, BFGS/Broyden, advanced recovery, trust-region ve arc-length; benchmark veya gerçek ürün problemleri somut gereksinim gösterdiğinde implementasyon sırasına alınır.

Hedef mimaride genişleme noktaları korunabilir; fakat kodlanmış özellik sayısı başarı ölçütü değildir.

### 8. UI ikinci dalgadır

Qt cross-platform frontend kararı korunur. Ancak tam UI geliştirmesi solver çekirdeğinin bilimsel doğrulamasının önüne geçmez.

Erken aşamada yalnız gerektiğinde minimal teknik shell / test harness oluşturulur. Tam Material Lab, Results Navigator ve mühendislik workflow UI'si çalışan solver dikey dilimleri sonrasında genişletilir.

### 9. Terminoloji

V1.0 için ana ifade **nonlinear structural response / nonlineer yapısal cevap** olacaktır.

Cauchy stress, principal stretch, strain-energy density, pressure, `J`, force ve torque sonuçları doğrudan kopma/ömür tahmini olarak sunulmaz.

Mullins, tearing energy, damage, fatigue ve life prediction gelecekte ayrı doğrulama programı gerektirir.

## Sonuç

DynaElastomerSolver'ın geliştirme ilkesi bundan sonra şöyledir:

> Önce çalışan ve doğrulanan en küçük fizik zinciri; sonra yalnız kanıtlanmış ihtiyaca göre mimari genişleme.

ANSYS ve Marc genel özellik kapsamı açısından kopyalanmayacaktır. Bunlar seçilmiş elastomer problem sınıflarında doğruluk, nonlinear robustness ve mühendislik davranışı için benchmark olacaktır.
