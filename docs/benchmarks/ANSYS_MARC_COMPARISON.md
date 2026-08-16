# DynaElastomerSolver — ANSYS / Hexagon Marc Architecture Benchmark

**Purpose:** Compare DynaElastomerSolver with mature commercial nonlinear FEA systems specifically in the elastomer-analysis chain.  
**Scope:** Materials, geometry, meshing, formulations, nonlinear solution, result semantics and validation.  
**Non-goal:** Feature-count parity with general-purpose CAE platforms.

---

## 1. Executive comparison

| Area | ANSYS Mechanical | Hexagon Marc / Mentat | DynaElastomerSolver direction |
|---|---|---|---|
| Product scope | General-purpose CAE | Strong nonlinear/general-purpose FEA | Specialized elastomer platform |
| Material management | Engineering Data / libraries / Granta ecosystem | Built-in material definitions, fitting and user materials | Material Lab + solver-independent Material Core |
| Hyperelasticity | Broad built-in family | Strong nonlinear rubber material capability | Focused native family + plugin API |
| Experimental fitting | Built into Engineering Data workflows | Dedicated experimental elastomer workflows/material fitting | Central product workflow |
| Material provenance | General material-data infrastructure | General material-data infrastructure | Explicit parameter provenance + validation states |
| Geometry | Broad CAD/import ecosystem | Mentat/CAD import and model setup | DXF → project-owned AnalysisGeometry |
| Sketch/CAD tools | Extensive | Broader than required here | Explicitly out of scope |
| Geometry checking | Mature geometry validation/repair workflows | Preprocessing/model checking capabilities | Geometry Check → Heal → Recheck |
| Mesh | Extensive controls and element families | Mature mesh/preprocessor environment | Replaceable IMeshProvider; Gmsh first |
| Nearly incompressible elastomers | Mixed displacement-pressure formulations available | Specialized incompressible/Herrmann-type formulations | Mixed `u-p` early in roadmap |
| Axisymmetric torsion | Supported in relevant 2D element technology | Nonlinear axisymmetric capabilities | Core specialized formulation |
| Nonlinear solver | Mature Newton/step/convergence controls | Core strength; mature nonlinear controls | Project-owned NonlinearSolutionManager |
| Linear solver | Direct/iterative solver options | Mature solver backend | `ILinearSolver`, MUMPS initial candidate |
| Raw integration-point data | Available through solver/result infrastructure | Calculated at integration points; postprocessing often extrapolates | Explicit RawResults + GaussPointInspector |
| Display result fields | Rich contours/probes/paths | Mentat postprocessing | Elastomer-focused contours/probes/path/history |
| Experiment comparison | Possible through broader workflows | Possible through broader workflows | Native simulation ↔ physical-test comparison |

---

## 2. Material definition

### ANSYS pattern

ANSYS uses Engineering Data as the main project material-definition environment. Materials may be pulled from libraries or created/edited in the project. Hyperelastic data can be defined from parameters and experimental curve-fitting workflows.

### Marc pattern

Marc/Mentat provides built-in nonlinear material models and routes for experimental data fitting; custom behavior can be introduced through user-material capabilities.

### DynaElastomerSolver decision

Dyna uses three distinct concepts:

```text
Physical Material
       ↓
Experimental Data
       ↓
Constitutive Parameter Sets
       ↓
Validation Records
```

A compound name is not itself a constitutive model. One physical material may own several fits, such as Yeoh and Ogden.

The system records where each parameter set came from.

---

## 3. Hyperelastic material family

### Target V1.0 Dyna library

```text
Hyperelastic
├── Neo-Hookean
├── Mooney-Rivlin
├── Yeoh
├── Ogden N1/N2/N3
├── Arruda-Boyce
└── Gent
```

Commercial solvers contain a broader catalog. Dyna intentionally targets a smaller, highly verified elastomer set first.

### Main architectural difference

Dyna separates:

```text
Constitutive Law
        ≠
Incompressibility Strategy
        ≠
Element Formulation
```

The material class does not decide the FE constraint method.

---

## 4. Material extensibility

Marc user-material mechanisms demonstrate the value of an extensible constitutive interface. Open-source MFront/FEBio references reinforce the same principle.

Dyna therefore defines:

```text
Material Core
├── Native Models
├── User Material Plugin
└── External Material Adapter
```

The canonical material call returns energy/stress/tangent/state through the project-owned data model.

---

## 5. Experimental calibration

Commercial reference systems support hyperelastic fitting from experimental test data.

Dyna makes calibration a primary system rather than a supporting utility:

```text
Experimental Dataset
        ↓
Data Transformation
        ↓
Material Core
        ↓
Optimizer
        ↓
Parameter Set
        ↓
Fit Metrics + Provenance
```

Model selection considers more than one scalar goodness-of-fit value. The framework is designed to support:

- RMSE / residuals
- R² as a descriptive metric
- parameter limits
- physical admissibility
- stability checks
- multi-mode consistency
- valid strain range
- extrapolation behavior
- product-test validation

---

## 6. Geometry

### Commercial systems

ANSYS and Marc support broader geometry and preprocessing workflows because they serve many physics and element families.

### Dyna decision

```text
External CAD
   ↓
DXF
   ↓
IDxfImporter
   ↓
AnalysisGeometry
```

No internal sketch environment is planned.

AnalysisGeometry contains curves, loops, regions, boundaries, selection sets and axis definitions solely for analysis preparation.

---

## 7. Geometry tools

Dyna borrows the mature workflow concept, not the CAD breadth:

```text
Geometry Check
├── Open contour
├── Gap
├── Duplicate
├── Tiny edge
├── Intersection
├── Invalid loop
├── Zero area
└── Axisymmetric validity

         ↓
Controlled Heal
         ↓
Recheck
```

