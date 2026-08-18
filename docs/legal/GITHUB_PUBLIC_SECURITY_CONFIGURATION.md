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

V0.3 için hedef required checks:

```text
dyna/v0.3-linux-gfortran14
dyna/v0.3-macos-gfortran14
dyna/v0.3-windows-gfortran14
dyna/v0.3-windows-ifx2025.2
dyna/v0.3-fenicsx-q2-reference
Legal / Public IP Guard
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

## 4. Automated Legal / Public IP Guard

`.github/workflows/legal-public-ip-guard.yml` aşağıdakileri otomatik doğrular:

- `LICENSE v1.1` varlığı,
- `Muhammet Fatih Kavak` hak sahibi kaydı,
- `COPYRIGHT.md`, `NOTICE.md`, `SECURITY.md`, `CONTRIBUTING.md`, third-party ve IP gate dosyaları,
- pinli stdlib provenance kaydı,
- kritik private-key/token pattern sınıfları,
- `.env`, private-key/certificate/credential benzeri yasaklı tracked dosyalar.

Secret bulunduğunda değer loglanmaz; yalnız dosya ve risk sınıfı raporlanır.

## 5. Pull request ve issue kapısı

`.github/pull_request_template.md` IP/provenance, third-party license, patent/ticari sır/NDA, secret/credential, müşteri verisi, supply-chain ve minimum permission kontrollerini içerir.

Public issue güvenliği:

- blank issue kapalı ✅
- bug formunda secret/security/NDA uyarısı ✅
- feature formunda patent/ticari sır/public-disclosure uyarısı ✅

## 6. Pre-Disclosure IP Gate

Yeni patent adayı veya gizli teknikler public Dyna branch'lerinde geliştirilmez. Önce ayrı private çalışma alanında tutulur.

İlgili belgeler:

- `docs/legal/PRE_DISCLOSURE_IP_GATE.md`
- `docs/legal/IP_PROVENANCE_REGISTER.md`

## 7. Güvenlik açığı bildirimi

Açık ayrıntılar public issue/PR'a yazılmaz. Tercih edilen kanal:

```text
Security → Advisories → Report a vulnerability
```

Private Vulnerability Reporting aktif değilse public hardening tamamlanmış sayılmaz.

## 8. Geçmiş denetimi

Current-tree hızlı keyword kontrolü temiz sonuç vermiştir; fakat aşağıdakiler ayrıca denetlenmelidir:

- full Git history,
- deleted files,
- branches/tags,
- Actions logs,
- workflow artifacts.

Bulunan credential yalnız silinmez; revoke/rotate edilir.

## 9. Release bütünlüğü

Release üretiminde:

- versioned tag,
- release notes,
- `LICENSE`,
- `COPYRIGHT.md`,
- `THIRD_PARTY_NOTICES.md`,
- SHA-256 checksum,
- mümkünse signed tag/release

kullanılır.

## 10. Güncel açık maddeler

- `main` branch protection / ruleset
- required CI + `Legal / Public IP Guard` check
- Private Vulnerability Reporting
- Secret scanning / Push Protection / Dependabot alerts / code scanning ayar teyidi
- full-history secret audit
- historical Actions log/artifact audit
- patent/public-disclosure uzman review
- ticari sır/NDA/provenance uzman review
- GitHub Archive Program kararı

**Tam hukuki hak sahibi adı:** Muhammet Fatih Kavak. ✅

Takip: Issue `#2 — Security: Public repository hardening`.
