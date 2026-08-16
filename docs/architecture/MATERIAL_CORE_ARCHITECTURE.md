# DynaElastomerSolver — Material Core Architecture v1.0

## 1. Goal

The Material Core is a solver-independent constitutive science layer. FEM, calibration, material-point verification and future external-solver adapters must use the same canonical material implementation.

```text
                    Material Core
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
 Calibration        FEM Solver       Point Tests
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │
                Future Solver Export
```

## 2. Core types

```text
material_model_t                 abstract
hyperelastic_model_t            abstract
material_definition_t           physical material record
material_parameter_set_t        constitutive parameters
material_kinematics_t           F, J and derived quantities
material_point_state_t          integration-point state
material_response_t             W, stress and tangent
material_validation_t           verification metadata
```

## 3. Material model contract

Illustrative Modern Fortran interface:

```fortran
type, abstract :: material_model_t
contains
    procedure(material_evaluate_if), deferred :: evaluate
    procedure(material_validate_if), deferred :: validate_parameters
end type material_model_t

type, abstract, extends(material_model_t) :: hyperelastic_model_t
contains
    procedure(energy_if), deferred :: strain_energy
end type hyperelastic_model_t
```

Initial concrete models:

```text
hyperelastic_model_t
├── neo_hookean_t
├── mooney_rivlin_t
├── yeoh_t
└── ogden_t
```

## 4. Kinematics passed to materials

The constitutive model does not know the FEM element.

```text
material_kinematics_t
├── F(3,3)
├── J
├── C(3,3)
├── B(3,3)
├── principal_stretches
└── optional temperature/time fields
```

The caller may be FEM, calibration or a material-point test driver.

## 5. Material response

```text
material_response_t
├── strain_energy
├── first_piola_stress P
├── cauchy_stress
├── consistent_tangent
├── pressure
├── J
└── status
```

Hyperelastic foundation:

`W = W(F)`

`P = ∂W / ∂F`

`A = ∂P / ∂F`

## 6. Material-point state

A state framework exists from the first version even if the initial hyperelastic models are history independent.

```text
material_point_state_t
├── committed state
├── trial state
└── history variables
```

Iteration policy:

```text
Committed
   ↓
Trial
   ↓
Newton iterations
 ┌─┴──────────┐
 fail      converge
  │             │
discard       commit
```

This enables future viscoelasticity, Mullins effect, hysteresis and damage without redesigning the material API.

## 7. Isochoric / volumetric separation

Material science and incompressibility enforcement are separate concerns.

```text
IsochoricConstitutiveModel
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
└── Ogden

Volumetric / Constraint Formulation
├── Compressible
├── NearlyIncompressible
└── MixedUP
```

Conceptually:

`W = W_iso(F_bar) + W_vol(J)`

Mixed `u-p` enforcement belongs to the FE formulation, not inside each material class.

## 8. Two material creation paths

```text
Material Creation
│
├── Direct Parameters
│      ↓
│  Parameter Validation
│
└── Experimental Data
       ↓
   Calibration
       ↓
   Parameter Set
```

Both paths produce the same canonical `material_parameter_set_t`.

## 9. Calibration driver

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
Parameter Set
```

Target dataset types:

- uniaxial tension
- compression
- simple shear
- planar tension
- biaxial tension
- volumetric

Calibration and FEM must never maintain duplicate implementations of the same constitutive law.

## 10. Material-point test driver

Before FEM, every constitutive model can be exercised under prescribed deformation paths.

Example:

```text
Uniaxial stretch λ
      ↓
Analytical deformation gradient F
      ↓
Material Core
      ↓
Energy / Stress / Tangent
```

This creates an independent constitutive verification layer.

## 11. Tangent diagnostic

A new material cannot become FEM-eligible until its consistent tangent is numerically verified.

Central finite difference concept:

`A_FD(iJkL) ≈ [P(F + εE_kL) - P(F - εE_kL)] / (2ε)`

Suggested error metric:

`e_A = ||A_analytic - A_FD|| / max(1, ||A_FD||)`

Pipeline:

```text
Material implementation
        ↓
Energy tests
        ↓
Stress tests
        ↓
Tangent diagnostic
        ↓
Material-point tests
        ↓
FEM eligible
```

## 12. Parameter metadata

Every model declares a parameter schema and capabilities.

Example Yeoh:

```text
Model ID: hyperelastic.yeoh.3
Parameters:
- C10
- C20
- C30
Capabilities:
- finite_strain = true
- nearly_incompressible = supported
- history = false
```

Example Ogden N2:

```text
μ1, α1, μ2, α2
```

This metadata is shared by UI, calibration, serialization and validation.

## 13. Physical material vs mathematical fit

```text
material_definition_t
├── Identity
│   ├── polymer family
│   ├── compound
│   ├── supplier
│   └── batch / lot
├── Experimental datasets
├── Parameter sets
│   ├── Yeoh fit
│   ├── Ogden fit
│   └── Mooney-Rivlin fit
└── Validation records
```

A single physical compound may own several constitutive fits.

## 14. Provenance

Each parameter set records:

- source
- dataset IDs
- calibration engine version
- optimizer
- objective definition
- fit metrics
- calibration date
- valid strain range
- test temperature range
- verification/validation status

The purpose is long-term scientific traceability.

## 15. Validation status

Suggested states:

```text
REFERENCE
EXPERIMENTAL
CALIBRATED
VERIFIED
PRODUCT_VALIDATED
```

Generic literature values remain `REFERENCE`. A compound calibrated from physical tests and validated against product testing may become `PRODUCT_VALIDATED`.

## 16. Analysis precheck contribution

The Material Core reports:

- parameter validity
- missing required parameters
- formulation compatibility
- known validity range
- nearly-incompressible requirement
- temperature-range warnings
- stability-check status
- calibration/validation status

The global `AnalysisPrecheck` combines this with geometry, mesh and boundary-condition checks.

## 17. Future solver adapters

```text
DynaElastomer Material Core
├── DynaElastomerSolver native
├── ANSYS adapter          [future]
├── Marc UMATERIAL adapter [future]
├── CalculiX adapter       [future]
└── generic material API   [future]
```

## 18. Initial implementation sequence

### MC-0.1
- `material_kinematics_t`
- `material_response_t`
- `material_model_t`
- `neo_hookean_t`
- material-point test driver

### MC-0.2
- numerical tangent
- tangent diagnostic
- Mooney-Rivlin
- Yeoh

### MC-0.3
- Ogden N1/N2/N3
- parameter metadata
- stability/parameter validation

### MC-0.4
- `material_point_state_t`
- committed/trial infrastructure

### MC-0.5
- experimental data integration
- calibration engine
- provenance
- validation records

## 19. Production acceptance rule

A constitutive model is not considered production-ready until it passes:

1. parameter validation
2. analytical energy checks
3. analytical stress checks
4. numerical tangent comparison
5. material-point tests
6. calibration round-trip tests
7. single-element FEM tests
8. mesh-convergence benchmarks
9. independent solver comparison
10. experimental validation where applicable

## 20. Principle

**Material knowledge is not embedded in the FEM solver. Calibration, FEM and verification share one canonical constitutive implementation.**
