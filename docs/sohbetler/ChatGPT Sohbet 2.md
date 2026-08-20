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
