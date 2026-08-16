# DynaElastomerSolver — Material Core Architecture v1.1

**Revision:** ANSYS / Marc / FEBio / MFront benchmark alignment  
**Status:** Accepted

## 1. Goal

The Material Core is a solver-independent constitutive science layer. FEM, calibration, material-point verification and future external-solver adapters use the same canonical implementation.

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

A physical material record and a mathematical constitutive fit are separate objects.

## 2. Core types

```text
material_model_t                 abstract
hyperelastic_model_t            abstract
material_definition_t           physical material record
material_parameter_set_t        constitutive parameters
material_kinematics_t           F, J and derived quantities
material_point_state_t          integration-point state
material_response_t             energy/stress/tangent/state response
material_validation_t           verification metadata
material_provenance_t           source and calibration traceability
```

## 3. Material model contract

Illustrative Modern Fortran contract:

```fortran
type, abstract :: material_model_t
contains
    procedure(material_evaluate_if), deferred :: evaluate
    procedure(material_validate_if), deferred :: validate_parameters
    procedure(material_metadata_if), deferred :: metadata
end type material_model_t

type, abstract, extends(material_model_t) :: hyperelastic_model_t
contains
    procedure(energy_if), deferred :: strain_energy
end type hyperelastic_model_t
```

Target V1.0 hyperelastic family:

```text
hyperelastic_model_t
├── neo_hookean_t
├── mooney_rivlin_t
├── yeoh_t
├── ogden_t
│   ├── N1
│   ├── N2
│   └── N3
├── arruda_boyce_t
└── gent_t
```

## 4. Material kinematics

The constitutive model never depends on a specific FEM element.

```text
material_kinematics_t
├── F(3,3)
├── J
├── C(3,3)
├── B(3,3)
├── principal_stretches
├── optional time increment
└── optional temperature fields
```

The caller may be FEM, calibration, a point-test driver or an external adapter.

## 5. Material response

```text
material_response_t
├── strain_energy
├── first_piola_stress P
├── cauchy_stress
├── consistent_tangent
├── constitutive pressure quantities where applicable
├── J
├── updated trial-state data
└── status
```

Hyperelastic foundation:

`W = W(F)`

`P = ∂W / ∂F`

`A = ∂P / ∂F`

The exact canonical tangent representation is fixed by the Material Core API and documented independently from any external solver convention.

## 6. Material-point state

```text
material_point_state_t
├── committed
├── trial
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
revert        commit
```

History storage exists from the first release even when basic hyperelastic models are stateless. This enables later viscoelasticity, Mullins effect, hysteresis and damage without breaking the material API.

## 7. Constitutive law is not the incompressibility strategy

This separation is mandatory.

```text
Constitutive Law
      ↓
Canonical Material Response
      ↓
IIncompressibilityStrategy
      ↓
Element Formulation
```

A Yeoh, Ogden or other constitutive class does not decide whether the FE formulation uses mixed `u-p`, a volumetric penalty, or another constraint method.

Conceptually:

`W = W_iso(F_bar) + W_vol(J)`

but FE enforcement is owned by the formulation/constraint layer.

Target strategies:

```text
IIncompressibilityStrategy
├── Compressible
├── NearlyIncompressible
└── MixedUP
```

## 8. Native material-plugin architecture

DynaElastomerSolver supports extensibility without modifying FEM.

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

Canonical plugin call:

```text
evaluate(kinematics, trial_state, parameters)
    ↓
MaterialResponse
```

Required plugin capabilities:

- stable model identifier/version
- parameter metadata
- parameter validation
- material response evaluation
- state initialization
- trial/commit/revert support when stateful
- error/status reporting
- tangent declaration/availability

A plugin cannot expose ANSYS-, Marc-, FEBio- or other solver-native parameter conventions directly into the core. External conventions are converted at adapters.

## 9. Parameter metadata

Every material model declares a schema shared by UI, calibration, serialization and validation.

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

Metadata also records units/conventions, allowed bounds and model-version information.

## 10. Two material creation paths

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

Both produce the same canonical `material_parameter_set_t`.

## 11. Experimental datasets

Target dataset families:

- uniaxial tension
- compression
- simple shear
- planar tension
- biaxial tension
- volumetric/compressibility

