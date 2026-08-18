#!/usr/bin/env python3
"""DynaElastomerSolver V0.3 Cook membrane için bağımsız FEniCSx referansı.

Bu script Dyna'nın Fortran element/assembly/Newton kodunu kullanmaz.
Aynı compressible Neo-Hookean enerji ve aynı normalize Cook geometrisi,
quadratic Q2 displacement alanı ile DOLFINx/UFL/PETSc üzerinde çözülür.

Amaç:
- displacement-only Q4 locking baseline için bağımsız tip displacement referansı,
- mixed Q4/P0 pressure alanının ölçeğini karşılaştırmak için p=lambda*ln(J)
  continuum alanının mean/std/RMS değerleri,
- 2x2/4x4/8x8/16x16 Q2 mesh-refinement trendi.

Q2 çözümü V0.3 production formulation seçimi değildir; yalnız bağımsız benchmarktır.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from mpi4py import MPI
import numpy as np
import ufl
from petsc4py import PETSc

import dolfinx
from dolfinx import fem, geometry, mesh
from dolfinx.fem.petsc import NonlinearProblem


MU = 1.0
LAMBDA = 1000.0
TRACTION_Y = 0.01

Y_RIGHT_BOTTOM = 44.0 / 48.0
Y_RIGHT_TOP = 60.0 / 48.0
Y_LEFT_TOP = 44.0 / 48.0
Y_RIGHT_MID = 0.5 * (Y_RIGHT_BOTTOM + Y_RIGHT_TOP)

MESH_LEVELS = (2, 4, 8, 16)


def global_scalar(msh: mesh.Mesh, expression) -> float:
    """MPI dağıtık scalar integrali global toplama ile döndürür."""
    local_value = fem.assemble_scalar(fem.form(expression))
    return float(msh.comm.allreduce(local_value, op=MPI.SUM))


def create_cook_mesh(comm: MPI.Comm, n: int) -> mesh.Mesh:
    """Dyna ile aynı normalize bilinear Cook geometrisini oluşturur."""
    msh = mesh.create_rectangle(
        comm=comm,
        points=((0.0, 0.0), (1.0, 1.0)),
        n=(n, n),
        cell_type=mesh.CellType.quadrilateral,
    )

    # Unit-square geometry koordinatlarını Dyna testindeki bilinear trapeze taşır.
    x = msh.geometry.x
    s = x[:, 0].copy()
    t = x[:, 1].copy()
    left_y = t * Y_LEFT_TOP
    right_y = (1.0 - t) * Y_RIGHT_BOTTOM + t * Y_RIGHT_TOP
    x[:, 1] = (1.0 - s) * left_y + s * right_y
    return msh


def evaluate_tip_y(msh: mesh.Mesh, uh: fem.Function) -> float:
    """Sağ sınır orta noktasındaki y displacement'i hücre aramasıyla değerlendirir."""
    tdim = msh.topology.dim
    tree = geometry.bb_tree(msh, tdim)

    # Tam sınır noktası bazı geometry toleranslarında hücre aramasına düşmeyebilir.
    # Önce tam nokta, gerekirse reference domain içine çok küçük kaydırılmış nokta denenir.
    candidates_to_try = (1.0, 1.0 - 1.0e-11)
    for xcoord in candidates_to_try:
        point = np.array([[xcoord, Y_RIGHT_MID, 0.0]], dtype=msh.geometry.x.dtype)
        candidates = geometry.compute_collisions_points(tree, point)
        colliding = geometry.compute_colliding_cells(msh, candidates, point)
        links = colliding.links(0)
        if len(links) > 0:
            cells = np.array([links[0]], dtype=np.int32)
            value = uh.eval(point, cells)
            return float(np.real(value[0, 1]))

    raise RuntimeError("Cook sağ orta noktasını içeren hücre bulunamadı.")


