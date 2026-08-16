# DynaElastomerSolver Architecture v1.0

## 1. Architectural goal

DynaElastomerSolver is a specialized nonlinear FEM platform for rubber and elastomer engineering. The architecture separates geometry, meshing, constitutive science, FEM, nonlinear solution, linear algebra and UI so that each subsystem can evolve independently.

```text
Application UI
      ↓
Application Layer
      ↓
Preprocessor
      ↓
AnalysisGeometry
      ↓
IMeshProvider
      ↓
InternalMesh
      ↓
Modern Fortran Physics Core
      ↓
ILinearSolver
      ↓
Results / Postprocessor
```

## 2. Non-negotiable separation rules

```text
Physics ≠ Geometry ≠ Meshing ≠ Linear Solver ≠ UI
```

Rules:

1. External libraries never become the canonical internal data model.
2. FEM never consumes Gmsh-native objects.
3. FEM never consumes DXF-native entities.
4. Material models do not depend on FEM elements.
5. Calibration and FEM use the same constitutive implementation.
6. Sparse linear solvers are accessed only through `ILinearSolver`.
7. Mesh generators are accessed only through `IMeshProvider`.
8. Geometry importers are accessed only through `IDxfImporter` or future geometry interfaces.

## 3. Main interfaces

```text
IDxfImporter
IMeshProvider
ILinearSolver
IMaterialModel
IOptimizer
IElementFormulation
IKinematicsFormulation
IBoundaryCondition
```

## 4. Geometry subsystem

The program is not a CAD application.

Initial geometry path:

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
Topology / Regions / Boundaries
```

Canonical geometry model:

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
├── LayerMetadata
└── AxisDefinition
```

Required validation tasks include:

- open contour detection
- duplicate edge detection
- tiny-edge detection
- gap detection
- self/intersection detection
- loop orientation
- hole detection
- zero-area region detection
- axisymmetric validity

DXF layers may optionally map to engineering semantics such as `ELASTOMER_REGION`, `BOND_FIXED`, `BOND_ROTATING`, `FREE_SURFACE`, and `AXIS`.

## 5. Mesh subsystem

```text
IMeshProvider
├── GmshMeshProvider
├── ImportedMeshProvider
├── AlternativeMeshProvider
└── ElastomerMeshProvider   [future]
```

Every provider produces:

```text
InternalMesh
├── Nodes
├── Elements
├── ElementSets
├── BoundarySets
├── RegionSets
└── Metadata
```

Initial development mesh provider: Gmsh.

Long-term possibility: a dedicated elastomer mesher that understands bonded surfaces, thin rubber layers, high-shear regions, axisymmetric quad meshing and mixed element requirements.

## 6. Modern Fortran computational core

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

Language policy:

- Fortran 2018 baseline
- portable Fortran 2023 features only when supported by target compilers
- `iso_fortran_env` for kinds
- `iso_c_binding` for public ABI
- no compiler-specific numerical semantics in the scientific core

Supported compilers:

- macOS / Apple Silicon: GNU gfortran
- Windows: Intel ifx + GNU gfortran validation
- Linux later: GNU gfortran

Build system: CMake.

## 7. Material subsystem

Hyperelastic models are energy-based:

`W = W(F)`

Material responses include:

- strain energy
- first Piola-Kirchhoff stress
- Cauchy stress
- consistent material tangent
- Jacobian `J`
- status/state information

Initial models:

```text
Hyperelastic
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
└── Ogden
    ├── N1
    ├── N2
    └── N3
```

Isochoric constitutive behavior and volumetric/incompressibility enforcement are kept separate:

```text
IsochoricConstitutiveModel
+
Volumetric / Constraint Formulation
```

This supports future mixed `u-p` formulations without embedding FE constraints into material models.

## 8. Material-point state

Every integration point uses a state framework from the beginning:

```text
MaterialPointState
├── committed
├── trial
└── history variables
```

History variables may be empty for the first hyperelastic models, but the same framework later supports viscoelasticity, Mullins effect, damage and hysteresis.

## 9. Calibration subsystem

Calibration is written in Modern Fortran and uses the same material model implementation as FEM.

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

