# ChatGPT Sohbet 1

**Proje:** DynaElastomerSolver  
**Sürekli kayıt branch'i:** `main`  
**Başlangıç:** 2026-08-17  
**Kural:** Her anlamlı proje adımından sonra teknik karar, gerçekleştirilen iş, doğrulama, güncel sürüm ve sıradaki plan bu dosyada güncellenir.

---

## 1. Ürün yönü

DynaElastomerSolver genel amaçlı CAE olmaya çalışmayacak.

Ana ürün ilkesi:

> Genel amaçlı CAE yerine nonlineer elastomer analizlerinde olağanüstü güçlü, güvenilir ve açıklanabilir olmak.

Öncelik:

```text
finite strain
→ hyperelasticity
→ nearly-incompressibility
→ robust Newton
→ plane strain
→ axisymmetric
→ axisymmetric torsion / 2.5D
```

ADR-0006: **implementation-first validation**. Önce çalışan ve ölçülen fizik, sonra yalnız ihtiyaç kadar mimari genişleme.

---

## 2. Sürüm ve branch kuralı

Kullanıcının talebiyle sürümler branch üzerinden geri dönülebilir hale getirildi.

```text
main             → doğrulanmış ana hat + sürekli kayıtlar
release/v0.2     → kararlı V0.2.0
develop/v0.3     → aktif V0.3.0
Sistem-ve-Mimari → kullanıcı ayrıca istemedikçe dokunulmaz
```

Her tamamlanan sürüm için `release/vX.Y`, yeni geliştirme için `develop/vX.Y+1` kullanılacak.

Draft PR #1:

`V0.3 — Nearly-Incompressible Formulation Bake-off`

V0.3 exit criteria tamamlanmadan ready/merge yapılmayacak.

---

## 3. V0.1 — Material Core

Tamamlandı:

- Modern Fortran 2018
- CMake
- Neo-Hookean strain energy
- First Piola-Kirchhoff `P`
- Cauchy stress
- analitik consistent material tangent
- invalid parameter / singular `F` / non-positive `J` diagnostics

Material tangent merkezi FD normalize hata:

```text
≈ 1.26e-9
```

---

## 4. V0.2 — Nonlinear FEM dikey dilimi

V0.2.0 tamamlandı ve `release/v0.2` branch'ine sabitlendi.

Tamamlanan ana zincir:

```text
Neo-Hookean
→ Q4 plane strain / 2×2 Gauss
→ Total-Lagrangian residual/tangent
→ global assembly
→ Full Newton
→ adaptive increment / cutback / rollback
→ InternalMesh
→ raw integration-point results
→ backend-independent lineer solver
→ stdlib/LAPACK dense backend
```

Eklenen solver yetenekleri:

- trial / commit / revert state
- convergence history
- cutback/retry
- minimum `J`
- failure root-cause preservation
- lineer solver report
- backend/equation-count/linear residual diagnostics

Bilinen V0.2 doğrulamaları:

```text
Material tangent FD               ≈ 1.26e-9
Q4 element tangent FD             ≈ 1.16e-9
2-element reaction relative error ≈ 1e-15
solver final free residual         ≈ 5.4e-15
nonlinear patch center error       ≈ 3.9e-17
```

Bağımsız FEniCSx/DOLFINx doğrulaması:

```text
Dyna lambda_y    = 0.8314690882666784
FEniCSx lambda_y = 0.8314690882666764
abs fark         ≈ 2.00e-15

Dyna reaction    = 1.7423183105139586
FEniCSx reaction = 1.7423183105139580
abs fark         ≈ 6.66e-16
```

20 CTest geçti:

- Ubuntu 24.04 / gfortran 14
- macOS ARM64 / gfortran 14
- Windows / gfortran 14
- Windows 2022 / Intel ifx 2025.2

---

## 5. Açık kaynak Fortran bağımlılık politikası

Aktif dependency:

`https://github.com/kavakfatih/stdlib`

Pinned commit:

`9a15c7772f1a76a6c497b9f3abb793841fc81f74`

Dyna kendi bilimsel çekirdeğini sahiplenir:

- constitutive law
- FEM formulation
- incompressibility strategy
- axisymmetric formulation
- torsion formulation
- nonlinear solution policy

Kütüphaneler infrastructure/solver/calibration katmanlarında adapter arkasında kullanılacak.

Araştırılan/planlanan:

- Reference LAPACK
- MUMPS
- MINPACK
- PRIMA
- PCHIP
- HDF5
- JSON-Fortran
- FrontISTR

---

## 6. V0.3 — Nearly-Incompressible Formulation Bake-off

Aktif branch:

`develop/v0.3`

Üç aday aynı fizik ve aynı benchmarklarda karşılaştırılıyor:

```text
A — displacement-only Q4
B — mixed Q4/P0 u-p
C — F-bar Q4
```

Production formulation henüz seçilmedi.

