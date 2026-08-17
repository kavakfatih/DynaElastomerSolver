# ADR-0003 — Owned UI Architecture

**Status:** Accepted  
**Project:** DynaElastomerSolver

## Context

DynaElastomerSolver requires a professional engineering desktop UI with ANSYS-like information architecture but a visually distinct, minimal technical design language. Open-source CAE systems provide useful ideas, but allowing an external CAE application to become the host UI would couple project state, interaction and product identity to another system.

## Decision

DynaElastomerSolver will own its complete user-experience architecture.

Owned components include:

- AppShell
- module system
- Navigator
- Workspace manager
- Inspector
- selection model
- command system
- undo/redo behavior
- solve monitor
- result pipeline
- validation workflow
- visualization data model
- design system

External frameworks may provide only low-level platform capabilities such as windowing, input, text, GPU drawing and OS integration.

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

## Framework decision

The UI framework is infrastructure, not product architecture.

Initial implementation candidate: **Avalonia/.NET**.

Rationale:

- cross-platform Windows/macOS desktop support
- MIT licensing
- suitable custom styling
- productive application/UI layer separate from Modern Fortran
- straightforward native ABI bridge through C-compatible functions

Qt remains a valid alternative if future prototyping demonstrates a decisive advantage for CAE-specific desktop/model-view or visualization integration.

The final framework is selected through an implementation spike before production UI work. No scientific/domain model may depend on Avalonia or Qt types.

## Visualization decision

DynaElastomerSolver will not initially embed ParaView/VTK/FEBio Studio as its visualization environment.

Because V1.0 focuses on 2D and axisymmetric analysis, the project will own `DynaViewport2D`, geometry/mesh/result render logic and selection overlays. Low-level drawing may use the selected framework's rendering infrastructure.

A future `IRenderBackend` may host a specialized external rendering library if 3D or very large datasets justify it.

## Consequences

### Positive

- product identity remains independent
- ANSYS-like workflow can be simplified for elastomers
- Material Lab and experimental validation can become first-class experiences
- solver UI can evolve independently from the Fortran solver
- external UI framework can be changed without changing scientific data structures
- licensing exposure is reduced compared with embedding a full CAE environment

### Costs

- AppShell, navigation, selection, inspector and result UX must be engineered internally
- custom viewport and engineering interaction require dedicated implementation/testing
- cross-platform behavior must be validated on both Windows and macOS

## Guiding principle

> DynaElastomerSolver may use UI technology, but it does not outsource its user experience.
