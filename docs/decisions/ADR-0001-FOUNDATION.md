# ADR-0001 — Temel Mimari Kararlar

**Durum:** Kabul edildi  
**Proje:** DynaElastomerSolver

## Bağlam

Proje, kauçuk/elastomer malzemeler ve ürünler için uzmanlaşmış bilimsel bir analiz platformu gerektirir. Tasarım; tek bir mesh üreticisine, seyrek çözücüye, CAD kernel'ına veya derleyiciye bağımlı olmadan uzun vadeli gelişimi desteklemelidir.

## Kararlar

### 1. Ürün kapsamı

DynaElastomerSolver genel amaçlı bir CAE klonu değil, uzmanlaşmış elastomer mühendisliği platformu olacaktır.

İlk odak:

- büyük deformasyon
- hiperelastisite
- yaklaşık sıkıştırılamaz davranış
- düzlem şekil değiştirme
- eksenel simetrik analiz
- eksenel simetrik burulma
- çekme, basma ve kayma
- malzeme kalibrasyonu
- kuvvet–yer değiştirme ve tork–açı cevabı

### 2. Bilimsel çekirdek dili

Hesaplama çekirdeği Modern Fortran kullanacaktır.

- temel: Fortran 2018
- desteklendiği yerde taşınabilir Fortran 2023 özellikleri kullanılabilir
- macOS/Apple Silicon derleyicisi: GNU gfortran
- Windows derleyicisi: Intel ifx, GNU gfortran ile doğrulama
- build sistemi: CMake

### 3. Kalibrasyon Fortran içinde kalır

Malzeme kalibrasyonu, objective function'lar ve optimizer'lar; malzeme modelleri ve FEM ile aynı hesaplama çekirdeğinin parçasıdır.

Neden: kalibrasyon ve FEM birebir aynı bünye uygulamasını kullanmalıdır.

### 4. Dahili CAD/eskiz sistemi yok

Program 2D çizim uygulamasına dönüşmeyecektir.

Geometri dışarıda oluşturulur ve başlangıçta DXF ile içe aktarılır. İç sistem yalnız analiz geometrisini yorumlar, doğrular ve modeller.

### 5. Kanonik iç geometri modeli

DXF entity'leri projeye ait `AnalysisGeometry` yapılarına dönüştürülür.

Hiçbir DXF kütüphanesi veya CAD kernel'ı iç analiz veri modelini tanımlayamaz.

### 6. Değiştirilebilir mesh sistemi

Mesh üretimine `IMeshProvider` üzerinden erişilir.

İlk aday: Gmsh adaptörü.

Tüm sağlayıcılar `InternalMesh` üretir. Gelecekte elastomere özgü mesh üreticisi FEM değiştirilmeden eklenebilir.

### 7. FEM solver projeye ait kalır

Doğrusal olmayan FEM solver, eleman formulasyonları, malzeme modelleri, assembly ve Newton-Raphson mantığı DynaElastomerSolver bileşenleridir.

Başlangıçta yalnız düşük seviyeli seyrek cebirsel sistem çözücüsü harici olabilir.

### 8. Değiştirilebilir seyrek doğrusal solver

Seyrek doğrusal çözüme `ILinearSolver` üzerinden erişilir.

İlk aday: MUMPS.

Gelecekte PETSc/PARDISO veya dahili uygulama değerlendirilebilir.

### 9. Enerji tabanlı hiperelastik malzeme mimarisi

Hiperelastik modeller strain-energy density üzerinden tanımlanır ve kanonik material response döndürür.

Hedef cevap:

- strain energy
- stress measures
- consistent tangent
- Jacobian
- state/status

### 10. Malzeme bilimi solver'dan bağımsızdır

Material Core şu sistemler tarafından ortak kullanılır:

- FEM
- kalibrasyon
- material-point testleri
- gelecekteki harici solver adaptörleri

Aynı Yeoh/Ogden uygulaması kalibrasyon ve FEM arasında kopyalanmamalıdır.

### 11. MaterialPoint state ilk günden bulunur

İlk hiperelastik modeller history-independent olsa bile integrasyon noktaları committed/trial/history state altyapısını destekler.

