# DynaElastomerSolver — GitHub Public Repository Security Baseline

**Repository:** `kavakfatih/DynaElastomerSolver`  
**Amaç:** Public repository için minimum branch, CI, secret ve vulnerability-reporting güvenlik ayarlarını standartlaştırmak.

## 1. `main` branch protection

GitHub → `Settings` → `Branches` → branch protection rule oluştur.

Branch name pattern:

```text
main
```

Önerilen ayarlar:

- Require a pull request before merging: **ON**
- Required approvals: solo-owner yapı nedeniyle **zorunlu değil**
- Dismiss stale approvals: ileride dış reviewer kullanılırsa **ON**
- Require review from Code Owners: ikinci bağımsız reviewer/maintainer eklenmeden zorunlu yapılmaz
- Require status checks to pass before merging: **ON**
- Require branches to be up to date before merging: **ON**
- Require conversation resolution before merging: **ON**
- Allow force pushes: **OFF**
- Allow deletions: **OFF**
- Do not allow bypassing: repository çalışma modeline göre ayrıca değerlendirilir; solo-owner recovery erişimi kaybedilmemelidir

V0.3 PR hattı için beklenen durum context'leri:

```text
dyna/v0.3-linux-gfortran14
dyna/v0.3-macos-gfortran14
dyna/v0.3-windows-gfortran14
dyna/v0.3-windows-ifx2025.2
dyna/v0.3-fenicsx-q2-reference
```

Bu context adları release döngüsü değiştiğinde güncellenir.

## 2. Security / Advanced Security

GitHub → `Settings` → `Security` → `Advanced Security`.

Doğrulanması/etkinleştirilmesi gerekenler:

- Secret Protection / secret scanning
- Push protection
- Private vulnerability reporting
- Dependabot alerts
- uygun olduğunda code scanning

Public repository için dependency graph GitHub tarafından desteklenen kapsamda kullanılmalıdır.

## 3. Dependency ve supply-chain politikası

Repository içinde:

- `.github/dependabot.yml` GitHub Actions dependency güncellemelerini haftalık takip eder.
- GitHub Actions mümkün olduğunda immutable commit SHA ile pinlenir.
- Container image'ları yalnız mutable tag ile bırakılmamalı; mümkünse digest ile pinlenmelidir.
- Yeni dependency ekleyen PR, `THIRD_PARTY_NOTICES.md` ve lisans uyumluluğunu kontrol etmelidir.

## 4. Pull request güvenlik kapısı

`.github/pull_request_template.md` aşağıdaki kontrolleri zorunlu hatırlatma olarak içerir:

- IP/provenance
- üçüncü taraf lisans
- patent/ticari sır/NDA
- secret/credential
- kişisel/müşteri verisi
- supply-chain
- minimum workflow permission
- private vulnerability reporting

## 5. Public güvenlik açığı bildirimi

Güvenlik açığı ayrıntıları public issue veya PR'da paylaşılmamalıdır.

Tercih edilen kanal:

```text
Security → Advisories → Report a vulnerability
```

Private Vulnerability Reporting aktif değilse bu durum security hardening tamamlanmış kabul edilmez.

## 6. Geçmiş denetimi

Public repository için yalnız current tree taraması yeterli değildir. Aşağıdaki geçmiş alanlar ayrıca incelenir:

- tüm commit geçmişi
- silinmiş dosyalar
- tags / branches
- Actions logs
- workflow artifacts
- eski build/config çıktıları

Bulunan credential yalnız history'den silinmez; **revoke/rotate** edilir.

## 7. Release bütünlüğü

Release üretiminde:

- versioned tag
- release notes
- `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- SHA-256 checksum
- mümkünse signed tag/release

kullanılır.

## 8. Mevcut bilinen açık maddeler

- `main` branch protection henüz GitHub ayarından etkinleştirilmeli.
- Private Vulnerability Reporting durumu UI üzerinden doğrulanmalı.
- Secret scanning / push protection / Dependabot alerts durumu UI üzerinden doğrulanmalı.
- Full-history secret audit tamamlanmalı.
- Historical Actions log/artifact audit tamamlanmalı.
- FEniCSx container image digest pinleme tamamlanmalı.
- Patent/ticari sır/provenance incelemesi tamamlanmalı.

Takip: GitHub Issue `#2 — Security: Public repository hardening`.
