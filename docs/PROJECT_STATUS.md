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

## 1. Production formulation kararı

ADR-0006 gereği formulation peşinen seçilmedi. V0.3 bake-off:

1. displacement-only Q4,
2. mixed Q4/P0 `u-p`,
3. F-bar Q4

adaylarını locking, dış referans doğruluğu, pressure stability, robustness, maliyet ve platform tekrar üretilebilirliği açısından karşılaştırdı.

ADR-0007 ile **F-bar Q4** plane-strain production default olarak seçildi.

Ana gerekçeler:

- displacement-only Q4 belirgin volumetric locking gösteriyor,
- mevcut Q4/P0 mixed pressure interpolation checkerboard null-mode riski taşıyor,
- F-bar dış Q2 referansa göre en düşük 8x8 displacement hatasını veriyor,
- F-bar bağımsız pressure DOF eklemiyor,
- residual energy-consistent, tangent analitik ve FD ile doğrulanmış,
- severe-distortion benchmarkı geçti,
- büyük-mesh süre/bellek baseline'ı CI artifacti olarak ölçülüyor,
- Results pressure semantiği artık kod seviyesinde açıkça tanımlı.

---

## 2. Resmi 38-test compiler matrix

Pressure-result contractı dahil doğrulanan code head:

`d2cad8642c20257e22f43cf147d6524a8c1bba6d`

| Platform | Configure | Build | 38 CTest | Benchmark artifacts |
|---|---|---|---|---|
| Windows 2022 / Intel ifx 2025.2 | ✅ | ✅ | ✅ | ✅ |
| Windows / gfortran 14 | ✅ | ✅ | ✅ | ✅ |
| macOS ARM64 / gfortran 14 | ✅ | ✅ | ✅ | ✅ |
| Linux / gfortran 14 | ✅ | ✅ | ✅ | ✅ |

Linux hattında büyük-mesh F-bar performans benchmarkı da geçti. ✅  
FEniCSx/DOLFINx V0.3 Cook Q2 dış referans workflow'u tekrar geçti. ✅

Platform numerical reproducibility:

```text
Cook maksimum bağıl fark  ≈ 3.65e-14
Sweep maksimum bağıl fark ≈ 1.39e-13
```

---

## 3. Resmi FEniCSx / DOLFINx Q2 dış referans

```text
DOLFINx = 0.11.0.post0
mu      = 1.0
lambda  = 1000.0
traction_y = 0.01
load steps = 5
```

| Q2 mesh | Tip displacement |
|---|---:|
| 2x2 | 0.0141286478615 |
| 4x4 | 0.0180747284976 |
| 8x8 | 0.0195456636855 |
| 16x16 | 0.0200264312978 |
| 32x32 | 0.0201973648361 |

```text
8 -> 16  = 2.400665%
16 -> 32 = 0.846316%
configured convergence-aday eşiği = 1.0%
```

32x32 FEniCSx ile bağımsız Q2/SciPy 32x32 precheck bağıl farkı ≈ `3.09e-8`.

---

## 4. Dış referansa göre 8x8 formulation doğruluğu

Referans:

```text
FEniCSx Q2 32x32 tip = 0.0201973648361
```

| Formulation | Dyna tip | Relative error | Equations | Newton / linear |
|---|---:|---:|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% | 144 | 10 / 10 |
| Mixed Q4/P0 | 0.01915555105 | 5.16% | 208 | 10 / 10 |
| F-bar Q4 | 0.01940548609 | **3.92%** | 144 | 15 / 15 |

---

## 5. Incompressibility sweep

Sabit 4x4 Cook mesh:

```text
lambda/mu = 10 -> 100 -> 1000
```

| lambda/mu | Displacement | Mixed | F-bar |
|---:|---:|---:|---:|
| 10 | 0.01326101 | 0.01841319 | 0.01911670 |
| 100 | 0.00744673 | 0.01702588 | 0.01768588 |
| 1000 | 0.00595658 | 0.01685744 | 0.01751507 |

Tip displacement kaybı:

```text
Displacement Q4 = 55.08%
Mixed Q4/P0     =  8.45%
F-bar Q4        =  8.38%
```

---

## 6. Mixed Q4/P0 pressure stability sonucu

CTest:

`benchmark.v0.3.mixed_up.checkerboard_null_mode`

```text
Checkerboard normalized coupling = 6.223551e-17
Probe normalized coupling        = 1.581139e-01
```

Mean-zero checkerboard pressure modu displacement divergence coupling'ine makine hassasiyeti seviyesinde kuplajsız kalıyor. Bu nedenle mevcut Q4/P0 mixed çift:

- araştırma/doğrulama için korunur,
- production default değildir,
- gelecekte independent pressure DOF gerekirse stabilizasyonlu veya inf-sup kararlı mixed formulation ayrı benchmark/ADR ile seçilir.

---

## 7. F-bar tangent ve severe-distortion robustness

Analitik consistent tangent:

```text
Python cross-FD  ≈ 8.73e-10
Python symmetry  ≈ 1.90e-16
GNU Fortran FD   ≈ 1.20e-9
GNU symmetry     ≈ 2.45e-16
```

Dedicated severe-distortion CTest:

`benchmark.v0.3.fbar.severe_distortion_affine`

Resmi macOS/gfortran sonucu:

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

Test dört platformda geçti. **Distortion/robustness exit criterion kapalıdır. ✅**

---

## 8. F-bar büyük-mesh performans baseline'ı

Executable:

`benchmark_v03_fbar_performance`

Politika:

