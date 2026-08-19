#!/usr/bin/env python3
"""Dyna V0.3 Cook benchmark CTest çıktısını makine-okunur JSON'a dönüştürür.

Bu araç yeni fizik hesaplamaz. Yalnız başarılı Fortran benchmark testlerinin
LastTest.log çıktısını ayrıştırır ve provenance bilgisiyle kalıcı bir sonuç
şemasına dönüştürür.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][+-]?\d+)?"


def finite_float(value: str, label: str) -> float:
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"Benchmark alanı sonlu değil: {label}={result}")
    return result


def find_float(text: str, pattern: str, label: str) -> float:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        raise ValueError(f"Beklenen benchmark alanı bulunamadı: {label}")
    return finite_float(match.group(1), label)


def find_solver_metrics(text: str, pattern: str, label: str) -> dict:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        raise ValueError(f"Beklenen solver metriği bulunamadı: {label}")
    final_min_j = finite_float(match.group(1), f"{label} finalMinJ")
    iterations = int(match.group(2))
    linear_solves = int(match.group(3))
    equations = int(match.group(4))
    if min(iterations, linear_solves, equations) < 0:
        raise ValueError(f"Negatif solver metriği: {label}")
    return {
        "final_minimum_j": final_min_j,
        "newton_iterations": iterations,
        "linear_solve_count": linear_solves,
        "max_linear_equation_count": equations,
    }


def parse_displacement(text: str) -> dict:
    cases: dict[str, dict] = {}
    for mesh in (2, 4, 8):
        tip = find_float(
            text,
            rf"Cook {mesh}x{mesh} tip displacement\s*=\s*({NUMBER})",
            f"displacement {mesh}x{mesh} tip",
        )
        solver = find_solver_metrics(
            text,
            rf"{mesh}x{mesh}:\s+finalMinJ=\s*({NUMBER})\s+iterations=(\d+)\s+linearSolves=(\d+)\s+equations=(\d+)",
            f"displacement {mesh}x{mesh}",
        )
        cases[str(mesh)] = {"tip_displacement": tip, **solver}

    gap_percent = find_float(
        text,
        rf"Coarse-to-8x8 stiffness/locking göstergesi\s*=\s*({NUMBER})\s*%",
        "displacement locking gap",
    )

    return {
        "formulation": "displacement_q4_full_integration",
        "mesh_results": cases,
        "coarse_to_8x8_gap_percent": gap_percent,
    }


def parse_mixed(text: str) -> dict:
    cases: dict[str, dict] = {}
    for mesh in (2, 4, 8):
        pressure_pattern = re.compile(
            rf"{mesh}x{mesh}:\s+tip=\s*({NUMBER})\s*\n"
            rf"\s*p\(min/mean/max\)=\s*({NUMBER})\s+({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*p\(std/rms\)=\s*({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*jump\(rms/max/norm\)=\s*({NUMBER})\s+({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*roughness\(jump/std,graph\)=\s*({NUMBER})\s+({NUMBER})",
            flags=re.MULTILINE,
        )
        match = pressure_pattern.search(text)
        if not match:
            raise ValueError(f"Mixed {mesh}x{mesh} benchmark bloğu bulunamadı")
        values = [finite_float(value, f"mixed {mesh}x{mesh}") for value in match.groups()]

        case_start = match.start()
        next_mesh_label = f"{mesh * 2}x{mesh * 2}:" if mesh < 8 else "V0.3 Q4-P0"
        case_end = text.find(next_mesh_label, match.end())
        if case_end < 0:
            case_end = len(text)
        local_text = text[case_start:case_end]
        solver = find_solver_metrics(
            local_text,
            rf"solver\(finalMinJ\)=\s*({NUMBER})\s+iterations=(\d+)\s+linearSolves=(\d+)\s+equations=(\d+)",
            f"mixed {mesh}x{mesh}",
        )

        cases[str(mesh)] = {
            "tip_displacement": values[0],
            **solver,
            "pressure": {
                "minimum": values[1],
                "mean": values[2],
                "maximum": values[3],
                "standard_deviation": values[4],
                "rms": values[5],
                "neighbor_jump_rms": values[6],
                "maximum_neighbor_jump": values[7],
                "normalized_neighbor_jump_rms": values[8],
                "neighbor_jump_to_std": values[9],
                "graph_roughness": values[10],
            },
        }

    return {
        "formulation": "mixed_q4_p0",
        "mesh_results": cases,
    }


def parse_fbar(text: str) -> dict:
    cases: dict[str, dict] = {}
    for mesh in (2, 4, 8):
        case_pattern = re.compile(
            rf"{mesh}x{mesh}:\s+F-bar tip=\s*({NUMBER})\s+finalMinJ=\s*({NUMBER})\s*\n"
            rf"\s*Jbar\(min/max\)=\s*({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*solver\s+iterations=(\d+)\s+linearSolves=(\d+)\s+equations=(\d+)",
            flags=re.MULTILINE,
        )
        match = case_pattern.search(text)
        if not match:
            raise ValueError(f"F-bar {mesh}x{mesh} benchmark bloğu bulunamadı")
        tip = finite_float(match.group(1), f"F-bar {mesh}x{mesh} tip")
        final_min_j = finite_float(match.group(2), f"F-bar {mesh}x{mesh} finalMinJ")
        jbar_min = finite_float(match.group(3), f"F-bar {mesh}x{mesh} Jbar min")
        jbar_max = finite_float(match.group(4), f"F-bar {mesh}x{mesh} Jbar max")

        cases[str(mesh)] = {
            "tip_displacement": tip,
            "final_minimum_j": final_min_j,
            "minimum_j_bar": jbar_min,
            "maximum_j_bar": jbar_max,
            "newton_iterations": int(match.group(5)),
            "linear_solve_count": int(match.group(6)),
            "max_linear_equation_count": int(match.group(7)),
        }

    gap_percent = find_float(
        text,
        rf"F-bar coarse-to-8x8 gap\s*=\s*({NUMBER})\s*%",
        "F-bar locking gap",
    )

    return {
        "formulation": "fbar_q4",
        "mesh_results": cases,
        "coarse_to_8x8_gap_percent": gap_percent,
        "tangent": "analytic_energy_consistent_second_variation",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--run-id", default="")
    parser.add_argument("--runner", default="ubuntu-24.04")
    parser.add_argument("--compiler", default="gfortran-14")
    args = parser.parse_args()

    text = args.log.read_text(encoding="utf-8", errors="replace")

    result = {
        "schema_version": 2,
        "milestone": "V0.3",
        "benchmark": "normalized_cook_membrane_nearly_incompressible",
        "provenance": {
            "source_commit": args.source_commit,
            "github_actions_run_id": args.run_id,
            "runner": args.runner,
            "compiler": args.compiler,
            "source": "CTest LastTest.log; passing Fortran benchmark stdout",
        },
        "problem": {
            "plane_condition": "plane_strain",
            "material": "compressible_neo_hookean_common_family",
            "mu": 1.0,
            "lambda": 1000.0,
            "reference_nominal_traction_y": 0.01,
            "meshes": ["2x2", "4x4", "8x8"],
        },
        "metric_semantics": {
            "final_minimum_j": "minimum J recomputed from the converged final state",
            "historical_newton_minimum_j": "not used in the formulation comparison JSON",
            "newton_iterations": "total nonlinear correction iterations over all load increments",
            "max_linear_equation_count": "largest reduced linear system solved by the formulation",
        },
        "formulations": {
            "displacement": parse_displacement(text),
            "mixed_up": parse_mixed(text),
            "fbar": parse_fbar(text),
        },
        "decision_status": "measurement_only_no_production_selection",
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
