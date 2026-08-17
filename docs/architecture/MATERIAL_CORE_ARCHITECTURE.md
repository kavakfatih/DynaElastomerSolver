# DynaElastomerSolver — Material Core Mimarisi v1.1

**Revizyon:** ANSYS / Marc / FEBio / MFront benchmark uyumu  
**Durum:** Kabul edildi

## 1. Amaç

Material Core, çözücüden bağımsız bünye bilimi katmanıdır. FEM, kalibrasyon, material-point doğrulaması ve gelecekteki harici çözücü adaptörleri aynı kanonik uygulamayı kullanır.

```text
                    Material Core
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
 Kalibrasyon        FEM Solver       Point Testleri
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │
             Gelecekte Harici Solver Export
```

Fiziksel malzeme kaydı ile matematiksel bünye uyumu birbirinden ayrı nesnelerdir.

## 2. Temel tipler

```text
material_model_t                 soyut
hyperelastic_model_t            soyut
material_definition_t           fiziksel malzeme kaydı
material_parameter_set_t        bünye parametreleri
material_kinematics_t           F, J ve türetilmiş büyüklükler
material_point_state_t          integrasyon noktası durumu
material_response_t             enerji/gerilme/tanjant/state cevabı
material_validation_t           doğrulama metadatası
material_provenance_t           kaynak ve kalibrasyon izlenebilirliği
```

## 3. Malzeme modeli sözleşmesi

Örnek Modern Fortran sözleşmesi:

```fortran
type, abstract :: material_model_t
contains
    procedure(material_evaluate_if), deferred :: evaluate
    procedure(material_validate_if), deferred :: validate_parameters
    procedure(material_metadata_if), deferred :: metadata
end type material_model_t

type, abstract, extends(material_model_t) :: hyperelastic_model_t
contains
    procedure(energy_if), deferred :: strain_energy
end type hyperelastic_model_t
```

V1.0 hedef hiperelastik ailesi:

```text
hyperelastic_model_t
├── neo_hookean_t
├── mooney_rivlin_t
├── yeoh_t
├── ogden_t
│   ├── N1
│   ├── N2
│   └── N3
├── arruda_boyce_t
└── gent_t
```

## 4. Malzeme kinematiği

Bünye modeli hiçbir zaman belirli bir FEM elemanına bağımlı değildir.

```text
material_kinematics_t
├── F(3,3)
├── J
├── C(3,3)
├── B(3,3)
├── principal_stretches
├── isteğe bağlı zaman artımı
└── isteğe bağlı sıcaklık alanları
```

Çağıran taraf FEM, kalibrasyon, point-test sürücüsü veya harici adaptör olabilir.

## 5. Malzeme cevabı

```text
material_response_t
├── strain_energy
├── first_piola_stress P
├── cauchy_stress
├── consistent_tangent
├── uygun olduğunda bünye basınç büyüklükleri
├── J
├── güncellenmiş trial-state verisi
└── status
```

Hiperelastik temel:

`W = W(F)`

`P = ∂W / ∂F`

`A = ∂P / ∂F`

Kanonik tanjant gösteriminin kesin biçimi Material Core API tarafından belirlenir ve harici çözücü kurallarından bağımsız olarak belgelenir.

## 6. Material-point durumu

```text
material_point_state_t
├── committed
├── trial
└── history variables
```

İterasyon politikası:

```text
Committed
   ↓
Trial
   ↓
Newton iterasyonları
 ┌─┴──────────┐
 başarısız   yakınsadı
  │             │
revert        commit
```

İlk hiperelastik modeller state bağımsız olsa bile history depolama ilk sürümden itibaren bulunur. Böylece daha sonra viskoelastisite, Mullins etkisi, histerezis ve hasar eklenirken material API bozulmaz.

## 7. Bünye yasası sıkıştırılamazlık stratejisi değildir

Bu ayrım zorunludur.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Yeoh, Ogden veya başka bir bünye sınıfı; FE formulasyonunun karma `u-p`, volumetric penalty veya başka bir kısıt yöntemi kullanıp kullanmayacağına karar vermez.

Kavramsal olarak:

`W = W_iso(F_bar) + W_vol(J)`

ancak FE uygulama yöntemi formulasyon/kısıt katmanının sorumluluğundadır.

Hedef stratejiler:

```text
IIncompressibilityStrategy
├── Compressible
├── NearlyIncompressible
└── MixedUP
```

## 8. Native material-plugin mimarisi

