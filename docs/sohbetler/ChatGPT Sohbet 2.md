# ChatGPT Sohbet 2

**Proje:** DynaElastomerSolver  
**Devam kaydı:** `docs/sohbetler/ChatGPT Sohbet 1.md` sonrasıdır.  
**Tarih:** 2026-08-19  

---

## 1. B4 stateful sparse solver context kapanış kaydı

B4 paketi tamamlandı ve `develop/v0.3` üzerinde doğrulandı.

Doğrulanmış B4 geliştirme head'i:

```text
develop/v0.3 = 31da56082c4a590bb7c526aa78187bdbc6836acf
```

B4 ile sparse çözüm yaşam döngüsü vendor-bağımsız context arkasına alındı:

```text
create/context
→ analyze_pattern()
→ reorder()
→ factorize()/numeric-ready
→ solve()
→ iterative_refinement()
→ reuse()
→ diagnostics()
→ release()
```

Q9/P1 fixed ve adaptive sparse Newton yolları stateful solver context kullanmaktadır. Sparsity pattern değişmediğinde symbolic analysis ve reorder yalnız bir kez yapılır; Newton iterasyonlarında numeric değerler güncellenir.

Korunan önemli gerçeklik sözleşmeleri:

- mevcut CSR GMRES backend sparse-direct değildir,
- direct factorization yapılmış gibi raporlanmaz,
- dense stdlib/LAPACK reference/fallback korunur,
- int64 metadata sözleşmesi hazırlanmıştır fakat mevcut GMRES köprüsünde gerçek int64 backend desteği henüz yoktur,
- mixed `u-P` fully-incompressible saddle-point problem SPD kabul edilmez.

Final B4 CI doğrulaması:

```text
Fortran CI #342 = SUCCESS
Linux / gfortran 14                 = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14               = PASS
Windows / Intel ifx 2025.2          = PASS
CTest                               = 74/74 PASS
H3 LEVEL 2 acceptance               = PASS
```

Aynı final head üzerinde FEniCSx mixed reference, fully-incompressible mixed reference, mixed quadrature diagnostic, Cook Q2 reference, Legal/Public IP Guard ve Full Git History Secret Audit workflow'ları da başarılıdır.

Commercial LEVEL 3 hâlâ açıktır; ANSYS/Marc benchmark sonuçları ve production sparse-direct kanıtı olmadan ticari parity ilan edilmez.

---

## 2. B5 sparse-direct backend ADR çalışma başlangıcı

Kullanıcı `Devam edelim` diyerek B5 paketine geçilmesini onayladı.

B5 teknik araştırması ve yeni ADR yazımı başlamadan önce bu sohbet kaydı oluşturuldu.

Başlangıçta doğrulanan PR durumu:

```text
PR #1                     = open
draft                     = true
merged                    = false
mergeable                 = true
PR head                   = 31da56082c4a590bb7c526aa78187bdbc6836acf
```

B5 amacı henüz production backend kodu eklemek değildir. Önce resmi kaynaklarla sparse-direct backend kararı verilecektir.

Karşılaştırılacak ana adaylar:

```text
MUMPS
PETSc + MUMPS
oneMKL PARDISO
```

Gerekirse güçlü alternatifler de karar matrisine eklenecektir.

Zorunlu değerlendirme kriterleri:

- symmetric-indefinite / saddle-point çözüm desteği,
- pivoting ve 2x2 pivot davranışı,
- symbolic analysis / ordering reuse,
- numeric refactorization reuse,
- iterative refinement,
- singularity / rank / pivot diagnostics,
- 64-bit index desteği,
- shared-memory ve MPI ölçeklenebilirlik,
- out-of-core veya memory-control seçenekleri,
- Modern Fortran/C interoperability,
- Windows x64 desteği,
- Linux x64 desteği,
- native macOS Apple Silicon ARM64 desteği,
- bağımlılık ve build karmaşıklığı,
- lisans, redistribution ve proprietary/source-available Dyna ile uyumluluk,
- vendor lock-in riski,
- ANSYS/Marc seviyesine yaklaşma açısından teknik yeterlilik.

Ürün mimarisi hedefi değişmemektedir:

```text
Q9/P1 FEM / Newton
        │
        ▼
Dyna CSR
        │
        ▼
Stateful Solver Context
        │
        ├── Dense LAPACK reference
        ├── Portable CSR GMRES bootstrap
        ├── Production sparse-direct backend
        └── Optional optimized backends
```

MacBook desteği zorunlu ürün şartıdır. B5 kararı `macOS Apple Silicon ARM64` desteğini ikincil veya opsiyonel saymayacaktır.

B5 çıktısı:

```text
resmi-kaynak karşılaştırma matrisi
→ önerilen primary sparse-direct backend
→ önerilen optional optimized backend(ler)
→ lisans/dağıtım kararı
→ ADR
→ B6 entegrasyon kapsamı
```

Kullanıcı açıkça istemeden PR #1 merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 3. B5 kararı ve B6 production MUMPS kapanış özeti

B5 ADR sonucunda primary production sparse-direct backend olarak **MUMPS 5.9.x** seçildi. oneMKL PARDISO teknik olarak güçlü olmakla birlikte güncel macOS desteği olmadığı için Windows/Linux optional optimized backend yönünde bırakıldı. PETSc + MUMPS future HPC/distributed seçenek olarak tutuldu.

