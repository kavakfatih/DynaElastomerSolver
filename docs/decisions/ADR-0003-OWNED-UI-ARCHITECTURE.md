# ADR-0003 — Projeye Ait UI Mimarisi

**Durum:** Kabul edildi  
**Proje:** DynaElastomerSolver

## Bağlam

DynaElastomerSolver, ANSYS benzeri bilgi mimarisine sahip ancak görsel olarak farklı, minimal ve teknik bir profesyonel mühendislik masaüstü arayüzüne ihtiyaç duyar. Açık kaynak CAE sistemleri yararlı fikirler sağlayabilir; ancak harici bir CAE uygulamasının veya UI framework'ünün proje durumunun, mühendislik davranışının ya da ürün kimliğinin sahibi haline gelmesi kabul edilemez bir bağımlılık oluşturur.

## Karar

DynaElastomerSolver kullanıcı deneyimi mimarisinin tamamına kendisi sahip olacaktır.

Projeye ait bileşenler:

- AppShell anlamı
- modül sistemi
- Navigator yapısı
- Workspace modeli
- Inspector şemaları
- seçim modeli
- command sistemi
- undo/redo davranışı
- solve monitor anlamı
- result pipeline
- doğrulama iş akışı
- görselleştirme veri modeli
- design system

Harici framework'ler windowing, input, text, GPU çizimi, kontroller ve OS entegrasyonu gibi frontend/platform yetenekleri sağlayabilir; ancak değiştirilebilir uygulamalar olarak kalmalıdır.

## Ana bilgi mimarisi

ANSYS Mechanical şu alanlarda ana yapısal referanstır:

- hiyerarşik mühendislik nesneleri
- selection → properties davranışı
- bağlamsal komutlar
- merkezi mühendislik viewport/workspace
- model hazır olma ve çözüm durumu

Dyna, ANSYS'in görsel stilini veya sürekli yoğun Ribbon/büyük global tree yaklaşımını kopyalamaz.

İkincil referanslar:

- FEBio Studio: model organizasyonu ve solve monitor
- SALOME: modüler application shell
- PrePoMax: sade FEA etkileşim modeli
- Gmsh: minimal mühendislik workspace'i
- ParaView: result pipeline, properties ve Basic/Advanced ayrımı
- ElmerGUI: object browser ve metadata-driven registration
- FEniCSx/MFront: UI'nin bilimsel çekirdekten bağımsızlığı

## Application shell

```text
Bağlamsal Araç Çubuğu
      ↓
Navigator | Workspace | Inspector
      ↓
Yardımcı / Solver / Yakınsama Paneli
```

Üst seviye modüller:

```text
Project
Geometry
Material Lab
Mesh
Analysis
Solve
Results
Validation
```

## Framework politikası

UI framework'ü ürün mimarisi değil altyapıdır.

Framework seçimi sonraki karar kaydıyla yönetilir:

- **ADR-0004 — Değiştirilebilir UI Sınırı Arkasında Qt Frontend**

Qt 6 / Qt Quick-QML ilk üretim frontend'i olarak seçilmiştir; ancak hiçbir bilimsel, domain, kanonik proje veya framework-neutral presentation modeli Qt tiplerine bağımlı olamaz.

Bu, ADR-0003'ün temel ilkesini korur: deneyim Dyna'ya aittir; framework yalnız uygular.

## Görselleştirme kararı

DynaElastomerSolver başlangıçta ParaView/VTK/FEBio Studio'yu görselleştirme ortamı olarak gömmeyecektir.

V1.0 2D ve eksenel simetrik analize odaklandığı için proje `ViewportSceneModel`, geometri/mesh/result semantics, selection overlay ve engineering probe'ların sahibidir. Mevcut frontend renderer sınırı arkasında Qt rendering altyapısı kullanabilir.

Gelecekte `IViewportRenderer` başka bir rendering teknolojisi kullanabilir.

## Sonuçlar

### Olumlu

- ürün kimliği bağımsız kalır
- ANSYS benzeri iş akışı elastomer mühendisliği için sadeleştirilebilir
- Material Lab ve deneysel doğrulama birinci sınıf deneyimler olabilir
- solver UI, Fortran solver'dan bağımsız gelişebilir
- frontend teknolojisi bilimsel veri yapıları değiştirilmeden değiştirilebilir
- lisans maruziyeti frontend bağımlılık sınırında lokal tutulur

### Maliyetler

- AppShell, navigation, selection, inspector ve result UX içeride geliştirilmelidir
- custom viewport ve engineering interaction özel uygulama/test gerektirir
- Windows ve macOS davranışı ayrı ayrı doğrulanmalıdır
- neutral presentation contracts ile aktif frontend arasında adaptör gerekir

## Yönlendirici ilke

> DynaElastomerSolver UI teknolojisi kullanabilir; ancak kullanıcı deneyimini dışarıya devretmez.