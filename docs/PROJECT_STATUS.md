# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-19  
**Sürekli kayıt branch'i:** `main`  
**Aktif geliştirme:** `develop/v0.3`

## Sürüm durumu

### Kararlı — V0.2.0

- Branch: `release/v0.2`
- CMake: `0.2.0`
- Durum: **tamamlandı**

V0.2; Linux/gfortran14, macOS ARM64/gfortran14, Windows/gfortran14 ve Windows/Intel ifx üzerinde doğrulandı ve bağımsız FEniCSx FEM referansından geçti.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake: `0.3.0`
- Draft PR: **#1 — `V0.3 — Herrmann / Mixed u-P Production Foundation`**
- PR kullanıcı açıkça istemeden merge edilmeyecek.
- Formulation ailesi: **ADR-0008 — Herrmann / stable mixed u-P**
- Aktif plane-strain element adayı: **ADR-0009 — Q9/P1 Herrmann**

```text
PRIMARY       = Q9/P1 Herrmann / stable mixed u-P
SECONDARY     = Q4 F-bar cross-check
BASELINE      = displacement-only
REGRESSION    = Q8/P1 stability research + Q4/P0 checkerboard research
```

---

## 1. Neden Q8/P1 yerine Q9/P1?

İlk high-order mixed aday Q8 serendipity + 3 element-internal P1 pressure DOF idi. Dedicated mesh-refinement inf-sup proxy diagnostic'i Q8/P1 pressure stability'sinin mesh incelmesiyle zayıfladığını gösterdi. Bu davranış gizlenmedi; regression testi olarak korundu.

Q9/P1 hattında ise:

- full pressure-coupling row rank,
- checkerboard coupling gate,
- mesh-refinement inf-sup proxy plateau,
- distorted pressure stability

ayrı testlerle korunmaktadır.

Plane-strain Q9/P1 yerel sistem:

```text
9 node × 2 displacement DOF = 18 u
3 element-internal P1 DOF   =  3 p
----------------------------------
21 local unknown
```

---

## 2. Q9/P1 mixed u-P çekirdeği

Mevcut implementation:

- isochoric Neo-Hookean material split,
- independent hydrostatic pressure unknown,
- `p > 0` compression convention,
- hydrostatic Cauchy contribution `-p I`,
- Herrmann potential,
- nearly-incompressible pressure compliance,
- fully-incompressible `J=1`, `K_pp=0` saddle-point limit,
- `R_u / R_p`,
- `K_uu / K_up / K_pu / K_pp`,
- analytic consistent tangent,
- Q9 geometry/interpolation,
- global mixed assembly,
- Q9 `InternalMesh`,
- Full Newton,
- adaptive increment,
- cutback/retry,
- displacement + pressure rollback,
- independent-pressure Results semantics.

Mixed pressure constraint sözleşmesi:

```text
Pi_p = -p (J-1) - 1/2 c_p p^2
R_p  = -(J-1) - c_p p

c_p > 0 : nearly incompressible
c_p = 0 : fully incompressible / Lagrange multiplier
```

Pointwise volumetric diagnostic ile weak-form pressure residual aynı şey değildir; ikisi ayrı raporlanır.

---

## 3. Son doğrulanmış CI baseline'ı

2026-08-19 tarihinde yeni pressure-patch / mesh-refinement / mixed-FEniCSx eklerinden **önceki** son doğrulanmış Q9/P1 head'de:

```text
CTest = 63/63 PASS
```

Compiler matrix:

- Linux / gfortran 14 ✅
- macOS ARM64 / gfortran 14 ✅
- Windows / gfortran 14 ✅
- Windows / Intel ifx 2025.2 ✅

Aynı head'de Legal/Public IP Guard, Full Git History Secret Audit ve mevcut FEniCSx reference hattı da başarılıydı.

**Önemli:** Bu dosyanın güncellendiği anda yeni 65-test paketi ve yeni mixed FEniCSx workflow'u henüz resmi CI sonucu ile doğrulanmış sayılmamaktadır. PASS sonucu alınmadan test sayısı veya external mixed doğruluk kapısı tamamlandı olarak ilan edilmeyecektir.

---

## 4. Q9/P1 production acceptance — mevcut kanıt

Mevcut dedicated production benchmark:

- `K/mu = 10, 100, 1000, fully incompressible` sweep,
- `2x2` ile `3x3` quadrature karşılaştırması,
- fully-incompressible saddle-point solve,
- severe-distortion manufactured exact-state recovery,
- ayrı displacement residual,
- ayrı pressure residual,
- ayrı volumetric constraint diagnostic.

Önceki CI kanıtında `K/mu=1000` ile fully-incompressible Cook displacement farkı yaklaşık `0.094%` mertebesindedir. `2x2` ile `3x3` Q9/P1 sonucu ise yaklaşık `5.27%` farklıdır; bu nedenle mevcut primary integration `3x3 Gauss` olarak tutulmaktadır.

Bu sayılar benchmark contractı sabitlenmeden ticari solver parity sonucu olarak yorumlanmaz.

---

## 5. Yeni kalite kapıları — bu geliştirme turu

### ADR-0009

Yeni karar kaydı yüksek doğruluk hedeflerini açık release gate'e dönüştürdü:

```text
analytic / FD tangent normalized error <= 1e-7
nominal tangent hedefi                 <= 1e-8
pressure patch displacement recovery   <= 1e-7
pressure patch pressure recovery       <= 1e-7
pressure weak residual                 <= 1e-9
K/mu=1000 -> incompressible gap        <= 0.5%
external mixed displacement error      <= 1.0%
external mixed pressure L2-type error  <= 2.0%
```

