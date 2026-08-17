# DynaElastomerSolver — Açık Kaynak Referans Kaydı

Bu belge, DynaElastomerSolver geliştirilirken incelenen veya adaptörler üzerinden kullanılması değerlendirilen açık kaynak projelerin yaşayan kaydıdır.

> Kural: Harici bir projenin veri modeli hiçbir zaman DynaElastomerSolver'ın kanonik veri modeli haline gelemez.

## 1. FEBio

- Repository: https://github.com/febiosoftware/FEBio
- Web: https://febio.org/
- Lisans: MIT
- Dil: C++
- Rol: nonlinear FEM ve bünye malzeme mimarisi referansı
- Öncelik: çok yüksek

İncelenecek başlıklar: material base class yapısı, hyperelastic model organizasyonu, MaterialPoint state, stress/consistent tangent sözleşmesi, yaklaşık sıkıştırılamazlık stratejisi ve regression/doğrulama yaklaşımı.

```text
FEBio Material Point
        ↓
Dyna MaterialPointState
        ↓
MaterialResponse
```

## 2. FEBio Studio

- Repository: https://github.com/febiosoftware/FEBioStudio
- Lisans: MIT
- Dil: C++
- Rol: pre/postprocessing ve model iş akışı referansı
- Öncelik: orta-yüksek

Model tree, malzeme atama, mesh/result ayrımı, job yönetimi ve model doğrulama incelenir. Amaç UI'yi kopyalamak değil analiz iş akışını anlamaktır.

## 3. TFEL / MFront

- Repository: https://github.com/thelfer/tfel
- Dokümantasyon: https://thelfer.github.io/tfel/
- Lisans: GPL / CeCILL-A ailesi; entegrasyon öncesi kesin şartlar tekrar kontrol edilmelidir
- Dil: C++
- Rol: solver-independent material behaviour mimarisi
- Öncelik: çok yüksek

Ana ilke: **Malzeme bilgisi onu kullanan solver'dan bağımsız olmalıdır.**

İncelenecek başlıklar: material behaviour tanımı, MTest/material-point testing, harici solver arayüzleri, parametre metadatası, finite-strain entegrasyonu ve doğrulama.

## 4. CalculiX

- Repository: https://github.com/Dhondtguido/CalculiX
- Web: https://www.calculix.de/
- Lisans: GPL-2.0
- Uygulama: Fortran ağırlıklı, C bileşenleri
- Rol: gerçek dünya Fortran FEM ve harici sparse-solver entegrasyon referansı
- Öncelik: çok yüksek

Fortran FEM organizasyonu, element rutinleri, global assembly, nonlinear solution flow ve sparse solver arayüzleri incelenir. Doğrudan kod kullanımı GPL etkileri nedeniyle ayrı değerlendirilmelidir.

## 5. OpenRadioss

- Repository: https://github.com/OpenRadioss/OpenRadioss
- Web: https://www.openradioss.org/
- Lisans: AGPL-3.0
- Rol: endüstriyel nonlinear solver iş akışı, Starter/Engine ayrımı ve material-curve input
- Öncelik: yüksek

```text
AnalysisModel
     ↓
AnalysisPrecheck
     ↓
Validated SolverInput
     ↓
Nonlinear Engine
```

## 6. FEniCSx / DOLFINx

- Repository: https://github.com/FEniCS/dolfinx
- Web: https://fenicsproject.org/
- Lisans: LGPL-3.0-or-later
- Diller: C++ + Python
- Rol: matematiksel/varyasyonel FEM referansı ve bağımsız doğrulama ortamı
- Öncelik: doğrulama için yüksek, üretim bağımlılığı olarak düşük

Hyperelastic potential-energy, residual/Jacobian, automatic differentiation ve mixed function spaces yeni formulasyonların doğrulanmasında referans olacaktır.

## 7. Gmsh

- Web: https://gmsh.info/
- Repository: https://gitlab.onelab.info/gmsh/gmsh
- Lisans: GPL v2+; ayrıca commercial licensing seçeneği
- Rol: ilk mesh sağlayıcısı
- Platformlar: Windows, Linux, macOS Intel ve macOS ARM
- Öncelik: yüksek

