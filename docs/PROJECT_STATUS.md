# DynaElastomerSolver — Güncel Proje Durumu

**Son güncelleme:** 2026-08-18  
**Sürekli kayıt branch'i:** `main`

## Sürüm durumu

### Kararlı — V0.2.0

- Branch: `release/v0.2`
- CMake: `0.2.0`
- Durum: **tamamlandı**

V0.2; Ubuntu/gfortran14, macOS ARM64/gfortran14, Windows/gfortran14 ve Windows 2022/Intel ifx 2025.2 üzerinde doğrulandı. FEniCSx/DOLFINx bağımsız FEM karşılaştırması geçti.

### Aktif geliştirme — V0.3.0

- Branch: `develop/v0.3`
- CMake: `0.3.0`
- Draft PR: **#1 — `V0.3 — Nearly-Incompressible Formulation Bake-off`**
- PR V0.3 exit criteria tamamlanmadan `main`e merge edilmeyecek.
- Production formulation kararı: **ADR-0007**

```text
V0.3 plane-strain nearly-incompressible production default = F-bar Q4
Displacement-only Q4 = baseline / regression
Mixed Q4/P0 = experimental / verification; production değil
```

---

## V0.3 formulation kararı

ADR-0006 gereği production formulation peşinen seçilmedi. V0.3 bake-off aşağıdaki adayları aynı Cook problemi üzerinde karşılaştırdı:

1. displacement-only Q4,
2. mixed Q4/P0 `u-p`,
3. F-bar Q4.

Karar ADR-0007 ile **F-bar Q4** lehine sabitlendi.

### Kararın ana nedenleri

- displacement-only Q4 nearly-incompressible limite giderken belirgin volumetric locking gösteriyor,
- mixed Q4/P0 displacement doğruluğu güçlü olmasına rağmen düzenli quadrilateral mesh üzerinde checkerboard pressure null-mode riski taşıyor,
- F-bar mevcut dış Q2 referansa göre en düşük 8x8 displacement hatasını veriyor,
- F-bar bağımsız pressure DOF eklemeden mixed'e göre daha küçük global sistem oluşturuyor,
- F-bar residual/tangent zinciri energy-consistent ve analytic consistent tangent ile doğrulandı,
- dedicated severe-distortion affine force-control benchmarkı F-bar production yolunu ciddi mesh distorsiyonu altında ayrıca doğruladı,
- büyük-mesh performans baseline'ı ayrı Linux CI artifacti olarak ölçülüyor; wall-clock sonucu correctness eşiği olarak kullanılmıyor.

---

## Resmi compiler matrix

V0.3 güncel CTest sayısı: **37**.

| Platform | Configure | Build | 37 CTest | Benchmark artifacts |
|---|---|---|---|---|
| Windows 2022 / Intel ifx 2025.2 | ✅ | ✅ | ✅ | ✅ |
| Windows / gfortran 14 | ✅ | ✅ | ✅ | ✅ |
| macOS ARM64 / gfortran 14 | ✅ | ✅ | ✅ | ✅ |
| Linux / gfortran 14 | ✅ | ✅ | ✅ | ✅ |

Performans altyapısı dahil doğrulanan code head:

`d89a352f4be4d833bf11aa5b9e953ed8e64805c1`

FEniCSx/DOLFINx V0.3 Cook Q2 dış referans workflow'u da aynı geliştirme hattında yeniden geçti. ✅

Platform numerical reproducibility:

```text
Cook maksimum bağıl fark  ≈ 3.65e-14
Sweep maksimum bağıl fark ≈ 1.39e-13
```

---

## Resmi FEniCSx / DOLFINx Q2 dış referans

```text
DOLFINx = 0.11.0.post0
mu      = 1.0
lambda  = 1000.0
traction_y = 0.01
load step = 5
```

Tip displacement:

| Q2 mesh | Tip displacement |
|---|---:|
| 2x2 | 0.0141286478615 |
| 4x4 | 0.0180747284976 |
| 8x8 | 0.0195456636855 |
| 16x16 | 0.0200264312978 |
| 32x32 | 0.0201973648361 |

Refinement:

```text
8 -> 16  = 2.400665%
16 -> 32 = 0.846316%
```

Configured convergence-aday eşiği `%1` olduğundan 32x32 Q2 referans **converged-aday** kabul edildi.

FEniCSx 32x32 sonucu ile bağımsız Q2/SciPy 32x32 precheck arasındaki relative fark yaklaşık `3.09e-8`.

---

## Dış referansa göre 8x8 formulation doğruluğu

Referans:

```text
FEniCSx Q2 32x32 tip = 0.0201973648361
```

| Formulation | Dyna tip | Relative error |
|---|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% |
| Mixed Q4/P0 | 0.01915555105 | 5.16% |
| F-bar Q4 | 0.01940548609 | **3.92%** |

