# ADR-0005 — Nonlineer Elastomer Solver Uzmanlaşması

**Durum:** Kabul edildi  
**Tarih:** 2026-08-17

## Bağlam

DynaElastomerSolver genel amaçlı bir CAE platformu olarak değil; kauçuk ve elastomer malzemelerde büyük deformasyon, yaklaşık sıkıştırılamazlık, hiperelastisite, eksenel simetrik ürünler ve burulma problemlerinde uzmanlaşmış bir mühendislik çözücüsü olarak geliştirilmektedir.

ANSYS Mechanical ve Hexagon Marc gibi ticari çözücüler, zor doğrusal olmayan problemlerde sağlamlık açısından referans seviyesindedir. FEBio, PETSc SNES, CalculiX ve FEniCSx gibi açık kaynak sistemler de nonlinear strategy, state yönetimi, mixed formulasyon ve doğrulama açısından önemli mimari dersler sunmaktadır.

Projenin rekabet avantajı, bu sistemlerin genel kapsamını kopyalamak değil; elastomer odaklı çözüm sağlamlığını, açıklanabilirliği ve deneysel doğrulamayı daha derin ele almaktır.

## Karar

DynaElastomerSolver'ın solver geliştirmesi aşağıdaki alanlarda bilinçli olarak uzmanlaştırılacaktır:

1. Sonlu şekil değiştirme ve büyük deformasyon.
2. Yaklaşık sıkıştırılamaz elastomerler için mixed `u-p` formulasyonları.
3. Full Newton, Modified Newton ve Quasi-Newton stratejileri.
4. Line search, adaptive increment, cutback ve retry.
5. Açık `ConvergenceReason` ve `DivergenceReason` kodları.
6. Negative `J`, ciddi eleman distorsiyonu ve mixed-pressure problemlerinin ayrı tanıları.
7. Trial / commit / revert / checkpoint state yönetimi.
8. Linear solver raporlarının nonlinear recovery kararlarında kullanılması.
9. Elastomer problem sınıflarına göre doğrulanmış Automatic solver profilleri.
10. Bağımsız çözücü benchmark'ları ve fiziksel ürün testleriyle doğrulama.

Solver mimarisinin ayrıntılı tanımı `docs/architecture/SOLVER_ARCHITECTURE.md` dosyasında tutulacaktır.

## Sonuçlar

### Olumlu

- Ürün odağı netleşir.
- Geliştirme kaynakları genel amaçlı CAE özellikleri yerine elastomer çözüm kalitesine yönelir.
- Solver başarısızlıkları daha açıklanabilir hale gelir.
- Mixed `u-p`, negative-J ve distortion gibi elastomer için kritik sorunlar birinci sınıf kavram olur.
- Gelecekte viskoelastisite, Mullins, histerezis ve hasar gibi history-dependent modeller için state altyapısı hazırlanır.

### Maliyetler

- Nonlinear solver altyapısı basit Newton döngüsünden daha karmaşık olacaktır.
- Daha geniş regression ve benchmark matrisi gerekecektir.
- Automatic modun güvenilir olması için gerçek problem sınıfları üzerinde ciddi doğrulama gerekecektir.
- Ticari çözücü seviyesinde sağlamlık yalnız mimariyle değil, uzun süreli doğrulama ve hata ayıklamayla kazanılacaktır.

## Kapsam dışı

İlk V1.0 için aşağıdakiler zorunlu değildir:

- genel amaçlı contact çözümü
- geniş multiphysics kapsamı
- yüzlerce farklı eleman ailesi
- arc-length/continuation'ın tüm varyantları
- explicit dynamics
- genel amaçlı metal plasticity kütüphanesi

Bunlar yalnız elastomer ürün hedefleri gerçek bir gereksinim oluşturursa daha sonra değerlendirilir.

## Değiştirilemez ilke

> DynaElastomerSolver'ın solver üstünlüğü özellik sayısından değil; büyük deformasyonlu, yaklaşık sıkıştırılamaz elastomer problemlerinde sağlamlık, şeffaflık ve doğrulamadan gelmelidir.
