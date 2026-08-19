# ADR-0009 — Q9/P1 Herrmann Production Adayı ve Kalite Kapıları

**Durum:** Kabul edildi  
**Tarih:** 2026-08-19  
**Kapsam:** Plane-strain mixed `u-p` production adayı, Q8/P1 stability sonucu ve yüksek doğruluk doğrulama kapıları

## Bağlam

ADR-0008, DynaElastomerSolver için ana nearly/fully incompressible formulation ailesini Herrmann / mixed `u-p` olarak belirledi ve ilk araştırma adayını Q8 serendipity displacement + 3 element-internal linear pressure DOF olarak tanımladı.

Q8/P1 üzerinde daha sonra yapılan mesh-refinement inf-sup proxy tanısı, pressure space'in mesh inceldikçe zayıflayan bir stability eğilimi taşıdığını gösterdi. Bu davranış regression kanıtı olarak korunur; Q8/P1 production-safe ilan edilmez.

Aynı 3-DOF pressure space, Q9 biquadratic displacement interpolation ile tekrar değerlendirildi. Q9/P1 hattında:

- pressure coupling rank/checkerboard testi,
- mesh-size inf-sup proxy plateau testi,
- distorted pressure-stability testi,
- analytic element tangent + finite-difference cross-check,
- global mixed assembly,
- nearly-incompressible ve fully-incompressible saddle-point çözüm,
- Full Newton + adaptive increment + cutback/rollback,
- displacement ve pressure residual raporları,
- independent-pressure Results sözleşmesi,
- 2x2 / 3x3 quadrature karşılaştırması,
- severe-distortion manufactured-state doğrulaması,
- Cook incompressibility production acceptance benchmarkı

oluşturulmuştur.

## Karar

### 1. Plane-strain ana production adayı Q9/P1 Herrmann'dır

Yeni ana aday:

```text
Q9 biquadratic displacement
+ 3 element-internal linear pressure DOF [1, xi, eta]
+ Herrmann / mixed u-p finite-strain formulation
```

Yerel bilinmeyen düzeni:

```text
9 node x 2 displacement DOF = 18 u DOF
+ 3 pressure DOF            =  3 p DOF
---------------------------------------
21 local unknown
```

Q8/P1 araştırma ve stability-regression amacıyla korunur; yeni production geliştirmeleri Q9/P1 üzerinde yapılır.

### 2. Axisymmetric ve axisymmetric-with-torsion genişlemesi Q9 tabanlı olacaktır

Plane-strain kabul zinciri kapandıktan sonra ana genişleme sırası:

```text
Q9/P1 plane strain
    ↓
Q9/P1 axisymmetric
    ↓
Q9/P1 axisymmetric with torsion / 2.5D
```

Axisymmetric-with-torsion adayında temel yerel bilinmeyen düzeni:

```text
9 node x (u_r, u_z, u_theta/phi) = 27 displacement DOF
+ 3 element-internal pressure DOF =  3 pressure DOF
----------------------------------------------------
30 local unknown
```

### 3. 3x3 Gauss mevcut plane-strain Q9/P1 primary quadrature'dır

Q9/P1 Cook acceptance testinde 2x2 ve 3x3 çözümleri aynı nonlinear problem üzerinde karşılaştırılmıştır. Her iki entegrasyon da yakınsasa da çözüm farkı yaklaşık %5 düzeyindedir. Bu nedenle 2x2 reduced integration, yalnız ticari solver davranışını taklit etmek amacıyla production default yapılmaz.

Mevcut karar:

```text
PRIMARY     = Q9/P1 + 3x3 Gauss
DIAGNOSTIC  = Q9/P1 + 2x2 Gauss
```

Bu karar external mixed reference ve mesh-convergence kanıtı geldikçe yeniden değerlendirilebilir.

## Yüksek kalite hedefi

DynaElastomerSolver için hedef yalnız bir benchmarkı yakınsatmak değildir. Hedef, desteklenen problem sınıflarında ticari nonlinear elastomer solverlarında beklenen mühendislik davranışına yaklaşan; bağımsız olarak doğrulanmış, ölçülebilir ve regression-test ile korunan bir mixed `u-p` çekirdeği oluşturmaktır.

Hexagon Marc ve ANSYS bu hedef için davranış ve benchmark referansıdır. Dyna'nın onlarla eşdeğer veya daha iyi olduğu, yalnız açık ve tekrarlanabilir benchmark kanıtı ile söylenebilir. Bu ADR ticari solver parity'sini **ilan etmez**; parity iddiası için gerekli kabul kapılarını tanımlar.

## Zorunlu numerical quality gates

### G1 — Interpolation ve geometry

- partition of unity ve derivative identity: machine precision düzeyi,
- Jacobian orientation / minimum determinant precheck,
- regular ve distorted geometry regression.

### G2 — Consistent tangent

- analytic tangent ile central finite-difference tangent normalize farkı hedefi: `<= 1e-7`,
- nominal doğrulama hedefi: `<= 1e-8`,
- block symmetry ayrıca raporlanır.

Tolerans gevşetmek, formulation veya implementasyon hatasını saklamak için kullanılamaz.

### G3 — Pressure patch ve pressure-mode recovery

Dedicated Q9/P1 test paketi en az:

1. fully-incompressible `J=1` manufactured state,
2. sabit pressure mode,
3. `xi` lineer pressure mode,
4. `eta` lineer pressure mode,
5. birleşik P1 pressure field

üzerinde displacement ve üç pressure katsayısını geri kazanmalıdır.