B6 ile gerçek MUMPS backend'i eklendi:

```text
Dyna CSR
→ SparseSolverContext
→ ISO_C_BINDING
→ Dyna MUMPS C adapter
→ MUMPS analyze / factorize / solve
```

MUMPS backend'i sahte sparse veya dense wrapper değildir; gerçek symbolic analysis, numeric factorization ve direct solve yaşam döngüsünü kullanır. Q9/P1 fixed ve adaptive Newton sparse yolları aynı stateful context üzerinden MUMPS ile çalışabilir.

B6 kabulünde:

- finite-compliance mixed `u-P`,
- fully-incompressible `cp=0`,
- dense↔MUMPS displacement/pressure/residual parity,
- fixed Newton,
- adaptive Newton,
- cutback/rollback,
- symbolic pattern reuse,
- direct factorization lifecycle,
- native macOS Apple Silicon ARM64,
- Linux/gfortran,
- Windows/gfortran,
- Windows/Intel ifx

kapıları başarılı şekilde doğrulandı.

---

## 4. B7a AUTO sparse policy kapanış kaydı

B7a final head'i:

```text
dedd56416bd77542400b821420f3580ba89a1250
```

2026-08-20 canlı GitHub doğrulamasında aynı head için bütün platform status'ları SUCCESS oldu:

```text
Normal Fortran / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS Direct / MUMPS-enabled
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS
```

B7a ile `AUTO` sparse policy, requested/selected backend diagnostics ve MUMPS yoksa portable GMRES fallback davranışı eklendi. Explicit MUMPS backend yolu korunmaktadır.

---

## 5. 2026-08-20 production sparse-direct zorunlu ürün kararı — B7b başlangıcı

Kullanıcı açık şekilde şu ürün kararını verdi:

> DynaElastomerSolver gerçek, birinci sınıf sparse-direct solver içermelidir. ANSYS ve Marc yaklaşımına benzer şekilde production nonlinear mixed `u-P` çözüm yolunda direct sparse solver ana seçeneklerden biri olmalıdır. MacBook / native Apple Silicon desteği korunmalıdır.

Bu karar bundan sonraki solver geliştirmesinde zorunlu mimari gereksinimdir.

B7b hedefi:

```text
AUTO                → mixed u-P / symmetric-indefinite için MUMPS Direct öncelikli
MUMPS_DIRECT        → explicit production sparse-direct; unavailable ise fail-fast
CSR_GMRES           → explicit iterative alternatif / controlled fallback
DENSE_REFERENCE     → yalnız reference, küçük problem ve regression amacı
```

Kritik davranış sözleşmesi:

- kullanıcı `MUMPS_DIRECT` seçerse sessiz GMRES fallback YOK,
- MUMPS unavailable ise explicit unsupported-backend error,
- AUTO için seçilen backend ve fallback nedeni diagnostics'te görünür,
- mixed `u-P` symmetric-indefinite problem production policy'sinde sparse-direct öncelikli olur,
- pattern aynıysa symbolic analysis/ordering reuse edilir,
- her Newton tangent güncellemesinde numeric refactorization yapılır,
- factorization/solve failure nonlinear cutback politikasına taşınabilir,
- macOS Apple Silicon ARM64 production destek matrisi zorunlu kalır.

ANSYS/Marc ile hedeflenen mimari seviye ile **commercial parity iddiası birbirinden ayrılır**. Gerçek ANSYS PLANE183 ve Hexagon Marc benchmarkları B12'de aynı geometri/mesh/material/load/BC/formulation ile yapılmadan `ANSYS/Marc LEVEL 3 parity` ilan edilmeyecektir.

Bu turda önce B7a'nın açık kalan CI işi kapatıldı; ardından B7b production sparse-direct geliştirmesi başlayacaktır.

PR #1 draft/open kalacaktır. Kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 6. 2026-08-20 B7b 8/8 SUCCESS checkpoint ve production-default düzeltme turu

Yeni geliştirme turuna başlamadan önce canlı GitHub durumu yeniden doğrulandı.

Başlangıç checkpoint'i:

```text
PR #1                     = open
draft                     = true
merged                    = false
mergeable                 = false
PR head                   = 37c3a234c786e3970529f496ddfa5238532c2fa0
```

Aynı head için combined CI status doğrulaması:

```text
Normal Fortran / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS Direct / MUMPS-enabled
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

B7b henüz kapatılmayacaktır. Canlı kod/handoff incelemesinde kalan kritik production-default problemi şudur:

```text
src/fortran/solvers/des_q9_plane_strain_herrmann_force_solver.f90
```

Q9/P1 fixed ve adaptive solver yolları caller `linear_settings` vermediğinde generic `linear_solver_settings_t()` default'unu kullanmaktadır. Generic default geriye uyumluluk için dense reference kalabilse de Q9/P1 production solver'ın no-settings davranışının dense olması istenmemektedir.

Bu turdaki acceptance hedefi:

```text
Q9/P1 no-settings
→ production_linear_solver_settings()
→ requested backend = AUTO
→ MUMPS-enabled build: selected = MUMPS DIRECT
→ MUMPS-disabled build: selected = CSR GMRES + MUMPS_UNAVAILABLE fallback
```

Caller explicit seçim verirse davranış korunacaktır:

```text
if (present(linear_settings)) active_linear_settings = linear_settings
```

Dense reference testleri explicit dense seçmeli; GMRES/MUMPS parity testleri explicit backend kullanmalı; yalnız production-default regression settings vermeden çalışmalıdır.

Adaptive direct factorization/solve failure davranışı ayrıca rollback → cutback → retry zincirinde doğrulanacak; unsupported backend ise physics failure gibi tekrarlı cutback'e çevrilmeden fail-fast kalacaktır.

Production build/preset tarafında MUMPS'ın explicit `ON` olduğu doğrulanmadan B7b kapanmış sayılmayacaktır.

Kullanıcı açıkça istemeden PR #1 merge edilmeyecek, `release/v0.3` oluşturulmayacak, `v0.3.0` tag atılmayacak ve GitHub Release oluşturulmayacaktır.

---

## 7. 2026-08-20 B7b production sparse-direct final kapanış kaydı

B7b çalışma paketi küçük alt adımlara bölünerek canlı GitHub üzerinden tekrar doğrulandı ve final acceptance head'i aşağıdaki seviyeye ulaştı:

```text
develop/v0.3 = 64148feec2c98743b7ecabd7111c4decc629ef14
```

Final PR durumu:

```text
PR #1       = open
draft       = true
merged      = false
mergeable   = false
head branch = develop/v0.3
```

Kapanan kritik production-default problemi:

```text
Q9/P1 fixed/adaptive no-settings
→ production_linear_solver_settings()
→ requested backend = AUTO
```

Build policy sonucu:

```text
MUMPS-enabled production build
→ selected backend = MUMPS DIRECT
→ direct_factorization_performed = true
→ fallback = false

MUMPS-disabled development build
→ selected backend = CSR GMRES
→ fallback_used = true
→ fallback_reason = MUMPS_UNAVAILABLE
```

Explicit caller backend seçimi korunmaktadır. Explicit `MUMPS_DIRECT` isteği MUMPS unavailable build'de sessiz GMRES fallback yapmaz; `DES_ERROR_UNSUPPORTED_LINEAR_BACKEND` ile fail-fast davranışı regression ile korunur.

Reference/production test intent ayrımı netleştirildi:

- dense reference testleri explicit `DES_LINEAR_BACKEND_STDLIB_DENSE` kullanır,
- GMRES parity testleri explicit GMRES kullanır,
- MUMPS parity testleri explicit MUMPS kullanır,
- production-default regression settings vermeden AUTO policy'yi zorlar.

`tests/test_auto_sparse_solver_policy.f90` Q9/P1 fixed ve adaptive no-settings davranışını iki build profilinde de doğrular. Ayrıca MUMPS unavailable durumda explicit MUMPS isteğinin nonlinear cutback döngüsüne girmeden fail-fast kaldığını kontrol eder.

Direct failure → nonlinear rollback/cutback zinciri için dedicated regression eklendi:

```text
tests/test_q9_herrmann_mumps_failure_cutback.f90
```

Bu test gerçek rank-deficient mixed sistem ile MUMPS numeric factorization failure üretir ve şu sözleşmeyi doğrular:

```text
factorization failure
→ DES_ERROR_LINEAR_SOLVE
→ trial u/p revert
→ cutback
→ retry
→ max_cutbacks+1 denemeden sonra CUTBACK_EXHAUSTED
→ commit_count = 0
→ revert_count = max_cutbacks + 1
→ committed u/p bozulmaz
```

Production/development build profilleri ayrıştırıldı:

```text
CMakePresets.json

dyna-development-minimal
→ DES_ENABLE_MUMPS=OFF

dyna-production
→ DES_ENABLE_MUMPS=ON
```

MUMPS Direct CI artık `dyna-production` preset'ini kullanır ve production sparse-direct context, AUTO/Q9 default policy, fixed/adaptive MUMPS parity ve MUMPS failure→cutback regression testlerini çalıştırır.

Final combined CI status, `64148feec2c98743b7ecabd7111c4decc629ef14` üzerinde:

```text
NORMAL / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS DIRECT / production preset
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

GitHub Actions run kimlikleri:

```text
Normal Fortran CI = 32348462977
MUMPS Direct CI   = 32348463043
```

B7b acceptance sonucu:

```text
B7b = PASS
```

Bu PASS commercial ANSYS/Marc parity anlamına gelmez. Commercial LEVEL 3/B12 gerçek ANSYS PLANE183 ve Hexagon Marc benchmarkları yapılana kadar OPEN kalır.

Sonraki paket B8 nonlinear robustness'tır; bu kapanış turunda B8 teknik implementasyonuna başlanmamıştır.

Kullanıcı açıkça istemeden PR #1 merge edilmedi, `release/v0.3` oluşturulmadı, `v0.3.0` tag atılmadı ve GitHub Release oluşturulmadı.

---

## 8. 2026-08-20 B8.1 nonlinear robustness başlangıç checkpoint'i

Kullanıcı geliştirmeye devam edilmesini onayladı. Yeni teknik tura başlamadan önce canlı GitHub durumu doğrulandı ve bu kayıt kod değişikliğinden önce eklendi.

Başlangıç durumu:

```text
PR #1       = open
draft       = true
merged      = false
mergeable   = false
head branch = develop/v0.3
head SHA    = 5d2bb5d2e4a0816a3624b5e86f644e976e985e18
```

