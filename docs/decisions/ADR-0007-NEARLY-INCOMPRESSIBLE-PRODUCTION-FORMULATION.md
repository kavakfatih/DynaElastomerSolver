# ADR-0007 — Nearly-Incompressible Production Formulation: F-bar Q4

**Durum:** Kabul edildi  
**Tarih:** 2026-08-18  
**Kapsam:** V0.3 plane-strain production baseline

## Bağlam

ADR-0006 gereği DynaElastomerSolver'ın nearly-incompressible production eleman formulasyonu peşinen seçilmedi. V0.3 içinde aynı fizik, aynı Cook geometrisi, aynı yük ve aynı ölçüm sözleşmesi altında üç aday karşılaştırıldı:

1. displacement-only Q4,
2. mixed Q4/P0 `u-p`,
3. F-bar Q4.

Karar; locking, dış referansa göre doğruluk, pressure stability, nonlinear convergence, lineer sistem maliyeti, platform tekrar üretilebilirliği ve axisymmetric/torsion genişletme riski birlikte değerlendirilerek verilir.

## Karar

### 1. V0.3 plane-strain production nearly-incompressible formulasyonu F-bar Q4'tür

Dyna'nın V0.3 plane-strain nearly-incompressible ana production yolu:

```text
Q4 displacement
+ finite-strain F-bar volumetric correction
+ energy-consistent residual
+ analytic consistent tangent
```

olarak sabitlenir.

Bu karar F-bar'ı tüm gelecek problem sınıfları için otomatik olarak kabul etmez. Axisymmetric ve axisymmetric torsion / 2.5D implementasyonları kendi kinematikleri ve hacim integralleri ile yeniden türetilecek ve ayrı doğrulanacaktır.

### 2. Displacement-only Q4 production nearly-incompressible yolundan çıkarılır

Displacement-only Q4 kodu:

- compressible/baseline karşılaştırması,
- regression,
- doğrulama,
- locking demonstrasyonu

amacıyla korunur; nearly-incompressible production elemanı olarak kullanılmaz.

### 3. Mevcut mixed Q4/P0 production yolundan çıkarılır, deneysel/doğrulama yolu olarak korunur

Mixed Q4/P0 implementasyonu silinmez. Aşağıdaki amaçlarla korunur:

- formulation karşılaştırması,
- pressure diagnostics geliştirmesi,
- mixed solver bloklarının doğrulanması,
- gelecekteki stabil mixed eleman ailesi için araştırma altyapısı.

Ancak mevcut Q4/P0 pressure uzayı, düzenli quadrilateral mesh üzerinde mean-zero checkerboard pressure modunu serbest displacement alanına pratik olarak kuplamayan bir `K_up` modu üretmektedir. Bu nedenle mevcut Q4/P0 çifti **as-is production-safe kabul edilmez**.

Gelecekte bağımsız pressure DOF zorunlu hale gelirse stabilizasyonlu veya inf-sup kararlı farklı bir mixed interpolation ayrı benchmark ve ayrı ADR ile seçilir.

## Kanıt özeti

### Dış Q2 referans

Resmi dış referans:

```text
FEniCSx / DOLFINx 0.11.0.post0
Q2 32x32 Cook tip = 0.0201973648361
16x16 -> 32x32 tip değişimi = 0.846316%
convergence-aday eşiği = 1.0%
```

Dyna 8x8 sonuçları:

| Formulation | Tip displacement | Q2 32x32 relative error |
|---|---:|---:|
| Displacement Q4 | 0.00656452664 | 67.50% |
| Mixed Q4/P0 | 0.01915555105 | 5.16% |
| F-bar Q4 | 0.01940548609 | **3.92%** |

F-bar mevcut external-reference displacement ölçütünde en doğru adaydır.

### Incompressibility sweep

Sabit 4x4 Cook mesh, `lambda/mu = 10 -> 1000` tip displacement kaybı:

| Formulation | Tip kaybı |
|---|---:|
| Displacement Q4 | 55.08% |
| Mixed Q4/P0 | 8.45% |
| F-bar Q4 | **8.38%** |

Displacement-only Q4 belirgin volumetric locking gösterir. Mixed ve F-bar bu yapay rijitleşmeyi büyük ölçüde azaltır.

### Mixed Q4/P0 checkerboard / pressure-space riski

Regression/decision testi:

`benchmark.v0.3.mixed_up.checkerboard_null_mode`

Düzenli 4x4 Q4 mesh, mean-zero pressure modları:

```text
checkerboard normalized K_up coupling = 6.223551e-17
mean-zero probe normalized coupling    = 1.581139e-01
```

Kontrol modu displacement alanına açık biçimde kuple olurken checkerboard modu makine hassasiyeti düzeyinde kuplajsızdır. Bu, yalnız smooth Cook pressure roughness trendiyle görülemeyen bir pressure-space stability riskidir.

