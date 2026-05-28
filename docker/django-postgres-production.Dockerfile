# =========================================================================
# TITLE: Production-Grade Multi-Stage Django Dockerfile
# INTERVIEW CHEAT SHEET (EDIT ONLY THESE 3 VARIABLES FOR LIVE CODE):
#   1. Line 13 & 31: Change '3.11-slim' to match the requested Python version.
#   2. Line 51: Change 'core.wsgi:application' to match the 'project_name.wsgi:application'.
#   3. Line 51: Change port '8000' if the interviewer specifies a different port.
# =========================================================================

# ==========================================
# STAGE 1: The Builder (The Construction Room)
# ==========================================
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install the exact compilation tools needed to build PostgreSQL drivers safely
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependencies list and pre-compile them into clean wheels
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt


# ==========================================
# STAGE 2: The Runner (The Final Slim Box)
# ==========================================
FROM python:3.11-slim AS runner

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Create a secure, non-privileged user so our app doesn't run as "root"
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Install ONLY the bare-minimum runtime library needed to talk to PostgreSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Pull ONLY the pre-compiled packages from Stage 1
COPY --from=builder /app/wheels /images/wheels
COPY --from=builder /app/requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/images/wheels -r requirements.txt \
    && rm -rf /images/wheels

# Copy actual Django application files into this final clean box
COPY . .

# Secure the application files to be owned by our non-root user
RUN chown -R appuser:appuser /app
USER appuser

# Open up digital port 8000 for cloud traffic
EXPOSE 8000

# Start the app using Gunicorn
CMD ["gunicorn", "core.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
