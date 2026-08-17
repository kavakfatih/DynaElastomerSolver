#!/usr/bin/env python3
"""DynaElastomerSolver V0.2 için bağımsız FEniCSx referans çözümü.

Problem:
- 2.0 x 1.0 plane-strain dikdörtgen
- sıkıştırılabilir Neo-Hookean
- mu=2.5, lambda=20.0
- sol kenar ux=0
- sağ kenar ux=0.5 -> lambda_x=1.25
- y yönü traction-free; yalnız sol-alt köşede rigid-body y hareketi tutulur

DOLFINx/FEniCSx, Dyna'nın Fortran FEM kodunu kullanmaz. Residual ve Jacobian UFL
otomatik türevleriyle, nonlinear çözüm PETSc SNES ile oluşturulur.
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
from dolfinx import fem, mesh
from dolfinx.fem.petsc import NonlinearProblem


MU = 2.5
LAMBDA = 20.0
LENGTH = 2.0
HEIGHT = 1.0
RIGHT_DISPLACEMENT = 0.5
LAMBDA_X = 1.0 + RIGHT_DISPLACEMENT / LENGTH

# Dyna V0.2 homogeneous-extension regressionının hedef değerleri.
DYNA_LAMBDA_Y = 0.8314690882666784
DYNA_REACTION_X = 1.7423183105139586


def traction_free_lateral_stretch(lambda_x: float, mu: float, lame_lambda: float) -> float:
    """P22=0 denklemini bağımsız scalar bisection ile çözer."""

    def equation(lambda_y: float) -> float:
        jac = lambda_x * lambda_y
        return mu * lambda_y + (lame_lambda * math.log(jac) - mu) / lambda_y

    lo, hi = 0.2, 1.5
    flo = equation(lo)
    for _ in range(160):
        mid = 0.5 * (lo + hi)
        fmid = equation(mid)
        if abs(fmid) < 1.0e-15:
            return mid
        if flo * fmid <= 0.0:
            hi = mid
        else:
            lo = mid
            flo = fmid
    return 0.5 * (lo + hi)


def global_scalar(msh: mesh.Mesh, expression) -> float:
    """MPI dağıtık scalar integrali global toplama ile döndürür."""
    local_value = fem.assemble_scalar(fem.form(expression))
    return float(msh.comm.allreduce(local_value, op=MPI.SUM))


def main() -> None:
    comm = MPI.COMM_WORLD
    scalar_type = PETSc.ScalarType

    msh = mesh.create_rectangle(
        comm=comm,
        points=((0.0, 0.0), (LENGTH, HEIGHT)),
        n=(8, 4),
        cell_type=mesh.CellType.quadrilateral,
    )

    V = fem.functionspace(msh, ("Lagrange", 1, (2,)))
    uh = fem.Function(V, name="u")
    v = ufl.TestFunction(V)
    du = ufl.TrialFunction(V)

    # Newton için yalnız başlangıç tahmini; çözüm değeri değildir.
    uh.interpolate(lambda x: np.vstack((0.25 * x[0], -0.15 * x[1])))

    fdim = msh.topology.dim - 1
    left_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], 0.0)
    )
    right_facets = mesh.locate_entities_boundary(
        msh, fdim, lambda x: np.isclose(x[0], LENGTH)
    )
    anchor_vertices = mesh.locate_entities_boundary(
        msh,
        0,
        lambda x: np.logical_and(np.isclose(x[0], 0.0), np.isclose(x[1], 0.0)),
    )

    left_x_dofs = fem.locate_dofs_topological(V.sub(0), fdim, left_facets)
    right_x_dofs = fem.locate_dofs_topological(V.sub(0), fdim, right_facets)
    anchor_y_dofs = fem.locate_dofs_topological(V.sub(1), 0, anchor_vertices)

    bcs = [
        fem.dirichletbc(scalar_type(0.0), left_x_dofs, V.sub(0)),
        fem.dirichletbc(scalar_type(RIGHT_DISPLACEMENT), right_x_dofs, V.sub(0)),
        fem.dirichletbc(scalar_type(0.0), anchor_y_dofs, V.sub(1)),
    ]

    grad_u = ufl.grad(uh)
    F2 = ufl.Identity(2) + grad_u
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

    # Tüm domain integralleri açıkça aynı mesh'e bağlanır. Bu hem residual/Jacobian
    # hem de post-processing formlarında UFL domain belirsizliğini ortadan kaldırır.
    dx = ufl.Measure("dx", domain=msh)
    potential = psi * dx
    residual = ufl.derivative(potential, uh, v)
    jacobian = ufl.derivative(residual, uh, du)

    problem = NonlinearProblem(
        residual,
        uh,
        J=jacobian,
        bcs=bcs,
        petsc_options_prefix="des_fenicsx_v02_",
        petsc_options={
            "snes_type": "newtonls",
            "snes_linesearch_type": "bt",
            "snes_rtol": 1.0e-11,
            "snes_atol": 1.0e-12,
            "snes_max_it": 50,
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
        raise RuntimeError(f"FEniCSx SNES yakınsamadı. reason={snes_reason}")

    # Reference right boundary için facet tag oluşturulur.
    right_facets = np.sort(right_facets.astype(np.int32))
    right_values = np.ones(len(right_facets), dtype=np.int32)
    right_tags = mesh.meshtags(msh, fdim, right_facets, right_values)
    ds_right = ufl.Measure("ds", domain=msh, subdomain_data=right_tags)

    P = ufl.diff(psi, F)
    area = global_scalar(msh, 1.0 * dx)
    avg_lambda_y = global_scalar(msh, F[1, 1] * dx) / area
    reaction_x = global_scalar(msh, P[0, 0] * ds_right(1))
    total_energy = global_scalar(msh, psi * dx)
    avg_j = global_scalar(msh, J * dx) / area

    analytical_lambda_y = traction_free_lateral_stretch(LAMBDA_X, MU, LAMBDA)
    analytical_j = LAMBDA_X * analytical_lambda_y
    analytical_reaction = (
        MU * LAMBDA_X
        + (LAMBDA * math.log(analytical_j) - MU) / LAMBDA_X
    ) * HEIGHT
    analytical_energy_density = (
        0.5 * MU * (LAMBDA_X**2 + analytical_lambda_y**2 + 1.0 - 3.0)
        - MU * math.log(analytical_j)
        + 0.5 * LAMBDA * math.log(analytical_j) ** 2
    )
    analytical_total_energy = analytical_energy_density * LENGTH * HEIGHT

    comparison = {
        "reference_solver": "FEniCSx / DOLFINx",
        "dolfinx_version": str(dolfinx.__version__),
        "problem": "V0.2 homogeneous plane-strain extension",
        "mesh": {"cell": "quadrilateral", "nx": 8, "ny": 4},
        "material": {"model": "compressible Neo-Hookean", "mu": MU, "lambda": LAMBDA},
        "load": {"lambda_x": LAMBDA_X, "right_displacement": RIGHT_DISPLACEMENT},
        "fenicsx": {
            "lambda_y_average": avg_lambda_y,
            "reaction_x": reaction_x,
            "J_average": avg_j,
            "total_strain_energy": total_energy,
            "snes_iterations": snes_iterations,
            "snes_reason": snes_reason,
        },
        "dyna_v02_target": {
            "lambda_y": DYNA_LAMBDA_Y,
            "reaction_x": DYNA_REACTION_X,
        },
        "closed_form": {
            "lambda_y": analytical_lambda_y,
            "reaction_x": analytical_reaction,
            "J": analytical_j,
            "total_strain_energy": analytical_total_energy,
        },
        "absolute_errors_vs_dyna": {
            "lambda_y": abs(avg_lambda_y - DYNA_LAMBDA_Y),
            "reaction_x": abs(reaction_x - DYNA_REACTION_X),
        },
        "absolute_errors_vs_closed_form": {
            "lambda_y": abs(avg_lambda_y - analytical_lambda_y),
            "reaction_x": abs(reaction_x - analytical_reaction),
            "J": abs(avg_j - analytical_j),
            "total_strain_energy": abs(total_energy - analytical_total_energy),
        },
    }

    # Q1 homojen çözüm bu problemde exact affine alanı temsil edebilir. Yine de farklı
    # nonlinear/assembly backend nedeniyle cross-solver toleransı material-point testinden
    # daha gevşek ve mühendislik açısından açık tutulur.
    tolerance_lambda_y = 2.0e-7
    tolerance_reaction = 2.0e-7
    tolerance_energy = 5.0e-7

    if comparison["absolute_errors_vs_dyna"]["lambda_y"] > tolerance_lambda_y:
        raise AssertionError("FEniCSx lambda_y, Dyna V0.2 hedef toleransını aştı.")
    if comparison["absolute_errors_vs_dyna"]["reaction_x"] > tolerance_reaction:
        raise AssertionError("FEniCSx reaction_x, Dyna V0.2 hedef toleransını aştı.")
    if comparison["absolute_errors_vs_closed_form"]["total_strain_energy"] > tolerance_energy:
        raise AssertionError("FEniCSx toplam enerji continuum referans toleransını aştı.")

    if comm.rank == 0:
        output_dir = Path("reference-results")
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / "fenicsx_v02_homogeneous_extension.json"
        output_path.write_text(json.dumps(comparison, indent=2), encoding="utf-8")
        print(json.dumps(comparison, indent=2))
        print(f"Bağımsız FEniCSx referansı BAŞARILI: {output_path}")


if __name__ == "__main__":
    main()
