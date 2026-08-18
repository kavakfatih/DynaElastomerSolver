# DynaElastomerSolver — GitHub Public Repository Security Baseline

**Hak sahibi / güvenlik koordinatörü:** Muhammet Fatih Kavak  
**Repository:** `kavakfatih/DynaElastomerSolver`

## 1. `main` branch protection

GitHub → `Settings` → `Branches` veya `Rules` üzerinden `main` için koruma tanımlanmalıdır.

Önerilen minimum:

- Require a pull request before merging: **ON**
- Require status checks to pass: **ON**
- Require branch to be up to date: **ON**
- Require conversation resolution: **ON**
- Allow force pushes: **OFF**
- Allow deletions: **OFF**

Solo-owner yapı nedeniyle bağımsız ikinci reviewer eklenene kadar required approval / Code Owner approval zorunluluğu recovery/merge akışını kilitlemeyecek şekilde seçilir.

V0.3 için beklenen status context'leri:

```text
dyna/v0.3-linux-gfortran14
dyna/v0.3-macos-gfortran14
dyna/v0.3-windows-gfortran14
dyna/v0.3-windows-ifx2025.2
dyna/v0.3-fenicsx-q2-reference
```

## 2. Advanced Security / Code Security

GitHub repository Settings içinde aşağıdakiler doğrulanmalıdır:

- Secret scanning / Secret Protection
- repository-level Push Protection
- Dependabot alerts
- Private Vulnerability Reporting
- uygun code scanning

Public repository için dependency graph platform tarafından sağlanır.

## 3. Supply-chain baseline

- `.github/dependabot.yml` — GitHub Actions weekly updates ✅
- third-party Actions immutable commit SHA ile pinli ✅
- FEniCSx container immutable digest ile pinli ✅
- yeni dependency için `THIRD_PARTY_NOTICES.md` ve lisans review zorunlu

Pinned FEniCSx image:

```text
dolfinx/dolfinx:v0.11.0@sha256:58b27e84a2f26b98ce2d9ccc537b0ee6a59e2fcfdf386626d5ed9ddf43425ece
```

## 4. Pull request kapısı

`.github/pull_request_template.md` şu kontrolleri içerir:

- IP/provenance,
- third-party license,
- patent/ticari sır/NDA,
- secret/credential,
- kişisel/müşteri verisi,
- supply-chain,
- minimum workflow permission,
- private vulnerability reporting.

## 5. Güvenlik açığı bildirimi

Açık ayrıntılar public issue/PR'a yazılmaz. Tercih edilen kanal:

```text
Security → Advisories → Report a vulnerability
```

Private Vulnerability Reporting aktif değilse public hardening tamamlanmış sayılmaz.

## 6. Geçmiş denetimi

Current-tree hızlı keyword kontrolü temiz sonuç vermiştir; fakat aşağıdakiler ayrıca denetlenmelidir:

- full Git history,
- deleted files,
- branches/tags,
- Actions logs,
- workflow artifacts.

Bulunan credential yalnız silinmez; revoke/rotate edilir.

## 7. Release bütünlüğü

Release üretiminde:

- versioned tag,
- release notes,
- `LICENSE`,
- `COPYRIGHT.md`,
- `THIRD_PARTY_NOTICES.md`,
- SHA-256 checksum,
- mümkünse signed tag/release

kullanılır.

## 8. Güncel açık maddeler

- `main` branch protection / ruleset
- required V0.3 CI contexts
- Private Vulnerability Reporting
- Secret scanning / Push Protection / Dependabot alerts / code scanning ayar teyidi
- full-history secret audit
- historical Actions log/artifact audit
- patent/public-disclosure review
- ticari sır/NDA/provenance review
- GitHub Archive Program kararı

**Tam hukuki hak sahibi adı doğrulandı ve uygulandı:** Muhammet Fatih Kavak. ✅

Takip: Issue `#2 — Security: Public repository hardening`.