DynaElastomerSolver FEM değiştirilmeden genişletilebilirliği destekler.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Kanonik plugin çağrısı:

```text
evaluate(kinematics, trial_state, parameters)
    ↓
MaterialResponse
```

Gerekli plugin yetenekleri:

- kararlı model kimliği/sürümü
- parametre metadatası
- parametre doğrulama
- malzeme cevabı değerlendirme
- state başlatma
- stateful ise trial/commit/revert desteği
- hata/status raporlama
- tanjant bildirimi/uygunluğu

Bir plugin ANSYS, Marc, FEBio veya başka bir çözücünün native parametre kurallarını doğrudan çekirdeğe taşıyamaz. Harici kurallar adaptörlerde dönüştürülür.

## 9. Parametre metadatası

Her malzeme modeli UI, kalibrasyon, serialization ve doğrulama tarafından ortak kullanılan bir şema bildirir.

Yeoh örneği:

```text
Model ID: hyperelastic.yeoh.3
Parameters:
- C10
- C20
- C30
Capabilities:
- finite_strain = true
- nearly_incompressible = supported
- history = false
```

Ogden N2 örneği:

```text
μ1, α1, μ2, α2
```

Metadata ayrıca birim/konvansiyon, izin verilen sınırlar ve model sürüm bilgisini içerir.

## 10. İki malzeme oluşturma yolu

```text
Malzeme Oluşturma
│
├── Doğrudan Parametreler
│      ↓
│  Parametre Doğrulama
│
└── Deneysel Veri
       ↓
   Kalibrasyon
       ↓
   Parametre Kümesi
```

Her iki yol da aynı kanonik `material_parameter_set_t` üretir.

## 11. Deneysel veri kümeleri

Hedef veri aileleri:

- tek eksenli çekme
- basma
- basit kayma
- düzlemsel çekme
- iki eksenli çekme
- hacimsel/sıkıştırılabilirlik

Uygun olduğunda ham test verisi ile işlenmiş/kalibrasyona hazır veri ayrı tutulur; böylece dönüşümler izlenebilir kalır.

## 12. Kalibrasyon sürücüsü

```text
Deneysel Veri Kümesi
       ↓
Test Kinematics Driver
       ↓
Material Core
       ↓
Tahmin Edilen Cevap
       ↓
Objective Function
       ↓
IOptimizer
       ↓
Parametre Kümesi
```

Kalibrasyon ile FEM aynı bünye yasasının farklı kopyalarını asla tutmaz.

Model karşılaştırması yalnız R² üzerinden yapılmaz. Seçim/doğrulama katmanı şunları dikkate alabilir:

- RMSE / residual yapısı
- parametre sınırları
- fiziksel kabul edilebilirlik
- kararlılık kontrolleri
- geçerli şekil değiştirme aralığı
- çoklu test modu tutarlılığı
- ekstrapolasyon davranışı
- ürün seviyesi doğrulama

## 13. Material-point test sürücüsü

Her bünye modeli sonlu eleman mesh'i olmadan test edilebilir.

```text
Tanımlı deformasyon yolu
      ↓
material_kinematics_t
      ↓
Material Core
      ↓
Enerji / Gerilme / Tanjant / State
```

Hedef point-test yolları:

- tek eksenli
- eş iki eksenli
- düzlemsel
- basit kayma
- hacimsel
- gelecekte stateful modeller için çevrimsel yollar

## 14. Tanjant tanısı

Yeni bir malzeme, consistent tangent doğrulanmadan FEM kullanımına uygun sayılmaz.

Sonlu fark referansı:

`A_FD(iJkL) ≈ [P(F + εE_kL) - P(F - εE_kL)] / (2ε)`

Örnek bağıl hata:

`e_A = ||A_analytic - A_FD|| / max(1, ||A_FD||)`

Zincir:

```text
Malzeme uygulaması
        ↓
Enerji testleri
        ↓
Gerilme testleri
        ↓
Tanjant tanısı
        ↓
Material-point testleri
        ↓
FEM kullanımına uygun
```

Tanı aracı üretim yeterliliği sağlandıktan sonra da geliştirme/doğrulama aracı olarak korunur.

## 15. Fiziksel malzeme ve matematiksel uyum

```text
material_definition_t
├── Kimlik
│   ├── polimer ailesi
│   ├── compound ID
│   ├── tedarikçi
│   ├── batch / lot
│   ├── sertlik metadatası
│   ├── yoğunluk metadatası
│   ├── kür/pişirme koşulu
│   └── test/ortam metadatası
├── Deneysel veri kümeleri
├── Parametre kümeleri
│   ├── Yeoh uyumu
│   ├── Ogden uyumu
│   ├── Mooney-Rivlin uyumu
│   └── diğer modeller
└── Doğrulama kayıtları
```

