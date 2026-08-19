#!/usr/bin/env python3
"""FEniCSx mixed Q2/DPC1 Cook quadrature convergence diagnostic.

Amaç: Dyna Q9/P1 ile bağımsız FEniCSx mixed referans arasında görülen
farkın integration order kaynaklı olup olmadığını ayırmak. Aynı n=4 Cook mesh,
aynı mixed continuum potential ve aynı function space ile yalnız UFL
quadrature_degree değiştirilir.

UFL quadrature_degree doğrudan "Gauss point count" değildir. Basix'in seçtiği
quadrature nokta sayısı ayrıca JSON'a yazılır; böylece Dyna 2x2/3x3/4x4
operatorleri ile karşılaştırma açık kalır.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from mpi4py import MPI
from petsc4py import PETSc

import basix
from basix.ufl import element, mixed_element
import numpy as np
import ufl

import dolfinx
from dolfinx import default_real_type, fem, geometry, mesh
from dolfinx.fem.petsc import NonlinearProblem

MU = 1.0
PRESSURE_COMPLIANCE = 1.0e-3
TRACTION_Y = 0.01
LOAD_STEPS = 8
MESH_N = 4
QUADRATURE_DEGREES = (2, 4, 6, 8)

Y_RIGHT_BOTTOM = 44.0 / 48.0
Y_RIGHT_TOP = 60.0 / 48.0
Y_LEFT_TOP = 44.0 / 48.0
Y_RIGHT_MID = 0.5 * (Y_RIGHT_BOTTOM + Y_RIGHT_TOP)


def global_scalar(msh: mesh.Mesh, expression) -> float:
    local_value = fem.assemble_scalar(fem.form(expression))
    return float(msh.comm.allreduce(local_value, op=MPI.SUM))


def create_cook_mesh(comm: MPI.Comm, n: int) -> mesh.Mesh:
    msh = mesh.create_rectangle(
        comm=comm,
        points=((0.0, 0.0), (1.0, 1.0)),
        n=(n, n),
        cell_type=mesh.CellType.quadrilateral,
    )
    x = msh.geometry.x
    s = x[:, 0].copy()
    t = x[:, 1].copy()
    left_y = t * Y_LEFT_TOP
    right_y = (1.0 - t) * Y_RIGHT_BOTTOM + t * Y_RIGHT_TOP
    x[:, 1] = (1.0 - s) * left_y + s * right_y
    return msh


def evaluate_midpoint_y(msh: mesh.Mesh, displacement: fem.Function) -> float:
    tree = geometry.bb_tree(msh, msh.topology.dim)
    for xcoord in (1.0, 1.0 - 1.0e-11):
        point = np.array([[xcoord, Y_RIGHT_MID, 0.0]], dtype=msh.geometry.x.dtype)
        candidates = geometry.compute_collisions_points(tree, point)
        colliding = geometry.compute_colliding_cells(msh, candidates, point)
        links = colliding.links(0)
        if len(links) > 0:
            cells = np.array([links[0]], dtype=np.int32)
            value = np.asarray(displacement.eval(point, cells)).reshape(-1)
            return float(np.real(value[1]))
    raise RuntimeError("Cook right-edge midpoint bulunamadı.")


def solve_case(quadrature_degree: int) -> dict:
    comm = MPI.COMM_WORLD
    scalar_type = PETSc.ScalarType
    msh = create_cook_mesh(comm, MESH_N)

    u_element = element(
        "Lagrange", msh.basix_cell(), 2, shape=(2,), dtype=default_real_type
    )
    p_element = element(
        "DPC",
        msh.basix_cell(),
        1,
        dpc_variant=basix.DPCVariant.legendre,
        discontinuous=True,
        dtype=default_real_type,
    )
    W = fem.functionspace(msh, mixed_element([u_element, p_element]))
    wh = fem.Function(W, name=f"mixed_qdeg_{quadrature_degree}")
    wh.x.array[:] = 0.0

    test = ufl.TestFunction(W)
    trial = ufl.TrialFunction(W)
    uh, ph = ufl.split(wh)

    fdim = msh.topology.dim - 1
    left_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], 0.0)
    )
    right_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], 1.0)
    )

    W_u = W.sub(0)
    V_u, _ = W_u.collapse()
    zero_u = fem.Function(V_u)
    zero_u.x.array[:] = 0.0
    left_dofs = fem.locate_dofs_topological((W_u, V_u), fdim, left_facets)
    bcs = [fem.dirichletbc(zero_u, left_dofs, W_u)]

    right_facets = np.sort(right_facets.astype(np.int32))
    tags = mesh.meshtags(
        msh,
        fdim,
        right_facets,
        np.ones(len(right_facets), dtype=np.int32),
    )

    metadata = {"quadrature_degree": quadrature_degree}
    dx = ufl.Measure("dx", domain=msh, metadata=metadata)
    ds = ufl.Measure("ds", domain=msh, subdomain_data=tags, metadata=metadata)

    F2 = ufl.Identity(2) + ufl.grad(uh)
    F = ufl.as_matrix(
        (
            (F2[0, 0], F2[0, 1], 0.0),
            (F2[1, 0], F2[1, 1], 0.0),
            (0.0, 0.0, 1.0),
        )
    )
    C = F.T * F
    J = ufl.det(F)
    I1 = ufl.tr(C)
    psi_iso = 0.5 * MU * (J ** (-2.0 / 3.0) * I1 - 3.0)
    psi_constraint = -ph * (J - 1.0) - 0.5 * PRESSURE_COMPLIANCE * ph * ph

    traction = fem.Constant(msh, np.zeros(2, dtype=scalar_type))
    potential = (psi_iso + psi_constraint) * dx - ufl.inner(traction, uh) * ds(1)
    residual = ufl.derivative(potential, wh, test)
    jacobian = ufl.derivative(residual, wh, trial)

    problem = NonlinearProblem(
        residual,
        wh,
        J=jacobian,
        bcs=bcs,
        petsc_options_prefix=f"des_qdiag_{quadrature_degree}_",
        petsc_options={
            "snes_type": "newtonls",
            "snes_linesearch_type": "bt",
            "snes_rtol": 1.0e-10,
            "snes_atol": 1.0e-11,
            "snes_max_it": 80,
            "snes_error_if_not_converged": True,
            "ksp_type": "preonly",
            "pc_type": "lu",
            "pc_factor_mat_solver_type": "mumps",
            "ksp_error_if_not_converged": True,
        },
    )

    iterations = []
    reason = 0
    for load_step in range(1, LOAD_STEPS + 1):
        traction.value[:] = np.array(
            [0.0, TRACTION_Y * load_step / LOAD_STEPS], dtype=scalar_type
        )
        problem.solve()
        reason = int(problem.solver.getConvergedReason())
        iterations.append(int(problem.solver.getIterationNumber()))
        if reason <= 0:
            raise RuntimeError(
                f"quadrature_degree={quadrature_degree} SNES failed: reason={reason}"
            )

    u_result = wh.sub(0).collapse()
    midpoint_y = evaluate_midpoint_y(msh, u_result)
    area = global_scalar(msh, 1.0 * dx)
    p_mean = global_scalar(msh, ph * dx) / area
    p_second = global_scalar(msh, ph * ph * dx) / area
    p_rms = math.sqrt(max(p_second, 0.0))
    p_std = math.sqrt(max(p_second - p_mean * p_mean, 0.0))
    constraint = (J - 1.0) + PRESSURE_COMPLIANCE * ph
    constraint_l2 = math.sqrt(
        max(global_scalar(msh, constraint * constraint * dx) / area, 0.0)
    )

    _, quadrature_weights = basix.make_quadrature(
        basix.CellType.quadrilateral, quadrature_degree
    )

    return {
        "quadrature_degree": quadrature_degree,
        "basix_cell_quadrature_points": int(len(quadrature_weights)),
        "midpoint_y_displacement": midpoint_y,
        "pressure_mean": p_mean,
        "pressure_std": p_std,
        "pressure_rms": p_rms,
        "volumetric_constraint_l2_rms": constraint_l2,
        "snes_iterations": int(sum(iterations)),
        "snes_reason": reason,
    }


def relative_gap(a: float, b: float) -> float:
    return abs(a - b) / max(abs(b), 1.0e-15)


def main() -> None:
    comm = MPI.COMM_WORLD
    cases = [solve_case(degree) for degree in QUADRATURE_DEGREES]
    if comm.rank != 0:
        return

    tips = [case["midpoint_y_displacement"] for case in cases]
    gaps = [relative_gap(tips[i - 1], tips[i]) for i in range(1, len(tips))]
    result = {
        "schema_version": 1,
        "diagnostic": "fenicsx_mixed_q2_dpc1_quadrature_convergence",
        "dolfinx_version": str(dolfinx.__version__),
        "mesh": f"{MESH_N}x{MESH_N}",
        "mu": MU,
        "pressure_compliance": PRESSURE_COMPLIANCE,
        "tip_definition": "right_edge_geometric_midpoint",
        "cases": cases,
        "successive_displacement_gaps": gaps,
        "note": "Diagnostic only; no commercial-solver parity claim.",
    }

    out = Path("reference-results")
    out.mkdir(exist_ok=True)
    path = out / "fenicsx-v03-mixed-quadrature-diagnostic.json"
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