Pressure error yalnız aynı sign/measure convention altında karşılaştırılır.

### Dedicated pressure patch

Yeni test:

`fem.q9.plane_strain.herrmann.pressure_patch`

Fully-incompressible `J=1` manufactured state üzerinde P1 pressure space'in dört durumu çözülür:

1. sabit pressure,
2. `xi` lineer mode,
3. `eta` lineer mode,
4. birleşik P1 field.

Amaç yalnız sabit basıncı değil, üç bağımsız pressure DOF'un tamamını solver seviyesinde geri kazanmaktır.

### Dedicated mesh refinement

Yeni test:

`benchmark.v0.3.herrmann.mesh_refinement`

Cook mesh zinciri:

```text
1x1 Q9 -> 2x2 Q9 -> 4x4 Q9
```

Sonuç noktası artık açıkça **sağ kenarın geometrik orta noktasıdır**. Bu seçim external FEniCSx benchmark contractı ile aynıdır. Test weak residualları, volumetric diagnostic'i ve displacement self-convergence trendini raporlar.

---

## 6. Bağımsız FEniCSx mixed u-P referansı

Tarihsel V0.3 FEniCSx scripti quadratic displacement-only Q2 referanstır. Q9/P1 pressure doğrulaması için yeterli değildir ve tarihsel benchmark olarak korunur.

Bu geliştirme turunda yeni bağımsız referans eklendi:

```text
FEniCSx / DOLFINx 0.11
continuous Q2 displacement
+ discontinuous DPC degree-1 pressure
= 3 complete-linear pressure DOF / element
```

External referans Dyna Fortran element/assembly/tangent/Newton kodunu kullanmaz ve Dyna ile aynı mixed continuum potentialı bağımsız UFL türevleriyle kurar:

```text
W_iso = mu/2 [J^(-2/3) I1 - 3]
Pi_p  = -p(J-1) - 1/2 c_p p^2
```

Mesh planı:

```text
2x2 -> 4x4 -> 8x8 -> 16x16
```

Raporlanan metrikler:

- right-edge midpoint displacement,
- pressure mean/std/RMS,
- volumetric constraint L2-RMS,
- average J,
- nonlinear iteration counts,
- mesh-convergence gap.

Yeni workflow resmi CI PASS almadan external reference gate kapalı sayılır.

---

## 7. Marc / ANSYS seviyesi hedefinin anlamı

Hedef, tek bir Cook displacement sayısını eşleştirmek değildir. Desteklenen problem sınıfında aşağıdaki kanıt zinciri gereklidir:

```text
consistent tangent
+ pressure mode recovery
+ pressure stability
+ incompressibility
+ mesh convergence
+ severe distortion
+ nonlinear cutback/rollback
+ independent mixed reference
+ commercial solver benchmark
```

ANSYS PLANE183 ve Hexagon Marc Herrmann davranış/benchmark referanslarıdır. Dyna'nın ticari solverlarla eşdeğer veya daha iyi olduğu, aynı geometry/material/load/pressure convention altında ölçülmüş karşılaştırma olmadan söylenmez.

---

## 8. Linear algebra ölçeklenebilirlik yönü

Dense LAPACK küçük doğrulama ve regression problemlerinde kalır. Production mixed solver büyüme yolu:

```text
block DOF API
→ sparse matrix assembly
→ sparse direct baseline
→ Schur complement / field split
→ scaling + conditioning diagnostics
```

Bu madde V0.3 plane-strain bilimsel doğruluğunu bloke etmez; Marc/ANSYS ölçeğinde büyük modeller için zorunludur.

---

## 9. V0.3 kapanmadan yapılacaklar

Öncelik sırası:

1. Yeni 65-test compiler matrix sonucunu doğrula; failure varsa tolerans gevşetmeden kök nedeni düzelt.
2. Yeni FEniCSx mixed Q2/DPC1 workflow'unu doğrula.
3. Dyna Q9/P1 Cook benchmark output noktasını external referansla tamamen aynı `right-edge midpoint` contractına sabitle.
4. Dyna ve FEniCSx mixed sonuçlarını aynı acceptance JSON/raporunda otomatik karşılaştır.
5. Pressure field error metriğini aynı pressure convention ile hesapla.
6. Fully-incompressible external mixed benchmark ekle.
7. README / PR açıklaması / release notlarını son CI kanıtıyla senkronla.
8. Issue #2'deki GitHub/security/manual IP hardening maddelerini kapat.
9. Kullanıcı açık onayı olmadan PR merge/tag/release yapma.

---

## 10. V0.4 / V0.5 sonraki ana teknik dalga

V0.3 plane-strain mixed u-P kanıt zinciri kapandıktan sonra:

```text
V0.4 = Axisymmetric Q9/P1 Herrmann
V0.5 = Axisymmetric-with-torsion / 2.5D Q9/P1 Herrmann
```

Axisymmetric-with-torsion yerel unknown düzeni:

```text
9 × (u_r,u_z,u_theta/phi) = 27 u
+ 3 pressure DOF          =  3 p
--------------------------------
30 local unknown
```

Reaction torque, torque-angle, torsional stiffness ve fiziksel ürün doğrulaması V0.5 production kapısıdır.

---

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli sohbet/proje kaydı
- `release/v0.2`: kararlı V0.2.0
- `develop/v0.3`: aktif mixed u-P geliştirme
- PR #1: **open / draft / merge edilmedi**
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe değiştirilmez
