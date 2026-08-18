# DynaElastomerSolver — Third-Party Notices

DynaElastomerSolver'ın özgün kodu `LICENSE` dosyasındaki proprietary / all-rights-reserved koşullarına tabidir.

Bu dosyada listelenen üçüncü taraf bileşenler **DynaElastomerSolver proprietary lisansına dönüştürülmez**. Kendi telif sahipleri ve kendi lisans koşulları geçerlidir.

## 1. Fortran stdlib

**Repository:** `https://github.com/kavakfatih/stdlib`  
**Pinlenen commit:** `9a15c7772f1a76a6c497b9f3abb793841fc81f74`  
**Upstream copyright:** `Copyright (c) 2019-2021 stdlib contributors`  
**Lisans:** MIT License

DynaElastomerSolver bu dependency'yi CMake `FetchContent` üzerinden kullanır. Bu dependency için Dyna'nın proprietary lisansı değil, aşağıdaki MIT License geçerlidir.

### MIT License

Copyright (c) 2019-2021 stdlib contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 2. Build / reference / CI araçları

Dyna repository'sinde kullanılan veya CI/reference doğrulamasında çağrılan compiler, BLAS/LAPACK implementasyonları, Python paketleri, FEniCSx/DOLFINx, PETSc, MUMPS, GitHub Actions ve diğer harici araçlar kendi lisansları ve kullanım koşullarına tabidir.

Bu araçların repository içinde yalnızca isimlerinin, adapterlarının, workflow tanımlarının veya entegrasyon çağrılarının bulunması; onların telif haklarının DynaElastomerSolver'a ait olduğu anlamına gelmez.

Bir üçüncü taraf kodu ileride repository içine vendored/copied biçimde alınırsa:

1. lisans uyumluluğu merge öncesinde incelenir,
2. gerekli copyright/license metni bu dosyaya eklenir,
3. gerekiyorsa kaynak dosya seviyesinde notice korunur,
4. proprietary Dyna koduyla sınır açık tutulur.

## 3. Lisans çakışması kuralı

Bir üçüncü taraf bileşenin kendi lisansı ile Dyna'nın `LICENSE` dosyası arasında farklılık varsa, **yalnız o üçüncü taraf bileşen bakımından üçüncü tarafın kendi lisansı uygulanır**.

DynaElastomerSolver'ın özgün kodu için ise `LICENSE` geçerlidir ve açıkça verilmeyen tüm haklar saklıdır.
