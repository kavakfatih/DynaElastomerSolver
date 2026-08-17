# ADR-0003 — Owned UI Architecture

**Status:** Accepted  
**Project:** DynaElastomerSolver

## Context

DynaElastomerSolver requires a professional engineering desktop UI with ANSYS-like information architecture but a visually distinct, minimal technical design language. Open-source CAE systems provide useful ideas, but allowing an external CAE application or UI framework to become the owner of project state, engineering behavior or product identity would create unacceptable coupling.

## Decision

DynaElastomerSolver owns its complete user-experience architecture.

Owned components include:

- AppShell semantics
- module system
- Navigator structure
- Workspace model
- Inspector schemas
- selection model
- command system
- undo/redo intent
- solve monitor semantics
- result pipeline
- validation workflow
- visualization data model
- design system

External frameworks may provide frontend/platform capabilities such as windowing, input, text, GPU drawing, controls and OS integration, but they must remain replaceable implementations.

## Primary information architecture

ANSYS Mechanical is the main structural reference for:

- hierarchical engineering objects
- selection → properties behavior
- contextual commands
- central engineering viewport/workspace
- model readiness and solution state

Dyna deliberately does not copy ANSYS visual styling or its permanently dense Ribbon/large global tree.

Secondary references:

- FEBio Studio: model organization and solve monitoring
- SALOME: modular application shell
- PrePoMax: simple FEA interaction model
- Gmsh: minimal engineering workspace
- ParaView: result pipeline, properties and Basic/Advanced separation
- ElmerGUI: object browser and metadata-driven registration
- FEniCSx/MFront: UI independence from the scientific core

## Application shell

```text
Context Toolbar
      ↓
Navigator | Workspace | Inspector
      ↓
Utility / Solver / Convergence Panel
```

Top-level modules:

```text
Project
Geometry
Material Lab
Mesh
Analysis
Solve
Results
Validation
```

## Framework policy

The UI framework is infrastructure, not product architecture.

The framework selection itself is governed by the later decision:

- **ADR-0004 — Qt Frontend Behind a Replaceable UI Boundary**

Qt 6 / Qt Quick-QML is the selected initial production frontend, but no scientific, domain, canonical project or framework-neutral presentation model may depend on Qt types.

This preserves the original ADR-0003 principle: Dyna owns the experience; the framework only implements it.

## Visualization decision

DynaElastomerSolver will not initially embed ParaView/VTK/FEBio Studio as its visualization environment.

Because V1.0 focuses on 2D and axisymmetric analysis, the project owns `ViewportSceneModel`, geometry/mesh/result semantics, selection overlays and engineering probes. The current frontend may use Qt rendering infrastructure behind a renderer boundary.

A future `IViewportRenderer` implementation may use another rendering technology if 3D or very large datasets justify it.

## Consequences

### Positive

- product identity remains independent
- ANSYS-like workflow can be simplified for elastomers
- Material Lab and experimental validation can become first-class experiences
- solver UI can evolve independently from the Fortran solver
- frontend technology can be replaced without changing scientific data structures
- licensing exposure is localized to the frontend dependency boundary

### Costs

- AppShell, navigation, selection, inspector and result UX must be engineered internally
- custom viewport and engineering interaction require dedicated implementation/testing
- cross-platform behavior must be validated on both Windows and macOS
- adapters are required between neutral presentation contracts and the active frontend framework

## Guiding principle

> DynaElastomerSolver may use UI technology, but it does not outsource its user experience.
