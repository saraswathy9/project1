# Dockerfile
# WHY: Packages the app + its dependencies into one portable image so it
# runs identically on your laptop, in Jenkins, and inside Kubernetes/EKS.

# ---- Stage 1: Build ----
FROM python:3.11-slim AS builder
WORKDIR /app
COPY app/requirements.txt .
# --no-cache-dir keeps the image small (no pip cache stored inside image)
RUN pip install --no-cache-dir -r requirements.txt --target=/install

# ---- Stage 2: Final small runtime image ----
FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /install /usr/local/lib/python3.11/site-packages
COPY app/ .

# Run as a non-root user (security best practice, checked by Trivy/DevSecOps scans)
RUN useradd -m appuser
USER appuser

EXPOSE 5000
# gunicorn = production-grade server (Flask's built-in server is dev-only)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
