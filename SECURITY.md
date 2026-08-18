# DynaElastomerSolver Güvenlik Politikası

**Güvenlik koordinatörü / hak sahibi:** Muhammet Fatih Kavak

Bu belge DynaElastomerSolver için güvenlik açığı bildirim, değerlendirme ve koordineli düzeltme politikasını tanımlar.

> Güvenlik açığı ayrıntılarını public issue, discussion, pull request, commit mesajı veya herkese açık başka bir kanalda paylaşmayın.

## Desteklenen sürümler

| Hat | Güvenlik desteği |
|---|---|
| Güncel yayınlanmış sürüm / release branch | Desteklenir |
| `main` | Desteklenir |
| `develop/*` | Geliştirme amaçlı; güvenlik bulguları değerlendirilir ancak production desteği sayılmaz |
| Eski ve superseded sürümler | Aksi açıkça belirtilmedikçe desteklenmez |

## Güvenlik açığı nasıl bildirilir?

Repository public durumdadır. Tercih edilen resmi kanal GitHub **Private Vulnerability Reporting** özelliğidir.

Private Vulnerability Reporting etkinse:

1. Repository içindeki **Security** bölümünü açın.
2. **Advisories** bölümüne gidin.
3. **Report a vulnerability** seçeneğini kullanın.
4. Açığın teknik ayrıntılarını yalnız bu özel kanal üzerinden iletin.

Private Vulnerability Reporting geçici olarak kullanılamıyorsa:

- teknik ayrıntıları public olarak yayınlamayın,
- yalnızca ayrıntı içermeyen bir iletişim talebi oluşturun,
- exploit, PoC, secret, kişisel veri, token, anahtar veya saldırı ayrıntısı paylaşmayın.

## Bildirimde bulunması yararlı bilgiler

Mümkünse etkilenen commit/sürüm/branch, işletim sistemi ve compiler, açığın sınıfı ve olası etkisi, tekrar üretme adımları, minimum PoC ve varsa geçici azaltım önerisini ekleyin. Gerçek credential, müşteri verisi, kişisel veri veya üretim sistemi bilgisi göndermeyin; gerektiğinde sentetik veri kullanın.

## Kapsam

Güvenlik kapsamında özellikle bellek güvenliği ve native-code kusurları, kontrolsüz dosya/mesh/veri girdileri, command injection, path traversal, dependency/supply-chain sorunları, CI/CD credential sızıntıları, GitHub Actions izin hataları, kötü amaçlı artifact/dependency ve güvenlik sınırını aşan adapter/external-tool çağrıları değerlendirilir.

Yalnızca bilimsel doğruluk farkları, yakınsama sorunları veya sayısal sonuç uyuşmazlıkları tek başına güvenlik açığı değildir; ancak bu davranış güvenlik sınırını etkiliyorsa güvenlik bildirimi olarak değerlendirilir.

## Koordineli açıklama politikası

- Güvenlik bulguları doğrulanmadan public ayrıntı paylaşılmaz.
- Düzeltme hazırlanırken gerekiyorsa private security advisory kullanılır.
- CVE gereksinimi etki ve dağıtım biçimine göre ayrıca değerlendirilir.
- Açıklama tarihi; düzeltme, kullanıcıların güncelleme imkânı ve raporlayan kişiyle koordinasyon dikkate alınarak belirlenir.
- Aktif istismar veya yüksek etkili secret sızıntısında normal süreç kısaltılabilir.

## Güvenli geliştirme kuralları

Repository public olduğundan aşağıdaki kontroller etkin tutulmalıdır:

- Secret scanning / Secret Protection,
- Push protection,
- Dependabot alerts,
- uygun olduğunda code scanning,
- minimum GitHub Actions permissions,
- dependency commit/digest pinleme,
- korunan ana branch ve zorunlu CI,
- force-push ve history rewrite kısıtlamaları,
- release/tag bütünlüğü kontrolleri.

Workflow token izinleri varsayılan olarak en düşük yetkiyle tanımlanmalıdır. Bir workflow yalnız ihtiyaç duyduğu write yetkisini almalıdır.

## Public repository post-public güvenlik kapısı

Public görünürlük sonrası hardening tamamlanmış sayılmadan önce:

1. tüm Git geçmişi secret/credential açısından taranmalı,
2. geçmiş Actions logları ve artifactleri incelenmeli,
3. varsa sızmış credentiallar yalnız silinmemeli, **iptal edilip yenilenmeli**,
4. müşteri/şirket içi/kişisel veri bulunmadığı doğrulanmalı,
5. patent ve ticari sır değerlendirmesi tamamlanmalı,
6. `LICENSE`, `COPYRIGHT.md`, `THIRD_PARTY_NOTICES.md` ve `CONTRIBUTING.md` güncel tutulmalı,
7. Private Vulnerability Reporting etkinleştirilmeli,
8. `main` branch protection/ruleset ve required CI zorunlu hale getirilmelidir.

## Mühendislik güvenliği notu

DynaElastomerSolver bilimsel/mühendislik yazılımıdır. Bir sayısal sonucun başarılı biçimde yakınsaması, sonucun tek başına ürün güvenliği, sertifikasyon veya fiziksel doğruluk garantisi olduğu anlamına gelmez. Safety-critical ve production kararları bağımsız doğrulama ve uygun mühendislik incelemesi gerektirir.
