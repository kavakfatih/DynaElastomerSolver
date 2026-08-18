# DynaElastomerSolver — Public Repository IP ve Güvenlik Politikası

**Sürüm:** 1.1 — 18 Ağustos 2026  
**Hak sahibi:** Fatih KAVAK  
**Repository:** `kavakfatih/DynaElastomerSolver`  
**Repository durumu:** **PUBLIC**  
**Lisans modeli:** Proprietary / source-available / All Rights Reserved  
**Açık kaynak durumu:** Açık kaynak değildir

Bu politika DynaElastomerSolver'ın public GitHub repository olarak yayınlanması ve public kaldığı sürece uygulanacak fikrî mülkiyet, patent, ticari sır, üçüncü taraf lisans, güvenlik ve repository yönetişim kurallarını tanımlar.

Repository public olduğu için, public geçiş öncesi tamamlanmamış kontroller bu sürümde **post-public acil iyileştirme** olarak değerlendirilir.

---

## 1. Temel hak ilkesi

Public repository yalnız kaynak kodunun herkes tarafından görüntülenebilir hâle gelmesi anlamına gelir.

DynaElastomerSolver'ın özgün içeriği için:

- MIT / Apache / GPL / BSD veya başka bir açık kaynak lisansı verilmemiştir,
- genel kullanım izni verilmez,
- ticari veya kurum içi production kullanım izni verilmez,
- değiştirme / türev eser izni verilmez,
- redistribution / sublicensing izni verilmez,
- patent lisansı verilmez,
- marka kullanım izni verilmez.

Bağlayıcı koşullar `LICENSE` içindedir. Üçüncü taraf bileşenler kendi lisansları altında kalır.

---

## 2. GitHub platform hakları — istisna

GitHub Terms of Service, public repository içeriği için GitHub'a, Affiliates'e ve GitHub kullanıcılarına doğrudan belirli platform hakları verebilir. Buna public repository'nin GitHub üzerinde görüntülenmesi ve fork edilmesi dahildir.

Dyna `LICENSE` dosyası bu platform haklarını genişletmez ve bunları ortadan kaldırdığı şeklinde yorumlanmaz.

**Önemli:** GitHub'ın yürürlükteki Terms of Service'i GitHub ve Affiliates için AI/ML geliştirme/eğitim hakları içerebilir. Dyna'nın üçüncü taraf AI/ML kısıtı, GitHub'ın kendi sözleşmesinden doğan haklarını geçersiz kıldığı şeklinde yorumlanmaz.

---

## 3. Patent ve kamuya açıklama durumu — ACİL

Repository artık public olduğu için içindeki teknik öğretim kamuya açıklanmış kabul edilebilir. Patentlenebilir olabilecek bir unsur varsa ülke/bölgeye göre yenilik ve başvuru stratejisi etkilenmiş olabilir.

Özellikle incelenecek alanlar:

- özgün nearly-incompressible formulation türetmeleri,
- özgün F-bar varyasyonları,
- axisymmetric / 2.5D torsion yöntemleri,
- nonlinear recovery / solver algoritmaları,
- calibration yöntemleri,
- özgün result semantics / veri işleme,
- ürün seviyesinde solver + ölçüm kombinasyonları.

**Kural:** Yeni patentlenebilir teknik içerik bundan sonra public branch'e eklenmeden önce patent değerlendirmesi yapılır. Mevcut public açıklamalar için patent vekiliyle mümkün olan başvuru seçenekleri gecikmeden değerlendirilir.

---

## 4. Ticari sır ve gizli bilgi

Public repository'de yer alan bir bilginin gizli tutulduğu varsayılamaz. Ticari sır olarak korunması gereken içerik public branch'lere eklenmez.

Yasak örnekler:

- müşteri verisi,
- NDA kapsamındaki teknik içerik,
- gerçek şirket içi test/reçete/proses/tolerans bilgileri,
- lisans anahtarları ve credentiallar,
- API tokenları / private keys,
- özel endpoint ve kurum içi ağ bilgileri,
- gizli CAD / mesh / ürün geometrileri,
- henüz patent stratejisi belirlenmemiş gizli teknik öğretim.