---

## 7. Ortak V0.3 yük/solver altyapısı

Eklendi:

- Q4 reference-edge traction
- 2-point edge Gauss integration
- skew-edge force conservation
- InternalMesh edge-load global assembly
- fixed-increment force-control Full Newton
- homogeneous analytic traction benchmark
- Cook-benzeri 2×2 / 4×4 / 8×8 mesh benchmarkları
- final-state `J` ile historical Newton minimum `J` ayrımı
- Newton iteration / lineer solve / equation-count ölçümü

Birleşik benchmark:

`tests/test_v03_cook_bakeoff_compare.f90`

Aynı executable içinde üç formulation çözülür ve doğrudan:

`V0.3_COOK_BAKEOFF_RESULTS.json`

üretilir.

Platform numerical reproducibility aracı:

`tools/verification/compare_v03_platform_results.py`

---

## 8. Displacement-only Q4 baseline

V0.2 full-integration Q4, V0.3'te locking baseline olarak korunuyor.

Cook baseline:

```text
mu = 1
lambda = 1000
traction_y = 0.01
```

Önemli karar:

> Coarse-to-8x8 displacement gap tek başına locking metriği değildir. 8x8 Q4 de locked olabilir. Production karşılaştırması dış converged referansa göre yapılacak.

---

## 9. Mixed Q4/P0

Mixed potential:

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

Element:

```text
8 displacement DOF + 1 constant P0 pressure DOF
```

Global sistem:

```text
[ Kuu Kup ] [du] = -[Ru]
[ Kpu Kpp ] [dp]    [Rp]
```

Tamamlandı:

- 9×9 residual/tangent
- `Kuu/Kup/Kpu/Kpp`
- tangent merkezi FD validation
- local error ≈ `1.74e-9`
- global mixed assembly
- mixed force-control Full Newton
- homogeneous analytic traction
- Cook 2×2 / 4×4 / 8×8

Pressure diagnostics:

- min/max/mean/std/RMS
- edge-neighbor graph
- neighbor jump RMS/max
- normalized jump
- `neighbor_jump_to_std`
- `graph_roughness`

Manufactured homogeneous pressure reference:

```text
Exact J                   = 1.031600
Exact pressure            = 0.5911089
maximum pressure residual = 1.11e-16
graph roughness           = 0
```

Cook benchmarkına ayrıca element bazlı pressure stationarity consistency kontrolü eklendi:

```text
p_e = lambda <ln J>_e
```

Bu kontrol pressure alanı roughness'ından ayrıdır; mixed denklemin kendisinin çözülüp çözülmediğini ölçer.

---

## 10. F-bar Q4

Kinematik:

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Enerji:

```text
E(u) = sum_g W(F_bar_g(u)) w_g
```

Residual bu enerjinin ilk varyasyonundan hesaplanır.

İlk prototipte numerical tangent kullanılmıştı. Bu sınır kaldırıldı.

Analitik consistent tangent:

```text
H_q = dF_bar/dq
    = alpha [B_q + beta_q F]

K_qr = sum_g w_g [H_q : A_bar : H_r + P_bar : H_qr]
```

Bağımsız doğrulama:

```text
Python derivation/reference:
normalized cross-FD error ≈ 8.73e-10
symmetry error            ≈ 1.90e-16

GNU Fortran 14.2 local:
max normalized cross-FD   ≈ 1.20e-9
symmetry error            ≈ 2.45e-16
```

F-bar artık numerical-tangent prototipi değildir.

---

## 11. Bağımsız Cook precheck

GitHub Actions CI engelinden bağımsız ikinci Python/NumPy FEM implementasyonu kullanıldı.

Kayıtlar:

- `docs/verification/results/V0.3_COOK_INDEPENDENT_PRECHECK.json`
- `docs/verification/V0.3_COOK_PRECHECK_ANALYSIS.md`

Tip displacement:

```text
              2x2         4x4         8x8
Displacement  0.00569117  0.00595658  0.00656453
Mixed         0.01224824  0.01685744  0.01915555
F-bar         0.01347320  0.01751507  0.01940549
```

Sinyaller:

```text
8x8 displacement / F-bar ≈ 33.8%

Mixed-F-bar relative tip farkı:
2x2 ≈ 9.09%
4x4 ≈ 3.75%
8x8 ≈ 1.29%

Mixed graph roughness:
2x2 ≈ 2.874
4x4 ≈ 0.976
8x8 ≈ 0.321
```

Bu precheck resmi Dyna Fortran/CTest kanıtı değildir.

### Geçici cross-check hata kaydı

İkinci geçici Python cross-check'te Q4 parent→reference gradient dönüşüm yönü yanlış uygulanmıştı (`J^{-1}` yerine Dyna'nın kullandığı `J^{-T}` yönü gerekliydi).

Yanlış geçici sonuç dosyaları repodan kaldırıldı.

