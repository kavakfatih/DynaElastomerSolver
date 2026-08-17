# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Ana ve sürekli güncellenen branch:** `main`

## Güncel geliştirme sürümü

**V0.2-dev — Nonlinear FEM Robustness**

Bu sürüm yayınlanmış ürün sürümü değil; aktif geliştirme kilometre taşıdır.

## Çalışan bilimsel çekirdek

- Modern Fortran bilimsel çekirdek
- CMake build altyapısı
- finite-strain kinematics
- sıkıştırılabilir Neo-Hookean material model
- strain energy
- First Piola-Kirchhoff stress
- Cauchy stress
- analitik consistent material tangent `dP/dF`
- finite-difference tangent doğrulaması
- Q4 plane-strain element
- 2×2 Gauss integration
- Total-Lagrangian element residual
- consistent element tangent
- çok elemanlı Q4 global assembly
- incremental Full Newton displacement-control solver
- adaptive displacement-control solver
- rollback
- cutback / retry
- reusable `solution_state_t`
- açık `trial → commit / revert` çözüm state akışı
- `convergence_history_t`
- minimum `J` takibi
- okunabilir solver/material hata açıklamaları

## Yeni V0.2 veri modeli

### Minimal `InternalMesh`

`internal_mesh_t` artık bilimsel çekirdeğin ilk kanonik mesh modelidir.

Şimdilik kasıtlı olarak yalnız:

- 2B düğüm koordinatları
- Q4 connectivity
- düğüm/eleman sayısı
- connectivity doğrulaması
- aynı elemanda yinelenen node kontrolü

taşır.

Harici mesher/CAD tipleri bu sınıra geçirilmez. Gmsh veya başka bir mesh sağlayıcı ileride bu kanonik tipe dönüştürülecektir.

Mevcut dizi tabanlı `X + connectivity` yolu geriye dönük regression testleri için korunur.

### Ham integration-point sonuçları

`integration_point_result_t` ve `integration_point_results_t` eklendi.

Her Q4 Gauss noktası için şu ham bilgiler saklanabilir:

- `element_id`
- `point_id`
- doğal koordinatlar `xi / eta`
- referans integration weight/Jacobian katkısı
- deformation gradient `F`
- `J = det(F)`
- First Piola-Kirchhoff stress `P`
- Cauchy stress
- strain-energy density
- material/status code
- valid flag

Bu veriler **ham Gauss-point sonuçlarıdır**. V0.2'de nodal extrapolation, averaging veya contour sonucu üretilmez.

### InternalMesh solver adapteri

Yeni adapter yolu:

```text
InternalMesh
    ↓
Q4 Newton Solver Adapter
    ↓
mevcut doğrulanmış Full Newton solver
    ↓
final assembly
    ↓
Raw Integration-Point Results
```

Mevcut Newton solver yeniden yazılmadı; doğrulanmış `X + connectivity` solver yolu adapter arkasında yeniden kullanıldı. Böylece veri modeli değişikliği nonlinear çözüm fiziğini gereksiz yere riske atmadı.

## Fortran kütüphane altyapısı

### Aktif dependency — Fortran stdlib

- Dyna repo/fork: `https://github.com/kavakfatih/stdlib`
- upstream: `https://github.com/fortran-lang/stdlib`
- sürüm: `0.8.1`
- pinlenen commit: `9a15c7772f1a76a6c497b9f3abb793841fc81f74`
- lisans: MIT; BLAS/LAPACK backend bölümlerinde ilgili modified-BSD koşulları
- build gereksinimi: `fypp`

İlk aktif kullanım:

```text
des_dense_linear
      ↓
stdlib_linalg::solve
      ↓
Reference LAPACK / *GESV backend
```

### Planlanan/araştırılan kütüphaneler

- Reference-LAPACK/lapack — dense lineer cebir referansı/backend
- fortran-lang/minpack — nonlinear least-squares / Levenberg-Marquardt
- libprima/prima — BOBYQA/COBYLA ve türevsiz bounded/constrained optimization
- jacobwilliams/PCHIP — deneysel eğrilerde shape-preserving interpolation/resampling
- MUMPS — production sparse direct solver adayı
- HDF5 — büyük ResultDatabase/checkpoint adayı
- JSON-Fortran — metadata/config adayı
- FrontISTR — Fortran FEM/MUMPS entegrasyon mimari referansı

Ayrıntılı envanter: `docs/references/FORTRAN_LIBRARIES.md`

