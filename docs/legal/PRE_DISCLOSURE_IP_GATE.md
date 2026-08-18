# DynaElastomerSolver — Pre-Disclosure IP Gate

**Hak sahibi:** Muhammet Fatih Kavak  
**Amaç:** Yeni teknik fikir, patent adayı, ticari sır, NDA veya müşteri içeriğinin public repository'ye erken açıklanmasını önlemek.

## Temel kural

`kavakfatih/DynaElastomerSolver` public repository'dir. Bu nedenle bu repository içindeki **tüm branch'ler, commitler, pull request'ler, issue'lar, Actions logları ve yayınlanan artifactler public kabul edilir**.

> Patentlenebilir veya gizli olma ihtimali bulunan yeni teknik içerik, public Dyna repository'sinde geliştirmeye başlanmaz.

Böyle bir çalışma önce ayrı **private repository / private çalışma alanında** tutulur.

## Sınıflandırma

Her yeni önemli teknik çalışma public commit öncesinde aşağıdaki sınıflardan birine alınır:

### PUBLIC-SAFE

- bilinen/standart mühendislik implementasyonu,
- gizli veri içermiyor,
- patent adayı değil veya yayın kararı verilmiş,
- üçüncü taraf lisans/provenance temiz.

Public Dyna repository'sine alınabilir.

### PRIVATE-REVIEW

- özgün yöntem olma ihtimali var,
- patentlenebilirlik belirsiz,
- müşteri/şirket/NDA bağlantısı olabilir,
- provenance henüz tamamlanmadı.

Public repository'ye alınmaz; private incelemede kalır.

### PATENT-CANDIDATE

- yeni formulation,
- yeni solver/recovery algoritması,
- özgün axisymmetric/2.5D/torsion yöntemi,
- yeni calibration/identification yöntemi,
- ürün seviyesinde yeni teknik çözüm,
- ölçüm + solver kombinasyonunda yeni teknik etki.

Patent uzmanı/vekili değerlendirmesi ve yayın kararı tamamlanmadan public'e alınmaz.

### PROHIBITED-PUBLIC

- ticari sır,
- NDA materyali,
- müşteri verisi,
- gizli CAD/mesh/test verisi,
- credential/private key/token,
- şirket içi proses/reçete/tolerans,
- üçüncü tarafın yayın hakkı verilmeyen içeriği.

Public repository'ye hiçbir koşulda doğrudan commit edilmez.

## Public'e geçiş kapısı

Private içerik ancak şu maddeler tamamlandığında public Dyna'ya taşınır:

- [ ] Hak sahipliği/provenance belirlendi
- [ ] Üçüncü taraf lisansları incelendi
- [ ] Patent adayı olup olmadığı değerlendirildi
- [ ] Gerekli patent başvurusu/yayın kararı tamamlandı
- [ ] Ticari sır/NDA/müşteri verisi temizlendi
- [ ] Secret/credential taraması yapıldı
- [ ] Teknik doğrulama planı hazır
- [ ] Public committe hangi içeriğin açıklanacağı kayıt altına alındı

## Public-disclosure kaydı

Önemli yeni teknik içerik public'e alındığında provenance kaydına en az:

```text
feature / yöntem
ilk public commit SHA
tarih
hak sahibi / contributor
third-party kaynaklar
patent review durumu
```

eklenir.

## GitHub notu

Public repository içinde "private branch" varsayımı yapılmaz. Gizlilik gereken iş ayrı private repository/çalışma alanında tutulur.

## İlişkili belgeler

- `LICENSE`
- `COPYRIGHT.md`
- `CONTRIBUTING.md`
- `THIRD_PARTY_NOTICES.md`
- `docs/legal/IP_PROVENANCE_REGISTER.md`
- `docs/legal/PUBLIC_REPOSITORY_IP_SECURITY_POLICY.md`
