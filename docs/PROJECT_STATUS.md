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

## Hedef platform önceliği

DynaElastomerSolver ürün hedefi:

1. **Windows x64 — birincil**
   - Intel ifx
   - gfortran portability
2. **macOS Apple Silicon — birincil**
   - gfortran
3. **Linux — ikincil bilimsel/CI ortamı**
   - gfortran
   - FEniCSx/DOLFINx dış referans

Linux ürün dağıtım önceliği değildir; bilimsel doğrulama ve taşınabilirlik için tutulur.

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

Q4/P0 hâlâ production formulation seçimi değildir.

## Aday C — F-bar Q4

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

### Analitik consistent tangent — tamamlandı, platform CI bekliyor

İlk verification prototipindeki merkezi finite-difference tangent kaldırıldı. Element tangent artık aynı enerjinin analitik ikinci varyasyonundan hesaplanır.

Temel zincir:

```text
H_q = dF_bar/dq = alpha [B_q + beta_q F]

K_qr = sum_g w_g [H_q : A_bar : H_r + P_bar : H_qr]
```

`H_qr`; `alpha`, `J` ve `J_bar`ın ikinci türevlerini içerir. Böylece Gauss noktaları arasındaki volumetrik F-bar coupling tangentte de korunur.

Bağımsız lokal doğrulama:

```text
Python derivation/reference:
normalized cross-FD error ≈ 8.73e-10
symmetry error            ≈ 1.90e-16

GNU Fortran 14.2:
max normalized cross-FD   ≈ 1.20e-9
symmetry error            ≈ 2.45e-16
```

Bu sonuçlar güçlü lokal bilimsel kanıttır; Windows/macOS CI tekrar çalışmadan platform doğrulaması kapanmış sayılmaz.

Tamamlanan F-bar zincir:

- `des_q4_plane_strain_fbar_neo_hookean.f90`
- homogeneous residual equivalence
- **analitik consistent tangent**
- independent cross-FD tangent + symmetry testi
- `des_q4_plane_strain_fbar_mesh.f90`
- global assembly
- `des_q4_plane_strain_fbar_force_solver.f90`
- homogeneous analytic traction benchmark
- F-bar Cook 2x2 / 4x4 / 8x8 benchmark

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

**Durum:** workflow kodu hazır; GitHub-hosted job'lar şu anda herhangi bir step başlamadan failure oluyor. Bu nedenle dış referans sonucu henüz başarı olarak kaydedilmedi.

---

## V0.3 CI ve test durumu

CTest tanımı: **32 test**.

Kesin lokal doğrulamalar:

```text
Mixed Q4/P0 9x9 tangent FD error ≈ 1.74e-9
F-bar analytic tangent cross-FD    ≈ 1.20e-9
F-bar analytic tangent symmetry    ≈ 2.45e-16
Pressure diagnostics unit yolu     geçti
Edge traction / global edge-load   geçti
```

### Açık CI engeli

Draft PR #1 mergeable durumdadır. Ancak GitHub-hosted Actions job'ları Windows, macOS, Linux ve FEniCSx workflow'unda **runner step'leri başlamadan** failure olmaktadır. Tek Linux job rerun'ında da aynı pre-step failure tekrarlandı.

Bu nedenle mevcut kanıt bir Fortran/CMake/FEM test hatasına işaret etmemektedir; failure build veya CTest aşamasına ulaşmamaktadır. Repository/account Actions kullanım ayarı veya GitHub-hosted runner provisioning tarafı ayrıca çözülmelidir.

V0.3 compiler matrix hedefi:

- **macOS ARM64 / gfortran 14 — birincil**
- **Windows / gfortran 14 — birincil**
- **Windows 2022 / Intel ifx 2025.2 — birincil**
- Ubuntu 24.04 / gfortran 14 — ikincil bilimsel CI

---

## Sıradaki V0.3 adımları

1. GitHub-hosted Actions pre-step engelini çöz ve önce Windows/macOS birincil matrix'i yeniden çalıştır.
2. F-bar analitik tangent'i Windows/ifx, Windows/gfortran ve macOS/gfortran üzerinde doğrula.
3. Gerçek Cook displacement / mixed / F-bar değerlerini ortak JSON'a çıkar.
4. FEniCSx Q2 2/4/8/16 Cook dış referansını çalıştır ve artifact sonucunu sakla.
5. Dyna tip displacement trendini Q2 16x16 referansına göre karşılaştır.
6. Mixed `p` mean/std/RMS ve graph roughness trendini continuum `lambda ln(J)` referansıyla kıyasla.
7. Üç formulation için ortak mesh / convergence / robustness / maliyet tablosunu oluştur.
8. Seçilen adayı bağımsız solver ile son kez doğrula.
9. Yalnız bundan sonra production formulation ADR kararını ver.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: V0.3 draft entegrasyon görünürlüğü; exit criteria öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
