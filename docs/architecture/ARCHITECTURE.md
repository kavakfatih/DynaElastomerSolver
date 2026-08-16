# DynaElastomerSolver Architecture v1.2

**Revision:** ANSYS / Hexagon Marc benchmark revision  
**Status:** Accepted architecture baseline

## 1. Architectural goal

DynaElastomerSolver is a specialized nonlinear FEM and material-engineering platform for rubber and elastomer products. It is not intended to reproduce the breadth of general-purpose CAE systems. Its depth is concentrated on constitutive material science, experimental calibration, nearly-incompressible finite-strain FEM, axisymmetric analysis, axisymmetric torsion, robust nonlinear solution and experimental validation.

The architecture is deliberately modular:

```text
Material Lab / Experimental Data
             ↓
        Material Core
             │
             ├──────────────┐
             │              │
External CAD / DXF      Calibration
       ↓
AnalysisGeometry
       ↓
Geometry Validation
       ↓
IMeshProvider
       ↓
InternalMesh
       ↓
AnalysisPrecheck
       ↓
Finite Element Model
       ↓
NonlinearSolutionManager
       ↓
ILinearSolver
       ↓
ResultDatabase
       ↓
Postprocessor / Experimental Comparison
```

## 2. Non-negotiable separation rules

```text
Physics ≠ Geometry ≠ Meshing ≠ Linear Solver ≠ UI
```

Additional v1.2 rules:

1. Constitutive law and incompressibility enforcement are separate concerns.
2. Newton iteration and nonlinear solution management are separate concerns.
3. Raw integration-point results and display/extrapolated results are stored separately.
4. Material knowledge is solver-independent and may be used by FEM, calibration, point testing and future external adapters.
5. Analysis validity is checked before solve through a first-class `AnalysisPrecheck` stage.
6. External libraries never become the canonical internal data model.
7. FEM never consumes Gmsh-native objects or DXF-native entities.
8. Calibration and FEM use the same constitutive implementation.
9. Sparse linear solvers are accessed only through `ILinearSolver`.
10. Mesh generators are accessed only through `IMeshProvider`.

## 3. Principal interfaces

```text
IDxfImporter
IMeshProvider
ILinearSolver
IMaterialModel
IMaterialPlugin
IOptimizer
IElementFormulation
IKinematicsFormulation
IIncompressibilityStrategy
IBoundaryCondition
IResultExtrapolator
```

These interfaces protect the scientific core from external implementation details.

## 4. Geometry subsystem

DynaElastomerSolver is not a CAD/sketch application.

```text
External CAD
   ↓
DXF
   ↓
IDxfImporter
   ↓
AnalysisGeometry
   ↓
GeometryValidator
   ↓
Topology / Regions / Boundaries / SelectionSets
```

Canonical model:

```text
AnalysisGeometry
├── Curve
│   ├── Line
│   ├── Arc
│   └── Spline
├── Loop
├── Region
├── Boundary
├── BoundarySet
├── SelectionSet
├── LayerMetadata
└── AxisDefinition
```

Required geometry checks:

- open contours
- duplicate edges
- tiny edges
- gaps
- intersections / self-intersections
- loop orientation
- hole detection
- zero-area regions
- axisymmetric validity
- region connectivity

Geometry tooling is limited to analysis preparation:

```text
Geometry Check
├── Validate
├── Detect
├── Controlled Heal
└── Recheck
```

General-purpose drawing, trimming, filleting, parametric modeling and CAD editing are out of scope.

## 5. Selection and scoping

Engineering meaning is attached to geometry-level selections rather than mesh node numbers.

Typical sets:

```text
INNER_BOND
OUTER_BOND
FREE_SURFACE
AXIS
ELASTOMER_REGION
```

Selection sets survive remeshing and are used for:

- material assignment
- boundary conditions
- loads
- result scoping
- validation comparison regions

## 6. Mesh subsystem

```text
IMeshProvider
├── GmshMeshProvider
├── ImportedMeshProvider
├── AlternativeMeshProvider
└── ElastomerMeshProvider   [future]
```

All providers produce the project-owned model:

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

Initial mesh provider: Gmsh adapter.

