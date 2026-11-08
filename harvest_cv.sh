#!/usr/bin/env bash
# ==============================================================================
# Vltimate CV v4.0 — Open-Core Technical Intelligence & ATS Resume Engine
# Usage: vltimate-cv [OPTIONS]
# ==============================================================================

set -euo pipefail
ORIG_ARGS=("$@")

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DEFAULT_CONFIG_DIR="${SCRIPT_DIR}/config"
if [[ -n "${VLTIMATE_HOME:-}" ]]; then
    DATA_DIR="${VLTIMATE_HOME}"
elif [[ -w "${SCRIPT_DIR}" ]]; then
    DATA_DIR="${SCRIPT_DIR}"
else
    DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/vltimate-cv"
fi

INPUT_DIR="${DATA_DIR}/input"
OUTPUT_DIR="${DATA_DIR}/output"
ARCHIVE_DIR="${DATA_DIR}/archives"
LOCAL_PREVIEW_DIR="${DATA_DIR}/local_preview"
LOG_DIR="${DATA_DIR}/logs"
CONFIG_DIR="${DATA_DIR}/config"
CONFIG_FILE="${CONFIG_DIR}/vltimate_config.env"
PDF_CUSTOM_FILE="${CONFIG_DIR}/pdf_customization.json"
USER_CONSTRAINTS_FILE="${CONFIG_DIR}/user_constraints.md"
CHECKPOINT_FILE="${CONFIG_DIR}/checkpoint.json"
DIFF_LOG_FILE="${DATA_DIR}/harvest_diff.log"
AUDIT_FILE="${CONFIG_DIR}/conflict_audit.json"
VAULT_KEY_FILE="${CONFIG_DIR}/vault_key.txt"
CLOUD_TOKEN_FILE="${CONFIG_DIR}/cloud_token.json"
VAULT_DIR="${DATA_DIR}/.vault_tmp"

SYSTEM_PROMPT_FILE="${SCRIPT_DIR}/cv_harvester_system_prompt.md"
TEMPLATE_FILE="${SCRIPT_DIR}/cv_template.html"
EXPORT_SCRIPT="${SCRIPT_DIR}/scripts/export_profile.py"
LLM_ADAPTER="${SCRIPT_DIR}/scripts/llm_adapter.py"

OUTPUT_PROFILE="${OUTPUT_DIR}/raw_technical_profile.md"
INPUT_PROFILE="${INPUT_DIR}/raw_technical_profile.md"
OUTPUT_CV_HTML="${OUTPUT_DIR}/cv.html"
SANITIZED_JSON="${OUTPUT_DIR}/profile_sanitized.json"
SANITIZED_TOON="${OUTPUT_DIR}/profile_sanitized.toon"

ENCRYPTED_ARCHIVE="${DATA_DIR}/personal_data.tar.gz.enc"
PLAIN_ARCHIVE="${DATA_DIR}/personal_data.tar.gz"

# ANSI Palette
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_CYAN='\033[38;2;91;206;250m'
C_PINK='\033[38;2;245;169;184m'
C_MAGENTA='\033[38;2;255;102;204m'
C_VIOLET='\033[38;2;170;85;255m'
C_GREEN='\033[38;2;80;250;123m'
C_GOLD='\033[38;2;255;184;108m'
C_RED='\033[38;2;255;85;85m'

unset GITHUB_USER GITHUB_TOKEN VAULT_REPO USE_SIMPLE_GLYPHS CLOUD_SYNC_ENABLED \
      ENCRYPT_PASS ENCRYPT_PASS1 ENCRYPT_PASS2 DECRYPT_PASS LLM_PROVIDER LLM_MODEL \
      CLOUD_STUDIO_URL VERBOSE TAILOR_TARGET FORCE_PDF ENABLE_DIFF INTERACTIVE_LOOP \
      ENCRYPT_MODE OPEN_GUI RECONFIG ONLY_VIEW VIEW_DB VIEW_LOG EXPORT_PROFILE \
      PUSH_TO_STUDIO LICENSE_KEY LAYOUT_MODE MANUAL_SOURCES 2>/dev/null || true

cleanup_secrets() {
    unset GITHUB_TOKEN DECRYPT_PASS ENCRYPT_PASS ENCRYPT_PASS1 ENCRYPT_PASS2 \
          GH_TOKEN VAULT_PAT GEMINI_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY VULTIMATE_TOKEN 2>/dev/null || true
}
trap cleanup_secrets EXIT INT TERM