Mevcut displacement doğruluğunda F-bar en güçlü adaydır ve ADR-0007 ile production default seçilmiştir.

---

## Incompressibility sweep

Sabit 4x4 Cook mesh:

```text
lambda/mu = 10 -> 100 -> 1000
```

Resmi Fortran/CTest sonuçları:

| lambda/mu | Displacement | Mixed | F-bar |
|---:|---:|---:|---:|
| 10 | 0.01326101 | 0.01841319 | 0.01911670 |
| 100 | 0.00744673 | 0.01702588 | 0.01768588 |
| 1000 | 0.00595658 | 0.01685744 | 0.01751507 |

`lambda/mu=10 -> 1000` tip kaybı:

```text
Displacement Q4 = 55.08%
Mixed Q4/P0     =  8.45%
F-bar Q4        =  8.38%
```

Bu sweep displacement-only Q4 locking davranışını açık biçimde ayırıyor.

---

## Mixed Q4/P0 pressure stability sonucu

Regression/decision testi:

`benchmark.v0.3.mixed_up.checkerboard_null_mode`

Düzenli 4x4 Q4 mesh üzerinde mean-zero pressure modları için resmi macOS/gfortran CTest çıktısı:

```text
Checkerboard normalized coupling = 6.223551e-17
Probe normalized coupling        = 1.581139e-01
```

Kontrol pressure modu displacement alanına belirgin kuplaj verirken checkerboard modu makine hassasiyeti seviyesinde kuplajsızdır.

Bu nedenle mevcut Q4/P0 mixed çift:

- araştırma ve doğrulama için korunur,
- production default değildir,
- gelecekte bağımsız pressure DOF gerekirse stabilizasyonlu veya inf-sup kararlı farklı mixed interpolation ayrı benchmark ile seçilir.

---

## F-bar Q4 production yolu

```text
J_bar = integral(J dV0) / integral(dV0)
alpha_g = (J_bar/J_g)^(1/3)
F_bar_g = alpha_g F_g
```

Residual enerjinin ilk varyasyonundan, tangent aynı enerjinin analitik ikinci varyasyonundan hesaplanır.

Doğrulama:

```text
Python cross-FD  ≈ 8.73e-10
Python symmetry  ≈ 1.90e-16
GNU Fortran FD   ≈ 1.20e-9
GNU symmetry     ≈ 2.45e-16
```

8x8 Cook maliyet göstergesi:

| Formulation | Equations | Newton / linear solve |
|---|---:|---:|
| Displacement Q4 | 144 | 10 / 10 |
| Mixed Q4/P0 | 208 | 10 / 10 |
| F-bar Q4 | 144 | 15 / 15 |

F-bar daha fazla Newton iterasyonu gerektiriyor; ancak mixed'e göre yaklaşık `%30.8` daha az equation içeriyor.

---

## F-bar dedicated severe-distortion robustness benchmarkı

Test:

`benchmark.v0.3.fbar.severe_distortion_affine`

Kaynak:

`tests/test_v03_fbar_severe_distortion_affine.f90`

Benchmark, V0.2 severe-distortion geometrisi ile aynı 2x2 Q4 mesh üzerinde çalışıyor. Merkez düğüm belirgin biçimde kaydırılmış durumda ve referans Gauss-Jacobian ağırlık oranı yaklaşık `0.1697`.

Hedef deformation tam izokorik büyük affine finite strain olarak seçildi:

```text
F11 = 1.20
F12 = 0.25
F21 = 0.00
F22 = 0.8333333333
J   = 1.0
mu  = 2.7
lambda = 1000
```

Nominal boundary traction test içinde bağımsız kapalı-form Neo-Hookean `P*N0` ile oluşturuluyor. Böylece traction assembly, F-bar global assembly ve force-control Full Newton aynı testte sınanıyor.

Resmi macOS/gfortran CTest sonucu:

```text
Reference min weight        = 7.254809e-02
Reference weight ratio      = 1.697222e-01
Exact affine free residual  = 1.518785e-13
Recovered displacement err  = 1.267320e-12
Final minimum J             = 1.000000
Final minimum J_bar         = 1.000000
Final maximum J_bar         = 1.000000
Newton linear solve count   = 32
```

Sonuç:

- severe-distorted mesh geçerli referans Jacobian ile korunuyor,
- bağımsız kapalı-form traction altında exact affine equilibrium makine hassasiyetine yakın kapanıyor,
- sıfır başlangıçtan 8 load increment Full Newton hedef affine alanı yaklaşık `1.27e-12` maksimum displacement hatasıyla geri kazanıyor,
- final `J` ve `J_bar` tam izokorik referansla uyuşuyor,
- aynı test Windows/ifx, Windows/gfortran, macOS/gfortran ve Linux/gfortran platformlarının tamamında geçti. ✅

Bu madde ile F-bar production yolunun dedicated distortion/robustness exit criterion'u **kapatıldı**.

