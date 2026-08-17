# ADR-0004 — Qt Frontend Behind a Replaceable UI Boundary

**Status:** Accepted  
**Project:** DynaElastomerSolver

## Context

DynaElastomerSolver requires one professional desktop frontend that can run on both macOS and Windows. The product must preserve an Apple-inspired visual language while supporting CAE-style navigation, inspectors, engineering charts, a custom 2D/axisymmetric viewport, solver monitoring and future high-performance visualization.

Qt 6 / Qt Quick provides a mature cross-platform desktop and graphics stack for these requirements. However, DynaElastomerSolver must not become a Qt-shaped application internally. A future move to another UI technology must remain possible without rewriting the scientific core, project model, application behavior or engineering interaction model.

This decision supersedes only the framework-candidate portion of ADR-0003. ADR-0003 remains valid for the broader principle that DynaElastomerSolver owns its UI architecture and user experience.

## Decision

The initial production desktop frontend will use:

```text
Qt 6
+ Qt Quick / QML
+ Dyna Design System
```

Qt is classified as a **replaceable frontend/platform dependency**, not as a domain or application dependency.

The architecture is:

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

## Hard dependency boundary

Qt types are forbidden outside the Qt frontend implementation boundary.

The following types and concepts must not appear in the scientific core, canonical project model, application services or framework-neutral presentation contracts:

- `QObject`
- `QString`
- `QVector`
- `QVariant`
- `QModelIndex`
- `QAbstractItemModel`
- `QQuickItem`
- QML object references
- Qt-specific signals/slots as domain events
- Qt-specific serialization as the canonical project format

Qt-specific code belongs under a dedicated frontend namespace/directory such as:

```text
src/ui/frontends/qt/
```

## Framework-neutral presentation contracts

DynaElastomerSolver owns neutral models for UI-relevant application state.

Examples:

```text
NavigationNode
SelectionState
InspectorSchema
InspectorProperty
CommandDescriptor
WorkspaceDescriptor
JobStatus
ConvergenceSample
ResultViewModel
ViewportSceneModel
DesignTokenSet
```

These models use stable identifiers and framework-neutral data types.

A Qt adapter translates them into Qt/QML-facing objects:

```text
NavigationNode
      ↓
QtNavigationModel
      ↓
QML Navigator
```

The same neutral model could later be rendered by another frontend:

```text
NavigationNode
├── QtNavigationModel
├── FutureAvaloniaAdapter
└── FutureNativeAdapter
```

## Application behavior ownership

The following behavior remains outside Qt:

- project state and project file semantics
- module definitions
- navigation hierarchy
- selection semantics
- command enable/disable rules
- undo/redo intent
- validation and precheck rules
- solver job state
- result definitions
- inspector metadata
- engineering units and validation rules
- viewport scene data
- material, mesh, analysis and result workflows

Qt renders and forwards user interaction. It does not define these semantics.

## Design-system ownership

The Apple-inspired Dyna visual language is project-owned.

Canonical design tokens are kept independently from QML implementation details:

```text
Color
Typography
Spacing
Radius
Stroke
ControlSize
Motion
Elevation
SemanticState
```

QML components implement these specifications, but QML files are not the canonical definition of the design language.

This permits another frontend to reproduce the same product identity later.

## Visualization boundary

The V1 visualization data model is project-owned:

```text
ViewportSceneModel
├── geometry primitives
├── mesh primitives
├── contour field data
├── selection state
├── boundaries
├── annotations
├── vectors
├── probes
└── camera state
```

Rendering is behind an interface:

```text
ViewportSceneModel
        ↓
IViewportRenderer
        ↓
QtViewportBackend
```

Qt rendering APIs may be used inside `QtViewportBackend`, but raw Qt renderer objects must not leak into `InternalMesh`, `ResultDatabase`, `AnalysisGeometry`, selection state or result-processing code.

A later Metal, Vulkan, VTK, Avalonia or other backend can therefore be introduced without changing the canonical engineering models.

## Repository boundary

Target structure:

```text
src/
├── fortran/                 # scientific core; no Qt
├── application/             # application/domain services; no Qt
├── presentation/            # neutral UI contracts; no Qt
└── ui/
    ├── design/              # canonical Dyna design tokens/specification
    └── frontends/
        └── qt/
            ├── app/
            ├── adapters/
            ├── models/
            ├── qml/
            └── viewport/
```

## Build boundary

Qt should be discoverable only by frontend build targets.

Conceptually:

```text
DynaCoreFortran        -> no Qt
DynaApplication        -> no Qt
DynaPresentation       -> no Qt
DynaQtFrontend         -> Qt dependency allowed
DynaDesktopApp         -> links DynaQtFrontend
```

Tests or build checks should fail if Qt headers or Qt-linked libraries appear in lower layers.

## Platform strategy

The initial Qt frontend targets:

- macOS on Apple Silicon
- Windows x64
- Windows ARM64 later if required

macOS and Windows use the same Dyna information architecture and design system. Platform-specific window chrome, menus, keyboard conventions and system integration may adapt to the host OS without changing engineering workflows.

## Licensing policy

Qt licensing is treated as an explicit infrastructure concern.

- Use only intentionally approved Qt modules.
- Keep a dependency/license registry for every Qt module shipped.
- Avoid introducing GPL-only modules without an explicit product/licensing decision.
- Preserve the architectural ability to replace Qt if licensing, commercial, technical or strategic requirements change.

The legal distribution model must be reviewed separately before commercial release.

## Consequences

### Positive

- one frontend codebase for macOS and Windows
- strong desktop and graphics capabilities
- native-capable engineering viewport path
- Apple-inspired appearance remains project-owned
- scientific and application architecture remains independent of Qt
- future frontend replacement is possible without rewriting the solver or canonical engineering models

### Costs

- adapters must be maintained between neutral presentation models and Qt/QML
- some UI code will necessarily be rewritten if the frontend framework changes
- strict architecture tests are required to prevent Qt types from leaking downward
- Qt module/license choices must be tracked deliberately

## Replacement test

The architecture is considered healthy only if this statement remains true:

> Removing `src/ui/frontends/qt` may remove the current desktop UI, but it must not remove or invalidate DynaElastomerSolver's scientific core, project model, application services, presentation contracts, result database or engineering workflows.

## Guiding principle

> Qt is the first DynaElastomerSolver frontend implementation; Qt is not DynaElastomerSolver's architecture.
