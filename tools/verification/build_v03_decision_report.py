#!/usr/bin/env python3
"""DynaElastomerSolver V0.3 formulation bake-off karar kanıt raporu.

Bu araç yeni FEM çözmez ve formulation seçmez.

Girdiler:
- Dyna birleşik Fortran Cook JSON'u (schema_version=3)
- bağımsız FEniCSx/DOLFINx Q2 Cook referans JSON'u

Çıktılar:
- karşılaştırma JSON'u
- Markdown kanıt tablosu

Referans mesh sayısı sabit değildir. Dış Q2 JSON'undaki en ince iki mesh otomatik
bulunur; convergence kararı bu iki seviyenin tip displacement farkına göre verilir.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

FORMULATIONS = ("displacement_q4", "mixed_q4_p0", "fbar_q4")
DYNA_MESHES = (2, 4, 8)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dyna", required=True, type=Path)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--json-output", required=True, type=Path)
    parser.add_argument("--markdown-output", required=True, type=Path)
    parser.add_argument("--reference-convergence-threshold", type=float, default=0.01)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_dyna(data: dict[str, Any]) -> None:
    if int(data.get("schema_version", -1)) != 3:
        raise ValueError("Dyna bake-off JSON schema_version=3 olmalıdır.")
    formulations = data.get("formulations")
    if not isinstance(formulations, dict):
        raise ValueError("Dyna formulations alanı eksik.")
    for name in FORMULATIONS:
        if name not in formulations:
            raise ValueError(f"Dyna formulation eksik: {name}")
        mesh_ids = {int(item["n"]) for item in formulations[name].get("meshes", [])}
        if mesh_ids != set(DYNA_MESHES):
            raise ValueError(f"{name}: Dyna mesh kümesi 2/4/8 olmalıdır: {sorted(mesh_ids)}")


def validate_reference(data: dict[str, Any]) -> list[int]:
    cases = data.get("mesh_cases")
    if not isinstance(cases, list):
        raise ValueError("Dış Q2 mesh_cases alanı eksik.")
    mesh_ids = sorted({int(item["n"]) for item in cases})
    if not set(DYNA_MESHES).issubset(mesh_ids):
        raise ValueError("Dış Q2 referans en az 2/4/8 meshlerini içermelidir.")
    if len(mesh_ids) < 4 or max(mesh_ids) <= 8:
        raise ValueError("Convergence kontrolü için 8x8'den daha ince en az bir Q2 mesh gerekir.")
    for case in cases:
        tip = float(case["tip_y_displacement"])
        if not math.isfinite(tip) or tip <= 0.0:
            raise ValueError(f"Geçersiz Q2 tip displacement: n={case.get('n')}")
    return mesh_ids


def dyna_mesh_map(data: dict[str, Any], formulation: str) -> dict[int, dict[str, Any]]:
    return {int(item["n"]): item for item in data["formulations"][formulation]["meshes"]}


def reference_mesh_map(data: dict[str, Any]) -> dict[int, dict[str, Any]]:
    return {int(item["n"]): item for item in data["mesh_cases"]}


def relative_error(value: float, reference: float) -> float:
    return abs(value - reference) / max(abs(reference), 1.0e-30)


def signed_relative_error(value: float, reference: float) -> float:
    return (value - reference) / max(abs(reference), 1.0e-30)


def pressure_metrics(case: dict[str, Any]) -> dict[str, float]:
    pressure = case["pressure_from_lambda_lnJ"]
    return {
        "mean": float(pressure["mean"]),
        "standard_deviation": float(pressure["standard_deviation"]),
        "rms": float(pressure["rms"]),
    }


def build_report(
    dyna: dict[str, Any], reference: dict[str, Any], convergence_threshold: float
) -> dict[str, Any]:
    validate_dyna(dyna)
    reference_levels = validate_reference(reference)
    q2 = reference_mesh_map(reference)

    previous_mesh = reference_levels[-2]
    finest_mesh = reference_levels[-1]
    previous_tip = float(q2[previous_mesh]["tip_y_displacement"])
    finest_tip = float(q2[finest_mesh]["tip_y_displacement"])
    final_refinement_change = relative_error(previous_tip, finest_tip)
    reference_candidate_converged = final_refinement_change <= convergence_threshold

    formulations: dict[str, Any] = {}
    for name in FORMULATIONS:
        source = dyna_mesh_map(dyna, name)
        rows = []
        for n in DYNA_MESHES:
            item = source[n]
            tip = float(item["tip"])
            same_mesh_tip = float(q2[n]["tip_y_displacement"])
            rows.append(
                {
                    "n": n,
                    "tip": tip,
                    "q2_same_mesh_tip": same_mesh_tip,
                    "tip_absolute_error_same_mesh": abs(tip - same_mesh_tip),
                    "tip_relative_error_same_mesh": relative_error(tip, same_mesh_tip),
                    "tip_signed_relative_error_same_mesh": signed_relative_error(tip, same_mesh_tip),
                    "q2_finest_mesh": finest_mesh,
                    "q2_finest_tip": finest_tip,
                    "tip_absolute_error_vs_q2_finest": abs(tip - finest_tip),
                    "tip_relative_error_vs_q2_finest": relative_error(tip, finest_tip),
                    "tip_signed_relative_error_vs_q2_finest": signed_relative_error(tip, finest_tip),
                    "final_min_j": float(item["final_min_j"]),
                    "iterations": int(item["iterations"]),
                    "linear_solves": int(item["linear_solves"]),
                    "equations": int(item["equations"]),
                    "pressure_mean": float(item.get("pressure_mean", 0.0)),
                    "pressure_std": float(item.get("pressure_std", 0.0)),
                    "pressure_rms": float(item.get("pressure_rms", 0.0)),
                    "pressure_jump_rms": float(item.get("pressure_jump_rms", 0.0)),
                    "pressure_graph_roughness": float(item.get("pressure_graph_roughness", 0.0)),
                    "min_j_bar": float(item.get("min_j_bar", 0.0)),
                    "max_j_bar": float(item.get("max_j_bar", 0.0)),
                }
            )
        formulations[name] = {
            "coarse_to_8x8_gap": float(dyna["formulations"][name]["coarse_to_8x8_gap"]),
            "meshes": rows,
        }

    pressure_comparison = []
    for row in formulations["mixed_q4_p0"]["meshes"]:
        n = int(row["n"])
        ref_p = pressure_metrics(q2[n])
        pressure_comparison.append(
            {
                "n": n,
                "dyna_mean": row["pressure_mean"],
                "q2_mean": ref_p["mean"],
                "mean_relative_error": relative_error(row["pressure_mean"], ref_p["mean"]),
                "dyna_std": row["pressure_std"],
                "q2_std": ref_p["standard_deviation"],
                "std_relative_error": relative_error(row["pressure_std"], ref_p["standard_deviation"]),
                "dyna_rms": row["pressure_rms"],
                "q2_rms": ref_p["rms"],
                "rms_relative_error": relative_error(row["pressure_rms"], ref_p["rms"]),
                "neighbor_jump_rms": row["pressure_jump_rms"],
                "graph_roughness": row["pressure_graph_roughness"],
            }
        )

    disp = {row["n"]: row for row in formulations["displacement_q4"]["meshes"]}
    mixed = {row["n"]: row for row in formulations["mixed_q4_p0"]["meshes"]}
    fbar = {row["n"]: row for row in formulations["fbar_q4"]["meshes"]}
    cost_comparison = []
    for n in DYNA_MESHES:
        cost_comparison.append(
            {
                "n": n,
                "displacement_equations": disp[n]["equations"],
                "mixed_equations": mixed[n]["equations"],
                "fbar_equations": fbar[n]["equations"],
                "mixed_to_displacement_equation_ratio": mixed[n]["equations"] / disp[n]["equations"],
                "fbar_to_displacement_equation_ratio": fbar[n]["equations"] / disp[n]["equations"],
                "displacement_iterations": disp[n]["iterations"],
                "mixed_iterations": mixed[n]["iterations"],
                "fbar_iterations": fbar[n]["iterations"],
            }
        )

    accuracy_order = sorted(
        (
            {
                "formulation": name,
                "tip_relative_error_vs_q2_finest": formulations[name]["meshes"][-1]["tip_relative_error_vs_q2_finest"],
            }
            for name in FORMULATIONS
        ),
        key=lambda item: item["tip_relative_error_vs_q2_finest"],
    )

    return {
        "schema_version": 2,
        "purpose": "V0.3 formulation selection evidence; no automatic production decision",
        "production_formulation_selected": False,
        "reference": {
            "solver": reference.get("reference_solver", "FEniCSx / DOLFINx"),
            "dolfinx_version": reference.get("dolfinx_version"),
            "available_mesh_levels": reference_levels,
            "previous_mesh": previous_mesh,
            "finest_mesh": finest_mesh,
            "finest_tip_y_displacement": finest_tip,
            "relative_tip_change_previous_to_finest": final_refinement_change,
            "candidate_convergence_threshold": convergence_threshold,
            "candidate_converged": reference_candidate_converged,
            "warning": None if reference_candidate_converged else (
                f"Q2 {previous_mesh}→{finest_mesh} tip değişimi eşikten büyük; "
                f"{finest_mesh}x{finest_mesh} henüz converged referans kabul edilmemeli."
            ),
        },
        "formulations": formulations,
        "mixed_pressure_vs_q2_continuum": pressure_comparison,
        "cost_comparison": cost_comparison,
        "accuracy_order_8x8_vs_q2_finest_informational_only": accuracy_order,
        "decision_rules": [
            "Production formulation otomatik seçilmez.",
            "Dış Q2 referans convergence eşiğini geçmeden absolute accuracy kararı verilmez.",
            "Coarse-to-8x8 gap locking doğruluğunun tek başına ölçüsü değildir.",
            "Mixed pressure roughness tek başına checkerboard kararı değildir.",
            "Accuracy, pressure stability, Newton robustness, maliyet ve axisymmetric/torsion genişletilebilirliği birlikte değerlendirilir.",
        ],
    }


def pct(value: float) -> str:
    return f"{100.0 * value:.3f}%"


def fmt(value: float) -> str:
    return f"{value:.8g}"


def build_markdown(report: dict[str, Any]) -> str:
    lines: list[str] = [
        "# V0.3 Formulation Karar Kanıt Tablosu",
        "",
        "**Durum:** otomatik production seçimi yapılmamıştır.",
        "",
    ]

    ref = report["reference"]
    lines += [
        "## Dış Q2 referans convergence",
        "",
        f"- Solver: `{ref['solver']}`",
    ]
    if ref.get("dolfinx_version"):
        lines.append(f"- DOLFINx: `{ref['dolfinx_version']}`")
    lines += [
        f"- Mesh seviyeleri: `{ref['available_mesh_levels']}`",
        f"- En ince Q2: `{ref['finest_mesh']}×{ref['finest_mesh']}`",
        f"- En ince Q2 tip: `{fmt(ref['finest_tip_y_displacement'])}`",
        f"- Son refinement tip değişimi: `{pct(ref['relative_tip_change_previous_to_finest'])}`",
        f"- Converged-aday eşiği: `{pct(ref['candidate_convergence_threshold'])}`",
        f"- Converged-aday: `{'EVET' if ref['candidate_converged'] else 'HAYIR'}`",
    ]
    if ref.get("warning"):
        lines.append(f"- ⚠️ {ref['warning']}")
    lines.append("")

    finest = ref["finest_mesh"]
    lines += [
        "## Tip displacement accuracy",
        "",
        f"| Formulation | Mesh | Dyna tip | Aynı-mesh Q2 | Aynı-mesh hata | Q2 {finest} tip | Q2 {finest} hata | final min J | Eq. | Iter. |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for name in FORMULATIONS:
        for row in report["formulations"][name]["meshes"]:
            lines.append(
                f"| {name} | {row['n']}×{row['n']} | {fmt(row['tip'])}"
                f" | {fmt(row['q2_same_mesh_tip'])} | {pct(row['tip_relative_error_same_mesh'])}"
                f" | {fmt(row['q2_finest_tip'])} | {pct(row['tip_relative_error_vs_q2_finest'])}"
                f" | {fmt(row['final_min_j'])} | {row['equations']} | {row['iterations']} |"
            )
    lines.append("")

    lines += [
        "## Mixed pressure vs continuum Q2",
        "",
        "| Mesh | Dyna p mean | Q2 p mean | mean hata | Dyna p std | Q2 p std | std hata | graph roughness |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in report["mixed_pressure_vs_q2_continuum"]:
        lines.append(
            f"| {row['n']}×{row['n']} | {fmt(row['dyna_mean'])} | {fmt(row['q2_mean'])}"
            f" | {pct(row['mean_relative_error'])} | {fmt(row['dyna_std'])} | {fmt(row['q2_std'])}"
            f" | {pct(row['std_relative_error'])} | {fmt(row['graph_roughness'])} |"
        )
    lines.append("")

    lines += [
        "## Lineer sistem maliyeti",
        "",
        "| Mesh | Disp. eq | Mixed eq | F-bar eq | Mixed/Disp. | F-bar/Disp. |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in report["cost_comparison"]:
        lines.append(
            f"| {row['n']}×{row['n']} | {row['displacement_equations']} | {row['mixed_equations']}"
            f" | {row['fbar_equations']} | {row['mixed_to_displacement_equation_ratio']:.3f}"
            f" | {row['fbar_to_displacement_equation_ratio']:.3f} |"
        )
    lines.append("")

    lines += [
        f"## 8×8 → Q2 {finest} accuracy sırası — yalnız bilgi",
        "",
    ]
    for index, item in enumerate(
        report["accuracy_order_8x8_vs_q2_finest_informational_only"], start=1
    ):
        lines.append(
            f"{index}. `{item['formulation']}` — relative tip hata "
            f"`{pct(item['tip_relative_error_vs_q2_finest'])}`"
        )
    lines += [
        "",
        "> Bu sıra production formulation kararı değildir. Dış referans convergence, pressure stability, Newton robustness, maliyet ve V0.4/V0.5 genişletilebilirliği birlikte değerlendirilmelidir.",
        "",
        "## Karar kuralları",
        "",
    ]
    lines.extend(f"- {rule}" for rule in report["decision_rules"])
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    report = build_report(
        load_json(args.dyna),
        load_json(args.reference),
        args.reference_convergence_threshold,
    )
    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    args.markdown_output.write_text(build_markdown(report), encoding="utf-8")
    print(f"V0.3 karar kanıt JSON'u: {args.json_output}")
    print(f"V0.3 karar kanıt Markdown: {args.markdown_output}")
    print(f"Q2 reference converged-aday: {report['reference']['candidate_converged']}")
    print("Production formulation otomatik seçilmedi.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
