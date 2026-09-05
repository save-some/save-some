# The save-some REST API.
#
# Multi-stage so the runtime image doesn't carry pip, build tooling or the wheel
# cache. Dependencies are installed into a virtualenv in the builder and the
# whole venv is copied across, which keeps the final layer small and means the
# runtime stage needs no compiler at all.

# ---------------------------------------------------------------------------
# Builder
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS builder

# psycopg2-binary ships wheels, so no libpq-dev or gcc is needed here. If a
# dependency without a wheel is ever added, this is where build-essential goes.
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copied on its own so a source change doesn't invalidate the dependency layer —
# this is the slow step and it should almost never re-run.
COPY requirements.txt .
RUN pip install -r requirements.txt

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH"

# Not root. The API needs no privileges, and a container that can't write to its
# own filesystem is one less thing to think about.
RUN useradd --create-home --uid 10001 api

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=api:api api ./api
COPY --chown=api:api helpers ./helpers
COPY --chown=api:api schema ./schema
COPY --chown=api:api seed ./seed

USER api

EXPOSE 8000

# The app object is named `application`, not `app` — api/main.py defines it that
# way, so `uvicorn api.main:app` fails.
#
# Bound to 0.0.0.0 because 127.0.0.1 inside a container is only reachable from
# inside that container, so a published port would connect to nothing.
CMD ["uvicorn", "api.main:application", "--host", "0.0.0.0", "--port", "8000"]

# Reports unhealthy until the API can actually serve, which is what `docker
# compose up --wait` and `make start` rely on rather than a fixed sleep.
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/v1/health',timeout=2).status==200 else 1)"
