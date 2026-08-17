# DynaElastomerSolver — UI Architecture v1.0

## 1. Goal

DynaElastomerSolver owns its user experience, information architecture and interaction model. The application will not embed or depend on another CAE application's UI. ANSYS Mechanical remains the primary information-architecture reference; FEBio Studio, SALOME, PrePoMax, Gmsh, ParaView, ElmerGUI, FEniCSx and MFront provide secondary architectural ideas.

The visual language is intentionally different from traditional CAE software: minimal, precise, technical and Apple-inspired, with restrained white/light-gray/dark-gray surfaces, limited system-blue accents, modest radii and no heavy visual decoration.

## 2. Ownership rule

```text
Dyna UI Architecture      OWNED
Dyna Design System        OWNED
Navigation / Selection    OWNED
Inspector / Commands      OWNED
Workspace behavior        OWNED
Result interaction        OWNED
Visualization data model  OWNED

Windowing / input / low-level GPU drawing
        ↓
replaceable platform/framework infrastructure
```

No external CAE application may define DynaElastomerSolver's UI state, project model, navigation structure or result model.

## 3. Primary UX model

ANSYS-inspired information architecture, simplified for elastomer engineering:

```text
┌──────────────────────────────────────────────────────────────┐
│ Context Toolbar                                              │
├──────────────┬─────────────────────────────┬─────────────────┤
│ Navigator    │ Workspace                   │ Inspector       │
│              │                             │                 │
│ Project      │ Geometry / Mesh             │ Properties      │
│ Materials    │ Material Curves             │ Validation      │
│ Analysis     │ Results / Charts            │ Advanced        │
│ Results      │                             │                 │
├──────────────┴─────────────────────────────┴─────────────────┤
│ Utility Panel: Messages | Jobs | Solver | Convergence | Data │
└──────────────────────────────────────────────────────────────┘
```

Core concept:

- Navigator answers: **Where am I and what object am I working on?**
- Workspace answers: **What engineering content am I viewing or editing?**
- Inspector answers: **What are the selected object's properties and validation state?**
- Context Toolbar answers: **What operations are relevant now?**
- Utility Panel answers: **What is the system/solver doing?**

## 4. Module architecture

The shell remains stable while engineering modules register their own UI contributions.

```text
DynaElastomerShell
        │
        ├── ProjectModule
        ├── GeometryModule
        ├── MaterialLabModule
        ├── MeshModule
        ├── AnalysisModule
        ├── SolveModule
        ├── ResultsModule
        └── ValidationModule
```

Each module exposes a `ModuleDefinition` containing:

```text
ModuleDefinition
├── NavigatorProvider
├── WorkspaceProvider
├── InspectorProvider
├── CommandProvider
├── ContextToolbarProvider
└── ValidationProvider
```

Future modules such as fatigue or viscoelastic characterization can be added without redesigning the application shell.

## 5. Main UI services

```text
AppShell
ProjectDocument
ModuleRegistry
NavigationService
SelectionService
CommandRegistry
UndoRedoService
InspectorService
WorkspaceManager
JobManager
NotificationService
VisualizationService
ApplicationServices
```

### SelectionService

Selection is centralized.

```text
Viewport selection
      ↓
SelectionService
├── Navigator highlight
├── Inspector update
├── Context command update
└── Result/geometry highlight
```

Navigator selection follows the same service in the opposite direction.

No module keeps an independent copy of the current selection.

### CommandRegistry

Commands such as `Import DXF`, `Validate`, `Generate Mesh`, `Run Calibration`, `Solve`, `Probe` and `Compare Test` are registered commands rather than hard-coded toolbar button logic.

This enables:

- keyboard shortcuts
- menus
- context toolbar
- command palette later
- undo/redo integration where applicable
- testable command enable/disable logic

## 6. Workspace model

The central area is not permanently a geometry viewport.

```text
Workspace
├── ProjectWorkspace
├── GeometryWorkspace
├── MaterialWorkspace
├── CalibrationWorkspace
├── MeshWorkspace
├── AnalysisWorkspace
├── SolveMonitorWorkspace
├── ResultsWorkspace
└── ValidationWorkspace
```

Examples:

- Geometry: 2D analysis geometry and boundaries
- Material Lab: test curves and constitutive fits
- Mesh: element visualization and quality
- Solve: convergence and increment history
- Results: contour / engineering charts
- Validation: simulation versus experiment

## 7. Contextual Navigator

DynaElastomerSolver does not use one indefinitely growing global tree.

Top-level navigation:

```text
Project
Geometry
Materials
Mesh
Analysis
Solve
Results
Validation
```

Inside a module, Navigator becomes module-specific.

Example — Geometry:

```text
Geometry
├── Regions
├── Boundaries
├── Selection Sets
└── Axis
```

Example — Material Lab:

```text
Materials
├── Library
├── Experimental Data
├── Material Models
├── Calibration
└── Validation
```

Example — Analysis:

```text
Analysis
├── Formulation
├── Material Assignment
├── Boundary Conditions
├── Solver Controls
└── Precheck
```

## 8. Inspector architecture

Inspector content is driven by selected-object metadata and specialized editors where required.

```text
Selected Object
      ↓
InspectorService
      ↓
Metadata / Editor Provider
      ↓
Inspector UI
```

Common properties should be metadata-driven rather than manually coded form-by-form.

Example metadata:

```text
RotationBC.Angle
Type: double
Unit: deg
Minimum: -360
Maximum: 360
Category: Definition
```

Specialized editors remain allowed for complex engineering content such as material calibration and result visualization.

## 9. Basic / Advanced model

Technical power must not require exposing every solver parameter by default.

Basic mode:

```text
Solver: Automatic
Mesh Size: 2 mm
Material Model: Yeoh-3
```

Advanced mode may expose:

- Newton strategy
- convergence tolerances
- maximum iterations
- line search
- increment limits
- mesh algorithm
- integration settings
- extrapolation options

The scientific defaults belong to the application layer, not to visual controls.

## 10. Deferred Apply

Expensive operations are explicit commands and do not execute on every property edit.

Examples:

```text
Mesh settings changed
        ↓
Pending Changes
        ↓
[Apply & Remesh]
```

Operations requiring deferred apply include:

- mesh generation
- geometry rebuild/healing
- calibration
- solve
- expensive result transformations

Cheap visual state changes remain immediate.

## 11. Analysis Precheck UI

`AnalysisPrecheck` is a first-class workspace/panel.

```text
Analysis Precheck

Geometry     ✓
Material     ✓
Mesh         ⚠
Constraints  ✓
Solver       ✓

Ready to Solve / Blocked
```

Every issue links back to the responsible object/module.

Precheck is not only a message log; it is actionable navigation.

## 12. Solve Monitor

The solver remains independent from the GUI, but the GUI has a dedicated live monitor.

```text
Solve Monitor
├── Current step
├── Current increment
├── Newton iteration
├── Residual norm
├── Increment size
├── Cutback events
├── Linear solver status
├── Warnings
└── Convergence chart
```

The UI receives structured job events from `JobManager` / application services. It never parses solver console text as its primary data source.

## 13. Result architecture

Solver data is not rendered directly.

```text
ResultDatabase
      ↓
ResultOperation
      ↓
ResultViewModel
      ↓
Visualization
```

Raw and display data remain distinct:

```text
RawResults
└── IntegrationPoint / Gauss Point

DisplayResults
└── extrapolated / averaged / derived results
```

Supported result operations will include:

- field selection
- nodal extrapolation
- averaging
- principal-value calculation
- derived engineering quantities
- path extraction
- history extraction
- experimental comparison

## 14. Native Gauss Point Inspector

A key scientific UI feature:

```text
Element 142
Gauss Point 3

λ1
λ2
λ3
J
Cauchy stress
pressure
strain energy
state variables
```

Users can inspect raw integration-point values without confusing them with smoothed/extrapolated contour data.

## 15. Visualization ownership

Initial scope is 2D / axisymmetric; therefore no external full CAE visualization application is required.

Project-owned visualization abstraction:

```text
VisualizationService
├── DynaViewport2D
├── GeometryRenderer
├── MeshRenderer
├── ResultRenderer
├── SelectionOverlay
├── AnnotationLayer
└── ChartRenderer
```

The domain/result model must not expose framework-specific or renderer-specific types.

A future renderer backend may be introduced behind an interface if 3D, volume rendering or very large datasets require it.

## 16. UI framework policy

The application UI is owned by DynaElastomerSolver, but a local cross-platform UI framework may provide low-level platform services.

Initial candidate: **Avalonia / .NET**.

Reasons:

- Windows and macOS support
- permissive MIT license
- C#/XAML productivity for a modular engineering desktop application
- custom styling suitable for a project-owned design system
- native interop path to the stable Dyna C ABI

Alternative candidate: **Qt 6** if future technical requirements favor its mature C++ desktop/model-view ecosystem.

The framework choice does not change Dyna's project data model, command system, application services or Fortran core.

## 17. Core bridge

UI never owns numerical physics.

```text
UI
 ↓
Application Services
 ↓
Dyna Native Client
 ↓
`des_*` C ABI
 ↓
Modern Fortran Core
```

Example application services:

```text
MaterialService
GeometryService
MeshService
AnalysisService
SolverService
ResultService
ValidationService
```

Only the native client/interoperability layer understands P/Invoke/C ABI details.

## 18. Visual design language

Dyna's visual identity is not ANSYS, Marc, FEBio Studio or ParaView.

Use:

- macOS/iOS-inspired minimal technical language
- white and very light gray surfaces
- dark gray/black typography
- limited system-blue accent
- clear hierarchy and whitespace
- compact technical controls
- modest corner radii
- precise alignment
- restrained separators

Avoid:

- orange accent
- heavy shadows
- oversized cards
- excessive gradients
- permanently visible dense ribbon controls
- decorative chrome that reduces engineering workspace

Information architecture may be ANSYS-inspired while appearance remains distinctly DynaElastomerSolver.

## 19. External UI dependency rule

Allowed:

```text
Local UI framework
Low-level renderer
Font/text shaping
OS integration
```

Not allowed as architectural owners:

```text
Embedded ParaView application
Embedded FEBio Studio UI
FreeCAD/SALOME as host shell
ANSYS-like external project manager
External material UI as canonical editor
```

Principle:

> External UI technologies may render and host controls; DynaElastomerSolver owns the engineering experience, application state and scientific interaction model.

## 20. Initial screen sequence

1. Project
2. Geometry
3. Material Lab
4. Mesh
5. Analysis
6. Precheck / Solve
7. Results
8. Validation

These screens share one AppShell and one project model rather than behaving as separate applications.