B8 paketi tek seferde büyütülmeyecektir. Kullanıcının çalışma kuralına uygun olarak küçük, kapanabilir alt paketlerle ilerlenir.

Bu tur yalnızca **B8.1 nonlinear Newton robustness foundation** kapsamındadır. Öncelik sırası:

```text
1. mixed u-P Newton correction için controlled damping / backtracking line-search altyapısı
2. residual growth / açık divergence tespiti
3. gerekli solver diagnostics ve regression testleri
```

B8.1 kabul ilkeleri:

- displacement ve pressure Newton increment'leri aynı line-search katsayısı ile ölçeklenecek,
- trial residual değerlendirmesi committed state'i bozmayacak,
- alpha=1 yeterince iyi ise full Newton davranışı korunacak,
- backtracking yalnız gerektiğinde devreye girecek,
- line-search başarısızlığı kontrollü nonlinear failure olarak adaptive cutback zincirine taşınabilecek,
- residual-growth/divergence tespiti deterministic ve ayarlanabilir olacak,
- mevcut dense / GMRES / MUMPS backend davranışı bozulmayacak,
- NaN/Inf guard, adaptive increment büyütme ve predictor bu alt pakete karıştırılmayacak; sonraki B8 alt paketlerinde ele alınacak.

Bu checkpoint commercial ANSYS/Marc parity iddiası değildir. B12/LEVEL 3 açık kalır.

Kullanıcı açıkça istemeden PR #1 merge edilmeyecek, `release/v0.3`, `v0.3.0` tag atılmayacak ve GitHub Release oluşturulmayacaktır.

---

## 9. 2026-08-20 B8.1 final kapanış ve B8.2 başlangıç checkpoint'i

B8.1 final teknik head'i:

```text
develop/v0.3 = 74bf35256ae353d85a225f77f1f11fabd503bfad
```

B8.1 ile Q9/P1 adaptive mixed `u-P` Newton yoluna controlled damping/backtracking line-search ve residual-growth/divergence detection altyapısı eklendi. Displacement ve pressure correction aynı `alpha` ile ölçeklenir; `alpha=1` yeterli olduğunda Full Newton korunur. Line-search başarısızlığı ve nonlinear divergence kontrollü solver error olarak rollback → cutback zincirine taşınabilir.

Convergence history tarafında correction scale ve line-search trial diagnostics korunur. Production report wrapper nonlinear settings'i dış API'ye taşır. Policy regression ve Q9 convergence-history regression testleri eklendi. MUMPS Direct CI path filtresi B8 nonlinear dosyalarını kapsayacak şekilde güncellendi ve robustness testleri production MUMPS presetinde de çalıştırılmaktadır.

Final CI doğrulaması, aynı `74bf35256ae353d85a225f77f1f11fabd503bfad` SHA üzerinde:

```text
NORMAL / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS DIRECT / production preset
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

GitHub Actions run kimlikleri:

```text
Normal Fortran CI = 32356579972
MUMPS Direct CI   = 32356580007
```

B8.1 acceptance sonucu:

```text
B8.1 = PASS
```

Bu geliştirme turunda sıradaki küçük paket **B8.2 — NaN/Inf rejection + cutback diagnostics** olarak sınırlandırılmıştır. B8.2'nin amacı:

```text
1. nonlinear residual / correction / trial state üzerinde non-finite değerleri erken yakalamak
2. NaN/Inf durumunu deterministic solver error'a dönüştürmek
3. adaptive solver'da rollback → cutback/retry davranışını açık şekilde raporlamak
4. convergence/cutback diagnostics içinde son failure nedeni ve non-finite olayını görünür kılmak
5. dedicated regression testleriyle committed displacement/pressure state'in bozulmadığını kanıtlamak
```

B8.2 kapsamına adaptive increment growth/shrink optimizasyonu ve predictor alınmayacaktır; bunlar ayrı alt paketlerde ele alınacaktır.

PR #1 `open + draft` kalacaktır. Kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır. Commercial ANSYS/Marc LEVEL 3/B12 parity hâlâ OPEN'dır.

---

## 10. 2026-08-20 B8.2 CI failure recovery checkpoint

Kullanıcı geliştirme akışının CI doğrulaması beklenirken yarıda kalmamasını ve sürümün zarar görmeden ilerlemesini istedi. Bu nedenle recovery turunda canlı GitHub durumu ve başarısız job logları doğrudan incelendi; teknik düzeltmeden önce bu checkpoint kaydedildi.

Canlı recovery başlangıcı:

```text
PR #1       = open
draft       = true
merged      = false
mergeable   = false
head branch = develop/v0.3
head SHA    = b10a7b1c496d16ff5a9f5f9fb4f6c3c35e450a4f
```

Aynı head üzerindeki CI sonucu:

```text
Normal Fortran CI = 32359317836  → 4/4 FAILURE
MUMPS Direct CI   = 32359317942  → 4/4 FAILURE
Toplam                               8/8 FAILURE
```

Kök neden solver numeriği veya mixed `u-P` formulation değildir. Bütün platformlar yeni regression testini derlerken aynı Fortran string sözdizimi hatasında durmuştur:

```text
tests/test_q9_herrmann_nonfinite_guard.f90
```

Türkçe hata mesajındaki `state'i` ifadesi tek tırnakla açılmış Fortran stringini erken kapatmıştır. Solver çekirdeği bu test compile noktasına kadar derlenmiştir; ortak failure bir test-source syntax problemidir.

