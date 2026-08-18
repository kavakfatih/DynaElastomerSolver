# DynaElastomerSolver — Sürüm ve Branch Politikası

Bu doküman, sürümler arasında güvenli geçiş yapılabilmesi ve geliştirme sırasında doğrulanmış sürümlerin korunması için kullanılan branch düzenini tanımlar.

## Temel kural

Her sürüm geçişinde doğrulanmış sürüm ayrı bir `release/vX.Y` branch'inde korunur. Yeni sürüm geliştirmesi ayrı bir `develop/vX.Y` branch'inde yapılır.

```text
main
  │
  ├── release/v0.2   ← doğrulanmış V0.2
  │
  └── develop/v0.3   ← V0.3 geliştirme hattı
          │
          ├── formulation benchmarkları
          ├── mixed u-p
          └── F-bar
```

## Branch rollerı

### `main`

- Doğrulanmış ana hat.
- Aktif geliştirme doğrudan burada yapılmaz.
- Bir release branch kapanış kriterlerini geçtiğinde `main` o commit'e ilerletilir.

### `release/vX.Y`

- Belirli bir sürümün korunmuş ve geri dönülebilir hattıdır.
- Sürüm kapanışı sırasında yalnız bug fix, CI, doğrulama ve dokümantasyon düzeltmeleri kabul edilir.
- Bir sonraki ana geliştirme burada yapılmaz.
- Kullanıcı geçmiş sürüme dönmek istediğinde bu branch checkout edilir.

### `develop/vX.Y`

- Bir sonraki sürümün aktif geliştirme hattıdır.
- Yeni fizik, solver, element veya veri modeli geliştirmeleri burada yapılır.
- Sürüm kapanışında bu branch'teki doğrulanmış commit yeni `release/vX.Y` branch'inin başlangıcı olur.

## V0.2 → V0.3 geçişi

1. Mevcut V0.2 kodu `release/v0.2` branch'ine alınır.
2. Compiler matrix, 20 CTest, kapalı-form benchmarklar ve dış FEM karşılaştırması tamamlanır.
3. V0.2 kapanış commit'i sabitlenir.
4. `main`, V0.2 kapanış commit'ine ilerletilir.
5. `develop/v0.3`, doğrulanmış V0.2 commit'inden oluşturulur.
6. Nearly-incompressible formulation bake-off yalnız `develop/v0.3` üzerinde geliştirilir.

## Sürüm değiştirme

Örnek:

```bash
git fetch origin

git switch release/v0.2
# veya
git switch develop/v0.3
```

Bu sayede farklı sürümlerin kodu aynı repository içinde açık şekilde ayrılır ve gerektiğinde geri dönülebilir.

## Kapanış kuralı

Bir `release/vX.Y` branch'i yalnız sürümün tanımlı doğrulama kriterleri geçildiğinde tamamlanmış kabul edilir. CI veya fizik doğrulaması başarısızken yeni sürüm geliştirmesi release branch üzerinde başlatılmaz.

## İsimlendirme

- Kararlı sürüm: `release/v0.2`, `release/v0.3`, ...
- Aktif geliştirme: `develop/v0.3`, `develop/v0.4`, ...
- Geçici deneyler gerekirse: `experiment/<kısa-ad>`

`Sistem-ve-Mimari` branch'i bu sürümleme akışından bağımsızdır ve kullanıcı ayrıca istemedikçe güncellenmez.
