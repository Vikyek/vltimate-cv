#!/usr/bin/env python3
"""
Vltimate CV - Zero-Trust Profile Redactor, Structured JSON/TOON Exporter, and Cloud Sync Bridge.
Uses Python stdlib only, with optional TOON compression when toon-mcp is installed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

SECRET_PATTERNS: List[Tuple[re.Pattern[str], str]] = [
    (re.compile(r"github_pat_[A-Za-z0-9_]{20,}"), "[REDACTED_GITHUB_PAT]"),
    (re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"), "[REDACTED_GITHUB_TOKEN]"),
    (re.compile(r"AIza[0-9A-Za-z\-_]{30,}"), "[REDACTED_GOOGLE_API_KEY]"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "[REDACTED_AWS_KEY]"),
    (re.compile(r"sk-[A-Za-z0-9\-_]{20,}"), "[REDACTED_API_KEY]"),
    (re.compile(r"(?i)bearer\s+[A-Za-z0-9\-_.~+/]+=*"), "Bearer [REDACTED_TOKEN]"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"), "[REDACTED_PRIVATE_KEY]"),
    (
        re.compile(
            r"(?im)^(\s*(?:export\s+)?[A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|PASS|KEY|AUTH|PAT|CREDENTIAL)[A-Z0-9_]*\s*=\s*)([\"']?)([^\n\"'#]+)\2"
        ),
        r"\1[REDACTED_ENV_VALUE]",
    ),
    (re.compile(r"https?://[^/\s:@]+:[^/\s@]+@"), "https://[REDACTED_CREDENTIALS]@"),
    (re.compile(r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"), "[INTERNAL_IP]"),
]


def redact_text(text: str, home_dir: str | None = None) -> Tuple[str, int]:
    """Scrub secrets, credentials, internal IPs, and local home paths from text."""
    redacted = text
    count = 0
    for pattern, replacement in SECRET_PATTERNS:
        redacted, n = pattern.subn(replacement, redacted)
        count += n

    home = home_dir or str(Path.home())
    if home and home != "/":
        occurrences = redacted.count(home)
        if occurrences:
            redacted = redacted.replace(home, "<HOME>")
            count += occurrences
    return redacted, count


def parse_markdown_sections(md_text: str) -> Dict[str, Any]:
    """Extract structured sections and bullet items from raw_technical_profile.md."""
    sections: Dict[str, List[str]] = {}
    current = "Overview"
    sections[current] = []

    for line in md_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                current = heading
                sections.setdefault(current, [])
        elif stripped:
            sections[current].append(stripped)

    return {
        "schema_version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "content_hash": hashlib.sha256(md_text.encode("utf-8")).hexdigest()[:16],
        "sections": {k: v for k, v in sections.items() if v},
    }


def _import_toon_converter() -> Any | None:
    """Import TOONConverter from installed package or optional sibling workspace."""
    for candidate in ("src.toon_converter", "toon_mcp.toon_converter"):
        try:
            mod = __import__(candidate, fromlist=["TOONConverter"])
            if hasattr(mod, "TOONConverter"):
                return mod.TOONConverter
        except ImportError:
            pass
    env_path = os.environ.get("VLTIMATE_TOON_MCP_PATH", "")
    sibling = Path(env_path) if env_path else Path(__file__).resolve().parents[2] / "toon-mcp"
    if (sibling / "src" / "toon_converter.py").is_file() and str(sibling) not in sys.path:
        sys.path.insert(0, str(sibling))
        try:
            from src.toon_converter import TOONConverter  # type: ignore

            return TOONConverter
        except ImportError:
            return None
    return None


def compress_to_toon(payload: Dict[str, Any]) -> Tuple[str, str]:
    """Compress structured JSON payload using toon-mcp if importable, else compact TOON envelope."""
    converter_cls = _import_toon_converter()
    if converter_cls is not None:
        conv = converter_cls(aggressive=True)
        return conv.json_to_toon(payload), "toon-mcp"

    # Built-in lossless lightweight TOON v1.0 envelope with key abbreviation & schema-encoded lists
    abbrev = {
        "schema_version": "sv",
        "generated_at": "ts",
        "content_hash": "h",
        "sections": "sec",
        "redactions_applied": "red",
        "projects": "prj",
        "name": "n",
        "description": "desc",
        "language": "lang",
        "stars": "st",
        "skills": "sk",
    }

    def _enc(node: Any) -> Any:
        if node is None:
            return "~"
        if isinstance(node, bool):
            return "T" if node else "F"
        if isinstance(node, list):
            if node and all(isinstance(x, dict) for x in node):
                keys = sorted(node[0].keys())
                if all(sorted(x.keys()) == keys for x in node):
                    return {
                        "_sch": [abbrev.get(k, k) for k in keys],
                        "_dat": [[_enc(x[k]) for k in keys] for x in node],
                    }
            return [_enc(x) for x in node]
        if isinstance(node, dict):
            return {abbrev.get(k, k): _enc(v) for k, v in node.items()}
        return node

    return json.dumps({"_toon": "1.0", "d": _enc(payload)}, separators=(",", ":"), ensure_ascii=False), "builtin-compact"


def export_profile(input_path: Path, output_json: Path, output_toon: Path | None = None) -> Dict[str, Any]:
    raw_text = input_path.read_text(encoding="utf-8", errors="replace")
    clean_text, redacted_count = redact_text(raw_text)
    structured = parse_markdown_sections(clean_text)
    structured["redactions_applied"] = redacted_count

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(structured, indent=2, ensure_ascii=False), encoding="utf-8")

    meta: Dict[str, Any] = {
        "json_path": str(output_json),
        "redactions_applied": redacted_count,
        "section_count": len(structured["sections"]),
    }

    if output_toon is not None:
        toon_str, engine = compress_to_toon(structured)
        output_toon.write_text(toon_str, encoding="utf-8")
        json_len = len(json.dumps(structured, ensure_ascii=False))
        meta["toon_path"] = str(output_toon)
        meta["toon_engine"] = engine
        meta["compression_pct"] = round((1.0 - (len(toon_str) / max(json_len, 1))) * 100.0, 1)

    return meta


def push_to_studio(studio_url: str, token: str, payload_path: Path) -> Dict[str, Any]:
    endpoint = studio_url.rstrip("/") + "/api/py/profiles/sync"
    body = payload_path.read_bytes()
    req = urllib.request.Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "vltimate-cv-cli/4.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cloud sync rejected ({exc.code}): {detail}") from exc


def validate_license_key(license_key: str, instance_name: str = "vltimate-cv-cli") -> Dict[str, Any]:
    """Validate Lemon Squeezy license key via official public license endpoint."""
    payload = urllib.parse.urlencode(
        {"license_key": license_key, "instance_name": instance_name}
    ).encode("utf-8")
    req = urllib.request.Request(
        "https://api.lemonsqueezy.com/v1/licenses/validate",
        data=payload,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "vltimate-cv-cli/4.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"License check failed ({exc.code}): {detail}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description="Export and sanitize Vltimate CV profile")
    parser.add_argument("--input", required=True, help="Path to raw_technical_profile.md")
    parser.add_argument("--out-json", required=True, help="Output sanitized JSON path")
    parser.add_argument("--out-toon", help="Optional output TOON path")
    parser.add_argument("--push-url", help="Optional Vltimate Studio base URL")
    parser.add_argument("--token", help="Cloud Studio bearer/license token")
    args = parser.parse_args()

    meta = export_profile(
        Path(args.input),
        Path(args.out_json),
        Path(args.out_toon) if args.out_toon else None,
    )
    print(json.dumps(meta))

    if args.push_url:
        token = args.token or os.environ.get("VULTIMATE_TOKEN", "")
        if not token:
            print("ERROR: Missing cloud token for --push-url", file=sys.stderr)
            return 2
        res = push_to_studio(args.push_url, token, Path(args.out_json))
        print(json.dumps({"cloud_sync": res}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