Recovery sözleşmesi:

```text
1. yalnız hatalı test stringi düzeltilecek
2. live develop/v0.3 head her write öncesi yeniden doğrulanacak
3. yeni head için normal + MUMPS CI takip edilecek
4. CI pending iken statik kaynak incelemesi ve mümkün olan yerel build/test doğrulaması sürdürülecek
5. yeni failure varsa log açılıp aynı B8.2 paketi içinde kök neden düzeltilecek
6. yalnız final 8/8 SUCCESS sonrası B8.2 = PASS yazılacak
```

Bu recovery turunda PR #1 merge edilmeyecek, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır. Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır.

---

## 11. 2026-08-20 B8.2 final kapanış ve B8.3 adaptive increment başlangıç checkpoint'i

B8.2 final teknik head'i:

```text
develop/v0.3 = da3f7a75b75313e0384fdd12c999f2fe678d71a4
```

Recovery sonrası test-string sözdizimi düzeltildi ve non-finite policy katmanı ayrıca sağlamlaştırıldı. B8.2 final kapsamı:

- `DES_ERROR_NONFINITE_NONLINEAR = -307`,
- residual, Newton correction ve trial displacement/pressure state üzerinde NaN/Inf rejection,
- nonlinear settings içinde non-finite gerçek sayıların reddi,
- line-search merit ve residual-growth helper girdilerinde non-finite koruması,
- doğrudan non-finite input için fail-fast/no-cutback,
- Newton sırasında üretilen non-finite değer için rollback → cutback/retry,
- committed mixed `u-P` state'in korunması,
- convergence history içinde `cutback_index` ve non-finite stage tanısı,
- production report içinde `nonfinite_event_count` ve `last_nonfinite_stage`,
- MUMPS failure/cutback regression ile cutback sırasının korunması.

Bağımsız GNU Fortran 14 doğrulamalarında nonlinear IEEE/policy katmanı ve yeni status-message yolu başarıyla derlenip çalıştırıldı.

Final CI, aynı `da3f7a75b75313e0384fdd12c999f2fe678d71a4` SHA üzerinde:

```text
NORMAL / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS DIRECT / production preset
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

GitHub Actions run kimlikleri:

```text
Normal Fortran CI = 32369907212
MUMPS Direct CI   = 32369907178
```

B8.2 acceptance sonucu:

```text
B8.2 = PASS
```

Bu kayıtla yeni küçük paket **B8.3 — adaptive increment growth/shrink policy** başlatılmıştır. Mevcut başarısızlık davranışı korunacaktır:

```text
failure
→ rollback
→ step = step * cutback_factor
→ retry
```

B8.3 yalnız commit edilmiş başarılı increment sonrasında kontrollü büyütme ekleyecektir. Güvenlik sözleşmesi:

```text
growth default = disabled
explicit enable gerekir
başarılı ve kolay Newton increment'i → growth adayı
aynı increment içinde cutback olmuşsa → growth yok
iteration threshold aşılmışsa → growth yok
next step <= configured maximum increment
next step <= remaining load
load factor 1.0 overshoot yok
rollback / mixed u-P transaction değişmez
predictor bu pakete dahil değildir
```

B8.3 için ayrı `adaptive_increment_settings_t` policy tipi tercih edilecektir; nonlinear line-search settings ile kavramsal olarak karıştırılmayacaktır. Existing caller API geriye uyumlu kalacak şekilde yeni optional argümanlar sonda eklenecektir.

Acceptance testleri en az şunları kapsayacaktır:

- default-disabled davranışın mevcut increment dizisini koruması,
- explicit enabled easy-convergence growth,
- cutback sonrası no-growth,
- iteration threshold no-growth,
- maximum/remaining-load cap,
- final load factor = 1,
- dense/GMRES/MUMPS mevcut regressions'ın bozulmaması,
- yeni policy + integration testinin production MUMPS CI içinde de çalışması.

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 12. 2026-08-20 B8.3 final kapanış ve B8.4 predictor başlangıç checkpoint'i

B8.3 final teknik head'i:

```text
develop/v0.3 = 03571d94c7061ba3466ffdbab9b7a5a8cd5cb161
```

B8.3 ile adaptive Q9/P1 mixed `u-P` production yoluna commit-sonrası kontrollü increment growth policy eklendi. Ayrı `adaptive_increment_settings_t` tipi kullanıldı; growth varsayılan olarak kapalı bırakılarak mevcut caller davranışı korundu.

Final B8.3 sözleşmesi:

```text
başarılı mixed u-P commit
→ iteration threshold uygunsa
→ aynı increment içinde cutback yoksa
→ configured growth factor uygula
→ maximum increment cap uygula
→ remaining-load cap uygula
→ load factor 1.0 overshoot etme
```

Rollback/cutback yolu değiştirilmedi:

```text
failure
→ displacement + pressure revert
→ step = step * cutback_factor
→ retry
```

Production report API'sine growth event sayısı ve maksimum kabul edilen increment tanıları taşındı. Policy unit regression ve gerçek Q9/P1 adaptive integration regression eklendi; growth açık/kapalı final mixed state parity ve final load-factor sözleşmesi korunmaktadır. Yeni testler MUMPS production CI robustness kapısına da alındı.

Final CI, aynı `03571d94c7061ba3466ffdbab9b7a5a8cd5cb161` SHA üzerinde:

```text
NORMAL / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS DIRECT / production preset
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

