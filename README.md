# DynaElastomerSolver

DynaElastomerSolver is a scientific engineering platform focused on nonlinear finite-element analysis, material characterization and validation of rubber/elastomer materials and elastomer-based products.

**Current architecture baseline:** `v1.2 — ANSYS / Hexagon Marc benchmark revision`

## Project focus

The project is intentionally **not** a general-purpose CAE package. Its goal is to specialize in elastomer mechanics and provide a focused engineering chain for:

- large-deformation nonlinear analysis
- plane-strain analysis
- axisymmetric analysis
- axisymmetric torsion
- tension, compression and shear
- nearly-incompressible mixed formulations
- hyperelastic constitutive models
- experimental material calibration
- torque-angle and force-displacement prediction
- transparent integration-point results
- independent-solver verification
- physical product-test validation

## Core workflow

```text
Physical Material / Experimental Data
              ↓
      Calibration / Material Core
              ↓
External CAD → DXF
              ↓
      AnalysisGeometry
              ↓
 Geometry Validation / Topology
              ↓
        IMeshProvider
              ↓
         InternalMesh
              ↓
       AnalysisPrecheck
              ↓
 Modern Fortran FEM Core
              ↓
 NonlinearSolutionManager
              ↓
        ILinearSolver
              ↓
        ResultDatabase
              ↓
 Postprocess / Test Comparison
```

The scientific core is written in **Modern Fortran**. External systems such as mesh generators and sparse linear solvers are isolated behind interfaces/adapters so the project does not become dependent on one implementation.

## Numerical stack

- **Language baseline:** Fortran 2018
- **Portable newer features:** selected Fortran 2023 features where supported
- **macOS / Apple Silicon:** GNU gfortran
- **Windows x64:** Intel ifx + GNU gfortran validation
- **Build system:** CMake
- **Initial mesh provider:** Gmsh adapter
- **Initial sparse linear solver:** MUMPS adapter

## Material models — V1.0 target

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1 / N2 / N3
- Arruda-Boyce
- Gent

The Material Core is solver-independent. FEM, calibration, material-point verification and future external solver adapters use the same canonical constitutive implementation.

Constitutive behavior and FE incompressibility enforcement are separate architectural concerns.

## Nonlinear solution architecture

```text
NonlinearSolutionManager
├── NewtonSolver
│   ├── FullNewton
│   └── ModifiedNewton
├── ConvergenceManager
├── IncrementController
├── CutbackManager
├── LineSearch
├── Predictor
├── FailureRecovery
└── StateCommitManager
```

The low-level sparse solver only solves the assembled algebraic system; nonlinear FEM physics and solution management remain project-owned.

## Geometry philosophy

DynaElastomerSolver is **not a CAD/sketch application**. Geometry is prepared in an external CAD system and imported primarily through DXF. The application interprets, validates and converts that geometry into analysis regions, boundaries and selection sets.

## Result philosophy

Raw integration-point physics is kept separate from extrapolated/averaged display results.

```text
ResultDatabase
├── RawResults
│   └── IntegrationPoint
├── DisplayResults
└── GlobalHistories
```

A first-class `GaussPointInspector` is planned for V1.0.

The platform also targets native simulation-to-test comparison for force-displacement and torque-angle validation.

## Documentation

- `docs/PROJECT_CONTEXT.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/decisions/ADR-0002-ANSYS-MARC-BENCHMARK-REVISION.md`
- `docs/benchmarks/ANSYS_MARC_COMPARISON.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`
- `docs/ROADMAP.md`

## Current status

Architecture and scientific foundations are being defined before implementation. The first implementation milestone builds the constitutive material engine and verification infrastructure before introducing the full FEM solver.
