"""Prepare Ketcher assets for the standalone mini-program web renderer.

Run ``python tools/prepare_web_render.py`` before uploading
``miniprogram/web-render/`` to HTTPS static hosting. Existing render/editor
host pages are preserved; only the generated ``ketcher/`` directory is replaced.
"""

import os
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_KETCHER = ROOT / "assets" / "web" / "ketcher"
WEB_RENDER = ROOT / "miniprogram" / "web-render"
DST_KETCHER = WEB_RENDER / "ketcher"


def main() -> None:
    if not SRC_KETCHER.is_dir():
        raise SystemExit(f"ERROR: 未找到原版 Ketcher: {SRC_KETCHER}")

    WEB_RENDER.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".ketcher-build-", dir=WEB_RENDER
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        staged_ketcher = temporary_root / "staged-ketcher"
        backup_ketcher = temporary_root / "previous-ketcher"
        shutil.copytree(SRC_KETCHER, staged_ketcher)

        had_previous = DST_KETCHER.exists() or DST_KETCHER.is_symlink()
        if had_previous:
            os.replace(DST_KETCHER, backup_ketcher)
        try:
            os.replace(staged_ketcher, DST_KETCHER)
        except Exception:
            if had_previous and (
                backup_ketcher.exists() or backup_ketcher.is_symlink()
            ):
                os.replace(backup_ketcher, DST_KETCHER)
            raise

    size = sum(path.stat().st_size for path in DST_KETCHER.rglob("*") if path.is_file())
    print(f"OK: Ketcher 已复制到 {DST_KETCHER}")
    print(f"Ketcher 目录总大小: {size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
