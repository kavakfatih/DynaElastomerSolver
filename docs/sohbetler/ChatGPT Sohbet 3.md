# ChatGPT Sohbet 3 — B8 Mimari Genişleme Başlangıcı

Tarih: 2026-08-22

## Çalışma Konusu

DynaElastomerSolver V0.3 sonrasında ANSYS Mechanical ve Hexagon Marc seviyesinde nonlinear elastomer solver altyapısının genişletilmesi.

## Mevcut Durum

Aktif branch:

- develop/v0.3

Korunan temel:

- Q9/P1 Herrmann mixed u-P ana production yolu
- F-bar bağımsız cross-check
- nonlinear Newton altyapısı
- adaptive increment/cutback
- block DOF ve sparse solver genişleme hazırlığı

## B8 Hedefi

Solver mimarisini analiz tiplerinden bağımsız hale getirmek:

- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D

## İlk Geliştirme Paketi

B8.1 Analysis Type Abstraction

Amaç:

Element, material ve nonlinear solver katmanlarının analiz kinematiğinden ayrılması.

Yeni yapılar:

- AnalysisType
- Kinematics manager
- Axisymmetric hazırlığı

## Sonraki Paketler

B8.2 Axisymmetric Q9/P1 Herrmann

B8.3 Axisymmetric torsion / 2.5D

B8.4 Hyperelastic material library

## Geliştirme Kuralı

Önce çalışan ve doğrulanan küçük fizik zinciri; sonra genişleme.

Her yeni formulation:

- analytic tangent
- FD tangent
- mesh convergence
- benchmark

ile doğrulanacak.

---

## 2. 2026-08-22 GitHub çalışma akışının yeniden doğrulanması ve gerçek implementasyon checkpoint'i

Kullanıcı geliştirmeye GitHub üzerinden gerçek dosya değişikliği, commit ve CI döngüsüyle devam edilmesini istedi. Bu kayıt bu turun **ilk repo write'ıdır**; sonraki teknik kaynak değişiklikleri bu checkpoint'ten sonra yapılacaktır.

Canlı GitHub durumu:

```text
PR #1       = open
draft       = true
merged      = false
mergeable   = false
head branch = develop/v0.3
head SHA    = 8a323277f79214fd8e513423d74a837818da9762
```

Aynı head üzerinde yayımlanmış normal compiler status'ları:

```text
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS
```

Production MUMPS ve dedicated MUMPS-int64 custom status'ları bu checkpoint anında aynı head için görünmemektedir; bu nedenle full 9/9 acceptance ilan edilmez.

Canlı head incelemesinde son commit `8a323277...` ile `src/fortran/fem/des_q9_plane_strain_mixed_up_kernel.f90` dosyasına yeni bir Q9/P1 foundation eklenmiştir. Bu dosya `9 displacement node x 2 + 1 pressure = 19 DOF` sözleşmesi kullanmaktadır. Ancak repository'nin daha önce doğrulanmış Herrmann P1 pressure-space sözleşmesi complete-linear `[1, xi, eta]` ve **3 bağımsız pressure DOF** kullanmaktadır; dolayısıyla Q9/P1 yerel bilinmeyen sayısı 21'dir. Yeni 19-DOF foundation mevcut production/reference formulation ile uyumlu değildir ve production mimarisinin üstüne inşa edilmeyecektir.

Bu turdaki teknik hedefler:

```text
1. 19-DOF Q9/P1 regression'ını mevcut 3-pressure-DOF Herrmann sözleşmesiyle hizala veya ayrı legacy/experimental sınırına çek
2. mevcut C1-C4 2D field-based mesh/DOF/CSR/nonlinear yollarını gerçek kaynak üzerinden yeniden doğrula
3. mixed block solver geliştirmesini mevcut global equation layout'u bozmadan ekle
4. Kuu/Kup/Kpu/Kpp alan görünümünü monolitik CSR production çözüm yolunun üstünde güvenli bir abstraction olarak kur
5. MUMPS Direct'i doğruluk/reference production backend olarak koru
6. iterative block/Schur/FGMRES yolu ancak mevcut fully-incompressible saddle-point ve pressure-stability kapılarını geçerse production candidate olsun
7. axisymmetric ve axisymmetric-with-torsion vertical slice'ını koru; torque-angle/reaction-torque contract geriye gitmesin
```

ANSYS/Marc seviyesi burada mimari ve doğrulama hedefidir; commercial parity yalnız eşlenik benchmark sonuçlarıyla ilan edilecektir. `supports_int64=false` end-to-end FEM equation numbering → CSR → backend capability zinciri tamamen kapanana kadar korunur.

PR #1 draft/open kalacaktır. Kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.
