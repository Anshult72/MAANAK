FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Fail image builds early if an import-time error would stop Uvicorn on boot.
RUN python -c "from app.main import app; assert app"

# Ensure storage directories exist
RUN mkdir -p storage/images storage/reports storage/audit

# Cloud platforms like Render, Koyeb, Railway pass $PORT automatically
EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