Yalnız current tree değil, Git geçmişi ve Actions log/artifact geçmişi de taranır. Bir credential geçmişte açığa çıkmışsa yalnız silmek yeterli değildir; revoke/rotate edilir.

---

## 5. Telif ve hak sahipliği

Public içerik için hak sahipliği/provenance belgelenmelidir.

Kontrol soruları:

- özgün kodu kim yazdı?
- işveren/şirket/üniversite/müşteri hak iddia edebilir mi?
- dış contributor katkısı var mı?
- üçüncü taraf kodu veya dokümanı kopyalandı mı?
- AI-assisted kodun provenance'ı incelendi mi?
- başka bir lisansın yükümlülüğü doğuyor mu?

Dış contributor içeriği gerekli IP assignment / izin olmadan production branch'e merge edilmez. Ayrıntı: `CONTRIBUTING.md`.

Türkiye'de isteğe bağlı kayıt-tescil, hakkı doğuran işlem olarak değil, eser sahipliğinin ispatını kolaylaştırabilecek ek kayıt yöntemi olarak ayrıca değerlendirilebilir.

---

## 6. Üçüncü taraf lisansları

Her dependency için en az şu kayıt tutulur:

```text
Dependency
├── upstream repository
├── version / commit
├── copyright owner
├── license
├── fetched / linked / vendored kullanım biçimi
└── notice yükümlülüğü
```

Mevcut doğrudan Fortran dependency:

```text
kavakfatih/stdlib
commit: 9a15c7772f1a76a6c497b9f3abb793841fc81f74
license: MIT
copyright: stdlib contributors
```

Üçüncü taraf bildirimleri `THIRD_PARTY_NOTICES.md` içinde tutulur. Üçüncü taraf kodu Dyna proprietary telif hakkıymış gibi yeniden etiketlenmez.

---

## 7. Katkı politikası

Varsayılan akış:

```text
Unsolicited external code contribution
→ otomatik kabul edilmez
→ IP/provenance incelemesi
→ gerekiyorsa yazılı hak devri / lisans sözleşmesi
→ teknik review + CI
→ owner kararı
```

Patentlenebilir veya gizli fikirler public issue/discussion içinde paylaşılmamalıdır.

---

## 8. Secret / credential güvenliği — ACİL

Aşağıdakiler taranır:

- current source tree,
- tüm Git commit geçmişi,
- silinmiş dosyalar,
- tag ve branch geçmişi,
- GitHub Actions logs,
- workflow artifactleri,
- test fixture'ları,
- config ve generated outputlar.

Aranacak sınıflar:

- GitHub tokenları,
- cloud API keys,
- SSH/private keys,
- passwords,
- connection strings,
- package registry credentials,
- signing keys,
- internal host/VPN bilgileri,
- kişisel veya müşteri verisi.

Current-tree hızlı araması tam audit yerine geçmez.

---

## 9. GitHub Actions / supply-chain güvenliği

Varsayılan workflow izin hedefi:

```yaml
permissions:
  contents: read
```

Write yetkisi yalnız gerçekten gerekliyse ve minimum kapsamla verilir.

Third-party Actions mümkünse immutable commit SHA ile pinlenir. Container image'ları mümkünse digest ile pinlenir.

Fork PR kodu:

- secretlara doğrudan erişmez,
- privileged workflow ile otomatik çalıştırılmaz,
- maintainer review olmadan write token alamaz.

Mevcut takip maddesi: FEniCSx referans workflow'undaki `dolfinx/dolfinx:v0.11.0` image tag'i digest ile sabitlenmelidir.

---

## 10. Public repository güvenlik özellikleri

Aşağıdaki kontroller doğrulanmadan public repo güvenlik açısından tamamlanmış kabul edilmez:

