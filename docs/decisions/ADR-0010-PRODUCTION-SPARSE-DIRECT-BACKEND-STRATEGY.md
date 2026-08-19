# ADR-0010 — Production Sparse-Direct Backend Stratejisi

**Durum:** Kabul edildi  
**Tarih:** 2026-08-19  
**Kapsam:** Q9/P1 Herrmann mixed `u-P` için production sparse-direct backend seçimi, platform ve lisans sınırları

## Bağlam

DynaElastomerSolver'ın V0.3 production adayı Q9/P1 Herrmann mixed `u-P` plane-strain formulationıdır. Nearly-incompressible durumda sistem güçlü biçimde coupled, fully-incompressible limitte ise `Kpp = 0` olan symmetric-indefinite saddle-point yapısına geçmektedir.

B4 ile sparse çözüm yaşam döngüsü vendor-bağımsız `SparseSolverContext` arkasına alınmıştır:

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

Mevcut stdlib CSR GMRES backend portable bootstrap/regression yoludur; sparse-direct değildir. Dense stdlib/LAPACK küçük problem reference/fallback yolu olarak korunur.

Production sparse-direct seçiminde zorunlu ürün platformları:

```text
Windows x64
Linux x64
macOS Apple Silicon ARM64
```

macOS Apple Silicon ARM64 desteği opsiyonel değildir.

## Değerlendirme kriterleri

Backend aşağıdaki özellikler açısından değerlendirilmiştir:

- symmetric-indefinite / saddle-point desteği,
- 1x1 / 2x2 pivoting ve numerically difficult matrix davranışı,
- symbolic analysis / ordering reuse,
- numeric refactorization reuse,
- iterative refinement ve backward-error ölçümü,
- singularity / null-pivot / inertia diagnostics,
- 64-bit index yolu,
- shared-memory ve MPI ölçeklenebilirlik,
- out-of-core / memory-control,
- Fortran/C interoperability,
- Windows, Linux ve native macOS ARM64 taşınabilirliği,
- build ve runtime bağımlılık yükü,
- proprietary/source-available Dyna dağıtım modeli ile lisans uyumluluğu,
- vendor lock-in riski.

## Aday 1 — MUMPS 5.9.x

MUMPS güncel resmi sürümü Temmuz 2026 itibarıyla `5.9.1`'dir.

Resmi özellikleri Dyna'nın mixed problem sınıfıyla doğrudan örtüşmektedir:

- symmetric positive-definite, general symmetric ve unsymmetric sparse sistemler,
- symmetric-indefinite preprocessing ve 2-by-2 pivots,
- parallel factorization/solve,
- MPI + OpenMP/multithreaded BLAS hibrit çalışma,
- uniprocessor çalışma yolu,
- out-of-core numerical phases,
- iterative refinement ve backward-error analysis,
- null-pivot detection ve null-space basis estimate,
- çeşitli ordering seçenekleri,
- Fortran ve C interface,
- selective 64-bit integer desteği.

MUMPS 5.9.1 değişiklikleri ayrıca:

- çok sayıda Lagrange multiplier içeren matrislerde symbolic factorization performans iyileştirmesi,
- symmetric-indefinite numerical factorization pivot search performans iyileştirmesi,
- güncel Windows/MSVC derleme düzeltmeleri,
- OpenMP derleme düzeltmeleri

içermektedir. Bu özellikler mixed `u-P` saddle-point sistemler için doğrudan önemlidir.

### Lisans

MUMPS 5.9.1 CeCILL-C lisansı ile dağıtılmaktadır; bazı bundled/optional ordering parçalarının ayrı lisansları vardır.

CeCILL-C resmi lisans/FAQ'sına göre MUMPS ile oluşturulan derivative application farklı, hatta proprietary bir lisans altında dağıtılabilir. Ancak MUMPS kaynak koduna yapılan değişiklikler CeCILL-C altında tutulmalı ve dağıtım sırasında MUMPS kullanımı/lisansı görünür biçimde belirtilmelidir. Binary MUMPS dağıtımında ilgili source-code erişim yükümlülükleri ayrıca uygulanır.

Bu karar hukuki görüş değildir. Release paketine MUMPS binary/source eklenmeden önce `THIRD_PARTY_NOTICES.md`, CeCILL-C metni, source-access yöntemi ve optional ordering lisansları ayrıca incelenecektir.

## Aday 2 — PETSc + MUMPS

PETSc'in güncel dokümantasyonu MUMPS'u `MATSOLVERMUMPS` yoluyla doğrudan sparse factorization backend'i olarak destekler. PETSc:

