# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Ana ve sürekli güncellenen branch:** `main`

## Güncel geliştirme sürümü

**V0.2-dev — Nonlinear FEM Robustness**

V0.2 bilimsel/işlevsel kapsamı büyük ölçüde tamamlanmıştır. Sürüm henüz kapatılmamıştır; kalan tek büyük kapanış maddesi Windows Intel ifx toolchain doğrulamasıdır.

## Çalışan bilimsel çekirdek

- Modern Fortran 2018 + CMake
- finite-strain kinematics
- sıkıştırılabilir Neo-Hookean
- strain energy
- First Piola-Kirchhoff stress
- Cauchy stress
- analitik consistent `dP/dF`
- material tangent FD doğrulaması
- Q4 plane-strain
- 2×2 Gauss integration
- Total-Lagrangian residual/tangent
- çok elemanlı assembly
- fixed-step Full Newton
- adaptive Newton
- rollback / cutback / retry
- `solution_state_t`: trial/commit/revert
- convergence history
- minimum `J` ve failure diagnostics
- `InternalMesh`
- ham integration-point results
- backend-bağımsız lineer solver sınırı
- stdlib/LAPACK dense backend
- Newton lineer solver diagnostics

## Aktif Fortran dependency

**`kavakfatih/stdlib`**

- repo: `https://github.com/kavakfatih/stdlib`
- stdlib sürümü: `0.8.1`
- pinlenen commit: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`
- build önişlemcisi: `fypp 3.2`
- ilk gerçek kullanım: `stdlib_linalg::solve` → LAPACK dense solve

Ayrıntılı envanter: `docs/references/FORTRAN_LIBRARIES.md`

## V0.2 ana doğrulama sonuçları

- material tangent normalize FD hatası ≈ `1.26e-9`
- Q4 element tangent normalize FD hatası ≈ `1.16e-9`
- iki elemanlı reaction relative error ≈ `1e-15`
- solver final free residual ≈ `5.4e-15`
- nonlinear patch merkez displacement error ≈ `3.9e-17`
- adaptive cutback final residual ≈ `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh reaction = `1.605586`
- InternalMesh ile eski assembly residual/tangent eşdeğerliği doğrulandı
- affine `F=diag(1.10,0.95,1)` için tüm Gauss noktalarında `J=1.045`

Detaylı katalog:

`docs/verification/V0.2_REFERENCE_BENCHMARKS.md`

## Severe-distortion continuum benchmark

2×2 Q4 mesh, merkez node:

```text
X5 = (1.45, 0.55)
```

Exact affine deformation:

```text
F = [1.35  0.28  0]
    [0.12  0.78  0]
    [0     0     1]

J = 1.0194
```

Test FEM/material-response API'sinden bağımsız kapalı-form Neo-Hookean referansı ile `F`, `J`, weighted `P`, toplam reference area ve toplam strain energy'yi karşılaştırır.

## Bağımsız dış FEM doğrulaması — BAŞARILI

Dış referans:

**FEniCSx / DOLFINx `0.11.0.post0`**  
Container: `dolfinx/dolfinx:v0.11.0`  
GitHub Actions run: `32075320773`  
Dyna commit: `3ba4c23e94f94b9d067c45f52d4bb10ee0b0542e`

Problem:
- 2×1 plane-strain rectangle
- Q1 quadrilateral 8×4 mesh
- `mu=2.5`, `lambda=20`
- `lambda_x=1.25`
- lateral traction-free
- Dyna ile aynı Neo-Hookean energy function
- residual/Jacobian: UFL automatic differentiation
- nonlinear solver: PETSc SNES
- linear solver: PETSc LU/MUMPS

FEniCSx:

```text
lambda_y average    = 0.8314690882666764
reaction_x          = 1.7423183105139580
J average           = 1.0393363603333432
total strain energy = 0.47146216298567123
SNES iterations     = 4
```

Dyna hedefi:

```text
lambda_y   = 0.8314690882666784
reaction_x = 1.7423183105139586
```

Mutlak FEniCSx ↔ Dyna farkı:

```text
lambda_y   ≈ 2.00e-15
reaction_x ≈ 6.66e-16
```

FEniCSx ↔ kapalı-form farkı:

```text
J            ≈ 4.88e-15
total energy ≈ 5.72e-15
```

Bağımsız dış FEM kriteri **geçmiştir**.

Kalıcı kayıtlar:
- `docs/verification/V0.2_EXTERNAL_FEM_VALIDATION.md`
- `docs/verification/results/FENICSX_V0.2_HOMOGENEOUS_EXTENSION.json`
- `tools/reference/fenicsx_v02_homogeneous_extension.py`
- `.github/workflows/fenicsx-reference.yml`

## Compiler matrix

Fortran workflow:

`.github/workflows/fortran-ci.yml`

20 CTest tanımı bulunmaktadır.

Doğrulanmış GitHub-hosted sonuçlar:

- [x] Ubuntu 24.04 / gfortran 14 — configure + build + **20 CTest başarılı**
- [x] macOS 26 ARM64 / gfortran 14 — configure + build + **20 CTest başarılı**
- [x] Windows 2025 / gfortran 14 — configure + build + **20 CTest başarılı**
- [ ] Windows / Intel ifx 2025.2 — toolchain doğrulaması açık

### ifx araştırmasında bulunan nedenler

İlk Ninja yolu:

```text
ifx --version: başarılı
CMake compiler identification: unknown
CMAKE_Fortran_PREPROCESS_SOURCE: missing
```

Bu durum CMake 4.4 ve ayrıca 4.3.4 ile tekrarlandı; kaynak/test hatası değildir.

İkinci denemede Visual Studio 17 2022 generator kullanıldığında `windows-2025` runner'ın Haziran 2026 itibarıyla VS2026 imajına yönlendirildiği ve VS2022 instance bulunmadığı doğrulandı.

Bu nedenle Intel job artık:

```text
windows-2022
Visual Studio 17 2022
-T fortran=ifx
Intel ifx 2025.2
```

kombinasyonunda doğrulanmaktadır.

## V0.2 kapanışından önce kalanlar

1. Windows 2022 / Intel ifx 2025.2 configure + build + 20 CTest'i başarıyla tamamlamak.
2. Son compiler-matrix sonucunu kalıcı doğrulama kaydına geçirmek.
3. V0.2 exit criteria'yı son kez kontrol edip kilometre taşını kapatmak.

Bağımsız dış FEM solver karşılaştırması artık kalan işler arasında değildir; tamamlanmıştır.

---

## Sıradaki geliştirme sürümü

**V0.3 — Nearly-Incompressible Formulation Bake-off**

```text
Displacement-only Q4
        vs
Mixed u-p
        vs
F-bar / eşdeğer locking azaltıcı formulation
```

Karar ölçütleri:
- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear Newton convergence
- distortion sensitivity
- minimum `J`
- DOF ve assembly maliyeti
- linear-system conditioning
- axisymmetric genişletilebilirlik
- axisymmetric torsion / 2.5D genişletilebilirliği

Production formulation benchmark kanıtıyla seçilecek ve ADR ile sabitlenecektir.

## Branch güncelleme kuralı

Sürekli proje kayıtları varsayılan olarak yalnız `main` branch'inde güncellenir.

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
