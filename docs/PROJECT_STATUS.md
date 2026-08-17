# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-17  
**Ana ve sürekli güncellenen branch:** `main`

## Güncel geliştirme sürümü

**V0.2-dev — Nonlinear FEM Robustness**

Bu sürüm yayınlanmış bir ürün sürümü değil; aktif geliştirme kilometre taşıdır.

### Çalışan çekirdek

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
- çok elemanlı global assembly
- pivotlamalı dense lineer çözücü
- incremental Full Newton displacement-control solver
- adaptive displacement-control solver
- rollback
- cutback / retry
- açık material/FEM/solver status kodları
- minimum `J` takibi
- Newton iteration/increment raporlaması

### Kanıtlanmış doğrulamalar

- Material tangent normalize FD hatası: yaklaşık `1.26e-9`
- Q4 element tangent normalize FD hatası: yaklaşık `1.16e-9`
- İki elemanlı reaksiyon referans hatası: yaklaşık `1.0e-15`
- Solver API final free residual: yaklaşık `5.4e-15`
- Distorsiyonlu nonlinear patch merkez displacement hatası: yaklaşık `3.9e-17`
- Adaptive cutback final residual: yaklaşık `3.9e-15`
- 1×1 / 2×2 / 4×4 homojen mesh refinement reaksiyonu: `1.605586`

### Adaptive failure senaryosu

```text
%100 ilk increment
      ↓
non-positive J
      ↓
trial çözüm reddedildi
      ↓
rollback
      ↓
%50 cutback
      ↓
retry
      ↓
ikinci kabul edilmiş increment
      ↓
%100 final yük seviyesi
```

Bu davranış, solver robustness mimarisindeki rollback/cutback kavramının gerçek bir failure benchmark'ı ile kanıtlandığını gösterir.

## V0.2 kapanışından önce kalan işler

1. Committed / trial çözüm state'ini reusable ve genel bir yapı haline getirmek.
2. Convergence history kaydı.
3. Cutback exhaustion / retry limit tanıları.
4. Failure reason raporlarını daha açık hale getirmek.
5. Ek nonlinear distortion ve robustness benchmark'ları.
6. macOS Apple Silicon + gfortran doğrulaması.
7. Windows x64 + Intel ifx doğrulaması.
8. Windows x64 + gfortran doğrulaması.
9. V0.2 çıkış kriterlerini tamamlayıp sürümü kapatmak.

---

## Sıradaki geliştirme sürümü

**V0.3 — Nearly-Incompressible Formulation Bake-off**

Amaç: elastomer için production element formulasyonunu varsayımla değil, aynı benchmark setinde karşılaştırarak seçmek.

### Karşılaştırılacak yollar

```text
Displacement-only Q4
        vs
Mixed u-p
        vs
F-bar / eşdeğer locking azaltıcı formulasyon
```

### Karar ölçütleri

- volumetric locking
- pressure stability / oscillation
- mesh convergence
- nonlinear Newton convergence
- distortion sensitivity
- minimum `J` davranışı
- DOF maliyeti
- assembly karmaşıklığı
- linear-system conditioning
- axisymmetric'e genişletilebilirlik
- axisymmetric torsion / 2.5D'ye genişletilebilirlik

### V0.3 çıkış kriteri

Production nearly-incompressible elastomer formulation, ölçülmüş benchmark sonuçlarıyla seçilecek ve yeni bir ADR ile sabitlenecektir.

---

## V0.3 sonrasındaki ana sıra

1. **V0.4 — Axisymmetric Nonlinear Elastomer**
2. **V0.5 — Axisymmetric Torsion / 2.5D**
3. **V0.6 — Hedef Hyperelastic Model Library**
   - Mooney-Rivlin
   - Yeoh
   - Ogden
4. Material calibration / Material Lab
5. Production solver robustness genişlemesi
6. Results pipeline uygulaması
7. Gerekli seviyede Qt frontend implementasyonu

## V1.0 ana hedefi

DynaElastomerSolver V1.0'ın hedefi genel amaçlı ANSYS/Marc feature parity değildir.

Hedef:

> Bonded metal–elastomer sistemlerinde, büyük deformasyonlu quasi-static plane-strain / axisymmetric / axisymmetric-torsion problemlerini seçilmiş ve doğrulanmış hiperelastik modeller ile güvenilir şekilde çözmek; sonuçları bağımsız solver ve fiziksel ürün testleriyle tanımlı mühendislik toleransları içinde doğrulamak.

## V1.0 kapsam dışı

- frictional contact
- separation
- self-contact
- debonding
- viskoelastisite
- Mullins effect
- fatigue / life prediction
- damage mechanics
- transient / harmonic / explicit dynamics
- binary User Material Plugin
- genel amaçlı CAD

## Branch güncelleme kuralı

Bu dosya ve diğer sürekli proje kayıtları varsayılan olarak yalnız `main` branch'inde güncellenir.

`Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
