# CI com identidade federada

O workflow [`.github/workflows/dbt.yml`](../../.github/workflows/dbt.yml) autentica no GCP sem chave JSON. O GitHub emite um token curto do job, o pool de identidade troca esse token por um acesso da conta de serviço `dbt-ci`, e o dbt lê essa credencial com `method: oauth` no target `ci`.

Isso é feito uma vez, na conta de quem mantém o repositório. Quem só vai avaliar o projeto não roda estes passos: a execução está na aba Actions do GitHub.

## 1. Criar o pool e a conta no GCP

O `.env` na raiz precisa ter `GCP_PROJECT`. O gcloud precisa estar autenticado numa conta com permissão de IAM nesse projeto.

Na raiz do repositório:

```bash
./scripts/ci/setup-workload-identity.sh
```

O script lê o `GCP_PROJECT` do `.env` e o repositório do remote `origin`. Cria, se ainda não existirem:

- o pool `github` e o provedor OIDC `github`, confiando só nesse repositório (`https://token.actions.githubusercontent.com`)
- a conta `dbt-ci@SEU_PROJETO.iam.gserviceaccount.com`
- `roles/bigquery.jobUser` e `roles/bigquery.dataEditor` para essa conta no projeto
- `roles/iam.workloadIdentityUser` para o repositório impersonar a conta

No final, o script imprime os três valores do passo seguinte.

A conta `dbt-ci` também precisa ler `gs://case_vagas`.
Caso o bucket deixe de ser público, quem o administra deve conceder `roles/storage.objectViewer` a `dbt-ci@SEU_PROJETO.iam.gserviceaccount.com`.

## 2. Criar as variáveis no GitHub

No repositório: **Settings → Secrets and variables → Actions → Variables → New repository variable**.

São variáveis, não secrets. Nenhuma delas é uma chave.

| Nome | Valor |
|---|---|
| `GCP_PROJECT` | O id do projeto, o mesmo do `.env`. |
| `GCP_SERVICE_ACCOUNT` | O e-mail impresso pelo script. Exemplo: `dbt-ci@desafio-prefrio.iam.gserviceaccount.com`. |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | O caminho impresso pelo script. O número no começo é o **número** do projeto, não o id. Exemplo: `projects/123456789/locations/global/workloadIdentityPools/github/providers/github`. |

O workflow lê esses três nomes. Sem eles, o job quebra no passo de autenticação.

## 3. Rodar

Um push em `master`, ou um pull request, dispara o workflow. Ele faz `uv sync --frozen`, `dbt deps` e `dbt build --target ci`.
