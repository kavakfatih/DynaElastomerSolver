# DynaElastomerSolver Roadmap

**Architecture baseline:** v1.2 — ANSYS / Hexagon Marc benchmark revision

Version numbers below are development milestones, not release promises.

## V0.1 — Computational Foundation

Goal: establish a portable, testable Modern Fortran scientific core before FEM implementation.

Deliverables:

- CMake cross-platform project
- Fortran 2018 baseline
- gfortran macOS build
- ifx Windows build
- gfortran Windows validation build
- precision / constants / status modules
- matrix and tensor utilities
- deformation-gradient utilities
- invariants
- material model abstract interfaces
- material kinematics / response types
- Neo-Hookean implementation
- material-point test driver
- analytical energy/stress tests
- numerical tangent checker

Exit criterion: Neo-Hookean material response is compiler-independent within defined tolerances and passes constitutive verification.

## V0.2 — Hyperelastic Material Library

Deliverables:

- Mooney-Rivlin
- Yeoh
- Ogden N1
- Ogden N2
- Ogden N3
- Arruda-Boyce
- Gent
- parameter metadata
- canonical parameter conventions
- parameter validation
- constitutive stability/admissibility checks
- tangent diagnostics for every model

Exit criterion: every model passes the Material Core production-eligibility pipeline up to material-point verification.

## V0.3 — Calibration Engine / Material Lab Foundation

Deliverables:

- physical material record
- experimental dataset model
- raw vs processed test-data traceability
- uniaxial tension data path
- engineering stress/strain transformation utilities
- objective-function API
- optimizer interface
- initial optimizer(s)
- parameter bounds
- RMSE / R² / residual metrics
- calibration provenance
- material parameter-set storage
- model comparison
- validation-status model

Then extend toward:

- compression
- simple shear
- planar tension
- biaxial tension
- volumetric/compressibility data

Exit criterion: calibration round-trip tests reproduce known synthetic parameter sets within tolerance, with provenance retained.

## V0.4 — FEM Verification Foundation

Goal: build the first complete nonlinear FEM chain using a simple verification element.

Deliverables:

- node / element / `InternalMesh` model
- generalized DOF manager
- Q4 plane-strain verification element
- shape functions
- Gauss integration
- deformation-gradient calculation
- element residual
- consistent tangent
- global assembly
- displacement boundary conditions
- basic Newton solver
- convergence monitoring
- simple dense/LAPACK linear solver path for small tests
- first `AnalysisPrecheck` framework
- first raw integration-point result storage

Exit criterion: Neo-Hookean plane-strain benchmarks and mesh-convergence tests pass and invalid basic models are rejected before solve.

## V0.5 — Mixed u-p / Incompressibility Foundation

Goal: move from verification-only displacement elements to production-oriented nearly-incompressible elastomer technology.

Deliverables:

- pressure field
- generalized mixed DOF infrastructure
- `IIncompressibilityStrategy`
- mixed residual/tangent blocks
- mixed element formulation research/implementation
- incompressibility verification
- volumetric-locking comparison against displacement-only formulation
- material/formulation compatibility checks in `AnalysisPrecheck`

Exit criterion: benchmark problems demonstrate stable nearly-incompressible behavior without unacceptable locking.

## V0.6 — Axisymmetric Analysis

Deliverables:

- axisymmetric kinematics
- `ur, uz` formulation
- mixed `ur, uz, p` formulation
- `2πR` integration
- axisymmetric boundary/selection sets
- axisymmetric geometry checks
- axisymmetric benchmark suite

Exit criterion: analytical/reference axisymmetric benchmarks and mesh convergence pass.

## V0.7 — Axisymmetric Torsion

This is a core project differentiator.

Deliverables:

- generalized twist field `φ`
- `ur, uz, φ` kinematics
- mixed `ur, uz, φ, p` formulation
- prescribed rotation boundary condition
- reaction torque
- torque-angle history
- torsional stiffness calculation
- torsion-specific convergence quantities where useful
- torsion benchmark suite

Exit criterion: DynaElastomerSolver results agree with independent reference solvers and selected physical torsion tests within defined engineering tolerances.