def solve_case(n: int) -> dict:
    comm = MPI.COMM_WORLD
    scalar_type = PETSc.ScalarType
    msh = create_cook_mesh(comm, n)

    # Q2 displacement alanı: Dyna Q4 baseline'dan bağımsız yüksek mertebeli referans.
    V = fem.functionspace(msh, ("Lagrange", 2, (2,)))
    uh = fem.Function(V, name="u")
    v = ufl.TestFunction(V)
    du = ufl.TrialFunction(V)
    uh.x.array[:] = 0.0

    fdim = msh.topology.dim - 1
    left_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], 0.0)
    )
    right_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], 1.0)
    )

    left_x_dofs = fem.locate_dofs_topological(V.sub(0), fdim, left_facets)
    left_y_dofs = fem.locate_dofs_topological(V.sub(1), fdim, left_facets)
    bcs = [
        fem.dirichletbc(scalar_type(0.0), left_x_dofs, V.sub(0)),
        fem.dirichletbc(scalar_type(0.0), left_y_dofs, V.sub(1)),
    ]

    right_facets = np.sort(right_facets.astype(np.int32))
    right_values = np.ones(len(right_facets), dtype=np.int32)
    right_tags = mesh.meshtags(msh, fdim, right_facets, right_values)

    dx = ufl.Measure("dx", domain=msh)
    ds = ufl.Measure("ds", domain=msh, subdomain_data=right_tags)

    F2 = ufl.Identity(2) + ufl.grad(uh)
    F = ufl.variable(
        ufl.as_matrix(
            (
                (F2[0, 0], F2[0, 1], 0.0),
                (F2[1, 0], F2[1, 1], 0.0),
                (0.0, 0.0, 1.0),
            )
        )
    )
    C = F.T * F
    I1 = ufl.tr(C)
    J = ufl.det(F)

    psi = (
        0.5 * MU * (I1 - 3.0)
        - MU * ufl.ln(J)
        + 0.5 * LAMBDA * ufl.ln(J) ** 2
    )

    traction = fem.Constant(
        msh, np.array([0.0, TRACTION_Y], dtype=scalar_type)
    )
    potential = psi * dx - ufl.inner(traction, uh) * ds(1)
    residual = ufl.derivative(potential, uh, v)
    jacobian = ufl.derivative(residual, uh, du)

    prefix = f"des_fenicsx_v03_cook_q2_{n}_"
    problem = NonlinearProblem(
        residual,
        uh,
        J=jacobian,
        bcs=bcs,
        petsc_options_prefix=prefix,
        petsc_options={
            "snes_type": "newtonls",
            "snes_linesearch_type": "bt",
            "snes_rtol": 1.0e-10,
            "snes_atol": 1.0e-11,
            "snes_max_it": 60,
            "snes_error_if_not_converged": True,
            "ksp_type": "preonly",
            "pc_type": "lu",
            "pc_factor_mat_solver_type": "mumps",
            "ksp_error_if_not_converged": True,
        },
    )
    problem.solve()

    snes_reason = int(problem.solver.getConvergedReason())
    snes_iterations = int(problem.solver.getIterationNumber())
    if snes_reason <= 0:
        raise RuntimeError(f"Q2 Cook SNES yakınsamadı: n={n}, reason={snes_reason}")

    area = global_scalar(msh, 1.0 * dx)
    p_field = LAMBDA * ufl.ln(J)
    p_mean = global_scalar(msh, p_field * dx) / area
    p_second = global_scalar(msh, p_field * p_field * dx) / area
    p_rms = math.sqrt(max(p_second, 0.0))
    p_std = math.sqrt(max(p_second - p_mean * p_mean, 0.0))
    j_mean = global_scalar(msh, J * dx) / area
    total_energy = global_scalar(msh, psi * dx)
    tip_y = evaluate_tip_y(msh, uh)

    if tip_y <= 0.0:
        raise AssertionError(f"Q2 Cook tip displacement pozitif değil: n={n}")
    if not all(math.isfinite(x) for x in (tip_y, p_mean, p_std, p_rms, j_mean, total_energy)):
        raise AssertionError(f"Q2 Cook sonlu olmayan sonuç üretti: n={n}")

    return {
        "n": n,
        "cell": "quadrilateral",
        "displacement_degree": 2,
        "tip_y_displacement": tip_y,
        "pressure_from_lambda_lnJ": {
            "mean": p_mean,
            "standard_deviation": p_std,
            "rms": p_rms,
        },
        "J_average": j_mean,
        "total_strain_energy": total_energy,
        "snes_iterations": snes_iterations,
        "snes_reason": snes_reason,
    }


def main() -> None:
    comm = MPI.COMM_WORLD
    cases = [solve_case(n) for n in MESH_LEVELS]

    if comm.rank != 0:
        return

    tip_by_n = {case["n"]: case["tip_y_displacement"] for case in cases}
    relative_8_to_16 = abs(tip_by_n[16] - tip_by_n[8]) / max(
        abs(tip_by_n[16]), 1.0e-15
    )

    result = {
        "reference_solver": "FEniCSx / DOLFINx",
        "dolfinx_version": str(dolfinx.__version__),
        "problem": "V0.3 normalized Cook membrane plane-strain external reference",
        "purpose": "independent Q2 displacement reference; no Dyna Fortran code used",
        "material": {
            "model": "compressible Neo-Hookean",
            "mu": MU,
            "lambda": LAMBDA,
            "equivalent_small_strain_poisson_ratio": LAMBDA / (2.0 * (LAMBDA + MU)),
        },
        "load": {
            "reference_nominal_traction": [0.0, TRACTION_Y],
            "left_boundary": "ux=uy=0",
        },
        "geometry": {
            "left_bottom": [0.0, 0.0],
            "right_bottom": [1.0, Y_RIGHT_BOTTOM],
            "right_top": [1.0, Y_RIGHT_TOP],
            "left_top": [0.0, Y_LEFT_TOP],
            "right_midpoint": [1.0, Y_RIGHT_MID],
        },
        "mesh_cases": cases,
        "refinement": {
            "relative_tip_change_8_to_16": relative_8_to_16,
            "finest_mesh": "16x16 Q2",
            "finest_tip_y_displacement": tip_by_n[16],
        },
        "notes": [
            "Pressure is the continuum field p=lambda*ln(J), not an independent mixed unknown.",
            "This result is an external benchmark, not a production formulation selection.",
        ],
    }

    output_dir = Path("reference-results")
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "fenicsx_v03_cook_q2_reference.json"
    output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"Bağımsız FEniCSx V0.3 Cook Q2 referansı TAMAMLANDI: {output_path}")


if __name__ == "__main__":
    main()