# Defaults
GITHUB_USER=""
GITHUB_TOKEN=""
CLOUD_SYNC_ENABLED="false"
VAULT_REPO="vltimate-cv-vault"
LLM_PROVIDER="agy"
LLM_MODEL=""
CLOUD_STUDIO_URL=""
USE_SIMPLE_GLYPHS=""

VERBOSE="false"
TAILOR_TARGET=""
FORCE_PDF="false"
ENABLE_DIFF="false"
INTERACTIVE_LOOP="true"
ENCRYPT_MODE="aes"
OPEN_GUI="false"
RECONFIG="false"
ONLY_VIEW="false"
VIEW_DB="false"
VIEW_LOG="false"
EXPORT_PROFILE="false"
PUSH_TO_STUDIO="false"
LICENSE_KEY=""
LAYOUT_MODE="ats"
MANUAL_SOURCES=()

# Detect Chromium-compatible browser dynamically
CHROME_BIN=""
for bin in google-chrome-stable google-chrome chromium chromium-browser brave brave-browser; do
    if command -v "${bin}" &>/dev/null; then
        CHROME_BIN="${bin}"
        break
    fi
done

# Auto-detect GitHub username if available
detect_github_user() {
    if [[ -n "${GITHUB_USER:-}" ]]; then
        return 0
    fi
    if command -v gh &>/dev/null; then
        GITHUB_USER="$(gh api user --jq .login 2>/dev/null || echo '')"
    fi
    if [[ -z "${GITHUB_USER:-}" ]]; then
        GITHUB_USER="$(git config --global github.user 2>/dev/null || echo '')"
    fi
}

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi

save_config() {
    mkdir -p "${CONFIG_DIR}"
    install -m 600 /dev/null "${CONFIG_FILE}"
    cat <<EOF > "${CONFIG_FILE}"
CLOUD_SYNC_ENABLED="${CLOUD_SYNC_ENABLED}"
GITHUB_USER="${GITHUB_USER}"
GITHUB_TOKEN="${GITHUB_TOKEN}"
VAULT_REPO="${VAULT_REPO}"
LLM_PROVIDER="${LLM_PROVIDER}"
LLM_MODEL="${LLM_MODEL}"
CLOUD_STUDIO_URL="${CLOUD_STUDIO_URL}"
USE_SIMPLE_GLYPHS="${USE_SIMPLE_GLYPHS}"
EOF
    chmod 600 "${CONFIG_FILE}"
}

init_glyphs() {
    if [[ "${USE_SIMPLE_GLYPHS}" == "true" ]]; then
        G_BANNER="✦"
        G_INFO="ℹ"
        G_WARN="▲"
        G_ERR="✘"
        G_DIAMOND="◈"
        G_STAR="✦"
        G_KEY="🗝"
        G_LOCK="◆"
        G_GUI="❖"
        G_DOC="📄"
        G_CHECK="✔"
        G_CROSS="✘"
    else
        G_BANNER="🌌"
        G_INFO="ℹ️"
        G_WARN="⚠️"
        G_ERR="❌"
        G_DIAMOND="💎"
        G_STAR="✨"
        G_KEY="🔑"
        G_LOCK="🔒"
        G_GUI="🎨"
        G_DOC="📜"
        G_CHECK="✔"
        G_CROSS="✘"
    fi
}
init_glyphs

