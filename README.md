# DynaElastomerSolver

DynaElastomerSolver is a scientific engineering platform focused on nonlinear finite-element analysis of rubber and elastomer materials and elastomer-based products.

## Project focus

The project is intentionally **not** a general-purpose CAE package. Its goal is to specialize in elastomer mechanics and provide a focused workflow for:

- large-deformation nonlinear analysis
- plane-strain analysis
- axisymmetric analysis
- axisymmetric torsion
- tension, compression and shear
- nearly-incompressible formulations
- hyperelastic constitutive models
- experimental material calibration
- torque-angle and force-displacement prediction
- solver verification and experimental validation

## Core architecture

```text
DXF
 ↓
AnalysisGeometry
 ↓
Geometry Validation / Topology
 ↓
IMeshProvider
 ↓
InternalMesh
 ↓
Modern Fortran FEM Core
 ↓
ILinearSolver
 ↓
Results
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

## Material models — initial scope

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1 / N2 / N3

The material core is solver-independent. FEM, calibration and material-point verification use the same canonical constitutive implementation.

## Geometry philosophy

DynaElastomerSolver is **not a CAD/sketch application**. Geometry is prepared in an external CAD system and imported primarily through DXF. The application interprets, validates and converts that geometry into analysis regions and boundaries.

## Documentation

- `docs/PROJECT_CONTEXT.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/MATERIAL_CORE_ARCHITECTURE.md`
- `docs/decisions/ADR-0001-FOUNDATION.md`
- `docs/references/OPEN_SOURCE_REFERENCES.md`
- `docs/ROADMAP.md`

## Current status

Architecture and scientific foundations are being defined before implementation. The first implementation milestone will build the constitutive material engine and verification infrastructure before introducing the full FEM solver.
