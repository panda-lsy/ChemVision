"""DECIMER OCSR FastAPI 包装器

将 DECIMER Python 包封装为 HTTP 服务，供 ChemVision Flutter 应用调用。

== 端点约定 ==
POST /process_image
  Content-Type: multipart/form-data
  Body: image=<图片字节>
  Response: text/plain
    - 成功：单行 SMILES
    - 失败：空字符串 或 "INVALID"

== 本地运行 ==
  # 1. 安装依赖（建议用 conda）
  conda create -n decimer python=3.10 -y
  conda activate decimer
  pip install decimer fastapi uvicorn[standard] python-multipart

  # 2. 启动服务
  python decimer_server.py
  # 或：uvicorn decimer_server:app --host 0.0.0.0 --port 7860

== 部署到 Hugging Face Spaces（推荐，免费托管） ==
  1. 在 https://huggingface.co/new-space 创建新 Space（SDK 选 Docker，License 选 MIT）
  2. 把本文件 + 同目录 tools/decimer_hf_space/ 下所有文件一起推到 Space 仓库根目录：
       - decimer_server.py（本文件）
       - Dockerfile
       - README.md（HF Space 元数据，含 YAML frontmatter）
       - requirements.txt
  3. 等待构建完成（首次约 5-10 分钟，需下载约 500MB 模型）
  4. 拿到 Space URL，形如 https://<your-username>-decimer-ocsr.hf.space

== 配合 Cloudflare Worker 使用 ==
  1. 在 cloudflare-worker/worker.js 中已包含 /decimer/ 路由（无需修改）
  2. 编辑 cloudflare-worker/wrangler.toml，设置 DECIMER_UPSTREAM 为 HF Space 地址：
       DECIMER_UPSTREAM = "https://<your-username>-decimer-ocsr.hf.space"
     或用 wrangler secret 设置：`wrangler secret put DECIMER_UPSTREAM`
  3. 部署 Worker：`cd cloudflare-worker && npx wrangler deploy`
  4. Flutter 端在设置页填入 Worker URL + /decimer，例如：
       https://api.chemvision.qzz.io/decimer
     或留空使用默认值
"""

from __future__ import annotations

import io
import logging
import os
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse

logger = logging.getLogger("decimer_server")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

app = FastAPI(title="DECIMER OCSR Wrapper", version="1.0.0")

# 允许任意来源跨域（如需更严格可改为指定域名列表）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# 延迟加载 DECIMER 模型，避免启动失败时整个服务不可用
_decimer_predict = None


def _load_decimer():
    global _decimer_predict
    if _decimer_predict is not None:
        return _decimer_predict
    try:
        from DECIMER import predict_SMILES  # type: ignore
        _decimer_predict = predict_SMILES
        logger.info("DECIMER model loaded")
        return _decimer_predict
    except Exception as e:  # noqa: BLE001
        logger.exception("Failed to load DECIMER: %s", e)
        raise


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/process_image", response_class=PlainTextResponse)
async def process_image(image: UploadFile = File(...)):
    """接收图片字节，返回识别出的 SMILES 字符串。"""
    raw = await image.read()
    if not raw:
        raise HTTPException(status_code=400, detail="empty image")

    predict = _load_decimer()
    # DECIMER 的 predict_SMILES 接受图片路径（或 bytes），
    # 但接受 PIL Image 对象时 pre_process.decode_image 会报
    # "'Image' object has no attribute 'read'"，因此写临时文件传路径
    suffix = ".png"
    ct = (image.content_type or "").lower()
    if "jpeg" in ct or "jpg" in ct:
        suffix = ".jpg"
    elif "webp" in ct:
        suffix = ".webp"

    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(raw)
            tmp_path = tmp.name
        # 预处理：转成 RGB JPEG/PNG（去掉透明通道，DECIMER 的 remove_transparent 偶尔会失败）
        try:
            from PIL import Image  # type: ignore
            with Image.open(tmp_path) as img:
                rgb = img.convert("RGB")
                rgb.save(tmp_path, format="PNG")
        except Exception as e:  # noqa: BLE001
            logger.warning("image normalize failed: %s", e)

        smiles = predict(tmp_path)
    except Exception as e:  # noqa: BLE001
        logger.exception("DECIMER inference failed: %s", e)
        return PlainTextResponse("INVALID")
    finally:
        if tmp_path:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

    if not smiles or not isinstance(smiles, str):
        return PlainTextResponse("")

    cleaned = smiles.strip()
    return PlainTextResponse(cleaned)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("decimer_server:app", host="0.0.0.0", port=7860, reload=False)
