# DynaElastomerSolver — Proje Kayıt ve Güncelleme Kuralları

**Durum:** Zorunlu proje çalışma kuralı  
**Son güncelleme:** 2026-08-17

## 1. Ana kural

Her anlamlı DynaElastomerSolver geliştirmesinin sonunda GitHub üzerindeki proje kayıtları da güncellenmelidir.

Kod geliştirmek tek başına tamamlanmış iş sayılmaz. Gerçek implementasyon ile proje planı, güncel sürüm ve sohbet kaydı senkron tutulmalıdır.

## 2. Varsayılan branch politikası

### `main`

Projenin **tek sürekli güncellenen ana branch'idir**.

Varsayılan olarak aşağıdakilerin tamamı `main` üzerinde güncellenir:
- Modern Fortran kaynak kodu
- FEM ve solver
- testler
- build altyapısı
- mimari ve sistem dokümantasyonu
- ADR kararları
- roadmap
- benchmark planları
- proje durumu
- sürüm planları
- ChatGPT proje sohbet günlüğü
- ileride uygulama ve UI kaynakları

### `Sistem-ve-Mimari`

Bu branch otomatik veya varsayılan olarak güncellenmez.

> Kullanıcı açıkça `Sistem-ve-Mimari` branch'ine yükleme/güncelleme istemedikçe bu branch'e hiçbir değişiklik yapılmaz.

Bu kural; sohbet kaydı, mimari doküman, sürüm durumu, roadmap ve diğer tüm dosyalar için geçerlidir.

## 3. Zorunlu sürekli güncellenen dosyalar — `main`

### A. `docs/sohbetler/ChatGPT Sohbet 1.md`

Bu ChatGPT sohbetinin sürekli proje günlüğüdür.

Her anlamlı konuşmada aşağıdakiler kaydedilir:
- kullanıcının yeni yönlendirmesi
- alınan teknik karar
- değiştirilen plan
- yapılan implementasyon
- önemli test / benchmark sonucu
- kapsam değişikliği
- branch / repository politikası değişikliği

### B. `docs/PROJECT_STATUS.md`

Her zaman projenin en güncel durumunu göstermelidir.

Zorunlu alanlar:
- güncel geliştirme sürümü
- tamamlanan özellikler
- çalışan bilimsel zincir
- son doğrulama sonuçları
- açık eksikler
- mevcut riskler
- sıradaki sürüm
- sıradaki teknik plan

### C. `docs/ROADMAP.md`

Milestone sırası veya kapsam değişirse güncellenmelidir.

ROADMAP yalnız gelecek planını değil, gerçekleşen teknik öğrenmelere göre plan değişikliklerini de yansıtmalıdır.

## 4. Güncelleme tetikleyicileri

Aşağıdaki durumlardan biri oluştuğunda `main` üzerindeki kayıt dosyaları kontrol edilmelidir:

1. Yeni bir bilimsel/fizik özelliği tamamlandığında.
2. Yeni FEM formulasyonu eklendiğinde.
3. Solver davranışı değiştiğinde.
4. Yeni material model eklendiğinde.
5. Benchmark/test sonucu önemli bir karar doğurduğunda.
6. Roadmap sırası değiştiğinde.
7. V1.0 kapsamı değiştiğinde.
8. UI/Results/Material/Solver mimarisi değiştiğinde.
9. Kullanıcı yeni bir proje kuralı koyduğunda.
10. Yeni branch politikası veya dependency kararı alındığında.

## 5. Sürüm politikası

Aktif geliştirme kilometre taşları şu formatla takip edilir:
- `V0.1`
- `V0.2-dev`
- `V0.3`
- vb.

`-dev`, kilometre taşının aktif geliştirme altında olduğunu belirtir.

Bir sürüm yalnız roadmap çıkış kriterleri karşılandığında tamamlanmış kabul edilir.

## 6. Güncel ve sıradaki sürüm kuralı

Her zaman `main` üzerinde aşağıdaki iki bilgi açıkça bulunmalıdır:

```text
Güncel sürüm
→ Şu anda hangi milestone üzerinde çalışılıyor?
→ Neler çalışıyor?
→ Neler eksik?

Sıradaki sürüm
→ Sonraki milestone nedir?
→ Hangi teknik problemi çözecek?
→ Çıkış kriteri nedir?
```

Bu bilginin ana kaynağı `docs/PROJECT_STATUS.md` dosyasıdır.

## 7. Sohbet günlüğü biçimi

Yeni kayıtlar kronolojik eklenir. Birebir uzun transkript zorunlu değildir; ancak kararın anlamını değiştirecek hiçbir teknik detay kaybedilmemelidir.

## 8. Doküman-kod tutarlılığı

Henüz implementasyonu olmayan bir özellik `çalışıyor`, `hazır`, `tamamlandı` diye yazılamaz.

Gerçek kod ve test ile doğrulanmış bir özellik de roadmap'te yalnız gelecek hedefi gibi bırakılmamalıdır.

## 9. Kanıta dayalı geliştirme

Yeni mimari soyutlama yalnız çalışan kod, başarısız benchmark, solver robustness ihtiyacı, doğrulama sonucu veya platform/dependency gereksinimi gerçek ihtiyaç gösterdiğinde eklenir.

## 10. Dil kuralı

GitHub üzerindeki insan tarafından okunan proje kayıtları Türkçe tutulur. Teknik identifier, API adı, matematiksel sembol, standart veya üçüncü taraf ürün adı gerektiğinde İngilizce kalabilir.

## 11. Değiştirilemez kayıt ilkesi

> Her anlamlı proje adımı sonunda `main` üzerindeki kod, sohbet günlüğü, güncel sürüm ve sıradaki plan birbiriyle tutarlı olmalıdır.

> `Sistem-ve-Mimari` branch'i kullanıcı ayrıca istemedikçe güncellenmez.
