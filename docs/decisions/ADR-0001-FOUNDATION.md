# ADR-0001 — Foundational Architecture Decisions

**Status:** Accepted  
**Project:** DynaElastomerSolver

## Context

The project requires a scientific analysis platform specialized in rubber/elastomer materials and products. The design must support long-term evolution without becoming dependent on one mesh generator, one sparse solver, one CAD kernel or one compiler.

## Decisions

### 1. Product scope

DynaElastomerSolver will be a specialized elastomer engineering platform, not a general-purpose CAE clone.

Initial focus:

- large deformation
- hyperelasticity
- nearly incompressible behavior
- plane strain
- axisymmetric analysis
- axisymmetric torsion
- tension, compression and shear
- material calibration
- force-displacement and torque-angle response

### 2. Scientific core language

The computational core will use Modern Fortran.

- baseline: Fortran 2018
- portable Fortran 2023 features may be used where supported
- macOS/Apple Silicon compiler: GNU gfortran
- Windows compiler: Intel ifx with GNU gfortran validation
- build system: CMake

### 3. Calibration remains in Fortran

Material calibration, objective functions and optimizers belong to the same computational core as the material models and FEM.

Reason: calibration and FEM must use the exact same constitutive implementation.

### 4. No internal CAD/sketch system

The program will not become a 2D drawing application.

Geometry is authored externally and imported, initially through DXF.

The internal system only interprets, validates and models analysis geometry.

### 5. Canonical internal geometry model

DXF entities are converted into project-owned `AnalysisGeometry` structures.

No DXF library or CAD kernel may define the internal analysis data model.

### 6. Replaceable mesh system

Meshing is accessed through `IMeshProvider`.

Initial candidate: Gmsh adapter.

All providers output `InternalMesh`.

A future elastomer-specific mesher may be developed without changing FEM.

### 7. FEM solver remains project-owned

The nonlinear FEM solver, element formulations, material models, assembly and Newton-Raphson logic are DynaElastomerSolver components.

Only the low-level sparse algebraic system solver may initially be external.

### 8. Replaceable sparse linear solver

Sparse linear solution is accessed through `ILinearSolver`.

Initial candidate: MUMPS.

Future alternatives may include PETSc/PARDISO or an internal implementation.

### 9. Energy-based hyperelastic material architecture

Hyperelastic models are defined through strain-energy density and return a canonical material response.

Target response includes:

- strain energy
- stress measures
- consistent tangent
- Jacobian
- state/status

### 10. Material science is solver-independent

The Material Core is shared by:

- FEM
- calibration
- material-point tests
- future external-solver adapters

The same Yeoh/Ogden implementation must never be duplicated between calibration and FEM.

### 11. MaterialPoint state from the beginning

Integration points support committed/trial/history state even if the first hyperelastic models are history-independent.

This enables future:

- viscoelasticity
- Mullins effect
- hysteresis
- damage

without redesigning the constitutive interface.

### 12. Isochoric and volumetric behavior are separated

Constitutive material science and incompressibility enforcement are different concerns.

Mixed `u-p` technology belongs to FEM formulation infrastructure rather than being hard-coded into each material model.

### 13. Mixed u-p is an early production requirement

A displacement-only Q4 element will be used as a foundation/verification element.

Because elastomers are nearly incompressible, mixed displacement-pressure formulation is moved early in the roadmap and is required before production-grade elastomer elements are considered complete.

### 14. Generalized fields / DOFs

DOFs are not hard-coded by element family.

Target fields include:

- displacement
- twist `φ`
- pressure `p`

This supports plane, axisymmetric and axisymmetric-torsion formulations within one infrastructure.

### 15. Axisymmetric torsion is a core differentiator

The target formulation uses a 2D meridional mesh with generalized twist.

Primary DOFs:

`ur, uz, φ`

Nearly-incompressible mixed formulation:

`ur, uz, φ, p`

This enables torque-angle prediction without a full 3D mesh for rotationally symmetric products.

### 16. Nonlinear robustness is modular

The nonlinear solver architecture must support:

- Newton-Raphson
- convergence monitoring
- load stepping
- adaptive increments
- cutback
- line search
- future arc-length

### 17. Verification is part of implementation

A feature is not considered complete without relevant verification.

Required levels include:

- mathematical tests
- constitutive tests
- tangent diagnostics
- single-element tests
- mesh convergence
- independent solver comparison
- experimental validation where possible

### 18. Open-source policy

Open-source systems may be studied and appropriately licensed components may be used, but all runtime dependencies are isolated behind adapters.

Primary references currently include:

- FEBio
- FEBio Studio
- TFEL/MFront
- CalculiX
- OpenRadioss
- FEniCSx
- Gmsh
- MUMPS
- DIME
- Clipper2

Licensing is reviewed before distribution.

### 19. Public ABI

Fortran internal OOP structures are not exposed directly.

Public native ABI uses `ISO_C_BINDING` and a stable C-compatible interface.

Prefix: `des_`.

Target native library names:

- Windows: `DynaElastomerCore.dll`
- macOS: `libDynaElastomerCore.dylib`
- Linux: `libDynaElastomerCore.so`

## Consequences

### Positive

- scientific core remains under project control
- external mesh/linear-solver technology can be replaced
- Mac and Windows development share one Fortran source base
- constitutive models are reusable across calibration and FEM
- future elastomer physics can be added without breaking the core abstractions
- open-source research can be used strategically without inheriting external data models

### Cost / trade-offs

- more interfaces/adapters must be maintained
- canonical internal geometry and mesh models must be designed carefully
- mixed formulations and consistent tangents increase early implementation complexity
- verification effort is treated as a first-class development cost

## Guiding principle

> DynaElastomerSolver owns the elastomer science and canonical engineering model; external tools are replaceable numerical infrastructure.
