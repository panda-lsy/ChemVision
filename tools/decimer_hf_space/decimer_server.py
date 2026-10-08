"""FastAPI wrapper for DECIMER optical chemical structure recognition."""

from __future__ import annotations

import asyncio
import logging
import os
import tempfile
import warnings

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from starlette.concurrency import run_in_threadpool

logger = logging.getLogger("decimer_server")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

MAX_UPLOAD_BYTES = 7 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000

app = FastAPI(title="DECIMER OCSR Wrapper", version="1.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

_decimer_predict = None
_inference_lock = asyncio.Semaphore(1)


class _ImageTooLarge(Exception):
    pass


def _load_decimer():
    global _decimer_predict
    if _decimer_predict is None:
        try:
            from DECIMER import predict_SMILES  # type: ignore
        except Exception:
            logger.exception("Failed to load DECIMER")
            raise
        _decimer_predict = predict_SMILES
        logger.info("DECIMER model loaded")
    return _decimer_predict


def _recognize_image(raw: bytes) -> str:
    source_path = None
    normalized_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as temporary:
            temporary.write(raw)
            source_path = temporary.name
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as temporary:
            normalized_path = temporary.name

        from PIL import Image  # type: ignore

        Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", Image.DecompressionBombWarning)
            try:
                with Image.open(source_path) as image:
                    if image.width * image.height > MAX_IMAGE_PIXELS:
                        raise _ImageTooLarge
                    image.convert("RGB").save(normalized_path, format="PNG")
            except Image.DecompressionBombError as error:
                raise _ImageTooLarge from error

        result = _load_decimer()(normalized_path)
        return result.strip() if isinstance(result, str) else ""
    finally:
        for temporary_path in (source_path, normalized_path):
            if temporary_path:
                try:
                    os.unlink(temporary_path)
                except OSError:
                    logger.warning("Could not remove temporary image file")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/process_image", response_class=PlainTextResponse)
async def process_image(image: UploadFile = File(...)):
    try:
        raw = await image.read(MAX_UPLOAD_BYTES + 1)
    finally:
        await image.close()

    if not raw:
        raise HTTPException(status_code=400, detail="empty image")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="image exceeds the 7 MiB limit")

    try:
        await asyncio.wait_for(_inference_lock.acquire(), timeout=30)
    except asyncio.TimeoutError as error:
        raise HTTPException(status_code=503, detail="recognition service is busy") from error

    try:
        smiles = await run_in_threadpool(_recognize_image, raw)
    except _ImageTooLarge as error:
        raise HTTPException(status_code=413, detail="image dimensions exceed the limit") from error
    except Exception:
        logger.exception("DECIMER inference failed")
        return PlainTextResponse("INVALID")
    finally:
        _inference_lock.release()

    return PlainTextResponse(smiles or "INVALID")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("decimer_server:app", host="0.0.0.0", port=7860, reload=False)
