FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y libpq-dev gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY api_server.py .

EXPOSE 8888

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8888/health')" || exit 1

CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8888"]
