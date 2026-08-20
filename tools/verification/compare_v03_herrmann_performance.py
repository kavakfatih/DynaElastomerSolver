#!/usr/bin/env python3
"""V0.3 Q9/P1 Herrmann GMRES/MUMPS performans baseline karsilastirmasi.

Timing degerleri yalniz raporlanir; CI pass/fail karari wall-clock oranina baglanmaz.
Yapisal metadata ve ayni fizik probleminin cozum sonucu ise correctness kapisi olarak
kontrol edilir.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


STRUCTURAL_FIELDS = (
    "mesh_n",
    "nodes",
    "elements",
    "displacement_dofs",
    "pressure_dofs",
    "total_dofs",
    "constrained_displacement_dofs",
    "free_equations",
    "csr_nnz",
)

PHYSICS_FIELDS = (
    "tip_y_displacement",
    "minimum_J",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gmres", required=True, type=Path)
    parser.add_argument("--mumps", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict) or not isinstance(data.get("cases"), list):
        raise SystemExit(f"Gecersiz performance JSON semasi: {path}")
    return data


def relative_gap(a: float, b: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), 1.0e-14)


def require_finite(case: dict[str, Any], field: str, label: str) -> float:
    value = float(case[field])
    if not math.isfinite(value):
        raise SystemExit(f"{label}: {field} finite degil")
    return value


def main() -> None:
    args = parse_args()
    gmres = load_json(args.gmres)
    mumps = load_json(args.mumps)

    gmres_cases = gmres["cases"]
    mumps_cases = mumps["cases"]
    if len(gmres_cases) != len(mumps_cases) or not gmres_cases:
        raise SystemExit("GMRES/MUMPS case sayilari uyusmuyor veya bos")

    comparison_cases: list[dict[str, Any]] = []
    max_tip_gap = 0.0
    max_j_gap = 0.0

    for index, (gcase, mcase) in enumerate(zip(gmres_cases, mumps_cases, strict=True), start=1):
        for field in STRUCTURAL_FIELDS:
            if gcase.get(field) != mcase.get(field):
                raise SystemExit(
                    f"case {index}: yapisal metadata uyusmuyor: {field} "
                    f"GMRES={gcase.get(field)} MUMPS={mcase.get(field)}"
                )

        if gcase.get("selected_backend") != "stdlib CSR GMRES (bootstrap)":
            raise SystemExit(f"case {index}: GMRES selected_backend beklenen degil")
        if mcase.get("selected_backend") != "MUMPS sparse direct":
            raise SystemExit(f"case {index}: MUMPS selected_backend beklenen degil")
        if bool(gcase.get("fallback_used")) or bool(mcase.get("fallback_used")):
            raise SystemExit(f"case {index}: explicit backend benchmark fallback kullanmamalidir")

        tip_g = require_finite(gcase, "tip_y_displacement", "GMRES")
        tip_m = require_finite(mcase, "tip_y_displacement", "MUMPS")
        j_g = require_finite(gcase, "minimum_J", "GMRES")
        j_m = require_finite(mcase, "minimum_J", "MUMPS")
        wall_g = require_finite(gcase, "wall_seconds", "GMRES")
        wall_m = require_finite(mcase, "wall_seconds", "MUMPS")

        tip_gap = relative_gap(tip_g, tip_m)
        j_gap = relative_gap(j_g, j_m)
        max_tip_gap = max(max_tip_gap, tip_gap)
        max_j_gap = max(max_j_gap, j_gap)

        # Bu iki esik performance degil correctness parity kapisidir.
        if tip_gap > 5.0e-6:
            raise SystemExit(f"case {index}: GMRES/MUMPS tip displacement parity asildi: {tip_gap}")
        if j_gap > 5.0e-6:
            raise SystemExit(f"case {index}: GMRES/MUMPS minimum J parity asildi: {j_gap}")

        for field in ("displacement_residual_inf_norm", "pressure_residual_inf_norm"):
            gval = require_finite(gcase, field, "GMRES")
            mval = require_finite(mcase, field, "MUMPS")
            if gval > 5.0e-8 or mval > 5.0e-8:
                raise SystemExit(f"case {index}: {field} correctness toleransi asildi")

        comparison_cases.append(
            {
                "mesh_n": gcase["mesh_n"],
                "total_dofs": gcase["total_dofs"],
                "csr_nnz": gcase["csr_nnz"],
                "gmres_wall_seconds": wall_g,
                "mumps_wall_seconds": wall_m,
                "mumps_over_gmres_wall_ratio": wall_m / max(wall_g, 1.0e-12),
                "tip_y_relative_gap": tip_gap,
                "minimum_J_relative_gap": j_gap,
            }
        )

    output = {
        "schema_version": 1,
        "comparison": "V0.3 Q9/P1 Herrmann same-runner GMRES vs MUMPS",
        "timing_policy": "report-only; timing ratio is never a pass/fail threshold",
        "correctness_policy": "structural metadata exact; tip_y/minimum_J relative gap <= 5e-6",
        "max_tip_y_relative_gap": max_tip_gap,
        "max_minimum_J_relative_gap": max_j_gap,
        "cases": comparison_cases,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