Minimum user-facing mesh controls targeted for the engineering preprocessor:

- global element size
- edge size
- number of edge divisions
- region sizing
- local refinement
- mapped/structured quadrilateral request where topology permits
- quad-dominant mode where appropriate
- mesh-quality report

The long-term project may add an elastomer-specific mesher for thin bonded rubber layers, high-shear regions, axisymmetric quads and mixed `u-p` requirements.

## 7. Mesh validation

`MeshPrecheck` contributes to `AnalysisPrecheck` and checks at minimum:

- Jacobian sign/quality
- connectivity
- node ordering
- element orientation
- degeneracy
- aspect ratio / distortion
- boundary and region mapping
- integration scheme compatibility
- material/element compatibility

## 8. Modern Fortran computational core

```text
src/fortran
├── core
├── math
├── materials
├── calibration
├── fem
├── solvers
├── results
└── api
```

Language/build policy:

- Fortran 2018 baseline
- portable Fortran 2023 features only when supported by target compilers
- `iso_fortran_env` for kinds
- `iso_c_binding` for public ABI
- CMake build system
- macOS/Apple Silicon: GNU gfortran
- Windows: Intel ifx + GNU gfortran validation
- Linux later: GNU gfortran

## 9. Material subsystem

Hyperelastic materials are energy-based and solver-independent.

Initial/target V1.0 model family:

```text
Hyperelastic
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden N1/N2/N3
├── Arruda-Boyce
└── Gent
```

Future physics:

- viscoelasticity
- rate dependence
- Mullins effect
- hysteresis
- damage
- fatigue-related material measures

A material response may include:

- strain energy
- first Piola-Kirchhoff stress
- Cauchy stress
- consistent tangent
- Jacobian `J`
- pressure-related constitutive quantities where applicable
- state/status information

## 10. Material plugin API

Inspired by the extensibility of mature nonlinear solvers, DynaElastomerSolver provides a native material-plugin concept.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Canonical contract:

```text
evaluate(kinematics, state, parameters)
    ↓
MaterialResponse
├── W
├── stress measures
├── consistent tangent
├── updated trial state
└── status
```

FEM does not change when a new material model is added.

## 11. Material-point state

Every integration point has explicit state infrastructure:

```text
MaterialPointState
├── committed
├── trial
└── history variables
```

On converged increments, trial state is committed. On failed/cut-back increments, trial state is discarded/reverted.

## 12. Constitutive law vs incompressibility strategy

This separation is explicit in v1.2.

```text
Constitutive Law
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

The constitutive model must not know whether the FE system uses a mixed `u-p`, penalty, or another constraint-enforcement method.

Conceptually:

```text
IsochoricConstitutiveModel
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden
├── Arruda-Boyce
└── Gent

IIncompressibilityStrategy
├── Compressible
├── NearlyIncompressible
└── MixedUP
```

This preserves material-model reuse across different FE formulations.

## 13. Calibration and material provenance

Calibration is part of the Modern Fortran scientific core and uses the exact same constitutive implementation as FEM.

```text
Experimental Dataset
       ↓
Test Kinematics Driver
       ↓
Material Core
       ↓
Predicted Response
       ↓
Objective Function
       ↓
IOptimizer
       ↓
Parameter Set + Metrics + Provenance
```

Target datasets:

- uniaxial tension
- compression
- simple shear
- planar tension
- biaxial tension
- volumetric data

A physical compound may own multiple constitutive fits. Parameter sets record dataset IDs, optimizer, objective function, calibration version, valid ranges and validation state.

## 14. Kinematics and generalized fields

```text
IKinematicsFormulation
├── PlaneStrain
├── PlaneStress        [later]
├── Axisymmetric
└── AxisymmetricTorsion
```

Fields are generalized rather than hard-coded in individual elements:

```text
Field
├── Displacement
├── Twist φ
└── Pressure p
```

Target DOFs:

- plane strain: `ux, uy` or mixed `ux, uy, p`
- axisymmetric: `ur, uz` or mixed `ur, uz, p`
- axisymmetric torsion: `ur, uz, φ` or mixed `ur, uz, φ, p`

Axisymmetric torsion remains a core product differentiator because it can predict torque-angle behavior using a meridional mesh instead of full 3D discretization for rotationally symmetric products.

## 15. Element strategy

Foundation/verification elements:

- Q4 plane strain
- Q4 axisymmetric
- Q4 axisymmetric torsion

Displacement-only Q4 technology is not considered the final production elastomer formulation.

Production development prioritizes mixed displacement-pressure technology for nearly-incompressible behavior. Future candidates may include higher-order/mixed families such as Q8/Q9-derived formulations after verification.

## 16. AnalysisPrecheck

The solve pipeline must not begin with an unvalidated model.

```text
AnalysisModel
    ↓