## V0.8 — Nonlinear Solution Manager / Robustness

Goal: evolve the foundation Newton loop into a production-oriented nonlinear solution subsystem.

Deliverables:

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

Additional requirements:

- automatic load stepping
- initial/minimum/maximum increment controls
- step growth
- cutback and retry policy
- multiple convergence criteria
- residual force monitoring
- moment/torque monitoring where applicable
- displacement/rotation correction monitoring
- negative-J / severe element-distortion detection
- robust state rollback / commit
- detailed convergence history
- Automatic and Advanced solver-control modes

Future research:

- arc-length / continuation methods
- stabilization techniques
- advanced predictor strategies

Exit criterion: defined difficult nonlinear benchmarks converge reproducibly with documented step/cutback histories.

## V0.9 — Engineering Pre/Post Processor

### Geometry

- DXF import adapter
- project-owned `AnalysisGeometry`
- line / arc / spline interpretation
- loop/region construction
- geometry validation/healing
- Geometry Check → Repair → Recheck workflow
- layer metadata
- axis definition
- named boundaries
- `SelectionSet`

No general-purpose sketch/CAD tools are planned.

### Mesh

- `IMeshProvider`
- Gmsh adapter
- expanded `InternalMesh`
- element/boundary/region/material sets
- element orientation metadata
- integration-scheme metadata
- mesh-quality metadata
- boundary/region mapping
- `MeshPrecheck`
- global size
- edge size / division controls
- local/region refinement
- mapped/structured quad request where supported

### Analysis precheck

Integrate validation from:

- geometry
- mesh
- material
- element/formulation
- boundary conditions
- solver configuration

Fatal errors block solution; nonfatal concerns are shown as warnings.

### Results

Implement explicit separation:

```text
ResultDatabase
├── RawResults
│   ├── nodal primary results
│   └── integration-point results
├── DisplayResults
│   └── extrapolated/averaged nodal fields
└── GlobalHistories
```

User-facing tools:

- displacement/stretch/stress/pressure/J/energy contours
- result scoping
- min/max
- node probe
- element probe
- `GaussPointInspector`
- path
- charts/history
- reaction force/torque
- force-displacement
- torque-angle
- tangent/secant stiffness
- derived results
- CSV export
- engineering report

### Experimental comparison

- import product-test history
- simulation/test overlay
- RMSE
- maximum/mean/relative error
- stiffness error
- comparison validity range

Exit criterion: a complete DXF → mesh → solve → inspect → compare-to-test workflow can be performed without external postprocessing software.

## V1.0 — Validated Elastomer Analysis Platform

Target workflow:

```text
Physical Material / Experimental Data
 ↓
Calibration / Material Validation
 ↓
DXF
 ↓
Analysis Geometry
 ↓
Mesh
 ↓
AnalysisPrecheck
 ↓
Finite-Strain Nonlinear FEM
 ↓
Plane / Axisymmetric / Axisymmetric Torsion
 ↓
Raw + Engineering Results
 ↓
Independent Solver Benchmarks
 ↓
Physical Product Test Comparison
 ↓
Validation
```

V1.0 is considered an engineering platform only after the required verification matrix is complete.

## Future research tracks

Not committed to initial V1.0 scope:

- viscoelasticity
- rate dependence
- Mullins effect
- hysteresis
- material damage
- cyclic elastomer behavior
- rubber fatigue/life methods
- harmonic/dynamic analysis
- transient dynamics
- contact
- rigid-body definitions
- elastomer-specific automatic mesher
- deformed-profile DXF export
- ANSYS material/user-material adapters
- Marc UMATERIAL adapter
- CalculiX material adapter
- alternative sparse solver backends

## Development rule

Every scientific feature follows:

```text
Theory
 ↓
Implementation
 ↓
Unit / Constitutive Verification
 ↓
Material-Point / Element Benchmark
 ↓
Mesh Convergence
 ↓
Independent Solver Comparison
 ↓
Experimental Validation where applicable
```

## Product principle

DynaElastomerSolver does not compete with general-purpose CAE systems by breadth. It aims to provide a more direct and transparent engineering chain for elastomer material characterization, nonlinear product analysis and experimental validation.
