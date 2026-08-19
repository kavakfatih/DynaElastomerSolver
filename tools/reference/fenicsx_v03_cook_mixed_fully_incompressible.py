#!/usr/bin/env python3
"""DynaElastomerSolver V0.3 fully-incompressible mixed u-p Cook referansi.

Bu script Dyna Fortran element/assembly/tangent/Newton kodunu kullanmaz.
DOLFINx/UFL/PETSc uzerinde ayni continuum mixed potential bagimsiz kurulur:

  W_iso = mu/2 * (J^(-2/3) I1 - 3)
  Pi_p  = -p*(J-1)

Pressure gercek Lagrange multiplier'dir ve weak pressure denklemi J-1=0'dur.
Dyna Q9/P1 ile matched-discrete karsilastirma icin:

  displacement = continuous Q2 Lagrange
  pressure     = discontinuous DPC degree 1 / 3 complete-linear cell DOF
  quadrature   = Basix degree 4 -> quadrilateral hucrede 9 nokta (3x3)

kullanilir. Cook traction/free-boundary problemi pressure constant mode'u momentum
denklemleri araciligiyla belirler; pressure'a yapay Dirichlet kosulu eklenmez.
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
PRESSURE_COMPLIANCE = 0.0
TRACTION_Y = 0.01
LOAD_STEPS = 8
QUADRATURE_DEGREE = 4
MESH_LEVELS = (2, 4, 8, 16)
REFERENCE_CONVERGENCE_THRESHOLD = 0.01

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
            if value.size < 2:
                raise RuntimeError("Fully incompressible Cook displacement okunamadi.")
            return float(np.real(value[1]))
    raise RuntimeError("Fully incompressible Cook right-edge midpoint bulunamadi.")


def solve_case(n: int) -> dict:
    comm = MPI.COMM_WORLD
    scalar_type = PETSc.ScalarType
    msh = create_cook_mesh(comm, n)

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
    wh = fem.Function(W, name="fully_incompressible_mixed_u_p")
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
    right_tags = mesh.meshtags(
        msh,
        fdim,
        right_facets,
        np.ones(len(right_facets), dtype=np.int32),
    )

    metadata = {"quadrature_degree": QUADRATURE_DEGREE}
    dx = ufl.Measure("dx", domain=msh, metadata=metadata)
    ds = ufl.Measure("ds", domain=msh, subdomain_data=right_tags, metadata=metadata)

    F2 = ufl.Identity(2) + ufl.grad(uh)
    F = ufl.as_matrix(
        (
            (F2[0, 0], F2[0, 1], 0.0),
            (F2[1, 0], F2[1, 1], 0.0),
            (0.0, 0.0, 1.0),
        )
    )
    C = F.T * F
    I1 = ufl.tr(C)
    J = ufl.det(F)

    psi_iso = 0.5 * MU * (J ** (-2.0 / 3.0) * I1 - 3.0)
    psi_constraint = -ph * (J - 1.0)

    traction = fem.Constant(msh, np.zeros(2, dtype=scalar_type))
    potential = (psi_iso + psi_constraint) * dx - ufl.inner(traction, uh) * ds(1)
    residual = ufl.derivative(potential, wh, test)
    jacobian = ufl.derivative(residual, wh, trial)

    problem = NonlinearProblem(
        residual,
        wh,
        J=jacobian,
        bcs=bcs,
        petsc_options_prefix=f"des_fenicsx_v03_fi_{n}_",
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

    iterations_per_step: list[int] = []
    reason = 0
    for load_step in range(1, LOAD_STEPS + 1):
        traction.value[:] = np.array(
            [0.0, TRACTION_Y * load_step / LOAD_STEPS], dtype=scalar_type
        )
        problem.solve()
        reason = int(problem.solver.getConvergedReason())
        iterations_per_step.append(int(problem.solver.getIterationNumber()))
        if reason <= 0:
            raise RuntimeError(
                "Fully incompressible mixed Cook SNES yakinsamadi: "
                f"n={n}, step={load_step}/{LOAD_STEPS}, reason={reason}"
            )

    u_result = wh.sub(0).collapse()
    midpoint_y = evaluate_midpoint_y(msh, u_result)

    area = global_scalar(msh, 1.0 * dx)
    p_mean = global_scalar(msh, ph * dx) / area
    p_second = global_scalar(msh, ph * ph * dx) / area
    p_rms = math.sqrt(max(p_second, 0.0))
    p_std = math.sqrt(max(p_second - p_mean * p_mean, 0.0))

    constraint = J - 1.0
    constraint_l2_rms = math.sqrt(
        max(global_scalar(msh, constraint * constraint * dx) / area, 0.0)
    )
    j_average = global_scalar(msh, J * dx) / area

    if midpoint_y <= 0.0:
        raise AssertionError(f"Fully incompressible midpoint displacement <= 0: n={n}")
    if not all(
        math.isfinite(value)
        for value in (
            midpoint_y,
            p_mean,
            p_std,
            p_rms,
            constraint_l2_rms,
            j_average,
        )
    ):
        raise AssertionError(f"Fully incompressible non-finite result: n={n}")

    return {
        "n": n,
        "displacement_space": "continuous Q2 Lagrange",
        "pressure_space": "discontinuous DPC degree 1 / 3 complete-linear cell DOF",
        "pressure_sign": "positive_in_compression",
        "pressure_cauchy_contribution": "-p*I",
        "pressure_compliance": PRESSURE_COMPLIANCE,
        "midpoint_y_displacement": midpoint_y,
        "pressure": {
            "mean": p_mean,
            "standard_deviation": p_std,
            "rms": p_rms,
        },
        "volumetric_constraint_l2_rms": constraint_l2_rms,
        "J_average": j_average,
        "load_steps": LOAD_STEPS,
        "snes_iterations": int(sum(iterations_per_step)),
        "snes_iterations_per_step": iterations_per_step,
        "snes_reason": reason,
    }


def main() -> None:
    comm = MPI.COMM_WORLD
    _, qweights = basix.make_quadrature(
        basix.CellType.quadrilateral, QUADRATURE_DEGREE
    )
    cases = [solve_case(n) for n in MESH_LEVELS]

    if comm.rank != 0:
        return

    tips = {case["n"]: case["midpoint_y_displacement"] for case in cases}
    previous_n = MESH_LEVELS[-2]
    finest_n = MESH_LEVELS[-1]
    relative_change = abs(tips[finest_n] - tips[previous_n]) / max(
        abs(tips[finest_n]), 1.0e-15
    )
    candidate_converged = relative_change <= REFERENCE_CONVERGENCE_THRESHOLD

    result = {
        "schema_version": 1,
        "reference_solver": "FEniCSx / DOLFINx fully-incompressible mixed u-p",
        "dolfinx_version": str(dolfinx.__version__),
        "formulation": "isochoric Neo-Hookean + independent pressure Lagrange multiplier",
        "mu": MU,
        "pressure_compliance": PRESSURE_COMPLIANCE,
        "traction_y": TRACTION_Y,
        "quadrature_degree": QUADRATURE_DEGREE,
        "basix_cell_quadrature_points": int(len(qweights)),
        "tip_definition": "right_edge_geometric_midpoint",
        "mesh_levels": list(MESH_LEVELS),
        "cases": cases,
        "finest_reference": {
            "n": finest_n,
            "midpoint_y_displacement": tips[finest_n],
        },
        "previous_to_finest_relative_displacement_change": relative_change,
        "configured_convergence_threshold": REFERENCE_CONVERGENCE_THRESHOLD,
        "reference_candidate_converged": candidate_converged,
        "independence_note": (
            "No Dyna Fortran element, assembly, tangent or Newton implementation is used."
        ),
    }

    out = Path("reference-results")
    out.mkdir(parents=True, exist_ok=True)
    path = out / "fenicsx-v03-cook-mixed-fully-incompressible.json"
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))

    if not candidate_converged:
        raise AssertionError(
            "Fully incompressible FEniCSx mixed 8x8 -> 16x16 displacement change "
            f"{100.0 * relative_change:.6f}% > "
            f"{100.0 * REFERENCE_CONVERGENCE_THRESHOLD:.3f}%"
        )


if __name__ == "__main__":
    main()