Raw test data and processed/calibration-ready data are retained separately where practical so transformations remain traceable.

## 12. Calibration driver

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

Calibration and FEM never maintain duplicate implementations of the same constitutive law.

Model comparison is not based on R² alone. The selection/validation layer may consider:

- RMSE / residual structure
- parameter bounds
- physical admissibility
- stability checks
- valid strain range
- multi-mode consistency
- extrapolation behavior
- product-level validation

## 13. Material-point test driver

Every constitutive model can be exercised without a finite-element mesh.

```text
Prescribed deformation path
      ↓
material_kinematics_t
      ↓
Material Core
      ↓
Energy / Stress / Tangent / State
```

Target point-test paths include:

- uniaxial
- equibiaxial
- planar
- simple shear
- volumetric
- cyclic paths for future stateful models

## 14. Tangent diagnostic

No new material becomes FEM-eligible until its consistent tangent is verified.

Finite-difference reference:

`A_FD(iJkL) ≈ [P(F + εE_kL) - P(F - εE_kL)] / (2ε)`

Example relative error:

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

The diagnostic remains available as a development/verification tool even after production qualification.

## 15. Physical material vs mathematical fit

```text
material_definition_t
├── Identity
│   ├── polymer family
│   ├── compound ID
│   ├── supplier
│   ├── batch / lot
│   ├── hardness metadata
│   ├── density metadata
│   ├── cure condition
│   └── test/environment metadata
├── Experimental datasets
├── Parameter sets
│   ├── Yeoh fit
│   ├── Ogden fit
│   ├── Mooney-Rivlin fit
│   └── other models
└── Validation records
```

Not every identity/traceability field is a solver input; those fields preserve engineering provenance.

## 16. Provenance

Each parameter set records at minimum:

- source type
- source/reference identifier
- input dataset IDs
- calibration engine version
- material-model version
- optimizer
- objective definition
- parameter bounds
- fit metrics
- calibration date
- valid strain range
- test temperature range
- verification status
- product-validation links where available

The system must be able to answer: **Where did this parameter set come from?**

## 17. Validation status

Suggested states:

```text
REFERENCE
EXPERIMENTAL
CALIBRATED
VERIFIED
PRODUCT_VALIDATED
```

A generic literature value remains `REFERENCE`. A compound fitted from controlled experimental data and confirmed through independent/product tests may become `PRODUCT_VALIDATED`.

## 18. Material contribution to AnalysisPrecheck

The Material Core reports:

- parameter validity
- missing required parameters
- constitutive/formulation compatibility
- known validity range
- nearly-incompressible recommendation/requirement
- temperature-range warning
- stability-check status
- calibration/validation status
- plugin/model version availability

The global `AnalysisPrecheck` combines these with geometry, mesh and boundary-condition diagnostics.

## 19. Canonical external conversions

External solver conventions are never canonical.

```text
ANSYS Material Parameters
        ↓ adapter
Dyna Canonical Parameter Set

Marc Material Parameters
        ↓ adapter
Dyna Canonical Parameter Set
```

The reverse direction may be provided later for export/user-material integration.

## 20. Future solver adapters

```text
DynaElastomer Material Core
├── DynaElastomerSolver native
├── ANSYS adapter          [future]
├── Marc UMATERIAL adapter [future]
├── CalculiX adapter       [future]
└── generic material API   [future]
```

## 21. Initial implementation sequence

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
- Arruda-Boyce
- Gent
- parameter metadata
- stability/parameter validation

### MC-0.4
- `material_point_state_t`
- committed/trial/revert infrastructure
- plugin lifecycle contract

### MC-0.5
- experimental-data integration
- calibration engine
- provenance
- validation records

## 22. Production acceptance rule

A constitutive model is not production-ready until it passes the applicable stages:

1. parameter validation
2. analytical energy checks
3. analytical stress checks
4. numerical tangent comparison
5. material-point tests
6. calibration round-trip tests
7. single-element FEM tests
8. mixed/incompressibility compatibility tests
9. mesh-convergence benchmarks
10. independent solver comparison
11. experimental validation where applicable

## 23. Principle

> Material knowledge is not embedded in the FEM solver. Calibration, FEM, point testing and future external interfaces share one canonical constitutive implementation, while incompressibility enforcement remains an FE-formulation concern.
