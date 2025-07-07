# backend/Dockerfile

# Stage 1: Build Stage (install dependencies)
FROM python:3.9-slim-buster as builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Production Stage (copy only necessary files)
FROM python:3.9-slim-buster

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]