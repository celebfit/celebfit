FROM pytorch/pytorch:2.2.0-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    MODEL_REPO_ROOT=/app/model_repo \
    HF_HOME=/data/huggingface \
    TORCH_HOME=/data/torch \
    ENABLE_SD=true \
    USE_GITHUB_PIPELINE=true \
    ALLOW_FALLBACK=false \
    API_PORT=8000

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# GitHub model pipeline (SD Inpaint + LoRA + BiSeNet + util)
RUN git clone --depth 1 https://github.com/jiucai233/ConditionalImageGeneration.git /app/model_repo

# BiSeNet ONNX weights
RUN cd /app/model_repo/masking_bisenet/face-parsing && \
    mkdir -p weights && \
    curl -fsSL -o weights/resnet18.onnx \
      https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx

COPY api/requirements-docker.txt /app/api/requirements-docker.txt
RUN pip install --no-cache-dir -r /app/api/requirements-docker.txt

COPY api/ /app/api/

RUN mkdir -p /data/huggingface /data/torch /app/weights

COPY deploy/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${API_PORT}/health" || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