---

## F-bar büyük-mesh performans baseline'ı

Benchmark executable:

`benchmark_v03_fbar_performance`

Kaynak:

`tests/benchmark_v03_fbar_performance.f90`

Politika:

- normal 37-test CTest correctness paketine dahil değildir,
- executable dört compiler hattında derlenir,
- gerçek performans ölçümü yalnız Linux/gfortran14 CI hattında çalışır,
- wall-clock süreleri **rapor amaçlıdır**, pass/fail eşiği değildir,
- solver yakınsaması ve artifact üretimi zorunludur,
- proses peak RSS `/usr/bin/time -v` ile ayrıca kaydedilir.

Dense backend için benchmarkın raporladığı analitik minimum matris çalışma-seti:

```text
K(ndof,ndof) + Kff(nfree,nfree) + Awork(nfree,nfree)
```

Bu değer stdlib/LAPACK iç workspace, allocator metadata ve diğer proses overhead'lerini içermez.

Resmi Linux/gfortran14 Debug CI baseline'ı:

| Cook mesh | Serbest denklem | Wall-clock | CPU | Bilinen dense matris alt sınırı |
|---:|---:|---:|---:|---:|
| 4x4 | 40 | 0.090 s | 0.090 s | 0.043 MiB |
| 8x8 | 144 | 0.375 s | 0.375 s | 0.517 MiB |
| 12x12 | 312 | 1.129 s | 1.129 s | 2.357 MiB |
| 16x16 | 544 | 3.242 s | 3.241 s | 7.064 MiB |

Tüm meshlerde:

```text
Newton iterations = 15
linear solves      = 15
minimum J          > 0
```

Benchmark prosesinin toplam peak RSS'i:

```text
11760 KiB ≈ 11.48 MiB
```

16x16 solve sonucu:

```text
tip_y = 0.0200139139424
final residual inf-norm ≈ 1.43e-9
minimum J ≈ 0.991933
```

Yorum:

- V0.3 dense backend için ilk tekrar üretilebilir süre/bellek baseline'ı artık CI artifactidir,
- sonuçlar runner donanımına bağlı olduğundan performans regresyonu için sabit süre eşiği konulmadı,
- analitik dense çalışma-seti mesh büyüdükçe hızlı artıyor; sparse backend gereksinimi ileriki büyük-model ölçeklenmesinde ölçülebilir hale geldi,
- bu madde ile V0.3 **wall-clock / bellek ölçüm altyapısı exit criterion'u kapatıldı**.

---

## Axisymmetric / torsion geçiş kuralı

ADR-0007 yalnız V0.3 **plane-strain** production baseline kararıdır.

Axisymmetric ve axisymmetric torsion / 2.5D için F-bar formulationı plane-strain kodundan doğrudan kopyalanmayacak. Yeniden türetilecek ve şu zincirle doğrulanacak:

```text
axisymmetric kinematics
→ hoop stretch
→ full J / J_bar
→ 2*pi*R reference-volume weighting
→ energy-consistent residual
→ analytic consistent tangent
→ FD tangent
→ patch/homogeneous benchmark
→ mesh refinement
→ independent external reference
→ product-level force/torque validation
```

F-bar Results pressure çıktısı bağımsız mixed pressure unknown olarak değil, constitutive/J tabanlı derived continuum pressure diagnostic olarak etiketlenecek.

---

## GitHub Actions bütçe engeli

Önceki runner-step öncesi failure'ların hesap/bütçe/provisioning katmanından kaynaklandığı doğrulandı. Bütçe açıldıktan sonra workflow'lar gerçek configure/build/CTest aşamasına ulaştı.

Bütçe sonrası ayrıştırılıp düzeltilen gerçek CI problemleri:

1. mixed testte Fortran `J/j` isim çakışması,
2. FEniCSx Cook Q2 için 5 kademeli load continuation gereksinimi,
3. DOLFINx v0.11 tek-nokta vector eval şekli uyumluluğu,
4. yeni F-bar distortion testinde yalnız test mesajına ait Fortran tek-tırnak sözdizimi hatası.

Dördüncü madde yalnız string mesajı düzeltilerek kapatıldı; benchmark fiziği ve toleransları değiştirilmedi.

---

## Güncel sıradaki V0.3 adımları

1. F-bar Results pressure semantiğini derived diagnostic olarak kod/contract seviyesinde netleştir.
2. PR #1 V0.3 exit criteria listesini son kez gözden geçir ve kalan maddeleri kapat.
3. V0.3 release hazırlığına geç.
4. Sonraki geliştirme dalgasında axisymmetric F-bar türetimini başlat.
5. Axisymmetric doğrulanmadan axisymmetric torsion / 2.5D production implementasyonuna geçme.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: V0.3 draft entegrasyon görünürlüğü; exit criteria öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
