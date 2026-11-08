"""End-to-end ATS PDF linear reading-order verification using headless Chromium + pdftotext."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "cv_template.html"


def find_browser() -> str | None:
    for name in ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser"):
        found = shutil.which(name)
        if found:
            return found
    return None


@pytest.mark.skipif(
    find_browser() is None or shutil.which("pdftotext") is None,
    reason="Headless Chromium browser and pdftotext are required for PDF ATS verification",
)
def test_strict_ats_mode_preserves_linear_reading_order(tmp_path: Path) -> None:
    browser = find_browser()
    assert browser is not None

    populated = (
        TEMPLATE.read_text(encoding="utf-8")
        .replace("[Candidate Full Name]", "Alex Rivera")
        .replace("[Target Engineering Role]", "Staff Backend Engineer")
        .replace("[Professional summary detailing verified core stack, architectural ownership, and measurable engineering outcomes.]", "Distributed systems engineer building resilient Python and TypeScript platforms.")
        .replace("[Job Title]", "Principal Systems Engineer")
        .replace("[Company Name]", "Northwind Systems")
        .replace("[Degree / Field of Study]", "B.Sc. Computer Science")
        .replace("[Institution Name]", "Warsaw University of Technology")
    )

    html_file = tmp_path / "cv_populated.html"
    pdf_file = tmp_path / "cv_en.pdf"
    html_file.write_text(populated, encoding="utf-8")

    subprocess.run(
        [
            browser,
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--no-pdf-header-footer",
            f"--print-to-pdf={pdf_file}",
            f"file://{html_file}?printLang=en&layout=ats",
        ],
        check=True,
        capture_output=True,
        timeout=30,
    )
    assert pdf_file.is_file() and pdf_file.stat().st_size > 1000

    txt_proc = subprocess.run(
        ["pdftotext", "-raw", str(pdf_file), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    raw_text = txt_proc.stdout
    upper = raw_text.upper()

    assert "ALEX RIVERA" in upper
    assert "VLTIMATE CV" not in upper  # Toolbar must be hidden in @media print

    idx_summary = upper.find("SUMMARY")
    idx_skills = upper.find("SKILLS")
    idx_experience = upper.find("EXPERIENCE")
    idx_education = upper.find("EDUCATION")
    idx_gdpr = upper.find("GDPR")

    assert -1 not in (idx_summary, idx_skills, idx_experience, idx_education)
    assert idx_summary < idx_skills < idx_experience < idx_education
    if idx_gdpr != -1:
        assert idx_education < idx_gdpr