```text
AnalysisGeometry
      ↓
GmshMeshProvider
      ↓
InternalMesh
```

Fortran FEM çekirdeği Gmsh native tiplerini görmez.

## 8. MUMPS

- Web: https://mumps-solver.org/
- Lisans: CeCILL-C
- Rol: ilk üretim sparse linear solver adayı
- Öncelik: yüksek

MUMPS yalnız kurulmuş cebirsel sistemi çözer:

`K Δu = -R`

Malzeme fiziği, FEM formulasyonu, assembly ve Newton-Raphson mantığı Dyna'ya aittir.

## 9. DIME

- Repository: https://github.com/coin3d/dime
- Lisans: BSD-3-Clause
- Dil: C++
- Rol: DXF parser/import-adapter adayı
- Öncelik: orta-yüksek

```text
DIME
 ↓
DimeDxfAdapter
 ↓
AnalysisGeometry
```

DIME veri yapıları adaptör sınırı dışına çıkmaz.

## 10. Clipper2

- Repository: https://github.com/AngusJohnson/Clipper2
- Lisans: Boost Software License 1.0
- Diller: C++, C#, Delphi
- Rol: isteğe bağlı 2D polygon/topoloji/iyileştirme yardımcısı
- Öncelik: koşullu

Polygon intersection, union/difference ve offset işlemleri için değerlendirilebilir; ana mesher değildir.

## 11. Kullanım sınıflandırması

### Mimari referanslar
FEBio, FEBio Studio, TFEL/MFront, CalculiX, OpenRadioss, FEniCSx.

### Runtime adaptörleri
Gmsh, MUMPS, seçilirse DIME ve gerektiğinde Clipper2.

### Bağımsız doğrulama ortamları
FEniCSx, FEBio, CalculiX ve mevcut olduğunda ANSYS / Hexagon Marc benchmark'ları.

## 12. Lisans politikası

| Proje | Lisans | Proje yaklaşımı |
|---|---|---|
| FEBio | MIT | mimari referans; yeniden kullanım değerlendirilebilir |
| FEBio Studio | MIT | workflow referansı |
| TFEL/MFront | GPL/CeCILL ilişkili | entegrasyon lisans incelemesi gerektirir |
| CalculiX | GPL-2.0 | referans; uyumsuz dağıtımda doğrudan kod kopyalanmaz |
| OpenRadioss | AGPL-3.0 | referans |
| DOLFINx | LGPL-3.0-or-later | doğrulama/referans |
| Gmsh | GPL-2+ / commercial | adaptör; dağıtım modeli ayrıca incelenir |
| MUMPS | CeCILL-C | adaptör; dağıtım öncesi lisans kontrolü |
| DIME | BSD-3-Clause | güçlü DXF adaptör adayı |
| Clipper2 | Boost-1.0 | isteğe bağlı geometri yardımcısı |

Bu tablo teknik proje kaydıdır, hukuki görüş değildir. Yayın öncesi tam sürüm ve entegrasyon/dağıtım yöntemi için lisanslar yeniden kontrol edilmelidir.

## 13. İnceleme önceliği

1. FEBio — MaterialPoint, hyperelasticity, tangent/state
2. TFEL/MFront — solver-independent material mimarisi
3. CalculiX — Fortran FEM ve sparse-solver entegrasyonu
4. OpenRadioss — material curve ve analysis precheck
5. FEniCSx — matematiksel doğrulama
6. DIME — DXF import
7. Gmsh — mesh adaptörü
8. MUMPS — linear-solver adaptörü
9. Clipper2 — gerektiğinde geometri yardımcıları

## 14. Proje ilkesi

DynaElastomerSolver açık kaynak projelerden öğrenebilir ve uygun lisanslı bileşenleri kullanabilir; ancak bilimsel veri modeli, bünye modelleri, kalibrasyon sistemi, FEM formulasyonları ve doğrusal olmayan çözüm mimarisi projeye ait ve uygulamadan bağımsız kalır.