Doğru dönüşüm uygulandığında mevcut `V0.3_COOK_INDEPENDENT_PRECHECK` sonuçları yeniden elde edildi.

Bu olay regression/reference matematiğinde dönüşüm yönünün açık tutulması gerektiğini teyit etti; Fortran üretim kodunda bu hata yoktu.

---

## 12. V0.3 incompressibility sweep

Yeni test:

`tests/test_v03_incompressibility_sweep.f90`

4×4 Cook meshinde:

```text
lambda/mu = 10, 100, 1000
```

üç formulation aynı yük altında çözülüyor.

Bağımsız doğru-gradient precheck:

```text
lambda/mu    Displacement     Mixed        F-bar
10           0.01326101       0.01841319   0.01911670
100          0.00744673       0.01702588   0.01768588
1000         0.00595658       0.01685744   0.01751507
```

`10 → 1000` değişiminde:

```text
Displacement tip drop ≈ 55.08%
Mixed tip drop        ≈  8.45%
F-bar tip drop        ≈  8.38%
Mixed/F-bar farkı @1000 ≈ 3.75%
```

Ham precheck:

`docs/verification/results/V0.3_INCOMPRESSIBILITY_SWEEP_PRECHECK.json`

Bu test displacement-only Q4 locking davranışını doğrudan `lambda/mu` ekseninde regression kriterine dönüştürür.

---

## 13. Benchmark JSON metadata düzeltmesi

F-bar artık analitik tangent kullandığı için `parse_v03_bakeoff_log.py` metadata'sı güncellendi:

```text
formulation = fbar_q4
tangent = analytic_energy_consistent_second_variation
```

Eski `central_finite_difference_verification_tangent` etiketi kaldırıldı.

---

## 14. V0.3 bağımsız FEniCSx Q2 referansı

Script:

`tools/reference/fenicsx_v03_cook_q2_reference.py`

Hedef:

- aynı Cook geometri/material/yük
- Q2 quadrilateral
- 2×2 / 4×4 / 8×8 / 16×16
- UFL automatic residual/Jacobian
- PETSc SNES + LU/MUMPS
- tip displacement
- continuum `p=lambda ln(J)`
- average `J`
- total strain energy

Dyna'nın formulation kodunu kullanmayan dış referanstır.

---

## 15. Platform önceliği

Birincil hedefler:

```text
Windows x64 / Intel ifx
Windows x64 / gfortran
macOS Apple Silicon / gfortran
```

Linux:

```text
secondary scientific CI
FEniCSx external reference
```

Linux ürün dağıtım önceliği değildir.

---

## 16. Açık GitHub Actions engeli

Draft PR conflict'i çözülmüş olsa da GitHub-hosted Actions job'ları:

- Windows / gfortran
- Windows / Intel ifx
- macOS ARM64 / gfortran
- Linux / gfortran
- FEniCSx Q2

runner step'leri başlamadan failure olmaktadır.

Tek Linux rerun'ında da aynı pre-step failure görülmüştür.

Bu nedenle mevcut failure:

```text
Fortran derleme hatası değil
CMake configure hatası değil
CTest physics failure değil
```

olarak değerlendiriliyor; GitHub Actions account/repository usage veya runner provisioning engeli ayrıca çözülmeli.

---

## 17. Güncel V0.3 test durumu

CTest tanımı:

**35 test**

Yeni/önemli V0.3 testleri arasında:

- displacement Cook locking baseline
- mixed Cook baseline
- F-bar Cook baseline
- birleşik üçlü Cook bake-off
- mixed pressure uniformity
- mixed Cook pressure stationarity consistency
- incompressibility `lambda/mu` sweep
- F-bar analytic tangent cross-FD/symmetry

35-test Windows/macOS matrix henüz GitHub Actions engeli nedeniyle kapanmış sayılmıyor.

---

## 18. Güncel sıradaki adım

1. GitHub-hosted Actions pre-step engelini çöz.
2. Windows/ifx + Windows/gfortran + macOS ARM64/gfortran 35-test matrix'i kapat.
3. Üç platformun `V0.3_COOK_BAKEOFF_RESULTS.json` sonuçlarını numerical reproducibility açısından karşılaştır.
4. Incompressibility sweep'i üç birincil platformda doğrula.
5. FEniCSx Q2 2/4/8/16 dış referans artifactini al.
6. Dyna üç formulation sonucunu converged Q2 referansına göre relative error ile değerlendir.
7. Mixed pressure mean/std/RMS/stationarity/graph roughness alanını continuum pressure referansıyla kıyasla.
8. Ortak convergence/robustness/maliyet tablosunu tamamla.
9. Seçilen formulation'ı bağımsız solver ile son kez doğrula.
10. Production formulation kararını ADR ile sabitle.

`Sistem-ve-Mimari` branch'ine bu geliştirmelerde dokunulmadı.
