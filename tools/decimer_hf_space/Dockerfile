# Hugging Face Spaces Dockerfile for DECIMER OCSR Wrapper
# 部署步骤见同目录 README.md
FROM python:3.10-slim

# DECIMER 依赖的系统库（OpenCV / Pillow 解码需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先装依赖，利用 Docker 层缓存
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# 拷贝应用代码
COPY decimer_server.py /app/decimer_server.py

# HF Spaces 默认端口 7860
ENV PORT=7860
EXPOSE 7860

# 启动服务
CMD ["uvicorn", "decimer_server:app", "--host", "0.0.0.0", "--port", "7860"]
