# DynaElastomerSolver — Açık Kaynak Fortran Kütüphaneleri

**Son araştırma:** 2026-08-18  
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

**Durum:** AKTİF OLARAK STDLIB ARKASINDA KULLANILIYOR / DOĞRUDAN API İKİNCİL  
**Repo:** https://github.com/Reference-LAPACK/lapack  
**Lisans:** modified BSD

LAPACK; lineer sistem, least-squares, eigenvalue, singular value decomposition ve matris factorization problemleri için temel referans Fortran kütüphanesidir. Kendi referans BLAS uygulamasını da içerir.

Dyna kullanım alanları:
- dense linear solve
- LU / Cholesky
- eigenvalue
- SVD
- least squares
- material calibration yardımcı cebiri
- test/verification lineer sistemleri

Politika:
- Dyna kodu mümkün olduğunda doğrudan legacy LAPACK isimlerine bağlanmak yerine `stdlib_linalg` katmanını kullanır.
- Platformda optimize BLAS/LAPACK varsa stdlib external backend üzerinden bunlardan yararlanılabilir.
- macOS'ta Accelerate, Intel/Windows tarafında MKL ve diğer optimize BLAS/LAPACK seçenekleri ileride benchmark edilebilir.
- Reference LAPACK kaynak kodu algoritmik doğrulama ve backend davranışı için temel referanstır.

### MUMPS

**Durum:** PRODUCTION SPARSE DIRECT SOLVER ADAYI — PLANLANAN  
**Resmi kaynak/indirme:** https://www.mumps-solver.org/  
**Resmi dokümantasyon:** https://www.mumps-solver.org/index.php?page=doc  
**Üçüncü taraf build harness repo:** https://github.com/coin-or-tools/ThirdParty-Mumps  
**İncelenen sürüm:** 5.9.1 (Temmuz 2026)  
**Lisans:** CeCILL-C; bazı bileşenlerde ayrıca BSD/PORD koşulları bulunur.

MUMPS'in resmi ana dağıtımı canonical bir GitHub repository üzerinden yayınlanmıyor. Bu nedenle resmi proje sayfası kaynak otoritesi olarak kabul edilir; üçüncü taraf repo yalnız build/packaging referansıdır.

Dyna için hedef kullanım:
- büyük sparse Newton tangent sistemleri
- symmetric/unsymmetric sistemler
- ileride mixed `u-p` saddle-point sistemleri
- factorization/solve diagnostics

MUMPS doğrudan FEM'e gömülmeyecek; Dyna linear-solver adapter sınırı arkasında tutulacaktır.

---

## 3. Material calibration / nonlinear parameter fitting

### Modernized MINPACK

**Durum:** GÜÇLÜ ADAY — V0.7 MATERIAL CALIBRATION  
**Repo:** https://github.com/fortran-lang/minpack  
**Dokümantasyon:** https://fortran-lang.github.io/minpack/  
**Lisans:** permissive BSD-style

MINPACK nonlinear equations ve nonlinear least-squares problemlerini çözer. Analitik Jacobian verilen veya fonksiyon değerlendirmelerinden Jacobian üreten yolları vardır.

Dyna için kullanım:
- Levenberg–Marquardt tabanlı nonlinear least-squares
- Neo-Hookean / Mooney-Rivlin / Yeoh / Ogden parametre fit'i
- analitik veya finite-difference Jacobian
- yüksek sayıda deneysel veri noktasına least-squares fit
- optimizer sonrası residual/RMSE minimizasyonu

**Önemli mimari not:** MINPACK klasik LM yolu doğal olarak bound-constrained optimizer değildir. Pozitiflik/fiziksel sınırlar gerekiyorsa parametre dönüşümleri kullanılabilir veya PRIMA ile bounded başlangıç çözümü bulunup MINPACK ile hassas yerel refinement yapılabilir.

### PRIMA — Powell yöntemlerinin modern referans implementasyonu

