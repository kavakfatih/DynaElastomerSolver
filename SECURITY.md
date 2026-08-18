# DynaElastomerSolver Güvenlik Politikası

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

Mümkünse aşağıdakileri ekleyin:

- etkilenen commit / sürüm / branch,
- etkilenen işletim sistemi ve compiler,
- açığın sınıfı ve olası etkisi,
- tekrar üretme adımları,
- minimum PoC,
- saldırının yerel mi uzaktan mı olduğu,
- kimlik doğrulama veya özel erişim gerekip gerekmediği,
- varsa geçici azaltım önerisi.

Gerçek credential, müşteri verisi, kişisel veri veya üretim sistemi bilgisi göndermeyin. Gerekliyse örnekleri sentetik veriyle yeniden üretin.

## Kapsam

Güvenlik kapsamında özellikle şunlar değerlendirilir:

- bellek güvenliği ve native-code kusurları,
- kontrolsüz dosya / mesh / veri girdilerinden kaynaklanan güvenlik sorunları,
- command injection veya shell invocation sorunları,
- path traversal ve yetkisiz dosya erişimi,
- dependency / supply-chain sorunları,
- CI/CD credential veya token sızıntıları,
- GitHub Actions izin hataları,
- kötü amaçlı artifact veya dependency kullanımı,
- beklenmeyen remote-code-execution yolları,
- güvenlik sınırını aşan plugin / adapter / external-tool çağrıları.

Yalnızca bilimsel doğruluk farkları, yakınsama sorunları veya sayısal sonuç uyuşmazlıkları tek başına güvenlik açığı değildir; ancak bu davranış güvenlik sınırını etkiliyorsa güvenlik bildirimi olarak değerlendirilebilir.

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
6. `LICENSE`, `THIRD_PARTY_NOTICES.md` ve `CONTRIBUTING.md` güncel tutulmalı,
7. Private Vulnerability Reporting etkinleştirilmeli,
8. `main` branch protection/ruleset ve required CI zorunlu hale getirilmelidir.

## Mühendislik güvenliği notu

DynaElastomerSolver bilimsel/mühendislik yazılımıdır. Bir sayısal sonucun başarılı biçimde yakınsaması, sonucun tek başına ürün güvenliği, sertifikasyon veya fiziksel doğruluk garantisi olduğu anlamına gelmez. Safety-critical ve production kararları bağımsız doğrulama ve uygun mühendislik incelemesi gerektirir.
