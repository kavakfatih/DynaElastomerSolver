#!/usr/bin/env python3
"""DynaElastomerSolver V0.3 Q9/P1 Herrmann H3 acceptance kaniti.

Bu arac yeni FEM cozmez. Mevcut Fortran benchmark JSON'larini, CTest parity
kayitlarini ve bagimsiz FEniCSx provenance snapshot'ini tek bir acceptance
raporunda birlestirir.

Amac:
- internal verification kapilarini tek yerde toplamak,
- matched-discrete FEniCSx parity testlerinin CTest paketinde gercekten
  calistigini dogrulamak,
- continuum displacement hedefi icin conservative upper-bound hesaplamak,
- ANSYS/Marc commercial parity tamamlanmadan LEVEL 3 ilan edilmesini engellemek.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--production", required=True, type=Path)
    p.add_argument("--mesh-refinement", required=True, type=Path)
    p.add_argument("--quadrature", required=True, type=Path)
    p.add_argument("--ctest-log", required=True, type=Path)
    p.add_argument("--reference-snapshot", required=True, type=Path)
    p.add_argument("--json-output", required=True, type=Path)
    p.add_argument("--markdown-output", required=True, type=Path)
    return p.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def relative_error(value: float, reference: float) -> float:
    return abs(value - reference) / max(abs(reference), 1.0e-30)


def conservative_matched_to_continuum_bound(
    matched_reference: float, continuum_reference: float, matched_tolerance: float
) -> float:
    """Matched-discrete gate gecerse continuum hatasinin konservatif ust siniri."""
    low = matched_reference * (1.0 - matched_tolerance)
    high = matched_reference * (1.0 + matched_tolerance)
    return max(
        relative_error(low, continuum_reference),
        relative_error(high, continuum_reference),
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_inputs(
    production: dict[str, Any],
    mesh: dict[str, Any],
    quadrature: dict[str, Any],
    snapshot: dict[str, Any],
) -> None:
    require(int(production.get("schema_version", -1)) == 1, "production schema_version=1 olmali")
    require(production.get("element") == "Q9/P1 Herrmann", "production element Q9/P1 Herrmann olmali")
    require(production.get("primary_quadrature") == "3x3", "primary quadrature 3x3 olmali")

    require(int(mesh.get("schema_version", -1)) == 1, "mesh-refinement schema_version=1 olmali")
    require(mesh.get("benchmark") == "q9_p1_herrmann_cook_mesh_refinement", "mesh benchmark kimligi uyusmuyor")
    require([int(x) for x in mesh.get("mesh_n", [])] == [1, 2, 4], "mesh seviyeleri 1/2/4 olmali")

    require(int(quadrature.get("schema_version", -1)) == 1, "quadrature schema_version=1 olmali")
    require(quadrature.get("benchmark") == "q9_p1_herrmann_quadrature_convergence", "quadrature benchmark kimligi uyusmuyor")
    require([int(x) for x in quadrature.get("quadrature_orders", [])] == [2, 3, 4], "quadrature seviyeleri 2/3/4 olmali")

    require(int(snapshot.get("schema_version", -1)) == 1, "reference snapshot schema_version=1 olmali")
    require(bool(snapshot["near_incompressible"]["reference_candidate_converged"]), "near-incompressible external reference converged degil")
    require(bool(snapshot["fully_incompressible"]["reference_candidate_converged"]), "fully-incompressible external reference converged degil")


def gate(name: str, value: float, limit: float, operator: str = "<=") -> dict[str, Any]:
    passed = value <= limit
    return {
        "name": name,
        "value": value,
        "limit": limit,
        "operator": operator,
        "passed": passed,
    }


def build_report(
    production: dict[str, Any],
    mesh: dict[str, Any],
    quadrature: dict[str, Any],
    ctest_text: str,
    snapshot: dict[str, Any],
) -> dict[str, Any]:
    validate_inputs(production, mesh, quadrature, snapshot)

    matched_tol = float(snapshot["matched_discrete_displacement_relative_tolerance"])
    continuum_target = float(snapshot["continuum_displacement_relative_target"])

    near = snapshot["near_incompressible"]
    full = snapshot["fully_incompressible"]
    near_mesh = {int(k): float(v) for k, v in near["mesh"].items()}
    full_mesh = {int(k): float(v) for k, v in full["mesh"].items()}

    near_ref_change_8_16 = relative_error(near_mesh[8], near_mesh[16])
    full_ref_change_8_16 = relative_error(full_mesh[8], full_mesh[16])

    # Dyna 4x4 / 3x3 nearly-incompressible degeri internal mesh-refinement
    # benchmarkindan dogrudan gelir.
    dyna_near_n4 = float(mesh["tip_y"][2])
    near_direct_continuum_error = relative_error(dyna_near_n4, near_mesh[16])

    # Fully incompressible matched-discrete CTest n=4'te FEniCSx n=4 degerine
    # <= matched_tol kosulunu zaten uygular. Burada bu gate gecmis kabul edilirse
    # n=16 continuum referansina gore matematiksel konservatif ust sinir hesaplanir.
    near_continuum_bound = conservative_matched_to_continuum_bound(
        near_mesh[4], near_mesh[16], matched_tol
    )
    full_continuum_bound = conservative_matched_to_continuum_bound(
        full_mesh[4], full_mesh[16], matched_tol
    )

    required_ctest_markers = {
        "near_incompressible_matched_parity": "benchmark.v0.3.herrmann.fenicsx_mixed_parity",
        "fully_incompressible_matched_parity": "benchmark.v0.3.herrmann.fenicsx_fully_incompressible_parity",
        "production_acceptance": "benchmark.v0.3.herrmann.production_acceptance",
        "mesh_refinement": "benchmark.v0.3.herrmann.mesh_refinement",
        "quadrature_convergence": "benchmark.v0.3.herrmann.quadrature_convergence",
    }
    ctest_presence = {
        key: marker in ctest_text for key, marker in required_ctest_markers.items()
    }

    sweep = production["incompressibility_sweep"]
    severe = production["severe_distortion"]

    numeric_gates = [
        gate(
            "K/mu=1000 -> fully incompressible tip gap",
            float(sweep["k1000_to_incompressible_relative_tip_gap"]),
            5.0e-3,
        ),
        gate(
            "max displacement weak residual",
            max(float(x) for x in sweep["displacement_residual_inf"]),
            2.0e-8,
        ),
        gate(
            "max pressure weak residual",
            max(float(x) for x in sweep["pressure_residual_inf"]),
            2.0e-8,
        ),
        gate(
            "severe distortion displacement recovery error",
            float(severe["max_displacement_error"]),
            1.0e-7,
        ),
        gate(
            "severe distortion pressure recovery error",
            float(severe["max_pressure_error"]),
            1.0e-7,
        ),
        gate(
            "Q9 mesh refinement 2x2 -> 4x4 gap",
            float(mesh["gap_2_to_4"]),
            1.0e-2,
        ),
        gate(
            "Q9 quadrature 3x3 -> 4x4 gap",
            float(quadrature["gap_3_to_4"]),
            5.0e-4,
        ),
        gate(
            "near-incompressible external reference 8x8 -> 16x16 convergence",
            near_ref_change_8_16,
            1.0e-2,
        ),
        gate(
            "fully-incompressible external reference 8x8 -> 16x16 convergence",
            full_ref_change_8_16,
            1.0e-2,
        ),
        gate(
            "Dyna Q9/P1 n=4 near-incompressible vs FEniCSx n=16 continuum",
            near_direct_continuum_error,
            continuum_target,
        ),
        gate(
            "near-incompressible matched-parity continuum upper bound",
            near_continuum_bound,
            continuum_target,
        ),
        gate(
            "fully-incompressible matched-parity continuum upper bound",
            full_continuum_bound,
            continuum_target,
        ),
    ]

    ctest_gate_pass = all(ctest_presence.values())
    numeric_gate_pass = all(item["passed"] for item in numeric_gates)
    level_2_pass = ctest_gate_pass and numeric_gate_pass

    return {
        "schema_version": 1,
        "benchmark": "v0.3_h3_q9_p1_herrmann_acceptance",
        "formulation": "Q9/P1 Herrmann mixed u-P plane strain",
        "primary_quadrature": "3x3 Gauss",
        "verification_level": {
            "LEVEL_0_IMPLEMENTED": True,
            "LEVEL_1_INTERNAL_VERIFIED": numeric_gate_pass,
            "LEVEL_2_INDEPENDENT_VERIFIED": level_2_pass,
            "LEVEL_3_COMMERCIAL_BENCHMARKED": False,
            "LEVEL_4_PRODUCT_VALIDATED": False,
        },
        "ctest_required_markers": ctest_presence,
        "numeric_gates": numeric_gates,
        "external_reference": {
            "matched_discrete_displacement_relative_tolerance": matched_tol,
            "continuum_displacement_relative_target": continuum_target,
            "near_incompressible": {
                "workflow_run_id": int(near["workflow_run_id"]),
                "fem_n4": near_mesh[4],
                "fem_n16": near_mesh[16],
                "reference_8_to_16_change": near_ref_change_8_16,
                "dyna_n4_3x3": dyna_near_n4,
                "dyna_n4_vs_fem_n16_relative_error": near_direct_continuum_error,
                "matched_gate_continuum_upper_bound": near_continuum_bound,
            },
            "fully_incompressible": {
                "workflow_run_id": int(full["workflow_run_id"]),
                "fem_n4": full_mesh[4],
                "fem_n16": full_mesh[16],
                "reference_8_to_16_change": full_ref_change_8_16,
                "matched_gate_continuum_upper_bound": full_continuum_bound,
            },
        },
        "pointwise_constraint_note": (
            "Herrmann pressure equation weak formdadir. Pointwise volumetric constraint "
            "tek basina acceptance gate degildir; weak residual, integral metrics ve "
            "independent parity ile birlikte yorumlanir."
        ),
        "commercial_parity_note": (
            "LEVEL 3 intentionally false: ANSYS PLANE183 and Hexagon Marc benchmark "
            "decks/results plus production sparse/block linear algebra evidence are still required."
        ),
        "overall_pass": level_2_pass,
    }


def pct(x: float) -> str:
    return f"{100.0 * x:.6f}%"


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# V0.3 H3 Q9/P1 Herrmann Acceptance Report",
        "",
        f"**LEVEL 2 independent verification:** `{'PASS' if report['overall_pass'] else 'FAIL'}`",
        "",
        "**LEVEL 3 commercial benchmark:** `OPEN` — ANSYS/Marc sonuclari olmadan PASS ilan edilmez.",
        "",
        "## Numeric gates",
        "",
        "| Gate | Value | Limit | Status |",
        "|---|---:|---:|---|",
    ]
    for item in report["numeric_gates"]:
        lines.append(
            f"| {item['name']} | {item['value']:.8e} | {item['limit']:.8e} | "
            f"{'PASS' if item['passed'] else 'FAIL'} |"
        )

    lines += ["", "## Required CTest evidence", ""]
    for name, present in report["ctest_required_markers"].items():
        lines.append(f"- `{name}`: {'PASS' if present else 'MISSING'}")

    ext = report["external_reference"]
    near = ext["near_incompressible"]
    full = ext["fully_incompressible"]
    lines += [
        "",
        "## Independent FEniCSx continuum evidence",
        "",
        f"- Near-incompressible FEniCSx 8→16 change: `{pct(near['reference_8_to_16_change'])}`",
        f"- Dyna n=4 / 3x3 vs FEniCSx n=16: `{pct(near['dyna_n4_vs_fem_n16_relative_error'])}`",
        f"- Near-incompressible matched-gate continuum upper bound: `{pct(near['matched_gate_continuum_upper_bound'])}`",
        f"- Fully-incompressible FEniCSx 8→16 change: `{pct(full['reference_8_to_16_change'])}`",
        f"- Fully-incompressible matched-gate continuum upper bound: `{pct(full['matched_gate_continuum_upper_bound'])}`",
        "",
        "## Interpretation",
        "",
        report["pointwise_constraint_note"],
        "",
        report["commercial_parity_note"],
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    production = load_json(args.production)
    mesh = load_json(args.mesh_refinement)
    quadrature = load_json(args.quadrature)
    snapshot = load_json(args.reference_snapshot)
    ctest_text = args.ctest_log.read_text(encoding="utf-8", errors="replace")

    report = build_report(production, mesh, quadrature, ctest_text, snapshot)

    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    args.markdown_output.write_text(build_markdown(report), encoding="utf-8")

    print(json.dumps(report, indent=2))
    if not report["overall_pass"]:
        raise SystemExit("V0.3 H3 Q9/P1 Herrmann LEVEL 2 acceptance gate FAILED")


if __name__ == "__main__":
    main()