mkdir -p "${LOG_DIR}" "${CONFIG_DIR}"
if [[ "${CONFIG_DIR}" != "${DEFAULT_CONFIG_DIR}" && -d "${DEFAULT_CONFIG_DIR}" ]]; then
    for tmpl in "${DEFAULT_CONFIG_DIR}"/*.template.*; do
        [[ -f "${tmpl}" ]] || continue
        base_tmpl="$(basename "${tmpl}")"
        if [[ ! -f "${CONFIG_DIR}/${base_tmpl}" ]]; then
            cp -f "${tmpl}" "${CONFIG_DIR}/${base_tmpl}" 2>/dev/null || true
        fi
    done
fi
LOG_FILE="${LOG_DIR}/harvest_$(date +'%Y-%m-%d_%H%M%S').log"

print_banner() {
    echo -e "${C_CYAN}┌────────────────────────────────────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_CYAN}│  ${C_BOLD}${C_MAGENTA}${G_BANNER} VLTIMATE CV v4.0${C_RESET}${C_CYAN} — Proof-of-Work Technical & ATS Resume Engine     │${C_RESET}"
    echo -e "${C_CYAN}│  ${C_PINK}Open-Core Harvester • Strict ATS PDFs • Zero-Trust Export${C_RESET}${C_CYAN}            │${C_RESET}"
    echo -e "${C_CYAN}└────────────────────────────────────────────────────────────────────────┘${C_RESET}"
}

sanitize_log_msg() {
    local msg="$*"
    msg="$(echo "${msg}" | sed -E 's/(github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]+|AIza[0-9A-Za-z_-]+|sk-[A-Za-z0-9_-]+)/[REDACTED_SECRET]/g')"
    echo "${msg}"
}

log_info() {
    local timestamp clean_msg
    timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    clean_msg="$(sanitize_log_msg "$*")"
    echo "[${timestamp}] ${G_INFO}  ${clean_msg}" >> "${LOG_FILE}"
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${C_DIM}[${timestamp}]${C_RESET} ${C_CYAN}${G_INFO}  ${clean_msg}${C_RESET}"
    else
        echo -e "${C_CYAN}${G_INFO}  ${clean_msg}${C_RESET}"
    fi
}

log_warn() {
    local timestamp clean_msg
    timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    clean_msg="$(sanitize_log_msg "$*")"
    echo "[${timestamp}] ${G_WARN}  ${clean_msg}" >> "${LOG_FILE}"
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${C_DIM}[${timestamp}]${C_RESET} ${C_GOLD}${G_WARN}  ${clean_msg}${C_RESET}"
    else
        echo -e "${C_GOLD}${G_WARN}  ${clean_msg}${C_RESET}"
    fi
}

log_err() {
    local timestamp clean_msg
    timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    clean_msg="$(sanitize_log_msg "$*")"
    echo "[${timestamp}] ${G_ERR} ${clean_msg}" >> "${LOG_FILE}"
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${C_DIM}[${timestamp}]${C_RESET} ${C_RED}${G_ERR} ${clean_msg}${C_RESET}" >&2
    else
        echo -e "${C_RED}${G_ERR} ${clean_msg}${C_RESET}" >&2
    fi
}

read_secret() {
    local prompt="$1"
    local input=""
    local char=""

    tput civis >&2 2>/dev/null || true
    printf "%b" "${C_MAGENTA}${prompt}${C_RESET}" >&2

    while IFS= read -r -s -n1 char; do
        if [[ -z "$char" ]]; then
            break
        elif [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ -n "$input" ]]; then
                input="${input%?}"
                printf "\b \b" >&2
            fi
        else
            input+="$char"
            printf "${C_PINK}*${C_RESET}" >&2
        fi
    done

    tput cnorm >&2 2>/dev/null || true
    echo "" >&2
    echo "$input"
}

save_checkpoint() {
    local state="$1"
    cat <<EOF > "${CHECKPOINT_FILE}"
{
  "state": "${state}",
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "data_dir": "${DATA_DIR}"
}
EOF
}

clear_checkpoint() {
    rm -f "${CHECKPOINT_FILE}" "${AUDIT_FILE}"
}

invoke_llm() {
    local prompt_text="$1"
    local out_file="${2:-}"
    local prompt_tmp
    prompt_tmp="$(mktemp)"
    printf "%s" "${prompt_text}" > "${prompt_tmp}"

    local rc=0
    if [[ "${LLM_PROVIDER}" == "agy" ]]; then
        if ! command -v agy &>/dev/null; then
            log_err "'agy' CLI not found. Specify --provider gemini|openai|anthropic|ollama."
            rm -f "${prompt_tmp}"
            return 1
        fi
        agy --dangerously-skip-permissions --print "$(cat "${prompt_tmp}")" >> "${LOG_FILE}" 2>&1 || rc=$?
    else
        local cmd=(python3 "${LLM_ADAPTER}" --provider "${LLM_PROVIDER}" --prompt-file "${prompt_tmp}")
        if [[ -n "${LLM_MODEL:-}" ]]; then
            cmd+=(--model "${LLM_MODEL}")
        fi
        if [[ -n "${out_file}" ]]; then
            cmd+=(--out "${out_file}")
        fi
        "${cmd[@]}" >> "${LOG_FILE}" 2>&1 || rc=$?
    fi

    rm -f "${prompt_tmp}"
    return "${rc}"
}

show_help() {
    print_banner
    echo -e "\n${C_BOLD}USAGE:${C_RESET}"
    echo -e "  vltimate-cv [OPTIONS]\n"
    echo -e "${C_BOLD}OPTIONS:${C_RESET}"
    echo -e "  ${C_CYAN}-h, --help${C_RESET}                  Show help documentation"
    echo -e "  ${C_CYAN}-v, --verbose${C_RESET}               Print ISO timestamps & detailed trace"
    echo -e "  ${C_CYAN}-l, --log${C_RESET}                   View the latest execution log in terminal"
    echo -e "  ${C_CYAN}-k, --db, --knowledge${C_RESET}       View synced technical profile database"
    echo -e "  ${C_CYAN}-a, --add-source <TARGET>${C_RESET}   Add custom scrapable path, URL, or note"
    echo -e "  ${C_CYAN}--provider <NAME>${C_RESET}           LLM backend: agy (default), gemini, openai, anthropic, ollama"
    echo -e "  ${C_CYAN}--model <MODEL>${C_RESET}             Override LLM model identifier"
    echo -e "  ${C_CYAN}--layout <MODE>${C_RESET}             PDF/HTML layout: ats (default, 1-col) or moderncv"
    echo -e "  ${C_CYAN}--export-profile${C_RESET}            Export secret-scrubbed JSON & TOON profile"
    echo -e "  ${C_CYAN}--push <STUDIO_URL>${C_RESET}         Export & sync sanitized profile to Vltimate Studio"
    echo -e "  ${C_CYAN}--license-key <KEY>${C_RESET}         Validate & save Pro license key (Lemon Squeezy)"
    echo -e "  ${C_CYAN}--simple-glyphs${C_RESET}             Force single-width fallback glyphs"
    echo -e "  ${C_CYAN}--rich-glyphs${C_RESET}               Force color emojis"
    echo -e "  ${C_CYAN}--view${C_RESET}                      Open local preview HTML resume in browser"
    echo -e "  ${C_CYAN}-t, --tailor <FILE|URL>${C_RESET}     Tailor summary & bullets to a Job Description"
    echo -e "  ${C_CYAN}-p, --pdf${C_RESET}                   Render headless PDF exports (EN & PL)"
    echo -e "  ${C_CYAN}-d, --diff${C_RESET}                  Generate visual experience diff log"
    echo -e "  ${C_CYAN}-i, --interactive${C_RESET}           Enable interactive refinement loop"
    echo -e "  ${C_CYAN}-e, --encrypt-mode <TYPE>${C_RESET}   Encryption backend: aes (default) or gpg"
    echo -e "  ${C_CYAN}--gui${C_RESET}                       Open customization GUI in browser"
    echo -e "  ${C_CYAN}-c, --config${C_RESET}                Reconfigure GitHub user, provider & cloud vault"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -l|--log) VIEW_LOG="true"; shift ;;
        -k|--db|--knowledge) VIEW_DB="true"; shift ;;
        -a|--add-source) MANUAL_SOURCES+=("$2"); shift 2 ;;
        --provider) LLM_PROVIDER="$2"; shift 2 ;;
        --model) LLM_MODEL="$2"; shift 2 ;;
        --layout) LAYOUT_MODE="$2"; shift 2 ;;
        --export-profile) EXPORT_PROFILE="true"; shift ;;
        --push) PUSH_TO_STUDIO="true"; CLOUD_STUDIO_URL="$2"; EXPORT_PROFILE="true"; shift 2 ;;
        --license-key) LICENSE_KEY="$2"; shift 2 ;;
        --simple-glyphs) USE_SIMPLE_GLYPHS="true"; save_config; init_glyphs; shift ;;
        --rich-glyphs) USE_SIMPLE_GLYPHS="false"; save_config; init_glyphs; shift ;;
        --view) ONLY_VIEW="true"; shift ;;
        -t|--tailor) TAILOR_TARGET="$2"; shift 2 ;;
        -p|--pdf) FORCE_PDF="true"; shift ;;
        -d|--diff) ENABLE_DIFF="true"; shift ;;
        -i|--interactive) INTERACTIVE_LOOP="true"; shift ;;
        -e|--encrypt-mode) ENCRYPT_MODE="$2"; shift 2 ;;
        --gui) OPEN_GUI="true"; shift ;;
        -c|--config) RECONFIG="true"; shift ;;
        *) log_err "Unknown option: $1"; show_help ;;
    esac
done

# Validate & cache Lemon Squeezy license key if passed
if [[ -n "${LICENSE_KEY}" ]]; then
    log_info "Validating license key with Lemon Squeezy..."
    if python3 - "${SCRIPT_DIR}/scripts" "${LICENSE_KEY}" "${CLOUD_TOKEN_FILE}" <<'PYEOF'
import json, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from export_profile import validate_license_key
key = sys.argv[2]
out_path = Path(sys.argv[3])
res = validate_license_key(key)
if not res.get("valid"):
    sys.exit(1)
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(json.dumps({"license_key": key, "meta": res}, indent=2), encoding="utf-8")
PYEOF
    then
        chmod 600 "${CLOUD_TOKEN_FILE}"
        log_info "${G_CHECK} Pro license key verified and saved to '${CLOUD_TOKEN_FILE}'."
        exit 0
    else
        log_err "License key validation failed."
        exit 1
    fi
fi

if [[ "${VIEW_LOG}" == "true" ]]; then
    LATEST_LOG="$(ls -t "${LOG_DIR}"/harvest_*.log 2>/dev/null | head -n 1 || echo '')"
    if [[ -n "${LATEST_LOG}" && -f "${LATEST_LOG}" ]]; then
        less -R "${LATEST_LOG}"
    else
        log_err "No log files found in '${LOG_DIR}'."
    fi
    exit 0
fi

if [[ "${VIEW_DB}" == "true" ]]; then
    DB_TARGET=""
    if [[ -f "${OUTPUT_PROFILE}" ]]; then
        DB_TARGET="${OUTPUT_PROFILE}"
    elif [[ -f "${INPUT_PROFILE}" ]]; then
        DB_TARGET="${INPUT_PROFILE}"
    elif [[ -f "${LOCAL_PREVIEW_DIR}/raw_technical_profile.md" ]]; then
        DB_TARGET="${LOCAL_PREVIEW_DIR}/raw_technical_profile.md"
    fi
    if [[ -n "${DB_TARGET}" ]]; then
        less -R "${DB_TARGET}"
    else
        log_err "No technical knowledge database found. Run vltimate-cv first."
    fi
    exit 0
fi

if [[ "${ONLY_VIEW}" == "true" ]]; then
    if [[ -f "${LOCAL_PREVIEW_DIR}/cv.html" ]]; then
        if [[ -n "${CHROME_BIN}" ]]; then
            "${CHROME_BIN}" "file://${LOCAL_PREVIEW_DIR}/cv.html?layout=${LAYOUT_MODE}" &>/dev/null &
        elif command -v xdg-open &>/dev/null; then
            xdg-open "file://${LOCAL_PREVIEW_DIR}/cv.html" &>/dev/null &
        fi
    else
        log_err "No preview found at './local_preview/cv.html'. Run vltimate-cv first."
    fi
    exit 0
fi

# Direct sanitized JSON/TOON export & optional Cloud Studio sync
if [[ "${EXPORT_PROFILE}" == "true" ]]; then
    SRC_PROFILE=""
    for candidate in "${OUTPUT_PROFILE}" "${INPUT_PROFILE}" "${LOCAL_PREVIEW_DIR}/raw_technical_profile.md"; do
        if [[ -f "${candidate}" ]]; then
            SRC_PROFILE="${candidate}"
            break
        fi
    done
    if [[ -z "${SRC_PROFILE}" ]]; then
        log_err "No raw_technical_profile.md found to export."
        exit 1
    fi
    mkdir -p "${OUTPUT_DIR}"
    EXPORT_ARGS=(python3 "${EXPORT_SCRIPT}" --input "${SRC_PROFILE}" --out-json "${SANITIZED_JSON}" --out-toon "${SANITIZED_TOON}")
    if [[ "${PUSH_TO_STUDIO}" == "true" && -n "${CLOUD_STUDIO_URL}" ]]; then
        TOKEN_VAL="${VULTIMATE_TOKEN:-}"
        if [[ -z "${TOKEN_VAL}" && -f "${CLOUD_TOKEN_FILE}" ]]; then
            TOKEN_VAL="$(python3 - "${CLOUD_TOKEN_FILE}" <<'PYEOF' 2>/dev/null || echo ''
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    print(json.load(f).get("license_key", ""))
PYEOF
)"
        fi
        EXPORT_ARGS+=(--push-url "${CLOUD_STUDIO_URL}" --token "${TOKEN_VAL}")
    fi
    "${EXPORT_ARGS[@]}"
    log_info "${G_CHECK} Exported redacted profile JSON & TOON cleanly."
    exit 0
fi

print_banner
detect_github_user
mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}" "${ARCHIVE_DIR}" "${LOCAL_PREVIEW_DIR}"

if [[ "${RECONFIG}" == "true" || ! -f "${CONFIG_FILE}" ]]; then
    if [[ -t 0 ]]; then
        read -r -p "👤 Enter GitHub username (detected: ${GITHUB_USER:-none}): " INPUT_GH_USER || INPUT_GH_USER=""
        if [[ -n "${INPUT_GH_USER}" ]]; then
            GITHUB_USER="${INPUT_GH_USER}"
        fi
        read -r -p "🤖 LLM provider [agy/gemini/openai/anthropic/ollama] (default: ${LLM_PROVIDER}): " INPUT_PROV || INPUT_PROV=""
        if [[ -n "${INPUT_PROV}" ]]; then
            LLM_PROVIDER="${INPUT_PROV}"
        fi
        read -r -p "⚡ Enable encrypted private GitHub vault sync? [y/N]: " SYNC_PROMPT || SYNC_PROMPT="n"
        if [[ "${SYNC_PROMPT}" =~ ^[Yy](es)?$ ]]; then
            CLOUD_SYNC_ENABLED="true"
            if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
                GITHUB_TOKEN="$(read_secret "${G_KEY} Enter fine-grained GitHub PAT: ")"
            fi
        fi
        save_config
    fi
fi

# Decrypt vault if encrypted archive exists
if [[ -f "${ENCRYPTED_ARCHIVE}" ]]; then
    log_info "Encrypted archive detected: './personal_data.tar.gz.enc'"
    while true; do
        if [[ -z "${DECRYPT_PASS:-}" && -f "${VAULT_KEY_FILE}" ]]; then
            DECRYPT_PASS="$(cat "${VAULT_KEY_FILE}")"
        elif [[ -z "${DECRYPT_PASS:-}" ]]; then
            DECRYPT_PASS="$(read_secret "${G_KEY} Enter decryption password: ")"
        fi
        TEMP_TAR="$(mktemp --suffix=.tar.gz)"
        if openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "${ENCRYPTED_ARCHIVE}" -out "${TEMP_TAR}" -pass pass:"${DECRYPT_PASS}" 2>/dev/null; then
            tar -xzf "${TEMP_TAR}" -C "${DATA_DIR}"
            rm -f "${TEMP_TAR}"
            install -m 600 /dev/null "${VAULT_KEY_FILE}"
            printf "%s" "${DECRYPT_PASS}" > "${VAULT_KEY_FILE}"
            break
        elif gpg --decrypt --batch --passphrase "${DECRYPT_PASS}" "${ENCRYPTED_ARCHIVE}" > "${TEMP_TAR}" 2>/dev/null; then
            tar -xzf "${TEMP_TAR}" -C "${DATA_DIR}"
            rm -f "${TEMP_TAR}"
            install -m 600 /dev/null "${VAULT_KEY_FILE}"
            printf "%s" "${DECRYPT_PASS}" > "${VAULT_KEY_FILE}"
            break
        else
            log_err "Decryption failed."
            rm -f "${TEMP_TAR}" "${VAULT_KEY_FILE}"
            unset DECRYPT_PASS
        fi
    done
fi

# Snapshot prior output before harvest
if [[ -f "${OUTPUT_PROFILE}" || -f "${INPUT_PROFILE}" ]]; then
    TIMESTAMP="$(date +'%Y-%m-%d_%H%M%S')"
    tar -czf "${ARCHIVE_DIR}/snapshot_${TIMESTAMP}.tar.gz" -C "${DATA_DIR}" "input" "output" 2>/dev/null || true
    cp -rf "${OUTPUT_DIR}"/* "${INPUT_DIR}/" 2>/dev/null || true
fi

# Execute LLM Harvest
if [[ ! -f "${SYSTEM_PROMPT_FILE}" ]]; then
    log_err "Missing system prompt: '${SYSTEM_PROMPT_FILE}'"
    exit 1
fi

HARVEST_PROMPT="Read '${SYSTEM_PROMPT_FILE}' and '${TEMPLATE_FILE}'."
if [[ -f "${USER_CONSTRAINTS_FILE}" ]]; then
    HARVEST_PROMPT="${HARVEST_PROMPT} Apply personal constraints from '${USER_CONSTRAINTS_FILE}'."
fi
if [[ -f "${INPUT_PROFILE}" ]]; then
    HARVEST_PROMPT="${HARVEST_PROMPT} Merge previous baseline from '${INPUT_PROFILE}'."
fi
if [[ -n "${GITHUB_USER:-}" ]]; then
    HARVEST_PROMPT="${HARVEST_PROMPT} Candidate GitHub handle: '${GITHUB_USER}'."
fi
if [[ -n "${TAILOR_TARGET}" ]]; then
    JD_FILE="${INPUT_DIR}/job_description.txt"
    if [[ -f "${TAILOR_TARGET}" ]]; then
        cp -f "${TAILOR_TARGET}" "${JD_FILE}"
    else
        curl -sL "${TAILOR_TARGET}" > "${JD_FILE}" || echo "${TAILOR_TARGET}" > "${JD_FILE}"
    fi
    HARVEST_PROMPT="${HARVEST_PROMPT} Read JD file '${JD_FILE}' and tailor summary, skills, and STAR-K bullets to match it."
fi
if [[ ${#MANUAL_SOURCES[@]} -gt 0 ]]; then
    HARVEST_PROMPT="${HARVEST_PROMPT} Extra user targets: ${MANUAL_SOURCES[*]}."
fi
HARVEST_PROMPT="${HARVEST_PROMPT} Save knowledge base to '${OUTPUT_PROFILE}' and bilingual HTML CV to '${OUTPUT_CV_HTML}'."

log_info "Running intelligence harvest using provider '${LLM_PROVIDER}'..."
save_checkpoint "STATE_HARVEST_STARTED"
if invoke_llm "${HARVEST_PROMPT}"; then
    save_checkpoint "STATE_HARVEST_COMPLETED"
else
    log_warn "Harvest finished with non-zero exit or provider unavailable; continuing if output exists."
fi

# Render PDFs if HTML exists and browser available
if [[ -f "${OUTPUT_CV_HTML}" && ( "${FORCE_PDF}" == "true" || -n "${CHROME_BIN}" ) ]]; then
    if [[ -n "${CHROME_BIN}" ]]; then
        log_info "Rendering headless PDFs (${LAYOUT_MODE} layout)..."
        "${CHROME_BIN}" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="${OUTPUT_DIR}/cv_en.pdf" "file://${OUTPUT_CV_HTML}?printLang=en&layout=${LAYOUT_MODE}" &>/dev/null || true
        "${CHROME_BIN}" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="${OUTPUT_DIR}/cv_pl.pdf" "file://${OUTPUT_CV_HTML}?printLang=pl&layout=${LAYOUT_MODE}" &>/dev/null || true
    fi
    mkdir -p "${LOCAL_PREVIEW_DIR}"
    cp -f "${OUTPUT_DIR}"/* "${LOCAL_PREVIEW_DIR}/" 2>/dev/null || true
    log_info "${G_CHECK} Outputs saved to './output/' and './local_preview/'."
fi

# Optional zero-trust export after harvest
if [[ -f "${OUTPUT_PROFILE}" ]]; then
    python3 "${EXPORT_SCRIPT}" --input "${OUTPUT_PROFILE}" --out-json "${SANITIZED_JSON}" --out-toon "${SANITIZED_TOON}" >/dev/null || true
fi

if [[ "${ENABLE_DIFF}" == "true" && -f "${INPUT_PROFILE}" && -f "${OUTPUT_PROFILE}" ]]; then
    diff -u "${INPUT_PROFILE}" "${OUTPUT_PROFILE}" > "${DIFF_LOG_FILE}" || true
fi

clear_checkpoint
if [[ "${OPEN_GUI}" == "true" ]]; then
    GUI_TARGET="${LOCAL_PREVIEW_DIR}/cv.html"
    [[ -f "${GUI_TARGET}" ]] || GUI_TARGET="${TEMPLATE_FILE}"
    if [[ -n "${CHROME_BIN}" ]]; then
        "${CHROME_BIN}" "file://${GUI_TARGET}?layout=${LAYOUT_MODE}" &>/dev/null &
    elif command -v xdg-open &>/dev/null; then
        xdg-open "file://${GUI_TARGET}" &>/dev/null &
    fi
fi
log_info "Vltimate CV v4.0 workflow complete."
