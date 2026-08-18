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


def find_float(text: str, pattern: str, label: str) -> float:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        raise ValueError(f"Beklenen benchmark alanı bulunamadı: {label}")
    value = float(match.group(1))
    if not math.isfinite(value):
        raise ValueError(f"Benchmark alanı sonlu değil: {label}={value}")
    return value


def parse_displacement(text: str) -> dict:
    tips = {}
    for mesh in (2, 4, 8):
        tips[str(mesh)] = find_float(
            text,
            rf"Cook {mesh}x{mesh} tip displacement\s*=\s*({NUMBER})",
            f"displacement {mesh}x{mesh} tip",
        )

    gap_percent = find_float(
        text,
        rf"Coarse-to-8x8 stiffness/locking göstergesi\s*=\s*({NUMBER})\s*%",
        "displacement locking gap",
    )

    return {
        "formulation": "displacement_q4_full_integration",
        "mesh_tip_displacement": tips,
        "coarse_to_8x8_gap_percent": gap_percent,
    }


def parse_mixed(text: str) -> dict:
    cases: dict[str, dict] = {}
    for mesh in (2, 4, 8):
        case_pattern = re.compile(
            rf"{mesh}x{mesh}:\s+tip=\s*({NUMBER})\s*\n"
            rf"\s*p\(min/mean/max\)=\s*({NUMBER})\s+({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*p\(std/rms\)=\s*({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*jump\(rms/max/norm\)=\s*({NUMBER})\s+({NUMBER})\s+({NUMBER})\s*\n"
            rf"\s*roughness\(jump/std,graph\)=\s*({NUMBER})\s+({NUMBER})",
            flags=re.MULTILINE,
        )
        match = case_pattern.search(text)
        if not match:
            raise ValueError(f"Mixed {mesh}x{mesh} benchmark bloğu bulunamadı")
        values = [float(value) for value in match.groups()]
        if not all(math.isfinite(value) for value in values):
            raise ValueError(f"Mixed {mesh}x{mesh} benchmarkında sonlu olmayan değer var")

        cases[str(mesh)] = {
            "tip_displacement": values[0],
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
        match = re.search(
            rf"{mesh}x{mesh} F-bar tip=\s*({NUMBER})\s+minJ=\s*({NUMBER})",
            text,
            flags=re.MULTILINE,
        )
        if not match:
            raise ValueError(f"F-bar {mesh}x{mesh} benchmark satırı bulunamadı")
        tip, min_j = (float(match.group(1)), float(match.group(2)))
        if not math.isfinite(tip) or not math.isfinite(min_j):
            raise ValueError(f"F-bar {mesh}x{mesh} benchmarkında sonlu olmayan değer var")
        cases[str(mesh)] = {
            "tip_displacement": tip,
            "minimum_j": min_j,
        }

    gap_percent = find_float(
        text,
        rf"F-bar coarse-to-8x8 gap\s*=\s*({NUMBER})\s*%",
        "F-bar locking gap",
    )

    return {
        "formulation": "fbar_q4_verification_prototype",
        "mesh_results": cases,
        "coarse_to_8x8_gap_percent": gap_percent,
        "tangent": "central_finite_difference_verification_tangent",
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
        "schema_version": 1,
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
