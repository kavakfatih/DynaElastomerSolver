# DynaElastomerSolver Roadmap

This roadmap reflects the current architectural decisions. Version numbers are development milestones, not release promises.

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
- parameter metadata
- parameter validation
- constitutive stability checks
- tangent diagnostics for every model

Exit criterion: every model passes the Material Core production-eligibility pipeline up to material-point verification.

## V0.3 — Calibration Engine

Deliverables:

- experimental dataset model
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

Then extend toward:

- compression
- simple shear
- planar tension
- biaxial tension
- volumetric data

Exit criterion: calibration round-trip tests reproduce known synthetic parameter sets within tolerance.

## V0.4 — FEM Verification Foundation

Goal: build the first complete nonlinear FEM chain using a simple verification element.

Deliverables:

- node / element / mesh data model
- generalized DOF manager
- Q4 plane-strain verification element
- shape functions
- Gauss integration
- deformation-gradient calculation
- element residual
- consistent tangent
- global assembly
- displacement boundary conditions
- Newton-Raphson
- convergence monitoring
- simple dense/LAPACK linear solver path for small tests

Exit criterion: Neo-Hookean plane-strain benchmarks and mesh-convergence tests pass.

## V0.5 — Mixed u-p Foundation

Goal: move from verification-only displacement elements to production-oriented nearly-incompressible elastomer technology.

Deliverables:

- pressure field
- generalized mixed DOF infrastructure
- mixed residual/tangent blocks
- mixed element formulation research/implementation
- incompressibility verification
- volumetric-locking comparison against displacement-only element

Exit criterion: benchmark problems demonstrate stable nearly-incompressible behavior without unacceptable locking.

## V0.6 — Axisymmetric Analysis

Deliverables:

- axisymmetric kinematics
- `ur, uz` formulation
- mixed `ur, uz, p` formulation
- `2πR` integration
- axisymmetric boundary sets
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
- torsion benchmark suite

Exit criterion: DynaElastomerSolver results agree with independent reference solvers and selected physical torsion tests within defined engineering tolerances.

## V0.8 — Nonlinear Robustness

Deliverables:

- adaptive load stepping
- cutback
- multiple convergence criteria
- line search
- better failure diagnostics
- negative-J / element-distortion detection
- state rollback / commit framework

Future research:

- arc-length
- advanced continuation strategies

## V0.9 — Engineering Pre/Post Processor

Deliverables:

### Geometry
- DXF import adapter
- project-owned `AnalysisGeometry`
- line / arc / spline interpretation
- loop/region construction
- geometry validation/healing
- layer metadata
- axis definition
- named boundaries

### Mesh
- `IMeshProvider`
- Gmsh adapter
- `InternalMesh`
- boundary/region mapping
- mesh-quality checks

### Results
- displacement contours
- stress/strain measures
- pressure
- principal stretch
- force-displacement history
- torque-angle history
- convergence history

No general-purpose sketch/CAD tools are planned.

## V1.0 — Validated Elastomer Analysis Platform

Target workflow:

```text
DXF
 ↓
Analysis Geometry
 ↓
Mesh
 ↓
Validated Material / Calibration
 ↓
Nonlinear FEM
 ↓
Plane / Axisymmetric / Axisymmetric Torsion
 ↓
Engineering Results
 ↓
Independent Solver Benchmarks
 ↓
Experimental Validation
```

V1.0 should be considered a validated engineering platform only after the required verification matrix is complete.

## Future research tracks

Not committed to initial V1.0 scope:

- viscoelasticity
- rate dependence
- Mullins effect
- hysteresis
- material damage
- cyclic elastomer behavior
- harmonic/dynamic analysis
- transient dynamics
- contact
- rigid-body definitions
- elastomer-specific automatic mesher
- external material adapters for ANSYS / Marc / CalculiX
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
Element Benchmark
 ↓
Mesh Convergence
 ↓
Independent Solver Comparison
 ↓
Experimental Validation where applicable
```
