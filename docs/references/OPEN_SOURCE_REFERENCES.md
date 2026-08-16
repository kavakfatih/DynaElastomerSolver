# DynaElastomerSolver — Open Source Reference Registry

This is a living registry of open-source projects studied, referenced or potentially used through adapters during DynaElastomerSolver development.

> Rule: an external project's data model must never become the canonical DynaElastomerSolver data model.

## 1. FEBio

- Repository: https://github.com/febiosoftware/FEBio
- Website: https://febio.org/
- License: MIT
- Primary language: C++
- Role for this project: nonlinear FEM and constitutive-material architecture reference
- Priority: very high

Topics to inspect:

- material base classes
- hyperelastic model organization
- material-point state
- stress / consistent-tangent contract
- nearly-incompressible material strategy
- tangent diagnostics
- regression and verification workflow

DynaElastomerSolver interpretation:

```text
FEBio Material Point concept
          ↓
DynaElastomer MaterialPointState
          ↓
MaterialResponse
```

## 2. FEBio Studio

- Repository: https://github.com/febiosoftware/FEBioStudio
- Website: https://febio.org/
- License: MIT
- Primary language: C++
- Role: pre/postprocessing workflow reference
- Priority: medium-high

Focus areas:

- model tree organization
- material assignment
- mesh/result separation
- job management
- model validation
- import/export boundaries

The goal is not to copy the UI; it is to study analysis workflow separation.

## 3. TFEL / MFront

- Repository: https://github.com/thelfer/tfel
- Documentation: https://thelfer.github.io/tfel/
- License: GPL / CeCILL-A family with project-specific linking provisions that must be rechecked before integration
- Primary language: C++
- Role: solver-independent material-behaviour architecture
- Priority: very high

Key idea:

**Material knowledge should be independent of the solver that consumes it.**

Topics to inspect:

- material behaviour definition
- material-point testing / MTest concepts
- external solver interfaces
- parameter metadata
- finite-strain behaviour integration
- behaviour verification

DynaElastomerSolver target:

```text
Material Core
├── FEM
├── Calibration
├── Material Point Tests
└── Future Solver Adapters
```

## 4. CalculiX

- Repository: https://github.com/Dhondtguido/CalculiX
- Website: https://www.calculix.de/
- License: GPL-2.0
- Primary implementation: Fortran-heavy with C components
- Role: real-world Fortran FEM architecture and external sparse-solver integration reference
- Priority: very high

Topics to inspect:

- Fortran FEM organization
- element routines
- global assembly
- nonlinear solution flow
- external sparse solver interfaces
- input-model to solver-model transformation

Policy: primarily an architectural/algorithmic reference. Direct code reuse must respect GPL implications.

## 5. OpenRadioss

- Repository: https://github.com/OpenRadioss/OpenRadioss
- Website: https://www.openradioss.org/
- License: AGPL-3.0
- Role: industrial nonlinear solver workflow, Starter/Engine separation and material-curve input
- Priority: high

Topics to inspect:

- Starter → Engine architecture
- model precheck
- experimental material curves
- direct-parameter vs curve-based material definition
- industrial verification practices
- compiler/build strategy

DynaElastomerSolver interpretation:

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
- Website: https://fenicsproject.org/
- License: LGPL-3.0-or-later
- Primary languages: C++ + Python
- Role: mathematical and variational FEM reference / independent verification environment
- Priority: high for verification, low as a production dependency

Topics to inspect:

- hyperelastic potential-energy formulation
- residual and Jacobian construction
- automatic differentiation
- mixed function spaces
- reference benchmark generation

Planned use: independent verification of new formulations rather than as the core DynaElastomerSolver runtime.

## 7. Gmsh

- Website: https://gmsh.info/
- Official development repository: https://gitlab.onelab.info/gmsh/gmsh
- License: GPL v2 or later; commercial licensing is also offered for incompatible distribution scenarios
- Role: initial mesh provider
- Platforms: Windows, Linux, macOS Intel and macOS ARM
- Priority: high

Integration rule:

```text
AnalysisGeometry
      ↓
GmshMeshProvider
      ↓
InternalMesh
```

The Fortran FEM core never sees Gmsh-native types.

## 8. MUMPS

- Project: MUltifrontal Massively Parallel sparse direct Solver
- Website: https://mumps-solver.org/
- Download: https://mumps-solver.org/index.php?page=dwnld
- License: CeCILL-C
- Role: initial production sparse linear solver candidate
- Priority: high

Scope boundary:

MUMPS solves the assembled algebraic system such as:

`K Δu = -R`

It does not own material physics, FEM formulation, assembly or Newton-Raphson logic.

```text
ILinearSolver
├── Dense/LAPACK
├── MUMPS
├── future PETSc/PARDISO
└── future internal solver
```

## 9. DIME

- Repository: https://github.com/coin3d/dime
- License: BSD-3-Clause
- Language: C++
- Role: free DXF parser/import-adapter candidate
- Priority: medium-high

Potential integration:

```text
DIME
 ↓
DimeDxfAdapter
 ↓
AnalysisGeometry
```

DIME data structures must not escape the adapter boundary.

## 10. Clipper2

- Repository: https://github.com/AngusJohnson/Clipper2
- License: Boost Software License 1.0
- Languages: C++, C#, Delphi
- Role: optional 2D polygon/topology/healing helper
- Priority: conditional

Potential uses:

- polygon intersection
- union/difference
- offset operations

It is not selected as the main mesher.

## 11. Usage classification

### Architectural references

- FEBio
- FEBio Studio
- TFEL/MFront
- CalculiX
- OpenRadioss
- FEniCSx

### Runtime through adapters

- Gmsh
- MUMPS
- DIME, if selected
- Clipper2, only where required

### Independent verification environments

- FEniCSx
- FEBio
- CalculiX
- commercial ANSYS / Hexagon Marc benchmarks where available

## 12. License policy

| Project | License | Default project policy |
|---|---|---|
| FEBio | MIT | architectural reference; reuse may be evaluated |
| FEBio Studio | MIT | workflow reference |
| TFEL/MFront | GPL/CeCILL-related | architecture reference; integration requires license review |
| CalculiX | GPL-2.0 | reference; avoid casual code copying into incompatible distribution |
| OpenRadioss | AGPL-3.0 | reference |
| DOLFINx | LGPL-3.0-or-later | verification/reference |
| Gmsh | GPL-2+ / commercial option | adapter; distribution model must be reviewed |
| MUMPS | CeCILL-C | adapter; license review before distribution |
| DIME | BSD-3-Clause | strong DXF-adapter candidate |
| Clipper2 | Boost-1.0 | optional geometry utility candidate |

This table is a technical project record, not legal advice. Licenses must be rechecked for the exact version and integration/distribution method before release.

## 13. Review priority

1. FEBio — MaterialPoint, hyperelasticity, tangent/state
2. TFEL/MFront — solver-independent material architecture
3. CalculiX — Fortran FEM and sparse-solver integration
4. OpenRadioss — material curves and analysis precheck
5. FEniCSx — mathematical verification
6. DIME — DXF import
7. Gmsh — mesh adapter
8. MUMPS — linear-solver adapter
9. Clipper2 — geometry utilities if needed

## 14. Project principle

DynaElastomerSolver may learn from open-source projects and use appropriately licensed components, but its scientific data model, constitutive models, calibration system, FEM formulations and nonlinear solution architecture remain project-owned and implementation-independent.
