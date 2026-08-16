# ADR-0002 — ANSYS / Hexagon Marc Benchmark Revision

**Status:** Accepted  
**Project:** DynaElastomerSolver  
**Architecture target:** v1.2

## Context

The foundational architecture was compared against the elastomer/nonlinear analysis workflow of ANSYS Mechanical and Hexagon Marc/Mentat. The purpose was not feature parity. The benchmark was used to identify mature architectural patterns that matter directly to rubber/elastomer engineering.

The comparison focused on:

- material definition
- hyperelastic material models
- experimental curve fitting
- geometry and geometry preparation
- meshing and mesh controls
- nearly-incompressible formulations
- nonlinear solution strategy
- sparse linear solution
- solver controls
- integration-point results
- postprocessing
- experiment/simulation validation

## Decision 1 — Keep the specialized product boundary

DynaElastomerSolver remains an elastomer engineering platform, not a general-purpose ANSYS/Marc clone.

General CAD, broad multiphysics, CFD, electromagnetics, large beam/shell catalogs and general-purpose metal plasticity are not added merely because commercial CAE systems provide them.

## Decision 2 — Add first-class AnalysisPrecheck

Mature CAE workflows validate model consistency before or during solve setup. DynaElastomerSolver therefore introduces:

```text
AnalysisModel
    ↓
AnalysisPrecheck
    ↓
Validated SolverInput
    ↓
Solve
```

Precheck aggregates geometry, mesh, material, formulation and boundary-condition diagnostics.

Fatal errors block solve. Engineering warnings remain visible but may be overridable later under controlled expert workflows.

## Decision 3 — Add native material-plugin architecture

Marc user-material extensibility and the solver-independent material concepts studied in open-source systems reinforce the need for a stable material contract.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

A new material model must not require FEM source changes.

## Decision 4 — Separate incompressibility enforcement from constitutive law

Hyperelastic constitutive science and FE constraint enforcement are explicitly separated.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

Mixed `u-p` is an FE-formulation technology, not a property hard-coded into Yeoh, Ogden or other material classes.

## Decision 5 — Replace monolithic nonlinear solver design

The old `NonlinearSolver` abstraction is refined into:

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

This reflects the fact that production nonlinear robustness comes from coordination of multiple mechanisms, not Newton iteration alone.

## Decision 6 — Add Automatic and Advanced solver-control modes

Commercial solvers expose extensive nonlinear controls, but DynaElastomerSolver will not force all complexity onto normal users.

### Automatic

The software selects sensible elastomer-specific defaults for incrementing, convergence, Newton strategy and linear solver.

### Advanced

Expert users may control Newton type, convergence tolerances, increment limits, line search, cutback and backend selection.

## Decision 7 — Expand InternalMesh metadata

`InternalMesh` now includes more than nodes/elements:

```text
InternalMesh
├── Nodes
├── Elements
├── ElementSets
├── BoundarySets
├── RegionSets
├── MaterialRegions
├── ElementOrientation
├── IntegrationScheme
├── MeshQuality
└── Metadata
```

Orientation, integration and quality are required for trustworthy analysis and diagnostics.

## Decision 8 — Separate raw and display results

Stress and related constitutive quantities originate at integration points. Display systems may extrapolate/average them to nodes.

DynaElastomerSolver makes this distinction explicit:

```text
ResultDatabase
├── RawResults
│   └── IntegrationPoint
└── DisplayResults
    └── Extrapolated/Averaged
```

A displayed contour must not obscure the origin/transformation of the data.

## Decision 9 — GaussPointInspector is a V1.0 engineering feature

Direct integration-point inspection is valuable for constitutive verification, mixed formulations and investigation of high-strain rubber regions.

The V1.0 postprocessor therefore includes a first-class Gauss-point inspection path.

## Decision 10 — Native experiment/FEA comparison

DynaElastomerSolver treats physical validation as part of the product, not an external spreadsheet activity.

```text
FEA Result
   +
Physical Product Test
        ↓
Overlay
        ↓
Error Metrics
        ↓
Validation Record
```

Target metrics include RMSE, maximum/mean error, relative error and stiffness error.

## Decision 11 — Extend the initial hyperelastic library

The V1.0 target material family becomes:

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1/N2/N3
- Arruda-Boyce
- Gent

This remains intentionally smaller than general commercial libraries but covers a stronger practical elastomer baseline.

## Decision 12 — Preserve the project-owned nonlinear FEM core

ANSYS and Marc comparisons do not change the ownership boundary:

DynaElastomerSolver owns:

- kinematics
- material models
- element formulations
- assembly
- mixed formulation logic
- nonlinear solution management
- convergence/cutback logic
- result semantics

A replaceable external sparse solver may solve the algebraic system only.

## Decision 13 — Keep geometry narrow

Commercial systems include broad CAD/geometry tools. DynaElastomerSolver does not adopt that scope.

The geometry subsystem provides only:

- DXF import
- topology interpretation
- region/boundary/selection definitions
- validation
- controlled healing
- axis definition
- mesh preparation

No internal sketcher is added.

## Consequences

### Positive

- architecture better reflects production nonlinear-solver needs
- integration-point physics becomes transparent
- material extensibility improves
- solver controls remain usable for both normal and expert users
- mixed incompressibility infrastructure is cleaner
- experimental validation becomes a native workflow
- mesh and solver diagnostics become auditable

### Cost

- more interfaces and state-management code
- more verification cases
- result extrapolation/averaging must be tested independently
- nonlinear control logic becomes a substantial engineering subsystem
- Material Plugin API requires strict ABI/versioning discipline

## Benchmark principle

ANSYS and Marc are reference systems for mature behavior and verification, not implementation templates to copy blindly.

> Adopt mature engineering principles where they strengthen elastomer analysis; reject breadth that does not serve the specialized product.