- MUMPS `ICNTL/CNTL/INFO` parametrelerine erişim sağlar,
- `MATAIJ/MATSBAIJ` üzerinden MUMPS entegrasyonu sunar,
- MPI + OpenMP MUMPS konfigürasyonunu destekler,
- macOS için güncel build talimatı,
- Windows için WSL, Cygwin, native Microsoft/Intel ve MSYS2/MinGW build yolları sunar,
- MUMPS full/selective 64-bit build modlarını belgelemektedir.

PETSc'in kendisi 2-clause BSD lisanslıdır; PETSc'in indirdiği harici paketler kendi lisanslarında kalır. Dolayısıyla MUMPS için CeCILL-C yükümlülükleri PETSc kullanıldığında ortadan kalkmaz.

### Değerlendirme

PETSc güçlü ve olgun bir solver orchestration katmanıdır; ancak Dyna B4 ile kendi stateful solver abstraction'ını zaten kurmuştur. PETSc'i yalnız MUMPS'a ulaşmak için production core'a eklemek:

- önemli dependency/build hacmi,
- MPI ve PETSc object modeline ek coupling,
- Dyna'nın sahip olduğu backend sınırıyla kısmi fonksiyon tekrarına

neden olur.

Bu nedenle PETSc + MUMPS ilk production desktop backend'i olarak seçilmez. Gelecekte distributed/HPC solve, araştırma karşılaştırması veya ek solver ailelerinin tek framework üzerinden kullanımı gerektiğinde yeniden değerlendirilecektir.

## Aday 3 — Intel oneMKL PARDISO

oneMKL PARDISO teknik açıdan çok güçlü bir adaydır:

- `mtype = -2`: real symmetric-indefinite,
- parallel `LDL^T/LU/LL^T` factorization,
- 1x1 ve 2x2 Bunch-Kaufman pivoting,
- highly-indefinite/saddle-point sistemler için scaling + symmetric weighted matching önerisi,
- ayrı analysis / numerical factorization / solve phases (`11 / 22 / 33`),
- iterative refinement,
- perturbed-pivot diagnostics,
- positive/negative inertia raporu,
- out-of-core çalışma,
- `pardiso_64` 64-bit integer interface,
- multithreaded CPU çalışması.

Bu phase modeli Dyna B4 context API'siyle neredeyse birebir eşleşmektedir.

### Platform engeli

Intel'in resmi güncel dokümantasyonuna göre oneMKL için macOS desteği `2024.0` sürümünden itibaren kaldırılmıştır. 2026 oneMKL system requirements güncel CPU hedefleri için Linux ve Windows'u listeler; native macOS Apple Silicon ARM64 production desteği yoktur.

Bu nedenle PARDISO, teknik üstünlüğüne rağmen Dyna'nın **primary cross-platform backend'i olamaz**.

### Lisans

Intel'in resmi oneMKL License FAQ'sı oneMKL redistribution'a Intel Simplified Software License altında izin verildiğini ve royalty alınmadığını belirtmektedir. Platform kısıtı çözülmediği için bu avantaj primary seçim için yeterli değildir.

## Ek aday — SuperLU_DIST

SuperLU_DIST BSD lisanslı, MPI/OpenMP destekli, 64-bit integer indexing ve iterative refinement sağlayan güçlü bir distributed sparse-direct çözücüdür. Ancak temel tasarımı general **nonsymmetric LU** sistemler içindir ve static pivoting kullanır.

Dyna'nın ana problem sınıfı symmetric-indefinite mixed saddle-point olduğundan symmetry'yi ve LDL-type yapıyı doğrudan kullanan MUMPS/PARDISO yaklaşımı daha doğal ve daha ölçülebilir bir production yoludur. SuperLU_DIST ilk backend olarak seçilmez; gelecekte unsymmetric problem sınıfları genişlerse tekrar değerlendirilebilir.

## Karar

### 1. Primary portable production sparse-direct backend = doğrudan MUMPS

```text
PRIMARY PORTABLE DIRECT = MUMPS 5.9.x
```

Dyna production çekirdeği PETSc üzerinden değil, kendi `SparseSolverContext` abstraction'ı arkasından **doğrudan MUMPS adapter** kullanacaktır.

Neden:

1. mixed `u-P` symmetric-indefinite/saddle-point problem sınıfına doğrudan uygundur,
2. 2x2 pivots ve null-pivot diagnostics vardır,
3. symbolic/numeric/solve yaşam döngüsü B4 mimarisiyle uyumludur,
4. iterative refinement ve backward-error diagnostics vardır,
5. out-of-core ve MPI/OpenMP ölçeklenme yolu açıktır,
6. selective/full 64-bit büyüme yolu vardır,
7. C ve Fortran interface sunar,
8. tek CPU vendorına bağlı değildir,
9. CeCILL-C Dyna'nın geri kalanını proprietary lisansa zorlamaz; MUMPS/modified-MUMPS yükümlülükleri ayrıştırılabilir.

### 2. İlk adapter ABI sınırı MUMPS C interface üzerinden kurulacaktır

MUMPS tipleri FEM, material, assembly veya Newton modüllerine taşınmayacaktır.

Hedef sınır:

```text
Fortran Newton
    ↓
Dyna SparseSolverContext
    ↓ ISO_C_BINDING
small Dyna MUMPS C adapter
    ↓
MUMPS C interface
    ↓
MUMPS factorization engine
```

Bu yaklaşım:

- MUMPS derived-type/include bağımlılığını Dyna Fortran core'dan ayırır,
- ileride PARDISO gibi C-callable backend'lerin aynı context arkasına eklenmesini kolaylaştırır,
- vendor backend API değişikliklerini tek adapter dosyasında sınırlar.

### 3. B6 ilk aşamada desktop/shared-memory profilidir

B6'nın ilk hedefi MPI cluster entegrasyonu değildir.

İlk production profile:

```text
single process
+ OpenMP / threaded BLAS mümkünse
+ MUMPS direct factorization
```

MPI/distributed mode daha sonra aynı backend'in ikinci ölçeklenme katmanı olarak açılacaktır.

Bu sayede MacBook ve Windows workstation kurulumu gereksiz MPI runtime bağımlılığı ile ağırlaştırılmayacaktır. MUMPS'un uniprocessor/libseq yolu ve gerektiğinde `NOSCALAPACK` build seçeneği B6 prototipinde değerlendirilecektir; performans kaybı ölçülmeden kalıcı default yapılmayacaktır.

### 4. oneMKL PARDISO optional optimized backend olarak tutulacaktır

```text
OPTIONAL WINDOWS/LINUX DIRECT = oneMKL PARDISO
```

PARDISO primary değildir. B7/B9 sonrasında, yalnız Windows/Linux'ta kullanıcı açıkça seçerse veya AUTO policy platform capability üzerinden seçerse devreye girebilecek optional backend olarak planlanır.

Native macOS ARM64 sisteminde PARDISO seçeneği advertise edilmeyecek ve silent fallback yapılmayacaktır.

### 5. PETSc production dependency değildir

```text
PETSc + MUMPS = future HPC / integration option
```

PETSc'in bugün production core'a eklenmesi reddedilmiştir. Bu karar PETSc'in teknik kalitesine karşı değildir; Dyna'nın mevcut owned solver context'i varken dependency ve object-model katmanını minimumda tutma kararıdır.

### 6. GMRES bootstrap korunur fakat production-direct yerine geçmez

```text
Dense LAPACK  = reference/fallback
CSR GMRES     = portable bootstrap/regression
MUMPS         = portable production sparse-direct
PARDISO       = optional Windows/Linux optimized direct
PETSc         = future HPC orchestration option
```

## B6 entegrasyon kapsamı

B6 yalnız MUMPS production adapter'ını oluşturacaktır.

### Build / dependency

- MUMPS sürümü explicit pinlenir; ilk aday `5.9.1`.
- Upstream archive checksum doğrulanır.
- Backend CMake option ile açılıp kapatılabilir olmalıdır.
- MUMPS bulunmadığında existing dense/GMRES build bozulmamalıdır.
- İlk CI denemesinde MUMPS source/build bağımlılıkları public ve tekrarlanabilir şekilde pinlenir.
- PORD veya başka optional ordering paketi otomatik olarak lisans kontrolü yapılmadan bundle edilmez.

### Matrix adapter

Dyna CSR kanonik storage olarak kalacaktır. MUMPS external format gereksinimi için structure conversion yalnız backend adapter içinde yapılır.

Pattern sabitse:

```text
CSR structure mapping = once
MUMPS analysis        = once
ordering              = once
numeric factorization = each required Newton matrix update
solve                 = each RHS
```

FEM assembly MUMPS triplet/COO veya MUMPS index tiplerini bilmez.

### Matrix class

Q9/P1 Herrmann nominal mixed tangent için ilk MUMPS yolu:

```text
matrix_class = symmetric_indefinite
```

