# Control API image (CI artifact). Runs as non-root; no secrets baked in.
# Local development usually runs uvicorn on the host instead, because the
# lab adapter needs the Docker CLI and the Terraform adapter needs terraform.
FROM python:3.15-slim AS build
WORKDIR /src
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-cache-dir --prefix=/install .

FROM python:3.15-slim
RUN useradd --create-home --uid 10001 cnops
COPY --from=build /install /usr/local
USER cnops
ENV CNOPS_LAB_MODE=fake \
    CNOPS_TERRAFORM_MODE=fake \
    CNOPS_STORE_MODE=fake \
    PYTHONUNBUFFERED=1
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"
CMD ["uvicorn", "--factory", "cnops_api.main:create_app", "--host", "0.0.0.0", "--port", "8000"]