Bu yaklaşım daha sonra viskoelastisite, Mullins etkisi, histerezis ve hasarın bünye arayüzü bozulmadan eklenmesini sağlar.

### 12. İzokorik ve hacimsel davranış ayrıdır

Bünye malzeme bilimi ile sıkıştırılamazlığın uygulanması farklı konulardır.

Karma `u-p` teknolojisi her malzeme modeline gömülmez; FEM formulasyon altyapısına aittir.

### 13. Karma u-p erken üretim gereksinimidir

Yalnız yer değiştirme kullanan Q4 elemanı temel/doğrulama elemanı olarak kullanılacaktır.

Elastomerler yaklaşık sıkıştırılamaz olduğundan karma displacement-pressure formulasyonu yol haritasının erken aşamasına alınır ve üretim sınıfı elastomer elemanları için zorunludur.

### 14. Genelleştirilmiş alanlar / DOF'lar

DOF'lar eleman ailesine hard-code edilmez.

Hedef alanlar:

- displacement
- twist `φ`
- pressure `p`

Bu altyapı düzlem, eksenel simetrik ve eksenel simetrik burulma formulasyonlarını ortak sistemde destekler.

### 15. Eksenel simetrik burulma temel farklılaştırıcıdır

Hedef formulasyon genelleştirilmiş twist ile 2D meridyen mesh'i kullanır.

Birincil DOF'lar:

`ur, uz, φ`

Yaklaşık sıkıştırılamaz karma formulasyon:

`ur, uz, φ, p`

Bu sayede dönel simetrik ürünlerde tam 3D mesh olmadan tork–açı tahmini yapılabilir.

### 16. Doğrusal olmayan sağlamlık modülerdir

Doğrusal olmayan solver mimarisi şunları desteklemelidir:

- Newton-Raphson
- yakınsama izleme
- load stepping
- adaptive increments
- cutback
- line search
- gelecekte arc-length

### 17. Doğrulama uygulamanın parçasıdır

İlgili doğrulamalar olmadan bir özellik tamamlanmış sayılmaz.

Gerekli seviyeler:

- matematiksel testler
- bünye testleri
- tanjant tanıları
- tek eleman testleri
- mesh yakınsaması
- bağımsız solver karşılaştırması
- mümkün olduğunda deneysel doğrulama

### 18. Açık kaynak politikası

Açık kaynak sistemler incelenebilir ve uygun lisanslı bileşenler kullanılabilir; ancak tüm runtime bağımlılıkları adaptör sınırlarında izole edilir.

Birincil referanslar:

- FEBio
- FEBio Studio
- TFEL/MFront
- CalculiX
- OpenRadioss
- FEniCSx
- Gmsh
- MUMPS
- DIME
- Clipper2

Dağıtım öncesi lisanslar ayrıca kontrol edilir.

### 19. Public ABI

Fortran iç OOP yapıları doğrudan dışarı açılmaz.

Public native ABI `ISO_C_BINDING` ve kararlı C uyumlu arayüz kullanır.

Prefix: `des_`.

Hedef native kütüphane adları:

- Windows: `DynaElastomerCore.dll`
- macOS: `libDynaElastomerCore.dylib`
- Linux: `libDynaElastomerCore.so`

## Sonuçlar

### Olumlu

- bilimsel çekirdek proje kontrolünde kalır
- harici mesh/linear-solver teknolojileri değiştirilebilir
- Mac ve Windows geliştirmesi aynı Fortran kaynak tabanını paylaşır
- bünye modelleri kalibrasyon ve FEM arasında yeniden kullanılabilir
- yeni elastomer fiziği temel soyutlamalar bozulmadan eklenebilir
- açık kaynak araştırmaları harici veri modelleri miras alınmadan stratejik kullanılabilir

### Maliyet / ödünleşimler

- daha fazla interface/adaptör bakımı gerekir
- kanonik geometri ve mesh modelleri dikkatle tasarlanmalıdır
- karma formulasyonlar ve consistent tangent erken karmaşıklığı artırır
- doğrulama birinci sınıf geliştirme maliyetidir

## Yönlendirici ilke

> DynaElastomerSolver elastomer biliminin ve kanonik mühendislik modelinin sahibidir; harici araçlar değiştirilebilir sayısal altyapıdır.