# ChatGPT Sohbet 1

**Proje:** DynaElastomerSolver  
**Sürekli kayıt branch'i:** `main`  
**Başlangıç:** 2026-08-17  
**Kural:** Her anlamlı proje adımından sonra teknik karar, gerçekleştirilen iş, doğrulama, güncel sürüm ve sıradaki plan bu dosyada güncellenir.

---

## 1. Ürün yönü

DynaElastomerSolver genel amaçlı CAE olmaya çalışmayacak. Ana ürün ilkesi:

> Genel amaçlı CAE olmak yerine, nonlineer elastomer analizlerinde olağanüstü güçlü ve güvenilir olmak.

Bilimsel sıra:

```text
finite strain
→ hyperelasticity
→ near incompressibility
→ robust nonlinear solve
→ plane strain
→ axisymmetric
→ axisymmetric torsion / 2.5D
```

ADR-0006 ile **implementation-first validation** kuralı kabul edildi: önce çalışan ve doğrulanmış fizik, sonra yalnız gerçek ihtiyaç ortaya çıktığında mimari genişleme.

---

## 2. Branch ve sürüm kuralı

Kullanıcının sürümler arasında geçebilme isteği üzerine branch modeli oluşturuldu:

```text
main
├── release/v0.2   ← kararlı V0.2.0
└── develop/v0.3   ← aktif V0.3.0
```

Kurallar:

- `main`: doğrulanmış ana hat + sürekli proje kayıtları.
- `release/vX.Y`: geri dönülebilir kararlı kilometre taşı.
- `develop/vX.Y`: aktif geliştirme hattı.
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez.
- V0.3 için Draft PR #1 açık tutulur; exit criteria tamamlanmadan ready/merge yapılmaz.

---

## 3. V0.1 — Material Core

Tamamlandı:

- Modern Fortran 2018 + CMake.
- finite-strain yardımcıları.
- compressible Neo-Hookean enerji.
- First Piola-Kirchhoff `P`.
- Cauchy stress.
- analitik consistent `dP/dF`.
- material-point ve merkezi FD tangent kontrolü.

Önemli sonuç:

```text
material tangent normalized FD error ≈ 1.26e-9
```

---

## 4. V0.2 — Nonlinear FEM dikey dilimi

Tamamlananlar:

- Q4 plane strain / 2×2 Gauss.
- Total-Lagrangian residual/tangent.
- global assembly.
- Full Newton.
- adaptive increment / cutback / rollback.
- `solution_state_t` trial/commit/revert.
- convergence history ve failure root-cause.
- `InternalMesh`.
- raw integration-point `F/J/P/Cauchy/W`.
- backend-independent lineer solver API.
- `kavakfatih/stdlib` → `stdlib_linalg::solve` → LAPACK.
- nonlinear patch, mesh refinement ve severe-distortion benchmarkları.

Önemli V0.2 sonuçları:

```text
Q4 element tangent FD error          ≈ 1.16e-9
2-element reaction relative error    ≈ 1e-15
solver final free residual           ≈ 5.4e-15
nonlinear patch center error         ≈ 3.9e-17
adaptive cutback residual            ≈ 3.87e-15
```

Bağımsız FEniCSx/DOLFINx homojen extension doğrulaması:

```text
lambda_y farkı      ≈ 2.00e-15
reaction farkı      ≈ 6.66e-16
J farkı             ≈ 4.88e-15
energy farkı        ≈ 5.72e-15
```

V0.2.0 dört compiler hattında 20 CTest ile doğrulandı:

- Ubuntu 24.04 / gfortran 14
- macOS ARM64 / gfortran 14
- Windows / gfortran 14
- Windows 2022 / Intel ifx 2025.2

**V0.2.0 tamamlandı ve `release/v0.2` branch'i ile sabitlendi.**

---

## 5. Açık kaynak Fortran kütüphaneleri

Aktif zorunlu dependency:

- `https://github.com/kavakfatih/stdlib`
- stdlib `0.8.1`
- pin: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

Planlanan / araştırılan:

- Reference LAPACK
- MUMPS
- stdlib sparse / GMRES
- MINPACK
- PRIMA
- PCHIP
- HDF5
- JSON-Fortran
- FrontISTR

V0.7 material calibration hedef zinciri:

```text
Experimental Data
→ PCHIP
→ Physical Objective / Constraints
→ PRIMA
→ MINPACK Levenberg-Marquardt
→ Material Validation
```

---

## 6. V0.3 — Nearly-Incompressible Formulation Bake-off

Aktif branch: `develop/v0.3`  
Draft PR: **#1 — V0.3 — Nearly-Incompressible Formulation Bake-off**

Karşılaştırılan adaylar:

1. displacement-only full-integration Q4
2. mixed Q4/P0 `u-p`
3. F-bar Q4

Production formulation henüz seçilmedi.

Ortak altyapı:

- Q4 reference-edge traction.
- InternalMesh edge-load assembly.
- fixed-increment force-control Full Newton.
- homogeneous analytic traction benchmark.
- normalize Cook-benzeri 2×2 / 4×4 / 8×8 benchmark.
- final-state `min J` ile historical Newton `min J` ayrımı.
- Newton iteration / linear solve / equation-count ölçümleri.
- CTest log → provenance içeren `V0.3_COOK_BAKEOFF_RESULTS.json` parserı.

---

## 7. Mixed Q4/P0 `u-p`

Kullanılan mixed potential:

```text
Psi(F,p) = mu/2(I1-3)
         - mu ln(J)
         + p ln(J)
         - p^2/(2 lambda)
```

Stationarity:

```text
p = lambda ln(J)
```

