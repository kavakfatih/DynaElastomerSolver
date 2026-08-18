# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı — V0.2.0

- Branch: `release/v0.2`
- CMake: `0.2.0`
- Release metadata commit: `d9a960fb2b8cd9aac0018deb5b099cf68ddc062f`
- Durum: **tamamlandı**

V0.2, 20 CTest ile Ubuntu/gfortran14, macOS ARM64/gfortran14, Windows/gfortran14 ve Windows 2022/Intel ifx 2025.2 üzerinde doğrulandı. FEniCSx/DOLFINx bağımsız FEM karşılaştırması da geçti.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake: `0.3.0`
- Draft entegrasyon PR: **#1 — `V0.3 — Nearly-Incompressible Formulation Bake-off`**
- PR durumu: **draft / merge edilmeyecek**; V0.3 exit criteria tamamlanmadan `main`e alınmayacak.
- Hedef: **Nearly-Incompressible Formulation Bake-off**

```text
Displacement-only Q4
        vs
Mixed Q4/P0 u-p
        vs
F-bar Q4
```

Production formulation henüz seçilmemiştir.

---

## V0.3 ortak benchmark altyapısı

Tamamlanan implementasyon:

- Q4 reference-edge traction / 2-point Gauss
- skew-edge ve total-force conservation testleri
- InternalMesh edge-load global assembly
- fixed-increment force-control Full Newton driver
- homogeneous analytic traction benchmark
- normalize Cook-benzeri 2x2 / 4x4 / 8x8 benchmark geometrisi
- develop branch için dört-compiler CI status context'leri
- branch concurrency: eski V0.3 koşuları iptal edilip yalnız en güncel commit tutulur
- Linux CTest `LastTest.log` benchmark artifact kaydı
- başarılı Fortran benchmark stdout'undan ortak `V0.3_COOK_BAKEOFF_RESULTS.json` üreten parser

Benchmark JSON'u yeni fizik hesaplamaz; yalnız gerçekten geçen Fortran CTest çıktısını provenance bilgisiyle makine-okunur hale getirir.

## Aday A — Displacement-only Q4

V0.2'den gelen full-integration baseline aynı Cook problemine bağlandı.

```text
mu = 1
lambda = 1000
traction_y = 0.01
```

Amaç: near-incompressible coarse-mesh stiffness / volumetric-locking eğrisini sabitlemek.

## Aday B — Mixed Q4/P0

Ortak V0.2 material law'u koruyan mixed potential:

```text
Psi(F,p) = mu/2 (I1-3)
         - mu ln(J)
         + p ln(J)
         - p^2/(2 lambda)
```

Stationarity:

```text
p = lambda ln(J)
```

Bu ilişki yerine konduğunda V0.2 compressible Neo-Hookean enerjisi geri elde edilir; karşılaştırmada material law değil volumetrik formulation değişir.

Global DOF:

```text
[u1x,u1y,...,unx,uny | p1,...,p_nelem]
```

Tamamlanan mixed zincir:

- Q4 displacement + P0 element pressure
- 9x9 element residual/tangent
- `Kuu/Kup/Kpu/Kpp`
- merkezi finite-difference tangent doğrulaması
- yerel GNU Fortran 14.2 tangent error ≈ `1.74e-9`
- homogeneous `p=lambda ln(J)` residual equivalence
- global mixed assembly
- mixed Full Newton force-control
- homogeneous analytic traction benchmark
- Cook 2x2 / 4x4 / 8x8 benchmark

### Pressure stability diagnostics

`src/fortran/results/des_pressure_diagnostics.f90`

Metrikler:

- min / max / mean
- standard deviation / RMS
- edge-neighbor pair count
- neighbor pressure-jump RMS
- maximum neighbor jump
- pressure RMS ile normalized neighbor jump
- **mean'den arındırılmış `neighbor_jump_to_std`**
- **`graph_roughness = (jump_rms/std)^2`**

`graph_roughness` mesh-komşuluk grafiğinde yüksek frekanslı pressure değişimini boyutsuzlaştırmak için eklenmiştir. Tek başına checkerboard kararı değildir; mesh refinement ve bağımsız pressure reference ile birlikte yorumlanacaktır.

Unit testte bilinen 2x2 pressure alanı için neighbor graph, jump RMS ve yeni roughness değerleri analitik beklenen değerlerle kontrol edilir; sabit pressure alanında roughness sıfır olmalıdır.

Q4/P0 hâlâ yalnız ilk mixed prototiptir; production formulation seçimi değildir.

## Aday C — F-bar verification prototype

