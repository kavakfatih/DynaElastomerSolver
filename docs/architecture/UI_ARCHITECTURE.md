# DynaElastomerSolver — UI Architecture v1.1

## 1. Goal

DynaElastomerSolver owns its user experience, information architecture, engineering interaction model and visual identity.

The initial production desktop frontend uses **Qt 6 + Qt Quick/QML**, targeting both macOS and Windows. Qt is deliberately treated as a replaceable frontend/platform dependency. The scientific core, application behavior, canonical project model and framework-neutral presentation contracts must remain usable if the UI framework is replaced later.

ANSYS Mechanical remains the primary information-architecture reference. FEBio Studio, SALOME, PrePoMax, Gmsh, ParaView, ElmerGUI, FEniCSx and MFront provide secondary architectural ideas.

The visual language is intentionally different from traditional CAE software: minimal, precise, technical and Apple-inspired, with restrained white/light-gray/dark-gray surfaces, limited system-blue accents, modest radii and no heavy decoration.

## 2. Ownership rule

```text
Dyna Scientific Core        OWNED
Dyna Application Model      OWNED
Dyna Presentation Contracts OWNED
Dyna UI Architecture        OWNED
Dyna Design System          OWNED
Navigation / Selection      OWNED
Inspector / Commands        OWNED
Workspace behavior          OWNED
Result interaction          OWNED
Visualization data model    OWNED

Qt 6 / Qt Quick / QML
        ↓
replaceable frontend/platform implementation
```

No external CAE application or UI framework may define DynaElastomerSolver's canonical engineering state.

## 3. Dependency direction

The dependency direction is one-way:

```text
Modern Fortran Scientific Core
              ↓
          `des_*` C ABI
              ↓
UI-independent Application Core
              ↓
Framework-neutral Presentation Contracts
              ↓
        Qt Frontend Adapters
              ↓
       Qt Quick / QML UI
```

The lower layers never import, reference or expose Qt types.

### Hard boundary rule

The following must remain inside the Qt frontend implementation:

- `QObject`
- `QString`
- `QVector`
- `QVariant`
- `QModelIndex`
- `QAbstractItemModel`
- `QQuickItem`
- Qt signals/slots used as presentation plumbing
- QML object references
- Qt-specific serialization
- Qt renderer handles

Domain and application code use framework-neutral structures, stable IDs, standard C/C++ types and canonical Dyna models.

## 4. Primary UX model

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

## 5. Module architecture

The shell remains stable while engineering modules register their own contributions.

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

Each module exposes a framework-neutral `ModuleDefinition`:

```text
ModuleDefinition
├── NavigatorProvider
├── WorkspaceProvider
├── InspectorProvider
├── CommandProvider
├── ContextToolbarProvider
└── ValidationProvider
```

Future modules such as fatigue, viscoelastic characterization or dynamics can be added without redesigning the application shell.

## 6. Framework-neutral presentation contracts

Presentation semantics are owned by DynaElastomerSolver rather than QML.

Initial contract families:

```text
NavigationNode
SelectionState
InspectorSchema
InspectorSection
InspectorProperty
CommandDescriptor
WorkspaceDescriptor
ModuleDefinition
JobStatus
ConvergenceSample
NotificationModel
ResultViewModel
ViewportSceneModel
DesignTokenSet
```

Example:

```text
NavigationNode
      ↓
QtNavigationModel
      ↓
QML Navigator
```

A future frontend can consume the same contract:

```text
NavigationNode
├── QtNavigationModel
├── FutureAvaloniaAdapter
└── FutureNativeAdapter
```

The intention is not to make UI markup portable. It is to make **engineering behavior and state portable**.

## 7. Main application services

Framework-independent services:

```text
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

Selection is centralized:

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

The canonical selection stores Dyna entity identifiers, not `QModelIndex`, QML objects or renderer pointers.

### CommandRegistry

Commands such as `Import DXF`, `Validate`, `Generate Mesh`, `Run Calibration`, `Solve`, `Probe` and `Compare Test` are registered commands rather than hard-coded toolbar logic.

This enables:

- keyboard shortcuts
- native menus
- context toolbar
- command palette later
- undo/redo integration where applicable
- testable enable/disable rules
- future frontend replacement

## 8. Workspace model

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

## 9. Contextual Navigator

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

## 10. Inspector architecture

Inspector content is driven by selected-object metadata and specialized editors where required.

```text
Selected Object
      ↓
InspectorService
      ↓
InspectorSchema / Editor Provider
      ↓
Frontend adapter
      ↓
Inspector UI
```

Common properties are metadata-driven rather than manually coded form-by-form.

Example canonical metadata:

```text
RotationBC.Angle
Type: double
Unit: deg
Minimum: -360
Maximum: 360
Category: Definition
```

Qt/QML decides how to draw this property, but it does not own its engineering definition or validation rules.

Specialized editors remain allowed for complex engineering content such as material calibration and result visualization.

## 11. Basic / Advanced model

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

Scientific defaults belong to the application layer, not QML controls.

## 12. Deferred Apply

Expensive operations are explicit commands and do not execute on every property edit.

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

## 13. Analysis Precheck UI

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

## 14. Solve Monitor

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

The frontend receives structured job events from `JobManager` / application services. It never parses solver console text as its primary data source.

## 15. Result architecture

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

Supported result operations include:

- field selection
- nodal extrapolation
- averaging
- principal-value calculation
- derived engineering quantities
- path extraction
- history extraction
- experimental comparison

## 16. Native Gauss Point Inspector

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

## 17. Visualization ownership

Initial scope is 2D / axisymmetric; therefore no external full CAE visualization application is required.

Canonical visualization model:

```text
ViewportSceneModel
├── geometry primitives
├── mesh primitives
├── contour fields
├── selection state
├── boundaries
├── annotations
├── vectors
├── probes
└── camera state
```

Rendering boundary:

```text
ViewportSceneModel
        ↓