Supported/target datasets:

- uniaxial tension
- compression
- simple shear
- planar tension
- biaxial tension
- volumetric data

A physical material can own multiple calibrated constitutive parameter sets.

## 10. Kinematics

```text
IKinematicsFormulation
├── PlaneStrain
├── PlaneStress        [later]
├── Axisymmetric
└── AxisymmetricTorsion
```

### Plane strain

DOF:

`ux, uy`

### Axisymmetric

DOF:

`ur, uz`

Axisymmetric integration uses the revolution factor `2πR`.

### Axisymmetric torsion

Primary generalized DOFs:

`ur, uz, φ`

Mixed nearly-incompressible formulation:

`ur, uz, φ, p`

This formulation is intended to predict torque-angle response of rotationally symmetric elastomer products without a full 3D mesh.

## 11. Generalized field / DOF system

DOFs are not hard-coded inside element classes.

```text
Field
├── Displacement
├── Twist φ
└── Pressure p
```

This allows plane, axisymmetric, torsion and mixed formulations to share the same DOF infrastructure.

## 12. Element strategy

Initial verification elements:

- Q4 Plane Strain
- Q4 Axisymmetric
- Q4 Axisymmetric Torsion

The displacement-only Q4 is a verification/foundation element, not the final production nearly-incompressible elastomer element.

Mixed `u-p` technology is moved early in the roadmap because elastomers are nearly incompressible.

Future candidates include Q8/Q9 and mixed displacement-pressure families.

## 13. Nonlinear solver

The nonlinear solver belongs to DynaElastomerSolver.

```text
NonlinearSolver
├── Newton-Raphson
├── Convergence Monitor
├── Load Controller
├── Adaptive Step
├── Cutback
├── Line Search
└── Arc-Length [future]
```

Equilibrium:

`R(u) = 0`

Newton increment:

`K_T Δu = -R`

## 14. Linear solver abstraction

The low-level sparse system solution is replaceable:

```text
ILinearSolver
├── Dense/LAPACK        [small tests]
├── MumpsSolver         [initial production candidate]
├── PardisoSolver       [future]
├── PetscSolver         [future]
└── InternalSolver      [future]
```

MUMPS does not own the FEM physics. It only solves assembled linear systems.

## 15. Boundary conditions

```text
IBoundaryCondition
├── Displacement
├── Rotation
├── Force
├── Pressure
├── Symmetry
└── Constraint
```

Boundary conditions are defined using geometry/mesh sets, not raw node numbers.

## 16. Results

Nodal:

- displacement
- twist
- pressure
- reaction force
- reaction torque

Integration point:

- deformation gradient `F`
- Jacobian `J`
- principal stretches
- Cauchy stress
- pressure
- strain-energy density
- shear stress

Global histories:

- force-displacement
- torque-angle
- torsional stiffness
- strain energy
- external work
- convergence history

## 17. Public API

The internal Fortran OOP types are never exposed directly.

C ABI naming prefix: `des_`.

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

Native library naming target:

- Windows: `DynaElastomerCore.dll`
- macOS: `libDynaElastomerCore.dylib`
- Linux: `libDynaElastomerCore.so`

## 18. Verification philosophy

A feature is not complete without verification.

Verification levels:

1. mathematical unit tests
2. constitutive benchmarks
3. numerical tangent diagnostics
4. single-element tests
5. mesh convergence
6. independent solver comparison
7. experimental validation

Reference environments may include FEBio, FEniCSx, CalculiX and commercial ANSYS/Marc benchmarks where available.

## 19. External dependency policy

```text
External Component
       ↓
Interface / Adapter
       ↓
DynaElastomerSolver Internal Model
```

Open-source systems may be studied and suitable components may be used, but no external project is permitted to define DynaElastomerSolver's scientific data model or architecture.

## 20. Scientific identity

The core value of the platform is:

```text
Elastomer Constitutive Science
+
Material Calibration
+
Specialized Nonlinear FEM
+
Nearly-Incompressible Element Technology
+
Axisymmetric Torsion
+
Verification and Experimental Validation
```
