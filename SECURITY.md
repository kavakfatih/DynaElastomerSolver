# DynaElastomerSolver Güvenlik Politikası

Bu belge DynaElastomerSolver için güvenlik açığı bildirim, değerlendirme ve koordineli düzeltme politikasını tanımlar.

> Güvenlik açığı ayrıntılarını public issue, discussion, pull request, commit mesajı veya herkese açık başka bir kanalda paylaşmayın.

## Güncel repository durumu

Repository şu anda **public** durumdadır. Public geçiş öncesi tamamlanması hedeflenen bir kontrol henüz doğrulanmadıysa, aşağıdaki maddeler **post-public acil iyileştirme** olarak ele alınır.

Özellikle `main` branch koruması, Private Vulnerability Reporting, secret scanning/push protection, geçmiş Git/Actions taraması ve patent/ticari sır incelemesi açık bırakılmamalıdır.

## Desteklenen sürümler

| Hat | Güvenlik desteği |
|---|---|
| Güncel yayınlanmış sürüm / release branch | Desteklenir |
| `main` | Desteklenir |
| `develop/*` | Geliştirme amaçlı; güvenlik bulguları değerlendirilir ancak production desteği sayılmaz |
| Eski ve superseded sürümler | Aksi açıkça belirtilmedikçe desteklenmez |

## Güvenlik açığı nasıl bildirilir?

Public repository için **GitHub Private Vulnerability Reporting** etkinleştirilmelidir.

Tercih edilen ve resmi bildirim kanalı:

1. Repository içindeki **Security** bölümünü açın.
2. **Report a vulnerability** / private vulnerability reporting seçeneğini kullanın.
3. Açığın teknik ayrıntılarını yalnız bu özel kanal üzerinden iletin.

Private vulnerability reporting geçici olarak kullanılamıyorsa:

- teknik ayrıntıları public olarak yayınlamayın,
- yalnızca ayrıntı içermeyen bir iletişim talebi oluşturun veya proje sahibiyle mevcut özel proje kanalı üzerinden iletişime geçin,
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

Public repository için aşağıdaki kontroller etkin tutulmalıdır:

- Secret scanning,
- Push protection,
- Dependabot alerts,
- uygun olduğunda code scanning,
- minimum GitHub Actions permissions,
- dependency commit/tag pinleme,
- korunan ana branch ve zorunlu CI,
- force-push ve history rewrite kısıtlamaları,
- release/tag bütünlüğü kontrolleri.

Workflow token izinleri varsayılan olarak en düşük yetkiyle tanımlanmalıdır. Bir workflow yalnız ihtiyaç duyduğu write yetkisini almalıdır.

## Public repository güvenlik kapısı / post-public remediation

Aşağıdaki kontrollerin tamamı doğrulanmalıdır:

1. tüm Git geçmişi secret/credential açısından taranmalı,
2. geçmiş Actions logları ve artifactleri incelenmeli,
3. varsa sızmış credentiallar yalnız silinmemeli, **iptal edilip yenilenmeli**,
4. müşteri/şirket içi/kişisel veri bulunmadığı doğrulanmalı,
5. patent ve ticari sır değerlendirmesi tamamlanmalı,
6. `LICENSE`, `THIRD_PARTY_NOTICES.md` ve `CONTRIBUTING.md` güncel olmalı,
7. Private Vulnerability Reporting etkinleştirilmeli,
8. branch ruleset / protection kuralları yeniden etkinleştirilmeli ve doğrulanmalıdır.

## Mühendislik güvenliği notu

DynaElastomerSolver bilimsel/mühendislik yazılımıdır. Bir sayısal sonucun başarılı biçimde yakınsaması, sonucun tek başına ürün güvenliği, sertifikasyon veya fiziksel doğruluk garantisi olduğu anlamına gelmez. Safety-critical ve production kararları bağımsız doğrulama ve uygun mühendislik incelemesi gerektirir.