- normal CTest correctness paketinden ayrıdır,
- tüm compiler hatlarında derlenir,
- gerçek süre/bellek ölçümü Linux/gfortran14 CI'da çalışır,
- wall-clock yalnız raporlanır; sabit pass/fail süre eşiği yoktur,
- solver yakınsaması ve artifact üretimi zorunludur.

Resmi Linux/gfortran14 Debug baseline'ı:

| Cook mesh | Serbest denklem | Wall-clock | CPU | Bilinen dense matris alt sınırı |
|---:|---:|---:|---:|---:|
| 4x4 | 40 | 0.090 s | 0.090 s | 0.043 MiB |
| 8x8 | 144 | 0.375 s | 0.375 s | 0.517 MiB |
| 12x12 | 312 | 1.129 s | 1.129 s | 2.357 MiB |
| 16x16 | 544 | 3.242 s | 3.241 s | 7.064 MiB |

Peak RSS:

```text
11760 KiB ≈ 11.48 MiB
```

**Wall-clock / bellek ölçüm altyapısı exit criterion kapalıdır. ✅**

---

## 9. Results pressure semantiği — tamamlandı

V0.3 Results contractı artık kinematik state ile constitutive state'i birbirinden ayırır.

`integration_point_result_t` içinde:

```text
F, J                         = gerçek kinematik state
constitutive_F, constitutive_J = malzeme modelinin gerçekten gördüğü state
pressure_value
pressure_source
pressure_measure
pressure_valid
```

Pressure scalar sözleşmesi:

```text
p_logJ = lambda * ln(constitutive_J)
```

Bu değer **`-tr(sigma)/3` hidrostatik Cauchy basıncı değildir**; `ln(J)` ile eşlenik volumetric constitutive scalar'dır.

Kaynak ayrımı:

```text
DES_PRESSURE_SOURCE_DERIVED_CONSTITUTIVE
DES_PRESSURE_SOURCE_INDEPENDENT_UNKNOWN
```

Standart displacement Q4:

```text
constitutive_F = F
constitutive_J = J
p_logJ         = lambda*ln(J)
source         = DERIVED_CONSTITUTIVE
```

F-bar Q4:

```text
F, J           = local gerçek Gauss kinematiği
constitutive_F = F_bar
constitutive_J = J_bar
p_logJ         = lambda*ln(J_bar)
source         = DERIVED_CONSTITUTIVE
```

Mixed formulation için çözülen pressure unknown aynı scalar measure altında fakat:

```text
source = INDEPENDENT_UNKNOWN
```

olarak etiketlenir.

Solver-level F-bar integration results yalnız **başarıyla yakınsamış final state** için üretilir.

Yeni CTest:

`benchmark.v0.3.fbar.pressure_result_contract`

Non-affine resmi macOS/gfortran sonucu:

```text
F-bar local J range        = 4.272392e-02
F-bar J vs constitutive J = 2.136196e-02
F-bar J_bar               = 1.149200e+00
Derived p_logJ            = 2.642255e+00
```

Test gerçek `J_g != J_bar` ayrımını zorlar ve source/measure contractını doğrular.

**F-bar Results pressure-semantics exit criterion kapalıdır. ✅**

---

## 10. Axisymmetric / torsion geçiş kuralı

ADR-0007 yalnız V0.3 **plane-strain** production baseline kararıdır.

Axisymmetric ve axisymmetric torsion / 2.5D için F-bar doğrudan kopyalanmayacak; yeniden türetilecek ve şu zincirle doğrulanacaktır:

```text
axisymmetric kinematics
→ hoop stretch
→ full J / J_bar
→ 2*pi*R reference-volume weighting
→ energy-consistent residual
→ analytic consistent tangent
→ FD tangent
→ homogeneous/patch benchmark
→ mesh refinement
→ independent external reference
→ product-level force/torque validation
```

---

## 11. GitHub Actions bütçe engeli — kapandı

Bütçe açıldıktan sonra runner step'leri normal çalışmaya başladı. Gerçek CI seviyesinde ayrıştırılıp düzeltilen başlıca konular:

1. mixed test `J/j` Fortran isim çakışması,
2. FEniCSx Q2 load continuation,
3. DOLFINx v0.11 tek-nokta vector eval uyumluluğu,
4. severe-distortion test mesajındaki tek-tırnak sözdizimi.

Solver fiziği tolerans gevşetilerek kurtarılmadı.

---

## 12. Güncel sıradaki V0.3 adımları

Ana teknik exit criteria artık kapalıdır:

- formulation bake-off ✅
- production ADR ✅
- 4-platform compiler matrix ✅
- platform numerical reproducibility ✅
- FEniCSx dış referans ✅
- incompressibility sweep ✅
- mixed checkerboard risk kararı ✅
- F-bar severe-distortion robustness ✅
- wall-clock / bellek baseline altyapısı ✅
- Results pressure semantics ✅

Kalan işler artık **release hazırlığı / final entegrasyon kontrolü** seviyesindedir:

1. PR #1 değişiklik listesini ve güncel CI head'ini son kez denetle.
2. README / status / ADR / release notlarının birbirleriyle tutarlı olduğunu kontrol et.
3. V0.3 release checklist ve release branch/tag hazırlığını oluştur.
4. Bu kontroller tamamlanmadan PR #1'i merge etme.
5. V0.3 kapandıktan sonra sonraki geliştirme dalgasında axisymmetric F-bar türetimine geç.

## Branch kuralı

- `main`: doğrulanmış ana hat + sürekli kayıtlar
- `release/v0.2`: geri dönülebilir V0.2.0
- `develop/v0.3`: aktif V0.3.0
- PR #1: open / draft; final release kontrolü öncesi merge yok
- `Sistem-ve-Mimari`: kullanıcı ayrıca istemedikçe güncellenmez
