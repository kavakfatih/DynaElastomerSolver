#!/usr/bin/env python3
"""DynaElastomerSolver tam Git geçmişi secret/credential denetimi.

Bu araç yalnız Git tarafından ulaşılabilir blobları inceler. Bir bulgu olduğunda
secret değerini yazdırmaz; yalnız risk sınıfını, obje SHA'sını ve bilinen yolu
raporlar.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

MAX_BLOB_BYTES = 25 * 1024 * 1024


@dataclass(frozen=True)
class Finding:
    risk: str
    oid: str
    path: str


def run_git(*args: str, input_data: bytes | None = None) -> bytes:
    proc = subprocess.run(
        ["git", *args],
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        message = proc.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"git {' '.join(args)} başarısız: {message}")
    return proc.stdout


def reachable_objects() -> list[tuple[str, str]]:
    raw = run_git("rev-list", "--objects", "--all").decode("utf-8", errors="replace")
    objects: list[tuple[str, str]] = []
    for line in raw.splitlines():
        if not line:
            continue
        parts = line.split(" ", 1)
        oid = parts[0].strip()
        path = parts[1].strip() if len(parts) == 2 else ""
        objects.append((oid, path))
    return objects


def object_metadata(oids: list[str]) -> dict[str, tuple[str, int]]:
    if not oids:
        return {}
    payload = ("\n".join(oids) + "\n").encode("ascii")
    raw = run_git(
        "cat-file",
        "--batch-check=%(objectname) %(objecttype) %(objectsize)",
        input_data=payload,
    ).decode("utf-8", errors="replace")
    result: dict[str, tuple[str, int]] = {}
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) != 3:
            continue
        oid, obj_type, size_text = fields
        try:
            size = int(size_text)
        except ValueError:
            continue
        result[oid] = (obj_type, size)
    return result


def build_content_patterns() -> list[tuple[str, re.Pattern[bytes]]]:
    private_key_markers = [
        b"-----BEGIN " + suffix + b"PRIVATE KEY-----"
        for suffix in (b"", b"RSA ", b"EC ", b"OPENSSH ", b"DSA ")
    ]

    token_prefixes = [
        b"gh" + b"p_",
        b"gh" + b"o_",
        b"gh" + b"u_",
        b"gh" + b"s_",
        b"gh" + b"r_",
        b"github_" + b"pat_",
    ]

    patterns: list[tuple[str, re.Pattern[bytes]]] = []
    for marker in private_key_markers:
        patterns.append(("private-key-marker", re.compile(re.escape(marker))))
    for prefix in token_prefixes:
        patterns.append(
            (
                "github-token",
                re.compile(re.escape(prefix) + rb"[A-Za-z0-9_]{20,}"),
            )
        )

    patterns.extend(
        [
            ("aws-access-key-id", re.compile((b"AK" + b"IA") + rb"[0-9A-Z]{16}")),
            (
                "jwt-like-token",
                re.compile(
                    (b"ey" + b"J")
                    + rb"[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
                ),
            ),
            (
                "credential-url",
                re.compile(rb"https?://[^/\s:@]{1,128}:[^@\s/]{3,256}@"),
            ),
        ]
    )

    credential_names = [
        b"password",
        b"passwd",
        b"secret",
        b"api_key",
        b"apikey",
        b"access_token",
        b"auth_token",
        b"client_secret",
        b"private_token",
    ]
    name_group = b"|".join(re.escape(name) for name in credential_names)
    patterns.append(
        (
            "credential-assignment",
            re.compile(
                rb"(?i)\b(?:"
                + name_group
                + rb")\b\s*[:=]\s*[\"']?[A-Za-z0-9_./+=-]{12,}"
            ),
        )
    )
    return patterns


def path_risk(path: str) -> str | None:
    normalized = path.replace("\\", "/")
    checks = [
        re.compile(r"(^|/)\.env(?:\..*)?$", re.I),
        re.compile(r"(^|/)(credentials|secrets)\.(?:json|ya?ml|toml|ini)$", re.I),
        re.compile(r"(^|/)id_(?:rsa|ed25519|ecdsa|dsa)(?:\..*)?$", re.I),
        re.compile(r"\.(?:pem|key|p12|pfx|jks|keystore)$", re.I),
    ]
    return "sensitive-filename" if any(p.search(normalized) for p in checks) else None


def looks_like_placeholder(data: bytes, match: re.Match[bytes]) -> bool:
    start = max(0, match.start() - 40)
    end = min(len(data), match.end() + 40)
    context = data[start:end].lower()
    markers = (
        b"example",
        b"placeholder",
        b"redacted",
        b"dummy",
        b"sample",
        b"your_",
        b"change_me",
        b"changeme",
    )
    return any(marker in context for marker in markers)


def write_report(path: str | None, payload: dict) -> None:
    if not path:
        return
    Path(path).write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ulaşılabilir tüm Git bloblarında secret/credential denetimi yapar."
    )
    parser.add_argument(
        "--report",
        help="Secret değerlerini içermeyen JSON özet raporunun yazılacağı yol.",
    )
    args = parser.parse_args()

    try:
        objects = reachable_objects()
        unique_paths: dict[str, set[str]] = {}
        for oid, path in objects:
            if path:
                unique_paths.setdefault(oid, set()).add(path)
            else:
                unique_paths.setdefault(oid, set())

        metadata = object_metadata(list(unique_paths))
        content_patterns = build_content_patterns()

        findings: set[Finding] = set()
        blobs_scanned = 0
        bytes_scanned = 0
        large_blobs_skipped = 0

        for oid, paths in unique_paths.items():
            obj_type, size = metadata.get(oid, ("", 0))
            if obj_type != "blob":
                continue

            display_paths = sorted(paths) or ["<path-bilinmiyor>"]
            for path in display_paths:
                risk = path_risk(path)
                if risk:
                    findings.add(Finding(risk, oid, path))

            if size > MAX_BLOB_BYTES:
                large_blobs_skipped += 1
                for path in display_paths:
                    findings.add(Finding("large-blob-not-content-scanned", oid, path))
                continue

            data = run_git("cat-file", "blob", oid)
            blobs_scanned += 1
            bytes_scanned += len(data)

            for risk, pattern in content_patterns:
                match = pattern.search(data)
                if match is None:
                    continue
                if risk == "credential-assignment" and looks_like_placeholder(data, match):
                    continue
                for path in display_paths:
                    findings.add(Finding(risk, oid, path))

        ordered_findings = sorted(findings, key=lambda x: (x.risk, x.path, x.oid))
        report = {
            "schema_version": 1,
            "status": "fail" if ordered_findings else "pass",
            "blobs_scanned": blobs_scanned,
            "bytes_scanned": bytes_scanned,
            "large_blobs_skipped": large_blobs_skipped,
            "findings": [
                {"risk": item.risk, "object": item.oid, "path": item.path}
                for item in ordered_findings
            ],
        }
        write_report(args.report, report)

        print(
            "Git history audit özeti: "
            f"blob={blobs_scanned}, bytes={bytes_scanned}, "
            f"large_skipped={large_blobs_skipped}, finding={len(ordered_findings)}"
        )

        if ordered_findings:
            for finding in ordered_findings:
                # Secret değerini asla loglama.
                print(
                    f"::error file={finding.path}::"
                    f"Git geçmişi riski={finding.risk}; object={finding.oid}"
                )
            return 1

        print("DynaElastomerSolver full reachable Git history secret audit: PASS")
        return 0

    except Exception as exc:
        write_report(
            args.report,
            {
                "schema_version": 1,
                "status": "error",
                "error_class": type(exc).__name__,
            },
        )
        print(f"::error::Git history audit çalıştırılamadı: {exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
