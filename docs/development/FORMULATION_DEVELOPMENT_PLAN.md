# DynaElastomerSolver — Formulation Geliştirme Planı

**Tarih:** 2026-08-19  
**Durum:** Aktif teknik plan  
**Temel ilke:** Önce çalışan ve doğrulanan fizik; sonra yalnız ölçülmüş ihtiyaca göre mimari genişleme.

## 1. Ürün hedefinin doğru çerçevesi

Axisymmetric with torsion / 2.5D, DynaElastomerSolver'ın önemli ana yeteneklerinden biridir; projenin tek ana hedefi değildir.

Birincil doğrulanmış problem sınıfı birlikte şu alanları kapsar:

- finite-strain / large-deformation elastomer mekaniği,
- nearly-incompressible hyperelasticity,
- plane strain,
- axisymmetric,
- axisymmetric with torsion / 2.5D,
- sağlam nonlinear solution management,
- reaction force / reaction torque,
- force-displacement ve torque-angle,
- hyperelastic material library ve calibration,
- bağımsız solver ve fiziksel ürün testi doğrulaması.

## 2. Formulation aileleri

Dyna tek bir incompressibility teknolojisine kilitlenmez.

### A — F-bar

V0.3 plane-strain production baseline:

```text
Q4 displacement + finite-strain F-bar
```

Durum:

- production default,
- energy-consistent residual,
- analytic consistent tangent,
- external FEniCSx doğrulaması,
- severe-distortion benchmarkı,
- pressure/result semantics doğrulaması.

Geliştirme yönü:

1. 8x8 -> 16x16 mesh-convergence ve dış-referans hata trendi,
2. adaptive increment + cutback/retry + committed/trial state,
3. InternalMesh üzerinden kanonik production çağrı yolu,
4. axisymmetric F-bar'ın yeniden türetilmesi,
5. axisymmetric-torsion F-bar'ın yeniden türetilmesi,
6. higher-order Q8/Q9 F-bar adayı.

### B — Stable mixed u-p

Mevcut Q4/P0 implementasyonu araştırma/doğrulama yoludur; checkerboard pressure null-mode riski nedeniyle future production mixed formulation için temel kabul edilmez.

Yeni mixed u-p formulation sıfırdan ayrı doğrulama programıyla geliştirilecektir.

İlk adaylar:

```text
Q2/Q1 Taylor-Hood benzeri iki-alan u-p
```

ve gerekirse:

```text
Q2 + discontinuous lower-order pressure/dilatation
üç-alan mixed Jacobian-pressure yaklaşımı
```

Seçim peşinen yapılmaz. Inf-sup/stability, pressure smoothness, locking, nonlinear convergence, DOF maliyeti ve axisymmetric-torsion genişletilebilirliği ölçülür.

## 3. Açık kaynak bilimsel referanslar

Açık kaynak projeler algoritmik ve mimari referans olarak kullanılabilir; Dyna'nın production kaynak kodu temiz bir yeniden implementasyon olarak yazılır.

### MFEM — Example 19

- incompressible nonlinear hyperelasticity,
- displacement + pressure block state,
- varsayılan Taylor-Hood yaklaşımı: ikinci mertebe displacement, birinci mertebe pressure,
- Newton adımında saddle-point block Jacobian,
- Schur-complement tabanlı block preconditioner.

Referans:

- https://mfem.org/examples/
- https://docs.mfem.org/4.8/ex19_8cpp_source.html

Lisans: BSD-3-Clause.

### deal.II — step-44

- quasi-incompressible finite-strain nonlinear solid mechanics,
- mixed Jacobian-pressure / three-field formulation,
- `Q2-DGPM1-DGPM1` higher-order örneği,
- mesh refinement + higher-order interpolation ile pressure/displacement yakınsama incelemesi.

Referans:

- https://dealii.org/current/doxygen/deal.II/step_44.html

Lisans ailesi: LGPL-2.1-or-later / dosya bazında belirtilen dual-license koşulları.

### PETSc

PETSc element formulation kaynağı değildir. Future sparse mixed global sistem için lineer/nonlinear cebir backend adayıdır.

Özellikle:

- SNES nonlinear solve,
- KSP,
- `PCFIELDSPLIT`,
- Schur-complement field split

mixed displacement-pressure block sisteminin büyük meshlerde ölçeklenmesi için incelenecektir.

Referans:

- https://petsc.org/main/manual/ksp/

Lisans: BSD-2-Clause.

## 4. IP / lisans uygulama kuralı