GitHub Actions run kimlikleri:

```text
Normal Fortran CI = 32373137069
MUMPS Direct CI   = 32373137067
```

B8.3 acceptance sonucu:

```text
B8.3 = PASS
```

Bu kayıtla yeni küçük paket **B8.4 — committed-state secant predictor foundation** başlatılmıştır.

B8.4 kapsamı:

```text
predictor default = disabled
explicit enable gerekir
predictor yalnız iki converged committed mixed state mevcutsa çalışır
u ve p aynı load-step ratio ile birlikte extrapolate edilir
predictor yalnız trial state'e uygulanır; committed state doğrudan değişmez
cutback/retry denemesinde predictor tekrar uygulanmaz
predictor scale configured upper bound ile sınırlandırılır
non-finite predictor adayı reddedilir
predictor başarısızlığı mevcut rollback/cutback zincirini bozamaz
existing API yeni optional argümanlar sonda eklenerek geriye uyumlu kalır
```

B8.4 acceptance testleri en az şunları kapsayacaktır:

- default-disabled no-op,
- history yetersizken predictor no-op,
- aynı scale ile coupled `u-p` secant extrapolation,
- predictor scale cap,
- non-finite predictor input rejection,
- gerçek Q9/P1 adaptive çözümde predictor event oluşması ve final state parity,
- rollback/cutback transaction'ın bozulmaması,
- normal + production MUMPS CI kapılarının korunması.

B8.4 yalnız predictor foundation kapsamındadır; arc-length/Riks, trust-region veya farklı continuation yöntemleri bu pakete alınmayacaktır.

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 13. 2026-08-20 B8.4 final kapanış ve B9.1 performance/scaling baseline başlangıç checkpoint'i

B8.4 final teknik head'i:

```text
develop/v0.3 = 06e7e056d52cfd30b8529184504d4a74fb8058bd
```

B8.4 ile adaptive Q9/P1 mixed `u-P` production yoluna committed-state secant predictor foundation eklendi. Predictor varsayılan olarak kapalıdır; yalnız explicit enable ve iki başarılı committed mixed state mevcut olduğunda trial state için kullanılır. Displacement ve pressure aynı load-step ratio ile birlikte extrapolate edilir; committed state doğrudan değiştirilmez. Cutback retry'de predictor devre dışı kalır ve non-finite predictor state/step girdileri reddedilir.

Production report API'sine predictor event sayısı ve maksimum predictor scale tanıları taşındı. Policy unit regression ve gerçek Q9/P1 predictor integration regression eklendi. Predictor açık/kapalı final displacement, pressure ve residual parity sözleşmesi korunur.

Final CI, aynı `06e7e056d52cfd30b8529184504d4a74fb8058bd` SHA üzerinde:

```text
NORMAL / MUMPS-off
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS DIRECT / production preset
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                   = 8/8 SUCCESS
```

GitHub Actions run kimlikleri:

```text
Normal Fortran CI = 32378352842
MUMPS Direct CI   = 32378352800
```

B8.4 acceptance sonucu:

```text
B8.4 = PASS
```

Bu kayıtla B8 nonlinear robustness paketi kapatılmış ve yeni küçük paket **B9.1 — Q9/P1 production performance/scaling baseline** başlatılmıştır.

B9.1 kapsamı yalnız ölçüm ve raporlama foundation'ıdır; bu alt pakette agresif optimizasyon yapılmayacaktır. İlk hedefler:

```text
1. Q9/P1 mixed problem boyutunu (node/element/u/p/total DOF) görünür raporlamak
2. CSR nonzero sayısı ve sparsity yoğunluğunu kaydetmek
3. nonlinear increment/Newton ve linear solve sayaçlarını aynı benchmark kaydında toplamak
4. wall-clock total solve süresini ve mümkünse assembly/linear-solve ana fazlarını ölçmek
5. küçükten büyüğe deterministik mesh seviyeleriyle scaling baseline üretmek
6. MUMPS production ve portable sparse yolunu aynı fizik probleminde karşılaştırılabilir metadata ile raporlamak
7. timing sonuçlarını correctness gate'e dönüştürmemek; CI donanım gürültüsü nedeniyle katı süre threshold'u koymamak
8. benchmark executable'ını normal CTest correctness paketinden ayrı tutmak
```

B9.1 kabulünde solver formulation, B8 nonlinear transaction semantics ve backend seçim politikası değiştirilmeyecektir. Ölçüm katmanı production sonuçlarını değiştirmemeli; aynı benchmark probleminin final mixed state/residual doğruluğu mevcut regression sözleşmeleriyle korunmalıdır.

B9.1 sonrasında performans verisine göre B9.2 optimizasyon hedefleri seçilecektir; ölçüm yapılmadan speculative optimization yapılmayacaktır.

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 14. 2026-08-20 B9.1 final kapanış ve B9.2 başlangıç checkpoint'i

B9.1 final acceptance head'i:

```text
develop/v0.3 = afd34bbfa320e49dfbe7a92b5bf7353a8df635d0
```

Canlı GitHub doğrulamasında PR #1 durumu:

```text
state       = open
draft       = true
merged      = false
head branch = develop/v0.3
```