## V0.7 için planlanan calibration zinciri

```text
Raw Experimental Data
        ↓
PCHIP
shape-preserving preprocessing
        ↓
Objective + physical admissibility
        ↓
PRIMA BOBYQA / COBYLA
        ↓
MINPACK Levenberg–Marquardt
        ↓
Material validation
        ↓
parameter set + metrics + provenance
```

Bu kütüphaneler V0.2 build dependency'si yapılmamıştır.

## Kanıtlanmış doğrulamalar

Önceki doğrulamalar:

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- iki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- solver API final free residual: yaklaşık `5.4e-15`
- distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh refinement reaksiyonu: `1.605586`
- adaptive failure benchmark: `2 commit / 1 revert`
- cutback exhaustion sonrası committed state korunuyor

Yeni InternalMesh/result doğrulaması:

- yeni `InternalMesh` assembly yolu bağımsız GNU Fortran derlemesinde çalıştı
- eski `X + connectivity` assembly ile residual farkı: test toleransı içinde sıfır
- tangent farkı: test toleransı içinde sıfır
- affine `F = diag(1.10, 0.95, 1.0)` için dört Gauss noktasında `J = 1.045`
- Q4 başına dört ham integration-point sonucu üretildi
- yinelenen node içeren geçersiz Q4 connectivity mesh oluşturma aşamasında reddedildi

Mevcut CTest tanımı **18 test** içerir. Yeni stdlib dependency nedeniyle 18 testin tamamı bu çalışma ortamında toplu olarak henüz koşturulmuş sayılmaz.

## Önemli doğrulama notu

`kavakfatih/stdlib` entegrasyonu kaynak/API/build-konfigürasyonu seviyesinde uygulanmıştır. Bu çalışma ortamında stdlib için gereken tam dependency build ortamı hazır olmadığı için full CTest/compiler matrix doğrulaması V0.2 kapanış maddesi olarak korunmaktadır.

Yeni `InternalMesh + integration-point` alt zinciri ise stdlib'den bağımsız minimal kaynak setiyle GNU Fortran altında ayrıca derlenip çalıştırılmıştır.

## V0.2 kapanışından önce kalan işler

1. stdlib tabanlı tam build'i GNU Fortran üzerinde 18/18 CTest ile doğrulamak.
2. Ek nonlinear distortion / robustness benchmark'ları.
3. Dense doğrulama solver yolunu production `ILinearSolver`/adapter sınırına hazırlamak.
4. Bağımsız solver/reference karşılaştırmasını genişletmek.
5. macOS Apple Silicon + gfortran build/test.
6. Windows x64 + Intel ifx build/test.
7. Windows x64 + gfortran build/test.
8. Compiler matrisi üzerinde regression testlerini çalıştırmak.
9. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

### Bu turda tamamlanan V0.2 maddeleri

- minimal `InternalMesh` veri modeli
- Q4 connectivity validation
- `InternalMesh` tabanlı assembly yolu
- ham integration-point result modeli
- `F / J / P / Cauchy / strain-energy` Gauss-point çıktısı
- eski dizi tabanlı assembly ile eşdeğerlik regression testi
- `InternalMesh` solver adapteri
- başarılı solver final state'inden ham Gauss sonuçlarını toplama yolu

---

## Sıradaki geliştirme sürümü

**V0.3 — Nearly-Incompressible Formulation Bake-off**

Karşılaştırma:

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
- DOF maliyeti
- assembly karmaşıklığı
- linear-system conditioning
- axisymmetric genişletilebilirlik
- axisymmetric torsion / 2.5D genişletilebilirliği

Production nearly-incompressible formulation benchmark kanıtıyla seçilecek ve ADR ile sabitlenecektir.

## V0.3 sonrasındaki ana sıra

1. V0.4 — Axisymmetric Nonlinear Elastomer
2. V0.5 — Axisymmetric Torsion / 2.5D
3. V0.6 — Mooney-Rivlin / Yeoh / Ogden material library
4. V0.7 — PCHIP + PRIMA + MINPACK tabanlı Material Calibration
5. V0.8 — Production NonlinearSolutionManager
6. V0.9 — Minimum engineering workflow / Results / Qt shell
7. V1.0 — doğrulanmış nonlinear elastomer solver

## Branch güncelleme kuralı

Bu dosya ve diğer sürekli proje kayıtları varsayılan olarak yalnız `main` branch'inde güncellenir.

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
