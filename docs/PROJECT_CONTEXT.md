# DynaElastomerSolver — Project Context

**Current architecture baseline:** v1.2 — ANSYS / Hexagon Marc benchmark revision

## Purpose

DynaElastomerSolver is being developed as a scientific engineering analysis platform specialized in rubber/elastomer materials and the products that use them.

The project deliberately avoids the breadth of a general-purpose CAE package. Instead, engineering effort is concentrated on elastomer constitutive behavior, material calibration, nearly-incompressible finite-element formulations, axisymmetric product analysis, robust nonlinear solution, transparent integration-point results and experimental validation.

## Primary analysis scope

Initial supported physics are planned as:

- 2D plane strain
- 2D plane stress at a later stage
- axisymmetric analysis
- axisymmetric torsion / 2.5D formulation
- tension
- compression
- simple shear
- torque-angle response
- force-displacement response
- finite strain / large deformation
- nearly incompressible elastomer behavior

## Initial material scope

V1.0 target constitutive library:

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1
- Ogden N2
- Ogden N3
- Arruda-Boyce
- Gent

Future material research may add viscoelasticity, rate dependence, Mullins effect, hysteresis, damage and rubber-fatigue/life methods.

## Material philosophy

A physical material and its mathematical constitutive fit are different objects.

```text
Physical Material
  ├── identity / polymer / compound / supplier / lot
  ├── experimental datasets
  ├── calibration records
  ├── one or more constitutive parameter sets
  └── validation records
```

Experimental data, calibrated parameters, model validation and provenance are preserved independently.

The Material Core is solver-independent and is shared by:

- calibration
- FEM
- material-point tests
- future external solver/material adapters

New material models are introduced through a canonical material-model/plugin interface rather than by changing FEM source code.

## Incompressibility philosophy

Constitutive law and FE incompressibility enforcement are separate concerns.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Mixed `u-p` is an early production requirement because rubber/elastomers are nearly incompressible.

## Geometry philosophy

DynaElastomerSolver does not contain a general-purpose 2D sketcher or CAD module.

Geometry is created externally and imported, initially through DXF. The application is responsible only for:

- DXF interpretation
- topology construction
- closed-loop and region detection
- boundary and selection-set identification
- geometry validation/healing
- axis definition
- analysis metadata
- preparation for meshing

The internal geometry representation is owned by DynaElastomerSolver and does not depend on any external DXF library.

## Mesh philosophy

Meshing is externalized through `IMeshProvider`.

Initial implementation:

- Gmsh adapter

Possible future implementations:

- alternative open-source mesher
- imported mesh adapter
- purpose-built `ElastomerMeshProvider`

All providers convert into DynaElastomerSolver's own `InternalMesh` model.

`InternalMesh` includes nodes/elements plus region/boundary/material sets, element orientation, integration metadata and mesh-quality information.

## Analysis precheck

A first-class `AnalysisPrecheck` stage validates the model before solve.

It combines:

- geometry diagnostics
- mesh quality/orientation/connectivity
- material parameter and validity checks
- element/formulation compatibility
- incompressibility strategy compatibility
- boundary-condition completeness
- solver setup checks

Fatal errors block solve; warnings remain visible for engineering review.

## Solver philosophy

The nonlinear finite-element solver is part of DynaElastomerSolver and is written in Modern Fortran.

Production nonlinear solution is not represented by a single Newton class. The architecture uses:

```text
NonlinearSolutionManager
├── NewtonSolver
├── ConvergenceManager
├── IncrementController
├── CutbackManager
├── LineSearch
├── Predictor
├── FailureRecovery
└── StateCommitManager
```

The only external solver initially planned is the low-level sparse linear equation solver used for systems such as:

`K * Δu = -R`

This is hidden behind `ILinearSolver`. Initial candidate: MUMPS.

## Result philosophy

Constitutive fields calculated at integration points are not silently treated as nodal results.

```text
ResultDatabase
├── RawResults
│   ├── nodal primary values
│   └── integration-point values
├── DisplayResults
│   └── extrapolated / averaged fields
└── GlobalHistories
```

V1.0 targets a first-class `GaussPointInspector` in addition to contour, probe, path and history tools.

Elastomer-specific priorities include principal stretch, shear quantities, hydrostatic pressure, `J`, strain-energy density, reaction torque/force, torque-angle and stiffness.

## Experimental validation philosophy

The platform targets a closed engineering chain:

```text
Experimental Material Data
        ↓
Calibration
        ↓
Constitutive Model
        ↓
Nonlinear FEM
        ↓
Physical Product Test
        ↓
Comparison / Error Metrics
        ↓
Validation Record
```

Simulation/test overlay and error metrics are native product features rather than external spreadsheet-only activities.

## Solver controls philosophy

Two user-facing levels are planned:

- **Automatic:** elastomer-focused defaults selected by the application
- **Advanced:** explicit Newton, convergence, increment, cutback, line-search and linear-solver controls for expert users

## Language and platform policy

- Modern Fortran
- Fortran 2018 baseline
- Fortran 2023 features only when portable across supported compilers
- macOS / Apple Silicon: GNU gfortran
- Windows x64: Intel ifx and GNU gfortran validation
- future Linux: GNU gfortran
- CMake as the primary build system
- `ISO_C_BINDING` for the public native API

## Scientific ownership

The following are core project scientific assets:

- canonical material model definitions
- material calibration engine
- material point framework
- constitutive stress/tangent implementation
- Material Plugin API conventions
- FEM kinematics
- mixed nearly-incompressible formulation
- element formulations
- nonlinear solution management
- axisymmetric torsion formulation
- result semantics and extrapolation rules
- verification framework
- experimental validation workflow

External libraries remain replaceable implementation details.

## Commercial-solver benchmark policy

ANSYS Mechanical and Hexagon Marc are used as reference systems for mature engineering behavior, solver robustness, result interpretation and verification.

They are not feature-count targets and do not define DynaElastomerSolver's internal architecture.

## Depo dili politikası

17 Ağustos 2026 itibarıyla DynaElastomerSolver GitHub deposundaki yeni ve güncellenen proje içerikleri Türkçe hazırlanacaktır.

Türkçe kullanılacak alanlar:

- mimari ve tasarım dokümantasyonu
- ADR karar kayıtları
- roadmap ve proje bağlamı açıklamaları
- README açıklamaları güncellendikçe
- issue/PR açıklamaları
- kod içi açıklamalar ve geliştirici notları
- kullanıcıya dönük metinler

Teknik uyumluluk ve yazılım ekosistemi nedeniyle aşağıdaki öğeler gerektiğinde İngilizce kalabilir:

- kaynak kod sembolleri ve public API adları
- sınıf, arayüz, modül ve fonksiyon isimleri
- `des_*` C ABI isimleri
- standart mühendislik terimleri ve standartların resmi adları
- üçüncü taraf kütüphane ve ürün adları
- dosya/klasör isimleri, değiştirmenin teknik fayda sağlamadığı durumlarda

Temel ilke: **insan tarafından okunan proje açıklamaları Türkçe, makine/ABI/ekosistem uyumluluğu gerektiren teknik tanımlayıcılar gerektiğinde İngilizce** olacaktır.
