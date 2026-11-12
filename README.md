# Vltimate CV

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An open-core, privacy-first **Proof-of-Work Technical Intelligence Harvester & Strict ATS Resume Engine**.

Unlike generic resume wrappers that fabricate buzzwords from blank prompts, **Vltimate CV** scans your real engineering footprint—local git repositories, shell histories, developer registries (`GitHub`, `npm`, `PyPI`), and baseline notes—enforces strict anti-hallucination constraints, and renders linear ATS-verified HTML/PDF resumes with bilingual support (`EN` / `PL`) and GDPR/RODO consent controls.

---

## Key Features

- **Provider-Agnostic BYOK Execution**: Works with `agy`, Gemini API (`GEMINI_API_KEY`), OpenAI (`OPENAI_API_KEY`), Anthropic (`ANTHROPIC_API_KEY`), or local `ollama`.
- **Strict Single-Column ATS Mode + ModernCV Toggle**: Guarantee sequential plain-text extraction order (`--layout ats`) for Workday, Greenhouse, and Taleo parsers, or switch to ModernCV split-margin (`--layout moderncv`).
- **Interactive Browser ATS Pre-Flight Scorecard**: Verify core section headings, missing placeholders, and job description keyword match directly inside `cv_template.html` with zero backend cost.
- **Zero-Trust Secret Redactor & TOON Exporter**: Scrubs tokens (`ghp_`, `github_pat_`, `AIza`, `AKIA`, `sk-`, `.env` assignments, private IPs, and home paths) before exporting JSON or compact `.toon` payloads (`--export-profile`).
- **Private Per-User Constraints (`config/user_constraints.md`)**: Keep excluded experience, localization rules, and personal reference notes isolated and gitignored.
- **Encrypted Local Vault**: Optional AES-256-CBC / GPG archive packing for generated personal artifacts.

---

## Prerequisites

- **Core**: `bash` (4.0+), `python` (3.10+), `git`, `curl`, `openssl`
- **Optional PDF / Encryption**: `chromium` or Chromium-compatible browser, `gnupg`

Install on Arch Linux:
```bash
sudo pacman -S bash python git curl openssl gnupg chromium
```

---

## Installation

### Automated Installation
```bash
git clone https://github.com/your-username/vltimate-cv.git
cd vltimate-cv
chmod +x install.sh
./install.sh
```

### Manual Installation
```bash
mkdir -p ~/.local/bin ~/.local/share/man/man1 ~/.local/share/vltimate-cv
cp -r cv_harvester_system_prompt.md cv_template.html harvest_cv.sh scripts config ~/.local/share/vltimate-cv/
chmod +x ~/.local/share/vltimate-cv/harvest_cv.sh
ln -sf ~/.local/share/vltimate-cv/harvest_cv.sh ~/.local/bin/vltimate-cv
install -Dm644 man/man1/vltimate-cv.1 ~/.local/share/man/man1/vltimate-cv.1
```

### Arch Linux Package (`PKGBUILD`)
```bash
makepkg -si
```

---

## CLI Usage

```text
USAGE:
  vltimate-cv [OPTIONS]

OPTIONS:
  -h, --help                  Show help documentation
  -v, --verbose               Print ISO timestamps & detailed trace
  -l, --log                   View the latest execution log in terminal
  -k, --db, --knowledge       View synced technical profile database
  -a, --add-source <TARGET>   Add custom scrapable path, URL, or note
  --provider <NAME>           LLM backend: agy (default), gemini, openai, anthropic, ollama
  --model <MODEL>             Override LLM model identifier
  --layout <MODE>             PDF/HTML layout: ats (default, 1-col) or moderncv
  --export-profile            Export secret-scrubbed JSON & TOON profile
  --push <STUDIO_URL>         Export & sync sanitized profile to Vltimate Studio
  --license-key <KEY>         Validate & save Pro license key (Lemon Squeezy)
  --simple-glyphs             Force single-width fallback glyphs
  --rich-glyphs               Force color emojis
  --view                      Open local preview HTML resume in browser
  -t, --tailor <FILE|URL>     Tailor summary & bullets to a Job Description
  -p, --pdf                   Render headless PDF exports (EN & PL)
  -d, --diff                  Generate visual experience diff log
  -i, --interactive           Enable interactive refinement loop
  -e, --encrypt-mode <TYPE>   Encryption backend: aes (default) or gpg
  --gui                       Open customization GUI in browser
  -c, --config                Reconfigure GitHub user, provider & cloud vault
```

### Quick Examples
```bash
# Harvest using Gemini free-tier API key and render Strict ATS PDFs
export GEMINI_API_KEY="your-api-key"
vltimate-cv --provider gemini --layout ats -p

# Tailor to a job description and export a redacted JSON/TOON profile
vltimate-cv --provider openai -t job_posting.txt --export-profile
```

---

## Security & Privacy

- All runtime outputs (`input/`, `output/`, `archives/`, `local_preview/`, `logs/`), keys (`config/vault_key.txt`, `config/cloud_token.json`), and personal rule overrides (`config/user_constraints.md`) are strictly excluded via `.gitignore`.
- `--export-profile` runs `scripts/export_profile.py` to scrub API keys, tokens, `.env` secrets, RFC1918 IPs, and `$HOME` paths prior to writing portable outputs.

---

## Verification & Testing

```bash
bash -n harvest_cv.sh install.sh
./harvest_cv.sh --help
pytest -v tests/
namcap PKGBUILD
```


---

## Support & Sponsorship

`vltimate-cv` is authored and maintained by **[Vikyek](https://github.com/Vikyek)** as an independent open-source project. Everything is 100% open-source, telemetry-free, and public.

<div align="center">


[![Sponsor Vikyek](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?logo=github&style=for-the-badge)](https://github.com/sponsors/Vikyek)
[![Donate on Liberapay](https://img.shields.io/badge/Donate-Liberapay-f6c915?style=for-the-badge&logo=liberapay&logoColor=black)](https://liberapay.com/Vikyek)
[![Donate with Stripe](https://img.shields.io/badge/Donate-Stripe-635BFF?style=for-the-badge&logo=stripe&logoColor=white)](https://profile.stripe.com/@vikyek)

</div>

> ### 🎯 Active Sponsorship Goal: Monthly Living Essentials
> **Target:** **2,710 PLN / ~$680 USD per month** (`630 PLN / week`) — Rent & Essential Utilities  
> Covering basic living essentials directly unlocks dedicated, sustainable full-time independent open-source engineering across Arch Linux utilities, developer tools, and AI middleware free from corporate telemetry, ads, or paywalls.

If this project saves you time, optimizes your setup, or accelerates your workflow, consider supporting ongoing work:

- **GitHub Sponsors**: [github.com/sponsors/Vikyek](https://github.com/sponsors/Vikyek) *(Monthly tiers and one-time tips)*
- **Liberapay**: [liberapay.com/Vikyek](https://liberapay.com/Vikyek) *(0% platform fee recurrent patronage in EUR/USD/PLN)*
- **Direct Stripe Profile**: [profile.stripe.com/@vikyek](https://profile.stripe.com/@vikyek) *(Direct one-time tips & sponsorship)*

Every contribution—monthly or one-time—directly supports active maintenance, hardware testbeds, and new feature development!

---

## License

Licensed under the [MIT License](LICENSE).