**Durum:** GÜÇLÜ ADAY — V0.7 MATERIAL CALIBRATION / DERIVATIVE-FREE OPTIMIZATION  
**Repo:** https://github.com/libprima/prima  
**Proje:** http://libprima.net  
**Lisans:** BSD-3-Clause  
**Dil:** Modern Fortran ana implementasyonu; ayrıca C/Python/MATLAB/Julia arayüzleri bulunur.

PRIMA, türev kullanmadan genel nonlinear optimization için Powell yöntemlerinin modern ve yoğun biçimde test edilmiş referans implementasyonudur.

Sağlanan temel yöntemler:
- `UOBYQA` — unconstrained
- `NEWUOA` — unconstrained
- `BOBYQA` — bound-constrained
- `LINCOA` — linearly constrained
- `COBYLA` — nonlinear constrained

Dyna için özellikle değerlidir çünkü elastomer calibration problemlerinde:
- objective fonksiyonun analitik türevi her zaman kolay değildir,
- Ogden gibi modeller başlangıç parametrelerine hassas olabilir,
- fiziksel parameter bounds gerekebilir,
- başarısız/uygunsuz material state'ler objective içinde ceza gerektirebilir.

Planlanan kullanım:
- `BOBYQA`: bounded parameter fit için ilk güçlü aday
- `COBYLA`: fiziksel inequality constraint gereken fitler için aday
- `NEWUOA`: unconstrained türevsiz başlangıç çözümü gereken deneyler için aday

PRIMA bir global optimizer değildir. Dyna içinde rolü; türevsiz ve kısıtlı güvenilir arama / başlangıç çözümü üretmek olacaktır.

### Önerilen calibration optimizer zinciri

```text
Experimental Data
        ↓
PCHIP preprocessing / resampling
        ↓
Objective + physical admissibility
        ↓
PRIMA BOBYQA / COBYLA
bounded veya constrained initial fit
        ↓
MINPACK Levenberg–Marquardt
local least-squares refinement
        ↓
Material validation
        ↓
parameter set + provenance
```

Bu zincir zorunlu tek akış değildir; model ve veri setine göre optimizer seçimi değişebilir. Ancak MINPACK + PRIMA birbirini tamamlayan iki ana calibration motoru adayı olarak tutulacaktır.

### NLESolver-Fortran

**Durum:** KAYNAK-KOD / ALGORİTMA REFERANSI; ŞİMDİLİK DEPENDENCY DEĞİL  
**Repo:** https://github.com/jacobwilliams/nlesolver-fortran  
**Lisans:** BSD-3-Clause

İncelenecek konular:
- Newton-Raphson organizasyonu
- Broyden / quasi-Newton
- nonlinear equation solver diagnostics

Dyna FEM Newton solver'ı ürünün ana uzmanlık alanıdır; bu nedenle generic nonlinear solver kütüphanesine devredilmeyecek. Kaynak kod yalnız algoritmik ve test tasarımı referansı olarak kullanılacaktır.

---

## 4. Deneysel veri hazırlama / interpolation

### PCHIP — Piecewise Cubic Hermite Interpolation

**Durum:** GÜÇLÜ ADAY — V0.7 MATERIAL DATA / CALIBRATION PREPROCESSING  
**Repo:** https://github.com/jacobwilliams/PCHIP  
**Dokümantasyon:** https://jacobwilliams.github.io/PCHIP/  
**Lisans:** BSD-3-Clause koşullarına karşılık gelen permissive lisans; ayrıca SLATEC kaynaklı public-domain kod bildirimi içerir.

PCHIP, SLATEC PCHIP'in modern Fortran güncellemesidir. Monoton veride shape-preserving / monotonic cubic Hermite interpolation sağlar ve dik/flat bölgelerde klasik cubic spline'ın oluşturabileceği overshoot davranışını önlemeye yardımcı olur.

