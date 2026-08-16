# DynaElastomerSolver — Project Context

## Purpose

DynaElastomerSolver is being developed as a scientific engineering analysis platform specialized in rubber and elastomer materials and the products that use them.

The project deliberately avoids the scope of a general-purpose CAE package such as ANSYS Mechanical or Hexagon Marc. Instead, it concentrates engineering effort on elastomer constitutive behavior, calibration, nonlinear finite-element formulations, axisymmetric product analysis and verification.

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

The first constitutive library will contain:

- Neo-Hookean
- Mooney-Rivlin
- Yeoh
- Ogden N1
- Ogden N2
- Ogden N3

Future material research may add Arruda-Boyce, Gent, viscoelasticity, Mullins effect, hysteresis and damage.

## Material philosophy

A physical material and its mathematical constitutive fit are different objects.

```text
Physical Material
  ├── identity / compound / lot
  ├── experimental datasets
  ├── calibration records
  └── one or more constitutive parameter sets
```

Experimental data, calibrated parameters, model validation and provenance are preserved independently.

## Geometry philosophy

DynaElastomerSolver does not contain a general-purpose 2D sketcher or CAD module.

Geometry is created externally and imported, initially through DXF. The application is responsible only for:

- DXF interpretation
- topology construction
- closed-loop and region detection
- boundary identification
- geometry validation/healing
- axis definition
- analysis metadata

The internal geometry representation is owned by DynaElastomerSolver and does not depend on any external DXF library.

## Mesh philosophy

Meshing is externalized through `IMeshProvider`.

Initial implementation:

- Gmsh adapter

Possible future implementations:

- alternative open-source mesher
- imported mesh adapter
- purpose-built `ElastomerMeshProvider`

All mesh providers convert into DynaElastomerSolver's own `InternalMesh` model.

## Solver philosophy

The nonlinear finite-element solver is part of DynaElastomerSolver and will be written in Modern Fortran.

The only external solver initially planned is the low-level sparse linear equation solver used for systems such as:

`K * Δu = -R`

This is hidden behind `ILinearSolver`. Initial candidate: MUMPS.

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

The following are core project intellectual and scientific assets:

- canonical material model definitions
- material calibration engine
- material point framework
- constitutive stress/tangent implementation
- FEM kinematics
- mixed nearly-incompressible formulation
- element formulations
- nonlinear solver logic
- axisymmetric torsion formulation
- verification framework
- experimental validation workflow

External libraries remain replaceable implementation details.