Bu nedenle displacement ve mixed formulation aynı Neo-Hookean material ailesini temsil eder.

Global DOF:

```text
[u1x,u1y,...,unx,uny | p1,...,p_nelem]
```

Tamamlandı:

- 9×9 element residual/tangent.
- `Kuu/Kup/Kpu/Kpp` block assembly.
- global mixed assembly.
- mixed Full Newton force-control.
- homogeneous analytic traction.
- mixed Cook 2×2 / 4×4 / 8×8.

Doğrulama:

```text
mixed 9x9 tangent FD error ≈ 1.74e-9
```

---

## 8. Pressure diagnostics

Yeni metrikler:

- min/max/mean/std/RMS.
- edge-neighbor graph.
- neighbor jump RMS.
- maximum neighbor jump.
- pressure-RMS normalized jump.
- mean-free `neighbor_jump_to_std`.
- `graph_roughness = (jump_rms/std)^2`.

Bu metrikler tek başına checkerboard/instability kararı değildir; mesh refinement ve dış pressure referansı ile yorumlanacaktır.

### Manufactured homojen zero-roughness benchmark

Yeni test:

`tests/test_v03_mixed_pressure_uniformity.f90`

Düzenli 2×2 Q4 mesh üzerinde homojen affine alan:

```text
F2 = [1.10  0.08]
     [0.03  0.94]

J = 1.0316
mu = 2.3
lambda = 19
p = lambda ln(J)
```

Yerel GNU Fortran 14.2 sonucu:

```text
Exact J                    = 1.031600
Exact pressure             = 0.5911089
maximum pressure residual  = 1.11e-16
pressure graph roughness   = 0.0
```

Pressure std ve bütün neighbor-jump/roughness ölçüleri de sıfır çıktı. Böylece pressure stationarity + diagnostics zinciri için exact sağlıklı referans elde edildi.

CTest tanımı **33** oldu.

---

## 9. F-bar Q4

Kinematik:

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Residual doğrudan energy-consistent:

```text
E(u) = sum_g W(F_bar_g(u)) w_g
```

### Analitik consistent tangent

İlk verification prototipindeki merkezi FD tangent kaldırıldı. Yeni analitik zincir:

```text
H_q = dF_bar/dq
    = alpha [B_q + beta_q F]

beta_q = 1/3 [J_bar,q/J_bar - J,q/J]

K_qr = sum_g w_g [H_q : A_bar : H_r + P_bar : H_qr]
```

`H_qr`, `alpha`, `J` ve `J_bar`ın ikinci türevlerini içerir; Gauss-point volumetrik coupling tangentte korunur.

Bağımsız doğrulamalar:

```text
Python reference:
cross-FD error ≈ 8.73e-10
symmetry       ≈ 1.90e-16

GNU Fortran 14.2:
cross-FD error ≈ 1.20e-9
symmetry       ≈ 2.45e-16
```

F-bar artık sayısal tangent prototipi değildir. Windows/macOS compiler doğrulaması hâlâ gereklidir.

---

## 10. Hedef platform önceliği

Kullanıcı ürünün Windows ve Mac için geliştirildiğini vurguladı. Öncelik:

```text
Windows x64 / Intel ifx       PRIMARY
Windows x64 / gfortran        PRIMARY portability
macOS Apple Silicon / gfortran PRIMARY
Linux / gfortran              SECONDARY scientific CI
Linux / FEniCSx               external reference only
```

Linux ürün dağıtım önceliği değildir.

---

## 11. GitHub Actions engeli

Draft PR conflict'i çözüldü ve PR tekrar `mergeable=true` hale getirildi.

Buna rağmen GitHub-hosted Actions job'ları:

- Windows/gfortran
- Windows/ifx
- macOS ARM64/gfortran
- Linux/gfortran
- FEniCSx Q2

runner step'leri başlamadan failure oldu. Tek Linux rerun'ında da aynı davranış görüldü.

Bu nedenle mevcut kanıt build/CMake/CTest/FEM kaynak hatasına işaret etmiyor. Problem GitHub-hosted Actions account/repository usage veya runner provisioning tarafında çözülmelidir.

---

## 12. Bağımsız V0.3 FEniCSx Q2 referansı

Hazır:

`tools/reference/fenicsx_v03_cook_q2_reference.py`

- aynı Cook geometri/material/load.
- Q2 quadrilateral.
- mesh 2/4/8/16.
- UFL automatic residual/Jacobian.
- PETSc SNES + LU/MUMPS.
- tip displacement.
- continuum `p=lambda ln(J)` mean/std/RMS.
- average `J`, energy, SNES iterations.

Workflow hazır fakat Actions pre-step engeli nedeniyle gerçek artifact henüz alınmadı.

---

## Güncel sıradaki adım

1. GitHub-hosted Actions pre-step engelini çöz.
2. Önce Windows/ifx + Windows/gfortran + macOS ARM64/gfortran matrix'ini kapat.
3. F-bar analitik tangent ve mixed pressure uniformity benchmarkını bu üç birincil platformda doğrula.
4. Displacement / mixed / F-bar Cook gerçek sonuçlarını ortak JSON'a çıkar.
5. FEniCSx Q2 2/4/8/16 artifact sonucunu al.
6. Dyna tip displacement trendini Q2 16×16 referansla karşılaştır.
7. Mixed pressure mean/std/RMS + graph roughness trendini continuum referansla kıyasla.
8. Üç formulation için ortak convergence/locking/robustness/maliyet tablosunu oluştur.
9. Production adayı bağımsız solver ile son kez doğrula.
10. ADR ile production formulation kararını sabitle.

`Sistem-ve-Mimari` branch'ine bu geliştirmelerde dokunulmadı.