- [ ] Secret scanning aktif ve incelendi
- [ ] Push protection aktif
- [ ] Dependabot alerts aktif
- [ ] Dependency graph aktif
- [ ] Code scanning uygun kapsamda aktif
- [ ] Private Vulnerability Reporting aktif
- [x] `SECURITY.md` mevcut
- [x] `CODEOWNERS` mevcut
- [x] Actions permissions minimum seviyeye yakın
- [ ] `main` branch korunuyor
- [ ] force push engelli
- [ ] zorunlu CI checks tanımlı
- [ ] release/tag bütünlük politikası uygulanıyor

---

## 11. `main` branch koruması — ACİL

Public geçiş sonrası 18 Ağustos 2026 denetiminde `main` için:

```text
protected = false
required status checks = off
```

Bu durum düzeltilmelidir.

Minimum politika:

- PR üzerinden değişiklik,
- CODEOWNERS review veya owner-controlled merge,
- gerekli CI check'leri,
- force-push yasağı,
- branch deletion yasağı,
- mümkünse signed commit/tag doğrulaması.

GitHub visibility değişiminde push ruleset'leri devre dışı bırakabileceğinden her visibility değişiminden sonra bu kontrol tekrarlanır.

---

## 12. Actions geçmişi ve artifactler

Public repository'nin geçmiş Actions history/logları görülebilir. Bu nedenle eski run'lar ayrıca denetlenir:

- credential / secret,
- internal path / host,
- müşteri veya kişisel veri,
- hassas artifact.

Şüpheli credential bulunursa revoke/rotate edilir.

---

## 13. GitHub Archive Program ve kalıcı kopyalar

Public repository fork, clone ve üçüncü taraf arşivlerine kopyalanabilir. Sonradan private yapmak geçmişte oluşturulmuş kopyaların tamamını geri alamaz.

GitHub Archive Program kapsamındaki uzun süreli arşivleme açısından opt-out seçeneği ayrıca değerlendirilir.

---

## 14. Public README hak bildirimi

README üst bölümünde aşağıdaki anlam görünür tutulur:

```text
SOURCE-AVAILABLE — NOT OPEN SOURCE
Copyright © 2026 Fatih KAVAK. All Rights Reserved.
See LICENSE and THIRD_PARTY_NOTICES.md.
```

Bu kontrol tamamlandı. ✅

---

## 15. Release bütünlüğü

Public release için önerilen minimum katman:

- versioned release,
- immutable tag,
- SHA-256 checksum,
- mümkünse signed tag/release,
- release notes,
- third-party notices,
- license notice.

---

## 16. Güncel GO / REMEDIATION durumu

### Tamamlanan IP / policy katmanı

- [x] Proprietary `LICENSE`
- [x] `NOTICE.md`
- [x] `THIRD_PARTY_NOTICES.md`
- [x] `CONTRIBUTING.md`
- [x] `SECURITY.md`
- [x] `.github/CODEOWNERS`
- [x] README proprietary/source-available banner

### Açık acil maddeler

- [ ] Hak sahipliği / işveren / contributor provenance final incelemesi
- [ ] Patent/public-disclosure hukuki incelemesi
- [ ] Ticari sır review
- [ ] Full-history secret scan
- [ ] Historical Actions logs/artifacts audit
- [ ] Gerekli credential rotation
- [ ] Private Vulnerability Reporting
- [ ] Secret scanning / push protection doğrulaması
- [ ] `main` branch protection/ruleset
- [ ] FEniCSx container digest pinleme
- [ ] GitHub Archive Program kararı

Bu maddeler açıkken repository public kalacaksa durum **PUBLIC / REMEDIATION REQUIRED** olarak kabul edilir.

---

## 17. Temel ilke

> Public görünürlük mülkiyet devri değildir; ancak GitHub Terms kaynaklı platform hakları, patentte kamuya açıklama, ticari sır kaybı ve kalıcı fork/clone riskleri yaratır. Dyna'nın özgün kodu için verilmeyen haklar saklıdır; buna rağmen public GitHub kullanımı mutlak kontrol sağlamaz.
