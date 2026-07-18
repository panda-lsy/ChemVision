---
title: Decimer Ocsr
emoji: 🧪
colorFrom: indigo
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# DECIMER OCSR Wrapper

将 [DECIMER](https://github.com/Kohulan/DECIMER-Image_Transformer)（Deep lEarning for Chemical IMagE Recognition）封装为 HTTP REST 服务，供 ChemVision Flutter 应用调用。

## 端点

### `GET /health`
返回 `{"status": "ok"}`，用于健康检查。

### `POST /process_image`
- Content-Type: `multipart/form-data`
- 字段：`image`（图片字节）
- 响应：`text/plain`
  - 成功：单行 SMILES 字符串
  - 失败：空字符串 或 `INVALID`

示例（curl）：
```bash
curl -X POST https://<your-space>.hf.space/process_image \
  -F "image=@molecule.png"
```

## 部署步骤

1. 在 [Hugging Face](https://huggingface.co/new-space) 创建新 Space
   - SDK 选 **Docker**
   - License 选 MIT（或与 DECIMER 兼容的许可）
2. 把本目录下所有文件 + `decimer_server.py`（位于上层 `tools/decimer_server.py`）一起推到 Space 仓库根目录：
   ```
   git clone https://huggingface.co/spaces/<your-username>/decimer-ocsr
   cp tools/decimer_hf_space/Dockerfile      decimer-ocsr/
   cp tools/decimer_hf_space/README.md       decimer-ocsr/
   cp tools/decimer_hf_space/requirements.txt decimer-ocsr/
   cp tools/decimer_server.py                decimer-ocsr/
   cd decimer-ocsr
   git add . && git commit -m "init decimer ocsr" && git push
   ```
3. 等待构建完成（首次约 5–10 分钟，需要下载 DECIMER 模型约 500 MB）
4. 拿到 Space URL，形如：`https://<your-username>-decimer-ocsr.hf.space`
5. 在 Cloudflare Worker 的 `wrangler.toml` 中设置上游：
   ```toml
   [vars]
   DECIMER_UPSTREAM = "https://<your-username>-decimer-ocsr.hf.space"
   ```
6. 部署 Worker：`cd cloudflare-worker && npx wrangler deploy`
7. Flutter 应用「设置 → OCSR 服务地址」填入 Worker URL + `/decimer`，例如：
   `https://api.chemvision.qzz.io/decimer`

## 免费额度说明

Hugging Face Spaces 免费档：
- CPU 16GB 内存（DECIMER 推理需要 4–8GB）
- 闲置自动休眠，首次请求冷启动约 30–60s
- 月流量 10 GB（个人使用足够）

如需常驻或更高吞吐，可升级到付费档或迁移到其他容器平台（Render / Fly.io / Railway 等），Dockerfile 通用。