Manufactured-state recovery hedefi:

```text
max displacement error <= 1e-7
max pressure error     <= 1e-7
pressure residual inf  <= 1e-9
```

### G4 — Pressure stability

- pressure-displacement coupling full row-rank,
- checkerboard / alternating pressure mode displacement alanından kopmamalı,
- mesh-refinement inf-sup proxy kabul alt sınırının altına çökmemeli,
- distorted mesh aynı stability sınıfını korumalı.

Mevcut Q9/P1 inf-sup regression kapıları minimum olarak korunur:

```text
min(beta_h)       >= 0.55
beta_h(n=4)/beta_h(n=2) >= 0.80
tail relative change    <= 0.12
```

Bu sayılar evrensel matematiksel inf-sup kanıtı değil; mevcut discrete diagnostic regression sınırlarıdır.

### G5 — Incompressibility

Aynı problemde compressibility sweep:

```text
K/mu = 10, 100, 1000, fully incompressible
```

çalıştırılır. `K/mu=1000` çözümünün fully-incompressible limite tip displacement farkı release hedefi olarak `<= 0.5%` tutulur.

Pointwise `J-1` değeri ile weak-form pressure residual birbirine karıştırılmaz. Mixed formulation acceptance için:

- displacement residual,
- pressure weak residual,
- pointwise volumetric diagnostic

ayrı raporlanır.

### G6 — Mesh convergence

Q9/P1 için dedicated Cook mesh-refinement zinciri en az `1x1 -> 2x2 -> 4x4` Q9 mesh üzerinde çalıştırılır.

Kabul için:

- tüm seviyeler nonlinear olarak yakınsamış olmalı,
- `J > 0` korunmalı,
- son iki seviye displacement değişimi raporlanmalı,
- pressure norm/field metriği ve weak-form constraint metriği raporlanmalı,
- external mixed reference geldikten sonra son seviye bağıl displacement error release gate'e dönüştürülmelidir.

### G7 — Severe distortion

Manufactured exact-state severe-distortion testinde:

```text
max displacement recovery error <= 1e-7
max pressure recovery error     <= 1e-7
residual metrics                <= 1e-7
```

korunur. Geometri yeterince zorlayıcı değilse test başarılı sayılmaz; distortion metriği ayrıca gate'tir.

### G8 — Nonlinear robustness

- Full Newton,
- adaptive increment,
- cutback/retry,
- displacement + pressure state rollback,
- deterministic failure reason,
- minimum `J` takibi,
- ayrı `R_u` ve `R_p` convergence metrics

production acceptance zincirinin parçasıdır.

### G9 — Independent mixed reference

Mevcut FEniCSx Q2 displacement-only Cook referansı tarihsel olarak korunur; ancak Q9/P1 Herrmann parity kanıtı değildir.

V0.3 bilimsel kapanış için bağımsız **mixed displacement-pressure** external reference oluşturulacaktır. En az:

- aynı geometry,
- aynı shear modulus,
- aynı compressibility / incompressibility convention,
- aynı traction,
- mesh-refinement,
- displacement,
- pressure field ölçüleri,
- volumetric constraint ölçüleri

karşılaştırılır.

Dyna'nın external mixed reference'a karşı hedef release doğruluğu:

```text
displacement relative error <= 1.0%
pressure field L2-type error <= 2.0%  (aynı pressure convention altında)
```

Pressure conventionları farklıysa doğrudan scalar karşılaştırma yapılmaz; önce işaret, measure ve Lagrange-multiplier tanımı eşleştirilir.

### G10 — Commercial solver benchmark

ANSYS ve/veya Hexagon Marc erişimi sağlandığında aynı benchmark deck'i ile bağımsız karşılaştırma yapılır. En az:

- plane strain nearly incompressible,
- fully incompressible,
- severe distortion,
- mesh refinement,
- pressure quality,
- nonlinear cutback/robustness

karşılaştırılır.

Ticari solver ile tek bir displacement sayısının uyuşması parity kanıtı değildir. Kabul raporu formulation, element order, integration, material convention, boundary conditions ve convergence controls farklarını açıkça kaydeder.

## Production linear algebra yönü

Dense LAPACK küçük doğrulama problemlerinde doğru ve yararlı baseline olarak korunur; fakat ticari solver ölçeğine yaklaşmak için mixed sistem üretim yolu:

```text
block DOF contract
→ sparse assembly
→ sparse direct baseline
→ Schur-complement / field-split option
→ scaling / conditioning diagnostics
```

şeklinde ilerler.

Bu çalışma V0.3 plane-strain bilimsel doğrulamasını bloke etmez; büyük model production ölçeklenebilirliği için sonraki zorunlu altyapıdır.

## ADR-0008 ile ilişki

ADR-0008'in ana kararı geçerlidir:

```text
PRIMARY = Herrmann / stable mixed u-P family
SECONDARY = F-bar
```

ADR-0009 yalnız ilk yüksek mertebeli production adayını günceller:

```text
Q8/P1 candidate -> stability diagnostic / research
Q9/P1 candidate -> active plane-strain production candidate
```

## Release kuralı

Q9/P1 şu anda güçlü bir production adayıdır; ancak external mixed reference ve dedicated pressure/mesh-convergence kapıları tamamlanmadan "Marc/ANSYS seviyesinde doğrulandı" veya genel production parity ifadesi kullanılmaz.

PR #1 kullanıcı açıkça istemeden merge edilmez; `release/v0.3` veya `v0.3.0` yayınlanmaz.
