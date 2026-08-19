# Herrmann / Mixed u-P Öncelikli Geliştirme Planı

**Tarih:** 2026-08-19  
**Karar:** ADR-0008  
**Ana öncelik:** Herrmann formulation element ailesi + mixed u-P production solver

## Hedef

Nearly/fully incompressible elastomer problemlerinde bağımsız hydrostatic pressure unknown çözen, plane-strain'den axisymmetric-with-torsion problem sınıfına kontrollü biçimde büyüyen production element/solver hattı kurmak.

F-bar korunur ve her aşamada bağımsız formulation cross-check olarak kullanılır.

---

## Faz H0 — Interpolation ve block altyapısı

1. Q8 serendipity displacement shape functions.
2. İlk 3-DOF lineer pressure-space adayı.
3. Partition-of-unity / Kronecker / derivative-sum testleri.
4. Pressure interpolation exact-linear testleri.
5. Generic displacement/pressure DOF layout sözleşmesi.
6. Mevcut Q4/P0 checkerboard testi regression olarak korunur.

**Exit:** Q8 ve pressure interpolation matematiği dört compiler platformunda bit-level'e yakın tekrar üretilebilir ve tüm interpolation identity testlerini geçer.

---

## Faz H1 — Plane-Strain Q8/P1 Herrmann Element

### Fizik

- finite-strain `F`, `J`, `F^{-T}`
- deviatoric hyperelastic response
- independent pressure unknown
- nearly-incompressible volumetric compatibility
- fully-incompressible `J=1` constraint

### Element sistemi

```text
R = [R_u, R_p]
K = [K_uu K_up; K_pu K_pp]
```

### Doğrulama

- reference state
- homogeneous finite deformation
- pressure patch
- element FD tangent
- tangent symmetry/expected block symmetry
- null-space / rank diagnostics
- checkerboard / spurious pressure mode taraması
- distorted-element test

**Exit:** Q8/P1 pressure space stability testlerini geçmeden production etiketi almaz.

---

## Faz H2 — Global Mixed Assembly + Nonlinear Solver

1. 3 pressure DOF/element global-equation map.
2. `InternalMesh` mixed formulation adapteri.
3. Full Newton mixed residual/tangent.
4. trial/commit/revert.
5. adaptive increment + cutback/retry.
6. displacement ve pressure convergence normları ayrı izlenir.
7. volumetric constraint violation ayrı convergence ölçütüdür.
8. pressure Results kaynağı `independent unknown` olarak korunur.

### Linear solver

Küçük doğrulama için dense LAPACK kalır.

Production yönü:

```text
block sparse assembly
→ sparse direct baseline
→ Schur complement / field split
```

MFEM ve PETSc örnekleri algoritmik referanstır; kaynak kod kopyalanmaz.

**Exit:** fully incompressible saddle-point limiti çözülebilir olmalı.

---

## Faz H3 — Plane-Strain Benchmark Kapısı

Aynı problem üzerinde:

- Dyna Q4 displacement
- Dyna Q4 F-bar
- Dyna mevcut Q4/P0 mixed
- Dyna Q8/P1 Herrmann
- FEniCSx Q2 mixed/reference
- mümkün olduğunda ANSYS PLANE183 mixed u-P
- mümkün olduğunda Hexagon Marc Herrmann element

ölçülecek.

Metrikler:

- displacement error
- pressure quality
- volumetric constraint error
- Newton iterations
- linear iterations / factorization cost
- equation count
- wall time
- memory
- mesh convergence rate

**Exit:** Q8/P1 yalnız tek Cook değerine göre değil stability + convergence + robustness kanıtıyla production kabul edilir.

---

## Faz H4 — Axisymmetric Q8/P1 Herrmann

- `u_r, u_z`
- full 3D axisymmetric `F`
- hoop stretch
- `2*pi*R` reference-volume weighting
- pressure constraint
- consistent tangent
- reaction force
- axisymmetric patch/homogeneous tests
- independent reference

F-bar axisymmetric aday paralel cross-check olarak tutulur ancak ana geliştirme hattını bloke etmez.

---

## Faz H5 — Axisymmetric With Torsion Q8/P1 Herrmann

Ana element unknown düzeni:

```text
8 × (u_r, u_z, u_theta/phi) + 3 pressure = 27 unknown/element
```

Gereksinimler:

- circumferential kinematics
- finite rotation/torsion terms
- hoop + shear coupling
- full `J`
- mixed volumetric constraint
- analytic consistent tangent
- prescribed rotation
- reaction torque
- torque-angle curve
- torsional stiffness
- independent ANSYS/Marc reference benchmark
- fiziksel ürün torque-angle doğrulaması

**Exit:** ürün-level test ile solver sonucu birlikte doğrulanmadan final production kabulü yapılmaz.

---

## Faz H6 — Material Model Genişletmesi

Mixed formulation bünye yasasından bağımsız tutulur.

Öncelik:

1. Neo-Hookean
2. Mooney-Rivlin
3. Yeoh
4. Ogden N1
5. Ogden N2/N3
6. Arruda-Boyce / Gent ihtiyaç halinde

Her material model hem F-bar hem Herrmann/mixed yoluna aynı canonical Material Core response üzerinden bağlanır.

---

## Tasarım ilkeleri

- Marc/ANSYS davranışını benchmark et; kaynak kodunu kopyalama.
- Pressure interpolation ve integration seçimini varsayım olarak gizleme; testle kabul et.
- `Nd/Np`, rank ve spurious mode kontrollerini AnalysisPrecheck'e taşı.
- Fully incompressible ve nearly incompressible rejimleri açıkça ayır.
- Dense solverı production ölçek için kalıcı çözüm sayma.
- F-bar'ı silme; bağımsız fizik kontrolü olarak yaşat.
- Axisymmetric-with-torsion ana hedeflerden biridir ama projenin tek ana hedefi değildir.
