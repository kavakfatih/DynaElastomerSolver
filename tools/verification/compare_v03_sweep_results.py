#!/usr/bin/env python3
"""V0.3 incompressibility sweep sonuçlarını platformlar arasında karşılaştırır.

Bu araç yeni fizik çözmez. Her platformda Fortran CTest'in ürettiği
`V0.3_INCOMPRESSIBILITY_SWEEP_RESULTS.json` dosyalarını karşılaştırır.
Amaç Windows/ifx, Windows/gfortran ve macOS/gfortran'ın aynı lambda/mu
sensitivity eğrisini verdiğini doğrulamaktır.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

FORMULATIONS = ("displacement_q4", "mixed_q4_p0", "fbar_q4")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", help="Karşılaştırılacak sweep JSON dosyaları")
    parser.add_argument("--rtol", type=float, default=1.0e-8)
    parser.add_argument("--atol", type=float, default=1.0e-11)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_result(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if int(data.get("schema_version", -1)) != 1:
        raise ValueError(f"{path}: beklenen schema_version=1 bulunamadı")
    if data.get("benchmark") != "cook_4x4_incompressibility_lambda_mu_sweep":
        raise ValueError(f"{path}: beklenmeyen benchmark adı")

    lambdas = [float(v) for v in data.get("lambda_over_mu", [])]
    if lambdas != [10.0, 100.0, 1000.0]:
        raise ValueError(f"{path}: lambda/mu dizisi 10/100/1000 değil: {lambdas}")

    tips = data.get("tip_displacement")
    drops = data.get("lambda10_to_1000_drop")
    if not isinstance(tips, dict) or not isinstance(drops, dict):
        raise ValueError(f"{path}: sweep sonuç alanları eksik")

    for formulation in FORMULATIONS:
        values = tips.get(formulation)
        if not isinstance(values, list) or len(values) != 3:
            raise ValueError(f"{path}: {formulation} tip dizisi 3 elemanlı değil")
        if formulation not in drops:
            raise ValueError(f"{path}: {formulation} drop metriği eksik")

    return data


def relative_difference(a: float, b: float, atol: float) -> float:
    return abs(a - b) / max(abs(a), abs(b), atol)


def compare(reference: dict[str, Any], candidate: dict[str, Any], rtol: float, atol: float) -> dict[str, Any]:
    failures: list[dict[str, Any]] = []
    max_relative_difference = 0.0

    for formulation in FORMULATIONS:
        ref_values = [float(v) for v in reference["tip_displacement"][formulation]]
        cand_values = [float(v) for v in candidate["tip_displacement"][formulation]]

        for index, lambda_value in enumerate((10.0, 100.0, 1000.0)):
            a = ref_values[index]
            b = cand_values[index]
            rel = relative_difference(a, b, atol)
            max_relative_difference = max(max_relative_difference, rel)
            if not math.isclose(a, b, rel_tol=rtol, abs_tol=atol):
                failures.append({
                    "formulation": formulation,
                    "lambda_over_mu": lambda_value,
                    "field": "tip_displacement",
                    "reference": a,
                    "candidate": b,
                    "relative_difference": rel,
                })

        a = float(reference["lambda10_to_1000_drop"][formulation])
        b = float(candidate["lambda10_to_1000_drop"][formulation])
        rel = relative_difference(a, b, atol)
        max_relative_difference = max(max_relative_difference, rel)
        if not math.isclose(a, b, rel_tol=rtol, abs_tol=atol):
            failures.append({
                "formulation": formulation,
                "field": "lambda10_to_1000_drop",
                "reference": a,
                "candidate": b,
                "relative_difference": rel,
            })

    a = float(reference["mixed_fbar_relative_tip_difference_at_lambda1000"])
    b = float(candidate["mixed_fbar_relative_tip_difference_at_lambda1000"])
    rel = relative_difference(a, b, atol)
    max_relative_difference = max(max_relative_difference, rel)
    if not math.isclose(a, b, rel_tol=rtol, abs_tol=atol):
        failures.append({
            "field": "mixed_fbar_relative_tip_difference_at_lambda1000",
            "reference": a,
            "candidate": b,
            "relative_difference": rel,
        })

    return {
        "passed": not failures,
        "max_relative_difference": max_relative_difference,
        "failures": failures,
    }


def main() -> int:
    args = parse_args()
    paths = [Path(p) for p in args.inputs]
    if len(paths) < 2:
        raise SystemExit("En az iki platform sweep JSON dosyası gerekli.")

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
        "benchmark": "cook_4x4_incompressibility_lambda_mu_sweep",
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
