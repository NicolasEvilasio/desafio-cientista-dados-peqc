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

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Instale o Google Cloud CLI antes de continuar." >&2
  exit 1
fi

remote="$(git -C "${ROOT}" remote get-url origin)"
remote="${remote%.git}"
remote="${remote#git@github.com:}"
remote="${remote#https://github.com/}"
remote="${remote#ssh://git@github.com/}"
repository="${remote}"

export CLOUDSDK_ACTIVE_CONFIG_NAME="${GCP_PROJECT}"
project_number="$(gcloud projects describe "${GCP_PROJECT}" --format='value(projectNumber)')"
service_account="dbt-ci@${GCP_PROJECT}.iam.gserviceaccount.com"
provider="projects/${project_number}/locations/global/workloadIdentityPools/github/providers/github"
member="principalSet://iam.googleapis.com/projects/${project_number}/locations/global/workloadIdentityPools/github/attribute.repository/${repository}"

gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project="${GCP_PROJECT}"

if ! gcloud iam workload-identity-pools describe github --project="${GCP_PROJECT}" --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create github \
    --project="${GCP_PROJECT}" \
    --location=global \
    --display-name="GitHub Actions"
fi

if ! gcloud iam workload-identity-pools providers describe github \
  --project="${GCP_PROJECT}" \
  --location=global \
  --workload-identity-pool=github >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc github \
    --project="${GCP_PROJECT}" \
    --location=global \
    --workload-identity-pool=github \
    --display-name="GitHub Actions" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${repository}'"
fi

if ! gcloud iam service-accounts describe "${service_account}" --project="${GCP_PROJECT}" >/dev/null 2>&1; then
  gcloud iam service-accounts create dbt-ci \
    --project="${GCP_PROJECT}" \
    --display-name="dbt CI"
fi

gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:${service_account}" \
  --role="roles/bigquery.jobUser" \
  --quiet

gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:${service_account}" \
  --role="roles/bigquery.dataEditor" \
  --quiet

gcloud iam service-accounts add-iam-policy-binding "${service_account}" \
  --project="${GCP_PROJECT}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="${member}" \
  --quiet

cat <<EOF

Identidade federada pronta para ${repository}.
Crie estas variáveis no GitHub (Settings → Secrets and variables → Actions → Variables):

  GCP_PROJECT=${GCP_PROJECT}
  GCP_SERVICE_ACCOUNT=${service_account}
  GCP_WORKLOAD_IDENTITY_PROVIDER=${provider}

A conta ${service_account} precisa ler gs://case_vagas.
Se o bucket não for público, conceda roles/storage.objectViewer a essa conta.

EOF
