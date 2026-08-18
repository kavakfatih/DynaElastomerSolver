# ADR-0008 — Herrmann / Mixed u-P Ana Production Yolu

**Durum:** Kabul edildi  
**Tarih:** 2026-08-19  
**Kapsam:** Nearly/fully incompressible elastomer element ailesi ve solver önceliği

## Bağlam

V0.3 bake-off, mevcut Q4/P0 mixed u-P prototipinin checkerboard pressure null-mode riski taşıdığını; buna karşılık Q4 F-bar'ın Cook benchmarkında güçlü doğruluk ve mesh yakınsaması verdiğini gösterdi. Bu kanıtlar geçerlidir ve korunur.

Ancak DynaElastomerSolver'ın uzun vadeli hedefi yalnız plane-strain Cook benchmarkını en küçük denklem sayısıyla çözmek değildir. Ana hedeflerden biri; büyük deformasyonlu, nearly/fully incompressible elastomer problemlerini güvenilir biçimde çözmek ve özellikle axisymmetric ile axisymmetric-with-torsion problem sınıflarını production seviyesine taşımaktır.

Hexagon Marc ve ANSYS yeniden değerlendirildiğinde iki olgun yaklaşım ortak bir yön göstermektedir:

- Marc, incompressibility için Herrmann variational-principle tabanlı solid ve 2D element ailelerini kullanır; bu aile plane-strain, axisymmetric ve 3D incompressible problemlere yöneliktir.
- ANSYS current-technology solid elementlerinde displacement ile hydrostatic pressure'ı bağımsız bilinmeyenler olarak çözen mixed u-P formulation kullanır.
- ANSYS PLANE183; 8-node quadratic displacement davranışı, 3 bağımsız lineer pressure DOF ve axisymmetric-with-torsion seçeneğini aynı element teknolojisi içinde destekler.
- Fully incompressible hyperelasticity için ANSYS mixed u-P formulationı zorunlu çözüm yolu olarak tanımlar.

Bu ürün yönü, Dyna'nın ana formulation omurgasının bağımsız pressure unknown içeren mixed bir aile olması gerektiğini desteklemektedir.

## Karar

### 1. Ana production formulation ailesi Herrmann / mixed u-P olacaktır

DynaElastomerSolver'ın nearly/fully incompressible elastomer ana yolu:

```text
Finite-strain kinematics
+ independent hydrostatic pressure unknown
+ Herrmann/mixed variational constraint
+ consistent block residual/tangent
+ nonlinear solution management
```

olarak geliştirilir.

"Herrmann" adı burada Marc'taki tarihsel/variational formulation ailesine referans verir. Dyna implementasyonu bağımsız türetilir; Marc veya ANSYS kaynak kodu kopyalanmaz.

### 2. İlk yüksek öncelikli production adayı Q8/P1 Herrmann elementidir

Plane-strain başlangıç adayı:

```text
Q8 serendipity displacement
+ element-internal 3-DOF linear pressure space
+ mixed u-P finite-strain formulation
```

Element başına temel bilinmeyen sayısı:

```text
16 displacement DOF + 3 pressure DOF = 19
```

Bu seçim ANSYS PLANE183'ün açıkça dokümante edilen 8-node quadratic + 3 linear pressure-DOF desenini benchmark referansı olarak kullanır; Dyna'nın residual, tangent, integration ve pressure basis'i bağımsız türetilecek ve ayrı doğrulanacaktır.

### 3. Mevcut Q4/P0 mixed u-P korunur fakat production ilan edilmez

Mevcut prototip:

- mixed block assembly doğrulaması,
- pressure diagnostics,
- saddle-point solver testleri,
- düşük-mertebe benchmark,
- checkerboard regression

amaçlarıyla korunur.

V0.3'te ölçülen checkerboard coupling riski giderilmeden Q4/P0 production-safe kabul edilmez.

### 4. F-bar korunur; ana yol değil, güçlü alternatif ve doğrulama formulationıdır

F-bar çalışması boşa gitmemiştir. Özellikle Q4 F-bar'ın Cook benchmarkında mesh incelmesiyle dış Q2 referansa yaklaşması güçlü bir kanıttır.

F-bar bundan sonra:

- bağımsız formulation cross-check,
- nearly-incompressible alternatif çözüm,
- mixed u-P regresyon karşılaştırması,
- performans/doğruluk trade-off ölçümü

olarak korunur ve geliştirilir.