AnalysisPrecheck
    ↓
Validated SolverInput
    ↓
Solve
```

Checks aggregate reports from:

### Geometry
- valid closed regions
- valid axis definition
- no unresolved critical topology errors

### Mesh
- quality/Jacobian/orientation
- mapping and integration compatibility

### Material
- parameter validity
- required parameters present
- calibration/validation status
- known validity range
- formulation compatibility

### Boundary conditions
- sufficient constraints
- rigid-body modes
- load/rotation definitions
- selection-set validity

### Formulation
- material/element compatibility
- incompressibility strategy compatibility
- required pressure field availability

Warnings and errors are distinguished; fatal errors block solution.

## 17. Nonlinear solution architecture

The nonlinear solution system is project-owned. v1.2 separates orchestration from Newton iteration.

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

Equilibrium:

`R(u) = 0`

Newton increment:

`K_T Δu = -R`

The manager controls increment acceptance, retries and state commit/revert behavior.

## 18. Convergence criteria

The architecture allows multiple convergence channels:

- residual force
- residual moment/torque where relevant
- displacement correction
- rotation/twist correction
- pressure-field convergence where applicable
- energy/residual diagnostics for research and debugging

Production defaults may use a subset; all criteria are stored in the convergence history.

## 19. Increment and cutback control

Large deformation is solved incrementally.

```text
Initial increment
      ↓
Newton iterations
  ┌───┴────────────┐
converged        failed
   │                │
accept          cutback
   │                │
step growth      retry
```

Target controls:

- initial increment
- minimum increment
- maximum increment
- growth factor
- cutback factor
- maximum retries
- automatic increment control

## 20. Solver controls — Automatic and Advanced

User-facing controls are intentionally simpler than general-purpose CAE systems.

### Automatic

The application chooses:

- Newton strategy
- initial increment
- growth/cutback behavior
- convergence tolerances
- linear-solver backend
- line-search activation when appropriate

### Advanced

Expert users may control:

- Full vs Modified Newton
- tangent update strategy
- maximum iterations
- convergence tolerances
- increment limits
- cutback settings
- line search
- predictor options
- linear solver selection

## 21. Linear solver abstraction

```text
ILinearSolver
├── Dense/LAPACK        [small tests]
├── MumpsSolver         [initial production candidate]
├── PardisoSolver       [future]
├── PetscSolver         [future]
└── InternalSolver      [future]
```

External sparse algebra does not own the FEM formulation or nonlinear algorithm. It only solves the assembled algebraic system.

## 22. Boundary conditions

```text
IBoundaryCondition
├── Displacement
├── Rotation
├── Force
├── Pressure
├── Symmetry
└── Constraint
```

BCs are scoped through geometry/mesh sets rather than raw node IDs.

## 23. Result database

v1.2 explicitly separates physics results from visualization projections.

```text
ResultDatabase
├── RawResults
│   ├── Nodal primary DOFs
│   └── IntegrationPoint results
│
├── DisplayResults
│   └── Nodal extrapolated / averaged fields
│
└── GlobalHistories
```

### Raw integration-point results

Target fields include:

- deformation gradient `F`
- Jacobian `J`
- principal stretches
- Cauchy stress
- pressure
- strain-energy density
- shear stress
- material state variables

### Nodal/primary results

- displacement
- twist
- pressure DOF where applicable
- reactions

### Global histories

- force-displacement
- torque-angle
- secant/tangent torsional stiffness
- strain energy
- external work
- convergence history

## 24. Result extrapolation and display

Gauss-point data is never silently treated as nodal data.

```text
IntegrationPoint Result
       ↓
