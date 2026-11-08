#!/usr/bin/env python3
"""
Vltimate CV - Provider-Agnostic BYOK LLM Adapter (stdlib only).
Supports: gemini, openai, anthropic, ollama.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request


def call_gemini(prompt: str, model: str, api_key: str) -> str:
    model_id = model or "gemini-2.5-flash"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_id}:generateContent?key={api_key}"
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    candidates = data.get("candidates", [])
    if not candidates:
        raise RuntimeError(f"Gemini returned no candidates: {data}")
    parts = candidates[0].get("content", {}).get("parts", [])
    return "".join(p.get("text", "") for p in parts)


def call_openai(prompt: str, model: str, api_key: str) -> str:
    model_id = model or "gpt-4o-mini"
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]


def call_anthropic(prompt: str, model: str, api_key: str) -> str:
    model_id = model or "claude-3-5-sonnet-latest"
    payload = {
        "model": model_id,
        "max_tokens": 8192,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return "".join(block.get("text", "") for block in data.get("content", []))


def call_ollama(prompt: str, model: str, host: str) -> str:
    base = (host or "http://127.0.0.1:11434").rstrip("/")
    model_id = model or "llama3.1"
    payload = {"model": model_id, "prompt": prompt, "stream": False}
    req = urllib.request.Request(
        f"{base}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data.get("response", "")


def main() -> int:
    parser = argparse.ArgumentParser(description="BYOK LLM adapter for Vltimate CV")
    parser.add_argument("--provider", required=True, choices=["gemini", "openai", "anthropic", "ollama"])
    parser.add_argument("--model", default="")
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--out", help="Optional output file")
    args = parser.parse_args()

    with open(args.prompt_file, "r", encoding="utf-8") as f:
        prompt = f.read()

    try:
        if args.provider == "gemini":
            key = os.environ.get("GEMINI_API_KEY", "")
            if not key:
                raise RuntimeError("GEMINI_API_KEY is not set")
            text = call_gemini(prompt, args.model, key)
        elif args.provider == "openai":
            key = os.environ.get("OPENAI_API_KEY", "")
            if not key:
                raise RuntimeError("OPENAI_API_KEY is not set")
            text = call_openai(prompt, args.model, key)
        elif args.provider == "anthropic":
            key = os.environ.get("ANTHROPIC_API_KEY", "")
            if not key:
                raise RuntimeError("ANTHROPIC_API_KEY is not set")
            text = call_anthropic(prompt, args.model, key)
        else:
            host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
            text = call_ollama(prompt, args.model, host)
    except urllib.error.HTTPError as exc:
        print(f"LLM API HTTP {exc.code}: {exc.read().decode('utf-8', errors='replace')}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"LLM error: {exc}", file=sys.stderr)
        return 1

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
