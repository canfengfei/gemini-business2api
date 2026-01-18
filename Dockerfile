# Stage 1: 构建前端
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend

# 先复制 package 文件利用 Docker 缓存
COPY frontend/package.json frontend/package-lock.json ./
RUN npm install --silent

# 复制前端源码并构建
COPY frontend/ ./
RUN npm run build

# Stage 2: 最终运行时镜像
FROM python:3.11-slim
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 安装 Chrome 浏览器和 Python 依赖
COPY requirements.txt .
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        wget \
        gnupg \
        ca-certificates \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
        xdg-utils && \
    # 添加 Google Chrome 官方源
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    # 防止被 autoremove 误删（以及构建期快速校验浏览器是否真的安装成功）
    apt-mark manual google-chrome-stable && \
    google-chrome-stable --version && \
    # 安装 Python 依赖
    pip install --no-cache-dir -r requirements.txt && \
    # 清理
    apt-get purge -y gcc wget gnupg && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置 Chrome 路径环境变量（优先使用真实二进制路径，避免某些库无法识别 wrapper）
ENV CHROME_BIN=/usr/bin/google-chrome-stable \
    GOOGLE_CHROME_BIN=/usr/bin/google-chrome-stable

# 复制后端代码
COPY main.py .
COPY core ./core
COPY util ./util

# 从 builder 阶段只复制构建好的静态文件
COPY --from=frontend-builder /app/static ./static

# 创建数据目录
RUN mkdir -p ./data

# 声明数据卷
VOLUME ["/app/data"]

# 启动服务
CMD ["python", "-u", "main.py"]