B9.1 measurement-only sözleşmesi tamamlandı. Q9/P1 benchmark katmanı solver formulation, nonlinear transaction semantics ve backend selection policy'sini değiştirmeden deterministik scaling verisi üretmektedir.

Normal CI final sonucu:

```text
Normal Fortran CI = 32384923935
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS
```

Production MUMPS CI final sonucu:

```text
MUMPS Direct CI = 32384923939
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS
```

İlk Linux/MUMPS job'u `96477292005`, Fortran toolchain indirme/provisioning aşamasındaki transient timeout nedeniyle kod build/test aşamasına ulaşmadan başarısız oldu. Solver kodunda düzeltme yapılmadı. Yalnız başarısız Linux job'u aynı acceptance SHA üzerinde yeniden çalıştırıldı; retry job'u `96484352673` toolchain, LAPACK, MUMPS production configure/build, production regressions ve B9 same-runner performance baseline adımlarının tamamında SUCCESS oldu.

Toplam kabul matrisi:

```text
Normal  = 4/4 SUCCESS
MUMPS   = 4/4 SUCCESS
Toplam  = 8/8 SUCCESS
```

Linux/gfortran normal benchmark artifact'ından ölçülen portable CSR GMRES baseline'ı:

```text
Mesh      Free eq.   Wall time (s)   Peak RSS (KiB)   Newton   Linear solve
Q9 1x1          15        0.004711             4416        4              4
Q9 2x2          52        0.028486             4876        4              4
Q9 3x3         111        1.246115             4876        8              8
Q9 4x4         192       11.000924             4876        8              8
```

Bütün dört mesh başarılı solve status'u üretmiştir. MUMPS CI Linux retry'sinde aynı runner üzerinde MUMPS ve GMRES benchmark JSON üretim adımı SUCCESS olmuştur. CI logunda kalıcı olarak yayımlanmayan MUMPS sayısal timing değerleri bu kayıtta uydurulmamıştır; yalnız doğrulanmış step sonucu kaydedilmiştir.

B9.1 acceptance sonucu:

```text
B9.1 = PASS
```

Bu kayıtla yeni küçük paket **B9.2 — ölçüme dayalı production performance optimization** başlatılmıştır. B9.2'de önce canlı kaynak üzerinde GMRES/MUMPS/assembly zaman maliyetinin hangi kod yolunda oluştuğu incelenecek; optimizasyon hedefi ancak bu source-level profiling incelemesinden sonra daraltılacaktır. B9.1 ölçümleri, özellikle 111 ve 192 serbest denklem seviyelerinde portable GMRES wall-time büyümesini araştırma önceliği yapmaktadır; ancak kaynak kanıtı olmadan belirli bir optimizasyon tekniği peşinen seçilmeyecektir.

B9.2 güvenlik sözleşmesi:

- mixed `u-P` formulation değişmeyecek,
- production AUTO→MUMPS Direct önceliği değişmeyecek,
- explicit GMRES portable alternatif olarak korunacak,
- dense reference yolu korunacak,
- correctness threshold'ları performans uğruna gevşetilmeyecek,
- B8 rollback/cutback/growth/predictor transaction semantics değişmeyecek,
- değişiklik küçük ve ayrı kabul edilebilir paket olacak,
- optimizasyon öncesi ve sonrası aynı benchmark ile ölçülecek,
- native macOS Apple Silicon, Linux ve Windows compiler matrisi korunacak.

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 15. 2026-08-20 B9.2 GMRES row-equilibration doğrulama checkpoint'i

Yeni geliştirme turu başında canlı GitHub durumu yeniden doğrulandı:

```text
PR #1       = open
draft       = true
merged      = false
mergeable   = false
head branch = develop/v0.3
head SHA    = 95c783f9e40814a9e6d74171ce03e811253da198
```

B9.2'nin ilk dar teknik adayı, portable CSR GMRES yolunda mixed `u-P` saddle-point sistem için **satır bazlı equation equilibration** olarak uygulanmıştır. Değişiklik yalnız:

```text
src/fortran/solvers/des_linear_solver.f90
```

dosyasında tutulmuştur. Mixed formulation, Q9/P1 assembly, nonlinear transaction, MUMPS Direct backend ve AUTO production policy değiştirilmemiştir.

Kullanılan lineer dönüşüm:

```text
D * A * x = D * b
```

burada her satır için `D_ii`, o satırdaki en büyük mutlak katsayının tersi olarak seçilir; sayısal olarak sıfır/boş satır değişmeden bırakılır. Bu yaklaşım, fully-incompressible `cp=0` limitinde pressure diagonal bloklarının sıfır olabilmesi nedeniyle sıradan diagonal/Jacobi preconditioner'a bağımlı değildir.

Pinned stdlib kaynağı ayrıca incelendi. Kullanılan stdlib GMRES sürümünde built-in Jacobi preconditioner diagonal üzerinden çalışmakta ve sıfır diagonal girdilerde inverse diagonal üretmemektedir. Bu nedenle fully-incompressible mixed `u-P` için Jacobi, genel production seçimi olarak kullanılmamıştır.

Doğruluk sözleşmesi korunmuştur: GMRES ölçeklenmiş sistemi çözse de final kabul hâlâ orijinal sistem residual'i ile yapılır:

```text
||A*x - b||_inf
```

Correctness tolerance gevşetilmemiştir.