Symmetry regression bozulursa backend yanlışlıkla symmetric storage kullanmayacaktır; Dyna context bunu fail-fast diagnostic olarak ele alacaktır.

### B6 zorunlu testleri

1. küçük manufactured symmetric-indefinite sparse sistem,
2. finite-compliance Q9/P1 dense ↔ MUMPS parity,
3. fully-incompressible `cp=0` Q9/P1 dense ↔ MUMPS parity,
4. fixed sparse Newton accepted-result parity,
5. adaptive sparse Newton accepted-result parity,
6. displacement + pressure rollback/cutback regression,
7. pattern-analysis reuse (`analysis_count = 1`),
8. factorization/solve counter contract,
9. deliberate singular/null-pivot diagnostic,
10. iterative-refinement/backward-error report contract,
11. MUMPS unavailable build fallback,
12. dört-platform build/CTest gate.

### Zorunlu platform gate

B6 production backend kabul edilmeden önce:

```text
Linux x64 / gfortran 14                 PASS
macOS Apple Silicon ARM64 / gfortran 14 PASS
Windows x64 / gfortran 14               PASS
Windows x64 / Intel ifx                  PASS
```

olmalıdır.

Özellikle macOS ARM64 native build başarısızsa MUMPS production-primary ilanı askıya alınır; Rosetta/x86 emulation kabul kapısı değildir.

## B9 64-bit yolu

B6 mevcut int32 Dyna CSR ile production direct correctness'i kapatır. B9'da:

- Dyna CSR row/column index türleri gerçek 64-bit hale getirilir,
- MUMPS selective 64-bit ve gerektiğinde full 64-bit build karşılaştırılır,
- memory/performance etkisi benchmark edilir,
- external ordering integer-width uyumluluğu CI gate yapılır.

## Lisans / dağıtım kapısı

MUMPS release binary'si Dyna ile dağıtılmadan önce aşağıdakiler kapanmalıdır:

- CeCILL-C license text distribution,
- MUMPS copyright/notice,
- exact upstream version + checksum,
- source-code access veya source bundle yöntemi,
- modified-MUMPS varsa değişikliklerin ayrıştırılması ve CeCILL-C source erişimi,
- kullanılan optional ordering paketlerinin lisansları,
- `THIRD_PARTY_NOTICES.md` güncellemesi,
- bağımsız hukuki inceleme.

Dyna'nın özgün proprietary/source-available kaynak kodu MUMPS CeCILL-C nedeniyle otomatik olarak CeCILL-C altına taşınmayacaktır; fakat dağıtım yükümlülükleri eksiksiz yerine getirilecektir.

## Sonuç

B5 kararı:

```text
PRIMARY    = direct MUMPS 5.9.x adapter
OPTIONAL   = oneMKL PARDISO on Windows/Linux
FUTURE HPC = PETSc + MUMPS
FALLBACK   = CSR GMRES
REFERENCE  = dense LAPACK
```

Bu karar ANSYS/Marc commercial parity ilanı değildir. Production sparse-direct correctness, platform parity ve performance kanıtı B6/B7/B9'da ayrıca kapanacaktır.

## Resmi kaynaklar

- MUMPS 5.9.1 documentation: https://mumps-solver.org/index.php?page=doc
- MUMPS main features: https://mumps-solver.org/
- MUMPS download, license and changelog: https://mumps-solver.org/index.php?page=dwnld
- CeCILL-C license: https://www.cecill.info/licences/Licence_CeCILL-C_V1-en.html
- CeCILL FAQ: https://www.cecill.info/faq.en.html
- PETSc MATSOLVERMUMPS: https://petsc.org/main/manualpages/Mat/MATSOLVERMUMPS/
- PETSc install/macOS/Windows: https://petsc.org/main/install/
- PETSc license: https://petsc.org/main/install/license/
- Intel oneMKL PARDISO: https://www.intel.com/content/www/us/en/docs/onemkl/developer-reference-c/2026-0/pardiso.html
- Intel oneMKL PARDISO pivoting: https://www.intel.com/content/www/us/en/docs/onemkl/developer-reference-c/2026-0/onemkl-pardiso-parallel-direct-sparse-solver-iface.html
- Intel oneMKL 2026 system requirements: https://www.intel.com/content/www/us/en/developer/articles/release-notes/onemkl/2026.html
- Intel oneMKL license FAQ: https://www.intel.com/content/www/us/en/developer/articles/tool/onemkl-license-faq.html
- SuperLU_DIST documentation: https://portal.nersc.gov/project/sparse/superlu/superlu_dist_code_html/index.html
