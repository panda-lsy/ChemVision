"""Offline release audit. Reports locations only; never prints matched secrets.

python tools/competition_audit.py --history --output <report.json>
Not a legal opinion, vulnerability database, or complete secret scanner.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "provider_key": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    "github_token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})"),
    "supabase_secret": re.compile(r"\bsb_secret_[A-Za-z0-9_-]{16,}"),
    "aws_access_key": re.compile(r"\bAKIA[A-Z0-9]{16}\b"),
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}
JWT = re.compile(r"\beyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def secret_kinds(line: str) -> list[str]:
    kinds = [name for name, pattern in PATTERNS.items() if pattern.search(line)]
    for match in JWT.finditer(line):
        try:
            payload = match[1] + "=" * (-len(match[1]) % 4)
            if json.loads(base64.urlsafe_b64decode(payload)).get("role") == "service_role":
                kinds.append("service_role_jwt")
        except (ValueError, UnicodeDecodeError):
            pass
    return kinds


def audit(history: bool) -> dict:
    tracked = [Path(p) for p in git("ls-files", "-z").decode().split("\0") if p]
    findings = []
    for rel in tracked:
        path = ROOT / rel
        if not path.is_file():
            continue
        raw = path.read_bytes()
        if b"\0" in raw or len(raw) > 5_000_000:
            continue
        for number, line in enumerate(raw.decode("utf-8", errors="replace").splitlines(), 1):
            for kind in secret_kinds(line):
                findings.append({"path": rel.as_posix(), "line": number, "kind": kind})

    historical = []
    if history:
        # Scan added lines across all locally available branches, not remote service data.
        # Stream history: vendor bundles and large diffs must not exhaust RAM.
        process = subprocess.Popen(
            ["git", "-C", str(ROOT), "log", "--all", "--format=COMMIT:%H",
             "--no-renames", "-p", "--diff-filter=AM", "--", "lib", "tools",
             "docs", "doc", ".github", "supabase", "android/app/src",
             "README.md", "pubspec.yaml", ".env", ".env.*"],
            stdout=subprocess.PIPE,
        )
        commit = path = ""
        assert process.stdout is not None
        for raw_line in process.stdout:
            line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
            if line.startswith("COMMIT:"):
                commit = line[7:]
            elif line.startswith("+++ b/"):
                path = line[6:]
            elif line.startswith("+") and not line.startswith("+++"):
                for kind in secret_kinds(line[1:]):
                    entry = {"commit": commit, "path": path, "kind": kind}
                    if entry not in historical:
                        historical.append(entry)
        if process.wait():
            raise RuntimeError("Git history scan failed")

    missing_assets = []
    for html in (ROOT / "assets/web").rglob("*.html"):
        for ref in re.findall(r'(?:src|href)=["\']([^"\']+)["\']', html.read_text("utf-8")):
            parsed = urlparse(ref)
            if parsed.scheme or parsed.netloc or not parsed.path or ref.startswith(("#", "/")):
                continue
            target = html.parent / unquote(parsed.path)
            if not target.is_file():
                missing_assets.append({"html": html.relative_to(ROOT).as_posix(), "ref": ref})

    dependencies = []
    config = ROOT / ".dart_tool/package_config.json"
    if config.exists():
        for package in json.loads(config.read_text("utf-8"))["packages"]:
            if package["name"] == "chemvision":
                continue
            resolved = urlparse(urljoin(config.as_uri(), package["rootUri"]))
            path_text = unquote(resolved.path)
            if re.match(r"^/[A-Za-z]:", path_text):
                path_text = path_text[1:]
            folder = Path(path_text)
            license_files = [p for p in folder.glob("*LICEN*") if p.is_file()]
            dependencies.append({
                "name": package["name"], "resolved_folder": folder.name,
                "license_files": [{"name": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                                  for p in license_files],
            })

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "head": git("rev-parse", "HEAD").decode().strip(),
        "scope": "tracked working tree; optional added lines of local Git history; local Pub dependency license presence",
        "limitations": "Pattern scan only; working tree excludes untracked/ignored files and binaries; history covers lib/tools/docs/doc/.github/supabase/android source/README/pubspec/.env paths, excluding vendor asset history; license presence is not compatibility review; no online CVE scan.",
        "tracked_files": len(tracked), "secret_findings": findings,
        "historical_secret_findings": historical,
        "missing_html_assets": missing_assets, "dependencies": dependencies,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--history", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit(args.history)
    payload = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", "utf-8")
    print(json.dumps({k: len(report[k]) for k in ["secret_findings", "historical_secret_findings", "missing_html_assets", "dependencies"]}))
    raise SystemExit(bool(report["secret_findings"] or report["missing_html_assets"]))
