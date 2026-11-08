"""Tests for zero-trust secret redaction, markdown export, and TOON compression."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import export_profile  # noqa: E402


def test_redact_text_scrubs_tokens_keys_ips_and_home() -> None:
    sample = "\n".join(
        [
            "GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwx",
            "fine=github_pat_11ABCDEF0123456789_abcdefghijklmnopqrstuv",
            "google=AIzaSyA1234567890123456789012345678901",
            "aws=AKIAIOSFODNN7EXAMPLE",
            "openai=sk-proj-abcdefghijklmnopqrstuvwxyz123456",
            "Authorization: Bearer super_secret_bearer_token_987654",
            "https://deployuser:s3cr3tPass@git.example.com/org/repo.git",
            "host=192.168.10.42 backup=10.20.30.40 internal=172.24.5.6",
            "repo=/home/alice/Projects/secret-app",
            "-----BEGIN RSA PRIVATE KEY-----\nMIIBOgIBAAJBALeakTestMaterial\n-----END RSA PRIVATE KEY-----",
        ]
    )

    cleaned, count = export_profile.redact_text(sample, home_dir="/home/alice")
    assert count >= 10
    for leaked in (
        "ghp_123456",
        "github_pat_11",
        "AIzaSyA",
        "AKIAIOSFODNN7EXAMPLE",
        "sk-proj-",
        "super_secret_bearer_token",
        "s3cr3tPass",
        "192.168.10.42",
        "10.20.30.40",
        "172.24.5.6",
        "/home/alice",
        "MIIBOgIBAAJBALeakTestMaterial",
    ):
        assert leaked not in cleaned
    assert "<HOME>/Projects/secret-app" in cleaned


def test_export_profile_cli_and_toon_compression(tmp_path: Path) -> None:
    md_in = tmp_path / "raw_technical_profile.md"
    md_in.write_text(
        "\n".join(
            [
                "# Summary & Core Domains",
                "- Built distributed Go and Python pipelines at /home/alice/dev.",
                "- Token check AIzaSyA1234567890123456789012345678901.",
                "",
                "# Public Repositories",
                "- repo-alpha: High-throughput indexer",
                "- repo-beta: Zero-trust CLI exporter",
                "",
                "# Languages, Frameworks & Tooling",
                "- Python, TypeScript, Bash, FastAPI, Next.js",
            ]
        ),
        encoding="utf-8",
    )

    out_json = tmp_path / "profile.json"
    out_toon = tmp_path / "profile.toon"

    proc = subprocess.run(
        [
            sys.executable,
            str(ROOT / "scripts" / "export_profile.py"),
            "--input",
            str(md_in),
            "--out-json",
            str(out_json),
            "--out-toon",
            str(out_toon),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    meta = json.loads(proc.stdout.strip())
    assert meta["redactions_applied"] >= 1
    assert meta["section_count"] == 3

    parsed_json = json.loads(out_json.read_text(encoding="utf-8"))
    assert "AIzaSyA" not in out_json.read_text(encoding="utf-8")
    assert parsed_json["redactions_applied"] >= 1

    toon_text = out_toon.read_text(encoding="utf-8")
    toon_obj = json.loads(toon_text)
    assert toon_obj["_toon"] == "1.0"
    assert len(toon_text) < len(out_json.read_text(encoding="utf-8"))