Her kimlik/izlenebilirlik alanı çözücü girdisi değildir; bazı alanlar mühendislik provenance bilgisini korur.

## 16. Provenance / kaynak izlenebilirliği

Her parametre kümesi en az şu bilgileri kaydeder:

- kaynak türü
- kaynak/referans kimliği
- girdi veri kümesi ID'leri
- kalibrasyon motoru sürümü
- malzeme modeli sürümü
- optimizer
- objective tanımı
- parametre sınırları
- uyum metrikleri
- kalibrasyon tarihi
- geçerli şekil değiştirme aralığı
- test sıcaklığı aralığı
- doğrulama durumu
- mevcutsa ürün doğrulama bağlantıları

Sistem şu soruyu cevaplayabilmelidir: **Bu parametre kümesi nereden geldi?**

## 17. Doğrulama durumu

Önerilen durumlar:

```text
REFERENCE
EXPERIMENTAL
CALIBRATED
VERIFIED
PRODUCT_VALIDATED
```

Genel bir literatür değeri `REFERENCE` olarak kalır. Kontrollü deneysel veriden uyarlanmış ve bağımsız/ürün testleriyle doğrulanmış bir compound `PRODUCT_VALIDATED` seviyesine çıkabilir.

## 18. Material Core'un AnalysisPrecheck katkısı

Material Core şu bilgileri raporlar:

- parametre geçerliliği
- eksik zorunlu parametreler
- bünye/formulasyon uyumluluğu
- bilinen geçerlilik aralığı
- yaklaşık sıkıştırılamazlık önerisi/gereksinimi
- sıcaklık aralığı uyarısı
- kararlılık kontrol durumu
- kalibrasyon/doğrulama durumu
- plugin/model sürümü kullanılabilirliği

Global `AnalysisPrecheck` bunları geometri, mesh ve sınır şartı tanılarıyla birleştirir.

## 19. Kanonik harici dönüşümler

Harici çözücü kuralları hiçbir zaman kanonik değildir.

```text
ANSYS Material Parameters
        ↓ adapter
Dyna Canonical Parameter Set

Marc Material Parameters
        ↓ adapter
Dyna Canonical Parameter Set
```

Ters yön ileride export/user-material entegrasyonu için sağlanabilir.

## 20. Gelecekteki çözücü adaptörleri

```text
DynaElastomer Material Core
├── DynaElastomerSolver native
├── ANSYS adapter          [gelecek]
├── Marc UMATERIAL adapter [gelecek]
├── CalculiX adapter       [gelecek]
└── generic material API   [gelecek]
```

## 21. İlk uygulama sırası

### MC-0.1
- `material_kinematics_t`
- `material_response_t`
- `material_model_t`
- `neo_hookean_t`
- material-point test sürücüsü

### MC-0.2
- sayısal tanjant
- tanjant tanısı
- Mooney-Rivlin
- Yeoh

### MC-0.3
- Ogden N1/N2/N3
- Arruda-Boyce
- Gent
- parametre metadatası
- kararlılık/parametre doğrulama

### MC-0.4
- `material_point_state_t`
- committed/trial/revert altyapısı
- plugin lifecycle sözleşmesi

### MC-0.5
- deneysel veri entegrasyonu
- kalibrasyon motoru
- provenance
- doğrulama kayıtları

## 22. Üretim kabul kuralı

Bir bünye modeli aşağıdaki uygun aşamaları geçmeden üretime hazır sayılmaz:

1. parametre doğrulama
2. analitik enerji kontrolleri
3. analitik gerilme kontrolleri
4. sayısal tanjant karşılaştırması
5. material-point testleri
6. kalibrasyon round-trip testleri
7. tek eleman FEM testleri
8. karma/sıkıştırılamazlık uyumluluk testleri
9. mesh yakınsama benchmark'ları
10. bağımsız çözücü karşılaştırması
11. uygun olduğunda deneysel doğrulama

## 23. İlke

> Malzeme bilgisi FEM çözücüsünün içine gömülmez. Kalibrasyon, FEM, point testleri ve gelecekteki harici arayüzler tek kanonik bünye uygulamasını paylaşır; sıkıştırılamazlığın nasıl uygulandığı ise FE formulasyonunun sorumluluğudur.