IViewportRenderer
        ↓
QtViewportBackend
```

Project-owned visualization responsibilities:

```text
VisualizationService
├── scene construction
├── engineering selection semantics
├── contour definitions
├── annotations
├── probe definitions
└── camera/navigation state
```

Qt may implement the current drawing backend, but Qt renderer objects do not leak into `AnalysisGeometry`, `InternalMesh`, `ResultDatabase` or presentation contracts.

A future renderer/backend may use Metal, Vulkan, VTK, Avalonia or another technology without changing the engineering models.

## 18. UI framework policy

### Selected initial frontend

```text
Qt 6
+ Qt Quick / QML
+ Dyna Design System
```

Reasons:

- one desktop frontend codebase for macOS and Windows
- strong C++/QML separation for a native scientific application
- mature desktop, input and graphics capabilities
- suitable path for a high-performance custom engineering viewport
- direct native interoperability path from C++ to the stable Dyna C ABI
- strong Apple Silicon/macOS support while preserving Windows support

Qt is a frontend technology, not a canonical model.

### Replacement requirement

The architecture must remain valid if Qt is removed.

Healthy replacement test:

> Removing `src/ui/frontends/qt` may remove the current desktop UI, but it must not remove or invalidate the scientific core, project model, application services, presentation contracts, result database or engineering workflows.

### Future alternatives

A future frontend may be implemented with:

- Avalonia
- SwiftUI/AppKit for a native macOS-only frontend
- WinUI for a native Windows-only frontend
- another suitable desktop UI framework

No such migration should require changes to the Modern Fortran physics or canonical engineering models.

## 19. Core bridge

UI never owns numerical physics.

```text
Qt/QML Frontend
      ↓
Qt Presentation Adapters
      ↓
Presentation Contracts
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

Only the native client/interoperability layer understands the C ABI details.

## 20. Dyna Design System

The visual design system is canonical project-owned specification, not a collection of QML styling accidents.

Canonical tokens:

```text
DesignTokenSet
├── Color
├── Typography
├── Spacing
├── Radius
├── Stroke
├── ControlSize
├── Motion
├── Elevation
└── SemanticState
```

Qt/QML implements these tokens for the current frontend. A future frontend implements the same design language independently.

Visual identity:

- Apple/macOS-inspired minimal technical language
- white and very light gray surfaces
- dark gray/black typography
- limited system-blue accent
- clear hierarchy and whitespace
- compact technical controls
- modest corner radii
- precise alignment
- restrained separators
- light/dark system appearance support

Avoid:

- orange accent
- heavy shadows
- oversized cards
- excessive gradients
- permanently visible dense ribbon controls
- decorative chrome that reduces engineering workspace

Information architecture may be ANSYS-inspired while appearance remains distinctly DynaElastomerSolver.

## 21. Platform adaptation

macOS and Windows share the same engineering UX, but platform conventions can adapt at the shell edge.

Examples:

```text
macOS
├── native/global menu conventions
├── Apple keyboard conventions
├── window/titlebar integration
└── Apple Silicon optimized build

Windows
├── Windows window conventions
├── Windows keyboard conventions
└── native deployment integration
```

These adaptations must not fork application semantics.

## 22. Repository boundary

Target structure:

```text
src/
├── fortran/
│   └── ...                       # no Qt
├── application/
│   └── ...                       # no Qt
├── presentation/
│   ├── navigation/
│   ├── inspector/
│   ├── commands/
│   ├── results/
│   └── viewport/                 # no Qt
└── ui/
    ├── design/                   # canonical Dyna design specification
    └── frontends/
        └── qt/
            ├── app/
            ├── adapters/
            ├── models/
            ├── qml/
            └── viewport/
```

## 23. Build boundary

Qt dependencies are permitted only in frontend targets.

Conceptually:

```text
DynaCoreFortran        -> no Qt
DynaApplication        -> no Qt
DynaPresentation       -> no Qt
DynaQtFrontend         -> Qt allowed
DynaDesktopApp         -> links DynaQtFrontend
```

Build/lint tests should fail if Qt includes or Qt-linked libraries leak into the lower layers.

## 24. Qt licensing/dependency policy

Qt dependencies are explicit and audited.

Rules:

- use only intentionally approved Qt modules
- maintain a dependency/license registry for every shipped module
- avoid GPL-only modules without an explicit licensing/product decision
- pin and validate supported Qt versions rather than blindly following latest
- keep Qt-specific code localized so technical, commercial or licensing changes do not force a product rewrite

Commercial distribution licensing must be reviewed separately before release.

## 25. External UI dependency rule

Allowed behind controlled boundaries:

```text
Qt frontend/platform services
low-level renderer backend
font/text shaping
OS integration
```

Not allowed as architectural owners:

```text
Embedded ParaView application
Embedded FEBio Studio UI
FreeCAD/SALOME as host shell
ANSYS-like external project manager
External material UI as canonical editor
Qt types in domain/application models
QML as the canonical project state
```

Principle:

> External UI technologies may render and host controls; DynaElastomerSolver owns the engineering experience, application state and scientific interaction model.

## 26. Initial screen sequence

1. Project
2. Geometry
3. Material Lab
4. Mesh
5. Analysis
6. Precheck / Solve
7. Results
8. Validation

These screens share one AppShell and one project model rather than behaving as separate applications.

## 27. Governing decisions

- ADR-0003 — Owned UI Architecture
- ADR-0004 — Qt Frontend Behind a Replaceable UI Boundary
