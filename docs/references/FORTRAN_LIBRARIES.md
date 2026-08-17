# DynaElastomerSolver — Açık Kaynak Fortran Kütüphaneleri

**Son araştırma:** 2026-08-17  
**Amaç:** DynaElastomerSolver geliştirmesinde kullanılacak, aday olarak değerlendirilecek veya kaynak-kod referansı olarak incelenecek açık kaynak Fortran kütüphanelerini tek yerde izlemek.

> Bu dosya yaşayan bir dependency/referans kaydıdır. Bir kütüphane gerçekten kullanılmaya başlandığında durum, sürüm/commit, kullanım noktası ve lisans bilgisi güncellenir.

## 1. Aktif kullanılan kütüphane

### Fortran Standard Library — `stdlib`

**Durum:** ZORUNLU / AKTİF KULLANIM  
**Dyna için repo:** https://github.com/kavakfatih/stdlib  
**Upstream:** https://github.com/fortran-lang/stdlib  
**Lisans:** MIT; iç BLAS/LAPACK backend kodlarının ilgili bölümleri modified BSD koşullarını da taşır.  
**Kullanılan fork sürümü:** `0.8.1`  
**Pinlenen commit:** `9a15c7772f1a76a6c497b9f3abb793841fc81f74`

Dyna build sistemi bu commit'i `FetchContent` ile doğrudan `kavakfatih/stdlib` deposundan alır. Branch adına floating dependency kullanılmaz.

### Şu anki gerçek kullanım

```text
Dyna des_dense_linear
        ↓
stdlib_linalg::solve
        ↓
LAPACK *GESV backend
```

Eski elle yazılmış Gaussian-elimination test çözücüsü kaldırılmış ve Dyna'nın küçük/dense doğrulama yolu `stdlib_linalg` üzerine taşınmıştır.

### Dyna için ayrıca değerlendirilecek stdlib bölümleri

- `stdlib_sparse`
  - COO
  - CSR
  - CSC
  - sparse format dönüşümleri
- `stdlib_linalg_iterative_solvers`
  - CG
  - PCG
  - BiCGSTAB
  - GMRES
- `stdlib_linalg`
  - LU
  - SVD
  - least-squares
  - eigen/linear algebra yardımcıları
- `stdlib_quadrature`
- `stdlib_stats`
- `stdlib_logger`
- `stdlib_error` / state türleri
- sorting / string / hashmap yardımcıları

### Build notu

`stdlib` kaynak üretiminde `fypp` kullanır. Bu nedenle Dyna configure aşamasında `fypp` bulunmasını zorunlu olarak kontrol eder.

---

## 2. Sayısal lineer cebir altyapısı

### Reference LAPACK / BLAS

**Durum:** STDLIB ÜZERİNDEN BACKEND / DOĞRUDAN API İKİNCİL  
**Repo:** https://github.com/Reference-LAPACK/lapack  
**Lisans:** modified BSD

Kullanım alanları:
- dense linear solve
- LU/Cholesky
- eigenvalue
- SVD
- least squares
- material calibration yardımcı cebiri

Politika:
- Mümkün olduğunda Dyna kodu doğrudan legacy LAPACK isimlerine bağlanmak yerine `stdlib_linalg` katmanını kullanır.
- Platformda optimize BLAS/LAPACK varsa stdlib external backend üzerinden bunlardan yararlanılabilir.
- Küçük doğrulama problemlerinde stdlib/reference backend yeterlidir.

### MUMPS

**Durum:** PRODUCTION SPARSE DIRECT SOLVER ADAYI — PLANLANAN  
**Resmi kaynak/indirme:** https://www.mumps-solver.org/  
**Resmi dokümantasyon:** https://www.mumps-solver.org/index.php?page=doc  
**Üçüncü taraf build harness repo:** https://github.com/coin-or-tools/ThirdParty-Mumps  
**Güncel incelenen sürüm:** 5.9.1 (Temmuz 2026)  
**Lisans:** CeCILL-C; bazı bileşenlerde ayrıca BSD/PORD koşulları bulunur.

MUMPS'in resmi ana dağıtımı canonical bir GitHub repository üzerinden yayınlanmıyor. Bu nedenle yukarıdaki resmi proje sayfası kaynak otoritesi olarak kabul edilir; üçüncü taraf repo yalnız build/packaging referansıdır.

Dyna için hedef kullanım:
- büyük sparse Newton tangent sistemleri
- symmetric/unsymmetric sistemler
- ileride mixed `u-p` saddle-point sistemleri
- factorization/solve diagnostics

MUMPS doğrudan FEM'e gömülmeyecek; `ILinearSolver` benzeri Dyna adapter sınırı arkasında tutulacaktır.

---

## 3. Material calibration / nonlinear parameter fitting

### Modernized MINPACK

**Durum:** GÜÇLÜ ADAY — V0.7 MATERIAL CALIBRATION  
**Repo:** https://github.com/fortran-lang/minpack  
**Dokümantasyon:** https://fortran-lang.github.io/minpack/  
**Lisans:** permissive BSD-style

Önemli kullanım:
- nonlinear least squares
- Levenberg–Marquardt
- analytic veya finite-difference Jacobian
- material model parameter fitting

Dyna Material Calibration motorunda LM tabanlı ilk güvenilir optimizer için en güçlü adaylardan biridir.

### NLESolver-Fortran

**Durum:** KAYNAK-KOD / ALGORİTMA REFERANSI; ŞİMDİLİK DEPENDENCY DEĞİL  
**Repo:** https://github.com/jacobwilliams/nlesolver-fortran  
**Lisans:** BSD-3-Clause