Dyna'nın proprietary source-available hak modelini korumak için varsayılan politika:

1. Matematiksel yöntemler, makaleler ve açık dokümantasyon incelenebilir.
2. MFEM/deal.II/PETSc mimari ve algoritma fikirleri benchmark/reference olarak kullanılabilir.
3. Üçüncü taraf kaynak kod blokları varsayılan olarak Dyna production koduna kopyalanmaz.
4. Zorunlu bir kod reuse kararı alınırsa önce ilgili lisans ve NOTICE yükümlülükleri `THIRD_PARTY_NOTICES.md` ve IP provenance kaydında değerlendirilir.
5. Dyna residual, tangent, assembly, field layout ve solver orchestration kodu kendi Fortran implementasyonumuz olarak yazılır.

## 5. Geliştirme dalgaları

### Dalga A — V0.3 F-bar kapatma

- [x] Q4 F-bar production kararı
- [x] 8x8 dış Q2 karşılaştırması
- [ ] 16x16 F-bar mesh-convergence gate
- [ ] adaptive F-bar force-control
- [ ] F-bar trial/commit/revert + cutback/retry
- [ ] F-bar InternalMesh production wrapper
- [ ] final architecture/status/release docs senkronu

32x32 Q4 normal correctness CI'ına dense backend döneminde zorunlu yapılmaz. Sparse backend geldikten sonra 32x32 ve daha büyük meshler tekrar açılır.

### Dalga B — Ortak axisymmetric kinematics

Formulation bağımsız çekirdek:

```text
ur, uz
hoop stretch
full 3D axisymmetric F
J
2*pi*R reference-volume weighting
```

F-bar ve future mixed u-p bu ortak kinematiği tüketmelidir.

### Dalga C — Axisymmetric with torsion / 2.5D

Formulation bağımsız alan:

```text
ur, uz, u_phi / phi
prescribed rotation
reaction torque
torque-angle
tangent/secant torsional stiffness
```

Önce F-bar yolu doğrulanır; mixed u-p aynı kinematics katmanına daha sonra bağlanır.

### Dalga D — Higher-order element altyapısı

- Q8/Q9 kinematics/interpolation,
- higher-order quadrature,
- Q8/Q9 F-bar,
- aynı DOF maliyetinde Q4-F-bar karşılaştırması.

### Dalga E — Stable mixed u-p

İlk production aday benchmarkı:

```text
Q2/Q1 Taylor-Hood benzeri displacement-pressure
```

Zorunlu doğrulama:

- material/element FD tangent,
- inf-sup / checkerboard/null-mode testi,
- manufactured uniform pressure,
- Cook mesh convergence,
- incompressibility sweep,
- severe distortion,
- pressure-field convergence,
- F-bar ile aynı DOF/maliyet benchmarkı,
- independent MFEM/FEniCSx/deal.II reference,
- axisymmetric geçiş,
- axisymmetric-torsion reaction-torque doğrulaması.

### Dalga F — Sparse block solver

Dense LAPACK doğrulama backend'i korunur.

Production büyük mixed sistemler için:

```text
ILinearSolver
  -> sparse direct aday
  -> PETSc KSP/PCFIELDSPLIT aday
  -> block/Schur diagnostics
```

backend benchmark sonucuna göre seçilir.

## 6. Production seçim ilkesi

F-bar ve mixed u-p birbirinin yerine zorla geçirilmez.

```text
Nearly incompressible + düşük/orta pressure-primary ihtiyaç
    -> F-bar güçlü production adayı

Çok yüksek incompressibility / independent pressure gerekli
    -> stable mixed u-p güçlü aday

Her iki yol da uygun
    -> ölçülmüş doğruluk + robustness + maliyet ile Automatic seçim
```

Production default ancak benchmark ve ADR ile değiştirilir.

## 7. Ortak doğrulama matrisi

Her yeni formulation aynı ölçüm sözleşmesinden geçer:

```text
Material point
-> element residual/tangent
-> finite-difference tangent
-> patch/homogeneous
-> mesh convergence
-> incompressibility/locking
-> pressure stability
-> severe distortion
-> nonlinear recovery
-> independent open-source reference
-> ANSYS/Marc karşılaştırması uygun olduğunda
-> fiziksel ürün force/torque testi
```

Amaç ANSYS veya başka bir paketi kopyalamak değil; seçilmiş elastomer problem sınıflarında doğruluk, robustness ve açıklanabilirlik açısından bağımsız olarak güçlü bir Dyna formulation ailesi oluşturmaktır.