Volumetric correction:

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Dyna 3x3 deformation-gradient temsili kullandığı için volumetric scaling üç boyutlu determinant mantığıyla yapılır.

### Energy-consistent residual

```text
E(u) = sum_g W(F_bar_g(u)) w_g
```

Residual bu enerjinin ilk varyasyonundan türetilmiştir; `J_bar` nedeniyle Gauss noktaları arasındaki coupling korunur.

### Tangent durumu

İlk F-bar tangent merkezi finite-difference ile üretilmektedir. Bu bilinçli **verification-first** prototip kararıdır. F-bar production adayı olarak kalırsa analitik consistent tangent ayrıca türetilecektir.

Tamamlanan F-bar zincir:

- `des_q4_plane_strain_fbar_neo_hookean.f90`
- homogeneous residual equivalence testi
- cross-FD tangent + symmetry testi
- `des_q4_plane_strain_fbar_mesh.f90`
- global assembly
- `des_q4_plane_strain_fbar_force_solver.f90`
- homogeneous analytic traction benchmark
- F-bar Cook 2x2 / 4x4 / 8x8 benchmark

F-bar residual/solver formu ayrıca gözden geçirildi; `J_bar` coupling ve external-force residual işaretinde açık bir tutarsızlık görülmedi. Yine de dört-compiler ve dış referans tamamlanmadan doğrulanmış production davranışı olarak kabul edilmeyecektir.

---

## Bağımsız V0.3 dış referans

Yeni bağımsız referans:

`tools/reference/fenicsx_v03_cook_q2_reference.py`

Amaç:

- Dyna Fortran element/assembly/Newton kodunu kullanmayan bir çözüm üretmek
- aynı normalize Cook geometrisi
- aynı compressible Neo-Hookean `mu=1`, `lambda=1000`
- aynı sağ kenar nominal traction `0.01`
- plane strain için 3x3 `F`, `F33=1`
- Q2 quadrilateral displacement alanı
- meshler: 2x2 / 4x4 / 8x8 / 16x16
- PETSc SNES + LU/MUMPS
- UFL automatic residual/Jacobian
- tip displacement
- continuum pressure `p=lambda ln(J)` mean/std/RMS
- ortalama `J`, total energy ve SNES iteration sayısı

Workflow:

`.github/workflows/fenicsx-v03-reference.yml`

- pinned container: `dolfinx/dolfinx:v0.11.0`
- artifact: `fenicsx-v03-cook-q2-reference`
- custom status: `dyna/v0.3-fenicsx-q2-reference`

**Durum:** workflow ve script repoya eklendi; gerçek run sonucu henüz başarı olarak kaydedilmemiştir.

---

## V0.3 CI ve test durumu

CTest tanımı: **32 test**.

Kesin yerel doğrulamalar:

```text
Mixed Q4/P0 9x9 tangent FD error ≈ 1.74e-9
Pressure diagnostics önceki unit test yolu: geçti
Edge traction / global edge-load: geçti
```

Yeni pressure graph-roughness testleri ve F-bar tam zinciri dört-compiler CI sonucu görülmeden tamamlandı sayılmayacaktır.

V0.3 compiler matrix hedefi:

- Ubuntu 24.04 / gfortran 14
- macOS 26 ARM64 / gfortran 14
- Windows 2025 / gfortran 14
- Windows 2022 / Intel ifx 2025.2

**Durum:** tam matrix henüz kapanmış olarak işaretlenmemiştir.

---

## Sıradaki V0.3 adımları

1. Aynı sabit `develop/v0.3` commit'i için 32-test dört-compiler sonucu kesinleştir.
2. Linux CTest artifactinden displacement / mixed / F-bar gerçek Cook değerlerini ortak JSON'a çıkar.
3. FEniCSx Q2 2/4/8/16 Cook dış referansını çalıştır ve artifact sonucunu sakla.
4. Dyna 2/4/8 tip displacement trendini Q2 16x16 referansına göre karşılaştır.
5. Mixed `p` mean/std/RMS değerlerini continuum `lambda ln(J)` referansıyla karşılaştır.
6. `neighbor_jump_to_std` ve `graph_roughness` mesh-refinement trendini değerlendir.
7. F-bar'ın güçlü kalması halinde analitik consistent tangent türet.
8. Üç formulation için ortak mesh / convergence / robustness / maliyet tablosunu oluştur.
9. Seçilen adayı bağımsız solver ile son kez doğrula.
10. Yalnız bundan sonra production formulation ADR kararını ver.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: V0.3 draft entegrasyon görünürlüğü; exit criteria öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
