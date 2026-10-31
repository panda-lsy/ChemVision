#!/usr/bin/env python3
"""Bundle the fallback fonts referenced by the installed Flutter Web engine."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
import sys
import time
from urllib.request import Request, urlopen


FONT_URL_PREFIX = "https://fonts.gstatic.com/s/"
FONT_PATH = re.compile(r"[a-z0-9]+/v[0-9]+/[A-Za-z0-9_.-]+\.woff2")


def font_paths(flutter_root: Path) -> list[str]:
    engine = flutter_root / "bin/cache/flutter_web_sdk/lib/_engine/engine"
    fallback_data = (engine / "font_fallback_data.dart").read_text(encoding="utf-8")
    canvaskit_fonts = (engine / "canvaskit/fonts.dart").read_text(encoding="utf-8")
    fallback = set(re.findall(r"'([^']+\.woff2)'", fallback_data))
    roboto = set(FONT_PATH.findall(canvaskit_fonts))
    if not fallback or any(not FONT_PATH.fullmatch(path) for path in fallback) or len(roboto) != 1:
        raise RuntimeError("Could not identify the Flutter engine's fallback fonts")
    return sorted(fallback | roboto)


def download_font(relative_path: str, destination: Path) -> int:
    target = destination / relative_path
    if target.is_file() and target.stat().st_size >= 48:
        with target.open("rb") as existing:
            header = existing.read(12)
            if (
                header[:4] == b"wOF2"
                and int.from_bytes(header[8:12], "big") == target.stat().st_size
            ):
                return target.stat().st_size

    last_error = None
    for attempt in range(3):
        try:
            request = Request(
                FONT_URL_PREFIX + relative_path,
                headers={"User-Agent": "ChemVision-font-bundler/1.0"},
            )
            with urlopen(request, timeout=30) as response:
                content = response.read()
            if (
                len(content) < 48
                or content[:4] != b"wOF2"
                or int.from_bytes(content[8:12], "big") != len(content)
            ):
                raise ValueError("Response is not a complete WOFF2 font")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            return len(content)
        except Exception as error:
            last_error = error
            if attempt < 2:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"Could not download {relative_path}: {last_error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-root", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()

    paths = font_paths(args.flutter_root)
    errors = []
    total_bytes = 0
    with ThreadPoolExecutor(max_workers=16) as pool:
        pending = {
            pool.submit(download_font, path, args.destination): path for path in paths
        }
        for future in as_completed(pending):
            try:
                total_bytes += future.result()
            except Exception as error:
                errors.append(str(error))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    (args.destination / "manifest.json").write_text(
        json.dumps({"version": 1, "fontCount": len(paths)}) + "\n", encoding="utf-8"
    )
    print(f"Bundled {len(paths)} Flutter fallback fonts ({total_bytes / 1024 / 1024:.1f} MiB).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