IResultExtrapolator
       ↓
Display/Nodal Result
       ↓
Contour
```

The application records the extrapolation/averaging method used for every displayed derived field.

Candidate display methods:

- extrapolated
- averaged
- nearest/integration-point inspection

## 25. Result inspection tools

V1.0 postprocessing target:

```text
Result Tools
├── Contour
├── Min / Max
├── Node Probe
├── Element Probe
├── GaussPointInspector
├── Path
├── Chart
├── History
├── Reaction
├── Result Scoping
├── Derived Result
├── CSV Export
└── Report
```

`GaussPointInspector` is a first-class engineering tool, not a debug-only function.

Example inspection:

```text
Element 1042 / Gauss Point 1
λ1
λ2
λ3
J
σ12
W
p
state variables
```

## 26. Elastomer-specific engineering results

Beyond generic stress contours, the platform emphasizes quantities useful for elastomer products:

- principal stretches
- shear measures
- hydrostatic pressure
- `J`
- strain-energy density
- reaction force/torque
- torque-angle curve
- force-displacement curve
- tangent stiffness
- secant stiffness

Von Mises stress may be available as a derived display quantity but is not treated as the primary elastomer design metric.

## 27. Experimental comparison and product validation

Experimental comparison is native to the result system.

```text
FEA History
    +
Physical Test History
        ↓
Overlay / Alignment
        ↓
Error Metrics
```

Target metrics:

- RMSE
- maximum absolute error
- mean error
- relative error
- stiffness error
- valid comparison range

This closes the central product workflow:

```text
Experimental Material Data
→ Calibration
→ Material Model
→ FEM
→ Physical Product Test
→ Validation
```

## 28. Derived results

The result architecture supports built-in and future user-defined derived quantities, for example:

- `Kt = dT/dθ`
- `Ksec = T/θ`
- maximum principal stretch
- normalized torque error
- energy density measures

Derived results must record their source fields and expression/version for traceability.

## 29. Public API

Internal Fortran OOP structures are not exposed directly.

C ABI prefix: `des_`.

Examples:

```text
des_solver_create
des_solver_run
des_solver_get_result
des_solver_destroy

des_calibration_create
des_calibration_add_dataset
des_calibration_run
des_calibration_get_result
```

Native libraries:

- Windows: `DynaElastomerCore.dll`
- macOS: `libDynaElastomerCore.dylib`
- Linux: `libDynaElastomerCore.so`

## 30. Verification philosophy

A feature is incomplete until verified at the appropriate levels:

1. mathematical unit tests
2. constitutive benchmarks
3. numerical tangent diagnostics
4. material-point tests
5. single-element tests
6. mixed-formulation / locking benchmarks
7. mesh convergence
8. independent solver comparison
9. experimental validation

Reference environments may include FEBio, FEniCSx, CalculiX and commercial ANSYS/Marc benchmarks where available.

## 31. External dependency policy

```text
External Component
       ↓
Interface / Adapter
       ↓
DynaElastomerSolver Internal Model
```

Open-source and commercial systems may inform implementation and validation, but they do not define the canonical scientific model.

## 32. Product boundaries

Intentionally excluded from the initial product:

- general-purpose 2D/3D CAD
- broad metal plasticity library
- CFD
- electromagnetics
- general multiphysics
- large beam/shell/general element catalogs
- topology optimization

These exclusions protect the elastomer specialization.

## 33. Scientific identity

DynaElastomerSolver is defined by:

```text
Elastomer Constitutive Science
+
Experimental Material Calibration
+
Solver-Independent Material Core
+
Finite-Strain Nearly-Incompressible FEM
+
Axisymmetric / Axisymmetric-Torsion Technology
+
Robust Nonlinear Solution Management
+
Transparent Integration-Point Results
+
Experimental Product Validation
```

The central rule remains:

> DynaElastomerSolver owns the elastomer science, canonical engineering models and nonlinear FEM logic; geometry parsers, meshers and low-level sparse solvers remain replaceable infrastructure.