İncelenecek konular:
- Newton-Raphson organizasyonu
- Broyden / quasi-Newton
- nonlinear equation solver diagnostics

Dyna FEM Newton solver'ı ürünün ana fikri mülkiyet/uzmanlık alanıdır; bu nedenle generic nonlinear solver kütüphanesine devredilmeyecek. Kaynak kod yalnız algoritmik ve test tasarımı referansı olarak kullanılacaktır.

---

## 4. Veri / ResultDatabase adayları

### HDF5

**Durum:** GÜÇLÜ ADAY — RESULTS / CHECKPOINT / BÜYÜK VERİ  
**Repo:** https://github.com/HDFGroup/hdf5  
**Dokümantasyon:** https://support.hdfgroup.org/documentation/hdf5/latest/  
**Fortran desteği:** resmi repository içinde Fortran binding/library bulunur.

Dyna için olası kullanım:
- `ResultDatabase`
- integration-point büyük veri blokları
- nodal sonuçlar
- increment/history verileri
- restart/checkpoint
- büyük analiz dosyaları

V0.2'de dependency olarak eklenmez. Önce ham integration-point result modeli netleştirilir.

### JSON-Fortran

**Durum:** ADAY — KÜÇÜK METADATA / CONFIG / EXPORT  
**Repo:** https://github.com/jacobwilliams/json-fortran  
**Lisans:** BSD-style / BSD-3-Clause

Dyna için olası kullanım:
- project metadata
- solver settings
- material metadata/provenance
- küçük insan-okunabilir veri değişimi

Büyük FEM result alanlarının ana saklama formatı olarak JSON kullanılmayacaktır.

---

## 5. Test altyapısı

### test-drive

**Durum:** ADAY; MEVCUT CTEST YAPISI YETERLİ OLDUĞU SÜRECE EKLENMEYECEK  
**Repo:** https://github.com/fortran-lang/test-drive  
**Lisans:** MIT veya Apache-2.0

Mevcut bağımsız Fortran executable + CTest yaklaşımı küçük test setinde açık ve yeterlidir. Test sayısı/bakım maliyeti belirgin biçimde arttığında `test-drive` yeniden değerlendirilecektir.

---

## 6. Gelecek dinamik analizler

### fortran-lang/fftpack

**Durum:** GELECEK ARAŞTIRMA — V1.0 DIŞI  
**Repo:** https://github.com/fortran-lang/fftpack  
**Dokümantasyon:** https://fortran-lang.github.io/fftpack/

Olası kullanım:
- harmonic/spectral post-processing
- frekans alanı yardımcı hesapları
- gelecekte viskoelastik/dinamik analiz araçları

Quasi-static V1.0 için dependency yapılmayacaktır.

---

## 7. FEM kaynak-kod referansı

### FrontISTR

**Durum:** KAYNAK-KOD / MİMARİ REFERANSI; DOĞRUDAN DEPENDENCY DEĞİL  
**Repo:** https://github.com/FrontISTR/FrontISTR  
**Aktif upstream:** https://gitlab.com/FrontISTR-Commons/FrontISTR  
**Lisans:** MIT

İncelenecek alanlar:
- modern/industrial Fortran FEM organizasyonu
- large deformation/nonlinear structural analysis
- sparse matrix assembly
- MUMPS wrapper/integration
- iterative/direct solver seçimleri
- parallel solver altyapısı

FrontISTR'ın fizik implementasyonu Dyna'ya doğrudan taşınmayacak; ancak permissive lisansı nedeniyle belirli altyapı yaklaşımlarından yararlanılması gerekirse kaynak ve commit açıkça kaydedilecektir.

---

## 8. Dyna açık kaynak kullanım kuralları

1. **Bilimsel çekirdek bize aittir.** Hyperelastic constitutive law, FEM formulation, incompressibility strategy, axisymmetric torsion ve nonlinear solution policy Dyna tarafından geliştirilir.
2. Öncelik kaynak kod kopyalamak değil, iyi tanımlı library API'leri kullanmaktır.
3. Bir açık kaynak implementasyondan anlamlı kod/algoritma uyarlanırsa kaynak repo, dosya/algoritma, commit ve lisans kayıt altına alınır.
4. MIT/BSD/Apache gibi permissive kaynaklar tercih edilir.
5. GPL/AGPL gibi güçlü copyleft kaynaklardan Dyna çekirdeğine doğrudan kod kopyalanmaz; yalnız bilimsel/algoritmik referans olarak incelenebilir.
6. Weak-copyleft veya özel lisanslı dependency'ler (ör. MUMPS/CeCILL-C) ürün dağıtımından önce ayrıca lisans değerlendirmesinden geçirilir.
7. Harici kütüphane native Dyna domain/FEM tiplerini belirlememelidir; adapter sınırı arkasında tutulmalıdır.
8. Kritik dependency'ler branch adına değil doğrulanmış sürüm/tag/commit'e sabitlenir.
9. Dependency yükseltmesi normal kod değişikliği gibi benchmark ve regression testlerinden geçmeden kabul edilmez.

## 9. Öncelik sırası

```text
Şimdi
├── kavakfatih/stdlib        ← aktif
│   └── stdlib_linalg::solve ← aktif ilk kullanım
│
V0.3 hazırlığı
├── stdlib_sparse            ← değerlendir
└── stdlib GMRES             ← benchmark/referans

Büyük sparse sistem aşaması
└── MUMPS                    ← production direct solver adayı

Material Calibration
└── MINPACK                  ← LM / nonlinear least-squares adayı

Results büyüdüğünde
├── HDF5                     ← büyük bilimsel veri
└── JSON-Fortran             ← metadata/config

Gelecek dynamics
└── FFTPACK
```
