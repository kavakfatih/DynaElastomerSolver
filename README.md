# DynaElastomerSolver — Sistem ve Mimari

Bu branch, DynaElastomerSolver projesinin **sistem mimarisi, bilimsel planları, tasarım kararları, yol haritası ve teknik referansları** için ayrılmıştır.

> **Branch:** `Sistem-ve-Mimari`

## Amaç

Bu branch'te çalıştırılabilir program kaynak kodu, test kodu veya build dosyası tutulmaz. Amaç; uygulama kodundan bağımsız, okunabilir ve sürdürülebilir bir **mimari ve sistem planı baseline'ı** oluşturmaktır.

Gerçek implementasyon ve çalışan program kaynakları `main` branch'inde geliştirilir.

## Bu branch'in kapsamı

- proje bağlamı ve ürün vizyonu
- ana sistem mimarisi
- nonlineer elastomer solver mimarisi
- Material Core mimarisi
- nearly-incompressible formulation planı
- FEM doğrulama ve benchmark stratejisi
- Results mimarisi
- UI ve Qt frontend sınırları
- ANSYS / Hexagon Marc karşılaştırmaları
- açık kaynak referansları
- ADR mimari karar kayıtları
- geliştirme yol haritası ve V1.0 kapsam sınırı

## Dokümantasyon haritası

### Proje ve yol haritası

- `docs/PROJECT_CONTEXT.md`
- `docs/ROADMAP.md`

### Mimari

- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/architecture/SOLVER_ARCHITECTURE.md`
- `docs/architecture/RESULTS_ARCHITECTURE.md`
- `docs/architecture/UI_ARCHITECTURE.md`

### Benchmark ve referanslar

- `docs/benchmarks/ANSYS_MARC_COMPARISON.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`

### Mimari karar kayıtları

- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/decisions/ADR-0002-ANSYS-MARC-BENCHMARK-REVISION.md`
- `docs/decisions/ADR-0003-OWNED-UI-ARCHITECTURE.md`
- `docs/decisions/ADR-0004-QT-FRONTEND-BOUNDARY.md`
- `docs/decisions/ADR-0005-NONLINEAR-ELASTOMER-SOLVER-SPECIALIZATION.md`
- `docs/decisions/ADR-0006-IMPLEMENTATION-FIRST-VALIDATION-AND-V1-SCOPE.md`

## Temel ürün yönü

DynaElastomerSolver genel amaçlı CAE kapsamını kopyalamayı hedeflemez. Ana uzmanlaşma alanı:

- büyük deformasyonlu nonlineer elastomer mekaniği
- hiperelastik malzeme davranışı
- yaklaşık sıkıştırılamazlık
- bonded metal–elastomer sistemleri
- plane strain
- axisymmetric
- axisymmetric torsion / 2.5D
- tork–açı ve kuvvet–yer değiştirme tahmini
- bağımsız solver ve fiziksel test doğrulaması

ANSYS Mechanical ve Hexagon Marc, özellik sayısı hedefi değil; seçilmiş elastomer problemlerinde doğruluk, çözüm sağlamlığı ve mühendislik davranışı için benchmark'tır.

## Branch politikası

Bu branch'e:

**Eklenebilir:**
- Markdown dokümanları
- mimari kararlar
- sistem şemaları
- matematiksel/formülasyon açıklamaları
- doğrulama planları
- benchmark planları
- UI bilgi mimarisi ve tasarım kuralları

**Eklenmez:**
- `.f90`, `.c`, `.cpp`, `.h`, `.cs`, `.swift`, `.qml` gibi uygulama kaynakları
- test programları
- executable örnekleri
- `CMakeLists.txt` veya başka build programları
- derlenmiş binary dosyalar

Dokümanlardaki formül, pseudo-code, interface adı ve kavramsal şemalar bu kuralın dışındadır; bunlar mimari açıklamanın parçasıdır.

## Dil politikası

İnsan tarafından okunan proje içeriği Türkçe tutulur. API, sınıf, interface, standart ve üçüncü taraf ürün adları gerektiğinde teknik uyumluluk nedeniyle İngilizce kalabilir.
