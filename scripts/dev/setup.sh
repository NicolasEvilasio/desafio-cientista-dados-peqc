#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Copie .env.example para .env e defina GCP_PROJECT." >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

if [[ -z "${GCP_PROJECT:-}" ]]; then
  echo "Defina GCP_PROJECT no .env." >&2
  exit 1
fi

PROJECT="${GCP_PROJECT}"
CONFIG_NAME="${PROJECT}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Instale o Google Cloud CLI antes de continuar." >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "Instale o uv antes de continuar." >&2
  exit 1
fi

if ! gcloud config configurations describe "${CONFIG_NAME}" >/dev/null 2>&1; then
  gcloud config configurations create "${CONFIG_NAME}" --no-activate
fi

export CLOUDSDK_ACTIVE_CONFIG_NAME="${CONFIG_NAME}"
gcloud config set project "${PROJECT}"
gcloud auth login
gcloud auth application-default login --project="${PROJECT}"

cd "${ROOT}"
uv sync
uv run pre-commit install
uv run dbt deps --project-dir dbt --profiles-dir dbt

echo "Setup concluído. Rode: uv run dbt build --project-dir dbt --profiles-dir dbt"