Mixed enerji içinde `K_pp ~ -1/lambda` regularizasyonu bulunduğundan sonlu `lambda` için tam global tangent null mode ifadesi kullanılmaz; kararın temel noktası, incompressible limite gidildikçe kaybolan `K_pp` karşısında divergence coupling bloğunda checkerboard modunun asymptotik olarak kontrolsüz kalmasıdır.

### Lineer sistem ve nonlinear maliyet

8x8 Cook:

| Formulation | Equations | Newton / linear solve |
|---|---:|---:|
| Displacement Q4 | 144 | 10 / 10 |
| Mixed Q4/P0 | 208 | 10 / 10 |
| F-bar Q4 | 144 | 15 / 15 |

F-bar bu benchmarkta mixed'den daha fazla Newton iterasyonu gerektirir; buna karşılık bağımsız pressure DOF eklemez ve mixed'e göre equation count yaklaşık %30.8 daha düşüktür (`144/208`). Başka ifadeyle mixed sistem F-bar'dan yaklaşık %44.4 daha fazla equation taşır.

Bu tablo tek başına wall-clock performans kararı değildir. Sparse solver ve daha büyük meshler geldiğinde gerçek süre/bellek profili ayrıca ölçülecektir.

### Tangent ve platform doğrulaması

F-bar analitik consistent tangent:

```text
Python cross-FD  ≈ 8.73e-10
Python symmetry  ≈ 1.90e-16
GNU Fortran FD   ≈ 1.20e-9
GNU symmetry     ≈ 2.45e-16
```

V0.3 resmi 36-test compiler matrix:

- Windows 2022 / Intel ifx 2025.2 ✅
- Windows / gfortran 14 ✅
- macOS ARM64 / gfortran 14 ✅
- Linux / gfortran 14 ✅

Platform Cook sonuçlarında gözlenen maksimum bağıl fark yaklaşık `3.65e-14` seviyesindedir.

## Axisymmetric ve axisymmetric torsion / 2.5D sonucu

F-bar seçiminin plane-strain implementasyonu axisymmetric koda kopyalanmayacaktır.

Axisymmetric genişletmede en az şu noktalar yeniden türetilecektir:

- tam 3D axisymmetric deformation gradient,
- hoop stretch,
- `J` ve `J_bar`,
- reference-volume ağırlığı (`2*pi*R` etkisi),
- F-bar varyasyonları ve consistent tangent,
- reaction force / torque sözleşmesi.

Axisymmetric torsion / 2.5D için circumferential displacement bileşeni eklendiğinde `F`, `J`, F-bar dönüşümü ve tangent yeniden doğrulanacaktır.

Her yeni formulation:

```text
material/element FD
→ patch/homogeneous test
→ mesh refinement
→ independent external reference
→ product-level torque/angle validation
```

zincirinden geçmeden production kabul edilmez.

## Pressure sonuç semantiği

F-bar displacement-only formulation bağımsız bir pressure unknown çözmez.

Bu nedenle Results katmanında gösterilecek pressure:

- constitutive response / `J` üzerinden türetilmiş continuum pressure diagnostic olarak etiketlenir,
- mixed solver pressure DOF'u gibi sunulmaz,
- element/gauss-point provenance bilgisi korunur.

Bağımsız pressure unknown gerektiren future true-incompressibility veya pressure-primary workflow'ları için stabil mixed formulation ayrı geliştirme konusudur.

## Sonuçlar ve trade-off'lar

### Kazanımlar

- V0.3 için en iyi mevcut external-reference displacement doğruluğu,
- displacement-only Q4'e göre güçlü locking azaltımı,
- mixed Q4/P0 checkerboard pressure-space riskinden kaçınma,
- bağımsız pressure DOF olmadan daha küçük global sistem,
- doğrulanmış energy-consistent residual ve analytic consistent tangent,
- mevcut constitutive Material Core ile doğrudan çalışma.

### Kabul edilen maliyetler

- Cook benchmarkında mixed'e göre daha fazla Newton iterasyonu,
- F-bar element seviyesinde Gauss noktaları arası volumetric coupling ve daha karmaşık tangent,
- bağımsız pressure DOF bulunmaması,
- axisymmetric / torsion genişletmelerinin ayrı derivation ve validation gerektirmesi.

## Supersede edilen varsayım

`docs/architecture/SOLVER_ARCHITECTURE.md` içindeki mixed `u-p` production formulationının peşinen birinci sınıf gereksinim kabul edildiğini belirten ifade, ADR-0006'nın kanıtla seçim ilkesi ve bu ADR'nin V0.3 benchmark kararı karşısında production implementation açısından supersede edilmiştir.

Bu ADR, gelecekte stabil bir mixed formulation geliştirilmesini yasaklamaz; yalnız mevcut Q4/P0 çiftinin production default olmasını reddeder.

## Son karar

```text
V0.3 plane-strain nearly-incompressible production default = F-bar Q4
Displacement-only Q4 = baseline / regression
Mixed Q4/P0 = experimental / verification; production değil
```

V0.3'ün bundan sonraki geliştirmesi F-bar production yolunu sağlamlaştırmaya ve axisymmetric geçiş öncesi kalan robustness doğrulamalarını tamamlamaya odaklanır.
