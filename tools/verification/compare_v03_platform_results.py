#!/usr/bin/env python3
"""V0.3 Cook bake-off sonuçlarını compiler/platformlar arasında karşılaştırır.

Bu araç yeni fizik çözmez. Her platformda gerçek Fortran birleşik benchmark testinin
ürettiği JSON dosyalarını karşılaştırır. Amaç Windows/ifx, Windows/gfortran ve
macOS/gfortran sonuçlarının aynı fiziksel çözümü verdiğini doğrulamaktır.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

FORMULATIONS = ("displacement_q4", "mixed_q4_p0", "fbar_q4")
NUMERIC_FIELDS = (
    "tip",
    "final_min_j",
    "pressure_mean",
    "pressure_std",
    "pressure_rms",
    "pressure_jump_rms",
    "pressure_graph_roughness",
    "min_j_bar",
    "max_j_bar",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", help="Karşılaştırılacak bake-off JSON dosyaları")
    parser.add_argument("--rtol", type=float, default=1.0e-8)
    parser.add_argument("--atol", type=float, default=1.0e-11)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_result(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if int(data.get("schema_version", -1)) != 3:
        raise ValueError(f"{path}: beklenen schema_version=3 bulunamadı")
    formulations = data.get("formulations")
    if not isinstance(formulations, dict):
        raise ValueError(f"{path}: formulations alanı eksik")
    for name in FORMULATIONS:
        if name not in formulations:
            raise ValueError(f"{path}: formulation eksik: {name}")
    return data


def mesh_map(data: dict[str, Any], formulation: str) -> dict[int, dict[str, Any]]:
    meshes = data["formulations"][formulation].get("meshes", [])
    result = {int(item["n"]): item for item in meshes}
    if set(result) != {2, 4, 8}:
        raise ValueError(f"{formulation}: beklenen mesh kümesi 2/4/8 değil: {sorted(result)}")
    return result


def compare(reference: dict[str, Any], candidate: dict[str, Any], rtol: float, atol: float) -> dict[str, Any]:
    failures: list[dict[str, Any]] = []
    iteration_differences: list[dict[str, Any]] = []
    max_relative_difference = 0.0

    for formulation in FORMULATIONS:
        ref_meshes = mesh_map(reference, formulation)
        cand_meshes = mesh_map(candidate, formulation)

        for n in (2, 4, 8):
            ref = ref_meshes[n]
            cand = cand_meshes[n]

            if int(ref["equations"]) != int(cand["equations"]):
                failures.append({
                    "formulation": formulation,
                    "mesh": n,
                    "field": "equations",
                    "reference": int(ref["equations"]),
                    "candidate": int(cand["equations"]),
                })

            for field in NUMERIC_FIELDS:
                a = float(ref.get(field, 0.0))
                b = float(cand.get(field, 0.0))
                scale = max(abs(a), abs(b), atol)
                rel = abs(a - b) / scale
                max_relative_difference = max(max_relative_difference, rel)
                if not math.isclose(a, b, rel_tol=rtol, abs_tol=atol):
                    failures.append({
                        "formulation": formulation,
                        "mesh": n,
                        "field": field,
                        "reference": a,
                        "candidate": b,
                        "relative_difference": rel,
                    })

            for field in ("iterations", "linear_solves"):
                a = int(ref.get(field, 0))
                b = int(cand.get(field, 0))
                if a != b:
                    # Iterasyon sayısı floating-point sınırında compiler'a göre bir
                    # adım değişebilir. Fiziksel alanlar eşleşiyorsa bunu bilgi olarak
                    # raporlarız, doğrudan platform başarısızlığı yapmayız.
                    iteration_differences.append({
                        "formulation": formulation,
                        "mesh": n,
                        "field": field,
                        "reference": a,
                        "candidate": b,
                    })

    return {
        "passed": not failures,
        "max_relative_difference": max_relative_difference,
        "failures": failures,
        "iteration_differences": iteration_differences,
    }


def main() -> int:
    args = parse_args()
    paths = [Path(p) for p in args.inputs]
    if len(paths) < 2:
        raise SystemExit("En az iki platform JSON dosyası gerekli.")

    loaded = [(path, load_result(path)) for path in paths]
    reference_path, reference = loaded[0]

    comparisons = []
    overall_passed = True
    for path, candidate in loaded[1:]:
        result = compare(reference, candidate, args.rtol, args.atol)
        result["reference"] = str(reference_path)
        result["candidate"] = str(path)
        comparisons.append(result)
        overall_passed = overall_passed and result["passed"]

    report = {
        "schema_version": 1,
        "passed": overall_passed,
        "rtol": args.rtol,
        "atol": args.atol,
        "comparisons": comparisons,
    }

    text = json.dumps(report, indent=2, ensure_ascii=False)
    print(text)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")

    return 0 if overall_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
