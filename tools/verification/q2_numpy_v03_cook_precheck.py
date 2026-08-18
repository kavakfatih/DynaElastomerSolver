#!/usr/bin/env python3
"""V0.3 Cook problemi için bağımsız Q2/SciPy sparse precheck.

Bu script Dyna Fortran element, assembly veya Newton kodunu kullanmaz.
FEniCSx/DOLFINx dış solver doğrulamasının yerine geçmez. Amaç:

- Q2 9-node quadrilateral ile bağımsız yüksek-mertebe convergence precheck'i,
- FEniCSx mesh seviyelerinin yeterli olup olmadığını önceden sınamak,
- Dyna displacement/mixed/F-bar bake-off sonuçları için ikinci bir referans izi.

Formulation:
- plane strain, 3x3 F ve F33=1
- compressible Neo-Hookean
- Q2 9-node quadrilateral
- 3x3 Gauss
- Total-Lagrangian residual + analytic consistent tangent
- SciPy sparse Full Newton
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import scipy.sparse as sp
import scipy.sparse.linalg as spla

MU = 1.0
LAMBDA = 1000.0
TRACTION_Y = 0.01
Y_RIGHT_BOTTOM = 44.0 / 48.0
Y_RIGHT_TOP = 60.0 / 48.0
Y_LEFT_TOP = 44.0 / 48.0

GAUSS = np.array([-math.sqrt(3.0 / 5.0), 0.0, math.sqrt(3.0 / 5.0)])
GAUSS_W = np.array([5.0 / 9.0, 8.0 / 9.0, 5.0 / 9.0])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--meshes", nargs="+", type=int, default=[2, 4, 8, 16])
    parser.add_argument("--output", type=Path, default=Path("V0.3_Q2_NUMPY_PRECHECK.json"))
    parser.add_argument("--increments", type=int, default=5)
    parser.add_argument("--tolerance", type=float, default=1.0e-10)
    parser.add_argument("--max-iterations", type=int, default=35)
    return parser.parse_args()


def lagrange_q2(x: float) -> tuple[np.ndarray, np.ndarray]:
    values = np.array(
        [0.5 * x * (x - 1.0), 1.0 - x * x, 0.5 * x * (x + 1.0)]
    )
    derivatives = np.array([x - 0.5, -2.0 * x, x + 0.5])
    return values, derivatives


def q2_shape(xi: float, eta: float) -> tuple[np.ndarray, np.ndarray]:
    lx, dlx = lagrange_q2(xi)
    le, dle = lagrange_q2(eta)
    n = np.empty(9)
    dn_parent = np.empty((9, 2))
    cursor = 0
    for j in range(3):
        for i in range(3):
            n[cursor] = lx[i] * le[j]
            dn_parent[cursor, 0] = dlx[i] * le[j]
            dn_parent[cursor, 1] = lx[i] * dle[j]
            cursor += 1
    return n, dn_parent


def build_mesh(n: int) -> tuple[np.ndarray, np.ndarray]:
    qn = 2 * n + 1
    coordinates = np.empty((qn * qn, 2))

    for gy in range(qn):
        t = gy / (2.0 * n)
        left_y = t * Y_LEFT_TOP
        right_y = (1.0 - t) * Y_RIGHT_BOTTOM + t * Y_RIGHT_TOP
        for gx in range(qn):
            s = gx / (2.0 * n)
            node = gy * qn + gx
            coordinates[node, 0] = s
            coordinates[node, 1] = (1.0 - s) * left_y + s * right_y

    connectivity = []
    for ey in range(n):
        for ex in range(n):
            nodes = []
            for j in range(3):
                for i in range(3):
                    nodes.append((2 * ey + j) * qn + (2 * ex + i))
            connectivity.append(nodes)

    return coordinates, np.asarray(connectivity, dtype=np.int32)


def precompute_geometry(
    coordinates: np.ndarray, connectivity: np.ndarray
) -> list[list[tuple[np.ndarray, float]]]:
    cache: list[list[tuple[np.ndarray, float]]] = []
    for ids in connectivity:
        xe = coordinates[ids]
        element_points = []
        for eta, w_eta in zip(GAUSS, GAUSS_W):
            for xi, w_xi in zip(GAUSS, GAUSS_W):
                _, dn_parent = q2_shape(float(xi), float(eta))
                jacobian = dn_parent.T @ xe
                det_jacobian = float(np.linalg.det(jacobian))
                if det_jacobian <= 0.0:
                    raise RuntimeError("Q2 reference geometry Jacobian pozitif değil.")
                dn_dx = (np.linalg.inv(jacobian) @ dn_parent.T).T
                element_points.append(
                    (dn_dx, det_jacobian * float(w_xi) * float(w_eta))
                )
        cache.append(element_points)
    return cache


def material_response(
    deformation_gradient: np.ndarray, mu: float, lame_lambda: float
) -> tuple[float, np.ndarray, np.ndarray, float]:
    j = float(np.linalg.det(deformation_gradient))
    if j <= 0.0:
        raise RuntimeError("Q2 precheck non-positive J üretti.")

    finvt = np.linalg.inv(deformation_gradient).T
    ln_j = math.log(j)
    alpha = lame_lambda * ln_j - mu
    p = mu * deformation_gradient + alpha * finvt

    tangent = np.zeros((3, 3, 3, 3))
    for i in range(3):
        for jdir in range(3):
            for k in range(3):
                for ldir in range(3):
                    value = mu if (i == k and jdir == ldir) else 0.0
                    value += lame_lambda * finvt[i, jdir] * finvt[k, ldir]
                    value -= alpha * finvt[k, jdir] * finvt[i, ldir]
                    tangent[i, jdir, k, ldir] = value

    i1 = float(np.sum(deformation_gradient * deformation_gradient))
    energy = 0.5 * mu * (i1 - 3.0) - mu * ln_j + 0.5 * lame_lambda * ln_j**2
    return j, p, tangent, energy


def build_external_force(coordinates: np.ndarray, n: int) -> np.ndarray:
    qn = 2 * n + 1
    force = np.zeros(2 * len(coordinates))

    for ey in range(n):
        ids = np.array([(2 * ey + j) * qn + 2 * n for j in range(3)])
        xe = coordinates[ids]
        for eta, weight in zip(GAUSS, GAUSS_W):
            values, derivatives = lagrange_q2(float(eta))
            edge_tangent = derivatives @ xe
            edge_jacobian = float(np.linalg.norm(edge_tangent))
            for a, node in enumerate(ids):
                force[2 * node + 1] += TRACTION_Y * values[a] * edge_jacobian * weight
    return force


def assemble(
    coordinates: np.ndarray,
    connectivity: np.ndarray,
    geometry_cache: list[list[tuple[np.ndarray, float]]],
    displacement: np.ndarray,
    mu: float,
    lame_lambda: float,
    build_tangent: bool,
):
    ndof = 2 * len(coordinates)
    residual = np.zeros(ndof)
    rows: list[int] = []
    cols: list[int] = []
    values: list[float] = []

    minimum_j = math.inf
    volume = 0.0
    j_sum = 0.0
    pressure_sum = 0.0
    pressure_square_sum = 0.0
    energy_sum = 0.0

    for element, ids in enumerate(connectivity):
        ue = displacement[ids]
        re = np.zeros(18)
        ke = np.zeros((18, 18)) if build_tangent else None

        for dn_dx, weight in geometry_cache[element]:
            f = np.eye(3)
            f[:2, :2] += ue.T @ dn_dx
            j, p, material_tangent, energy = material_response(f, mu, lame_lambda)
            minimum_j = min(minimum_j, j)

            pressure = lame_lambda * math.log(j)
            volume += weight
            j_sum += weight * j
            pressure_sum += weight * pressure
            pressure_square_sum += weight * pressure * pressure
            energy_sum += weight * energy

            for a in range(9):
                for i in range(2):
                    row = 2 * a + i
                    for jdir in range(2):
                        re[row] += p[i, jdir] * dn_dx[a, jdir] * weight

                    if build_tangent:
                        for b in range(9):
                            for k in range(2):
                                col = 2 * b + k
                                value = 0.0
                                for jdir in range(2):
                                    for ldir in range(2):
                                        value += (
                                            material_tangent[i, jdir, k, ldir]
                                            * dn_dx[a, jdir]
                                            * dn_dx[b, ldir]
                                        )
                                ke[row, col] += value * weight

        dofs = np.empty(18, dtype=np.int32)
        for a, node in enumerate(ids):
            dofs[2 * a] = 2 * node
            dofs[2 * a + 1] = 2 * node + 1
        residual[dofs] += re

        if build_tangent and ke is not None:
            rows.extend(np.repeat(dofs, 18).tolist())
            cols.extend(np.tile(dofs, 18).tolist())
            values.extend(ke.ravel().tolist())

    tangent = None
    if build_tangent:
        tangent = sp.coo_matrix(
            (values, (rows, cols)), shape=(ndof, ndof)
        ).tocsr()

    pressure_mean = pressure_sum / volume
    pressure_second = pressure_square_sum / volume
    statistics = {
        "J_average": j_sum / volume,
        "pressure_mean": pressure_mean,
        "pressure_standard_deviation": math.sqrt(
            max(pressure_second - pressure_mean**2, 0.0)
        ),
        "pressure_rms": math.sqrt(max(pressure_second, 0.0)),
        "total_strain_energy": energy_sum,
    }
    return residual, tangent, minimum_j, statistics


def solve_case(
    n: int,
    increments: int,
    tolerance: float,
    max_iterations: int,
) -> dict:
    coordinates, connectivity = build_mesh(n)
    geometry_cache = precompute_geometry(coordinates, connectivity)
    external_force = build_external_force(coordinates, n)

    qn = 2 * n + 1
    displacement = np.zeros((len(coordinates), 2))
    ndof = 2 * len(coordinates)

    fixed = []
    for gy in range(qn):
        node = gy * qn
        fixed.extend((2 * node, 2 * node + 1))
    fixed = np.asarray(fixed, dtype=np.int32)
    is_free = np.ones(ndof, dtype=bool)
    is_free[fixed] = False
    free = np.flatnonzero(is_free)

    total_iterations = 0
    maximum_residual = 0.0
    for increment in range(1, increments + 1):
        load_factor = increment / increments
        converged = False
        for iteration in range(max_iterations + 1):
            residual, tangent, _, _ = assemble(
                coordinates,
                connectivity,
                geometry_cache,
                displacement,
                MU,
                LAMBDA,
                True,
            )
            effective = residual - load_factor * external_force
            residual_norm = float(np.max(np.abs(effective[free])))
            maximum_residual = max(maximum_residual, residual_norm)
            if residual_norm < tolerance:
                converged = True
                break
            if iteration == max_iterations or tangent is None:
                break

            kff = tangent[free][:, free]
            delta = spla.spsolve(kff, -effective[free])
            flat = displacement.reshape(-1)
            flat[free] += delta
            displacement = flat.reshape((-1, 2))
            total_iterations += 1

        if not converged:
            raise RuntimeError(
                f"Q2 sparse precheck yakınsamadı: n={n}, increment={increment}, residual={residual_norm}"
            )

    _, _, minimum_j, stats = assemble(
        coordinates,
        connectivity,
        geometry_cache,
        displacement,
        MU,
        LAMBDA,
        False,
    )
    midpoint_node = n * qn + 2 * n
    tip = float(displacement[midpoint_node, 1])

    return {
        "n": n,
        "element": "Q2 9-node quadrilateral",
        "gauss": "3x3",
        "tip_y_displacement": tip,
        "minimum_J": minimum_j,
        "J_average": stats["J_average"],
        "pressure_from_lambda_lnJ": {
            "mean": stats["pressure_mean"],
            "standard_deviation": stats["pressure_standard_deviation"],
            "rms": stats["pressure_rms"],
        },
        "total_strain_energy": stats["total_strain_energy"],
        "newton_corrections": total_iterations,
        "free_equations": int(len(free)),
        "maximum_increment_residual_seen": maximum_residual,
    }


def main() -> int:
    args = parse_args()
    meshes = sorted(set(args.meshes))
    if any(n < 1 for n in meshes):
        raise SystemExit("Mesh seviyeleri pozitif olmalıdır.")

    cases = [
        solve_case(n, args.increments, args.tolerance, args.max_iterations)
        for n in meshes
    ]

    refinement = []
    for previous, current in zip(cases[:-1], cases[1:]):
        relative_change = abs(
            current["tip_y_displacement"] - previous["tip_y_displacement"]
        ) / max(abs(current["tip_y_displacement"]), 1.0e-30)
        refinement.append(
            {
                "from": previous["n"],
                "to": current["n"],
                "relative_tip_change": relative_change,
            }
        )

    result = {
        "schema_version": 1,
        "status": "independent_q2_precheck_not_fenicsx_not_official_dyna_ctest",
        "implementation": "Python/NumPy/SciPy sparse independent Q2 FEM",
        "problem": "V0.3 normalized Cook membrane plane strain",
        "material": {"model": "compressible Neo-Hookean", "mu": MU, "lambda": LAMBDA},
        "traction_y": TRACTION_Y,
        "mesh_cases": cases,
        "refinement": refinement,
        "notes": [
            "Dyna Fortran code is not used.",
            "This does not replace the FEniCSx/DOLFINx external reference exit criterion.",
        ],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"Q2 independent precheck: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