İlk aday SHA:

```text
95c783f9e40814a9e6d74171ce03e811253da198
```

Aynı SHA üzerinde canlı combined status'ta normal compiler matrisi kapanmıştır:

```text
Normal Fortran CI = 32391481483
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS
```

MUMPS Direct custom status context'leri bu checkpoint anında henüz yayımlanmamıştır. Bu nedenle B9.2 **PASS değildir**.

B9.2 kapanış için aynı teknik davranış üzerinde şu kapılar zorunludur:

```text
1. production MUMPS 4/4 SUCCESS
2. normal 4/4 SUCCESS korunması
3. B9.1 ile aynı Linux/gfortran benchmark runner'ında GMRES 1x1..4x4 yeniden ölçümü
4. özellikle 3x3 ve 4x4 seviyelerinde gerçek wall-time etkisinin kaydedilmesi
5. final displacement / pressure / residual correctness'in korunması
6. performans kazancı yoksa veya regression varsa row-equilibration production optimizasyonu olarak kabul edilmeyecek
```

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.

---

## 16. 2026-08-20 B9.2 final kapanış ve B9.3 faz-zamanlama başlangıç checkpoint'i

B9.2 final teknik head'i:

```text
95c783f9e40814a9e6d74171ce03e811253da198
```

Final CI aynı teknik SHA üzerinde kapanmıştır:

```text
Normal Fortran CI = 32391481483
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

MUMPS Direct CI = 32391481350
Linux / gfortran 14                     = PASS
macOS Apple Silicon ARM64 / gfortran 14 = PASS
Windows / gfortran 14                   = PASS
Windows / Intel ifx 2025.2              = PASS

Toplam                                  = 8/8 SUCCESS
```

Normal Linux/gfortran artifact'ında row-equilibration sonrası portable CSR GMRES ölçümleri:

```text
Mesh      Free eq.   B9.1 wall(s)   B9.2 wall(s)   Değişim
Q9 1x1          15       0.004711       0.004780     +%1.5
Q9 2x2          52       0.028486       0.030167     +%5.9
Q9 3x3         111       1.246115       0.811191     -%34.9
Q9 4x4         192      11.000924       3.029243     -%72.5
```

Küçük vakalarda runner/timing gürültüsü seviyesinde hafif artış varken, B9.1'de darboğaz olarak belirlenen 3x3 ve 4x4 vakalarında belirgin iyileşme vardır. 3x3 yaklaşık 1.54x, 4x4 yaklaşık 3.63x hızlanmıştır. Benchmark timing sonuçları report-only kalır; katı wall-clock pass/fail threshold'u eklenmemiştir.

MUMPS production Linux job artifact'ında aynı runner üzerinde GMRES ve MUMPS karşılaştırması da başarıyla üretilmiştir. 4x4 vaka için:

```text
GMRES wall = 0.874241 s
MUMPS wall = 0.005339 s
MUMPS/GMRES wall ratio = 0.006107
```

Bu timing oranı correctness gate değildir; production AUTO→MUMPS Direct önceliğini destekleyen performans kanıtı olarak kaydedilir.

Aynı-runner correctness karşılaştırmasında maksimum farklar:

```text
max tip-y relative gap    = 8.448152123001485e-09
max minimum-J relative gap = 8.901110489039245e-11
acceptance limit           = 5e-6
```

Dolayısıyla GMRES row-equilibration final mixed state doğruluğunu bozmadı. Normal Linux CTest paketi 81/81 PASS olmuş; fully-incompressible Q9/P1, sparse CSR GMRES indefinite, adaptive increment/predictor ve production acceptance regressions başarıyla çalışmıştır. Original-system residual acceptance korunur; correctness toleransları gevşetilmemiştir.

B9.2 acceptance sonucu:

```text
B9.2 = PASS
```

Bu kayıtla yeni küçük paket **B9.3 — Q9/P1 phase-level performance instrumentation** başlatılmıştır. B9.3'ün amacı yeni bir optimizasyon tekniği eklemek değil, B9.1/B9.2 toplam süre ölçümünü ana fazlara ayırarak sonraki optimizasyon hedefini kanıtla seçmektir.

B9.3 kapsamı:

```text
1. assembly süresini görünür ölçmek
2. linear solver toplam süresini görünür ölçmek
3. mümkünse linear analyze/reorder/factorize/solve alt fazlarını backend-neutral diagnostics ile ayırmak
4. GMRES ve MUMPS benchmark JSON'una aynı faz alanlarını eklemek
5. timing alanlarını report-only tutmak; correctness threshold yapmamak
6. mevcut solver formulation ve numerical policy'yi değiştirmemek
7. normal + MUMPS 8/8 compiler matrisi ile doğrulamak
```

B9.3'te mixed `u-P` formulation, row-equilibration, production AUTO→MUMPS policy, nonlinear rollback/cutback/growth/predictor semantics ve correctness toleransları değiştirilmeyecektir. Faz ölçümü solver sonucunu etkilememeli ve native macOS Apple Silicon/Linux/Windows desteği korunmalıdır.

Commercial ANSYS/Marc LEVEL 3/B12 parity OPEN kalır. PR #1 `open + draft` kalacaktır; kullanıcı açıkça istemeden merge, `release/v0.3`, `v0.3.0` tag veya GitHub Release oluşturulmayacaktır.