F-bar kodu silinmez; fakat yeni element/solver yatırımlarında birinci öncelik mixed u-P/Herrmann hattıdır.

### 5. Fully incompressible limit birinci sınıf gereksinimdir

Mixed formulation iki rejimi açıkça ayıracaktır:

```text
Nearly incompressible:
  finite bulk compliance / volumetric constraint regularization

Fully incompressible:
  J = 1 constraint
  pressure = true independent Lagrange multiplier
  K_pp -> 0 saddle-point limit
```

Bu nedenle production mixed solver, yalnız sonlu lambda ile regularize edilmiş küçük testleri değil gerçek saddle-point limiti de çözebilmelidir.

### 6. Pressure DOF'ları element-internal/global-equation bilinmeyenleri olarak modellenir

Pressure DOF'ları kullanıcı mesh node'larına zorunlu olarak eklenmez. Elementin kendi pressure bilinmeyenleri global denklem sistemine dahil edilir ve displacement-pressure block yapısı korunur:

```text
[ K_uu  K_up ] [du] = -[R_u]
[ K_pu  K_pp ] [dp]    [R_p]
```

Fully incompressible limitte `K_pp` sıfır/semidefinite saddle-point davranışına yaklaşabilir.

### 7. Sparse/block linear algebra production gereksinimidir

Dense LAPACK küçük doğrulama problemlerinde kalır. Mixed production hattı için:

1. backend-independent block matrix/DOF sözleşmesi,
2. sparse direct production baseline,
3. Schur-complement / field-split iterative seçenek

geliştirilecektir.

MFEM Example 19 ve PETSc `PCFIELDSPLIT` yalnız açık kaynak mimari/algoritma referanslarıdır. Kod kopyalanmaz; lisans/provenance sınırı korunur.

### 8. Axisymmetric ve axisymmetric-with-torsion mixed u-P ana genişleme hattıdır

Sıra:

```text
Plane strain Q8/P1 Herrmann
    ↓
Axisymmetric Q8/P1 Herrmann
    ↓
Axisymmetric-with-torsion Q8/P1 Herrmann
```

Axisymmetric with torsion adayında:

```text
8 node × (u_r, u_z, u_theta/phi) = 24 displacement DOF
+ 3 internal pressure DOF
= 27 element unknown
```

Kinematik, hoop stretch, circumferential shear, `J`, pressure constraint, consistent tangent ve `2*pi*R` integration bağımsız türetilecektir.

### 9. Element acceptance yalnız doğrulukla değil stability ile verilir

Her Herrmann/mixed aday şu kapılardan geçer:

```text
shape/interpolation identities
→ material/element finite-difference tangent
→ pressure patch test
→ inf-sup / rank / null-mode diagnostics
→ checkerboard test
→ incompressibility sweep
→ mesh convergence
→ severe distortion
→ independent external reference
→ nonlinear cutback/rollback
```

Axisymmetric-torsion production kabulü ayrıca reaction torque ve fiziksel torque-angle doğrulaması gerektirir.

## ADR-0007 ile ilişki

ADR-0007'nin V0.3 plane-strain bake-off ölçümleri geçerliliğini korur; tarihsel bilimsel karar kaydı olarak silinmez.

Ancak şu ifade artık supersede edilmiştir:

```text
"F-bar Q4 = genel production ana yolu"
```

Yeni mimari öncelik:

```text
PRIMARY: Herrmann / stable mixed u-P element family
SECONDARY / CROSS-CHECK: F-bar element family
BASELINE / REGRESSION: displacement-only family
EXPERIMENTAL: current Q4/P0 mixed prototype until stability issue is resolved
```

## Referans yönü

- Hexagon Marc: Herrmann formulation; incompressible 2D/solid element guidance.
- ANSYS: Mixed u-P Formulations; PLANE183 8-node quadratic element; 3 linear pressure DOF; axisymmetric with torsion.
- MFEM Example 19: incompressible nonlinear hyperelasticity block `u-p` system and Schur-complement preconditioning pattern.
- PETSc `PCFIELDSPLIT`: saddle-point / Schur-complement field-split infrastructure.

## Son karar

DynaElastomerSolver geliştirme önceliği bundan sonra Herrmann/mixed u-P production ailesidir. İlk somut element hattı Q8/P1 plane strain ile başlar; aynı interpolation ve block-solver prensipleri axisymmetric ve axisymmetric-with-torsion'a kontrollü biçimde genişletilir. F-bar doğrulama ve alternatif formulation olarak korunur.