Named/selection sets represent engineering meaning independently of mesh numbering.

---

## 8. Meshing

ANSYS and Marc provide mature meshing environments. Dyna initially uses a replaceable provider architecture:

```text
AnalysisGeometry
       ↓
IMeshProvider
       ↓
GmshMeshProvider
       ↓
InternalMesh
```

`InternalMesh` retains:

- nodes
- elements
- element sets
- boundary sets
- region/material sets
- element orientation
- integration scheme
- mesh-quality metadata

Planned user controls include global size, edge divisions, local/region sizing, mapped quad requests and mesh-quality inspection.

---

## 9. Nearly-incompressible elastomer formulation

Commercial nonlinear FEA systems use specialized formulations because displacement-only low-order elements can lock for nearly incompressible rubber.

Dyna therefore treats mixed technology as an early production requirement:

```text
Plane strain          ux, uy, p
Axisymmetric          ur, uz, p
Axisymmetric torsion  ur, uz, φ, p
```

Displacement-only Q4 technology is a learning/verification foundation, not the final production elastomer formulation.

---

## 10. Nonlinear solution

The benchmark showed that robust nonlinear analysis is not equivalent to implementing Newton-Raphson alone.

Dyna v1.2 architecture:

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

The system owns FEM and nonlinear solution logic.

---

## 11. Solver-control philosophy

Commercial systems expose many controls because they solve a very broad problem class.

Dyna uses two levels:

### Automatic

Elastomer-focused defaults selected by the application.

### Advanced

Expert control of:

- Full/Modified Newton
- tangent update behavior
- maximum iterations
- convergence tolerances
- initial/min/max increment
- cutback
- line search
- predictor
- linear solver backend

This provides technical depth without making the normal workflow unnecessarily complex.

---

## 12. Linear solution

The nonlinear FEM solver is project-owned. The low-level sparse system may be solved by replaceable infrastructure:

```text
K Δu = -R
```

```text
ILinearSolver
├── Dense/LAPACK
├── MUMPS
├── PARDISO   [future]
├── PETSc     [future]
└── Internal  [future]
```

Using an external sparse solver does not outsource the FEM physics.

---

## 13. Result semantics

Commercial FEM systems compute many constitutive quantities at integration points and then transform/extrapolate them for visualization.

Dyna makes that distinction explicit:

```text
ResultDatabase
├── RawResults
│   ├── Primary nodal DOFs
│   └── IntegrationPoint fields
├── DisplayResults
│   └── Extrapolated / averaged fields
└── GlobalHistories
```

The application records how a display field was derived.

---

## 14. Gauss-point inspection

Direct integration-point access is a V1.0 requirement.

Example:

```text
Element 1042
Gauss Point 1

λ1
λ2
λ3
J
σ12
W
p
state variables
```

This supports constitutive debugging, verification and investigation of critical high-strain rubber regions.

---

## 15. Elastomer-specific result priorities

Dyna emphasizes:

- principal stretches
- shear measures
- hydrostatic pressure
- Jacobian `J`
- strain-energy density
- reaction torque/force
- torque-angle
- force-displacement
- tangent/secant stiffness

Generic quantities may still be available, but the product is optimized around elastomer engineering interpretation.

---

## 16. Result tools

Target V1.0 tools:

- contour
- result scoping
- min/max
- node probe
- element probe
- Gauss-point probe
- path
- chart/history
- reaction force/torque
- derived results
- CSV export
- engineering report

A future deformed-profile DXF export may be added for geometry comparison/design workflows.

---

## 17. Experiment ↔ simulation validation

This is one of the principal Dyna differentiators.

```text
FEA Torque-Angle / Force-Displacement
                +
Physical Product Test
                ↓
Overlay / Alignment
                ↓
Error Metrics
                ↓
Validation Record
```

Target metrics:

- RMSE
- maximum absolute error
- mean error
- relative error
- stiffness error
- comparison validity range

This creates a closed chain from material test data to product validation.

---

## 18. What Dyna intentionally does not copy

The initial product does not target:

- broad internal CAD
- CFD
- electromagnetics
- general multiphysics
- large metal-plasticity catalog
- general beam/shell catalog
- topology optimization
- broad 3D contact capability in the first release

These omissions are strategic, not missing architecture.

---

## 19. Architectural conclusion

ANSYS contributes valuable reference patterns for engineering-data management, preprocessing, meshing, solver controls and postprocessing breadth.

Marc is an especially important benchmark for nonlinear elastomer behavior, material extensibility, incompressibility and robust nonlinear solution workflows.

DynaElastomerSolver adopts the relevant engineering principles while maintaining a narrower product identity:

```text
Material Characterization
        ↓
Calibration
        ↓
Validated Constitutive Model
        ↓
2D / Axisymmetric / Torsion FEM
        ↓
Transparent Nonlinear Solution
        ↓
Raw + Engineering Results
        ↓
Physical Test Validation
```

---

## 20. Reference documentation

Official/reference sources used during architecture study include:

### ANSYS

- ANSYS Mechanical / Engineering Data documentation
- ANSYS hyperelastic material and curve-fitting documentation
- ANSYS PLANE182 element documentation
- ANSYS nonlinear Static Structural / solver-control documentation
- ANSYS Mechanical result/postprocessing documentation

Primary documentation domain: `https://ansyshelp.ansys.com/`

### Hexagon Marc

- Hexagon Marc product/release information
- Hexagon Nexus Marc documentation/community technical discussions on materials, incompressibility, user materials, nonlinear solution and postprocessing

Primary product/community domains:

- `https://nexus.hexagon.com/home/product/marc/`
- `https://nexus.hexagon.com/community/public/marc/`

This benchmark document records architectural conclusions, not a compatibility certification against either commercial solver.
