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

Kullanıcı açıkça istemeden PR #1 merge edilmeyecek, `release/v0.3` oluşturulmayacak, `v0.3.0` tag atılmayacak ve GitHub Release oluşturulmayacaktır.

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