Dyna için çok uygun kullanım alanları:
- çekme/basma/shear deney eğrilerini ortak strain grid'ine resample etmek
- farklı testlerin karşılaştırma noktalarını eşlemek
- deney eğrisinin monoton bölgelerinde overshoot oluşturmadan interpolation yapmak
- interpolated curve derivative hesaplamak
- eğri altında integral/enerji benzeri veri türetmek
- deneysel ve FEA eğrilerini ortak x-grid üzerinde karşılaştırmak

Özellikle kauçuk stress–strain eğrilerinde fiziksel eğri şeklini yapay cubic-spline salınımlarıyla bozmamak için standart cubic spline'a göre daha güvenli bir preprocessing seçeneğidir.

İlk entegrasyon hedefi V0.7 Material Calibration aşamasıdır. V0.2 solver çekirdeğine dependency olarak eklenmeyecektir.

---

## 5. Veri / ResultDatabase adayları

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

## 6. Test altyapısı

### test-drive

**Durum:** ADAY; MEVCUT CTEST YAPISI YETERLİ OLDUĞU SÜRECE EKLENMEYECEK  
**Repo:** https://github.com/fortran-lang/test-drive  
**Lisans:** MIT veya Apache-2.0

Mevcut bağımsız Fortran executable + CTest yaklaşımı küçük test setinde açık ve yeterlidir. Test sayısı/bakım maliyeti belirgin biçimde arttığında `test-drive` yeniden değerlendirilecektir.

---

## 7. Gelecek dinamik analizler

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

## 8. FEM kaynak-kod referansı

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

## 9. Dyna açık kaynak kullanım kuralları

1. **Bilimsel çekirdek bize aittir.** Hyperelastic constitutive law, FEM formulation, incompressibility strategy, axisymmetric torsion ve nonlinear solution policy Dyna tarafından geliştirilir.
2. Öncelik kaynak kod kopyalamak değil, iyi tanımlı library API'leri kullanmaktır.
3. Bir açık kaynak implementasyondan anlamlı kod/algoritma uyarlanırsa kaynak repo, dosya/algoritma, commit ve lisans kayıt altına alınır.
4. MIT/BSD/Apache gibi permissive kaynaklar tercih edilir.
5. GPL/AGPL gibi güçlü copyleft kaynaklardan Dyna çekirdeğine doğrudan kod kopyalanmaz; yalnız bilimsel/algoritmik referans olarak incelenebilir.
6. Weak-copyleft veya özel lisanslı dependency'ler ürün dağıtımından önce ayrıca lisans değerlendirmesinden geçirilir.
7. Harici kütüphane native Dyna domain/FEM tiplerini belirlememelidir; adapter sınırı arkasında tutulmalıdır.
8. Kritik dependency'ler branch adına değil doğrulanmış sürüm/tag/commit'e sabitlenir.
9. Dependency yükseltmesi normal kod değişikliği gibi benchmark ve regression testlerinden geçmeden kabul edilmez.
10. Calibration optimizer'ları doğrudan Material Core'un içine gömülmez; `IOptimizer` benzeri adapter/strategy sınırı arkasında tutulur.
11. Experimental interpolation preprocessing, ham deney datasını overwrite etmez; orijinal veri provenance ile korunur.

## 10. Öncelik sırası

```text
Şimdi
├── kavakfatih/stdlib          ← aktif
│   ├── stdlib_linalg::solve   ← aktif ilk kullanım
│   └── Reference LAPACK       ← backend / referans
│
V0.3 hazırlığı
├── stdlib_sparse              ← değerlendir
└── stdlib GMRES               ← benchmark/referans

Büyük sparse sistem aşaması
└── MUMPS                      ← production direct solver adayı

V0.7 Material Data / Calibration
├── PCHIP                      ← shape-preserving experimental interpolation
├── PRIMA                      ← bounded / constrained derivative-free fit
└── MINPACK                    ← LM least-squares refinement

Results büyüdüğünde
├── HDF5                       ← büyük bilimsel veri
└── JSON-Fortran               ← metadata/config

Gelecek dynamics
└── FFTPACK
```
